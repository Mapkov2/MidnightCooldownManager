local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]

local Compat = CDM.CooldownViewerCompat
local IsSafeNumber = CDM.IsSafeNumber
local table_wipe = table.wipe
local type = type
local ipairs = ipairs
local GetInventoryItemID = GetInventoryItemID

local recordGeneration = 1
local recordStats = {
    frameInvalidations = 0,
    generationInvalidations = 0,
    fullInvalidations = 0,
    lastInvalidationReason = "load",
}

local function IsValidID(id)
    return IsSafeNumber(id) and id > 0
end

local function GetFirstLinkedSpellID(linkedSpellIDs)
    if type(linkedSpellIDs) ~= "table" then return nil end
    for _, linkedID in ipairs(linkedSpellIDs) do
        if IsValidID(linkedID) then
            return linkedID
        end
    end
    return nil
end

local function CallFrameMethod(frame, methodName)
    return Compat and Compat:CallFrameMethod(frame, methodName) or nil
end

local function ResolveRecordItemID(frame, info)
    if not frame then return nil end

    local itemID = frame.itemID
    if IsValidID(itemID) then return itemID end

    itemID = info and info.itemID
    if IsValidID(itemID) then return itemID end

    local equipSlot = info and info.equipSlot
    if IsValidID(equipSlot) and GetInventoryItemID then
        itemID = GetInventoryItemID("player", equipSlot)
        if IsValidID(itemID) then return itemID end
    end

    itemID = CallFrameMethod(frame, "GetItemID")
    if IsValidID(itemID) then return itemID end

    return nil
end

local function ResolveRecordBase(spellID)
    if not IsValidID(spellID) then return nil end

    local normalize = CDM.NormalizeToBase
    if normalize then
        local base = normalize(spellID)
        if IsValidID(base) then
            return base
        end
    end

    local cvBase = C_Spell and C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(spellID)
    if IsValidID(cvBase) then
        return cvBase
    end

    return spellID
end

local function ResolveCooldownInfoDisplaySpellID(info, fallbackBaseSpellID)
    if info then
        if IsValidID(info.overrideTooltipSpellID) then return info.overrideTooltipSpellID end
        if IsValidID(info.overrideSpellID) then return info.overrideSpellID end
        if IsValidID(info.spellID) then return info.spellID end

        local linkedID = GetFirstLinkedSpellID(info.linkedSpellIDs)
        if linkedID then return linkedID end
    end

    if IsValidID(fallbackBaseSpellID) then
        return fallbackBaseSpellID
    end

    return nil
end

function CDM:GetCooldownInfoDisplaySpellID(info, fallbackBaseSpellID)
    return ResolveCooldownInfoDisplaySpellID(info, fallbackBaseSpellID)
end

local function GetFrameCooldownInfo(frame, cooldownID)
    local indexEntry = cooldownID and CDM.GetCooldownIndexEntryByID and CDM:GetCooldownIndexEntryByID(cooldownID)
    if indexEntry and indexEntry.cooldownInfo then
        return indexEntry.cooldownInfo, "index", indexEntry
    end

    local info = cooldownID and CDM.GetCooldownInfoByID and CDM:GetCooldownInfoByID(cooldownID)
    if info then return info, "compat", nil end

    info = frame and frame.cooldownInfo
    if info then return info, "frame", nil end

    info = CallFrameMethod(frame, "GetCooldownInfo")
    if info then return info, "method", nil end

    return nil, nil, nil
end

local function IsFrameRecordCacheValid(frame, cooldownID)
    local info = frame and frame.cooldownInfo
    return frame.cdmCooldownRecordGen == recordGeneration
        and frame.cdmCooldownRecordID == cooldownID
        and frame.cdmCooldownRecordInfo == info
        and frame.cdmCooldownRecordRawSpellID == frame.spellID
        and frame.cdmCooldownRecordRawItemID == frame.itemID
        and frame.cdmCooldownRecordRawItemSpellID == frame.itemSpellID
        and frame.cdmCooldownRecordRawCustom == frame.isCustomBuff
