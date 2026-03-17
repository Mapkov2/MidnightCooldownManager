-- ########################################################
-- MSA_Options.lua
-- Options frame, detail panel, list building, slash commands
-- ########################################################

local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local tinsert, tsort = table.insert, table.sort
local pcall, select = pcall, select
local wipe = wipe or table.wipe

-----------------------------------------------------------
-- Context menu (right-click on aura/group rows)
-----------------------------------------------------------

function MSWA_ShowListContextMenu(row)
    if not row or not row.entryType then return end
    local db = MSWA_GetDB()

    -- Modern Midnight 12.0 menu API (MenuUtil.CreateContextMenu)
    if not MenuUtil or not MenuUtil.CreateContextMenu then return end

    -- Count multi-selected auras
    local multiSel = MSWA._multiSelect or {}
    local multiCount = 0
    for _ in pairs(multiSel) do multiCount = multiCount + 1 end

    -- Multi-select batch menu: when right-clicking a multi-selected aura
    if multiCount > 1 and row.entryType == "AURA" and row.key and multiSel[row.key] then
        MenuUtil.CreateContextMenu(row, function(ownerRegion, rootDescription)
            rootDescription:CreateTitle(multiCount .. " Auras Selected")
            rootDescription:CreateButton("Export Selected (" .. multiCount .. ")", function()
                -- Collect all export strings and combine
                local parts = {}
                for key in pairs(multiSel) do
                    local s = MSWA_BuildAuraExportString(key)
                    if s then tinsert(parts, s) end
                end
                if #parts > 0 then
                    local combined = table.concat(parts, "\n---\n")
                    local ef = MSWA_GetExportFrame()
                    ef.title:SetText("Export " .. #parts .. " Auras")
                    ef.editBox:SetText(combined); ef.editBox:HighlightText(); ef:Show()
                end
            end)
            rootDescription:CreateDivider()
            rootDescription:CreateButton("|cffff4040Delete Selected (" .. multiCount .. ")|r", function()
                local keys = {}
                for key in pairs(multiSel) do tinsert(keys, key) end
                wipe(multiSel)
                for _, key in ipairs(keys) do
                    MSWA_DeleteAuraKey(key)
                end
                MSWA_RequestFullRefresh()
            end)
        end)
        return
    end

    MenuUtil.CreateContextMenu(row, function(ownerRegion, rootDescription)
        if row.entryType == "AURA" and row.key ~= nil then
            local key = row.key
            local currentName = (db.customNames and db.customNames[key]) or ""
            local displayName = MSWA_GetDisplayNameForKey(key) or "Aura"
            local defaultText = (currentName ~= "" and currentName) or displayName

            rootDescription:CreateTitle(displayName)
            rootDescription:CreateButton("Rename", function()
                C_Timer.After(0, function()
                    if MSWA_ShowInlineRenameForKey then
                        MSWA_ShowInlineRenameForKey(key, defaultText)
                    end
                end)
            end)

            -- Move Up / Move Down (only for grouped auras)
            local gid = row.groupID
            if gid and type(MSWA_MoveGroupMember) == "function" then
                local members = nil
                if type(MSWA_EnsureGroupMembers) == "function" then
                    members = MSWA_EnsureGroupMembers(gid)
                elseif db.groupMembers and type(db.groupMembers[gid]) == "table" then
                    members = db.groupMembers[gid]
                end
                local idxm, n = nil, (type(members) == "table" and #members or 0)
                if type(members) == "table" then
                    for j = 1, #members do
                        if members[j] == key then idxm = j; break end
                    end
                end
                local canUp  = idxm and idxm > 1
                local canDown = idxm and n > 1 and idxm < n

                local btnUp = rootDescription:CreateButton("Move Up", function()
                    MSWA_MoveGroupMember(gid, key, -1)
                    MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList()
                end)
                if not canUp then btnUp:SetEnabled(false) end

                local btnDown = rootDescription:CreateButton("Move Down", function()
                    MSWA_MoveGroupMember(gid, key, 1)
                    MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList()
                end)
                if not canDown then btnDown:SetEnabled(false) end
            end

            rootDescription:CreateButton("Export", function()
                MSWA_ExportAura(key)
            end)
            rootDescription:CreateDivider()
            rootDescription:CreateButton("|cffff4040Delete|r", function()
                MSWA_DeleteAuraKey(key)
                MSWA_RequestFullRefresh()
            end)

        elseif row.entryType == "GROUP" and row.groupID then
            local gid = row.groupID
            local g = db.groups and db.groups[gid]

            rootDescription:CreateTitle((g and g.name) or "Group")
            rootDescription:CreateButton("Rename", function()
                C_Timer.After(0, function()
                    if MSWA_ShowInlineRenameForGroup then
                        MSWA_ShowInlineRenameForGroup(gid, (g and g.name) or "")
                    end
                end)
            end)
            rootDescription:CreateButton("Export Group", function()
                MSWA_ExportGroup(gid)
            end)
            rootDescription:CreateDivider()
            rootDescription:CreateButton("|cffff4040Delete Group|r", function()
                MSWA_DeleteGroup(gid)
                MSWA_RequestFullRefresh()
            end)
        end
    end)
end

-----------------------------------------------------------
-- Options panel state
-----------------------------------------------------------

MSWA.optionsFrame = nil

function MSWA_RefreshOptionsList()
    local f = MSWA.optionsFrame
    if not f then return end
    if f.UpdateAuraList then
        f:UpdateAuraList()
    end
    if type(MSWA_UpdateDetailPanel) == "function" then
        MSWA_UpdateDetailPanel()
    end
end

-----------------------------------------------------------
-- Sorted tracked IDs
-----------------------------------------------------------

local tempIDList = {}

local function MSWA_BuildSortedTrackedIDs()
    local tracked = MSWA_GetTrackedSpells()
    local db      = MSWA_GetDB()

    if wipe then wipe(tempIDList)
    else for i = #tempIDList, 1, -1 do tempIDList[i] = nil end
    end

    for id, enabled in pairs(tracked) do
        if enabled and type(id) == "number" then tinsert(tempIDList, id) end
    end
    tsort(tempIDList)

    if db.trackedItems then
        local itemIDs = {}
        for itemID, enabled in pairs(db.trackedItems) do
            if enabled then tinsert(itemIDs, itemID) end
        end
        tsort(itemIDs)
        for _, itemID in ipairs(itemIDs) do tinsert(tempIDList, ("item:%d"):format(itemID)) end
    end

    local instanceKeys = {}
    for id, enabled in pairs(tracked) do
        if enabled and MSWA_IsSpellInstanceKey(id) then tinsert(instanceKeys, id) end
    end
    tsort(instanceKeys, function(a, b)
        local sa = MSWA_KeyToSpellID(a) or 0
        local sb = MSWA_KeyToSpellID(b) or 0
        if sa ~= sb then return sa < sb end
        return a < b
    end)
    for _, k in ipairs(instanceKeys) do tinsert(tempIDList, k) end

    -- Item instance keys (item:ID:N in trackedSpells)
    local itemInstanceKeys = {}
    for id, enabled in pairs(tracked) do
        if enabled and MSWA_IsItemInstanceKey(id) then tinsert(itemInstanceKeys, id) end
    end
    tsort(itemInstanceKeys, function(a, b)
        local ia = MSWA_KeyToItemID(a) or 0
        local ib = MSWA_KeyToItemID(b) or 0
        if ia ~= ib then return ia < ib end
        return a < b
    end)
    for _, k in ipairs(itemInstanceKeys) do tinsert(tempIDList, k) end

    for id, enabled in pairs(tracked) do
        if enabled and type(id) ~= "number" and not MSWA_IsSpellInstanceKey(id) and not MSWA_IsItemInstanceKey(id) then
            tinsert(tempIDList, id)
        end
    end

    return tempIDList
end

-----------------------------------------------------------
-- Build list entries (loaded vs not-loaded partitioning)
-----------------------------------------------------------

local function MSWA_BuildListEntries()
    local db = MSWA_GetDB()
    local ids = MSWA_BuildSortedTrackedIDs()
    local grouped, ungrouped, notLoaded = {}, {}, {}

    local function OrderGroupList(gid, list)
        if not list or #list <= 1 then return list end

        local members = nil
        if type(MSWA_EnsureGroupMembers) == "function" then
            members = MSWA_EnsureGroupMembers(gid)
        elseif db.groupMembers and type(db.groupMembers[gid]) == "table" then
            members = db.groupMembers[gid]
        end
        if type(members) ~= "table" or #members == 0 then return list end

        local present = {}
        for i = 1, #list do
            present[list[i]] = true
        end

        local out = {}
        for i = 1, #members do
            local k = members[i]
            if present[k] then
                tinsert(out, k)
                present[k] = nil
            end
        end

        -- Fallback: append any keys not yet in groupMembers (legacy DB)
        for i = 1, #list do
            local k = list[i]
            if present[k] then
                tinsert(out, k)
            end
        end
        return out
    end

    local function IsAuraLoadedNow(key)
        local s = nil
        if db and db.spellSettings then
            s = db.spellSettings[key] or db.spellSettings[tostring(key)]
        end
        return MSWA_ShouldLoadAura(s)
    end

    for _, key in ipairs(ids) do
        local loaded = IsAuraLoadedNow(key)
        local gid = db.auraGroups and db.auraGroups[key]
        local validGroup = (gid and db.groups and db.groups[gid]) and gid or nil
        if not loaded then
            tinsert(notLoaded, { key = key, groupID = validGroup })
        else
            if validGroup then
                grouped[validGroup] = grouped[validGroup] or {}
                tinsert(grouped[validGroup], key)
            else
                tinsert(ungrouped, key)
            end
        end
    end

    local entries = {}

    if db.groupOrder then
        for _, gid in ipairs(db.groupOrder) do
            local g = db.groups and db.groups[gid]
            if g then
                local groupEntry = { entryType = 'GROUP', groupID = gid, groupStart = true }
                tinsert(entries, groupEntry)
                local list = OrderGroupList(gid, grouped[gid])
                if list and #list > 0 then
                    for idx2, key in ipairs(list) do
                        local auraEntry = { entryType = 'AURA', key = key, groupID = gid, indent = 16 }
                        if idx2 == #list then auraEntry.groupEnd = true end
                        tinsert(entries, auraEntry)
                    end
                else
                    groupEntry.groupEnd = true
                end
            end
        end
    end

    tinsert(entries, { entryType = 'UNGROUPED' })
    for _, key in ipairs(ungrouped) do
        tinsert(entries, { entryType = 'AURA', key = key, groupID = nil, indent = 0 })
    end

    if notLoaded and #notLoaded > 0 then
        tinsert(entries, { entryType = 'NOTLOADED', groupStart = true, thickTop = true })
        for _, it in ipairs(notLoaded) do
            tinsert(entries, { entryType = 'AURA', key = it.key, groupID = it.groupID, indent = 0, notLoaded = true })
        end
    end

    return entries
end

-- ########################################################
-- V2 REWRITE STARTS HERE — MSUF/PeelDamage Midnight Theme
-- ########################################################

local W = MSWA_W
local T = W and W.Theme or {}

-----------------------------------------------------------
-- Re-declare after full definition (same as original)
-----------------------------------------------------------
MSWA_RefreshOptionsList = function()
    local f = MSWA.optionsFrame; if not f then return end
    if f.UpdateAuraList then f:UpdateAuraList() end
    if type(MSWA_UpdateDetailPanel) == "function" then MSWA_UpdateDetailPanel() end
end

-----------------------------------------------------------
-- NAV PAGES definition
-----------------------------------------------------------
local NAV_PAGES = {
    { key = "trigger", label = "Trigger" },
    { key = "look",    label = "Look" },
    { key = "text",    label = "Text" },
    { key = "glow",    label = "Glow" },
    { key = "sound",   label = "Sound" },
    { key = "alpha",   label = "Alpha" },
    { key = "load",    label = "Load" },
    { key = "pos",     label = "Position" },
}

local _pages = {}
local _navButtons = {}
local _currentPageKey = nil
local _pageHost = nil

-----------------------------------------------------------
-- Page switching (PeelDamage MenuCore pattern)
-----------------------------------------------------------
local function SwitchPage(key)
    if not _pages[key] then return end
    if W.CloseAllDropdowns then W.CloseAllDropdowns() end

    if _currentPageKey and _pages[_currentPageKey] and _pages[_currentPageKey].frame then
        _pages[_currentPageKey].frame:Hide()
    end
    for _, btn in pairs(_navButtons) do if btn.SetActive then btn:SetActive(false) end end

    if not _pages[key].frame then
        if _pages[key].build then
            _pages[key].frame = _pages[key].build(_pageHost)
            if _pages[key].frame then _pages[key].frame:SetAllPoints(_pageHost) end
        end
    end

    if _pages[key].frame then
        _pages[key].frame:Show()
        if _pages[key].frame.Refresh then pcall(_pages[key].frame.Refresh, _pages[key].frame) end
    end
    if _navButtons[key] then _navButtons[key]:SetActive(true) end
    _currentPageKey = key
end

-----------------------------------------------------------
-- Shared helpers for page builders
-----------------------------------------------------------
local function GetSel()
    local key = MSWA.selectedSpellID; if not key then return nil end
    return select(1, MSWA_GetSpellSettings(MSWA_GetDB(), key)) or nil
end
local function EnsureSel()
    local key = MSWA.selectedSpellID; if not key then return nil end
    return select(1, MSWA_GetOrCreateSpellSettings(MSWA_GetDB(), key))
end
local function GetSelKey() return MSWA.selectedSpellID end

-----------------------------------------------------------
-- Detail panel update (v2 — delegates to active page)
-----------------------------------------------------------
MSWA_UpdateDetailPanel = function()
    local f = MSWA.optionsFrame; if not f then return end
    local key = MSWA.selectedSpellID
    local gid = MSWA.selectedGroupID

    -- Group selected
    if gid and not key then
        local db = MSWA_GetDB(); local g = (db.groups or {})[gid]
        if not g then MSWA.selectedGroupID = nil
        else
            if f.groupPanel then f.groupPanel:Show(); if f.groupPanel.Sync then f.groupPanel:Sync() end end
            if _pageHost then _pageHost:Hide() end
            if f.navRail then f.navRail:Hide() end
            if f.emptyPanel then f.emptyPanel:Hide() end
            return
        end
    end

    -- Nothing selected
    if not key then
        if f.groupPanel then f.groupPanel:Hide() end
        if _pageHost then _pageHost:Hide() end
        if f.navRail then f.navRail:Hide() end
        if f.emptyPanel then f.emptyPanel:Show() end
        return
    end

    -- Aura selected
    if f.groupPanel then f.groupPanel:Hide() end
    if f.emptyPanel then f.emptyPanel:Hide() end
    if f.navRail then f.navRail:Show() end
    if _pageHost then _pageHost:Show() end

    -- Refresh current page
    if _currentPageKey and _pages[_currentPageKey] and _pages[_currentPageKey].frame then
        if _pages[_currentPageKey].frame.Refresh then
            pcall(_pages[_currentPageKey].frame.Refresh, _pages[_currentPageKey].frame)
        end
    end
end

-----------------------------------------------------------
-- Font helpers (preserved from original)
-----------------------------------------------------------
local BUILTIN_FONT_PATHS = {}
do
    local p = "Fonts\\"
    BUILTIN_FONT_PATHS["DEFAULT"] = p .. "FRIZQT__.TTF"
    BUILTIN_FONT_PATHS["FRIZQT"] = p .. "FRIZQT__.TTF"
    BUILTIN_FONT_PATHS["ARIALN"] = p .. "ARIALN.TTF"
    BUILTIN_FONT_PATHS["MORPHEUS"] = p .. "MORPHEUS.TTF"
    BUILTIN_FONT_PATHS["SKURRI"] = p .. "SKURRI.TTF"
end

function MSWA_GetFontPathFromKey(key)
    if not key or key == "DEFAULT" then return BUILTIN_FONT_PATHS["DEFAULT"] end
    if BUILTIN_FONT_PATHS[key] then return BUILTIN_FONT_PATHS[key] end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local p = LSM:Fetch("font", key, true)
        if p then return p end
    end
    return BUILTIN_FONT_PATHS["DEFAULT"]
end

function MSWA_RebuildFontChoices()
    MSWA.fontChoices = {{ key = "DEFAULT", label = "Default (Blizzard)" }}
    for k, _ in pairs(BUILTIN_FONT_PATHS) do
        if k ~= "DEFAULT" then tinsert(MSWA.fontChoices, { key = k, label = k }) end
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for _, name in ipairs(LSM:List("font") or {}) do
            if not BUILTIN_FONT_PATHS[name] then
                tinsert(MSWA.fontChoices, { key = name, label = name })
            end
        end
    end
end

local function GetTextPosLabel(pt)
    local labels = { BOTTOMRIGHT="Bottom Right", BOTTOMLEFT="Bottom Left", TOPRIGHT="Top Right", TOPLEFT="Top Left", CENTER="Center" }
    return labels[pt] or pt
end
MSWA_GetTextPosLabel = GetTextPosLabel

function MSWA_ApplyUIFont() end -- no-op for now, theme handles fonts


-- ═══════════════════════════════════════════════════════
-- PAGE BUILDERS
-- Each returns a frame with :Refresh()
-- ═══════════════════════════════════════════════════════

-----------------------------------------------------------
-- PAGE: Trigger (Aura Mode + Spell ID + Anchor)
-----------------------------------------------------------
local function BuildTriggerPage(host)
    local f = W.ScrollPage(host)
    local c = f._content

    -- Dynamic aura name title (updated in Refresh)
    local pageTitle = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pageTitle:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -10); pageTitle:SetText(""); W.SkinTitle(pageTitle)
    local pageSub = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pageSub:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -3); pageSub:SetText(""); W.SkinMuted(pageSub)

    -- ── Add ID / Drop Zone (visible for drafts + always at top) ──
    local addLabel = W.Label(c, "Add ID:", "TOPLEFT", pageSub, "BOTTOMLEFT", 0, -10)
    local addEdit = W.EditBox(c, 80, 22, true)
    addEdit:SetPoint("LEFT", addLabel, "RIGHT", 8, 0)
    local addBtn = W.Button(c, "Add", 50, 22)
    addBtn:SetPoint("LEFT", addEdit, "RIGHT", 6, 0)

    -- Drop Zone
    local dropZone = CreateFrame("Button", nil, c)
    dropZone:SetSize(320, 36)
    dropZone:SetPoint("TOPLEFT", addLabel, "BOTTOMLEFT", 0, -6)
    dropZone.bg = dropZone:CreateTexture(nil, "BACKGROUND")
    dropZone.bg:SetAllPoints(); dropZone.bg:SetColorTexture(0.06, 0.08, 0.14, 0.7)
    dropZone.border = CreateFrame("Frame", nil, dropZone, "BackdropTemplate")
    dropZone.border:SetAllPoints()
    dropZone.border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    dropZone.border:SetBackdropBorderColor(T.edgeR, T.edgeG, T.edgeB, 0.6)
    dropZone.icon = dropZone:CreateTexture(nil, "ARTWORK")
    dropZone.icon:SetSize(20, 20); dropZone.icon:SetPoint("LEFT", 8, 0)
    dropZone.icon:SetTexture("Interface\\CURSOR\\openhandglow"); dropZone.icon:SetDesaturated(true); dropZone.icon:SetVertexColor(0.6, 0.6, 0.6)
    dropZone.label = dropZone:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dropZone.label:SetPoint("LEFT", dropZone.icon, "RIGHT", 8, 0); dropZone.label:SetText("Drop Spell or Item here"); W.SkinMuted(dropZone.label)

    -- AddFromUI logic
    local function AddFromUI()
        local text = addEdit:GetText(); local id = tonumber(text); if not id then return end
        local db = MSWA_GetDB(); db.trackedItems = db.trackedItems or {}; db.trackedSpells = db.trackedSpells or {}
        local newKey
        local name = MSWA_GetSpellName and MSWA_GetSpellName(id) or nil
        if name then
            if db.trackedSpells[id] then newKey = MSWA_NewSpellInstanceKey(id); db.trackedSpells[newKey] = true
            else db.trackedSpells[id] = true; newKey = id end
        else
            if db.trackedItems[id] then newKey = MSWA_NewItemInstanceKey(id); db.trackedSpells[newKey] = true
            else db.trackedItems[id] = true; newKey = ("item:%d"):format(id) end
        end
        -- Replace draft key if one is selected
        local oldKey = MSWA.selectedSpellID
        if oldKey and MSWA_IsDraftKey(oldKey) and newKey then
            db.spellSettings = db.spellSettings or {}
            local s = db.spellSettings[oldKey]
            if s then db.spellSettings[oldKey] = nil; if not db.spellSettings[newKey] then db.spellSettings[newKey] = s end end
            if db.auraGroups and db.auraGroups[oldKey] then if not db.auraGroups[newKey] then db.auraGroups[newKey] = db.auraGroups[oldKey] end; db.auraGroups[oldKey] = nil end
            if db.customNames and db.customNames[oldKey] then if not db.customNames[newKey] then db.customNames[newKey] = db.customNames[oldKey] end; db.customNames[oldKey] = nil end
            db.trackedSpells[oldKey] = nil
        end
        MSWA.selectedSpellID = newKey; addEdit:SetText(""); MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList()
    end
    addBtn:SetScript("OnClick", AddFromUI)
    addEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); AddFromUI() end)

    -- Drop zone: receive spell/item from cursor
    local function HandleCursorDrop()
        if not GetCursorInfo then return false end
        local cursorType, id, info, extra = GetCursorInfo()
        if not cursorType then return false end
        local numericID
        if cursorType == "spell" then
            -- Resolve spell ID (extra = spellID in 12.0)
            local data
            if extra then data = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(extra) end
            if not data and id then data = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id) end
            if not data or not data.spellID then ClearCursor(); return false end
            numericID = data.spellID
        elseif cursorType == "item" then
            numericID = tonumber(id)
            if not numericID and type(info) == "string" then local p = info:match("item:(%d+)"); numericID = p and tonumber(p) end
            if not numericID then ClearCursor(); return false end
        else ClearCursor(); return false end
        addEdit:SetText(tostring(numericID)); ClearCursor(); AddFromUI(); return true
    end
    addEdit:SetScript("OnReceiveDrag", function() HandleCursorDrop() end)
    dropZone:SetScript("OnReceiveDrag", function() HandleCursorDrop() end)
    dropZone:SetScript("OnClick", function(self, button) if button == "LeftButton" and GetCursorInfo and GetCursorInfo() then HandleCursorDrop() end end)
    dropZone:RegisterForClicks("LeftButtonUp")
    dropZone:SetScript("OnEnter", function(self)
        local hasCursor = GetCursorInfo and GetCursorInfo()
        if hasCursor then self.bg:SetColorTexture(0.10, 0.20, 0.10, 0.8); self.label:SetText("|cff44ff44Release to add|r")
        else self.bg:SetColorTexture(0.08, 0.10, 0.16, 0.8) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Drag & Drop", 1, 0.82, 0)
        GameTooltip:AddLine("Drag a spell or item here to add it.", 1, 1, 1); GameTooltip:Show()
    end)
    dropZone:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.06, 0.08, 0.14, 0.7); self.label:SetText("Drop Spell or Item here"); W.SkinMuted(self.label)
        GameTooltip:Hide()
    end)

    -- ── Aura Mode Cards (2x3 grid) ──
    local modeHeader = W.SectionHeader(c, "Aura Mode", dropZone, -12)
    local MODES = {
        { key = nil,              label = "Cooldown",    desc = "Standard CD tracker" },
        { key = "AUTOBUFF",       label = "Auto Buff",   desc = "Show while buff active" },
        { key = "BUFF_THEN_CD",   label = "Buff > CD",   desc = "Buff timer, then CD" },
        { key = "REMINDER_BUFF",  label = "Reminder",    desc = "Alert when missing" },
        { key = "CHARGES",        label = "Charges",     desc = "User-defined charges" },
        { key = "BUFF_AURA",      label = "Buff Aura",   desc = "Pure buff watcher" },
    }
    local modeCards = {}
    local cardW = 155
    for i, m in ipairs(MODES) do
        local card = W.ModeCard(c, m.label, m.desc, cardW, 40, function()
            local key = GetSelKey(); if not key then return end
            local s = EnsureSel(); if not s then return end
            local oldMode = s.auraMode
            s.auraMode = m.key
            if MSWA._autoBuff then MSWA._autoBuff[key] = nil end
            if m.key == "AUTOBUFF" or m.key == "BUFF_THEN_CD" then
                if not s.autoBuffDuration then s.autoBuffDuration = 10 end
            elseif m.key == "REMINDER_BUFF" then
                if not s.autoBuffDuration then s.autoBuffDuration = 3600 end
                if not s.reminderText then s.reminderText = "MISSING!" end
                if not s.reminderTextColor then s.reminderTextColor = { r = 1, g = 0.2, b = 0.2 } end
            elseif m.key == "CHARGES" then
                if not s.chargeMax then s.chargeMax = 3 end
                if not s.chargeDuration then s.chargeDuration = 0 end
                MSWA._charges = MSWA._charges or {}
                MSWA._charges[key] = { remaining = s.chargeMax, rechargeStart = 0 }
            elseif m.key == "BUFF_AURA" then
                s.auraUnit = s.auraUnit or "player"
                if s.showWhenAbsent == nil then s.showWhenAbsent = false end
                if s.desaturateOnAbsent == nil then s.desaturateOnAbsent = true end
                if s.alphaOnAbsent == nil then s.alphaOnAbsent = 0.45 end
                if s.showStacks == nil then s.showStacks = true end
                local sid = MSWA_KeyToSpellID(key) or MSWA_KeyToItemID(key)
                if sid then s.auraSpellID = sid; if MSWA_RegisterBuffWatch then MSWA_RegisterBuffWatch(tostring(key), sid, s.auraUnit or "player") end end
            end
            if m.key ~= "BUFF_AURA" and MSWA_UnregisterBuffWatch then MSWA_UnregisterBuffWatch(tostring(key)) end
            if not m.key and MSWA._charges then MSWA._charges[key] = nil end
            MSWA_UpdateDetailPanel(); MSWA_RequestUpdateSpells()
        end)
        local col = ((i - 1) % 2)
        local row2 = math.floor((i - 1) / 2)
        card:SetPoint("TOPLEFT", modeHeader, "BOTTOMLEFT", col * (cardW + 6), -10 - row2 * 46)
        modeCards[i] = card
    end

    -- Last mode card row bottom = anchor for sub-settings
    local subAnchor = modeCards[5]

    -- Mode sub-settings (all initially hidden, shown per mode in Refresh)
    local buffDurLabel = W.Label(c, "Buff duration (sec):", "TOPLEFT", subAnchor, "BOTTOMLEFT", 0, -14)
    local buffDurEdit = W.EditBox(c, 70, 22)
    buffDurEdit:SetPoint("LEFT", buffDurLabel, "RIGHT", 8, 0)
    buffDurEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus()
        local key = GetSelKey(); if not key then return end; local s = EnsureSel()
        local v = tonumber(self:GetText()); if v and v >= 0.1 then s.autoBuffDuration = math.floor(v * 1000 + 0.5) / 1000 end
        if MSWA._autoBuff then MSWA._autoBuff[key] = nil end; MSWA_RequestUpdateSpells()
    end)

    local buffDelayLabel = W.Label(c, "Timer restart after (sec):", "TOPLEFT", buffDurLabel, "BOTTOMLEFT", 0, -6)
    local buffDelayEdit = W.EditBox(c, 70, 22)
    buffDelayEdit:SetPoint("LEFT", buffDelayLabel, "RIGHT", 8, 0)
    buffDelayEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus()
        local key = GetSelKey(); if not key then return end; local s = EnsureSel()
        local v = tonumber(self:GetText())
        if v and v >= 0 then v = math.floor(v * 1000 + 0.5) / 1000; s.autoBuffDelay = (v > 0) and v or nil else s.autoBuffDelay = nil end
        if MSWA._autoBuff then MSWA._autoBuff[key] = nil end; MSWA_RequestUpdateSpells()
    end)

    local hasteCheck = W.Checkbox(c, "Haste scaling (duration adjusts to spell haste)", nil, function(v)
        local s = EnsureSel(); if s then s.hasteScaling = v and true or nil end
        local key = GetSelKey(); if key and MSWA._autoBuff then MSWA._autoBuff[key] = nil end; MSWA_RequestUpdateSpells()
    end)
    hasteCheck:SetPoint("TOPLEFT", buffDelayLabel, "BOTTOMLEFT", 0, -8)

    local reminderTextLabel = W.Label(c, "Reminder text:", "TOPLEFT", hasteCheck, "BOTTOMLEFT", 0, -10)
    local reminderTextEdit = W.EditBox(c, 140, 22)
    reminderTextEdit:SetPoint("LEFT", reminderTextLabel, "RIGHT", 8, 0)
    reminderTextEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus()
        local s = EnsureSel(); if s then s.reminderText = (self:GetText() ~= "" and self:GetText()) or nil end
        MSWA_InvalidateIconCache()
    end)

    local baAbsentCheck = W.Checkbox(c, "Show when absent (dimmed)", nil, function(v)
        local s = EnsureSel(); if s then s.showWhenAbsent = v end; MSWA_RequestUpdateSpells()
    end)
    baAbsentCheck:SetPoint("TOPLEFT", reminderTextLabel, "BOTTOMLEFT", 0, -10)
    local baDesatCheck = W.Checkbox(c, "Desaturate icon when absent", nil, function(v)
        local s = EnsureSel(); if s then s.desaturateOnAbsent = v end; MSWA_RequestUpdateSpells()
    end)
    baDesatCheck:SetPoint("TOPLEFT", baAbsentCheck, "BOTTOMLEFT", 0, -4)
    local baStacksCheck = W.Checkbox(c, "Show stack count", nil, function(v)
        local s = EnsureSel(); if s then s.showStacks = v end; MSWA_RequestUpdateSpells()
    end)
    baStacksCheck:SetPoint("TOPLEFT", baDesatCheck, "BOTTOMLEFT", 0, -4)

    local chargeMaxLabel = W.Label(c, "Max charges:", "TOPLEFT", baStacksCheck, "BOTTOMLEFT", 0, -10)
    local chargeMaxEdit = W.EditBox(c, 50, 22, true)
    chargeMaxEdit:SetPoint("LEFT", chargeMaxLabel, "RIGHT", 8, 0)
    chargeMaxEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus()
        local s = EnsureSel(); if s then local v = tonumber(self:GetText()); if v and v >= 1 then s.chargeMax = v end end
        MSWA_RequestUpdateSpells()
    end)
    local chargeDurLabel = W.Label(c, "Recharge time:", "TOPLEFT", chargeMaxLabel, "BOTTOMLEFT", 0, -6)
    local chargeDurEdit = W.EditBox(c, 50, 22)
    chargeDurEdit:SetPoint("LEFT", chargeDurLabel, "RIGHT", 8, 0)
    chargeDurEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus()
        local s = EnsureSel(); if s then local v = tonumber(self:GetText()); if v then s.chargeDuration = v end end
        MSWA_RequestUpdateSpells()
    end)

    -- Spell/Item ID section (re-anchored dynamically in Refresh)
    local idHeader = W.SectionHeader(c, "Spell / Item ID", subAnchor, -14)
    local rekeyLabel = W.Label(c, "ID:", "TOPLEFT", idHeader, "BOTTOMLEFT", 0, -10)
    local rekeyEdit = W.EditBox(c, 80, 22, true)
    rekeyEdit:SetPoint("LEFT", rekeyLabel, "RIGHT", 8, 0)
    local rekeyBtn = W.Button(c, "Change", 70, 22, function()
        local key = GetSelKey(); if not key then return end
        local newID = tonumber(rekeyEdit:GetText()); if not newID or newID <= 0 then return end
        rekeyEdit:ClearFocus()
        local ok, result = MSWA_RekeyAura(key, newID)
        if ok then MSWA_InvalidateIconCache(); MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList()
        else MSWA_Print("Could not change ID: " .. tostring(result)) end
    end)
    rekeyBtn:SetPoint("LEFT", rekeyEdit, "RIGHT", 6, 0)
    local rekeyHint = W.MutedLabel(c, "Change spell/item ID. All settings preserved.", "TOPLEFT", rekeyLabel, "BOTTOMLEFT", 0, -4)

    -- Anchor section (re-anchored dynamically in Refresh)
    local anchorHeader = W.SectionHeader(c, "Anchor", rekeyHint, -12)
    local anchorLabel = W.Label(c, "Frame:", "TOPLEFT", anchorHeader, "BOTTOMLEFT", 0, -10)
    local anchorEdit = W.EditBox(c, 220, 22)
    anchorEdit:SetPoint("LEFT", anchorLabel, "RIGHT", 8, 0)

    local function ApplyAnchor()
        local key = GetSelKey(); if not key then return end; local s = EnsureSel()
        if s then local v = anchorEdit:GetText():gsub("^%s+",""):gsub("%s+$",""); s.anchorFrame = (v ~= "" and v) or nil end
        MSWA_RequestUpdateSpells()
    end
    anchorEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ApplyAnchor() end)
    anchorEdit:SetScript("OnEditFocusLost", ApplyAnchor)

    local presetCD = W.Button(c, "CD Manager", 100, 22, function() anchorEdit:SetText("CooldownManager"); ApplyAnchor() end)
    presetCD:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -8)
    local presetMSUF = W.Button(c, "MSUF Player", 100, 22, function() anchorEdit:SetText("MSUF_player"); ApplyAnchor() end)
    presetMSUF:SetPoint("LEFT", presetCD, "RIGHT", 6, 0)
    local presetDefault = W.Button(c, "Default", 80, 22, function()
        local s = EnsureSel(); if s then s.anchorFrame = nil; s.x = 0; s.y = 0 end; MSWA_RequestUpdateSpells(); f:Refresh()
    end)
    presetDefault:SetPoint("LEFT", presetMSUF, "RIGHT", 6, 0)

    c:SetHeight(900)

    function f:Refresh()
        local key = GetSelKey(); if not key then return end
        local db = MSWA_GetDB(); local s = GetSel() or {}
        local curMode = s.auraMode
        local isDraft = MSWA_IsDraftKey(key)

        -- Dynamic page title: aura name + mode badge
        local name = MSWA_GetDisplayNameForKey(key) or "New Aura"
        local abTag = ""
        if curMode == "AUTOBUFF" then abTag = " |cff44ddff[Auto Buff]|r"
        elseif curMode == "BUFF_THEN_CD" then abTag = " |cff44ffaa[Buff > CD]|r"
        elseif curMode == "REMINDER_BUFF" then abTag = " |cffff6644[Reminder]|r"
        elseif curMode == "CHARGES" then abTag = " |cff44ddff[Charges]|r"
        elseif curMode == "BUFF_AURA" then abTag = " |cff55bbff[Buff Aura]|r" end
        pageTitle:SetText(name .. abTag)

        -- Subtitle: spell/item ID info
        if isDraft then
            pageSub:SetText("Enter a Spell or Item ID below, or drag from Spellbook/Bags.")
        elseif MSWA_IsItemKey(key) then
            pageSub:SetText(("Item %d"):format(MSWA_KeyToItemID(key) or 0))
        elseif type(key) == "number" then
            pageSub:SetText(("Spell %d"):format(key))
        elseif MSWA_IsSpellInstanceKey(key) then
            pageSub:SetText(("Spell %d (instance)"):format(MSWA_KeyToSpellID(key) or 0))
        else
            pageSub:SetText("")
        end

        -- Show Add-ID area only for drafts (or always visible at reduced prominence)
        addLabel:SetShown(isDraft); addEdit:SetShown(isDraft); addBtn:SetShown(isDraft)
        dropZone:SetShown(isDraft)

        -- Sync mode cards
        for i, m in ipairs(MODES) do modeCards[i]:SetSelected((curMode or "nil") == (m.key or "nil")) end

        -- Dynamic anchor: modeHeader moves up when add-area hidden
        modeHeader:ClearAllPoints()
        if isDraft then
            modeHeader:SetPoint("TOPLEFT", dropZone, "BOTTOMLEFT", 0, -12)
        else
            modeHeader:SetPoint("TOPLEFT", pageSub, "BOTTOMLEFT", 0, -12)
        end

        -- Show/hide sub-settings per mode
        local hasBuffMode = (curMode == "AUTOBUFF" or curMode == "BUFF_THEN_CD" or curMode == "REMINDER_BUFF")
        local isReminder = (curMode == "REMINDER_BUFF")
        local isCharges = (curMode == "CHARGES")
        local isBuffAura = (curMode == "BUFF_AURA")

        buffDurLabel:SetShown(hasBuffMode); buffDurEdit:SetShown(hasBuffMode)
        buffDelayLabel:SetShown(hasBuffMode); buffDelayEdit:SetShown(hasBuffMode)
        hasteCheck:SetShown(hasBuffMode)
        reminderTextLabel:SetShown(isReminder); reminderTextEdit:SetShown(isReminder)
        baAbsentCheck:SetShown(isBuffAura); baDesatCheck:SetShown(isBuffAura); baStacksCheck:SetShown(isBuffAura)
        chargeMaxLabel:SetShown(isCharges); chargeMaxEdit:SetShown(isCharges)
        chargeDurLabel:SetShown(isCharges); chargeDurEdit:SetShown(isCharges)

        -- DYNAMIC RE-ANCHOR: idHeader anchors to last visible sub-element
        -- Hide rekey for drafts (drafts use the Add-ID area at top)
        idHeader:SetShown(not isDraft); rekeyLabel:SetShown(not isDraft); rekeyEdit:SetShown(not isDraft); rekeyBtn:SetShown(not isDraft); rekeyHint:SetShown(not isDraft)

        if not isDraft then
            idHeader:ClearAllPoints()
            if isCharges then
                idHeader:SetPoint("TOPLEFT", chargeDurLabel, "BOTTOMLEFT", 0, -14)
            elseif isBuffAura then
                idHeader:SetPoint("TOPLEFT", baStacksCheck, "BOTTOMLEFT", 0, -14)
            elseif isReminder then
                idHeader:SetPoint("TOPLEFT", reminderTextLabel, "BOTTOMLEFT", 0, -14)
            elseif hasBuffMode then
                idHeader:SetPoint("TOPLEFT", hasteCheck, "BOTTOMLEFT", 0, -14)
            else
                idHeader:SetPoint("TOPLEFT", subAnchor, "BOTTOMLEFT", 0, -14)
            end
        end

        -- Anchor section: re-anchor below idHeader or mode cards for drafts
        anchorHeader:ClearAllPoints()
        if isDraft then
            anchorHeader:SetPoint("TOPLEFT", subAnchor, "BOTTOMLEFT", 0, -14)
        else
            anchorHeader:SetPoint("TOPLEFT", rekeyHint, "BOTTOMLEFT", 0, -12)
        end

        -- Sync values
        if hasBuffMode then
            local dur = s.autoBuffDuration or (isReminder and 3600 or 10)
            buffDurEdit:SetText(tostring(math.floor(tonumber(dur) * 1000 + 0.5) / 1000))
            buffDelayEdit:SetText(tostring(math.floor((s.autoBuffDelay or 0) * 1000 + 0.5) / 1000))
            hasteCheck:SetChecked(s.hasteScaling and true or false)
        end
        if isReminder then reminderTextEdit:SetText(s.reminderText or "MISSING!") end
        if isBuffAura then
            baAbsentCheck:SetChecked(s.showWhenAbsent and true or false)
            baDesatCheck:SetChecked(s.desaturateOnAbsent ~= false)
            baStacksCheck:SetChecked(s.showStacks ~= false)
        end
        if isCharges then
            chargeMaxEdit:SetText(tostring(s.chargeMax or 3))
            chargeDurEdit:SetText(tostring(s.chargeDuration or 0))
        end

        -- Rekey (sync value)
        local currentID
        if MSWA_IsItemKey(key) then currentID = MSWA_KeyToItemID(key)
        elseif MSWA_IsSpellInstanceKey(key) then currentID = MSWA_KeyToSpellID(key)
        elseif type(key) == "number" then currentID = key end
        rekeyEdit:SetText(currentID and tostring(currentID) or "")

        -- Anchor
        local gid2 = MSWA_GetAuraGroup and MSWA_GetAuraGroup(key) or nil
        local a
        if gid2 then local g2 = (db.groups or {})[gid2]; a = (g2 and g2.anchorFrame) or ""
        else a = s.anchorFrame or "" end
        anchorEdit:SetText(a)
    end
    return f
