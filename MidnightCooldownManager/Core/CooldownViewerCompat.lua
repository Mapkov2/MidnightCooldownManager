local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]

local IsSafeNumber = CDM.IsSafeNumber
local table_wipe = table.wipe
local tonumber = tonumber
local tostring = tostring
local type = type
local pcall = pcall

local Compat = {}
CDM.CooldownViewerCompat = Compat

local infoCache = {}
local infoCacheSize = 0
local groupBuffItemsCache = nil
local groupBuffItemsCacheSize = 0
local generation = 1
local categories
local categoryNamesByID
local EMPTY_CATEGORIES = {}
local MAX_INFO_CACHE_ENTRIES = 4096
local SOURCE_CATEGORY_NAMES = {
    "Essential",
    "Utility",
    "TrackedBuff",
    "TrackedBar",
    "EquipSlotEssential",
    "EquipSlotTracked",
    "SpecAgnosticEssential",
    "SpecAgnosticTracked",
}
local SOURCE_CATEGORY_KEYS = {
    { key = "essential", name = "Essential" },
    { key = "utility", name = "Utility" },
    { key = "buff", name = "TrackedBuff" },
    { key = "bar", name = "TrackedBar" },
    { key = "equipEssential", name = "EquipSlotEssential" },
    { key = "equipTracked", name = "EquipSlotTracked" },
    { key = "specAgnosticEssential", name = "SpecAgnosticEssential" },
    { key = "specAgnosticTracked", name = "SpecAgnosticTracked" },
}
local SETTINGS_ADDON_NAME = "Blizzard_CooldownViewer"
local SETTINGS_PANEL_NAME = "CooldownViewerSettings"
local SETTINGS_EVENT_NAMES = {
    onShow = "CooldownViewerSettings.OnShow",
    onHide = "CooldownViewerSettings.OnHide",
    onDataChanged = "CooldownViewerSettings.OnDataChanged",
    onPendingChanges = "CooldownViewerSettings.OnPendingChanges",
}
local ACQUIRE_ITEM_FRAME_METHOD = "OnAcquireItemFrame"
local ACTIVE_STATE_CHANGED_METHOD = "OnActiveStateChanged"
local REFRESH_LAYOUT_METHOD = "RefreshLayout"
local COOLDOWN_ITEM_LIFECYCLE_CALLBACKS = {
    { key = "onCooldownSet", method = "SetCooldownID" },
    { key = "onCooldownCleared", method = "ClearCooldownID" },
    { key = "onOverrideSpellChanged", method = "SetOverrideSpell" },
    { key = "onDataRefreshed", method = "RefreshData" },
    { key = "onDataReset", method = "ResetCooldownData" },
}

local stats = {
    hits = 0,
    misses = 0,
    apiCalls = 0,
    groupBuffApiCalls = 0,
    apiErrors = 0,
    cooldownInfoErrors = 0,
    categorySetErrors = 0,
    groupBuffErrors = 0,
    lastAPIError = "none",
    invalidations = 0,
    hiddenCategoryRemaps = 0,
    lastInvalidationReason = "load",
}
local settingsVisibilityHookCallbacks = {}
local settingsVisibilityLoadWatcherSet = false
local sourceCategoryMap
local sourceCategoryMapGeneration = -1

local function IsValidID(id)
    return IsSafeNumber(id) and id > 0
end

local function TrackAPIError(kind, err)
    stats.apiErrors = stats.apiErrors + 1
    stats.lastAPIError = kind .. ": " .. tostring(err or "unknown")
    if kind == "cooldownInfo" then
        stats.cooldownInfoErrors = stats.cooldownInfoErrors + 1
    elseif kind == "categorySet" then
        stats.categorySetErrors = stats.categorySetErrors + 1
    elseif kind == "groupBuffItems" then
        stats.groupBuffErrors = stats.groupBuffErrors + 1
    end
end

function Compat:IsValidCooldownID(id)
    return IsValidID(id)
end

