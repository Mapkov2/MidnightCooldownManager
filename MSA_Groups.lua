-- ########################################################
-- MSA_Groups.lua
-- Group CRUD, aura group assignment, context menus
-- ########################################################

local tinsert = table.insert
local pairs, tostring, type, tonumber = pairs, tostring, type, tonumber
local tsort = table.sort

-----------------------------------------------------------
-- Group member ordering (stored for export/import + UI)
-- db.groupMembers[gid] = array of aura keys in desired order
-----------------------------------------------------------

local function _ensureTable(t, k)
    if type(t[k]) ~= "table" then t[k] = {} end
    return t[k]
end

local function _arrayRemoveValue(arr, val)
    if type(arr) ~= "table" then return end
    for i = #arr, 1, -1 do
        if arr[i] == val then
            table.remove(arr, i)
        end
    end
end

local function _arrayContains(arr, val)
    if type(arr) ~= "table" then return false end
    for i = 1, #arr do
        if arr[i] == val then return true end
    end
    return false
end

local function _getXY(db, key)
    local s = db and db.spellSettings and db.spellSettings[key]
    if type(s) ~= "table" then return 0, 0 end
    local x = tonumber(s.x) or 0
    local y = tonumber(s.y) or 0
    return x, y
end

-- Rebuild member order from current positions (row-major: top->bottom, left->right)
function MSWA_SyncGroupMembersFromPositions(gid)
    if not gid then return end
    local db = MSWA_GetDB()
    if not (db and db.groups and db.groups[gid]) then return end

    db.groupMembers = db.groupMembers or {}
    local members = _ensureTable(db.groupMembers, gid)

    -- Ensure members list contains all current group auras
    if db.auraGroups then
        for key, g in pairs(db.auraGroups) do
            if g == gid and (not _arrayContains(members, key)) then
                tinsert(members, key)
            end
        end
    end

    -- Remove any keys no longer in this group
    for i = #members, 1, -1 do
        local key = members[i]
        if not (db.auraGroups and db.auraGroups[key] == gid) then
            table.remove(members, i)
        end
    end

    tsort(members, function(a, b)
        local ax, ay = _getXY(db, a)
        local bx, by = _getXY(db, b)
        -- higher Y first (top row), then lower X first (left to right)
        if ay ~= by then return ay > by end
        if ax ~= bx then return ax < bx end
        -- stable fallback
        return tostring(a) < tostring(b)
    end)

    return members
end

-- Ensure groupMembers[gid] exists and is sane
function MSWA_EnsureGroupMembers(gid)
    if not gid then return nil end
    local db = MSWA_GetDB()
    if not (db and db.groups and db.groups[gid]) then return nil end
    db.groupMembers = db.groupMembers or {}
    if type(db.groupMembers[gid]) ~= "table" then
        db.groupMembers[gid] = {}
    end
    MSWA_SyncGroupMembersFromPositions(gid)
    return db.groupMembers[gid]
end

-- Move a member within a group (delta: -1 up, +1 down)
-- Also swaps the stored x/y positions so the visual order matches.
function MSWA_MoveGroupMember(gid, key, delta)
    if not gid or key == nil or not delta then return end
    local db = MSWA_GetDB()
    if not (db and db.groups and db.groups[gid]) then return end
    if not (db.auraGroups and db.auraGroups[key] == gid) then return end

    local members = MSWA_EnsureGroupMembers(gid)
    if type(members) ~= "table" then return end

    local idx
    for i = 1, #members do
        if members[i] == key then idx = i; break end
    end
    if not idx then return end

    local newIdx = idx + (delta < 0 and -1 or 1)
    if newIdx < 1 or newIdx > #members then return end

    local otherKey = members[newIdx]
    if otherKey == nil then return end

    -- Swap list positions
    members[idx], members[newIdx] = members[newIdx], members[idx]

    -- Swap x/y so the on-screen order changes immediately
    db.spellSettings = db.spellSettings or {}
    local sA = db.spellSettings[key] or {}
    local sB = db.spellSettings[otherKey] or {}
    local ax, ay = tonumber(sA.x) or 0, tonumber(sA.y) or 0
    local bx, by = tonumber(sB.x) or 0, tonumber(sB.y) or 0
    sA.x, sA.y = bx, by
    sB.x, sB.y = ax, ay
    db.spellSettings[key] = sA
    db.spellSettings[otherKey] = sB

    if type(MSWA_RequestFullRefresh) == "function" then
        MSWA_RequestFullRefresh()
    elseif type(MSWA_RefreshOptionsList) == "function" then
        MSWA_RefreshOptionsList()
    end