end

-----------------------------------------------------------
-- PAGE: Look (Display Type + Visual Options)
-----------------------------------------------------------
local function BuildLookPage(host)
    local f = W.ScrollPage(host)
    local c = f._content
    local pageTitle = W.Title(c, "", 12, -10)
    W.MutedLabel(c, "Display type, icon/bar settings.", "TOPLEFT", c, "TOPLEFT", 12, -30)

    local dtHeader = W.SectionHeader(c, "Display Type", nil, -54)
    local dtIcon = W.ModeCard(c, "Icon", "Square button", 155, 36)
    dtIcon:SetPoint("TOPLEFT", dtHeader, "BOTTOMLEFT", 0, -8)
    local dtBar = W.ModeCard(c, "Bar", "Progress bar", 155, 36)
    dtBar:SetPoint("LEFT", dtIcon, "RIGHT", 6, 0)

    dtIcon:SetScript("OnMouseDown", function() local s = EnsureSel(); if s then s.displayType = nil end; MSWA_RequestUpdateSpells(); f:Refresh() end)
    dtBar:SetScript("OnMouseDown", function() local s = EnsureSel(); if s then s.displayType = "BAR" end; MSWA_RequestUpdateSpells(); f:Refresh() end)

    -- ── Icon settings ──
    local iconHeader = W.SectionHeader(c, "Icon Settings", dtIcon, -16)

    local ciLabel = W.Label(c, "Custom Icon ID:", "TOPLEFT", iconHeader, "BOTTOMLEFT", 0, -10)
    local ciEdit = W.EditBox(c, 70, 22, true)
    ciEdit:SetPoint("LEFT", ciLabel, "RIGHT", 8, 0)

    -- Icon preview + clear button
    local ciPreview = c:CreateTexture(nil, "ARTWORK")
    ciPreview:SetSize(22, 22); ciPreview:SetPoint("LEFT", ciEdit, "RIGHT", 6, 0)
    ciPreview:SetTexCoord(0.07, 0.93, 0.07, 0.93); ciPreview:Hide()
    local ciClear = W.Button(c, "X", 22, 22, function()
        local s = EnsureSel(); if s then s.customIconID = nil end
        ciEdit:SetText(""); ciPreview:Hide()
        MSWA_InvalidateIconCache(); MSWA_RefreshOptionsList()
    end)
    ciClear:SetPoint("LEFT", ciPreview, "RIGHT", 4, 0)

    ciEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus()
        local s = EnsureSel(); if not s then return end
        local v = tonumber(self:GetText()); s.customIconID = (v and v > 0) and v or nil
        if v and v > 0 then ciPreview:SetTexture(v); ciPreview:Show() else ciPreview:Hide() end
        MSWA_InvalidateIconCache(); MSWA_RefreshOptionsList()
    end)

    local cbGray = W.Checkbox(c, "Grayscale on cooldown", nil, function(v) local s = EnsureSel(); if s then s.grayOnCooldown = v or nil end; MSWA_RequestUpdateSpells() end)
    cbGray:SetPoint("TOPLEFT", ciLabel, "BOTTOMLEFT", 0, -8)
    local cbGrayZero = W.Checkbox(c, "Show grayed when item count is 0", nil, function(v) local s = EnsureSel(); if s then s.showOnZeroCount = v or nil end; MSWA_RequestUpdateSpells() end)
    cbGrayZero:SetPoint("TOPLEFT", cbGray, "BOTTOMLEFT", 0, -4)
    local cbSwipe = W.Checkbox(c, "Swipe darkens on loss", nil, function(v) local s = EnsureSel(); if s then s.swipeDarken = v or nil end; MSWA_RequestUpdateSpells() end)
    cbSwipe:SetPoint("TOPLEFT", cbGrayZero, "BOTTOMLEFT", 0, -4)
    local cbDecimal = W.Checkbox(c, "Show decimal (e.g. 3.7 instead of 4)", nil, function(v) local s = EnsureSel(); if s then s.showDecimal = v end; MSWA_InvalidateIconCache(); MSWA_RequestUpdateSpells() end)
    cbDecimal:SetPoint("TOPLEFT", cbSwipe, "BOTTOMLEFT", 0, -4)

    -- ── Bar settings ──
    local barHeader = W.SectionHeader(c, "Bar Settings", cbDecimal, -16)
    local barNameLabel = W.Label(c, "Name:", "TOPLEFT", barHeader, "BOTTOMLEFT", 0, -10)
    local barNameEdit = W.EditBox(c, 180, 22)
    barNameEdit:SetPoint("LEFT", barNameLabel, "RIGHT", 8, 0)
    barNameEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus()
        local key = GetSelKey(); if not key then return end; local db = MSWA_GetDB()
        db.customNames = db.customNames or {}; local v = self:GetText()
        db.customNames[key] = (v ~= "" and v) or nil; MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList()
    end)

    local barWLabel = W.Label(c, "Width:", "TOPLEFT", barNameLabel, "BOTTOMLEFT", 0, -8)
    local barWEdit = W.EditBox(c, 60, 22, true); barWEdit:SetPoint("LEFT", barWLabel, "RIGHT", 8, 0)
    local barHLabel = W.Label(c, "H:", "LEFT", barWEdit, "RIGHT", 8, 0)
    local barHEdit = W.EditBox(c, 60, 22, true); barHEdit:SetPoint("LEFT", barHLabel, "RIGHT", 4, 0)
    local function ApplyBarSize() local s = EnsureSel(); if not s then return end
        local w = tonumber(barWEdit:GetText()); if w and w > 0 then s.barWidth = w end
        local h = tonumber(barHEdit:GetText()); if h and h > 0 then s.barHeight = h end
        MSWA_RequestUpdateSpells()
    end
    barWEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ApplyBarSize() end)
    barHEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ApplyBarSize() end)

    local barFontLabel = W.Label(c, "Font size:", "TOPLEFT", barWLabel, "BOTTOMLEFT", 0, -8)
    local barFontEdit = W.EditBox(c, 50, 22, true); barFontEdit:SetPoint("LEFT", barFontLabel, "RIGHT", 8, 0)
    barFontEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus()
        local s = EnsureSel(); if s then local v = tonumber(self:GetText()); if v and v >= 6 and v <= 48 then s.barFontSize = v end end; MSWA_RequestUpdateSpells()
    end)

    local barColor = W.ColorSwatch(c, "Bar Color",
        function() local s = GetSel(); local bc = s and s.barColor or { r = 0.9, g = 0.7, b = 0 }; return { bc.r, bc.g, bc.b } end,
        function(v) local s = EnsureSel(); if s then s.barColor = { r = v[1], g = v[2], b = v[3] } end; MSWA_RequestUpdateSpells() end)
    barColor:SetPoint("TOPLEFT", barFontLabel, "BOTTOMLEFT", 0, -8)

    -- Fill Direction dropdown
    local ddFillDir = W.Dropdown(c, "Fill Direction", 200,
        function() return {
            { text = "Left -> Right", value = "LR" }, { text = "Right -> Left", value = "RL" },
            { text = "Bottom -> Top (vertical)", value = "BT" }, { text = "Top -> Bottom (vertical)", value = "TB" },
        } end,
        function() local s = GetSel(); return s and s.barFillDir or "LR" end,
        function(v) local s = EnsureSel(); if s then s.barFillDir = v end; MSWA_RequestUpdateSpells() end)
    ddFillDir:SetPoint("TOPLEFT", barColor, "BOTTOMLEFT", 0, -8)

    -- Icon Position dropdown
    local ddIconPos = W.Dropdown(c, "Icon Position", 140,
        function() return { { text = "Left", value = "LEFT" }, { text = "Right", value = "RIGHT" }, { text = "Top", value = "TOP" }, { text = "Bottom", value = "BOTTOM" } } end,
        function() local s = GetSel(); return s and s.barIconPos or "LEFT" end,
        function(v) local s = EnsureSel(); if s then s.barIconPos = v end; MSWA_RequestUpdateSpells() end)
    ddIconPos:SetPoint("TOPLEFT", ddFillDir, "BOTTOMLEFT", 0, -4)

    -- Bar Texture
    local barTexLabel = W.Label(c, "Texture:", "TOPLEFT", ddIconPos, "BOTTOMLEFT", 0, -8)
    local barTexEdit = W.EditBox(c, 200, 22)
    barTexEdit:SetPoint("LEFT", barTexLabel, "RIGHT", 8, 0)
    barTexEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus()
        local s = EnsureSel(); if s then local v = self:GetText(); s.barTexture = (v ~= "" and v) or nil end; MSWA_RequestUpdateSpells()
    end)
    W.MutedLabel(c, "SharedMedia name or path. Leave empty for default.", "TOPLEFT", barTexLabel, "BOTTOMLEFT", 0, -4)

    -- Checkboxes
    local cbBarName = W.Checkbox(c, "Show name", nil, function(v) local s = EnsureSel(); if s then s.barShowName = v end; MSWA_RequestUpdateSpells() end)
    cbBarName:SetPoint("TOPLEFT", barTexLabel, "BOTTOMLEFT", 0, -22)
    local cbBarTimer = W.Checkbox(c, "Show timer", nil, function(v) local s = EnsureSel(); if s then s.barShowTimer = v end; MSWA_RequestUpdateSpells() end)
    cbBarTimer:SetPoint("TOPLEFT", cbBarName, "BOTTOMLEFT", 0, -4)
    local cbBarSpark = W.Checkbox(c, "Show spark", nil, function(v) local s = EnsureSel(); if s then s.barShowSpark = v end; MSWA_RequestUpdateSpells() end)
    cbBarSpark:SetPoint("TOPLEFT", cbBarTimer, "BOTTOMLEFT", 0, -4)
    local cbBarIcon = W.Checkbox(c, "Show icon", nil, function(v) local s = EnsureSel(); if s then s.barShowIcon = v end; MSWA_RequestUpdateSpells() end)
    cbBarIcon:SetPoint("TOPLEFT", cbBarSpark, "BOTTOMLEFT", 0, -4)

    c:SetHeight(1000)

    function f:Refresh()
        local key = GetSelKey(); if key then pageTitle:SetText(MSWA_GetDisplayNameForKey(key) or "Aura") end
        local s = GetSel() or {}
        local isBar = (s.displayType == "BAR")
        dtIcon:SetSelected(not isBar); dtBar:SetSelected(isBar)

        -- Show/hide bar vs icon settings
        local barItems = { barHeader, barNameLabel, barNameEdit, barWLabel, barWEdit, barHLabel, barHEdit, barFontLabel, barFontEdit,
            barColor, ddFillDir, ddIconPos, barTexLabel, barTexEdit, cbBarName, cbBarTimer, cbBarSpark, cbBarIcon }
        for _, item in ipairs(barItems) do if item.SetShown then item:SetShown(isBar) elseif item.Show then if isBar then item:Show() else item:Hide() end end end

        -- Icon settings
        local cid = s.customIconID
        ciEdit:SetText((cid and cid > 0) and tostring(cid) or "")
        if cid and cid > 0 then ciPreview:SetTexture(cid); ciPreview:Show() else ciPreview:Hide() end
        cbGray:SetChecked(s.grayOnCooldown and true or false)
        cbGrayZero:SetChecked(s.showOnZeroCount and true or false)
        cbSwipe:SetChecked(s.swipeDarken and true or false)
        cbDecimal:SetChecked(s.showDecimal and true or false)

        if isBar then
            local db = MSWA_GetDB(); local cn = (db.customNames and db.customNames[key]) or ""
            barNameEdit:SetText(cn ~= "" and cn or (MSWA_GetDisplayNameForKey(key) or ""))
            barWEdit:SetText(tostring(s.barWidth or 200)); barHEdit:SetText(tostring(s.barHeight or 22))
            barFontEdit:SetText(tostring(s.barFontSize or s.textFontSize or db.textFontSize or 12))
            barColor:Refresh(); ddFillDir:Refresh(); ddIconPos:Refresh()
            barTexEdit:SetText(s.barTexture or "")
            cbBarName:SetChecked(s.barShowName ~= false); cbBarTimer:SetChecked(s.barShowTimer ~= false)
            cbBarSpark:SetChecked(s.barShowSpark ~= false); cbBarIcon:SetChecked(s.barShowIcon ~= false)
        end
    end
    return f
