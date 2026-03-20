-- ########################################################
-- MSA_BuffBridge.lua  (v5 - EQoL-style event-driven cache)
--
-- Central aura data layer for BUFF_AURA mode icons.
-- Replaces per-tick GetUnitAuras polling with event-driven
-- dirty-flag cache.  CDM frame scanner uses dirty-flag too.
--
-- Architecture:
--   UNIT_AURA(player/target) -> set dirty flag
--   Next read from UpdateEngine -> rebuild cache once
--   All subsequent reads in same tick -> cached O(1)
--
-- Secret-safe: no comparisons on tainted values.
-- Zero idle CPU: no OnUpdate, no timers, pure event relay.
-- ########################################################

local MSWA = _G.MSWA
if type(MSWA) ~= "table" then return end

local type, tostring, tonumber = type, tostring, tonumber
local pcall     = pcall
local GetTime   = GetTime
local wipe      = wipe or table.wipe

-----------------------------------------------------------
-- API capability detection (once at load time)
-----------------------------------------------------------

local C_UnitAuras = C_UnitAuras
local C_Spell     = C_Spell

local hasGetUnitAuras  = C_UnitAuras and C_UnitAuras.GetUnitAuras
local hasGetPlayerAura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
local hasGetCDAura     = C_UnitAuras and C_UnitAuras.GetCooldownAuraBySpellID
local hasGetAuraCount  = C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount

local _issecretvalue = _G.issecretvalue

-----------------------------------------------------------
-- Player aura cache (event-driven, not per-tick)
--
-- _playerDirty: true = cache stale, needs rebuild
-- _playerCache[spellId] = auraData
-- Rebuilt ONLY on first read after UNIT_AURA fires.
-----------------------------------------------------------

local _playerCache = {}   -- [spellId] = auraData
local _playerDirty = true -- start dirty to force initial build

local function RebuildPlayerCache()
    if not _playerDirty then return end
    _playerDirty = false
    wipe(_playerCache)

    if not hasGetUnitAuras then return end

    -- EQoL pattern: GetUnitAuras returns all auras with
    -- whitelisted/readable fields (Midnight 12.0 safe)
    local auras = C_UnitAuras.GetUnitAuras("player", "HELPFUL")
    if type(auras) ~= "table" then return end

    for i = 1, #auras do
        local a = auras[i]
        if a then
            local sid = a.spellId
            -- Only cache if spellId is readable (not secret)
            if sid and not (_issecretvalue and _issecretvalue(sid)) then
                if not _playerCache[sid] then
                    _playerCache[sid] = a
                end
            end
        end
    end
end

-----------------------------------------------------------
-- Target aura cache (same pattern, separate dirty flag)
-----------------------------------------------------------

local _targetCache = {}
local _targetDirty = true

local function RebuildTargetCache()
    if not _targetDirty then return end
    _targetDirty = false
    wipe(_targetCache)

    if not hasGetUnitAuras then return end

    local auras = C_UnitAuras.GetUnitAuras("target", "HELPFUL")
    if type(auras) ~= "table" then return end

    for i = 1, #auras do
        local a = auras[i]
        if a then
            local sid = a.spellId
            if sid and not (_issecretvalue and _issecretvalue(sid)) then
                if not _targetCache[sid] then
                    _targetCache[sid] = a
                end
            end
        end
    end

    -- Also scan HARMFUL for target debuffs
    local debuffs = C_UnitAuras.GetUnitAuras("target", "HARMFUL")
    if type(debuffs) ~= "table" then return end

    for i = 1, #debuffs do
        local a = debuffs[i]
        if a then
            local sid = a.spellId
            if sid and not (_issecretvalue and _issecretvalue(sid)) then
                if not _targetCache[sid] then
                    _targetCache[sid] = a
                end
            end
        end
    end
end

-----------------------------------------------------------
-- Public aura API
-----------------------------------------------------------

--- Invalidate player buff cache (called from events)
function MSWA_InvalidateBuffCache()
    _playerDirty = true
end

