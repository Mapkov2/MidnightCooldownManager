local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]

local CDM_C = CDM and CDM.CONST or {}
local Snap = CDM.Pixel.Snap

CDM.CustomBuffs = {
    activeBuffs = {},       -- [spellID] = { expires, frame, startTime, duration }
    activeBuffVersion = 0,
    iconFrames = {},        -- [spellID] = frame
    framePool = {},         -- reusable, inactive custom buff frames
}

local CB = CDM.CustomBuffs
local VIEWERS = CDM_C.VIEWERS

local GetTime = GetTime
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local GetSpellTexture = C_Spell.GetSpellTexture

local EMPTY_ORDER = {}
local ungroupedSeenScratch = {}

local TIME_SPIRAL_TRIGGERS = {
    [48265]  = true,  -- Death's Advance
    [195072] = true,  -- Fel Rush
    [189110] = true,  -- Infernal Strike
    [1850]   = true,  -- Dash
    [252216] = true,  -- Tiger Dash
    [358267] = true,  -- Hover
    [186257] = true,  -- Aspect of the Cheetah
    [1953]   = true,  -- Blink
    [212653] = true,  -- Shimmer
    [361138] = true,  -- Roll
    [119085] = true,  -- Chi Torpedo
    [190784] = true,  -- Divine Steed
    [73325]  = true,  -- Leap of Faith
    [2983]   = true,  -- Sprint
    [192063] = true,  -- Gust of Wind
    [58875]  = true,  -- Spirit Walk
    [79206]  = true,  -- Spiritwalker's Grace
    [48020]  = true,  -- Demonic Circle: Teleport
    [6544]   = true,  -- Heroic Leap
}

local TIME_SPIRAL_GLOW_FILTERS = {
    { talentID = 427640, spells = {198793, 370965, 195072} },  -- Inertia → Vengeful Retreat, The Hunt, Fel Rush
    { talentID = 427794, spells = {195072} },                  -- Dash of Chaos → Fel Rush
    { talentID = 385899, spells = {385899} },                  -- Soulburn
}

local glowSuppressSpells = {}
local suppressGlowUntil = 0

local BLOODLUST_DEBUFFS = {
    [57723]  = 32182,   -- Exhaustion → Heroism
    [57724]  = 2825,    -- Sated → Bloodlust
    [80354]  = 80353,   -- Temporal Displacement → Time Warp
    [95809]  = 90355,   -- Insanity → Ancient Hysteria
    [160455] = 264667,  -- Fatigued → Primal Rage
    [264689] = 264667,  -- Fatigued → Primal Rage
    [390435] = 390386,  -- Exhaustion → Fury of the Aspects
}

local function AddEquivalentSpellID(set, spellID)
    if type(set) ~= "table" or not CDM.IsSafeNumber(spellID) or spellID <= 0 then return end
    set[spellID] = true

    local baseID = CDM.NormalizeToBase and CDM.NormalizeToBase(spellID)
    if CDM.IsSafeNumber(baseID) and baseID > 0 then
        set[baseID] = true
    end

    local stableID = CDM.ResolveStableBase and CDM:ResolveStableBase(spellID)
    if CDM.IsSafeNumber(stableID) and stableID > 0 then
        set[stableID] = true
    end

    if CDM.ForEachSpellMatchCandidate then
        CDM:ForEachSpellMatchCandidate(spellID, function(candidateID)
            if CDM.IsSafeNumber(candidateID) and candidateID > 0 then
                set[candidateID] = true
            end
        end)
    end
end

local function SpellSetHasEquivalent(set, spellID)
    if type(set) ~= "table" or not CDM.IsSafeNumber(spellID) or spellID <= 0 then
        return false
    end
    if set[spellID] then return true end

    local baseID = CDM.NormalizeToBase and CDM.NormalizeToBase(spellID)
    if CDM.IsSafeNumber(baseID) and set[baseID] then return true end

    local stableID = CDM.ResolveStableBase and CDM:ResolveStableBase(spellID)
    if CDM.IsSafeNumber(stableID) and set[stableID] then return true end

    if CDM.ForEachSpellMatchCandidate then
        local found = false
        CDM:ForEachSpellMatchCandidate(spellID, function(candidateID)
            if set[candidateID] then
                found = true
                return true
            end
        end)
        if found then return true end
    end

    return false