end

-----------------------------------------------------------
-- PAGE: Text (Timer Font + Stack Counter)
-----------------------------------------------------------
local function BuildTextPage(host)
    local f = W.ScrollPage(host)
    local c = f._content
    local pageTitle = W.Title(c, "", 12, -10)
    W.MutedLabel(c, "Timer text formatting and stack counter settings.", "TOPLEFT", c, "TOPLEFT", 12, -30)

    local h1 = W.SectionHeader(c, "Timer Text", nil, -54)

    local fontChoices = function()
        if not MSWA.fontChoices then MSWA_RebuildFontChoices() end
        local out = {}
        for _, d in ipairs(MSWA.fontChoices or {}) do tinsert(out, { text = d.label, value = d.key }) end
        return out
    end

    local ddFont = W.Dropdown(c, "Font", 200, fontChoices,
        function() local s = GetSel(); local db = MSWA_GetDB(); return (s and s.textFontKey) or (db and db.fontKey) or "DEFAULT" end,
        function(v) local key = GetSelKey(); if key then local s = EnsureSel(); if s then s.textFontKey = (v ~= "DEFAULT") and v or nil end
        else MSWA_GetDB().fontKey = (v ~= "DEFAULT") and v or "DEFAULT" end; MSWA_InvalidateIconCache() end)
    ddFont:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -10)

    local sizeLabel = W.Label(c, "Size:", "TOPLEFT", ddFont, "BOTTOMLEFT", 0, -8)
    local sizeEdit = W.EditBox(c, 50, 22, true); sizeEdit:SetPoint("LEFT", sizeLabel, "RIGHT", 8, 0)
    local sizeMinus = W.Button(c, "-", 24, 22, function()
        local s = EnsureSel() or MSWA_GetDB(); local cur = tonumber(s.textFontSize or MSWA_GetDB().textFontSize or 12)
        cur = math.max(6, cur - 1); s.textFontSize = cur; sizeEdit:SetText(tostring(cur)); MSWA_InvalidateIconCache()
    end); sizeMinus:SetPoint("LEFT", sizeEdit, "RIGHT", 4, 0)
    local sizePlus = W.Button(c, "+", 24, 22, function()
        local s = EnsureSel() or MSWA_GetDB(); local cur = tonumber(s.textFontSize or MSWA_GetDB().textFontSize or 12)
        cur = math.min(48, cur + 1); s.textFontSize = cur; sizeEdit:SetText(tostring(cur)); MSWA_InvalidateIconCache()
    end); sizePlus:SetPoint("LEFT", sizeMinus, "RIGHT", 2, 0)

    local ddPos = W.Dropdown(c, "Position", 140,
        function() local out = {}; for _, p in ipairs({"BOTTOMRIGHT","BOTTOMLEFT","TOPRIGHT","TOPLEFT","CENTER"}) do tinsert(out, {text=GetTextPosLabel(p), value=p}) end; return out end,
        function() local s = GetSel(); return (s and s.textPoint) or MSWA_GetDB().textPoint or "BOTTOMRIGHT" end,
        function(v) local key = GetSelKey(); if key then local s = EnsureSel(); s.textPoint = v else MSWA_GetDB().textPoint = v end; MSWA_InvalidateIconCache() end)
    ddPos:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -8)

    local textColor = W.ColorSwatch(c, "Text Color",
        function() local s = GetSel(); local tc = (s and s.textColor) or MSWA_GetDB().textColor or {r=1,g=1,b=1}; return {tc.r, tc.g, tc.b} end,
        function(v) local key = GetSelKey(); if key then local s = EnsureSel(); s.textColor = {r=v[1],g=v[2],b=v[3]} else local db = MSWA_GetDB(); db.textColor = {r=v[1],g=v[2],b=v[3]} end; MSWA_InvalidateIconCache() end)
    textColor:SetPoint("TOPLEFT", ddPos, "BOTTOMLEFT", 0, -8)

    -- Stacks section
    local h2 = W.SectionHeader(c, "Stack Counter", textColor, -16)

    local ddStackFont = W.Dropdown(c, "Font", 200, fontChoices,
        function() local s = GetSel(); local db = MSWA_GetDB(); return (s and s.stackFontKey) or (db and db.stackFontKey) or (db and db.fontKey) or "DEFAULT" end,
        function(v) local key = GetSelKey(); if key then local s = EnsureSel(); s.stackFontKey = (v ~= "DEFAULT") and v or nil end; MSWA_InvalidateIconCache() end)
    ddStackFont:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -10)

    local stackSizeLabel = W.Label(c, "Size:", "TOPLEFT", ddStackFont, "BOTTOMLEFT", 0, -8)
    local stackSizeEdit = W.EditBox(c, 50, 22, true); stackSizeEdit:SetPoint("LEFT", stackSizeLabel, "RIGHT", 8, 0)
    stackSizeEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus()
        local s = EnsureSel(); if s then local v = tonumber(self:GetText()); if v and v >= 6 and v <= 48 then s.stackFontSize = v end end; MSWA_InvalidateIconCache()
    end)

    local stackColor = W.ColorSwatch(c, "Color",
        function() local s = GetSel(); local sc = (s and s.stackColor) or {r=1,g=1,b=1}; return {sc.r, sc.g, sc.b} end,
        function(v) local s = EnsureSel(); if s then s.stackColor = {r=v[1],g=v[2],b=v[3]} end; MSWA_InvalidateIconCache() end)
    stackColor:SetPoint("TOPLEFT", stackSizeLabel, "BOTTOMLEFT", 0, -8)

    local cbHideStacksCD = W.Checkbox(c, "Hide stacks while on cooldown", nil, function(v) local s = EnsureSel(); if s then s.hideStacksOnCooldown = v end; MSWA_RequestUpdateSpells() end)
    cbHideStacksCD:SetPoint("TOPLEFT", stackColor, "BOTTOMLEFT", 0, -8)

    c:SetHeight(600)

    function f:Refresh()
        local key = GetSelKey(); if key then pageTitle:SetText(MSWA_GetDisplayNameForKey(key) or "Aura") end
        local s = GetSel() or {}; local db = MSWA_GetDB()
        ddFont:Refresh()
        local sz = tonumber(s.textFontSize or db.textFontSize or 12); sizeEdit:SetText(tostring(math.max(6, math.min(48, sz))))
        ddPos:Refresh(); textColor:Refresh()
        ddStackFont:Refresh()
        stackSizeEdit:SetText(tostring(tonumber(s.stackFontSize or db.stackFontSize or 12)))
        stackColor:Refresh()
        cbHideStacksCD:SetChecked(s.hideStacksOnCooldown and true or false)
    end
    return f