--- Invalidate target cache
function MSWA_InvalidateTargetCache()
    _targetDirty = true
end

--- Get player aura data by spell ID (event-driven cache)
function MSWA_GetPlayerAuraDataBySpellID(spellID)
    if not spellID then return nil end

    -- Primary: event-driven cache (EQoL Midnight pattern)
    if hasGetUnitAuras then
        RebuildPlayerCache()
        local cached = _playerCache[spellID]
        if cached then return cached end
    end

    -- Fallback: GetPlayerAuraBySpellID (works for some buffs)
    if hasGetPlayerAura then
        local data = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if data then return data end
    end

    -- Last resort: GetCooldownAuraBySpellID (CD-only auras)
    if hasGetCDAura then
        local ok, data = pcall(C_UnitAuras.GetCooldownAuraBySpellID, spellID)
        if ok and type(data) == "table" then return data end
    end

    return nil
end

--- Get aura data for arbitrary unit by spell ID
function MSWA_GetAuraDataForUnit(unit, spellID)
    if not unit or not spellID then return nil end

    if unit == "player" then
        return MSWA_GetPlayerAuraDataBySpellID(spellID)
    end

    if unit == "target" then
        if hasGetUnitAuras then
            RebuildTargetCache()
            local cached = _targetCache[spellID]
            if cached then return cached end
        end
        return nil
    end

    -- Generic unit: direct API call (no cache)
    if hasGetUnitAuras then
        local auras = C_UnitAuras.GetUnitAuras(unit, "HELPFUL")
        if type(auras) == "table" then
            for i = 1, #auras do
                local a = auras[i]
                if a and a.spellId == spellID then return a end
            end
        end
    end
    return nil
end

--- Check if a value is a Midnight secret value
function MSWA_IsSecretValue(val)
    if val == nil then return false end
    if _issecretvalue and _issecretvalue(val) then return true end
    return false
end

--- Safe field read: returns nil for secret values
function MSWA_SafeAuraField(auraData, fieldName)
    if not auraData then return nil end
    local val = auraData[fieldName]
    if val == nil then return nil end
    if _issecretvalue and _issecretvalue(val) then return nil end
    return val
end

--- Stack text (EQoL signature: GetAuraApplicationDisplayCount)
function MSWA_GetAuraStackText(auraData, minCount)
    if not auraData or not hasGetAuraCount then return nil end
    minCount = minCount or 2

    -- EQoL signature: GetAuraApplicationDisplayCount(unit, instanceID, min, max)
    local instanceID = auraData.auraInstanceID
    if instanceID then
        local ok, s = pcall(C_UnitAuras.GetAuraApplicationDisplayCount,
                            "player", instanceID, minCount, 1000)
        if ok and s then return tostring(s) end
    end

    -- Fallback: read applications directly if not secret
    local apps = auraData.applications
    if apps and not (_issecretvalue and _issecretvalue(apps)) then
        if apps >= minCount then return tostring(apps) end
    end

    return nil
end

-----------------------------------------------------------
-- CDM (Cooldown Manager) Frame Scanner
-- Dirty-flag based: only rescans when CDM frames change.
-- Secret-safe: tostring() comparison on cooldownIDs.
-----------------------------------------------------------

local _cdmFrameCache = {}  -- [tostring(cooldownID)] = frame
local _cdmDirty      = true
local _cdmScratch    = {}  -- reusable select() buffer

-- Capture vararg into reusable scratch table
local function CaptureCDMChildren(buf, ...)
    wipe(buf)
    local n = select("#", ...)
    for i = 1, n do buf[i] = select(i, ...) end
    return n
end