end

local function IsBuiltInCustomBuffTemplateSpell(spellID)
    if not CDM.IsSafeNumber(spellID) or spellID <= 0 then
        return false
    end

    for _, tmpl in ipairs(CDM.CustomBuffTemplates or {}) do
        if tmpl.spellID == spellID then
            return true
        end
    end

    return false
end

function CDM:IsCustomBuffTemplateSpell(spellID)
    return IsBuiltInCustomBuffTemplateSpell(spellID)
end

local function BuildLoadedCDMBuffSpellSet(specID)
    local set = {}
    local currentSpecID = CDM.GetCurrentSpecID and CDM:GetCurrentSpecID() or nil

    if specID and currentSpecID and specID ~= currentSpecID then
        local cached = CDM.GetSpecBuffSpellCache and CDM:GetSpecBuffSpellCache(specID)
        if type(cached) ~= "table" then
            return set, false, "cache_missing"
        end

        for _, entry in ipairs(cached) do
            AddEquivalentSpellID(set, entry.spellID)
            AddEquivalentSpellID(set, entry.baseSpellID)
            AddEquivalentSpellID(set, entry.overrideSpellID)
            AddEquivalentSpellID(set, entry.overrideTooltipSpellID)
            if type(entry.linkedSpellIDs) == "table" then
                for _, linkedID in ipairs(entry.linkedSpellIDs) do
                    AddEquivalentSpellID(set, linkedID)
                end
            end
        end
        return set, true
    end

    if not CDM.ForEachCooldownViewerInfoByKind then
        return set, false, "cdm_unavailable"
    end

    local seen = {}
    CDM:ForEachCooldownViewerInfoByKind("buff", function(cooldownID, info, _, entry)
        if seen[cooldownID] then return end
        seen[cooldownID] = true
        if entry then
            AddEquivalentSpellID(set, entry.displaySpellID)
            AddEquivalentSpellID(set, entry.spellID)
            AddEquivalentSpellID(set, entry.overrideSpellID)
            AddEquivalentSpellID(set, entry.overrideTooltipSpellID)
            if type(entry.linkedSpellIDs) == "table" then
                for _, linkedID in ipairs(entry.linkedSpellIDs) do
                    AddEquivalentSpellID(set, linkedID)
                end
            end
        end
        if info then
            AddEquivalentSpellID(set, info.spellID)
            AddEquivalentSpellID(set, info.overrideSpellID)
            AddEquivalentSpellID(set, info.overrideTooltipSpellID)
            if type(info.linkedSpellIDs) == "table" then
                for _, linkedID in ipairs(info.linkedSpellIDs) do
                    AddEquivalentSpellID(set, linkedID)
                end
            end
        end
    end)

    return set, true
end

function CDM:IsCustomBuffSpellLoadedInCDM(spellID, specID)
    if not CDM.IsSafeNumber(spellID) or spellID <= 0 then
        return false, "invalid_spell_id"
    end

    if IsBuiltInCustomBuffTemplateSpell(spellID) then
        return true, "custom_template"
    end

    local set, ready, reason = BuildLoadedCDMBuffSpellSet(specID)
    if not ready then
        return false, reason or "not_loaded_in_cdm"
    end
    if SpellSetHasEquivalent(set, spellID) then
        return true
    end
    return false, "not_loaded_in_cdm"
end

function CDM:RebuildGlowFilters()
    table.wipe(glowSuppressSpells)
    for _, entry in ipairs(TIME_SPIRAL_GLOW_FILTERS) do
        if IsPlayerSpell(entry.talentID) then
            for _, spellID in ipairs(entry.spells) do
                glowSuppressSpells[spellID] = true
            end
        end
    end
end

local cachedCustomBuffStyles = {
    fontPath = nil,
    fontOutline = nil,
    fontSize = 12,
    fontColor = nil,
}