end

-----------------------------------------------------------
-- PAGE: Glow
-----------------------------------------------------------
local function BuildGlowPage(host)
    local f = W.ScrollPage(host)
    local c = f._content
    local avail = MSWA_IsGlowAvailable and MSWA_IsGlowAvailable() or false
    local pageTitle = W.Title(c, "", 12, -10)

    local cbEnable = W.Checkbox(c, "Enable Glow", nil, function(v)
        local s = EnsureSel(); if not s then return end
        s.glow = s.glow or {}; s.glow.enabled = v
        if not v and MSWA_StopAllGlows then MSWA_StopAllGlows() end; MSWA_RequestUpdateSpells()
    end)
    cbEnable:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -40)

    local GLOW_TYPES = { PIXEL = "Pixel Glow", AUTOCAST = "AutoCast Glow", BUTTON = "Action Button Glow", PROC = "Proc Glow" }
    local ddType = W.Dropdown(c, "Type", 180,
        function() return {{ text="Pixel Glow", value="PIXEL" },{ text="AutoCast Glow", value="AUTOCAST" },{ text="Action Button Glow", value="BUTTON" },{ text="Proc Glow", value="PROC" }} end,
        function() local s = GetSel(); return s and s.glow and s.glow.glowType or "PIXEL" end,
        function(v) local s = EnsureSel(); if s then s.glow = s.glow or {}; s.glow.glowType = v end; if MSWA_StopAllGlows then MSWA_StopAllGlows() end; MSWA_RequestUpdateSpells(); f:Refresh() end)
    ddType:SetPoint("TOPLEFT", cbEnable, "BOTTOMLEFT", 0, -8)

    local glowColor = W.ColorSwatch(c, "Color",
        function() local s = GetSel(); local gc = s and s.glow and s.glow.color or {r=0.95,g=0.95,b=0.32}; return {gc.r, gc.g, gc.b} end,
        function(v) local s = EnsureSel(); if s then s.glow = s.glow or {}; s.glow.color = s.glow.color or {}; s.glow.color.r=v[1]; s.glow.color.g=v[2]; s.glow.color.b=v[3] end; MSWA_RequestUpdateSpells() end)
    glowColor:SetPoint("TOPLEFT", ddType, "BOTTOMLEFT", 0, -8)

    local ddCond = W.Dropdown(c, "Condition", 180,
        function() return {{ text="Always", value="ALWAYS" },{ text="On Ready", value="READY" },{ text="On Cooldown", value="ON_CD" },{ text="Timer below X", value="TIMER_BELOW" },{ text="Timer above X", value="TIMER_ABOVE" }} end,
        function() local s = GetSel(); return s and s.glow and s.glow.condition or "ALWAYS" end,
        function(v) local s = EnsureSel(); if s then s.glow = s.glow or {}; s.glow.condition = v end; MSWA_RequestUpdateSpells(); f:Refresh() end)
    ddCond:SetPoint("TOPLEFT", glowColor, "BOTTOMLEFT", 0, -8)

    local condValLabel = W.Label(c, "Seconds:", "TOPLEFT", ddCond, "BOTTOMLEFT", 0, -8)
    local condValEdit = W.EditBox(c, 50, 22)
    condValEdit:SetPoint("LEFT", condValLabel, "RIGHT", 8, 0)
    condValEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus()
        local s = EnsureSel(); if s then s.glow = s.glow or {}; local v = tonumber(self:GetText()); if v and v >= 0 then s.glow.conditionValue = v end end; MSWA_RequestUpdateSpells()
    end)

    local h2 = W.SectionHeader(c, "Fine-Tuning", condValLabel, -14)
    local linesLabel = W.Label(c, "Lines:", "TOPLEFT", h2, "BOTTOMLEFT", 0, -10)
    local linesEdit = W.EditBox(c, 40, 22, true); linesEdit:SetPoint("LEFT", linesLabel, "RIGHT", 8, 0)
    local freqLabel = W.Label(c, "Speed:", "LEFT", linesEdit, "RIGHT", 12, 0)
    local freqEdit = W.EditBox(c, 50, 22); freqEdit:SetPoint("LEFT", freqLabel, "RIGHT", 8, 0)
    local thickLabel = W.Label(c, "Thickness:", "TOPLEFT", linesLabel, "BOTTOMLEFT", 0, -8)
    local thickEdit = W.EditBox(c, 50, 22); thickEdit:SetPoint("LEFT", thickLabel, "RIGHT", 8, 0)

    local function ApplyGlowDetails()
        local s = EnsureSel(); if not s then return end; s.glow = s.glow or {}
        local l = tonumber(linesEdit:GetText()); if l and l >= 1 and l <= 32 then s.glow.lines = l end
        local fr = tonumber(freqEdit:GetText()); if fr then s.glow.frequency = fr end
        local th = tonumber(thickEdit:GetText()); if th and th > 0 then s.glow.thickness = th; s.glow.scale = th end
        if MSWA_StopAllGlows then MSWA_StopAllGlows() end; MSWA_RequestUpdateSpells()
    end
    linesEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ApplyGlowDetails() end)
    freqEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ApplyGlowDetails() end)
    thickEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ApplyGlowDetails() end)

    c:SetHeight(500)

    function f:Refresh()
        local key = GetSelKey(); if key then pageTitle:SetText(MSWA_GetDisplayNameForKey(key) or "Aura") end
        local s = GetSel() or {}; local gs = s.glow or {}
        cbEnable:SetChecked(gs.enabled and true or false)
        ddType:Refresh(); glowColor:Refresh(); ddCond:Refresh()
        local cond = gs.condition or "ALWAYS"
        local showVal = (cond == "TIMER_BELOW" or cond == "TIMER_ABOVE")
        condValLabel:SetShown(showVal); condValEdit:SetShown(showVal)
        if showVal then condValEdit:SetText(tostring(gs.conditionValue or 5)) end
        linesEdit:SetText(tostring(gs.lines or 8))
        freqEdit:SetText(tostring(gs.frequency or 0.25))
        thickEdit:SetText(tostring(gs.thickness or gs.scale or 2))
    end
    return f