end

local function StoreFrameRecordCacheKeys(frame, cooldownID)
    frame.cdmCooldownRecordGen = recordGeneration
    frame.cdmCooldownRecordID = cooldownID
    frame.cdmCooldownRecordInfo = frame.cooldownInfo
    frame.cdmCooldownRecordRawSpellID = frame.spellID
    frame.cdmCooldownRecordRawItemID = frame.itemID
    frame.cdmCooldownRecordRawItemSpellID = frame.itemSpellID
    frame.cdmCooldownRecordRawCustom = frame.isCustomBuff
end

function CDM:GetFrameCooldownRecord(frame)
    if not frame then return nil end

    local cooldownID = self.GetFrameCooldownID and self:GetFrameCooldownID(frame) or nil
    if IsFrameRecordCacheValid(frame, cooldownID) then
        return frame.cdmCooldownRecord
    end

    local info, source, indexEntry = GetFrameCooldownInfo(frame, cooldownID)
    local spellID = (indexEntry and indexEntry.spellID) or (info and info.spellID) or nil
    local overrideSpellID = (indexEntry and indexEntry.overrideSpellID) or (info and info.overrideSpellID) or nil
    local overrideTooltipSpellID = (indexEntry and indexEntry.overrideTooltipSpellID) or (info and info.overrideTooltipSpellID) or nil
    local linkedSpellIDs = (indexEntry and indexEntry.linkedSpellIDs) or (info and info.linkedSpellIDs) or nil
    local category = indexEntry and indexEntry.category or nil
    local spellCategoryID = (indexEntry and indexEntry.spellCategoryID) or (info and info.spellCategoryID) or nil
    local equipSlot = (indexEntry and indexEntry.equipSlot) or (info and info.equipSlot) or nil
    local itemID = ResolveRecordItemID(frame, info)

    if not IsValidID(spellID) then
        spellID = CallFrameMethod(frame, "GetSpellID")
    end
    if not IsValidID(spellID) and frame.isCustomBuff then
        spellID = frame.spellID
    end

    local baseSpellID = CallFrameMethod(frame, "GetBaseSpellID")
    if not IsValidID(baseSpellID) then
        baseSpellID = ResolveRecordBase(spellID)
    end

    local displaySpellID = ResolveCooldownInfoDisplaySpellID(info, baseSpellID)

    if not cooldownID and not info and not IsValidID(displaySpellID) and not IsValidID(baseSpellID) and not IsValidID(itemID) then
        self:InvalidateFrameCooldownRecord(frame)
        frame.cdmCooldownRecord = nil
        return nil
    end

    local record = frame.cdmCooldownRecord
    if type(record) ~= "table" then
        record = {}
    else
        table_wipe(record)
    end

    record.cooldownID = cooldownID
    record.cooldownInfo = info
    record.indexEntry = indexEntry
    record.cacheGeneration = recordGeneration
    record.source = source or (cooldownID and "cooldownID") or "frame"
    record.category = category
    record.spellCategoryID = IsValidID(spellCategoryID) and spellCategoryID or nil
    record.equipSlot = IsValidID(equipSlot) and equipSlot or nil
    record.isInvisible = ((indexEntry and indexEntry.isInvisible) or (info and info.isInvisible)) and true or false
    record.isKnown = ((indexEntry and indexEntry.isKnown) or (info and info.isKnown)) and true or false
    record.charges = ((indexEntry and indexEntry.charges) or (info and info.charges)) and true or false
    record.flags = (indexEntry and indexEntry.flags) or (info and info.flags) or nil
    record.rawSpellID = IsValidID(frame.spellID) and frame.spellID or nil
    record.rawItemID = IsValidID(frame.itemID) and frame.itemID or nil
    record.rawItemSpellID = IsValidID(frame.itemSpellID) and frame.itemSpellID or nil
    record.rawCustom = frame.isCustomBuff and true or false
    record.spellID = IsValidID(spellID) and spellID or nil
    record.baseSpellID = IsValidID(baseSpellID) and baseSpellID or nil
    record.itemID = IsValidID(itemID) and itemID or nil
    record.displaySpellID = IsValidID(displaySpellID) and displaySpellID or record.spellID or record.baseSpellID or GetFirstLinkedSpellID(linkedSpellIDs)
    record.preferredSpellID = record.displaySpellID
    record.overrideSpellID = IsValidID(overrideSpellID) and overrideSpellID or nil
    record.overrideTooltipSpellID = IsValidID(overrideTooltipSpellID) and overrideTooltipSpellID or nil
    record.linkedSpellIDs = linkedSpellIDs
    record.isSpellBacked = (indexEntry and indexEntry.isSpellBacked)
        or IsValidID(record.spellID)
        or IsValidID(record.baseSpellID)
        or IsValidID(record.overrideSpellID)
        or IsValidID(record.overrideTooltipSpellID)
        or IsValidID(GetFirstLinkedSpellID(linkedSpellIDs))
    record.isItemBacked = (indexEntry and indexEntry.isItemBacked)
        or IsValidID(record.itemID)
        or IsValidID(record.equipSlot)
        or IsValidID(record.spellCategoryID)

    StoreFrameRecordCacheKeys(frame, cooldownID)
    frame.cdmCooldownRecord = record
    return record