function Compat:NormalizeCooldownID(id)
    if IsValidID(id) then
        return id
    end
    if type(id) == "string" then
        local num = tonumber(id)
        if IsValidID(num) then
            return num
        end
    end
    return nil
end

function Compat:CallFrameMethod(frame, methodName)
    local method = frame and frame[methodName]
    if type(method) ~= "function" then return nil end
    local ok, value = pcall(method, frame)
    if ok then return value end
    return nil
end

function Compat:FrameHasChargeVisualSource(frame)
    return self:CallFrameMethod(frame, "HasVisualDataSource_Charges") and true or false
end

function Compat:IsFrameUsingAuraDisplayTime(frame)
    return frame and frame.cooldownUseAuraDisplayTime == true or false
end

function Compat:GetFrameCooldownDesaturated(frame)
    if not frame then return nil end
    return frame.cooldownDesaturated
end

function Compat:GetViewerFrame(viewerName)
    if type(viewerName) ~= "string" then return nil end
    return _G[viewerName]
end

function Compat:ForEachActiveFrame(viewers, callback)
    if type(viewers) ~= "table" or type(callback) ~= "function" then return end

    for _, viewerName in ipairs(viewers) do
        local viewer = self:GetViewerFrame(viewerName)
        local pool = viewer and viewer.itemFramePool
        if pool and pool.EnumerateActive then
            for frame in pool:EnumerateActive() do
                if callback(frame, viewerName, viewer) then
                    return true
                end
            end
        end
    end
end

function Compat:CountActiveFrames(viewerOrName)
    local viewer = type(viewerOrName) == "string" and self:GetViewerFrame(viewerOrName) or viewerOrName
    local pool = viewer and viewer.itemFramePool
    if not (pool and pool.EnumerateActive) then
        return 0
    end

    local count = 0
    for _ in pool:EnumerateActive() do
        count = count + 1
    end
    return count
end

function Compat:InstallViewerAcquireCallback(viewerOrName, ownerKey, callback)
    if not ownerKey or type(callback) ~= "function" then return false end

    local viewer = type(viewerOrName) == "string" and self:GetViewerFrame(viewerOrName) or viewerOrName
    if not viewer or type(viewer[ACQUIRE_ITEM_FRAME_METHOD]) ~= "function" then
        return false
    end

    local hooked = viewer.cdmAcquireHookOwners
    if type(hooked) ~= "table" then
        hooked = {}
        viewer.cdmAcquireHookOwners = hooked
    elseif hooked[ownerKey] then
        return true
    end
    hooked[ownerKey] = true

    hooksecurefunc(viewer, ACQUIRE_ITEM_FRAME_METHOD, function(_, itemFrame)
        callback(itemFrame, viewer, viewerOrName)
    end)
    return true
end

function Compat:InstallViewerRefreshLayoutCallback(viewerOrName, ownerKey, callback)
    if not ownerKey or type(callback) ~= "function" then return false end

    local viewer = type(viewerOrName) == "string" and self:GetViewerFrame(viewerOrName) or viewerOrName
    if not viewer or type(viewer[REFRESH_LAYOUT_METHOD]) ~= "function" then
        return false
    end

    local hooked = viewer.cdmRefreshLayoutHookOwners
    if type(hooked) ~= "table" then
        hooked = {}
        viewer.cdmRefreshLayoutHookOwners = hooked
    elseif hooked[ownerKey] then
        return true
    end
    hooked[ownerKey] = true

    hooksecurefunc(viewer, REFRESH_LAYOUT_METHOD, function(self, ...)
        callback(self, viewerOrName, ...)
    end)
    return true
end

function Compat:InstallItemActiveStateCallback(itemFrame, ownerKey, callback)
    if not itemFrame or not ownerKey or type(callback) ~= "function" then return false end
    if type(itemFrame[ACTIVE_STATE_CHANGED_METHOD]) ~= "function" then
        return false
    end

    local hooked = itemFrame.cdmActiveStateHookOwners
    if type(hooked) ~= "table" then
        hooked = {}
        itemFrame.cdmActiveStateHookOwners = hooked
    elseif hooked[ownerKey] then
        return true
    end
    hooked[ownerKey] = true

    hooksecurefunc(itemFrame, ACTIVE_STATE_CHANGED_METHOD, function(self, ...)
        callback(self, ...)
    end)
    return true