end

-----------------------------------------------------------
-- PAGE: Sound
-----------------------------------------------------------
local function BuildSoundPage(host)
    local f = W.ScrollPage(host)
    local c = f._content
    local pageTitle = W.Title(c, "", 12, -10)
    W.MutedLabel(c, "Play sounds when cooldowns start or become ready.", "TOPLEFT", c, "TOPLEFT", 12, -30)

    local function SoundOpts()
        local out = {{ text = "-- None --", value = "NONE" }}
        if MSWA_GetSoundChoices then for _, e in ipairs(MSWA_GetSoundChoices()) do tinsert(out, { text = e.label, value = e.key }) end end
        return out
    end

    local ddStart = W.Dropdown(c, "On Cooldown Start", 240, SoundOpts,
        function() local s = GetSel(); return s and s.soundOnStart or "NONE" end,
        function(v) local s = EnsureSel(); if s then s.soundOnStart = v end end)
    ddStart:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -58)

    local prevStart = W.Button(c, ">", 28, 22, function()
        local s = GetSel(); if s and s.soundOnStart and s.soundOnStart ~= "NONE" and MSWA_PlaySoundByKey then MSWA_PlaySoundByKey(s.soundOnStart, s.soundChannel or "Master") end
    end); prevStart:SetPoint("LEFT", ddStart._btn, "RIGHT", 6, 0)

    local ddReady = W.Dropdown(c, "On Ready", 240, SoundOpts,
        function() local s = GetSel(); return s and s.soundOnReady or "NONE" end,
        function(v) local s = EnsureSel(); if s then s.soundOnReady = v end end)
    ddReady:SetPoint("TOPLEFT", ddStart, "BOTTOMLEFT", 0, -8)

    local prevReady = W.Button(c, ">", 28, 22, function()
        local s = GetSel(); if s and s.soundOnReady and s.soundOnReady ~= "NONE" and MSWA_PlaySoundByKey then MSWA_PlaySoundByKey(s.soundOnReady, s.soundChannel or "Master") end
    end); prevReady:SetPoint("LEFT", ddReady._btn, "RIGHT", 6, 0)

    local ddCh = W.Dropdown(c, "Audio Channel", 160,
        function() return {{ text="Master",value="Master" },{ text="SFX",value="SFX" },{ text="Music",value="Music" },{ text="Ambience",value="Ambience" },{ text="Dialog",value="Dialog" }} end,
        function() local s = GetSel(); return s and s.soundChannel or "Master" end,
        function(v) local s = EnsureSel(); if s then s.soundChannel = v end end)
    ddCh:SetPoint("TOPLEFT", ddReady, "BOTTOMLEFT", 0, -8)

    c:SetHeight(280)
    function f:Refresh() local key = GetSelKey(); if key then pageTitle:SetText(MSWA_GetDisplayNameForKey(key) or "Aura") end; ddStart:Refresh(); ddReady:Refresh(); ddCh:Refresh() end
    return f
end

