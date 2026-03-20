-- ########################################################
-- MSA_KeyHelpers.lua
-- Key type helpers, display name, icon lookup
--
-- v2: Optimized string matching: string.find with plain flag
--     and string.sub instead of string.match (regex) for
--     hot-path key type checks.
-- ########################################################

local tonumber, tostring, type = tonumber, tostring, type
local GetItemInfo = GetItemInfo
local GetItemIcon = GetItemIcon
local strfind = string.find
local strsub  = string.sub
local strmatch = string.match

local DRAFT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-----------------------------------------------------------
-- Key type checks (v2: optimized with find+sub)
-----------------------------------------------------------

function MSWA_IsItemKey(key)
    if type(key) ~= "string" then return false end
    -- Check for "item:" prefix; accepts "item:123" and "item:123:N"
    if strsub(key, 1, 5) ~= "item:" then return false end
    local rest = strsub(key, 6)
    if rest == "" then return false end
    return strmatch(rest, "^%d+$") ~= nil or strmatch(rest, "^%d+:%d+$") ~= nil
end

function MSWA_IsItemInstanceKey(key)
    if type(key) ~= "string" then return false end
    return strmatch(key, "^item:%d+:%d+$") ~= nil
end

function MSWA_KeyToItemID(key)
    if type(key) ~= "string" then return nil end
    if strsub(key, 1, 5) ~= "item:" then return nil end
    local id = strmatch(key, "^item:(%d+)")
    return tonumber(id)
end

function MSWA_NewItemInstanceKey(itemID)
    local db = MSWA_GetDB()
    db._instanceCounter = (db._instanceCounter or 0) + 1
    return ("item:%d:%d"):format(itemID, db._instanceCounter)
end

function MSWA_IsDraftKey(key)
    if type(key) ~= "string" then return false end
    if strsub(key, 1, 6) ~= "DRAFT:" then return false end
    local rest = strsub(key, 7)
    return rest ~= "" and strmatch(rest, "^%d+$") ~= nil
end

function MSWA_NewDraftKey()
    local db = MSWA_GetDB()
    db._draftCounter = (db._draftCounter or 0) + 1
    return ("DRAFT:%d"):format(db._draftCounter)
end

function MSWA_IsSpellInstanceKey(key)
    if type(key) ~= "string" then return false end
    if strsub(key, 1, 6) ~= "spell:" then return false end
    -- Must match spell:NUMBER:NUMBER
    return strmatch(key, "^spell:%d+:%d+$") ~= nil
end

function MSWA_KeyToSpellID(key)
    if type(key) == "number" then return key end
    if type(key) == "string" then
        if strsub(key, 1, 6) ~= "spell:" then return nil end
        local id = strmatch(key, "^spell:(%d+):%d+$")
        if id then return tonumber(id) end
    end
    return nil
end

function MSWA_NewSpellInstanceKey(spellID)
    local db = MSWA_GetDB()
    db._instanceCounter = (db._instanceCounter or 0) + 1
    return ("spell:%d:%d"):format(spellID, db._instanceCounter)
end

function MSWA_IsSpellKey(key)
    return type(key) == "number" or MSWA_IsSpellInstanceKey(key)
end

-----------------------------------------------------------
-- Trinket key checks
-----------------------------------------------------------

function MSWA_IsTrinketKey(key)
    return key == "trinket:13" or key == "trinket:14"
end

function MSWA_KeyToTrinketSlot(key)
    if key == "trinket:13" then return 13 end
    if key == "trinket:14" then return 14 end
    return nil
end

--- Returns the equipped item ID for a trinket slot, or nil
function MSWA_GetTrinketItemID(slot)
    if not slot then return nil end
    if GetInventoryItemID then
        return GetInventoryItemID("player", slot)
    end
    return nil
end

-----------------------------------------------------------
-- Auto Buff check
-----------------------------------------------------------

function MSWA_IsAutoBuff(key)
    if key == nil then return false end
    local db = MSWA_GetDB()
    if not db or not db.spellSettings then return false end
    local s = db.spellSettings[key] or db.spellSettings[tostring(key)]
    return s and (s.auraMode == "AUTOBUFF" or s.auraMode == "BUFF_THEN_CD")
end