end

local function _reflowGroupMembers(db, gid)
    if not gid then return end
    if not (db and db.groups and db.groups[gid]) then return end

    db.groupMembers = db.groupMembers or {}
    db.spellSettings = db.spellSettings or {}

    local members = db.groupMembers[gid]
    if type(members) ~= "table" then return end

    local group = db.groups[gid]
    local size = tonumber(group.size) or MSWA.ICON_SIZE or 32
    local step = size + (MSWA.ICON_SPACE or 0)
    local dir = group.growthDirection or "RIGHT"

    for i = #members, 1, -1 do
        local mkey = members[i]
        if not (db.auraGroups and db.auraGroups[mkey] == gid) then
            table.remove(members, i)
        end
    end

    for i = 1, #members do
        local mkey = members[i]
        local s = db.spellSettings[mkey]
        if type(s) ~= "table" then s = {}; db.spellSettings[mkey] = s end
        local count = i - 1
        if dir == "LEFT" then
            s.x = -(count * step)
            s.y = 0
        elseif dir == "UP" then
            s.x = 0
            s.y = count * step
        elseif dir == "DOWN" then
            s.x = 0
            s.y = -(count * step)
        else
            s.x = count * step
            s.y = 0
        end
        s.width = s.width or size
        s.height = s.height or size
        s.anchorFrame = nil
    end
end

function MSWA_ReflowGroupMembers(gid)
    local db = MSWA_GetDB()
    _reflowGroupMembers(db, gid)
end