local function RebuildCDMFrameCache()
    if not _cdmDirty then return end
    _cdmDirty = false
    wipe(_cdmFrameCache)

    local viewers = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }
    for vi = 1, #viewers do
        local viewer = _G[viewers[vi]]
        if viewer then
            -- Collect from GetChildren
            if viewer.GetChildren then
                local childCount = CaptureCDMChildren(_cdmScratch, viewer:GetChildren())
                for ci = 1, childCount do
                    local child = _cdmScratch[ci]
                    if child then
                        local cdID = child.cooldownID
                        if not cdID and child.cooldownInfo then cdID = child.cooldownInfo.cooldownID end
                        if cdID then _cdmFrameCache[tostring(cdID)] = child end
                    end
                end
            end
            -- Also check layoutChildren (some viewers use this)
            local lc = viewer.layoutChildren
            if type(lc) == "table" then
                for _, child in pairs(lc) do
                    if type(child) == "table" then
                        local cdID = child.cooldownID
                        if not cdID and child.cooldownInfo then cdID = child.cooldownInfo.cooldownID end
                        if cdID and not _cdmFrameCache[tostring(cdID)] then
                            _cdmFrameCache[tostring(cdID)] = child
                        end
                    end
                end
            end
        end
    end
end

--- Invalidate CDM cache (called on viewer changes)
function MSWA_InvalidateCDMCache()
    _cdmDirty = true
end

-- Check if an auraInstanceID is usable (non-secret, positive number)
local function IsUsableAuraInstanceID(v)
    return type(v) == "number" and not (_issecretvalue and _issecretvalue(v)) and v > 0
end

--- Get aura data from a CDM viewer frame by cooldownID.
--- Falls back to spell-based lookup if frame scanning yields nothing.
--- @param cooldownID number|string  stored cdmCooldownID
--- @param fallbackSID number|nil    spell ID for fallback
--- @return table|nil  auraData (Blizzard struct or synthetic)
function MSWA_GetCDMFrameAuraData(cooldownID, fallbackSID)
    if not cooldownID then
        if fallbackSID then return MSWA_GetPlayerAuraDataBySpellID(fallbackSID) end
        return nil
    end

    RebuildCDMFrameCache()

    local frame = _cdmFrameCache[tostring(cooldownID)]
    if frame then
        -- 1) Read auraInstanceID from frame -> GetAuraDataByAuraInstanceID
        local auraInstanceID = frame.auraInstanceID
        if IsUsableAuraInstanceID(auraInstanceID) then
            local auraUnit
            if type(frame.GetAuraDataUnit) == "function" then
                local ok, u = pcall(frame.GetAuraDataUnit, frame)
                if ok and type(u) == "string" and u ~= "" then auraUnit = u end
            end
            if not auraUnit and type(frame.auraDataUnit) == "string" then
                auraUnit = frame.auraDataUnit
            end
            if not auraUnit then auraUnit = "player" end

            if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
                local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(auraUnit, auraInstanceID)
                if auraData then return auraData end
            end
        end

        -- 2) Totem fallback (shamans etc.)
        if frame.totemData ~= nil and GetTotemInfo then
            local slot = frame.preferredTotemUpdateSlot
            if not slot and frame.totemData then
                local ok, s = pcall(function() return frame.totemData.slot end)
                if ok then slot = s end
            end
            if slot then
                local _, _, startTime, duration = GetTotemInfo(slot)
                if duration and duration > 0 then
                    local iconTex
                    if frame.Icon and frame.Icon.Icon and frame.Icon.Icon.GetTexture then
                        iconTex = frame.Icon.Icon:GetTexture()
                    end
                    return {
                        duration       = duration,
                        expirationTime = startTime + duration,
                        timeMod        = 1,
                        applications   = 0,
                        icon           = iconTex,
                        _isCDMTotem    = true,
                    }
                end
            end
        end
    end

    -- 3) Fallback: standard spellID-based lookup
    if fallbackSID then
        return MSWA_GetPlayerAuraDataBySpellID(fallbackSID)
    end
    return nil
end

-----------------------------------------------------------
-- Reminder threshold helper for BUFF_AURA
-- Returns true if aura should be HIDDEN (remaining > threshold).
-- Secret values -> never hide.  Absent -> never hide.
-----------------------------------------------------------

