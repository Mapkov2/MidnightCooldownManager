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
local _cdmCycleCache = {}  -- cleared once per UpdateSpells() cycle

function MSWA_BeginCDMAuraCycle()
    wipe(_cdmCycleCache)
end

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
    wipe(_cdmCycleCache)
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

    local cacheKey = tostring(cooldownID)
    local cycleEntry = _cdmCycleCache[cacheKey]
    if cycleEntry ~= nil then
        return cycleEntry ~= false and cycleEntry or nil
    end

    RebuildCDMFrameCache()

    local frame = _cdmFrameCache[cacheKey]
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
                if auraData then
                    _cdmCycleCache[cacheKey] = auraData
                    return auraData
                end
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
                    local synthetic = {
                        duration       = duration,
                        expirationTime = startTime + duration,
                        timeMod        = 1,
                        applications   = 0,
                        icon           = iconTex,
                        _isCDMTotem    = true,
                    }
                    _cdmCycleCache[cacheKey] = synthetic
                    return synthetic
                end
            end
        end
    end

    -- 3) Fallback: standard spellID-based lookup
    if fallbackSID then
        local auraData = MSWA_GetPlayerAuraDataBySpellID(fallbackSID)
        _cdmCycleCache[cacheKey] = auraData or false
        return auraData
    end
    _cdmCycleCache[cacheKey] = false
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

if eventFrame.RegisterUnitEvent then
    eventFrame:RegisterUnitEvent("UNIT_AURA", "player", "target")
else
    eventFrame:RegisterEvent("UNIT_AURA")
end
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

-- Named handler (no closure allocation)
local function OnEvent(_, event, arg1, arg2)
    if event == "UNIT_AURA" then
        if arg1 == "player" then
            _playerDirty = true
            wipe(_cdmCycleCache)
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
        wipe(_cdmCycleCache)
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
    wipe(_cdmCycleCache)
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

local _msaEssentialAttachCache = { viewer = nil, at = 0, width = 36, height = 36, spacing = 4, rows = nil }
local _msaEssentialAttachHosts = {}
local _msaEssentialActiveAttachments = {}
local _msaMSUFBridgeState = { proxy = nil, viewer = nil, extraLeft = 0, extraRight = 0, active = false, revision = 0 }
local _msaMSUFBridgeNotifyPending = false

local function CV_ScheduleMSUFBridgeNotify()
    if _msaMSUFBridgeNotifyPending then return end
    _msaMSUFBridgeNotifyPending = true
    local function _flush()
        _msaMSUFBridgeNotifyPending = false
        local cb = _G and _G.MSUF_OnCDMExtensionChanged
        if type(cb) == "function" then
            cb()
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, _flush)
    else
        _flush()
    end
end

local function CV_GetMSUFBridgeProxy(viewer)
    local state = _msaMSUFBridgeState
    local proxy = state.proxy
    if not proxy then
        proxy = CreateFrame("Frame", "MSWA_EssentialBridgeProxy", (viewer and viewer:GetParent()) or UIParent)
        proxy:EnableMouse(false)
        proxy:Hide()
        state.proxy = proxy
    end

    local desiredParent = (viewer and viewer:GetParent()) or UIParent
    if proxy:GetParent() ~= desiredParent then
        proxy:SetParent(desiredParent)
    end
    if viewer and viewer.GetFrameStrata and proxy.SetFrameStrata then
        proxy:SetFrameStrata(viewer:GetFrameStrata())
    end
    if viewer and viewer.GetFrameLevel and proxy.SetFrameLevel then
        proxy:SetFrameLevel((viewer:GetFrameLevel() or 0) + 1)
    end
    return proxy
end

local function CV_UpdateMSUFBridge(viewer, extraLeft, extraRight)
    local state = _msaMSUFBridgeState
    local active = viewer and ((extraLeft or 0) + (extraRight or 0)) > 0 and true or false
    local changed = false

    if active and viewer then
        local proxy = CV_GetMSUFBridgeProxy(viewer)
        proxy:ClearAllPoints()
        proxy:SetPoint("TOPLEFT", viewer, "TOPLEFT", -(extraLeft or 0), 0)
        proxy:SetPoint("BOTTOMRIGHT", viewer, "BOTTOMRIGHT", (extraRight or 0), 0)
        proxy:Show()
    elseif state.proxy then
        state.proxy:ClearAllPoints()
        state.proxy:Hide()
    end

    if state.viewer ~= viewer then changed = true end
    if math.abs((state.extraLeft or 0) - (extraLeft or 0)) > 0.5 then changed = true end
    if math.abs((state.extraRight or 0) - (extraRight or 0)) > 0.5 then changed = true end
    if (state.active and true or false) ~= active then changed = true end

    state.viewer = viewer
    state.extraLeft = extraLeft or 0
    state.extraRight = extraRight or 0
    state.active = active and true or false

    if changed then
        state.revision = (state.revision or 0) + 1
        CV_ScheduleMSUFBridgeNotify()
    end