function MSWA_MoveAuraToGroupPosition(key, targetGid, targetIndex)
    if key == nil then return end

    local db = MSWA_GetDB()
    db.auraGroups = db.auraGroups or {}
    db.groupMembers = db.groupMembers or {}
    db.spellSettings = db.spellSettings or {}

    local sourceGid = db.auraGroups[key]
    local s = db.spellSettings[key]
    if type(s) ~= "table" then s = {}; db.spellSettings[key] = s end

    if sourceGid and type(db.groupMembers[sourceGid]) == "table" then
        _arrayRemoveValue(db.groupMembers[sourceGid], key)
    end

    if targetGid and db.groups and db.groups[targetGid] then
        local members = db.groupMembers[targetGid]
        if type(members) ~= "table" then
            members = {}
            db.groupMembers[targetGid] = members
        end

        _arrayRemoveValue(members, key)

        local insertAt = tonumber(targetIndex) or (#members + 1)
        if insertAt < 1 then insertAt = 1 end
        if insertAt > (#members + 1) then insertAt = #members + 1 end

        table.insert(members, insertAt, key)
        db.auraGroups[key] = targetGid
        s.anchorFrame = nil

        _reflowGroupMembers(db, targetGid)
        if sourceGid and sourceGid ~= targetGid then
            _reflowGroupMembers(db, sourceGid)
        end
    else
        local oldGroup = sourceGid and db.groups and db.groups[sourceGid] or nil
        if oldGroup then
            s.x = (tonumber(s.x) or 0) + (tonumber(oldGroup.x) or 0)
            s.y = (tonumber(s.y) or 0) + (tonumber(oldGroup.y) or 0)
            if oldGroup.anchorFrame and oldGroup.anchorFrame ~= "" then
                s.anchorFrame = oldGroup.anchorFrame
            end
        end
        db.auraGroups[key] = nil

        if sourceGid then
            _reflowGroupMembers(db, sourceGid)
        end
    end

    if type(MSWA_RequestFullRefresh) == "function" then
        MSWA_RequestFullRefresh()
    elseif type(MSWA_RequestUpdateSpells) == "function" then
        MSWA_RequestUpdateSpells()
    end
    if type(MSWA_RefreshOptionsList) == "function" then
        MSWA_RefreshOptionsList()
    end
end


-----------------------------------------------------------
-- Group helpers (WA-like)
-----------------------------------------------------------

function MSWA_NewGroupID()
    local db = MSWA_GetDB()
    db._groupCounter = (db._groupCounter or 0) + 1
    return ("GROUP:%d"):format(db._groupCounter)
end

function MSWA_CreateGroup(name)
    local db = MSWA_GetDB()
    db.groups = db.groups or {}
    db.groupOrder = db.groupOrder or {}

    local gid = MSWA_NewGroupID()
    db.groups[gid] = {
        name       = name or ("Group %d"):format(db._groupCounter or 0),
        x          = 0,
        y          = 0,
        size       = MSWA.ICON_SIZE,
        anchorFrame = nil, -- global frame name (string) or nil => MSWA.frame
        point      = "CENTER",
        relPoint   = "CENTER",
        growthDirection = "RIGHT",  -- RIGHT / LEFT / UP / DOWN
    }
    tinsert(db.groupOrder, gid)
    return gid
end

function MSWA_DeleteGroup(gid)
    local db = MSWA_GetDB()
    if not (db.groups and db.groups[gid]) then return end

    if db.auraGroups then
        for key, g in pairs(db.auraGroups) do
            if g == gid then db.auraGroups[key] = nil end
        end
    end

    db.groups[gid] = nil

    if db.groupOrder then
        for i = #db.groupOrder, 1, -1 do
            if db.groupOrder[i] == gid then
                table.remove(db.groupOrder, i)
            end
        end
    end

    if MSWA.selectedGroupID == gid then
        MSWA.selectedGroupID = nil
    end
end

-----------------------------------------------------------
-- Aura → Group assignment
-----------------------------------------------------------

function MSWA_GetAuraGroup(key)
    local db = MSWA_GetDB()
    if db.auraGroups then return db.auraGroups[key] end
    return nil
end

function MSWA_SetAuraGroup(key, gid)
    local db = MSWA_GetDB()
    db.auraGroups = db.auraGroups or {}
    db.spellSettings = db.spellSettings or {}
    db.groupMembers = db.groupMembers or {}

    local s = db.spellSettings[key]
    local sExisted = s ~= nil
    if not s then s = {} end

    local prevGid = db.auraGroups[key]

    if gid and db.groups and db.groups[gid] then
        s.anchorFrame = nil
        local members = MSWA_EnsureGroupMembers and MSWA_EnsureGroupMembers(gid) or nil
        if type(members) ~= "table" then
            members = db.groupMembers[gid]
            if type(members) ~= "table" then members = {}; db.groupMembers[gid] = members end
        end

        -- Remove from previous group's member list (if moving groups)
        if prevGid and prevGid ~= gid and db.groupMembers and type(db.groupMembers[prevGid]) == "table" then
            _arrayRemoveValue(db.groupMembers[prevGid], key)
        end

        -- Ensure key is present only once, and compute its index
        local idx
        for i = 1, #members do
            if members[i] == key then idx = i; break end
        end
        if not idx then
            tinsert(members, key)
            idx = #members
        end

        local count = (idx - 1)
        local group = db.groups[gid]
        local size = group.size or MSWA.ICON_SIZE
        local step = size + MSWA.ICON_SPACE
        local dir = group.growthDirection or "RIGHT"
        if dir == "LEFT" then
            s.x = -(count * step)
            s.y = 0
        elseif dir == "UP" then
            s.x = 0
            s.y = count * step
        elseif dir == "DOWN" then
            s.x = 0
            s.y = -(count * step)
        else -- RIGHT (default)
            s.x = count * step
            s.y = 0
        end
        s.width  = s.width  or size
        s.height = s.height or size
        db.auraGroups[key] = gid
    else
        local old = db.auraGroups[key]
        local group = old and db.groups and db.groups[old] or nil
        if group then
            -- Preserve on-screen position when removing from a group:
            -- group offsets are relative to the group's anchor frame.
            s.x = (s.x or 0) + (group.x or 0)
            s.y = (s.y or 0) + (group.y or 0)
            if group.anchorFrame and group.anchorFrame ~= "" then
                s.anchorFrame = group.anchorFrame
            end
        end
        db.auraGroups[key] = nil

        -- Remove from member list
        if old and db.groupMembers and type(db.groupMembers[old]) == "table" then
            _arrayRemoveValue(db.groupMembers[old], key)
        end
    end

    if sExisted or db.auraGroups[key] ~= nil or next(s) ~= nil then
        db.spellSettings[key] = s
    end
end

-----------------------------------------------------------
-- Delete / rename helpers
-----------------------------------------------------------

function MSWA_DeleteAuraKey(key)
    if key == nil then return end
    local db = MSWA_GetDB()

    if MSWA_IsItemInstanceKey(key) then
        -- Item instance keys (item:ID:N) are stored in trackedSpells
        if db.trackedSpells then db.trackedSpells[key] = nil end
    elseif MSWA_IsItemKey(key) then
        local itemID = MSWA_KeyToItemID(key)
        if itemID and db.trackedItems then db.trackedItems[itemID] = nil end
    else
        if db.trackedSpells then db.trackedSpells[key] = nil end
    end

    if db.spellSettings then db.spellSettings[key] = nil end
    if db.auraGroups    then db.auraGroups[key]    = nil end
    if db.customNames   then db.customNames[key]   = nil end

    -- Clear autobuff state
    if MSWA._autoBuff then MSWA._autoBuff[key] = nil end

    if MSWA.selectedSpellID == key then
        MSWA.selectedSpellID = nil
    end
end

function MSWA_RequestFullRefresh()
    if type(MSWA_RefreshOptionsList) == "function" then
        MSWA_RefreshOptionsList()
    elseif type(_G.MSWA_RefreshOptionsList) == "function" then
        _G.MSWA_RefreshOptionsList()
    end
    if type(MSWA_RequestUpdateSpells) == "function" then
        MSWA_RequestUpdateSpells()
    elseif type(MSWA_UpdateSpells) == "function" then
        pcall(MSWA_UpdateSpells)
    elseif type(_G.MSWA_UpdateSpells) == "function" then
        pcall(_G.MSWA_UpdateSpells)
    end
end

-----------------------------------------------------------
-- StaticPopup dialogs (lazy-register once)
-----------------------------------------------------------

function MSWA_EnsureRenamePopups()
    if StaticPopupDialogs and not StaticPopupDialogs.MSWA_RENAME_AURA then
        StaticPopupDialogs.MSWA_RENAME_AURA = {
            text = "Rename Aura",
            button1 = ACCEPT,
            button2 = CANCEL,
            hasEditBox = true,
            maxLetters = 64,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            OnShow = function(self, data)
                local d = data or self.data
                local t = (d and d.defaultText) or ""
                self.editBox:SetText(t)
                self.editBox:HighlightText()
                self.editBox:SetFocus()
            end,
            OnAccept = function(self, data)
                local d = data or self.data
                if not d or d.key == nil then return end
                local db = MSWA_GetDB()
                db.customNames = db.customNames or {}
                local txt = (self.editBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if txt == "" then
                    db.customNames[d.key] = nil
                else
                    db.customNames[d.key] = txt
                end
                MSWA_RequestFullRefresh()
            end,
        }
    end

    if StaticPopupDialogs and not StaticPopupDialogs.MSWA_RENAME_GROUP then
        StaticPopupDialogs.MSWA_RENAME_GROUP = {
            text = "Rename Group",
            button1 = ACCEPT,
            button2 = CANCEL,
            hasEditBox = true,
            maxLetters = 64,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            OnShow = function(self, data)
                local d = data or self.data
                local t = (d and d.defaultText) or ""
                self.editBox:SetText(t)
                self.editBox:HighlightText()
                self.editBox:SetFocus()
            end,
            OnAccept = function(self, data)
                local d = data or self.data
                if not d or not d.groupID then return end
                local db = MSWA_GetDB()
                local g = db.groups and db.groups[d.groupID]
                if g then
                    local txt = (self.editBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if txt ~= "" then g.name = txt end
                end
                MSWA_RequestFullRefresh()
            end,
        }
    end
end

-----------------------------------------------------------
-- Context menu frame
-----------------------------------------------------------

function MSWA_GetContextMenuFrame()
    if not MSWA._contextMenuFrame then
        MSWA._contextMenuFrame = CreateFrame("Frame", "MSWA_ContextMenuFrame", UIParent, "UIDropDownMenuTemplate")
    end
    return MSWA._contextMenuFrame
end