function MSWA_IsBuffThenCD(key)
    if key == nil then return false end
    local db = MSWA_GetDB()
    if not db or not db.spellSettings then return false end
    local s = db.spellSettings[key] or db.spellSettings[tostring(key)]
    return s and s.auraMode == "BUFF_THEN_CD"
end

-----------------------------------------------------------
-- Display name / icon
-----------------------------------------------------------

function MSWA_GetDisplayNameForKey(key)
    local db = MSWA_GetDB()
    if db.customNames and db.customNames[key] and db.customNames[key] ~= "" then
        return db.customNames[key]
    end
    if MSWA_IsTrinketKey(key) then
        local slot = MSWA_KeyToTrinketSlot(key)
        local itemID = MSWA_GetTrinketItemID(slot)
        if itemID and GetItemInfo then
            local name = GetItemInfo(itemID)
            if name then return name end
        end
        return slot == 13 and "Trinket 1 (Slot 13)" or "Trinket 2 (Slot 14)"
    elseif MSWA_IsDraftKey(key) then
        return "???"
    elseif MSWA_IsItemInstanceKey(key) then
        local itemID = MSWA_KeyToItemID(key)
        if itemID and GetItemInfo then
            local name = GetItemInfo(itemID)
            if name then return name .. " (copy)" end
        end
        return ("Item %d (copy)"):format(itemID or 0)
    elseif MSWA_IsItemKey(key) then
        local itemID = MSWA_KeyToItemID(key)
        if itemID and GetItemInfo then
            local name = GetItemInfo(itemID)
            if name then return name end
        end
        return ("Item %d"):format(itemID or 0)
    elseif MSWA_IsSpellInstanceKey(key) then
        local spellID = MSWA_KeyToSpellID(key)
        local name = spellID and MSWA_GetSpellName(spellID) or nil
        return (name or "Spell") .. " (copy)"
    else
        local name = (type(key) == "number") and MSWA_GetSpellName(key) or nil
        return name or "Unknown"
    end
end

function MSWA_GetIconForKey(key)
    -- Custom icon override (per-aura setting)
    local db = MSWA_GetDB()
    local s = select(1, MSWA_GetSpellSettings(db, key))
    if s and s.customIconID then
        local cid = tonumber(s.customIconID)
        if cid and cid > 0 then return cid end
    end

    if MSWA_IsTrinketKey(key) then
        local slot = MSWA_KeyToTrinketSlot(key)
        if slot and GetInventoryItemTexture then
            local tex = GetInventoryItemTexture("player", slot)
            if tex then return tex end
        end
        return 136243
    elseif MSWA_IsDraftKey(key) then
        return DRAFT_ICON
    elseif MSWA_IsItemKey(key) then
        -- Handles both item:123 and item:123:N
        local itemID = MSWA_KeyToItemID(key)
        if itemID and GetItemIcon then
            local tex = GetItemIcon(itemID)
            if tex then return tex end
        end
        return 136243
    else
        local spellID = MSWA_KeyToSpellID(key)
        if spellID then
            return MSWA_GetSpellIcon(spellID) or 136243
        end
        return 136243
    end
end

-----------------------------------------------------------
-- Settings key resolution (number/string equivalence)
-----------------------------------------------------------

function MSWA_ResolveSpellSettingsKey(db, key)
    if not db then return key end
    db.spellSettings = db.spellSettings or {}
    if key == nil then return nil end

    if db.spellSettings[key] ~= nil then
        return key
    end

    local t = type(key)
    if t == "number" then
        local sk = tostring(key)
        if db.spellSettings[sk] ~= nil then return sk end
    elseif t == "string" then
        local nk = tonumber(key)
        if nk and db.spellSettings[nk] ~= nil then return nk end
    end

    return key
end

function MSWA_GetSpellSettings(db, key)
    if not db or key == nil then return nil, key end
    local resolved = MSWA_ResolveSpellSettingsKey(db, key)
    return (db.spellSettings or {})[resolved], resolved
end

function MSWA_GetOrCreateSpellSettings(db, key)
    if not db or key == nil then return nil, key end
    db.spellSettings = db.spellSettings or {}
    local resolved = MSWA_ResolveSpellSettingsKey(db, key)
    local s = db.spellSettings[resolved]
    if not s then
        s = {}
        db.spellSettings[resolved] = s
    end
    return s, resolved
end