function MSWA_ShouldHideByThreshold(s, auraData, now)
    if not s or not s.reminderThresholdMin then return false end
    local thresh = tonumber(s.reminderThresholdMin)
    if not thresh or thresh <= 0 then return false end

    if not auraData then return false end

    local exp = auraData.expirationTime
    local dur = auraData.duration

    -- Secret values -> can't check, always show
    if _issecretvalue then
        if (exp and _issecretvalue(exp)) or (dur and _issecretvalue(dur)) then
            return false
        end
    end

    -- Permanent buff (duration=0) -> always show
    if not dur or dur == 0 then return false end
    if not exp or exp == 0 then return false end

    local remaining = exp - now
    if remaining <= 0 then return false end

    -- Hide if remaining time is ABOVE threshold (buff still healthy)
    return remaining > (thresh * 60)
end

-----------------------------------------------------------
-- Resolve aura data for a BUFF_AURA entry
-- Central helper: CDM path or direct player lookup.
-- @param s       spellSettings entry
-- @param fallbackID  spellID or itemID to use if s.auraSpellID is nil
-- @return auraData, buffActive
-----------------------------------------------------------

function MSWA_ResolveBuffAura(s, fallbackID)
    local buffSID = s.auraSpellID or fallbackID
    local cdmID = s.cdmCooldownID
    local auraData
    if cdmID then
        auraData = MSWA_GetCDMFrameAuraData(cdmID, buffSID)
    else
        auraData = MSWA_GetPlayerAuraDataBySpellID(buffSID)
    end
    return auraData, (auraData ~= nil)
end

-----------------------------------------------------------
-- Apply cooldown sweep for aura data (secret-safe)
-- Shared by icon render + bar info collection.
-----------------------------------------------------------

function MSWA_ApplyAuraCooldown(cd, auraData)
    if not cd or not auraData then
        if cd then MSWA_ClearCooldownFrame(cd) end
        return
    end
    local dur = auraData.duration
    local exp = auraData.expirationTime
    local isSecret = _issecretvalue and (
        (dur and _issecretvalue(dur)) or
        (exp and _issecretvalue(exp))
    )
    if isSecret then
        if cd.SetCooldownFromExpirationTime then
            cd:SetCooldownFromExpirationTime(exp, dur, auraData.timeMod)
            cd.__mswaSet = true
        end
    elseif dur and dur > 0 and exp then
        MSWA_ApplyCooldownFrame(cd, exp - dur, dur, auraData.timeMod or 1, exp)
    else
        MSWA_ClearCooldownFrame(cd)
    end
end

-----------------------------------------------------------
-- Collect bar info for BUFF_AURA mode
-- Fills bInfo fields from aura data.  Called from
-- UpdateEngine bar post-processing loop.
-----------------------------------------------------------

function MSWA_CollectBuffAuraBarInfo(bInfo, bs, bkey, previewMode)
    local sid = bs.auraSpellID or tonumber(bkey)
    local cdmID = bs.cdmCooldownID
    local ad
    if cdmID then
        ad = MSWA_GetCDMFrameAuraData(cdmID, sid)
    elseif sid then
        ad = MSWA_GetPlayerAuraDataBySpellID(sid)
    end

    if ad then
        local e = ad.expirationTime
        local d = ad.duration
        if e and d then
            if _issecretvalue and ((_issecretvalue(e)) or (_issecretvalue(d))) then
                bInfo.isSecret = true
            else
                bInfo.expires  = e
                bInfo.duration = d
            end
        end
        bInfo.stacks = MSWA_GetAuraStackText(ad, 2)
    else
        bInfo.isActive = (bs.showWhenAbsent == true or previewMode)
        if not bInfo.isActive then bInfo.isActive = false end
        bInfo.absentAlpha = tonumber(bs.alphaOnAbsent) or 0.45
    end
end

-----------------------------------------------------------
-- Event frame: UNIT_AURA relay + target changes
-- Drives dirty-flag invalidation for all caches.
-----------------------------------------------------------

local eventFrame = CreateFrame("Frame", "MSWA_BuffEventFrame", UIParent)

eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