-----------------------------------------------------------
-- PAGE: Alpha (4 sliders)
-----------------------------------------------------------
local function BuildAlphaPage(host)
    local f = W.ScrollPage(host)
    local c = f._content
    local pageTitle = W.Title(c, "", 12, -10)
    W.MutedLabel(c, "Control icon opacity per state.", "TOPLEFT", c, "TOPLEFT", 12, -30)

    local function MakeAlphaSlider(label, field, anchor, yOff)
        local sl = W.Slider(c, label, 0, 100, 1,
            function() local s = GetSel(); return math.floor(((s and tonumber(s[field])) or 1.0) * 100 + 0.5) end,
            function(v) local s = EnsureSel(); if s then s[field] = v / 100; MSWA_RequestUpdateSpells() end end)
        sl:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff or -8)
        return sl
    end

    local h1 = W.SectionHeader(c, "State Alpha", nil, -54)
    local slCD = MakeAlphaSlider("On Cooldown", "cdAlpha", h1, -12)
    local slOOC = MakeAlphaSlider("Out of Combat", "oocAlpha", slCD)
    local slCombat = MakeAlphaSlider("In Combat", "combatAlpha", slOOC)
    local slReady = MakeAlphaSlider("Ready", "readyAlpha", slCombat)

    c:SetHeight(340)
    function f:Refresh() local key = GetSelKey(); if key then pageTitle:SetText(MSWA_GetDisplayNameForKey(key) or "Aura") end; slCD:Refresh(); slOOC:Refresh(); slCombat:Refresh(); slReady:Refresh() end
    return f
end

-----------------------------------------------------------
-- PAGE: Load (Load Conditions)
-----------------------------------------------------------
local function BuildLoadPage(host)
    local f = W.ScrollPage(host)
    local c = f._content
    local pageTitle = W.Title(c, "", 12, -10)
    W.MutedLabel(c, "Control when this aura is active.", "TOPLEFT", c, "TOPLEFT", 12, -30)

    local cbNever = W.Checkbox(c, "Never (disable)", nil, function(v)
        local s = EnsureSel(); if s then s.loadNever = v or nil end; MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList()
    end)
    cbNever:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -58)

    local combatLabel = W.Label(c, "Combat:", "TOPLEFT", cbNever, "BOTTOMLEFT", 0, -10)
    local combatBtn = W.Button(c, "Always", 100, 22, function()
        local s = EnsureSel(); if not s or s.loadNever then return end
        local cur = s.loadCombatMode
        local next = cur == nil and "IN" or (cur == "IN" and "OUT" or nil)
        s.loadCombatMode = next; MSWA_RequestUpdateSpells(); f:Refresh()
    end)
    combatBtn:SetPoint("LEFT", combatLabel, "RIGHT", 8, 0)

    local encLabel = W.Label(c, "Encounter:", "TOPLEFT", combatLabel, "BOTTOMLEFT", 0, -8)
    local encBtn = W.Button(c, "Always", 100, 22, function()
        local s = EnsureSel(); if not s or s.loadNever then return end
        local cur = s.loadEncounterMode
        local next = cur == nil and "IN" or (cur == "IN" and "OUT" or nil)
        s.loadEncounterMode = next; MSWA_RequestUpdateSpells(); f:Refresh()
    end)
    encBtn:SetPoint("LEFT", encLabel, "RIGHT", 8, 0)

    local charLabel = W.Label(c, "Character:", "TOPLEFT", encLabel, "BOTTOMLEFT", 0, -8)
    local charEdit = W.EditBox(c, 160, 22)
    charEdit:SetPoint("LEFT", charLabel, "RIGHT", 8, 0)
    charEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus()
        local s = EnsureSel(); if not s or s.loadNever then return end
        local v = self:GetText():gsub("^%s+",""):gsub("%s+$","")
        if v == "" then s.loadCharName = nil
        else if not v:find("%-") then local realm = MSWA_GetPlayerRealm and MSWA_GetPlayerRealm() or ""; if realm ~= "" then v = v .. "-" .. realm end end
            s.loadCharName = v end
        MSWA_RequestUpdateSpells()
    end)

    local meBtn = W.Button(c, "Me", 40, 22, function()
        local s = EnsureSel(); if not s or s.loadNever then return end
        local name = MSWA_GetPlayerName and MSWA_GetPlayerName() or ""
        local realm = MSWA_GetPlayerRealm and MSWA_GetPlayerRealm() or ""
        local full = realm ~= "" and (name .. "-" .. realm) or name
        s.loadCharName = full; MSWA_RequestUpdateSpells(); f:Refresh()
    end)
    meBtn:SetPoint("LEFT", charEdit, "RIGHT", 6, 0)

    c:SetHeight(320)

    function f:Refresh()
        local key = GetSelKey(); if key then pageTitle:SetText(MSWA_GetDisplayNameForKey(key) or "Aura") end
        local s = GetSel() or {}
        cbNever:SetChecked(s.loadNever and true or false)
        local cm = s.loadCombatMode
        local cmText = cm == "IN" and "In Combat" or (cm == "OUT" and "Out of Combat" or "Always")
        combatBtn:SetText(cmText)
        local em = s.loadEncounterMode
        local emText = em == "IN" and "In Encounter" or (em == "OUT" and "No Encounter" or "Always")
        encBtn:SetText(emText)
        charEdit:SetText(s.loadCharName or "")
    end
    return f
end

-----------------------------------------------------------
-- PAGE: Position (X/Y/W/H)
-----------------------------------------------------------
local function BuildPositionPage(host)
    local f = W.ScrollPage(host)
    local c = f._content
    local pageTitle = W.Title(c, "", 12, -10)
    W.MutedLabel(c, "Fine-tune aura placement and dimensions.", "TOPLEFT", c, "TOPLEFT", 12, -30)

    local h1 = W.SectionHeader(c, "Coordinates", nil, -54)

    local function MakePosRow(lbl, anchor, yOff, field, default)
        local l = W.Label(c, lbl, "TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff or -8)
        local eb = W.EditBox(c, 70, 22); eb:SetPoint("LEFT", l, "RIGHT", 8, 0)
        local minus = W.Button(c, "-", 24, 22, function()
            local s = EnsureSel(); if s then s[field] = (s[field] or default or 0) - 1 end
            MSWA_RequestUpdateSpells(); f:Refresh()
        end); minus:SetPoint("LEFT", eb, "RIGHT", 4, 0)
        local plus = W.Button(c, "+", 24, 22, function()
            local s = EnsureSel(); if s then s[field] = (s[field] or default or 0) + 1 end
            MSWA_RequestUpdateSpells(); f:Refresh()
        end); plus:SetPoint("LEFT", minus, "RIGHT", 2, 0)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus()
            local s = EnsureSel(); if s then local v = tonumber(self:GetText()); if v then s[field] = v end end; MSWA_RequestUpdateSpells()
        end)
        return l, eb
    end

    local lX, ebX = MakePosRow("X:", h1, -10, "x", 0)
    local lY, ebY = MakePosRow("Y:", lX, -8, "y", 0)
    local lW, ebW = MakePosRow("Width:", lY, -8, "width", MSWA.ICON_SIZE)
    local lH, ebH = MakePosRow("Height:", lW, -8, "height", MSWA.ICON_SIZE)

    local btnReset = W.Button(c, "Reset Position", 120, 24, function()
        local s = EnsureSel(); if s then s.x = 0; s.y = 0 end; MSWA_RequestUpdateSpells(); f:Refresh()
    end); btnReset:SetPoint("TOPLEFT", lH, "BOTTOMLEFT", 0, -14)

    local btnDefault = W.Button(c, "Default Size", 120, 24, function()
        local s = EnsureSel(); if s then s.width = nil; s.height = nil end; MSWA_RequestUpdateSpells(); f:Refresh()
    end); btnDefault:SetPoint("LEFT", btnReset, "RIGHT", 8, 0)

    c:SetHeight(320)

    function f:Refresh()
        local key = GetSelKey(); if key then pageTitle:SetText(MSWA_GetDisplayNameForKey(key) or "Aura") end
        local s = GetSel() or {}
        ebX:SetText(("%d"):format(s.x or 0)); ebY:SetText(("%d"):format(s.y or 0))
        ebW:SetText(("%d"):format(s.width or MSWA.ICON_SIZE)); ebH:SetText(("%d"):format(s.height or MSWA.ICON_SIZE))
    end
    return f
end

-- Register all pages
_pages = {
    trigger = { build = BuildTriggerPage, frame = nil },
    look    = { build = BuildLookPage,    frame = nil },
    text    = { build = BuildTextPage,    frame = nil },
    glow    = { build = BuildGlowPage,    frame = nil },
    sound   = { build = BuildSoundPage,   frame = nil },
    alpha   = { build = BuildAlphaPage,   frame = nil },
    load    = { build = BuildLoadPage,    frame = nil },
    pos     = { build = BuildPositionPage,frame = nil },
}

-- ═══════════════════════════════════════════════════════
-- CreateOptionsFrame (v2 — MSUF/PeelDamage Midnight)
-- ═══════════════════════════════════════════════════════

local NAV_WIDTH = 100
local NAV_BTN_H = 24
local NAV_BTN_GAP = 3