end

function MSWA_GetOrCreateEssentialBridgeProxy()
    local viewer = _G["EssentialCooldownViewer"] or _G["CooldownManager"]
    if viewer and (not viewer.IsForbidden or not viewer:IsForbidden()) then
        return CV_GetMSUFBridgeProxy(viewer)
    end
    return _msaMSUFBridgeState.proxy
end

function MSWA_GetEssentialBridgeFrame()
    local state = _msaMSUFBridgeState
    if state and state.active and state.proxy then
        return state.proxy
    end
    return MSWA_GetEssentialCooldownViewerFrame and MSWA_GetEssentialCooldownViewerFrame() or (_G["EssentialCooldownViewer"] or _G["CooldownManager"])
end

function MSWA_GetEssentialBridgeRevision()
    return (_msaMSUFBridgeState and _msaMSUFBridgeState.revision) or 0
end

local function CV_GetAttachHostToken(key)
    if MSWA_KeyToTrinketSlot then
        local slot = MSWA_KeyToTrinketSlot(key)
        if slot then return tostring(slot) end
    end
    return tostring(key or "msa")
end

local function CV_GetFirstPointTuple(frame)
    if not frame or not frame.GetPoint then return nil end
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    return point, relativeTo, relativePoint, xOfs, yOfs
end

local function CV_PointHasSide(point, token)
    return type(point) == "string" and point:find(token, 1, true) ~= nil
end

local function CV_ApplyViewerBounds(viewer)
    if not viewer or (viewer.IsForbidden and viewer:IsForbidden()) then return end

    local extraLeft, extraRight = 0, 0
    local viewerLeft = viewer.GetLeft and viewer:GetLeft() or nil
    local viewerRight = viewer.GetRight and viewer:GetRight() or nil

    for _, entry in pairs(_msaEssentialActiveAttachments) do
        if entry and entry.viewer == viewer then
            local width = entry.width or 0
            local offsetX = entry.offsetX or 0
            local row = entry.row
            if entry.side == "START" then
                local baseLeft = nil
                if row and row.leftButton and row.leftButton.left then
                    baseLeft = row.leftButton.left
                elseif type(viewerLeft) == "number" then
                    baseLeft = viewerLeft
                end
                if type(baseLeft) == "number" and type(viewerLeft) == "number" then
                    local outerLeft = baseLeft + offsetX - width
                    local need = viewerLeft - outerLeft
                    if type(need) == "number" and need > extraLeft then extraLeft = need end
                end
            else
                local baseRight = nil
                if row and row.rightButton and row.rightButton.right then
                    baseRight = row.rightButton.right
                elseif type(viewerRight) == "number" then
                    baseRight = viewerRight
                end
                if type(baseRight) == "number" and type(viewerRight) == "number" then
                    local outerRight = baseRight + offsetX + width
                    local need = outerRight - viewerRight
                    if type(need) == "number" and need > extraRight then extraRight = need end
                end
            end
        end
    end

    if extraLeft < 0 then extraLeft = 0 end
    if extraRight < 0 then extraRight = 0 end

    CV_UpdateMSUFBridge(viewer, extraLeft, extraRight)
end

function MSWA_RegisterActiveEssentialAttachment(key, layout)
    if not key or type(layout) ~= "table" or not layout.viewer then return end
    _msaEssentialActiveAttachments[tostring(key)] = {
        viewer = layout.viewer,
        side = layout.side or "END",
        row = layout.row,
        offsetX = layout.offsetX or 0,
        width = layout.width or 0,
    }
    CV_ApplyViewerBounds(layout.viewer)
end

function MSWA_UnregisterActiveEssentialAttachment(key)
    if not key then return end
    local token = tostring(key)
    local entry = _msaEssentialActiveAttachments[token]
    _msaEssentialActiveAttachments[token] = nil
    if entry and entry.viewer then
        CV_ApplyViewerBounds(entry.viewer)
    end
end