end

function Compat:InstallCooldownItemLifecycleCallbacks(itemFrame, ownerKey, callbacks)
    if not itemFrame or type(callbacks) ~= "table" then return end
    ownerKey = ownerKey or "default"

    local hooked = itemFrame.cdmLifecycleHookOwners
    if type(hooked) ~= "table" then
        hooked = {}
        itemFrame.cdmLifecycleHookOwners = hooked
    elseif hooked[ownerKey] then
        return
    end
    hooked[ownerKey] = true

    for _, spec in ipairs(COOLDOWN_ITEM_LIFECYCLE_CALLBACKS) do
        local methodName = spec.method
        local callback = callbacks[spec.key]
        if type(callback) == "function" and type(itemFrame[methodName]) == "function" then
            hooksecurefunc(itemFrame, methodName, callback)
        end
    end
end

local function SecureCallMethod(method, owner, ...)
    if type(method) ~= "function" then return false end
    if _G.securecallfunction then
        securecallfunction(method, owner, ...)
        return true
    end
    local ok = pcall(method, owner, ...)
    return ok and true or false
end

local function SecureCallGlobal(functionName, ...)
    local fn = _G[functionName]
    if type(fn) ~= "function" then return false end
    if _G.securecall then
        securecall(functionName, ...)
        return true
    end
    local ok = pcall(fn, ...)
    return ok and true or false
end

function Compat:GetSettingsPanel(load)
    local panel = _G[SETTINGS_PANEL_NAME]
    if panel or not load then
        return panel
    end

    if _G.C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, SETTINGS_ADDON_NAME)
    end

    return _G[SETTINGS_PANEL_NAME]
end

function Compat:IsSettingsPanelVisible()
    local panel = self:GetSettingsPanel(false)
    return panel and panel.IsVisible and panel:IsVisible() or false
end

function Compat:ToggleSettingsPanel()
    local panel = self:GetSettingsPanel(true)
    if not panel then return false end

    if panel.IsVisible and panel:IsVisible() then
        return SecureCallGlobal("HideUIPanel", panel)
    end

    if panel.ShowUIPanel and SecureCallMethod(panel.ShowUIPanel, panel) then
        return true
    end

    return SecureCallGlobal("ShowUIPanel", panel)
end

local function HookSettingsPanelVisibilityOwner(panel, ownerKey, callback)
    if not (panel and ownerKey and type(callback) == "function") then return false end

    local hooked = panel.cdmSettingsVisibilityHookOwners
    if type(hooked) ~= "table" then
        hooked = {}
        panel.cdmSettingsVisibilityHookOwners = hooked
    elseif hooked[ownerKey] then
        return true
    end
    hooked[ownerKey] = true

    panel:HookScript("OnShow", callback)
    panel:HookScript("OnHide", callback)
    return true
end

local function FlushSettingsPanelVisibilityHooks()
    local panel = Compat:GetSettingsPanel(false)
    if not panel then return false end

    for ownerKey, callback in pairs(settingsVisibilityHookCallbacks) do
        HookSettingsPanelVisibilityOwner(panel, ownerKey, callback)
    end
    return true
end

function Compat:HookSettingsPanelVisibility(ownerKey, callback)
    if not ownerKey or type(callback) ~= "function" then return false end
    settingsVisibilityHookCallbacks[ownerKey] = callback

    if FlushSettingsPanelVisibilityHooks() then
        return true
    end

    if not settingsVisibilityLoadWatcherSet and EventUtil and EventUtil.ContinueOnAddOnLoaded then
        settingsVisibilityLoadWatcherSet = true
        EventUtil.ContinueOnAddOnLoaded(SETTINGS_ADDON_NAME, FlushSettingsPanelVisibilityHooks)
    end

    return false