local function MSWA_CreateOptionsFrame()
    if MSWA.optionsFrame then return MSWA.optionsFrame end

    local f = CreateFrame("Frame", "MidnightSimpleAurasOptions", UIParent, "BackdropTemplate")
    f:SetSize(940, 560); f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
    f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    W.ApplyBackdrop(f, 0.97)

    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(760, 440, 1200, 800)
    elseif f.SetMinResize then f:SetMinResize(760, 440); f:SetMaxResize(1200, 800) end

    -- Resize grip
    local grip = CreateFrame("Frame", nil, f)
    grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -4, 4); grip:EnableMouse(true)
    grip:SetFrameLevel(f:GetFrameLevel() + 10)
    local gt = grip:CreateTexture(nil, "OVERLAY"); gt:SetAllPoints()
    gt:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT"); gt:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); gt:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up") end)
    grip:SetScript("OnEnter", function() gt:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight") end)
    grip:SetScript("OnLeave", function() gt:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up") end)

    -- ESC close
    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "MidnightSimpleAurasOptions") end

    -- Title + Version
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 12, -10); f.title:SetText("Midnight Simple Auras"); W.SkinTitle(f.title)
    local tocVer = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("MidnightSimpleAuras", "Version") or "?"
    f.versionText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.versionText:SetPoint("LEFT", f.title, "RIGHT", 8, -1); f.versionText:SetText("v" .. tocVer); W.SkinMuted(f.versionText)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2); closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ── Content area ──
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 8, -34); content:SetPoint("BOTTOMRIGHT", -8, 40)

    -- ════════════════════════════════════════════════════
    -- LEFT SIDEBAR: Aura list
    -- ════════════════════════════════════════════════════
    local listPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    listPanel:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
    listPanel:SetWidth(280)
    W.ApplyBackdrop(listPanel, 0.22)
    f.listPanel = listPanel

    -- Top buttons
    f.btnNew = W.Button(listPanel, "New", 60, 22); f.btnNew:SetPoint("TOPLEFT", 6, -6)
    f.btnImport = W.Button(listPanel, "Import", 60, 22); f.btnImport:SetPoint("LEFT", f.btnNew, "RIGHT", 4, 0)
    f.btnExport = W.Button(listPanel, "Export", 60, 22); f.btnExport:SetPoint("LEFT", f.btnImport, "RIGHT", 4, 0)
    f.btnGroup = W.Button(listPanel, "Group", 60, 22); f.btnGroup:SetPoint("LEFT", f.btnExport, "RIGHT", 4, 0)

    -- Aura list scroll
    local rowHeight = 24
    local MAX_VISIBLE_ROWS = 28
    f.rowHeight = rowHeight

    function f:GetVisibleRows()
        local h = self.listPanel and self.listPanel:GetHeight() or 400
        return math.max(4, math.floor((h - 56) / rowHeight))
    end

    local scrollFrame = CreateFrame("ScrollFrame", "MSWA_AuraListScrollFrame", listPanel, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 0, -36)
    scrollFrame:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -2, 6)
    scrollFrame:EnableMouseWheel(true)
    f.scrollFrame = scrollFrame

    -- Inline rename EditBox
    local inlineEdit = CreateFrame("EditBox", "MSWA_InlineRenameEdit", listPanel, "InputBoxTemplate")
    inlineEdit:SetSize(200, 20); inlineEdit:SetAutoFocus(false); inlineEdit:SetMaxLetters(64)
    inlineEdit:SetFrameStrata("DIALOG"); inlineEdit:Hide()
    inlineEdit._renameKey = nil; inlineEdit._renameGroupID = nil
    f.inlineEdit = inlineEdit

    local function InlineRename_Commit(self)
        local txt = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local db = MSWA_GetDB()
        if self._renameGroupID then
            local g = db.groups and db.groups[self._renameGroupID]
            if g and txt ~= "" then g.name = txt end
        elseif self._renameKey ~= nil then
            db.customNames = db.customNames or {}
            db.customNames[self._renameKey] = (txt ~= "" and txt) or nil
        end
        self._renameKey = nil; self._renameGroupID = nil; self:Hide(); self:ClearFocus()
        MSWA_RefreshOptionsList(); MSWA_RequestUpdateSpells()
    end
    local function InlineRename_Cancel(self) self._renameKey = nil; self._renameGroupID = nil; self:Hide(); self:ClearFocus() end
    inlineEdit:SetScript("OnEnterPressed", InlineRename_Commit)
    inlineEdit:SetScript("OnEscapePressed", InlineRename_Cancel)
    inlineEdit:SetScript("OnEditFocusLost", InlineRename_Cancel)

    function MSWA_ShowInlineRenameForKey(key, defaultText)
        for i = 1, MAX_VISIBLE_ROWS do local row = f.rows[i]; if row and row:IsShown() and row.key == key then
            inlineEdit._renameKey = key; inlineEdit._renameGroupID = nil
            inlineEdit:ClearAllPoints(); inlineEdit:SetPoint("LEFT", row.icon, "RIGHT", 4 + (row.indent or 0), 0)
            inlineEdit:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            inlineEdit:SetText(defaultText or ""); inlineEdit:Show(); inlineEdit:SetFocus(); inlineEdit:HighlightText()
            return
        end end
    end
    function MSWA_ShowInlineRenameForGroup(gid, defaultText)
        for i = 1, MAX_VISIBLE_ROWS do local row = f.rows[i]; if row and row:IsShown() and row.entryType == "GROUP" and row.groupID == gid then
            inlineEdit._renameKey = nil; inlineEdit._renameGroupID = gid
            inlineEdit:ClearAllPoints(); inlineEdit:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
            inlineEdit:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            inlineEdit:SetText(defaultText or ""); inlineEdit:Show(); inlineEdit:SetFocus(); inlineEdit:HighlightText()
            return
        end end
    end

    -- Multi-select state
    MSWA._multiSelect = MSWA._multiSelect or {}
    MSWA._lastClickedKey = nil

    -- Create list rows
    f.rows = {}
    for i = 1, MAX_VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, listPanel)
        row:SetSize(270, rowHeight); row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 4, -((i - 1) * rowHeight))
        row:EnableMouse(true); row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(20, 20); row.icon:SetPoint("LEFT", 2, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0); row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text:SetJustifyH("LEFT"); W.SkinText(row.text)

        row.selectedTex = row:CreateTexture(nil, "BACKGROUND")
        row.selectedTex:SetAllPoints(); row.selectedTex:SetColorTexture(T.accentR, T.accentG, T.accentB, 0.35); row.selectedTex:Hide()
        row.multiSelTex = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row.multiSelTex:SetAllPoints(); row.multiSelTex:SetColorTexture(0, 0.8, 0.8, 0.15); row.multiSelTex:Hide()

        row.dragInsertTop = row:CreateTexture(nil, "OVERLAY"); row.dragInsertTop:SetHeight(2)
        row.dragInsertTop:SetPoint("TOPLEFT", 0, 1); row.dragInsertTop:SetPoint("TOPRIGHT", 0, 1)
        row.dragInsertTop:SetColorTexture(T.accentR, T.accentG, T.accentB, 0.9); row.dragInsertTop:Hide()
        row.dragInsertBot = row:CreateTexture(nil, "OVERLAY"); row.dragInsertBot:SetHeight(2)
        row.dragInsertBot:SetPoint("BOTTOMLEFT", 0, -1); row.dragInsertBot:SetPoint("BOTTOMRIGHT", 0, -1)
        row.dragInsertBot:SetColorTexture(T.accentR, T.accentG, T.accentB, 0.9); row.dragInsertBot:Hide()

        row.sepTop = row:CreateTexture(nil, "ARTWORK"); row.sepTop:SetHeight(1)
        row.sepTop:SetPoint("TOPLEFT", 0, 0); row.sepTop:SetPoint("TOPRIGHT", 0, 0)
        row.sepTop:SetColorTexture(T.edgeR, T.edgeG, T.edgeB, 0.4); row.sepTop:Hide()
        row.sepBottom = row:CreateTexture(nil, "ARTWORK"); row.sepBottom:SetHeight(1)
        row.sepBottom:SetPoint("BOTTOMLEFT", 0, 0); row.sepBottom:SetPoint("BOTTOMRIGHT", 0, 0)
        row.sepBottom:SetColorTexture(T.edgeR, T.edgeG, T.edgeB, 0.4); row.sepBottom:Hide()

        row.entryType = nil; row.groupID = nil; row.key = nil; row.indent = 0

        -- Hover
        row:SetScript("OnEnter", function(self)
            if not self.selectedTex:IsShown() then
                self.selectedTex:SetColorTexture(1, 1, 1, 0.06); self.selectedTex:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            local isSelected = (MSWA.selectedSpellID ~= nil and MSWA.selectedSpellID == self.key) or (MSWA.selectedGroupID and MSWA.selectedGroupID == self.groupID and self.entryType == "GROUP")
            if not isSelected then self.selectedTex:Hide() end
        end)

        -- Click
        row:SetScript("OnClick", function(self, button)
            if button == "RightButton" then MSWA_ShowListContextMenu(self); return end
            if self.entryType == "AURA" and self.key ~= nil then
                -- Shift-click: range select
                if IsShiftKeyDown() and MSWA._lastClickedKey then
                    -- multi-select range (simplified)
                    MSWA._multiSelect[self.key] = true
                elseif IsControlKeyDown() then
                    -- Ctrl: toggle multi-select
                    local ms = MSWA._multiSelect
                    ms[self.key] = not ms[self.key] or nil
                else
                    -- Normal click
                    wipe(MSWA._multiSelect)
                    MSWA.selectedSpellID = self.key; MSWA.selectedGroupID = self.groupID
                    if not _currentPageKey then SwitchPage("trigger") end
                end
                MSWA._lastClickedKey = self.key
                f:UpdateAuraList()
            elseif self.entryType == "GROUP" and self.groupID then
                wipe(MSWA._multiSelect)
                MSWA.selectedSpellID = nil; MSWA.selectedGroupID = self.groupID
                f:UpdateAuraList()
            end
        end)

        f.rows[i] = row
    end

    -- Helper for row text layout
    function MSWA_LayoutListRowText(row)
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 4 + (row.indent or 0), 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    end

    -- UpdateAuraList
    function f:UpdateAuraList()
        if f.inlineEdit and f.inlineEdit:IsShown() then
            f.inlineEdit._renameKey = nil; f.inlineEdit._renameGroupID = nil; f.inlineEdit:Hide(); f.inlineEdit:ClearFocus()
        end
        local db = MSWA_GetDB()
        local entries = MSWA_BuildListEntries()
        f._lastEntries = entries
        local selectedKey = MSWA.selectedSpellID
        local selectedGroup = MSWA.selectedGroupID
        local multiSel = MSWA._multiSelect
        local total = #entries
        local visibleRows = self:GetVisibleRows()
        FauxScrollFrame_Update(scrollFrame, total, visibleRows, rowHeight)
        local offset = FauxScrollFrame_GetOffset(scrollFrame) or 0

        for i = 1, visibleRows do
            local row = self.rows[i]; local idx = offset + i; local entry = entries[idx]
            if entry then
                row.entryType = entry.entryType; row.groupID = entry.groupID; row.key = entry.key; row.indent = entry.indent or 0
                row:Show(); row.selectedTex:Hide(); row.multiSelTex:Hide(); row.dragInsertTop:Hide(); row.dragInsertBot:Hide()
                if row.sepTop then row.sepTop:Hide() end; if row.sepBottom then row.sepBottom:Hide() end
                row.icon:SetTexture(nil); row:SetAlpha(1)
                if row.icon.SetDesaturated then row.icon:SetDesaturated(false) end
                MSWA_LayoutListRowText(row)
                if entry.groupStart and row.sepTop then row.sepTop:SetHeight(entry.thickTop and 2 or 1); row.sepTop:Show() end
                if entry.groupEnd and row.sepBottom then row.sepBottom:SetHeight(entry.thickBottom and 2 or 1); row.sepBottom:Show() end

                if entry.entryType == "GROUP" then
                    local g = db.groups and db.groups[entry.groupID] or nil
                    row.text:SetText(g and g.name or "Group"); row.icon:SetTexture(nil)
                    if selectedGroup and selectedGroup == entry.groupID then row.selectedTex:SetColorTexture(T.accentR, T.accentG, T.accentB, 0.35); row.selectedTex:Show() end
                elseif entry.entryType == "UNGROUPED" then
                    row.text:SetText("|cff888888Ungrouped|r"); row.icon:SetTexture(nil)
                elseif entry.entryType == "NOTLOADED" then
                    row.text:SetText("|cff666666Not Loaded|r"); row.icon:SetTexture(nil)
                else
                    local key = entry.key
                    local icon = MSWA_GetIconForKey(key)
                    local name = MSWA_GetDisplayNameForKey(key)
                    local abPrefix = ""
                    if MSWA_IsAutoBuff and MSWA_IsAutoBuff(key) then abPrefix = "|cff44ddff[AB]|r " end
                    local displayName = abPrefix .. (name or "Unknown")
                    if entry.notLoaded then
                        local suffix = ""
                        if entry.groupID then local g2 = db.groups and db.groups[entry.groupID]; if g2 and g2.name then suffix = " |cff666666(" .. g2.name .. ")|r" end end
                        row.text:SetText("|cff888888" .. displayName .. "|r" .. suffix); row:SetAlpha(0.55)
                        if row.icon.SetDesaturated then row.icon:SetDesaturated(true) end
                    else
                        row.text:SetText(displayName); row:SetAlpha(1)
                    end
                    row.icon:SetTexture(icon)
                    if selectedKey ~= nil and selectedKey == key then row.selectedTex:SetColorTexture(T.accentR, T.accentG, T.accentB, 0.35); row.selectedTex:Show() end
                    if key and multiSel[key] then row.multiSelTex:Show() end
                end
            else
                row.entryType = nil; row.groupID = nil; row.key = nil; row.indent = 0
                row.icon:SetTexture(nil); row.text:SetText(""); row.selectedTex:Hide(); row.multiSelTex:Hide()
                row.dragInsertTop:Hide(); row.dragInsertBot:Hide()
                if row.sepTop then row.sepTop:Hide() end; if row.sepBottom then row.sepBottom:Hide() end
                row:Hide()
            end
        end
        for i = visibleRows + 1, MAX_VISIBLE_ROWS do
            local row = self.rows[i]; if row then
                row.entryType = nil; row.groupID = nil; row.key = nil; row.icon:SetTexture(nil); row.text:SetText("")
                row.selectedTex:Hide(); row.multiSelTex:Hide(); row.dragInsertTop:Hide(); row.dragInsertBot:Hide()
                if row.sepTop then row.sepTop:Hide() end; if row.sepBottom then row.sepBottom:Hide() end; row:Hide()
            end
        end
        MSWA_UpdateDetailPanel()
    end

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, rowHeight, function() f:UpdateAuraList() end) end)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        FauxScrollFrame_OnVerticalScroll(self, current - (delta * rowHeight * 3), rowHeight, function() f:UpdateAuraList() end)
    end)

    -- ════════════════════════════════════════════════════
    -- NAV RAIL (vertical tab icons)
    -- ════════════════════════════════════════════════════
    local navRail = CreateFrame("Frame", nil, content, "BackdropTemplate")
    navRail:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 6, 0)
    navRail:SetPoint("BOTTOMLEFT", listPanel, "BOTTOMRIGHT", 6, 0)
    navRail:SetWidth(NAV_WIDTH)
    W.ApplyBackdrop(navRail, 0.22)
    f.navRail = navRail

    local yPos = -6
    for _, nav in ipairs(NAV_PAGES) do
        local btn = W.NavButton(navRail, nav.label, NAV_WIDTH - 10, NAV_BTN_H, false, function() SwitchPage(nav.key) end)
        btn:SetPoint("TOPLEFT", navRail, "TOPLEFT", 5, yPos)
        _navButtons[nav.key] = btn
        yPos = yPos - NAV_BTN_H - NAV_BTN_GAP
    end

    -- ════════════════════════════════════════════════════
    -- PAGE HOST (right panel)
    -- ════════════════════════════════════════════════════
    _pageHost = CreateFrame("Frame", nil, content)
    _pageHost:SetPoint("TOPLEFT", navRail, "TOPRIGHT", 6, 0)
    _pageHost:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

    -- rightTitle removed — aura name is shown inside each page header via Refresh()

    -- Empty panel
    f.emptyPanel = CreateFrame("Frame", nil, content)
    f.emptyPanel:SetPoint("TOPLEFT", navRail, "TOPRIGHT", 6, 0)
    f.emptyPanel:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    W.ApplyBackdrop(f.emptyPanel, 0.25)
    local emptyText = f.emptyPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyText:SetPoint("CENTER", 0, 0); emptyText:SetText("Select an aura from the list to edit."); W.SkinMuted(emptyText)

    -- Group panel (shown when group header selected)
    f.groupPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    f.groupPanel:SetPoint("TOPLEFT", navRail, "TOPRIGHT", 6, 0)
    f.groupPanel:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    f.groupPanel:Hide()
    W.ApplyBackdrop(f.groupPanel, 0.35)

    local gpTitle = W.Title(f.groupPanel, "Group Settings", 12, -10)
    local gpNameLabel = W.Label(f.groupPanel, "Name:", "TOPLEFT", gpTitle, "BOTTOMLEFT", 0, -12)
    f.groupNameEdit = W.EditBox(f.groupPanel, 220, 22); f.groupNameEdit:SetPoint("LEFT", gpNameLabel, "RIGHT", 10, 0)
    f.groupNameEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus()
        local db = MSWA_GetDB(); local gid = MSWA.selectedGroupID; local g = gid and db.groups and db.groups[gid]
        if g then g.name = self:GetText() or g.name; MSWA_RefreshOptionsList() end
    end)

    local gpXLabel = W.Label(f.groupPanel, "X:", "TOPLEFT", gpNameLabel, "BOTTOMLEFT", 0, -12)
    f.groupXEdit = W.EditBox(f.groupPanel, 70, 22); f.groupXEdit:SetPoint("LEFT", gpXLabel, "RIGHT", 8, 0)
    local gpYLabel = W.Label(f.groupPanel, "Y:", "LEFT", f.groupXEdit, "RIGHT", 12, 0)
    f.groupYEdit = W.EditBox(f.groupPanel, 70, 22); f.groupYEdit:SetPoint("LEFT", gpYLabel, "RIGHT", 8, 0)
    local gpSizeLabel = W.Label(f.groupPanel, "Icon size:", "TOPLEFT", gpXLabel, "BOTTOMLEFT", 0, -12)
    f.groupSizeEdit = W.EditBox(f.groupPanel, 70, 22); f.groupSizeEdit:SetPoint("LEFT", gpSizeLabel, "RIGHT", 8, 0)
    local gpAnchorLabel = W.Label(f.groupPanel, "Anchor:", "TOPLEFT", gpSizeLabel, "BOTTOMLEFT", 0, -12)
    f.groupAnchorEdit = W.EditBox(f.groupPanel, 220, 22); f.groupAnchorEdit:SetPoint("LEFT", gpAnchorLabel, "RIGHT", 8, 0)

    local gpGrowthDd = W.Dropdown(f.groupPanel, "Growth Direction", 150,
        function() return {{ text="Right",value="RIGHT" },{ text="Left",value="LEFT" },{ text="Up",value="UP" },{ text="Down",value="DOWN" }} end,
        function() local db = MSWA_GetDB(); local gid = MSWA.selectedGroupID; local g = gid and db.groups and db.groups[gid]; return g and g.growthDirection or "RIGHT" end,
        function(v)
            local db = MSWA_GetDB(); local gid = MSWA.selectedGroupID; local g = gid and db.groups and db.groups[gid]; if not g then return end
            g.growthDirection = v; MSWA_RequestUpdateSpells()
        end)
    gpGrowthDd:SetPoint("TOPLEFT", gpAnchorLabel, "BOTTOMLEFT", 0, -12)

    local gpApplyBtn = W.Button(f.groupPanel, "Apply", 80, 24, function()
        local db = MSWA_GetDB(); local gid = MSWA.selectedGroupID; local g = gid and db.groups and db.groups[gid]; if not g then return end
        g.x = tonumber(f.groupXEdit:GetText()) or 0; g.y = tonumber(f.groupYEdit:GetText()) or 0
        g.size = tonumber(f.groupSizeEdit:GetText()) or MSWA.ICON_SIZE
        local af = f.groupAnchorEdit:GetText():gsub("^%s+",""):gsub("%s+$","")
        g.anchorFrame = (af ~= "" and af) or nil
        if MSWA_ForceUpdateSpells then MSWA_ForceUpdateSpells() else MSWA_RequestUpdateSpells() end
    end)
    gpApplyBtn:SetPoint("TOPLEFT", gpGrowthDd, "BOTTOMLEFT", 0, -14)

    function f.groupPanel:Sync()
        local db = MSWA_GetDB(); local gid = MSWA.selectedGroupID; local g = gid and db.groups and db.groups[gid]; if not g then return end
        f.groupNameEdit:SetText(g.name or ""); f.groupXEdit:SetText(tostring(g.x or 0))
        f.groupYEdit:SetText(tostring(g.y or 0)); f.groupSizeEdit:SetText(tostring(g.size or MSWA.ICON_SIZE))
        f.groupAnchorEdit:SetText(g.anchorFrame or "")
        gpGrowthDd:Refresh()
    end

    -- ════════════════════════════════════════════════════
    -- BOTTOM BAR
    -- ════════════════════════════════════════════════════
    local bottomBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    bottomBar:SetPoint("BOTTOMLEFT", 8, 8); bottomBar:SetPoint("BOTTOMRIGHT", -8, 8); bottomBar:SetHeight(28)
    W.ApplyBackdrop(bottomBar, 0.30)

    f.btnPreview = W.Button(bottomBar, "Preview", 70, 22, function()
        MSWA.previewMode = not MSWA.previewMode
        if MSWA.previewMode then f.btnPreview:SetText("|cff00ff00Preview|r") else f.btnPreview:SetText("Preview") end
        MSWA_RequestUpdateSpells()
    end)
    f.btnPreview:SetPoint("LEFT", 6, 0)

    f.btnIDInfo = W.Button(bottomBar, "ID Info", 65, 22, function(self, button)
        local db = MSWA_GetDB()
        local on = not (db.showSpellID or db.showIconID)
        db.showSpellID = on; db.showIconID = on
        if on then MSWA_Print("Tooltip ID Info ON") else MSWA_Print("Tooltip ID Info OFF") end
    end)
    f.btnIDInfo:SetPoint("LEFT", f.btnPreview, "RIGHT", 4, 0)

    local statusText = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("RIGHT", bottomBar, "RIGHT", -8, 0); W.SkinMuted(statusText)
    f._statusText = statusText

    -- ════════════════════════════════════════════════════
    -- TOP BUTTON SCRIPTS
    -- ════════════════════════════════════════════════════
    f.btnNew:SetScript("OnClick", function(self)
        if not MenuUtil or not MenuUtil.CreateContextMenu then
            local db = MSWA_GetDB(); db.trackedSpells = db.trackedSpells or {}; local dk = MSWA_NewDraftKey(); db.trackedSpells[dk] = true
            MSWA.selectedSpellID = dk; MSWA.selectedGroupID = nil; SwitchPage("trigger"); MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList()
            return
        end
        MenuUtil.CreateContextMenu(self, function(_, rootDescription)
            rootDescription:CreateTitle("New Aura")
            rootDescription:CreateButton("Cooldown", function()
                local db = MSWA_GetDB(); db.trackedSpells = db.trackedSpells or {}; local dk = MSWA_NewDraftKey(); db.trackedSpells[dk] = true
                MSWA.selectedSpellID = dk; MSWA.selectedGroupID = nil; SwitchPage("trigger"); MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList()
            end)
            rootDescription:CreateButton("Buff Aura", function()
                local db = MSWA_GetDB(); db.trackedSpells = db.trackedSpells or {}; local dk = MSWA_NewDraftKey(); db.trackedSpells[dk] = true
                db.spellSettings = db.spellSettings or {}; local s = {}
                s.auraMode = "BUFF_AURA"; s.auraUnit = "player"; s.showWhenAbsent = false; s.desaturateOnAbsent = true; s.alphaOnAbsent = 0.45; s.showStacks = true
                db.spellSettings[dk] = s
                MSWA.selectedSpellID = dk; MSWA.selectedGroupID = nil; SwitchPage("trigger"); MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList()
            end)
            rootDescription:CreateButton("From Template...", function()
                if MSWA_ToggleTemplateBrowser then MSWA_ToggleTemplateBrowser() end
            end)
        end)
    end)
    f.btnImport:SetScript("OnClick", function() MSWA_OpenImportFrame() end)
    f.btnExport:SetScript("OnClick", function()
        if MSWA.selectedGroupID then MSWA_ExportGroup(MSWA.selectedGroupID); return end
        local key = MSWA.selectedSpellID; if not key then MSWA_Print("Select an aura or group to export."); return end
        MSWA_ExportAura(key)
    end)
    f.btnGroup:SetScript("OnClick", function()
        local gid = MSWA_CreateGroup(nil); MSWA.selectedSpellID = nil; MSWA.selectedGroupID = gid
        MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList()
    end)

    -- ════════════════════════════════════════════════════
    -- OnShow / OnHide / OnSizeChanged
    -- ════════════════════════════════════════════════════
    f:SetScript("OnSizeChanged", function(self)
        if self:IsShown() and self.UpdateAuraList then self:UpdateAuraList() end
    end)
    f:SetScript("OnShow", function()
        MSWA.selectedSpellID = nil; MSWA.selectedGroupID = nil; MSWA.previewMode = false
        if f.btnPreview then f.btnPreview:SetText("Preview") end
        _currentPageKey = "trigger"; SwitchPage("trigger")
        f:UpdateAuraList(); MSWA_RebuildFontChoices()
    end)
    f:SetScript("OnHide", function()
        MSWA.selectedSpellID = nil; MSWA.selectedGroupID = nil
        if MSWA.previewMode then MSWA.previewMode = false; if f.btnPreview then f.btnPreview:SetText("Preview") end; MSWA_RequestUpdateSpells() end
    end)

    f:Hide(); MSWA.optionsFrame = f; MSWA_RebuildFontChoices()
    f:UpdateAuraList()
    return f
