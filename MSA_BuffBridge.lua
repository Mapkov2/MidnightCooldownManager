-- ########################################################
-- MSA_BuffBridge.lua
-- Bridge between PlayerBuffs engine and UpdateEngine
--
-- Provides the functions that the UpdateEngine hot-path
-- calls to decide how to display an aura-type icon:
--   * Active buff -> normal icon with timer
--   * Absent buff (showWhenAbsent) -> desaturated / dimmed
--   * Absent buff (!showWhenAbsent) -> hidden
--
-- Secret-safe: no value comparisons, pcall on all API.
-- Zero idle CPU: only called when UpdateEngine is active.
-- ########################################################

local MSWA = _G.MSWA
if type(MSWA) ~= "table" then return end

local type, tonumber, pcall = type, tonumber, pcall
local GetTime = GetTime

-----------------------------------------------------------
-- Determine if a tracked key is an "aura" type
-- (vs traditional cooldown tracking)
-----------------------------------------------------------

function MSWA_IsAuraType(key)
    if not key then return false end
    local db = MSWA_GetDB and MSWA_GetDB()
    if not db then return false end
    local s = db.spellSettings and db.spellSettings[key]
    if not s then return false end
    return s.trackType == "aura"
end

-----------------------------------------------------------
-- Get display data for an aura-type icon
-- Returns a table suitable for the UpdateEngine icon loop:
--   show, icon, remaining, duration, stacks, alpha, desat
-----------------------------------------------------------

function MSWA_GetAuraDisplayData(key)
    if not key then
        return false, nil, 0, 0, 0, 1, false
    end

    local db = MSWA_GetDB and MSWA_GetDB()
    if not db then
        return false, nil, 0, 0, 0, 1, false
    end

    local s = db.spellSettings and db.spellSettings[key]
    if not s or s.trackType ~= "aura" then
        return false, nil, 0, 0, 0, 1, false
    end

    local active, remaining, duration, stacks, buffIcon
    if MSWA_GetBuffData then
        active, remaining, duration, stacks, buffIcon = MSWA_GetBuffData(key)
    else
        active = false
        remaining = 0
        duration = 0
        stacks = 0
    end

    -- Resolve icon: buff icon > spell texture > override
    local icon = buffIcon
    if not icon and s.auraSpellID then
        icon = MSWA_GetSpellIconSafe and MSWA_GetSpellIconSafe(s.auraSpellID)
    end
    if s.iconOverride then
        icon = s.iconOverride
    end

    if active then
        return true, icon, remaining, duration, stacks, 1.0, false
    else
        -- Not active
        if s.showWhenAbsent then
            local alpha = tonumber(s.alphaOnAbsent) or 0.45
            local desat = (s.desaturateOnAbsent ~= false)  -- default true for absent
            return true, icon, 0, 0, 0, alpha, desat
        else
            return false, icon, 0, 0, 0, 1, false
        end
    end
end

-----------------------------------------------------------
-- Apply absent visual styling to an icon button
-- Called by the icon rendering loop when show=true but
-- the buff is not active.
-----------------------------------------------------------

function MSWA_ApplyAbsentStyle(btn, alpha, desaturate)
    if not btn then return end

    -- Alpha
    local a = tonumber(alpha) or 0.45
    if a < 0 then a = 0 end
    if a > 1 then a = 1 end
    btn:SetAlpha(a)

    -- Desaturation
    if desaturate then
        local tex = btn.icon or btn.Icon
        if tex and tex.SetDesaturated then
            pcall(tex.SetDesaturated, tex, true)
        end
        -- Also desaturate cooldown overlay if present
        local cd = btn.cooldown or btn.Cooldown
        if cd and cd.SetDesaturated then
            pcall(cd.SetDesaturated, cd, true)
        end
    end
end

-----------------------------------------------------------
-- Remove absent visual styling (buff became active)
-----------------------------------------------------------

function MSWA_ClearAbsentStyle(btn)
    if not btn then return end
    btn:SetAlpha(1)

    local tex = btn.icon or btn.Icon
    if tex and tex.SetDesaturated then
        pcall(tex.SetDesaturated, tex, false)
    end
    local cd = btn.cooldown or btn.Cooldown
    if cd and cd.SetDesaturated then
        pcall(cd.SetDesaturated, cd, false)
    end
end

-----------------------------------------------------------
-- Icon tooltip for aura-type entries
-- Adds the buff spell ID + source info to the tooltip
-----------------------------------------------------------

function MSWA_SetAuraTooltip(tooltip, key)
    if not tooltip or not key then return end
    local db = MSWA_GetDB and MSWA_GetDB()
    if not db then return end

    local s = db.spellSettings and db.spellSettings[key]
    if not s or s.trackType ~= "aura" then return end

    local spellID = s.auraSpellID
    if spellID then
        tooltip:AddLine(" ")
        tooltip:AddLine(("Tracked Buff ID: |cffffffff%d|r"):format(spellID), 0.5, 0.8, 1)
    end

    local buff = MSWA._activeBuffs and MSWA._activeBuffs[key]
    if buff then
        if buff.active then
            tooltip:AddLine("|cff00ff00Active|r", 0.5, 1, 0.5)
            if buff.stacks and buff.stacks > 0 then
                tooltip:AddLine(("Stacks: |cffffffff%d|r"):format(buff.stacks), 0.7, 0.7, 0.7)
            end
        else
            tooltip:AddLine("|cffff4444Absent|r", 1, 0.3, 0.3)
        end
    end
end

-----------------------------------------------------------
-- Ensure buff watches are registered when aura-type
-- entries are first enabled or settings change
-----------------------------------------------------------

function MSWA_EnsureBuffWatch(key)
    if not key then return end
    local db = MSWA_GetDB and MSWA_GetDB()
    if not db then return end

    local s = db.spellSettings and db.spellSettings[key]
    if not s or s.trackType ~= "aura" then return end
    if not s.auraSpellID then return end

    if MSWA_RegisterBuffWatch then
        MSWA_RegisterBuffWatch(
            key,
            s.auraSpellID,
            s.auraUnit or "player",
            s.auraFilter or "HELPFUL"
        )
    end
end

-----------------------------------------------------------
-- Count active buffs in a group (for group header display)
-----------------------------------------------------------

function MSWA_CountActiveBuffsInGroup(gid)
    if not gid then return 0, 0 end
    local db = MSWA_GetDB and MSWA_GetDB()
    if not db or not db.auraGroups then return 0, 0 end

    local total = 0
    local active = 0

    for key, g in pairs(db.auraGroups) do
        if g == gid then
            local s = db.spellSettings and db.spellSettings[key]
            if s and s.trackType == "aura" then
                total = total + 1
                local buff = MSWA._activeBuffs and MSWA._activeBuffs[key]
                if buff and buff.active then
                    active = active + 1
                end
            end
        end
    end

    return active, total
end