end

function Compat:RegisterSettingsEventCallback(eventKey, callback, owner)
    local eventName = SETTINGS_EVENT_NAMES[eventKey]
    if not (eventName and type(callback) == "function") then return false end
    if not (EventRegistry and EventRegistry.RegisterCallback) then return false end
    EventRegistry:RegisterCallback(eventName, callback, owner)
    return true
end

function Compat:UnregisterSettingsEventCallback(eventKey, owner)
    local eventName = SETTINGS_EVENT_NAMES[eventKey]
    if not (eventName and owner) then return false end
    if not (EventRegistry and EventRegistry.UnregisterCallback) then return false end
    EventRegistry:UnregisterCallback(eventName, owner)
    return true
end

function Compat:GetFrameCooldownID(frame)
    if not frame then return nil end

    local id = self:NormalizeCooldownID(frame.cooldownID)
    if id then return id end

    local info = frame.cooldownInfo
    id = self:NormalizeCooldownID(info and info.cooldownID)
    if id then return id end

    local icon = frame.Icon
    id = self:NormalizeCooldownID(icon and icon.cooldownID)
    if id then return id end

    return self:NormalizeCooldownID(self:CallFrameMethod(frame, "GetCooldownID"))
end

function Compat:GetCooldownInfo(cooldownID)
    cooldownID = self:NormalizeCooldownID(cooldownID)
    if not cooldownID then return nil end

    local cached = infoCache[cooldownID]
    if cached ~= nil then
        stats.hits = stats.hits + 1
        return cached ~= false and cached or nil
    end

    stats.misses = stats.misses + 1

    local info
    local apiSucceeded = false
    local cv = C_CooldownViewer
    if cv and cv.GetCooldownViewerCooldownInfo then
        stats.apiCalls = stats.apiCalls + 1
        local ok, result = pcall(cv.GetCooldownViewerCooldownInfo, cooldownID)
        if ok then
            apiSucceeded = true
            info = result
        else
            TrackAPIError("cooldownInfo", result)
        end
    end

    if not apiSucceeded then
        return nil
    end

    if infoCache[cooldownID] == nil then
        infoCacheSize = infoCacheSize + 1
        if infoCacheSize > MAX_INFO_CACHE_ENTRIES then
            table_wipe(infoCache)
            infoCacheSize = 1
        end
    end

    infoCache[cooldownID] = info or false
    return info
end