local function RefreshCachedCustomBuffStyles()
    local db = CDM.db
    local defaults = CDM.defaults or {}

    CDM_C.RefreshBaseFontCache()
    cachedCustomBuffStyles.fontPath = CDM_C.GetBaseFontPath()
    cachedCustomBuffStyles.fontOutline = CDM_C.GetBaseFontOutline()
    cachedCustomBuffStyles.fontSize = db and db.buffCooldownFontSize or defaults.buffCooldownFontSize or 12
    cachedCustomBuffStyles.fontColor = (db and db.buffCooldownColor) or defaults.buffCooldownColor or CDM_C.WHITE
end

CDM.RefreshCachedCustomBuffStyles = RefreshCachedCustomBuffStyles

local function SetupCustomBuffCooldownTextLayout(frame)
    if not frame or not frame.Cooldown then return end

    local text = frame.Cooldown.Text or frame.Cooldown.text
    if not text or not text.SetFont then return end
    text:SetIgnoreParentScale(true)
    text:ClearAllPoints()
    text:SetPoint("CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetShadowOffset(0, 0)
    text:SetDrawLayer("OVERLAY", 7)
end

local function IsGroupedCustomBuff(spellID)
    local sets = CDM.BuffGroupSets
    local grouped = sets and sets.grouped
    return grouped and grouped[spellID] and true or false
end

local function ApplyCustomBuffCooldownTextStyle(frame)
    if not frame or not frame.Cooldown then return end
    if not cachedCustomBuffStyles.fontPath then
        RefreshCachedCustomBuffStyles()
    end

    local text = frame.Cooldown.Text or frame.Cooldown.text
    if not text or not text.SetFont then return end
    local fontColor = cachedCustomBuffStyles.fontColor or CDM_C.WHITE
    text:SetFont(
        cachedCustomBuffStyles.fontPath,
        CDM.Pixel.FontSize(cachedCustomBuffStyles.fontSize),
        cachedCustomBuffStyles.fontOutline
    )
    text:SetTextColor(fontColor.r, fontColor.g, fontColor.b, fontColor.a or 1)
end

local function ReanchorBuffViewer()
    local v = CDM:GetCooldownViewerFrame(VIEWERS.BUFF)
    if v then CDM:ForceReanchor(v) end
end

function CDM:GetCustomBuffEffectiveSize(spellID)
    local sets = self.BuffGroupSets
    local grouped = sets and sets.grouped
    local groupIdx = spellID and grouped and grouped[spellID]
    local groupData = groupIdx and sets.groups and sets.groups[groupIdx]
    if groupData then
        return Snap(groupData.iconWidth or 30), Snap(groupData.iconHeight or 30)
    end
    local defaults = self.defaults or {}
    local defaultSize = defaults.sizeBuff or { w = 32, h = 32 }
    local dbSize = self.db and self.db.sizeBuff
    return (dbSize and dbSize.w) or defaultSize.w, (dbSize and dbSize.h) or defaultSize.h
end

local function CreateCustomBuffIcon(spellID, config)
    if CB.iconFrames[spellID] then
        return CB.iconFrames[spellID]
    end

    local w, h = CDM:GetCustomBuffEffectiveSize(spellID)

    local frame = table.remove(CB.framePool)
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)

        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        CDM.Pixel.DisableTextureSnap(icon)
        frame.Icon = icon

        local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
        cooldown:SetAllPoints()
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawSwipe(not (CDM.db and CDM.db.hideBuffSwipe))
        cooldown:SetSwipeColor(CDM_C.SWIPE_COLOR.r, CDM_C.SWIPE_COLOR.g, CDM_C.SWIPE_COLOR.b, CDM_C.SWIPE_COLOR.a)
        cooldown:SetReverse(true)  -- Fill up as time passes (like a buff)
        frame.Cooldown = cooldown
        SetupCustomBuffCooldownTextLayout(frame)

        if CDM.BORDER and CDM.BORDER.CreateBorder then
            frame.cdmBorder = CDM.BORDER:CreateBorder(frame)
        end
    end

    frame:SetSize(w, h)
    frame.spellID = spellID
    frame.isCustomBuff = true
    frame.customBuffStartTime = nil
    if CDM.InvalidateFrameCooldownRecord then
        CDM:InvalidateFrameCooldownRecord(frame)
    end

    if frame.Icon then
        frame.Icon:SetAllPoints()
        CDM_C.ApplyIconTexCoord(frame.Icon, CDM_C.GetEffectiveZoomAmount(), w, h)
        frame.Icon:SetTexture(config.icon)
        frame.Icon:SetDesaturation(0)
    end

    if frame.Cooldown then
        frame.Cooldown:SetAllPoints()
        frame.Cooldown:SetDrawBling(not (CDM.db and CDM.db.hideCooldownBling))
        frame.Cooldown:SetScript("OnCooldownDone", nil)
    end

    frame:Hide()

    CB.iconFrames[spellID] = frame

    return frame