-- Named handler (no closure allocation)
local function OnEvent(_, event, arg1, arg2)
    if event == "UNIT_AURA" then
        if arg1 == "player" then
            _playerDirty = true
            _cdmDirty = true  -- CDM frames may have updated
            if MSWA_RequestUpdateSpells then MSWA_RequestUpdateSpells() end
        elseif arg1 == "target" then
            _targetDirty = true
            if MSWA_RequestUpdateSpells then MSWA_RequestUpdateSpells() end
        end
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        _targetDirty = true
        _cdmDirty = true
        if MSWA_RequestUpdateSpells then MSWA_RequestUpdateSpells() end
        return
    end

    if event == "PLAYER_EQUIPMENT_CHANGED" then
        -- arg1 = equipmentSlot.  Only care about trinket slots 13/14.
        if arg1 == 13 or arg1 == 14 then
            -- Invalidate icon cache for trinket keys so texture updates
            MSWA_InvalidateTrinketIcons()
            if MSWA_RequestUpdateSpells then MSWA_RequestUpdateSpells() end
        end
        return
    end

    -- PLAYER_ENTERING_WORLD: full invalidation
    _playerDirty = true
    _targetDirty = true
    _cdmDirty    = true
    if MSWA_RequestUpdateSpells then MSWA_RequestUpdateSpells() end
end

eventFrame:SetScript("OnEvent", OnEvent)


-----------------------------------------------------------
-- Blizzard Cooldown Viewer visibility controller
-- EQoL-style integration for hiding/fading Blizzard viewers
-- while MSA tracks the same buffs/cooldowns.
-----------------------------------------------------------

local CV_RULES = {
    IN_COMBAT        = "IN_COMBAT",
    WHILE_MOUNTED    = "WHILE_MOUNTED",
    WHILE_NOT_MOUNTED = "WHILE_NOT_MOUNTED",
    MOUSEOVER        = "MOUSEOVER",
    PLAYER_HAS_TARGET = "PLAYER_HAS_TARGET",
    PLAYER_CASTING   = "PLAYER_CASTING",
    PLAYER_IN_GROUP  = "PLAYER_IN_GROUP",
    ALWAYS_HIDDEN    = "ALWAYS_HIDDEN",
}

local CV_FRAME_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffBarCooldownViewer",
    "BuffIconCooldownViewer",
}

MSWA.COOLDOWN_VIEWER_VIS_RULES = CV_RULES

function MSWA_GetCooldownViewerFrameNames()
    return CV_FRAME_NAMES
end

local _cvHoverState = {}
local _cvHoverFrame = CreateFrame("Frame", "MSWA_CooldownViewerHoverFrame", UIParent)
local _cvHoverAccum = 0
local _cvRetryPending = false
local _cvRetryCount = 0

_cvHoverFrame:Hide()

local function CV_GetDB()
    local db = MSWA_GetDB()
    db.cooldownViewerVisibility = db.cooldownViewerVisibility or {}
    if db.cooldownViewerFadeAmount == nil then db.cooldownViewerFadeAmount = 1 end
    if db.cooldownViewerSharedMouseover == nil then db.cooldownViewerSharedMouseover = false end
    return db
end

local function CV_CopySelection(src)
    if type(src) ~= "table" then return nil end
    local out = {}
    local hasAny = false
    for k, v in pairs(src) do
        if v == true then
            out[k] = true
            hasAny = true
        end
    end
    if hasAny then return out end
    return nil
end

local function CV_FrameExists(frameName)
    local f = frameName and _G[frameName]
    return f ~= nil, f
end

local function CV_IsCasting()
    return (UnitCastingInfo and UnitCastingInfo("player")) ~= nil
        or (UnitChannelInfo and UnitChannelInfo("player")) ~= nil
end

local function CV_UsesMouseover(cfg)
    return type(cfg) == "table" and cfg[CV_RULES.MOUSEOVER] == true
end

local function CV_AnySharedHover(frameName, shared)
    local hovered = _cvHoverState[frameName] == true
    if hovered or not shared then return hovered end
    for otherName, state in pairs(_cvHoverState) do
        if otherName ~= frameName and state == true then
            return true
        end
    end
    return false