function Compat:GetCategories()
    if categories then return categories end

    local evc = Enum and Enum.CooldownViewerCategory
    if not evc then
        return EMPTY_CATEGORIES
    end

    categories = {}
    local seen = {}
    local function Add(category)
        if type(category) ~= "number" or seen[category] then return end
        seen[category] = true
        categories[#categories + 1] = category
    end

    for _, categoryName in ipairs(SOURCE_CATEGORY_NAMES) do
        Add(evc[categoryName])
    end

    return categories
end

function Compat:GetEffectiveCategory(sourceCategory, info)
    if not info then return sourceCategory end

    local hideFlag = Enum and Enum.CooldownSetSpellFlags and Enum.CooldownSetSpellFlags.HideByDefault
    if not (hideFlag and FlagsUtil and FlagsUtil.IsSet and info.flags and FlagsUtil.IsSet(info.flags, hideFlag)) then
        return sourceCategory
    end

    local evc = Enum and Enum.CooldownViewerCategory
    if not evc then return sourceCategory end

    if sourceCategory == evc.Essential or sourceCategory == evc.Utility then
        return evc.HiddenActive or evc.HiddenSpell or sourceCategory
    end
    if sourceCategory == evc.TrackedBuff or sourceCategory == evc.TrackedBar then
        return evc.HiddenPassive or evc.HiddenAura or sourceCategory
    end

    return sourceCategory
end

function Compat:GetCategoryName(category)
    if type(category) == "number" then
        if not categoryNamesByID then
            categoryNamesByID = {}
            local evc = Enum and Enum.CooldownViewerCategory
            if evc then
                for name, value in pairs(evc) do
                    if type(value) == "number" and categoryNamesByID[value] == nil then
                        categoryNamesByID[value] = name
                    end
                end
            end
        end
        return categoryNamesByID[category] or tostring(category)
    end
    return tostring(category or "nil")
end

function Compat:GetCategoryByName(categoryName)
    local evc = Enum and Enum.CooldownViewerCategory
    if not evc or type(categoryName) ~= "string" then return nil end
    local category = evc[categoryName]
    return type(category) == "number" and category or nil
end

function Compat:GetSourceCategoryMap()
    if sourceCategoryMap and sourceCategoryMapGeneration == generation then
        return sourceCategoryMap
    end

    local map = { snapshotSet = {} }
    local resolved = 0
    for _, spec in ipairs(SOURCE_CATEGORY_KEYS) do
        local category = self:GetCategoryByName(spec.name)
        if category ~= nil then
            map[spec.key] = category
            map.snapshotSet[category] = true
            resolved = resolved + 1
        end
    end

    sourceCategoryMap = map
    sourceCategoryMapGeneration = resolved > 0 and generation or -1
    return map
end

function Compat:ForEachCooldownInfo(callback)
    if type(callback) ~= "function" then return end

    local cv = C_CooldownViewer
    if not cv or not cv.GetCooldownViewerCategorySet then return end

    for _, category in ipairs(self:GetCategories()) do
        local ok, cooldownIDs = pcall(cv.GetCooldownViewerCategorySet, category, true)
        if not ok then
            TrackAPIError("categorySet", cooldownIDs)
            cooldownIDs = nil
        end
        if cooldownIDs then
            for _, cooldownID in ipairs(cooldownIDs) do
                local info = self:GetCooldownInfo(cooldownID)
                if info then
                    local effectiveCategory = self:GetEffectiveCategory(category, info)
                    if effectiveCategory ~= category then
                        stats.hiddenCategoryRemaps = stats.hiddenCategoryRemaps + 1
                    end
                    if callback(cooldownID, info, effectiveCategory, category) then
                        return true
                    end
                end
            end
        end
    end
end

function Compat:GetGroupBuffItems()
    if groupBuffItemsCache ~= nil then
        return groupBuffItemsCache ~= false and groupBuffItemsCache or nil
    end

    local cv = C_CooldownViewer
    if cv and cv.GetGroupBuffItems then
        stats.groupBuffApiCalls = stats.groupBuffApiCalls + 1
        local ok, items = pcall(cv.GetGroupBuffItems)
        if not ok then
            TrackAPIError("groupBuffItems", items)
            groupBuffItemsCacheSize = 0
            return nil
        end
        if type(items) == "table" then
            groupBuffItemsCache = items
            groupBuffItemsCacheSize = #items
            return items
        end
    end

    groupBuffItemsCache = false
    groupBuffItemsCacheSize = 0
    return nil
end

function Compat:ForEachGroupBuffItem(callback)
    if type(callback) ~= "function" then return end
    local items = self:GetGroupBuffItems()
    if not items then return end
    for _, item in ipairs(items) do
        if item and callback(item) then
            return true
        end
    end
end

function Compat:Invalidate(reason)
    generation = generation + 1
    table_wipe(infoCache)
    infoCacheSize = 0
    categories = nil
    categoryNamesByID = nil
    sourceCategoryMap = nil
    sourceCategoryMapGeneration = -1
    groupBuffItemsCache = nil
    groupBuffItemsCacheSize = 0
    stats.invalidations = stats.invalidations + 1
    stats.lastInvalidationReason = reason or "unknown"
end

function Compat:GetGeneration()
    return generation
end

function Compat:GetDiagnostics()
    return {
        generation = generation,
        infoCacheSize = infoCacheSize,
        hits = stats.hits,
        misses = stats.misses,
        apiCalls = stats.apiCalls,
        groupBuffApiCalls = stats.groupBuffApiCalls,
        apiErrors = stats.apiErrors,
        cooldownInfoErrors = stats.cooldownInfoErrors,
        categorySetErrors = stats.categorySetErrors,
        groupBuffErrors = stats.groupBuffErrors,
        lastAPIError = stats.lastAPIError,
        invalidations = stats.invalidations,
        hiddenCategoryRemaps = stats.hiddenCategoryRemaps,
        lastInvalidationReason = stats.lastInvalidationReason,
        hasCooldownInfoAPI = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo and true or false,
        hasCategorySetAPI = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet and true or false,
        hasGroupBuffItemsAPI = C_CooldownViewer and C_CooldownViewer.GetGroupBuffItems and true or false,
        categoryCount = #self:GetCategories(),
        groupBuffItemsCacheSize = groupBuffItemsCacheSize,
    }
end

function CDM:GetFrameCooldownID(frame)
    return Compat:GetFrameCooldownID(frame)
end

function CDM:GetCooldownInfoByID(cooldownID)
    return Compat:GetCooldownInfo(cooldownID)
end

function CDM:GetGroupBuffItems()
    return Compat:GetGroupBuffItems()
end

function CDM:ForEachGroupBuffItem(callback)
    return Compat:ForEachGroupBuffItem(callback)
end

function CDM:GetCooldownViewerCategoryName(category)
    return Compat:GetCategoryName(category)
end

function CDM:GetCooldownViewerCategoryByName(categoryName)
    return Compat:GetCategoryByName(categoryName)
end

function CDM:GetCooldownViewerSourceCategoryMap()
    return Compat:GetSourceCategoryMap()
end

function CDM:InstallCooldownItemLifecycleCallbacks(itemFrame, ownerKey, callbacks)
    return Compat:InstallCooldownItemLifecycleCallbacks(itemFrame, ownerKey, callbacks)
end

function CDM:FrameHasChargeVisualSource(frame)
    return Compat:FrameHasChargeVisualSource(frame)
end

function CDM:IsFrameUsingAuraDisplayTime(frame)
    return Compat:IsFrameUsingAuraDisplayTime(frame)
end

function CDM:GetFrameCooldownDesaturated(frame)
    return Compat:GetFrameCooldownDesaturated(frame)
end

function CDM:GetCooldownViewerFrame(viewerName)
    return Compat:GetViewerFrame(viewerName)
end

function CDM:ForEachCooldownViewerActiveFrame(viewers, callback)
    return Compat:ForEachActiveFrame(viewers, callback)
end

function CDM:CountCooldownViewerActiveFrames(viewerOrName)
    return Compat:CountActiveFrames(viewerOrName)
end

function CDM:InstallCooldownViewerAcquireCallback(viewerOrName, ownerKey, callback)
    return Compat:InstallViewerAcquireCallback(viewerOrName, ownerKey, callback)
end

function CDM:InstallCooldownViewerRefreshLayoutCallback(viewerOrName, ownerKey, callback)
    return Compat:InstallViewerRefreshLayoutCallback(viewerOrName, ownerKey, callback)
end

function CDM:InstallCooldownItemActiveStateCallback(itemFrame, ownerKey, callback)
    return Compat:InstallItemActiveStateCallback(itemFrame, ownerKey, callback)
end

function CDM:IsCooldownViewerSettingsPanelVisible()
    return Compat:IsSettingsPanelVisible()
end

function CDM:ToggleCooldownViewerSettingsPanel()
    return Compat:ToggleSettingsPanel()
end

function CDM:HookCooldownViewerSettingsVisibility(ownerKey, callback)
    return Compat:HookSettingsPanelVisibility(ownerKey, callback)
end

function CDM:RegisterCooldownViewerSettingsCallback(eventKey, callback, owner)
    return Compat:RegisterSettingsEventCallback(eventKey, callback, owner)
end

function CDM:UnregisterCooldownViewerSettingsCallback(eventKey, owner)
    return Compat:UnregisterSettingsEventCallback(eventKey, owner)
end