end

local DeactivateCustomBuff

local function ActivateCustomBuff(spellID, config, overrideStartTime)
    local frame = CreateCustomBuffIcon(spellID, config)

    local startTime = overrideStartTime or GetTime()
    local duration = config.duration

    if not frame.cdmDurationObj then
        frame.cdmDurationObj = C_DurationUtil.CreateDuration()
    end
    frame.cdmDurationObj:SetTimeFromStart(startTime, duration)
    frame.Cooldown:SetCooldownFromDurationObject(frame.cdmDurationObj)
    if CDM.ApplyIconCooldownTint then
        CDM:ApplyIconCooldownTint(frame, "buff", true)
    end
    frame.Cooldown:SetScript("OnCooldownDone", function()
        DeactivateCustomBuff(spellID)
    end)
    if not IsGroupedCustomBuff(spellID) then
        ApplyCustomBuffCooldownTextStyle(frame)
    end

    CB.activeBuffs[spellID] = {
        expires = startTime + duration,
        frame = frame,
        startTime = startTime,
        duration = duration,
    }
    CB.activeBuffVersion = (CB.activeBuffVersion or 0) + 1

    frame.customBuffStartTime = startTime

    frame:Show()
    ReanchorBuffViewer()

    if CDM.PlayCustomBuffNotification then
        CDM:PlayCustomBuffNotification(spellID, false)
    end
end

DeactivateCustomBuff = function(spellID)
    local buffData = CB.activeBuffs[spellID]
    if not buffData then return end

    if CDM.PlayCustomBuffNotification then
        CDM:PlayCustomBuffNotification(spellID, true)
    end

    if buffData.frame then
        if buffData.frame.Cooldown then
            buffData.frame.Cooldown:SetScript("OnCooldownDone", nil)
        end
        if CDM.ApplyIconCooldownTint then
            CDM:ApplyIconCooldownTint(buffData.frame, "buff", false)
        end
        buffData.frame:Hide()
    end

    CB.activeBuffs[spellID] = nil
    CB.activeBuffVersion = (CB.activeBuffVersion or 0) + 1
    ReanchorBuffViewer()
end

local function OnSpellCastSucceeded(event, unit, castGUID, spellID)
    local config = CDM.db.customBuffRegistry and CDM.db.customBuffRegistry[spellID]
    if not config or config.triggerType then return end

    ActivateCustomBuff(spellID, config)
end

local function OnSpellCastSent(event, unit, target, castGUID, spellID)
    if not CDM.IsSafeNumber(spellID) then return end
    if not glowSuppressSpells[spellID] then return end
    suppressGlowUntil = GetTime() + 1.5
end

local function OnGlowShow(event, spellID)
    if not CDM.IsSafeNumber(spellID) then return end
    if not TIME_SPIRAL_TRIGGERS[spellID] then return end
    if GetTime() < suppressGlowUntil then return end
    local config = CDM.db.customBuffRegistry and CDM.db.customBuffRegistry[374968]
    if not config then return end
    if CB.activeBuffs[374968] then return end
    ActivateCustomBuff(374968, config)
end

local function OnGlowHide(event, spellID)
    if not CDM.IsSafeNumber(spellID) then return end
    if not TIME_SPIRAL_TRIGGERS[spellID] then return end
    if not CB.activeBuffs[374968] then return end
    DeactivateCustomBuff(374968)