end

function MSWA_GetCooldownViewerVisibility(frameName)
    local db = CV_GetDB()
    return CV_CopySelection(db.cooldownViewerVisibility[frameName])
end

function MSWA_SetCooldownViewerVisibility(frameName, key, shouldSelect)
    if not frameName or not key then return end
    local db = CV_GetDB()
    local bucket = db.cooldownViewerVisibility[frameName]
    if type(bucket) ~= "table" then
        bucket = {}
        db.cooldownViewerVisibility[frameName] = bucket
    end
    if shouldSelect then
        bucket[key] = true
    else
        bucket[key] = nil
    end
    if not next(bucket) then
        db.cooldownViewerVisibility[frameName] = nil
    end
    MSWA_ApplyCooldownViewerVisibility()
end

function MSWA_ClearCooldownViewerVisibility(frameName)
    if not frameName then return end
    local db = CV_GetDB()
    db.cooldownViewerVisibility[frameName] = nil
    _cvHoverState[frameName] = nil
    MSWA_ApplyCooldownViewerVisibility()
end

function MSWA_GetCooldownViewerFadeAmount()
    local db = CV_GetDB()
    local v = tonumber(db.cooldownViewerFadeAmount) or 1
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    return v
end

function MSWA_GetCooldownViewerFadePercent()
    return math.floor((MSWA_GetCooldownViewerFadeAmount() * 100) + 0.5)
end

function MSWA_SetCooldownViewerFadePercent(pct)
    local db = CV_GetDB()
    pct = tonumber(pct) or 0
    if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
    db.cooldownViewerFadeAmount = pct / 100
    MSWA_ApplyCooldownViewerVisibility()
end

function MSWA_GetCooldownViewerSharedMouseover()
    local db = CV_GetDB()
    return db.cooldownViewerSharedMouseover == true
end

function MSWA_SetCooldownViewerSharedMouseover(enabled)
    local db = CV_GetDB()
    db.cooldownViewerSharedMouseover = enabled and true or false
    MSWA_ApplyCooldownViewerVisibility()
end

local function CV_ComputeTargetAlpha(frameName, cfg, db)
    if type(cfg) ~= "table" then return 1, false end

    local fadedAlpha = 1 - (tonumber(db.cooldownViewerFadeAmount) or 1)
    if fadedAlpha < 0 then fadedAlpha = 0 elseif fadedAlpha > 1 then fadedAlpha = 1 end

    if cfg[CV_RULES.ALWAYS_HIDDEN] then
        return 0, false
    end

    local hoverEnabled = cfg[CV_RULES.MOUSEOVER] == true
    local hovered = CV_AnySharedHover(frameName, db.cooldownViewerSharedMouseover == true)
    local mounted = IsMounted and IsMounted() and true or false
    local inCombat = InCombatLockdown and InCombatLockdown() and true or false
    local hasTarget = UnitExists and UnitExists("target") and true or false
    local inGroup = IsInGroup and IsInGroup() and true or false
    local isCasting = CV_IsCasting()

    local hasShowRules = cfg[CV_RULES.IN_COMBAT]
        or cfg[CV_RULES.WHILE_MOUNTED]
        or cfg[CV_RULES.WHILE_NOT_MOUNTED]
        or cfg[CV_RULES.MOUSEOVER]
        or cfg[CV_RULES.PLAYER_HAS_TARGET]
        or cfg[CV_RULES.PLAYER_CASTING]
        or cfg[CV_RULES.PLAYER_IN_GROUP]

    if not hasShowRules then
        return 1, hoverEnabled
    end

    local shouldShow = false
    if cfg[CV_RULES.IN_COMBAT] and inCombat then shouldShow = true end
    if cfg[CV_RULES.WHILE_MOUNTED] and mounted then shouldShow = true end
    if cfg[CV_RULES.WHILE_NOT_MOUNTED] and not mounted then shouldShow = true end
    if cfg[CV_RULES.MOUSEOVER] and hovered then shouldShow = true end
    if cfg[CV_RULES.PLAYER_HAS_TARGET] and hasTarget then shouldShow = true end
    if cfg[CV_RULES.PLAYER_CASTING] and isCasting then shouldShow = true end
    if cfg[CV_RULES.PLAYER_IN_GROUP] and inGroup then shouldShow = true end

    if shouldShow then return 1, hoverEnabled end
    return fadedAlpha, hoverEnabled
