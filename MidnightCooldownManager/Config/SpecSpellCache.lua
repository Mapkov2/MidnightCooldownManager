local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]
local API = CDM.API

local IsSafeNumber = CDM.IsSafeNumber

local HIDE_BY_DEFAULT_FLAG = Enum.CooldownSetSpellFlags and Enum.CooldownSetSpellFlags.HideByDefault
local function IsHiddenByDefault(info)
    return info and info.flags and HIDE_BY_DEFAULT_FLAG and FlagsUtil and FlagsUtil.IsSet
        and FlagsUtil.IsSet(info.flags, HIDE_BY_DEFAULT_FLAG) or false
end

local function IsValidID(id)
    return IsSafeNumber(id) and id > 0
end

local EMPTY_CATEGORY_MAP = { snapshotSet = {} }
local function GetCategoryMap()
    return CDM.GetCooldownViewerSourceCategoryMap and CDM:GetCooldownViewerSourceCategoryMap() or EMPTY_CATEGORY_MAP
end

local specEssentialCache = {}
local specUtilityCache = {}
local specBuffSpellCache = {}
local specBarSpellCache = {}

local function EnsureStorage()
    local db = MidnightCooldownManagerDB
    if not db then return nil end
    if not db.global then db.global = {} end
    if not db.global.sharedSpecCaches then db.global.sharedSpecCaches = {} end
    local s = db.global.sharedSpecCaches
    if not s.specEssentialCache then s.specEssentialCache = {} end
    if not s.specUtilityCache then s.specUtilityCache = {} end
    if not s.specBuffSpellCache then s.specBuffSpellCache = {} end
    if not s.specBarSpellCache then s.specBarSpellCache = {} end
    return s
end

function CDM:_BuildSnapshotEntry(info, cooldownID)
    if not info then return nil end
    local displaySpellID = self.GetCooldownInfoDisplaySpellID and self:GetCooldownInfoDisplaySpellID(info) or info.overrideTooltipSpellID or info.overrideSpellID or info.spellID
    local baseSpellID = IsValidID(info.spellID) and info.spellID or displaySpellID
    local linkedSpellIDs = info.linkedSpellIDs
    local hasLinkedSpell = false
    if type(linkedSpellIDs) == "table" then
        for _, linkedID in ipairs(linkedSpellIDs) do
            if IsValidID(linkedID) then
                hasLinkedSpell = true
                break
            end
        end
    end
    return {
        cooldownID = cooldownID,
        spellID = displaySpellID,
        baseSpellID = baseSpellID,
        overrideSpellID = IsValidID(info.overrideSpellID) and info.overrideSpellID or nil,
        overrideTooltipSpellID = IsValidID(info.overrideTooltipSpellID) and info.overrideTooltipSpellID or nil,
        linkedSpellIDs = linkedSpellIDs,
        spellCategoryID = info.spellCategoryID,
        equipSlot = info.equipSlot,
        isSpellBacked = IsValidID(info.spellID)
            or IsValidID(info.overrideSpellID)
            or IsValidID(info.overrideTooltipSpellID)
            or hasLinkedSpell,
        isItemBacked = IsValidID(info.equipSlot) or IsValidID(info.spellCategoryID),
        isInvisible = info.isInvisible or false,
        hidden = IsHiddenByDefault(info),
        charges = info.charges or false,
    }
end

local function AppendSnapshotList(target, source)
    if not source or #source == 0 then return target end
    if not target then target = {} end
    for _, entry in ipairs(source) do
        target[#target + 1] = entry
    end
    return target
end

local function BuildSnapshotBucket(snapshotLists, ...)
    local bucket
    for i = 1, select("#", ...) do
        local category = select(i, ...)
        if category ~= nil then
            bucket = AppendSnapshotList(bucket, snapshotLists and snapshotLists[category])
        end
    end
    return bucket
end

function CDM:_PersistSpecSnapshots(specID, snapshotLists)
    if not specID then return end
    local categoryMap = GetCategoryMap()
    local essential = BuildSnapshotBucket(snapshotLists, categoryMap.essential, categoryMap.equipEssential, categoryMap.specAgnosticEssential)
    local utility   = BuildSnapshotBucket(snapshotLists, categoryMap.utility, categoryMap.equipTracked, categoryMap.specAgnosticTracked)
    local buff      = BuildSnapshotBucket(snapshotLists, categoryMap.buff)
    local bar       = BuildSnapshotBucket(snapshotLists, categoryMap.bar)

    if essential and #essential == 0 then essential = nil end
    if utility and #utility == 0 then utility = nil end
    if buff and #buff == 0 then buff = nil end
    if bar and #bar == 0 then bar = nil end

    specEssentialCache[specID] = essential
    specUtilityCache[specID]   = utility
    specBuffSpellCache[specID] = buff
    specBarSpellCache[specID]  = bar

    local storage = EnsureStorage()
    if storage then
        storage.specEssentialCache[specID] = essential
        storage.specUtilityCache[specID]   = utility
        storage.specBuffSpellCache[specID] = buff
        storage.specBarSpellCache[specID]  = bar
    end
end

function API:GetSpecEssentialCache(specID)
    local cached = specEssentialCache[specID]
    if cached then return cached end
    local storage = EnsureStorage()
    return storage and storage.specEssentialCache[specID]
end

function API:GetSpecUtilityCache(specID)
    local cached = specUtilityCache[specID]
    if cached then return cached end
    local storage = EnsureStorage()
    return storage and storage.specUtilityCache[specID]
end

function API:GetSpecBuffSpellCache(specID)
    local cached = specBuffSpellCache[specID]
    if cached then return cached end
    local storage = EnsureStorage()
    return storage and storage.specBuffSpellCache[specID]
end

function API:GetSpecBarSpellCache(specID)
    local cached = specBarSpellCache[specID]
    if cached then return cached end
    local storage = EnsureStorage()
    return storage and storage.specBarSpellCache[specID]
end