end

local bloodlustDebuffInstanceID

local function ActivateBloodlustFromDebuff(aura, lustBuffID, requireWithinWindow)
    local config = CDM.db.customBuffRegistry and CDM.db.customBuffRegistry[2825]
    if not config then return end
    if CB.activeBuffs[2825] then return end

    local dur = aura.duration
    if not dur or dur <= 0 then dur = 600 end
    local appliedTime = aura.expirationTime - dur

    if requireWithinWindow and (GetTime() - appliedTime) >= 40 then return end

    ActivateCustomBuff(2825, config, appliedTime)
    local frame = CB.iconFrames[2825]
    if frame and frame.Icon then
        frame.Icon:SetTexture(GetSpellTexture(lustBuffID))
    end
end

local function SeedBloodlust()
    bloodlustDebuffInstanceID = nil
    for debuffID, lustBuffID in pairs(BLOODLUST_DEBUFFS) do
        local aura = GetPlayerAuraBySpellID(debuffID)
        if aura and aura.auraInstanceID and aura.expirationTime then
            bloodlustDebuffInstanceID = aura.auraInstanceID
            ActivateBloodlustFromDebuff(aura, lustBuffID, true)
            return
        end
    end
end

local function OnBloodlustAura(event, unit, info)
    if not info or info.isFullUpdate then
        SeedBloodlust()
        return
    end
    if info.addedAuras then
        for _, aura in ipairs(info.addedAuras) do
            local sid = aura.spellId
            if CDM.IsSafeNumber(sid) then
                local lustBuffID = BLOODLUST_DEBUFFS[sid]
                if lustBuffID and aura.auraInstanceID and aura.expirationTime then
                    bloodlustDebuffInstanceID = aura.auraInstanceID
                    ActivateBloodlustFromDebuff(aura, lustBuffID, false)
                    break
                end
            end
        end
    end
    if bloodlustDebuffInstanceID and info.removedAuraInstanceIDs then
        for _, id in ipairs(info.removedAuraInstanceIDs) do
            if id == bloodlustDebuffInstanceID then
                bloodlustDebuffInstanceID = nil
                break
            end
        end
    end
end

