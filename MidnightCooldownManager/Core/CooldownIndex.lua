local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]

local Compat = CDM.CooldownViewerCompat
local IsSafeNumber = CDM.IsSafeNumber
local table_wipe = table.wipe
local GetTime = GetTime

local index = {
    byCooldownID = {},
    bySpellID = {},
    orderedEntries = {},
    categoryCounts = {},
    totalCooldowns = 0,
    totalSpellKeys = 0,
    displaySpellRecords = 0,
    nonSpellRecords = 0,
    spellBackedRecords = 0,
    itemBackedRecords = 0,
    equipSlotRecords = 0,
    invisibleRecords = 0,
    duplicateCooldowns = 0,
    generation = 0,
    compatGeneration = 0,
    dirty = true,
    lastBuildReason = "load",
    lastBuildTime = 0,
}

local CATEGORY_SOURCE_KINDS = {
    active = {
        "Essential",
        "Utility",
        "EquipSlotEssential",
        "EquipSlotTracked",
        "SpecAgnosticEssential",
        "SpecAgnosticTracked",
    },
    buff = {
        "TrackedBuff",
    },
    bar = {
        "TrackedBar",
    },
    aura = {
        "TrackedBuff",
        "TrackedBar",
    },
}

local categorySetCache = {
    compatGeneration = -1,
    sets = {},
}

local function IsValidID(id)
    return IsSafeNumber(id) and id > 0
end

local function HasValidLinkedSpell(linkedSpellIDs)
    if type(linkedSpellIDs) ~= "table" then return false end
    for _, linkedID in ipairs(linkedSpellIDs) do
        if IsValidID(linkedID) then
            return true
        end
    end
    return false
end