function MSWA_GetEssentialAttachHost(key, viewer)
    if not key then return nil end
    viewer = viewer or MSWA_GetEssentialCooldownViewerFrame()
    if not viewer then return nil end

    local token = CV_GetAttachHostToken(key)
    local host = _msaEssentialAttachHosts[token]
    if not host then
        host = CreateFrame("Frame", nil, viewer)
        host:SetSize(1, 1)
        host:EnableMouse(false)
        host:Hide()
        _msaEssentialAttachHosts[token] = host
    elseif host:GetParent() ~= viewer then
        host:SetParent(viewer)
    end

    if viewer.GetFrameStrata and host.SetFrameStrata then
        host:SetFrameStrata(viewer:GetFrameStrata())
    end
    if viewer.GetFrameLevel and host.SetFrameLevel then
        host:SetFrameLevel((viewer:GetFrameLevel() or 0) + 5)
    end

    return host
end

function MSWA_HideEssentialAttachHost(key)
    if not key then return end
    local token = CV_GetAttachHostToken(key)
    local host = _msaEssentialAttachHosts[token]
    if host then
        host:ClearAllPoints()
        host:Hide()
    end
    MSWA_UnregisterActiveEssentialAttachment(key)
end

local function CV_SafeBool(val)
    if val == nil then return false end
    if _issecretvalue and _issecretvalue(val) then return false end
    return val == true
end

local function CV_SafeIsShown(frame)
    if not frame or not frame.IsShown then return false end
    local ok, shown = pcall(frame.IsShown, frame)
    if not ok then return false end
    return CV_SafeBool(shown)
end

local function CV_SafeObjectType(frame)
    if not frame or not frame.GetObjectType then return nil end
    local ok, objectType = pcall(frame.GetObjectType, frame)
    if not ok or (_issecretvalue and _issecretvalue(objectType)) then return nil end
    if type(objectType) ~= "string" then return nil end
    return objectType
end

local function CV_SafeNumberMethod(frame, methodName)
    local method = frame and frame[methodName]
    if not method then return nil end
    local ok, value = pcall(method, frame)
    if not ok or (_issecretvalue and _issecretvalue(value)) then return nil end
    if type(value) ~= "number" then return nil end
    return value
end

local function CV_SafeCenter(frame)
    if not frame or not frame.GetCenter then return nil, nil end
    local ok, x, y = pcall(frame.GetCenter, frame)
    if not ok then return nil, nil end
    if (_issecretvalue and ((_issecretvalue(x)) or (_issecretvalue(y)))) then return nil, nil end
    if type(x) ~= "number" or type(y) ~= "number" then return nil, nil end
    return x, y
end

local function CV_IsMSAAttachButton(frame)
    if not frame then return false end
    if frame.spellID ~= nil then return true end
    local name = (frame.GetName and frame:GetName()) or nil
    return type(name) == "string" and name:find("MidnightSimpleAurasIcon", 1, true) == 1
end

local function CV_FindVisibleButtonMetrics(root, depth)
    if not root or depth < 0 or not root.GetChildren then return nil, nil end
    local kids = { root:GetChildren() }
    for i = 1, #kids do
        local child = kids[i]
        if child and (not CV_IsMSAAttachButton(child)) and CV_SafeObjectType(child) == "Button" and CV_SafeIsShown(child) then
            local w = CV_SafeNumberMethod(child, "GetWidth")
            local h = CV_SafeNumberMethod(child, "GetHeight")
            if type(w) == "number" and type(h) == "number" and w >= 18 and w <= 80 and h >= 18 and h <= 80 then
                return w, h
            end
        end
    end
    if depth <= 0 then return nil, nil end
    for i = 1, #kids do
        local w, h = CV_FindVisibleButtonMetrics(kids[i], depth - 1)
        if w and h then return w, h end
    end
    return nil, nil
end

local function CV_CollectVisibleButtons(root, depth, out)
    if not root or depth < 0 or not root.GetChildren then return out end
    out = out or {}
    local kids = { root:GetChildren() }
    for i = 1, #kids do
        local child = kids[i]
        if child and (not CV_IsMSAAttachButton(child)) and CV_SafeIsShown(child) and CV_SafeObjectType(child) == "Button" then
            local w = CV_SafeNumberMethod(child, "GetWidth")
            local h = CV_SafeNumberMethod(child, "GetHeight")
            local x, y = CV_SafeCenter(child)
            if type(w) == "number" and type(h) == "number" and type(x) == "number" and type(y) == "number" and w >= 18 and w <= 80 and h >= 18 and h <= 80 then
                out[#out + 1] = {
                    frame = child,
                    width = w,
                    height = h,
                    cx = x,
                    cy = y,
                    left = x - (w * 0.5),
                    right = x + (w * 0.5),
                    top = y + (h * 0.5),
                    bottom = y - (h * 0.5),
                }
            end
        end
    end
    if depth <= 0 then return out end
    for i = 1, #kids do
        CV_CollectVisibleButtons(kids[i], depth - 1, out)
    end
    return out