function MSWA_KeyEquals(a, b)
    if a == b then return true end
    local na, nb = tonumber(a), tonumber(b)
    if na and nb and na == nb then return true end
    return tostring(a) == tostring(b)
end

-----------------------------------------------------------
-- Rekey: change spell/item ID, preserve all settings
-----------------------------------------------------------

function MSWA_RekeyAura(oldKey, newSpellOrItemID)
    if oldKey == nil or not newSpellOrItemID then return false, "Invalid arguments" end
    local db = MSWA_GetDB()
    if not db then return false, "No database" end

    local newID = tonumber(newSpellOrItemID)
    if not newID or newID <= 0 then return false, "Invalid ID" end

    -- Determine old key type and build new key
    local newKey
    local isItem = MSWA_IsItemKey(oldKey)
    local isItemInst = MSWA_IsItemInstanceKey(oldKey)
    local isSpellInst = MSWA_IsSpellInstanceKey(oldKey)

    if isItemInst then
        -- "item:OLD:N" -> "item:NEW:N"
        local inst = strmatch(tostring(oldKey), "^item:%d+:(%d+)$")
        newKey = ("item:%d:%s"):format(newID, inst)
    elseif isItem then
        -- "item:OLD" -> "item:NEW"
        newKey = ("item:%d"):format(newID)
    elseif isSpellInst then
        -- "spell:OLD:N" -> "spell:NEW:N"
        local inst = strmatch(tostring(oldKey), "^spell:%d+:(%d+)$")
        newKey = ("spell:%d:%s"):format(newID, inst)
    else
        -- Numeric spell ID
        newKey = newID
    end

    -- Check collision
    if MSWA_KeyEquals(oldKey, newKey) then return false, "Same ID" end
    if db.spellSettings and db.spellSettings[newKey] then
        return false, "ID " .. newID .. " already exists"
    end

    -- 1) Move spellSettings
    db.spellSettings = db.spellSettings or {}
    local settings = db.spellSettings[oldKey]
    if settings then
        db.spellSettings[newKey] = settings
        db.spellSettings[oldKey] = nil
    end

    -- 2) Move trackedSpells / trackedItems
    if isItem or isItemInst then
        if db.trackedItems and db.trackedItems[oldKey] then
            db.trackedItems[newKey] = db.trackedItems[oldKey]
            db.trackedItems[oldKey] = nil
        end
    else
        if db.trackedSpells and db.trackedSpells[oldKey] then
            db.trackedSpells[newKey] = db.trackedSpells[oldKey]
            db.trackedSpells[oldKey] = nil
        end
    end

    -- 3) Move customNames
    if db.customNames and db.customNames[oldKey] then
        db.customNames[newKey] = db.customNames[oldKey]
        db.customNames[oldKey] = nil
    end

    -- 4) Move group assignment
    if db.auraGroups and db.auraGroups[oldKey] then
        local gid = db.auraGroups[oldKey]
        db.auraGroups[newKey] = gid
        db.auraGroups[oldKey] = nil

        -- Update groupMembers array
        if db.groupMembers and db.groupMembers[gid] then
            local members = db.groupMembers[gid]
            for i = 1, #members do
                if MSWA_KeyEquals(members[i], oldKey) then
                    members[i] = newKey
                    break
                end
            end
        end
    end

    -- 5) Update selection
    if MSWA.selectedSpellID and MSWA_KeyEquals(MSWA.selectedSpellID, oldKey) then
        MSWA.selectedSpellID = newKey
    end

    return true, newKey
end

-- Globals for cross-file access
_G.MSWA_GetSpellSettings = MSWA_GetSpellSettings
_G.MSWA_GetOrCreateSpellSettings = MSWA_GetOrCreateSpellSettings
_G.MSWA_ResolveSpellSettingsKey = MSWA_ResolveSpellSettingsKey
_G.MSWA_IsItemInstanceKey = MSWA_IsItemInstanceKey
_G.MSWA_NewItemInstanceKey = MSWA_NewItemInstanceKey
_G.MSWA_IsBuffThenCD = MSWA_IsBuffThenCD
_G.MSWA_IsTrinketKey = MSWA_IsTrinketKey
_G.MSWA_KeyToTrinketSlot = MSWA_KeyToTrinketSlot
_G.MSWA_GetTrinketItemID = MSWA_GetTrinketItemID