local function AddSpellKey(entry, spellID)
    if not IsValidID(spellID) then return end
    local list = index.bySpellID[spellID]
    if not list then
        list = {}
        index.bySpellID[spellID] = list
        index.totalSpellKeys = index.totalSpellKeys + 1
    end
    list[#list + 1] = entry
end

local function ResetIndex(reason)
    table_wipe(index.byCooldownID)
    table_wipe(index.bySpellID)
    table_wipe(index.orderedEntries)
    table_wipe(index.categoryCounts)
    index.totalCooldowns = 0
    index.totalSpellKeys = 0
    index.displaySpellRecords = 0
    index.nonSpellRecords = 0
    index.spellBackedRecords = 0
    index.itemBackedRecords = 0
    index.equipSlotRecords = 0
    index.invisibleRecords = 0
    index.duplicateCooldowns = 0
    index.generation = index.generation + 1
    index.compatGeneration = Compat and Compat:GetGeneration() or 0
    index.dirty = false
    index.lastBuildReason = reason or "rebuild"
    index.lastBuildTime = GetTime and GetTime() or 0
end

local function ResetCategorySetCache(compatGeneration)
    table_wipe(categorySetCache.sets)
    categorySetCache.compatGeneration = compatGeneration or (Compat and Compat:GetGeneration() or 0)
end

local function AddEntryCategory(entry, category, sourceCategory)
    if category ~= nil and entry.category ~= category then
        local categories = entry.categories
        if not categories then
            categories = { [entry.category] = true }
            entry.categories = categories
        end
        categories[category] = true
    end

    if sourceCategory ~= nil and entry.sourceCategory ~= sourceCategory then
        local sourceCategories = entry.sourceCategories
        if not sourceCategories then
            sourceCategories = { [entry.sourceCategory] = true }
            entry.sourceCategories = sourceCategories
        end
        sourceCategories[sourceCategory] = true
    end
end

function CDM:InvalidateCooldownIndex(reason)
    index.dirty = true
    index.lastBuildReason = reason or "invalidated"
    ResetCategorySetCache()
end

function CDM:RebuildCooldownIndex(reason)
    ResetIndex(reason)

    if not Compat then
        return index
    end

    Compat:ForEachCooldownInfo(function(cooldownID, info, category, sourceCategory)
        local normalizedID = Compat:NormalizeCooldownID(cooldownID)
        if not normalizedID then return end

        index.categoryCounts[category] = (index.categoryCounts[category] or 0) + 1

        local existing = index.byCooldownID[normalizedID]
        if existing then
            index.duplicateCooldowns = index.duplicateCooldowns + 1
            AddEntryCategory(existing, category, sourceCategory or category)
            return
        end

        local entry = {
            cooldownID = normalizedID,
            cooldownInfo = info,
            category = category,
            sourceCategory = sourceCategory or category,
            spellID = IsValidID(info.spellID) and info.spellID or nil,
            overrideSpellID = IsValidID(info.overrideSpellID) and info.overrideSpellID or nil,
            overrideTooltipSpellID = IsValidID(info.overrideTooltipSpellID) and info.overrideTooltipSpellID or nil,
            spellCategoryID = IsValidID(info.spellCategoryID) and info.spellCategoryID or nil,
            equipSlot = IsValidID(info.equipSlot) and info.equipSlot or nil,
            isInvisible = info.isInvisible and true or false,
            isKnown = info.isKnown and true or false,
            charges = info.charges and true or false,
            flags = info.flags,
            linkedSpellIDs = info.linkedSpellIDs,
        }
        entry.displaySpellID = CDM.GetCooldownInfoDisplaySpellID and CDM:GetCooldownInfoDisplaySpellID(info) or entry.overrideTooltipSpellID or entry.overrideSpellID or entry.spellID
        entry.isSpellBacked = IsValidID(entry.spellID)
            or IsValidID(entry.overrideSpellID)
            or IsValidID(entry.overrideTooltipSpellID)
            or HasValidLinkedSpell(entry.linkedSpellIDs)
        entry.isItemBacked = IsValidID(entry.equipSlot) or IsValidID(entry.spellCategoryID)

        index.byCooldownID[normalizedID] = entry
        index.orderedEntries[#index.orderedEntries + 1] = entry
        index.totalCooldowns = index.totalCooldowns + 1
        if entry.displaySpellID then index.displaySpellRecords = index.displaySpellRecords + 1 end
        if not entry.spellID then index.nonSpellRecords = index.nonSpellRecords + 1 end
        if entry.isSpellBacked then index.spellBackedRecords = index.spellBackedRecords + 1 end
        if entry.isItemBacked then index.itemBackedRecords = index.itemBackedRecords + 1 end
        if entry.equipSlot then index.equipSlotRecords = index.equipSlotRecords + 1 end
        if entry.isInvisible then index.invisibleRecords = index.invisibleRecords + 1 end

        AddSpellKey(entry, entry.displaySpellID)
        AddSpellKey(entry, entry.overrideTooltipSpellID)
        AddSpellKey(entry, entry.overrideSpellID)
        AddSpellKey(entry, entry.spellID)
        if entry.linkedSpellIDs then
            for _, linkedID in ipairs(entry.linkedSpellIDs) do
                AddSpellKey(entry, linkedID)
            end
        end
    end)

    ResetCategorySetCache(index.compatGeneration)
    return index
end

function CDM:GetCooldownIndex()
    local compatGeneration = Compat and Compat:GetGeneration() or 0
    if index.dirty or index.compatGeneration ~= compatGeneration then
        self:RebuildCooldownIndex(index.lastBuildReason or "lazy")
    end
    return index
end

function CDM:GetCooldownIndexEntryByID(cooldownID)
    if not Compat then return nil end
    cooldownID = Compat:NormalizeCooldownID(cooldownID)
    if not cooldownID then return nil end
    return self:GetCooldownIndex().byCooldownID[cooldownID]
end

function CDM:GetCooldownIndexEntriesForSpell(spellID)
    if not IsValidID(spellID) then return nil end
    return self:GetCooldownIndex().bySpellID[spellID]
end

function CDM:ForEachCooldownIndexEntry(callback)
    if type(callback) ~= "function" then return end
    for _, entry in ipairs(self:GetCooldownIndex().orderedEntries) do
        if callback(entry.cooldownID, entry) then
            return true
        end
    end
end

local function GetCategorySet(kind)
    if not Compat then return nil end

    local compatGeneration = Compat:GetGeneration()
    if categorySetCache.compatGeneration ~= compatGeneration then
        ResetCategorySetCache(compatGeneration)
    end

    local cached = categorySetCache.sets[kind]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local categoryNames = CATEGORY_SOURCE_KINDS[kind]
    if type(categoryNames) ~= "table" then
        categorySetCache.sets[kind] = false
        return nil
    end

    local set = {}
    for _, categoryName in ipairs(categoryNames) do
        local category = Compat:GetCategoryByName(categoryName)
        if category then
            set[category] = true
        end
    end

    if next(set) then
        categorySetCache.sets[kind] = set
        return set
    end

    categorySetCache.sets[kind] = false
    return nil
end

local function EntryMatchesCategorySet(entry, categorySet)
    if categorySet[entry.sourceCategory] then return true end

    local sourceCategories = entry.sourceCategories
    if sourceCategories then
        for category in pairs(sourceCategories) do
            if categorySet[category] then return true end
        end
    end

    return false
end

function CDM:ForEachCooldownIndexEntryBySourceKind(kind, callback, opts)
    if type(callback) ~= "function" then return end

    local categorySet = GetCategorySet(kind)
    if not categorySet then return end

    local includeInvisible = opts and opts.includeInvisible
    return self:ForEachCooldownIndexEntry(function(cooldownID, entry)
        if EntryMatchesCategorySet(entry, categorySet) and (includeInvisible or not entry.isInvisible) then
            return callback(cooldownID, entry)
        end
    end)
end

function CDM:ForEachCooldownViewerInfo(callback)
    if type(callback) ~= "function" then return end
    return self:ForEachCooldownIndexEntry(function(cooldownID, entry)
        return callback(cooldownID, entry.cooldownInfo, entry.category, entry)
    end)
end

function CDM:ForEachCooldownViewerInfoByKind(kind, callback, opts)
    if type(callback) ~= "function" then return end
    return self:ForEachCooldownIndexEntryBySourceKind(kind, function(cooldownID, entry)
        return callback(cooldownID, entry.cooldownInfo, entry.category, entry)
    end, opts)
end

function CDM:GetCooldownIndexDiagnostics()
    local current = self:GetCooldownIndex()
    return {
        generation = current.generation,
        compatGeneration = current.compatGeneration,
        dirty = current.dirty,
        totalCooldowns = current.totalCooldowns,
        totalSpellKeys = current.totalSpellKeys,
        displaySpellRecords = current.displaySpellRecords,
        nonSpellRecords = current.nonSpellRecords,
        spellBackedRecords = current.spellBackedRecords,
        itemBackedRecords = current.itemBackedRecords,
        equipSlotRecords = current.equipSlotRecords,
        invisibleRecords = current.invisibleRecords,
        duplicateCooldowns = current.duplicateCooldowns,
        lastBuildReason = current.lastBuildReason,
        lastBuildTime = current.lastBuildTime,
        categoryCounts = current.categoryCounts,
        categorySetCacheGeneration = categorySetCache.compatGeneration,
    }
end
