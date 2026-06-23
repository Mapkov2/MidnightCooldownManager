local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]

local COLOR_REGISTRY = {}

local lastRefreshSpecID = nil

local IsSafeNumber = CDM.IsSafeNumber
local table_wipe = table.wipe
local ipairs = ipairs

local function IsUsableID(id)
    return IsSafeNumber(id) and id > 0
end

local EMPTY_CATEGORY_MAP = { snapshotSet = {} }
local function GetCategoryMap()
    return CDM.GetCooldownViewerSourceCategoryMap and CDM:GetCooldownViewerSourceCategoryMap() or EMPTY_CATEGORY_MAP
end
local GROUP_MATCH_OPTS = { validator = IsUsableID }

local function AddCandidate(list, seen, id)
    if not IsUsableID(id) then return end
    if not seen[id] then
        list[#list + 1] = id
        seen[id] = true
    end
end

local spellCandidateList = {}
local spellCandidateSeen = {}

function CDM:GetSpellIDCandidates(frame)
    table_wipe(spellCandidateList)
    table_wipe(spellCandidateSeen)
    if not frame then return spellCandidateList end

    if self.ForEachFrameSpellCandidate then
        self:ForEachFrameSpellCandidate(frame, function(id)
            AddCandidate(spellCandidateList, spellCandidateSeen, id)
        end)
    end

    return spellCandidateList
end

function CDM:ForEachActiveFrame(viewers, fn)
    if self.ForEachCooldownViewerActiveFrame then
        return self:ForEachCooldownViewerActiveFrame(viewers, fn)
    end
end

local buffGlowCandidateList = {}
local buffGlowCandidateSeen = {}

local function AddBuffGlowCandidate(id)
    if not IsUsableID(id) then return end
    if buffGlowCandidateSeen[id] then return end
    buffGlowCandidateSeen[id] = true
    buffGlowCandidateList[#buffGlowCandidateList + 1] = id
end

function CDM:ResolveBuffGlowState(frame, specID, preferCategory)
    if not frame or not specID then
        return false, nil, nil
    end
    if not self.GetSpellGlowEnabled or not self.GetSpellGlowColor then
        return false, nil, nil
    end

    table_wipe(buffGlowCandidateList)
    table_wipe(buffGlowCandidateSeen)

    local groupedID = frame.cdmBuffCategorySpellID
    if preferCategory then
        AddBuffGlowCandidate(groupedID)
    end

    if self.ForEachFrameSpellCandidate then
        self:ForEachFrameSpellCandidate(frame, AddBuffGlowCandidate)
    end

    if not preferCategory then
        AddBuffGlowCandidate(groupedID)
    end

    for _, id in ipairs(buffGlowCandidateList) do
        if self:GetSpellGlowEnabled(specID, id) then
            local glowColor = self:GetSpellGlowColor(specID, id)
            frame.cdmBuffGlowSourceID = id
            return true, glowColor, id
        end
    end

    frame.cdmBuffGlowSourceID = nil
    return false, nil, nil
end

CDM.SpellSets = {
    colors = COLOR_REGISTRY,
    hasBuffGlows = false,
}

local function GetOverrideIfDifferent(spellID)
    if not IsUsableID(spellID) or not C_Spell.GetOverrideSpell then return nil end
    local id = C_Spell.GetOverrideSpell(spellID)
    if IsUsableID(id) and id ~= spellID then
        return id
    end
    return nil
end

local function GetEffectiveSpellID(spellID)
    if not spellID then return spellID end
    return GetOverrideIfDifferent(spellID) or spellID
end

CDM.GetOverrideIfDifferent = GetOverrideIfDifferent
CDM.GetEffectiveSpellID = GetEffectiveSpellID

local normalizeBaseCache = {}
local normalizeBaseCacheSize = 0
local MAX_NORMALIZE_CACHE_ENTRIES = 4096

local function CacheNormalizedBase(id, resolved)
    if normalizeBaseCache[id] == nil then
        normalizeBaseCacheSize = normalizeBaseCacheSize + 1
        if normalizeBaseCacheSize > MAX_NORMALIZE_CACHE_ENTRIES then
            table_wipe(normalizeBaseCache)
            normalizeBaseCacheSize = 1
        end
    end
    normalizeBaseCache[id] = resolved
end

function CDM:ClearNormalizationCache()
    table_wipe(normalizeBaseCache)
    normalizeBaseCacheSize = 0
    self.spellCacheGeneration = (self.spellCacheGeneration or 0) + 1
end

local function NormalizeToBase(id)
    if not IsUsableID(id) then return nil end

    if normalizeBaseCache[id] ~= nil then
        return normalizeBaseCache[id]
    end

    local baseID = C_Spell.GetBaseSpell(id)
    if IsUsableID(baseID) and baseID ~= id then
        CacheNormalizedBase(id, baseID)
        return baseID
    end

    CacheNormalizedBase(id, id)
    return id
end

CDM.NormalizeToBase = NormalizeToBase

local function GetBaseSpellIfDifferent(spellID)
    if not IsUsableID(spellID) then return nil end
    local base = NormalizeToBase(spellID)
    return (base and base ~= spellID) and base or nil
end

local scratchMatchCandidates = {}
local scratchMatchSeen = {}
local scratchMatchCandidatesAlt = {}
local scratchMatchSeenAlt = {}
local scratchMatchShared = {}

local function BuildBuffGroupMatchCandidatesInto(spellID, out, outSeen)
    table_wipe(out)
    table_wipe(outSeen)
    if not IsUsableID(spellID) then return out end

    AddCandidate(out, outSeen, spellID)

    local baseID = GetBaseSpellIfDifferent(spellID)
    if baseID then
        AddCandidate(out, outSeen, baseID)
    end

    local overrideID = GetOverrideIfDifferent(spellID)
    if overrideID then
        AddCandidate(out, outSeen, overrideID)
        AddCandidate(out, outSeen, GetBaseSpellIfDifferent(overrideID))
    end

    if baseID then
        AddCandidate(out, outSeen, GetOverrideIfDifferent(baseID))
    end

    return out
end

function CDM:ForEachSpellMatchCandidate(spellID, fn)
    if not fn then return end
    local list = BuildBuffGroupMatchCandidatesInto(spellID, scratchMatchCandidatesAlt, scratchMatchSeenAlt)
    for _, key in ipairs(list) do
        if fn(key) then return end
    end
end

local function MatchCooldownInfo(info, spellToTarget, opts)
    return CDM.MatchCooldownInfoToGroup and CDM:MatchCooldownInfoToGroup(info, spellToTarget, opts) or nil
end

function CDM:GetPreferredBuffGroupSpellID(frame)
    if not frame then return nil end
    local candidates = self:GetSpellIDCandidates(frame)
    return candidates and candidates[1] or nil
end

function CDM:GetBuffOverrideStorageKey(spellID)
    if not IsUsableID(spellID) then
        return nil
    end
    return NormalizeToBase(spellID)
end

local function CopyOverrideEntry(entry)
    if type(entry) ~= "table" then return entry end

    local copy = {}
    for key, value in pairs(entry) do
        if type(value) == "table" then
            local subCopy = {}
            for subKey, subValue in pairs(value) do
                subCopy[subKey] = subValue
            end
            copy[key] = subCopy
        else
            copy[key] = value
        end
    end

    return copy
end

function CDM:CopyBuffOverrideEntry(entry)
    return CopyOverrideEntry(entry)
end

local function MergeMissingOverrideFields(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then return end

    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = CopyOverrideEntry(value)
        end
    end
end

function CDM:MergeMissingBuffOverrideFields(target, source)
    MergeMissingOverrideFields(target, source)
end

local function CollectMergedBuffOverrideEntry(overrideMap, spellID, removeEntries)
    if type(overrideMap) ~= "table" or not IsUsableID(spellID) then
        return nil, {}
    end

    local keys = BuildBuffGroupMatchCandidatesInto(spellID, scratchMatchCandidates, scratchMatchSeen)
    local merged
    for _, key in ipairs(keys) do
        local entry = overrideMap[key]
        if type(entry) == "table" then
            if not merged then
                merged = CopyOverrideEntry(entry)
            else
                MergeMissingOverrideFields(merged, entry)
            end
            if removeEntries then
                overrideMap[key] = nil
            end
        end
    end

    return merged, keys
end

function CDM:ResolveBuffOverrideEntry(overrideMap, spellID)
    if type(overrideMap) ~= "table" or not IsUsableID(spellID) then
        return nil
    end

    for _, key in ipairs(BuildBuffGroupMatchCandidatesInto(spellID, scratchMatchCandidates, scratchMatchSeen)) do
        local entry = overrideMap[key]
        if type(entry) == "table" then
            return entry
        end
    end

    return nil
end

CDM.ResolveBarOverrideEntry = CDM.ResolveBuffOverrideEntry

function CDM:GetMergedBuffOverrideEntry(overrideMap, spellID)
    return (CollectMergedBuffOverrideEntry(overrideMap, spellID, false))
end

function CDM:EnsureBuffOverrideEntry(overrideMap, spellID)
    if type(overrideMap) ~= "table" or not IsUsableID(spellID) then
        return nil
    end

    local target, keys = CollectMergedBuffOverrideEntry(overrideMap, spellID, false)
    local storageKey = self:GetBuffOverrideStorageKey(spellID)
    if not IsUsableID(storageKey) then
        return nil
    end

    if not target then
        target = {}
    end

    overrideMap[storageKey] = target
    for _, key in ipairs(keys) do
        if key ~= storageKey then
            overrideMap[key] = nil
        end
    end

    return target
end

function CDM:ExtractMergedBuffOverrideEntry(overrideMap, spellID)
    return (CollectMergedBuffOverrideEntry(overrideMap, spellID, true))
end

function CDM:StoreMergedBuffOverrideEntry(overrideMap, spellID, incoming)
    if type(overrideMap) ~= "table" or type(incoming) ~= "table" or not IsUsableID(spellID) then
        return
    end

    local storageKey = self:GetBuffOverrideStorageKey(spellID)
    if not IsUsableID(storageKey) then
        return
    end

    for _, key in ipairs(BuildBuffGroupMatchCandidatesInto(spellID, scratchMatchCandidates, scratchMatchSeen)) do
        if key ~= storageKey then
            overrideMap[key] = nil
        end
    end

    overrideMap[storageKey] = CopyOverrideEntry(incoming)
end

local EMPTY_SET = {}

local function CheckIDAgainstGroupSet(id, groupSet)
    if not IsUsableID(id) then return nil, nil end
    if groupSet[id] then return id, groupSet[id] end
    return nil, nil
end

local function CheckIDAgainstRegistry(id)
    local buffSets = CDM.BuffGroupSets
    local matchID, groupIdx = CheckIDAgainstGroupSet(id, buffSets and buffSets.grouped or EMPTY_SET)
    if matchID then return "buffgroup", matchID, groupIdx end

    local barSets = CDM.BarGroupSets
    matchID, groupIdx = CheckIDAgainstGroupSet(id, barSets and barSets.grouped or EMPTY_SET)
    if matchID then return "bargroup", matchID, groupIdx end

    return nil, nil
end

CDM.CheckIDAgainstRegistry = CheckIDAgainstRegistry

local function GetColorForSpellID(id)
    if not IsUsableID(id) then return nil end
    if not next(COLOR_REGISTRY) then return nil end
    if COLOR_REGISTRY[id] then return COLOR_REGISTRY[id] end
    local base = NormalizeToBase(id)
    if base and base ~= id and COLOR_REGISTRY[base] then return COLOR_REGISTRY[base] end
    local stable = CDM.ResolveStableBase and CDM:ResolveStableBase(id)
    if stable and stable ~= id and stable ~= base and COLOR_REGISTRY[stable] then return COLOR_REGISTRY[stable] end
    return nil
end

CDM.GetColorForSpellID = GetColorForSpellID

local function GetBaseSpellID(frame)
    if not frame then return nil end

    local record = CDM.GetFrameCooldownRecord and CDM:GetFrameCooldownRecord(frame)
    if record then
        if record.cooldownInfo and IsUsableID(record.spellID) then
            return record.spellID
        end
        if IsUsableID(record.baseSpellID) then
            return record.baseSpellID
        end
        if IsUsableID(record.spellID) then
            return NormalizeToBase(record.spellID)
        end
    end

    return nil
end

CDM.GetBaseSpellID = GetBaseSpellID

local function CheckCooldownGroupMatch(frame, cdidGroupSet, spellGroupSet, cacheKey)
    if CDM.MatchFrameCooldownGroup then
        return CDM:MatchFrameCooldownGroup(frame, cdidGroupSet, spellGroupSet, cacheKey)
    end
    return nil, nil
end

function CDM.CheckCdGroupMatch(frame)
    local sets = CDM.CooldownGroupSets
    local cdidSet = sets and sets.cooldownIDGrouped or EMPTY_SET
    local spellSet = sets and sets.grouped or EMPTY_SET
    local _, groupIdx = CheckCooldownGroupMatch(frame, cdidSet, spellSet, "cdmCdGroupSpellID")
    return groupIdx
end

local function CheckBarRegistryMatch(frame)
    local sets = CDM.BarGroupSets
    local cdidSet = sets and sets.cooldownIDGrouped or EMPTY_SET
    local spellSet = sets and sets.grouped or EMPTY_SET
    local matchID, groupIdx = CheckCooldownGroupMatch(frame, cdidSet, spellSet, "cdmBarGroupSpellID")
    if matchID then return "bargroup", matchID, groupIdx end
    return nil, nil
end

CDM.CheckBarRegistryMatch = CheckBarRegistryMatch

function CDM:GetBarRegistryMatch(frame)
    return CheckBarRegistryMatch(frame)
end

local function CheckBuffRegistryMatch(frame)
    local sets = CDM.BuffGroupSets
    local cdidSet = sets and sets.cooldownIDGrouped or EMPTY_SET
    local spellSet = sets and sets.grouped or EMPTY_SET
    local matchID, groupIdx = CheckCooldownGroupMatch(frame, cdidSet, spellSet, "cdmBuffCategorySpellID")
    if matchID then return "buffgroup", matchID, groupIdx end
    return nil, nil
end

CDM.CheckBuffRegistryMatch = CheckBuffRegistryMatch

function CDM:GetBuffRegistryMatch(frame)
    return CheckBuffRegistryMatch(frame)
end

function CDM:MarkSpecDataDirty()
    lastRefreshSpecID = nil
end

function CDM:RefreshSpecData()
    local specIndex = GetSpecialization()
    if not specIndex then
        self.SpellSets.hasBuffGlows = false
        return
    end

    local specID = GetSpecializationInfo(specIndex)
    if not specID then
        self.SpellSets.hasBuffGlows = false
        return
    end

    if specID == lastRefreshSpecID then return end

    if not self:IsCooldownViewerDataReady() then
        return
    end

    table_wipe(COLOR_REGISTRY)
    self.SpellSets.hasBuffGlows = false

    self:ClearNormalizationCache()
    if self.ClearStableBaseCache then self:ClearStableBaseCache() end
    self:InvalidateFrameCategoryCache()
    if self.RebuildCooldownIndex then
        self:RebuildCooldownIndex("RefreshSpecData")
    end

    local rawSpellRegistry = self.db and self.db.spellRegistry
    local rawSpecRegistry = rawSpellRegistry and rawSpellRegistry[specID]

    local rawColors = rawSpecRegistry and rawSpecRegistry.colors
    if rawColors then
        for id, color in pairs(rawColors) do
            COLOR_REGISTRY[id] = color
        end
    end

    self.SpellSets.hasBuffGlows = type(rawSpecRegistry and rawSpecRegistry.glowEnabled) == "table"
        and next(rawSpecRegistry.glowEnabled) ~= nil or false

    local previousCdMatches
    if self.CooldownGroupSets and self.CooldownGroupSets.cooldownIDGrouped then
        previousCdMatches = {}
        for cdID, entry in pairs(self.CooldownGroupSets.cooldownIDGrouped) do
            previousCdMatches[cdID] = entry
        end
    end

    local buffSpellToGroup = self._BuildBuffGroupSpellMap and self:_BuildBuffGroupSpellMap() or {}
    local barSpellToGroup  = self._BuildBarGroupSpellMap and self:_BuildBarGroupSpellMap() or {}
    local cdSpellToGroup   = self._BuildCdGroupSpellMap and self:_BuildCdGroupSpellMap() or {}

    if self._auraOverlayEnabled then table_wipe(self._auraOverlayEnabled) end
    if self._readyGlowCooldownIDs then table_wipe(self._readyGlowCooldownIDs) end
    local auraSpellToEntry = self._BuildAuraOverlaySpellMap and self:_BuildAuraOverlaySpellMap(specID) or {}

    local groupOpts = GROUP_MATCH_OPTS
    local auraOpts = self.AURA_OVERLAY_MATCH_OPTS
    local categoryMap = GetCategoryMap()
    local snapshotCats = categoryMap.snapshotSet
    local buffSets = self.BuffGroupSets
    local barSets = self.BarGroupSets
    local cdSets = self.CooldownGroupSets
    local auraMap = self._auraOverlayEnabled
    local readyGlowSet = self._readyGlowCooldownIDs

    local catEss = categoryMap.essential
    local catUti = categoryMap.utility

    local snapshotLists = {}

    if groupOpts and self.ForEachCooldownViewerInfo then
        local currentSnapshotCat
        local currentSnapList
        self:ForEachCooldownViewerInfo(function(cdID, info, cat, entry)
            local snapshotCat = (entry and entry.sourceCategory) or cat
            if currentSnapshotCat ~= snapshotCat then
                currentSnapshotCat = snapshotCat
                currentSnapList = nil
                if snapshotCats[snapshotCat] then
                    currentSnapList = snapshotLists[snapshotCat]
                    if not currentSnapList then
                        currentSnapList = {}
                        snapshotLists[snapshotCat] = currentSnapList
                    end
                end
            end

            if buffSets then
                local buffMatch = MatchCooldownInfo(info, buffSpellToGroup, groupOpts)
                if buffMatch then buffSets.cooldownIDGrouped[cdID] = buffMatch end
            end

            if barSets then
                local barMatch = MatchCooldownInfo(info, barSpellToGroup, groupOpts)
                if barMatch then barSets.cooldownIDGrouped[cdID] = barMatch end
            end

            if cdSets then
                local cdMatch = MatchCooldownInfo(info, cdSpellToGroup, groupOpts)
                if cdMatch then cdSets.cooldownIDGrouped[cdID] = cdMatch end
            end

            if auraOpts and auraMap and (cat == catEss or cat == catUti) then
                local auraMatch = MatchCooldownInfo(info, auraSpellToEntry, auraOpts)
                if auraMatch then
                    auraMap[cdID] = auraMatch
                    if auraMatch.readyGlowEnabled and readyGlowSet then
                        readyGlowSet[cdID] = true
                    end
                end
            end

            if currentSnapList and self._BuildSnapshotEntry then
                currentSnapList[#currentSnapList + 1] = self:_BuildSnapshotEntry(info, cdID)
            end
        end)
    end

    if previousCdMatches and cdSets then
        for cdID, entry in pairs(previousCdMatches) do
            local current = cdSpellToGroup[entry.storedID]
            if not cdSets.cooldownIDGrouped[cdID] and current then
                cdSets.cooldownIDGrouped[cdID] = current
            end
        end
    end

    if self.InvalidateStaticGroupsCache then self:InvalidateStaticGroupsCache() end
    if self._PostAuraOverlayBuild then self:_PostAuraOverlayBuild() end
    if self._PersistSpecSnapshots then self:_PersistSpecSnapshots(specID, snapshotLists) end

    lastRefreshSpecID = specID
end

function CDM:InstallSpellCacheAcquireResetHook(v)
    CDM:InstallCooldownViewerAcquireCallback(v, "spellCache", function(itemFrame)
        if CDM.InvalidateFrameCooldownRecord then
            CDM:InvalidateFrameCooldownRecord(itemFrame)
        end
        itemFrame.cdmBuffCategorySpellID = nil
        itemFrame.cdmBarGroupSpellID = nil
        itemFrame.cdmCdGroupSpellID = nil
        itemFrame.cdmCategoryCacheGen = nil
    end)
end