end

function CDM:GetFrameItemID(frame)
    local record = self:GetFrameCooldownRecord(frame)
    return record and record.itemID or nil
end

function CDM:ForEachFrameSpellCandidate(frame, callback)
    if type(callback) ~= "function" then return nil end

    local record = self:GetFrameCooldownRecord(frame)
    if not record then return nil end

    local function Emit(id)
        if IsValidID(id) then
            return callback(id, record)
        end
    end

    if Emit(record.displaySpellID) then return record end
    if Emit(record.overrideTooltipSpellID) then return record end
    if Emit(record.overrideSpellID) then return record end
    if Emit(record.spellID) then return record end
    if record.linkedSpellIDs then
        for _, linkedID in ipairs(record.linkedSpellIDs) do
            if Emit(linkedID) then return record end
        end
    end
    if Emit(record.baseSpellID) then return record end

    return record
end

function CDM:InvalidateFrameCooldownRecord(frame)
    if not frame then return end
    recordStats.frameInvalidations = recordStats.frameInvalidations + 1
    frame.cdmCooldownRecordGen = nil
    frame.cdmCooldownRecordID = nil
    frame.cdmCooldownRecordInfo = nil
    frame.cdmCooldownRecordRawSpellID = nil
    frame.cdmCooldownRecordRawItemID = nil
    frame.cdmCooldownRecordRawItemSpellID = nil
    frame.cdmCooldownRecordRawCustom = nil
    frame.cdmCooldownRecord = nil
end

function CDM:InvalidateFrameCooldownRecords(reason)
    recordGeneration = recordGeneration + 1
    recordStats.generationInvalidations = recordStats.generationInvalidations + 1
    recordStats.lastInvalidationReason = reason or "frame_generation"
    if self.InvalidateFrameCategoryCache then
        self:InvalidateFrameCategoryCache(reason)
    end
end

function CDM:InvalidateCooldownRecordCache(reason)
    recordGeneration = recordGeneration + 1
    recordStats.fullInvalidations = recordStats.fullInvalidations + 1
    recordStats.lastInvalidationReason = reason or "full"
    if Compat then
        Compat:Invalidate(reason)
    end
    if self.InvalidateCooldownIndex then
        self:InvalidateCooldownIndex(reason)
    end
    if self.InvalidateFrameCategoryCache then
        self:InvalidateFrameCategoryCache()
    end
end

function CDM:GetCooldownRecordDiagnostics()
    return {
        generation = recordGeneration,
        frameInvalidations = recordStats.frameInvalidations,
        generationInvalidations = recordStats.generationInvalidations,
        fullInvalidations = recordStats.fullInvalidations,
        lastInvalidationReason = recordStats.lastInvalidationReason,
    }
end