end

-----------------------------------------------------------
-- Toggle options
-----------------------------------------------------------
function MSWA_ToggleOptions()
    local f = MSWA.optionsFrame or MSWA_CreateOptionsFrame()
    if f:IsShown() then f:Hide() else MSWA_RefreshOptionsList(); f:Show() end
end

SLASH_MIDNIGHTSIMPLEWEAKAURAS1 = "/msa"
SLASH_MIDNIGHTSIMPLEWEAKAURAS2 = "/ms"
SLASH_MIDNIGHTSIMPLEWEAKAURAS3 = "/midnightsimpleauras"

SlashCmdList["MIDNIGHTSIMPLEWEAKAURAS"] = function(msg)
    local db = MSWA_GetDB()
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$"); cmd = cmd or ""; rest = rest or ""

    if cmd == "" or cmd == "config" or cmd == "options" or cmd == "menu" then MSWA_ToggleOptions(); return end
    if cmd == "move" or cmd == "unlock" then db.locked = false; MSWA.frame.infoText:Show(); MSWA_UpdatePositionFromDB(); MSWA_Print("Frame unlocked."); return end
    if cmd == "lock" then db.locked = true; MSWA.frame.infoText:Hide(); MSWA_UpdatePositionFromDB(); MSWA_Print("Frame locked."); return end
    if cmd == "reset" then db.position = { x = 0, y = -150 }; MSWA_UpdatePositionFromDB(); MSWA_Print("Position reset."); return end

    if cmd == "add" then
        local id = tonumber(rest); if not id then MSWA_Print("Use: /msa add <SpellID>"); return end
        local name = MSWA_GetSpellName(id); if not name then MSWA_Print("Invalid SpellID: " .. id); return end
        local newKey; if db.trackedSpells[id] then newKey = MSWA_NewSpellInstanceKey(id); db.trackedSpells[newKey] = true else db.trackedSpells[id] = true; newKey = id end
        MSWA.selectedSpellID = newKey; MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList(); MSWA_Print(("Now tracking %s (%d)."):format(name, id)); return
    end
    if cmd == "additem" or cmd == "itemadd" then
        local id = tonumber(rest); if not id then MSWA_Print("Use: /msa additem <ItemID>"); return end
        db.trackedItems = db.trackedItems or {}; db.trackedSpells = db.trackedSpells or {}
        local newKey
        if db.trackedItems[id] then newKey = MSWA_NewItemInstanceKey(id); db.trackedSpells[newKey] = true
        else db.trackedItems[id] = true; newKey = ("item:%d"):format(id) end
        MSWA.selectedSpellID = newKey; MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList()
        MSWA_Print(("Now tracking item %d."):format(id)); return
    end
    if cmd == "remove" or cmd == "del" or cmd == "delete" then
        local id = tonumber(rest); if not id then MSWA_Print("Use: /msa remove <SpellID>"); return end
        if db.trackedSpells[id] then
            db.trackedSpells[id] = nil; if MSWA.selectedSpellID == id then MSWA.selectedSpellID = nil; MSWA.selectedGroupID = nil end
            MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList(); MSWA_Print(("Stopped tracking %d."):format(id))
        else MSWA_Print("Not tracked: " .. id) end; return
    end
    if cmd == "removeitem" or cmd == "delitem" or cmd == "deleteitem" then
        local id = tonumber(rest); if not id then MSWA_Print("Use: /msa removeitem <ItemID>"); return end
        db.trackedItems = db.trackedItems or {}; local key = ("item:%d"):format(id)
        if db.trackedItems[id] then db.trackedItems[id] = nil; if db.customNames then db.customNames[key] = nil end
            if MSWA.selectedSpellID == key then MSWA.selectedSpellID = nil; MSWA.selectedGroupID = nil end
            MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList(); MSWA_Print(("Stopped tracking item %d."):format(id))
        else MSWA_Print("Not tracked: " .. id) end; return
    end
    if cmd == "list" then
        MSWA_Print("Tracked SpellIDs:"); local empty = true
        for id, enabled in pairs(db.trackedSpells) do if enabled then print(("  - %s : %s"):format(tostring(id), MSWA_GetSpellName(id) or "???")); empty = false end end
        if empty then MSWA_Print("None.") end
        MSWA_Print("Tracked ItemIDs:"); local ie = true; db.trackedItems = db.trackedItems or {}
        for itemID, enabled in pairs(db.trackedItems) do if enabled then print(("  - %d"):format(itemID)); ie = false end end
        if ie then MSWA_Print("None.") end; return
    end

    if cmd == "id" or cmd == "idinfo" then
        local on = not (db.showSpellID or db.showIconID)
        db.showSpellID = on; db.showIconID = on
        if on then MSWA_Print("Tooltip ID Info ON") else MSWA_Print("Tooltip ID Info OFF") end
        local optF = MSWA.optionsFrame
        if optF and optF.btnIDInfo then
            if on then optF.btnIDInfo:SetText("|cff00ff00ID Info|r") else optF.btnIDInfo:SetText("ID Info") end
        end
        return
    end

    if cmd == "template" or cmd == "templates" or cmd == "browse" then
        if MSWA_ToggleTemplateBrowser then MSWA_ToggleTemplateBrowser() else MSWA_Print("Template browser not loaded.") end
        return
    end

    MSWA_Print("Commands: /msa, /msa move, /msa lock, /msa reset, /msa add <ID>, /msa remove <ID>, /msa additem <ID>, /msa removeitem <ID>, /msa list, /msa id, /msa template")
end

-----------------------------------------------------------
-- Open helpers (called by MSUF)
-----------------------------------------------------------

function MSWA_OpenOptions() MSWA_ToggleOptions() end
function MidnightSimpleAuras_OpenOptions() MSWA_ToggleOptions() end