local function ReleaseCustomBuffFrame(spellID)
    local frame = CB.iconFrames[spellID]
    if not frame then return end

    if frame.Cooldown then
        frame.Cooldown:SetScript("OnCooldownDone", nil)
        frame.Cooldown:Clear()
    end
    if CDM.ApplyIconCooldownTint then
        CDM:ApplyIconCooldownTint(frame, "buff", false)
    end
    frame:Hide()
    frame:ClearAllPoints()
    frame.cdmAnchor = nil
    if frame:GetParent() ~= UIParent then
        frame:SetParent(UIParent)
    end
    frame.spellID = nil
    frame.customBuffStartTime = nil
    if CDM.InvalidateFrameCooldownRecord then
        CDM:InvalidateFrameCooldownRecord(frame)
    end
    CB.framePool[#CB.framePool + 1] = frame
    CB.iconFrames[spellID] = nil
end

local function MoveMapEntry(map, oldSpellID, newSpellID)
    if type(map) ~= "table" then return end
    local value = map[oldSpellID]
    if value ~= nil then
        if map[newSpellID] == nil then
            map[newSpellID] = value
        end
        map[oldSpellID] = nil
    end
end

local function MoveOverrideEntry(overrideMap, oldSpellID, newSpellID)
    if type(overrideMap) ~= "table" then return end
    if CDM.ExtractMergedBuffOverrideEntry and CDM.StoreMergedBuffOverrideEntry then
        local incoming = CDM:ExtractMergedBuffOverrideEntry(overrideMap, oldSpellID)
        if incoming then
            local existing = CDM.GetMergedBuffOverrideEntry and CDM:GetMergedBuffOverrideEntry(overrideMap, newSpellID)
            if existing and CDM.MergeMissingBuffOverrideFields then
                CDM:MergeMissingBuffOverrideFields(existing, incoming)
                CDM:StoreMergedBuffOverrideEntry(overrideMap, newSpellID, existing)
            else
                CDM:StoreMergedBuffOverrideEntry(overrideMap, newSpellID, incoming)
            end
        end
        return
    end

    local oldKey = (CDM.GetBuffOverrideStorageKey and CDM:GetBuffOverrideStorageKey(oldSpellID)) or oldSpellID
    local newKey = (CDM.GetBuffOverrideStorageKey and CDM:GetBuffOverrideStorageKey(newSpellID)) or newSpellID
    if overrideMap[oldKey] ~= nil then
        if overrideMap[newKey] == nil then
            overrideMap[newKey] = overrideMap[oldKey]
        end
        overrideMap[oldKey] = nil
    end
end

local function ReplaceSpellInGroupList(spellList, oldSpellID, newSpellID)
    if type(spellList) ~= "table" then return end
    local hasNew = false
    for _, sid in ipairs(spellList) do
        if sid == newSpellID then
            hasNew = true
            break
        end
    end
    for i = #spellList, 1, -1 do
        if spellList[i] == oldSpellID then
            if hasNew then
                table.remove(spellList, i)
            else
                spellList[i] = newSpellID
                hasNew = true
            end
        end
    end
end

local function MigrateCustomBuffReferences(oldSpellID, newSpellID)
    local db = CDM.db
    if not db then return end

    if db.ungroupedCustomBuffOrder then
        for _, order in pairs(db.ungroupedCustomBuffOrder) do
            if type(order) == "table" then
                local hasNew = false
                for _, entry in ipairs(order) do
                    if type(entry) == "table" and entry.spellID == newSpellID then
                        hasNew = true
                        break
                    end
                end
                for i = #order, 1, -1 do
                    local entry = order[i]
                    if type(entry) == "table" and entry.spellID == oldSpellID then
                        if hasNew then
                            table.remove(order, i)
                        else
                            entry.spellID = newSpellID
                            hasNew = true
                        end
                    end
                end
            end
        end
    end

    if db.buffGroups then
        for _, specGroups in pairs(db.buffGroups) do
            if type(specGroups) == "table" then
                for _, groupData in ipairs(specGroups) do
                    if type(groupData) == "table" then
                        ReplaceSpellInGroupList(groupData.spells, oldSpellID, newSpellID)
                        MoveOverrideEntry(groupData.spellOverrides, oldSpellID, newSpellID)
                    end
                end
            end
        end
    end

    if db.ungroupedBuffOverrides then
        for _, specOv in pairs(db.ungroupedBuffOverrides) do
            MoveOverrideEntry(specOv, oldSpellID, newSpellID)
        end
    end

    if db.spellRegistry then
        for specID, registry in pairs(db.spellRegistry) do
            if type(registry) == "table" then
                MoveMapEntry(registry.colors, oldSpellID, newSpellID)
                MoveMapEntry(registry.glowEnabled, oldSpellID, newSpellID)
                MoveMapEntry(registry.glowColors, oldSpellID, newSpellID)
            end
            if CDM.CompactRegistrySpec then
                CDM:CompactRegistrySpec(specID)
            end
        end
    end
end

function CDM:AddCustomBuffSpell(spellID, duration, templateOverrides, specID)
    if not spellID or not duration then return false, "invalid_custom_buff" end

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then return false, "invalid_spell_id" end

    local isLoaded, loadErr = CDM:IsCustomBuffSpellLoadedInCDM(spellID, specID)
    if not isLoaded then
        return false, loadErr or "not_loaded_in_cdm"
    end

    if not CDM.db.customBuffRegistry then
        CDM.db.customBuffRegistry = {}
    end

    local entry = {
        duration = duration,
        name = spellInfo.name,
        icon = spellInfo.iconID,
    }
    if templateOverrides then
        if templateOverrides.icon then entry.icon = templateOverrides.icon end
        if templateOverrides.triggerType then entry.triggerType = templateOverrides.triggerType end
    end

    CDM.db.customBuffRegistry[spellID] = entry
    return true
end

function CDM:ReplaceCustomBuffSpell(oldSpellID, newSpellID, duration, templateOverrides, specID)
    if not oldSpellID or not newSpellID or not duration then return false, "invalid_custom_buff" end
    if not CDM.db.customBuffRegistry or not CDM.db.customBuffRegistry[oldSpellID] then
        return false, "custom_buff_not_found"
    end

    local spellInfo = C_Spell.GetSpellInfo(newSpellID)
    if not spellInfo then return false, "invalid_spell_id" end

    if oldSpellID ~= newSpellID then
        local isLoaded, loadErr = CDM:IsCustomBuffSpellLoadedInCDM(newSpellID, specID)
        if not isLoaded then
            return false, loadErr or "not_loaded_in_cdm"
        end
    end

    local oldEntry = CDM.db.customBuffRegistry[oldSpellID]
    if oldSpellID ~= newSpellID and CDM.db.customBuffRegistry[newSpellID] then
        return false, "custom_buff_exists"
    end

    if oldSpellID ~= newSpellID then
        if CB.activeBuffs[oldSpellID] then
            DeactivateCustomBuff(oldSpellID)
        end
        ReleaseCustomBuffFrame(oldSpellID)
    end

    local entry = {
        duration = duration,
        name = spellInfo.name,
        icon = spellInfo.iconID,
    }
    if oldEntry and oldEntry.triggerType then entry.triggerType = oldEntry.triggerType end
    if templateOverrides then
        if templateOverrides.icon then entry.icon = templateOverrides.icon end
        if templateOverrides.triggerType then entry.triggerType = templateOverrides.triggerType end
    elseif oldEntry and oldEntry.triggerType and oldEntry.icon and oldEntry.icon ~= entry.icon then
        entry.icon = oldEntry.icon
    end

    CDM.db.customBuffRegistry[newSpellID] = entry
    if oldSpellID ~= newSpellID then
        CDM.db.customBuffRegistry[oldSpellID] = nil
        MigrateCustomBuffReferences(oldSpellID, newSpellID)
    end

    return true
end

function CDM:RemoveCustomBuffSpell(spellID)
    if not CDM.db.customBuffRegistry then return end

    if CB.activeBuffs[spellID] then
        DeactivateCustomBuff(spellID)
    end

    ReleaseCustomBuffFrame(spellID)

    CDM.db.customBuffRegistry[spellID] = nil

    if CDM.db.ungroupedCustomBuffOrder then
        for _, order in pairs(CDM.db.ungroupedCustomBuffOrder) do
            for i = #order, 1, -1 do
                if order[i].spellID == spellID then
                    table.remove(order, i)
                end
            end
        end
    end

    if CDM.db.buffGroups then
        for _, specGroups in pairs(CDM.db.buffGroups) do
            if type(specGroups) == "table" then
                for _, groupData in ipairs(specGroups) do
                    if groupData.spells then
                        for i = #groupData.spells, 1, -1 do
                            if groupData.spells[i] == spellID then
                                table.remove(groupData.spells, i)
                            end
                        end
                    end
                end
            end
        end
    end

    local isAlsoNative = CDM.ResolveStableBase and CDM:ResolveStableBase(spellID)
    if not isAlsoNative then
        local storageKey = CDM.GetBuffOverrideStorageKey and CDM:GetBuffOverrideStorageKey(spellID) or spellID

        if CDM.db.ungroupedBuffOverrides then
            for _, specOv in pairs(CDM.db.ungroupedBuffOverrides) do
                if type(specOv) == "table" then
                    specOv[spellID] = nil
                    if storageKey then specOv[storageKey] = nil end
                end
            end
        end

        if CDM.db.spellRegistry then
            for specID, registry in pairs(CDM.db.spellRegistry) do
                if type(registry) == "table" then
                    if registry.colors then registry.colors[spellID] = nil end
                    if registry.glowEnabled then registry.glowEnabled[spellID] = nil end
                    if registry.glowColors then registry.glowColors[spellID] = nil end
                end
                if CDM.CompactRegistrySpec then
                    CDM:CompactRegistrySpec(specID)
                end
            end
        end
    end
end

function CDM:UpdateCustomBuffs()
    RefreshCachedCustomBuffStyles()

    for spellID, frame in pairs(CB.iconFrames) do
        local w, h = self:GetCustomBuffEffectiveSize(spellID)
        frame:SetSize(w, h)

        if frame.Icon then
            CDM_C.ApplyIconTexCoord(frame.Icon, CDM_C.GetEffectiveZoomAmount(), w, h)
        end

        if not IsGroupedCustomBuff(spellID) then
            ApplyCustomBuffCooldownTextStyle(frame)
        end
    end
end

CDM.CustomBuffTemplates = {
    { spellID = 1236616, duration = 30 },  -- Light's Potential
    { spellID = 1236994, duration = 30 },  -- Potion of Recklessness
    { spellID = 1239479, duration = 10 },  -- Potion of Devoured Dreams
    { spellID = 374968, duration = 10, icon = 4622479, triggerType = "timespiral" },  -- Time Spiral
    { spellID = 2825, duration = 40, triggerType = "bloodlust" },  -- Bloodlust
}


function CDM:IsCustomBuffInAnyGroup(specID, spellID)
    local groups = self.db and self.db.buffGroups and self.db.buffGroups[specID]
    if not groups then return false end
    for _, groupData in ipairs(groups) do
        if groupData.spells then
            for _, sid in ipairs(groupData.spells) do
                if sid == spellID then return true end
            end
        end
    end
    return false
end

function CDM:GetUngroupedCustomBuffOrder(specID)
    if not specID then return EMPTY_ORDER end
    local db = self.db
    if not db then return EMPTY_ORDER end

    local registry = db.customBuffRegistry
    if not registry then return EMPTY_ORDER end

    if not db.ungroupedCustomBuffOrder then
        db.ungroupedCustomBuffOrder = {}
    end

    local order = db.ungroupedCustomBuffOrder[specID]
    if not order then
        order = {}
        db.ungroupedCustomBuffOrder[specID] = order
    end

    for i = #order, 1, -1 do
        local entry = order[i]
        if not registry[entry.spellID] or self:IsCustomBuffInAnyGroup(specID, entry.spellID) then
            table.remove(order, i)
        end
    end

    local seen = ungroupedSeenScratch
    table.wipe(seen)
    for _, entry in ipairs(order) do
        seen[entry.spellID] = true
    end

    for spellID in pairs(registry) do
        if not seen[spellID] and not self:IsCustomBuffInAnyGroup(specID, spellID) then
            order[#order + 1] = { spellID = spellID, afterNative = 0 }
        end
    end

    return order
end

function CDM:SetUngroupedCustomBuffOrder(specID, list)
    if not specID or not self.db then return end
    if not self.db.ungroupedCustomBuffOrder then
        self.db.ungroupedCustomBuffOrder = {}
    end
    self.db.ungroupedCustomBuffOrder[specID] = list
end

local function OnPlayerDead()
    if not next(CB.activeBuffs) then return end
    local toClear = {}
    for spellID in pairs(CB.activeBuffs) do
        toClear[#toClear + 1] = spellID
    end
    for i = 1, #toClear do
        DeactivateCustomBuff(toClear[i])
    end
end

local CUSTOM_BUFF_EVENTS = {
    UNIT_SPELLCAST_SUCCEEDED        = OnSpellCastSucceeded,
    UNIT_SPELLCAST_SENT             = OnSpellCastSent,
    UNIT_AURA                       = OnBloodlustAura,
    SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = OnGlowShow,
    SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = OnGlowHide,
    PLAYER_DEAD                     = OnPlayerDead,
}

function CDM:InitializeCustomBuffs()
    local eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        local fn = CUSTOM_BUFF_EVENTS[event]
        if fn then fn(event, ...) end
    end)
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
    eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    eventFrame:RegisterEvent("PLAYER_DEAD")

    self:RebuildGlowFilters()
end

CDM:RegisterRefreshCallback("customBuffs", function()
    CDM:UpdateCustomBuffs()
end, 50, { "BUFF_DATA", "LAYOUT", "STYLE" })