end

local function CV_ScheduleRetry()
    if _cvRetryPending then return end
    if not (C_Timer and C_Timer.After) then return end
    if _cvRetryCount >= 6 then return end
    _cvRetryPending = true
    _cvRetryCount = _cvRetryCount + 1
    C_Timer.After(1, function()
        _cvRetryPending = false
        MSWA_ApplyCooldownViewerVisibility()
    end)
end

local function CV_UpdateHoverLoop(db)
    local wantsHover = false
    for i = 1, #CV_FRAME_NAMES do
        local cfg = db.cooldownViewerVisibility[CV_FRAME_NAMES[i]]
        if CV_UsesMouseover(cfg) then
            wantsHover = true
            break
        end
    end

    if wantsHover then
        _cvHoverAccum = 0
        _cvHoverFrame:Show()
    else
        wipe(_cvHoverState)
        _cvHoverFrame:Hide()
    end
end

function MSWA_ApplyCooldownViewerVisibility()
    local db = CV_GetDB()
    local missing = false

    for i = 1, #CV_FRAME_NAMES do
        local frameName = CV_FRAME_NAMES[i]
        local exists, frame = CV_FrameExists(frameName)
        local cfg = MSWA_GetCooldownViewerVisibility(frameName)

        if not exists then
            if cfg then missing = true end
        else
            if cfg then
                local alpha = CV_ComputeTargetAlpha(frameName, cfg, db)
                if frame.SetAlpha then frame:SetAlpha(alpha) end
                -- Do NOT call EnableMouse/DisableMouse on Blizzard Cooldown Viewer frames.
                -- These frames are protected and can taint/block when touched by addon code.
                -- Shared mouseover still works because we only read MouseIsOver(frame) and
                -- leave Blizzard's own mouse handling untouched.
            else
                _cvHoverState[frameName] = nil
                if frame.SetAlpha then frame:SetAlpha(1) end
            end
        end
    end

    CV_UpdateHoverLoop(db)

    if missing then
        CV_ScheduleRetry()
    else
        _cvRetryCount = 0
    end
end

_cvHoverFrame:SetScript("OnUpdate", function(self, elapsed)
    _cvHoverAccum = (_cvHoverAccum or 0) + (elapsed or 0)
    if _cvHoverAccum < 0.05 then return end
    _cvHoverAccum = 0

    local changed = false
    for i = 1, #CV_FRAME_NAMES do
        local frameName = CV_FRAME_NAMES[i]
        local frame = _G[frameName]
        local hovered = false
        if frame and frame.IsShown and frame:IsShown() and MouseIsOver then
            hovered = MouseIsOver(frame) and true or false
        end
        if _cvHoverState[frameName] ~= hovered then
            _cvHoverState[frameName] = hovered
            changed = true
        end
    end

    if changed then
        MSWA_ApplyCooldownViewerVisibility()
    end
end)

local function CV_ExtraEventHandler(_, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        if C_Timer and C_Timer.After then
            C_Timer.After(0, MSWA_ApplyCooldownViewerVisibility)
            C_Timer.After(1, MSWA_ApplyCooldownViewerVisibility)
        else
            MSWA_ApplyCooldownViewerVisibility()
        end
        return
    end

    if event == "UNIT_AURA" or event == "PLAYER_EQUIPMENT_CHANGED" then
        return
    end

    if event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if arg1 ~= "player" then return end
    end

    MSWA_ApplyCooldownViewerVisibility()
end

eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
if eventFrame.HookScript then
    eventFrame:HookScript("OnEvent", CV_ExtraEventHandler)
end