end

local function CV_BuildRowsFromButtons(buttons)
    if type(buttons) ~= "table" or #buttons == 0 then return nil end

    table.sort(buttons, function(a, b)
        if a.cy == b.cy then return a.cx < b.cx end
        return a.cy > b.cy
    end)

    local avgH = 0
    for i = 1, #buttons do avgH = avgH + (buttons[i].height or 0) end
    avgH = (#buttons > 0) and (avgH / #buttons) or 36
    local rowThreshold = math.max(8, math.floor((avgH * 0.45) + 0.5))

    local rows = {}
    for i = 1, #buttons do
        local b = buttons[i]
        local placed = false
        for r = 1, #rows do
            local row = rows[r]
            if math.abs((b.cy or 0) - (row.cy or 0)) <= rowThreshold then
                row.buttons[#row.buttons + 1] = b
                row.cy = ((row.cy * row.count) + b.cy) / (row.count + 1)
                row.count = row.count + 1
                placed = true
                break
            end
        end
        if not placed then
            rows[#rows + 1] = { buttons = { b }, cy = b.cy, count = 1 }
        end
    end

    table.sort(rows, function(a, b) return (a.cy or 0) > (b.cy or 0) end)

    for r = 1, #rows do
        local row = rows[r]
        table.sort(row.buttons, function(a, b) return (a.cx or 0) < (b.cx or 0) end)
        row.index = r
        row.leftButton = row.buttons[1]
        row.rightButton = row.buttons[#row.buttons]

        local width, height = 0, 0
        local totalGap, gapCount = 0, 0
        for i = 1, #row.buttons do
            local b = row.buttons[i]
            width = width + (b.width or 0)
            height = height + (b.height or 0)
            if i > 1 then
                local prev = row.buttons[i - 1]
                local gap = (b.left or 0) - (prev.right or 0)
                if type(gap) == "number" and gap >= 0 and gap <= 40 then
                    totalGap = totalGap + gap
                    gapCount = gapCount + 1
                end
            end
        end
        row.width = (#row.buttons > 0) and (width / #row.buttons) or 36
        row.height = (#row.buttons > 0) and (height / #row.buttons) or 36
        row.spacing = (gapCount > 0) and (totalGap / gapCount) or 4
    end

    return rows
end

local function CV_RoundPixel(v)
    v = tonumber(v) or 0
    return math.floor(v + (v >= 0 and 0.5 or -0.5))
end

local function CV_ResolveAttachRowIndex(rows, pref)
    if type(rows) ~= "table" or #rows == 0 then return 1 end
    if pref == "ROW2" and rows[2] then return 2 end
    if pref == "ROW1" and rows[1] then return 1 end
    return 1
end

function MSWA_GetEssentialCooldownViewerFrame()
    local f = _G["EssentialCooldownViewer"] or _G["CooldownManager"]
    if not f then return nil end
    if CV_SafeIsShown(f) then return f end
    -- Keep using the real viewer frame even during transient visibility/layout churn.
    -- This avoids attached trinkets falling back to standalone positioning and
    -- visually "disappearing" when Blizzard momentarily rebuilds the viewer.
    return f
end

function MSWA_GetAttachedTrinketLayout(key)
    if not (MSWA_IsTrinketKey and MSWA_IsTrinketKey(key)) then return nil end

    local viewer = MSWA_GetEssentialCooldownViewerFrame()
    if not viewer then return nil end

    local now = (GetTimePreciseSec and GetTimePreciseSec()) or (GetTime and GetTime()) or 0
    local cache = _msaEssentialAttachCache
    if cache.viewer ~= viewer or (now - (cache.at or 0)) > 0.25 then
        local oldViewer = cache.viewer
        local oldWidth = cache.width
        local oldHeight = cache.height
        local oldSpacing = cache.spacing
        local oldRows = cache.rows

        local w, h = CV_FindVisibleButtonMetrics(viewer, 2)
        local rows = CV_BuildRowsFromButtons(CV_CollectVisibleButtons(viewer, 3, {}))
        if rows and rows[1] then
            w = rows[1].width or w
            h = rows[1].height or h
        end
        if not w or not h then
            local vh = viewer.GetHeight and viewer:GetHeight() or nil
            if type(vh) == "number" and vh >= 20 and vh <= 96 then
                w, h = vh, vh
            end
        end

        cache.viewer = viewer
        cache.at = now

        if type(w) == "number" and w > 0 then
            cache.width = math.floor(w + 0.5)
        elseif oldViewer == viewer and type(oldWidth) == "number" and oldWidth > 0 then
            cache.width = oldWidth
        else
            cache.width = 36
        end

        if type(h) == "number" and h > 0 then
            cache.height = math.floor(h + 0.5)
        elseif oldViewer == viewer and type(oldHeight) == "number" and oldHeight > 0 then
            cache.height = oldHeight
        else
            cache.height = 36
        end

        if rows and rows[1] then
            cache.rows = rows
            cache.spacing = rows[1].spacing or 4
        elseif oldViewer == viewer and oldRows and oldRows[1] then
            cache.rows = oldRows
            cache.spacing = oldSpacing or 4
        else
            cache.rows = nil
            cache.spacing = 4
        end
    end

    local db = MSWA_GetDB()
    local tracked = db and db.trackedSpells or nil
    local settings = db and db.spellSettings or nil
    local s = settings and (settings[key] or settings[tostring(key)]) or nil
    local side = (s and s.attachEssentialSide) or "END"
    local rowPref = (s and s.attachEssentialRow) or "AUTO"
    local exactSpacing = (s and s.attachEssentialExactSpacing) ~= false
    local fineX = (s and tonumber(s.attachEssentialOffsetX)) or 0
    local fineY = (s and tonumber(s.attachEssentialOffsetY)) or 0
    local rowIndex = CV_ResolveAttachRowIndex(cache.rows, rowPref)
    local row = cache.rows and cache.rows[rowIndex] or nil

    local aw = row and row.width or cache.width or 36
    local ah = row and row.height or cache.height or 36
    local asp = exactSpacing and row and row.spacing or cache.spacing or 4
    if not asp or asp < 0 then asp = 4 end

    local prior = 0
    local ordered = { "trinket:13", "trinket:14" }
    local inCombat = InCombatLockdown and InCombatLockdown() and true or false
    local inEncounter = IsEncounterInProgress and IsEncounterInProgress() and true or false
    local previewMode = MSWA and MSWA.previewMode and true or false
    local optFrame = MSWA and MSWA.optionsFrame or nil
    local selectedKey = (optFrame and optFrame.IsShown and optFrame:IsShown() and MSWA.selectedSpellID) or nil

    for i = 1, #ordered do
        local tk = ordered[i]
        if tk == key then break end

        local os = settings and (settings[tk] or settings[tostring(tk)]) or nil
        local otherItemID = MSWA_GetTrinketItemID(MSWA_KeyToTrinketSlot(tk))
        local otherShouldLoad = os and MSWA_ShouldLoadAura and MSWA_ShouldLoadAura(os, inCombat, inEncounter)
        local otherVisible = tracked and tracked[tk] and otherItemID and os and os.attachToEssential and (otherShouldLoad or previewMode or tk == selectedKey)

        if otherVisible then
            local otherSide = os.attachEssentialSide or "END"
            local otherRow = CV_ResolveAttachRowIndex(cache.rows, os.attachEssentialRow or "AUTO")
            if otherSide == side and otherRow == rowIndex then
                prior = prior + 1
            end
        end
    end

    local anchorTo = nil
    local point, relPoint, offX = nil, nil, 0
    if row and row.leftButton and row.rightButton then
        if side == "START" then
            anchorTo = row.leftButton.frame
            point, relPoint = "RIGHT", "LEFT"
            offX = -((asp or 4) + (prior * ((aw or 36) + (asp or 4))))
        else
            anchorTo = row.rightButton.frame
            point, relPoint = "LEFT", "RIGHT"
            offX = (asp or 4) + (prior * ((aw or 36) + (asp or 4)))
        end
    else
        anchorTo = viewer
        if side == "START" then
            point, relPoint = "RIGHT", "LEFT"
            offX = -((asp or 4) + (prior * ((aw or 36) + (asp or 4))))
        else
            point, relPoint = "LEFT", "RIGHT"
            offX = (asp or 4) + (prior * ((aw or 36) + (asp or 4)))
        end
    end

    local finalOffsetX = CV_RoundPixel((((offX or 0) + fineX) or 0))
    local finalOffsetY = CV_RoundPixel((fineY or 0))

    return {
        viewer = viewer,
        anchorTo = anchorTo,
        anchorPoint = point,
        relativePoint = relPoint,
        offsetX = finalOffsetX,
        offsetY = finalOffsetY,
        width = math.floor((aw or 36) + 0.5),
        height = math.floor((ah or 36) + 0.5),
        spacing = asp,
        prior = prior,
        side = side,
        rowIndex = rowIndex,
        row = row,
    }
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
        if frame and CV_SafeIsShown(frame) and MouseIsOver then
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
