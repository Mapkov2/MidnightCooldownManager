-- ########################################################
-- MSA_UpdateEngine.lua  (v8 – per-button cache, inlined tick)
--
-- v8: Per-button metadata cached during full redraw:
--   btn._msaS        = settings reference (no tostring fallback in tick)
--   btn._msaSID      = numeric spellID (no MSWA_KeyToSpellID in tick)
--   btn._msaIID      = numeric itemID  (no MSWA_KeyToItemID in tick)
--   btn._msaIsItem   = bool
--   TickVisuals reads these directly → zero string ops per tick.
--
--   MSWA_IsCooldownActive inlined in tick path.
--   select(1, ...) eliminated from MSWA_GetSpellGlowRemaining calls.
--   Haste cached once per frame, not per-icon.
--
-- Perf fixes vs v6:
--   • Two-path engine: full redraw vs lightweight tick
--     Full redraw  = event-driven (dirty flag from game events)
--     Lightweight tick = only glow/textcolor remaining calcs
--     Normal CDs without glow/textcolor = ZERO engine ticks
--
--   • Per-button visual state cache (_msaVS):
--     Tracks alpha, desat, shown state.
--     Skips Blizzard API calls when state is unchanged.
--
--   • ALL pcall removed from UpdateEngine:
--     GetItemCooldown returns plain Lua values, NOT secret.
--     Direct inline comparison = fastest possible path.
--
--   • Unified handlers (4 modes × unified source abstraction)
--     Less code = less instruction cache pressure.
--
--   • PositionButton + ClearAllPoints ONLY on full redraw.
--     Timer ticks skip them entirely.
--
--   • BuffVisual (pcall in SpellAPI.lua) ONLY on full redraw.
--     Stacks don't change on timer ticks.
--
--   • CooldownFrame ONLY updated on full redraw.
--     Blizzard's CooldownFrameTemplate handles animation.
--
-- Prior fixes preserved:
--   • GetTime() cached once per OnUpdate frame
--   • AutoBuffTick throttled to 10 Hz
--   • Text/Stack style dirty-flagged via _msaStyleKey
--   • Glow remaining calc shares cached now-time
--   • db fetched once, passed through everywhere
--   • needsTimerTick only set for glow/textColor2 conditions
-- ########################################################

local pairs, type, tonumber, tostring = pairs, type, tonumber, tostring
local GetTime         = GetTime
local GetItemCooldown = GetItemCooldown
local GetItemIcon     = GetItemIcon
local wipe            = wipe or table.wipe

-----------------------------------------------------------
-- Constants
-----------------------------------------------------------

local THROTTLE_INTERVAL = 0.100   -- 10 Hz

-----------------------------------------------------------
-- Haste-scaled Auto Buff duration helper
-----------------------------------------------------------

local UnitSpellHaste = UnitSpellHaste

local function GetEffectiveBuffDuration(s)
    local dur = tonumber(s and s.autoBuffDuration) or 10
    if dur < 0.1 then dur = 0.1 end
    if s and s.hasteScaling and UnitSpellHaste then
        local h = tonumber(UnitSpellHaste("player")) or 0
        if h > 0 then
            dur = dur / (1 + h / 100)
        end
    end
    return dur
end

-----------------------------------------------------------
-- Engine frame (hidden = zero CPU)
-----------------------------------------------------------

local engineFrame = CreateFrame("Frame", "MSWA_EngineFrame", UIParent)
engineFrame:Hide()

local dirty              = false
local autoBuffActive     = false
local needsTimerTick     = false
local lastFullUpdate     = 0
local forceImmediate     = false
local lastActiveCount    = 0

-----------------------------------------------------------
-- Forward-declared
-----------------------------------------------------------

local MSWA_UpdateEventRegistration

-----------------------------------------------------------
-- Icon state cache
-----------------------------------------------------------

local iconCache = {}

local function WipeIconCache()
    for i = 1, MSWA.MAX_ICONS do
        iconCache[i] = nil
    end
end

-----------------------------------------------------------
-- Item key cache (avoid string.format in hot loop)
-----------------------------------------------------------

local itemKeyCache = {}

local function GetItemKey(itemID)
    local k = itemKeyCache[itemID]
    if not k then
        k = ("item:%d"):format(itemID)
        itemKeyCache[itemID] = k
    end
    return k
end

-----------------------------------------------------------
-- PositionButton (top-level, zero closure allocation)
-----------------------------------------------------------

local function PositionButton(btn, s, key, idx, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
    local gid = MSWA_GetAuraGroup and MSWA_GetAuraGroup(key) or (_G.GetAuraGroup and _G.GetAuraGroup(key) or nil)
    local group = gid and db.groups and db.groups[gid] or nil

    if group then
        local gf = nil

        if groupCtx then
            groupCtx.used[gid] = true
            if not groupCtx.applied[gid] and type(MSWA_ApplyGroupAnchorFrame) == "function" then
                gf = MSWA_ApplyGroupAnchorFrame(gid, group)
                groupCtx.frames[gid] = gf
                groupCtx.applied[gid] = true
            else
                gf = groupCtx.frames[gid]
                if not gf and type(MSWA_GetOrCreateGroupAnchorFrame) == "function" then
                    gf = MSWA_GetOrCreateGroupAnchorFrame(gid)
                    groupCtx.frames[gid] = gf
                end
            end
        elseif type(MSWA_ApplyGroupAnchorFrame) == "function" then
            gf = MSWA_ApplyGroupAnchorFrame(gid, group)
        end

        if not gf then gf = frame end

        btn:SetPoint("CENTER", gf, "CENTER", (s and s.x or 0), (s and s.y or 0))

        local size = group.size or ICON_SIZE
        local w = (s and s.width) or size
        local h = (s and s.height) or size
        btn:SetSize(w, h)

        if groupCtx then
            local b = groupCtx.bounds[gid]
            if not b then
                b = { init = false, minL = 0, maxR = 0, minB = 0, maxT = 0 }
                groupCtx.bounds[gid] = b
            end
            local x = (s and s.x) or 0
            local y = (s and s.y) or 0
            local halfW = w * 0.5
            local halfH = h * 0.5
            local left  = x - halfW
            local right = x + halfW
            local bot   = y - halfH
            local top   = y + halfH
            if not b.init then
                b.init = true
                b.minL = left; b.maxR = right
                b.minB = bot;  b.maxT = top
            else
                if left  < b.minL then b.minL = left end
                if right > b.maxR then b.maxR = right end
                if bot   < b.minB then b.minB = bot end
                if top   > b.maxT then b.maxT = top end
            end
        end
    else
        local anchorFrame = MSWA_GetAnchorFrame(s or {})
        local lx = s and s.x or 0
        local ly = s and s.y or 0
        if s and s.anchorFrame then
            btn:SetPoint("CENTER", anchorFrame, "CENTER", lx, ly)
        elseif s and s.x and s.y then
            btn:SetPoint("CENTER", frame, "CENTER", lx, ly)
        else
            btn:SetPoint("LEFT", frame, "LEFT", (idx - 1) * (ICON_SIZE + ICON_SPACE), 0)
        end
        if s and s.width and s.height then
            btn:SetSize(s.width, s.height)
        else
            btn:SetSize(ICON_SIZE, ICON_SIZE)
        end
    end
end

-----------------------------------------------------------
-- Inline helpers
-----------------------------------------------------------

local function ClearStackAndCount(btn)
    if btn.count then btn.count:SetText(""); btn.count:Hide() end
    if btn.stackText then btn.stackText:SetText(""); btn.stackText:Hide() end
end

local function IsItemZeroCount(s, itemID)
    if not s or not s.showOnZeroCount or not itemID then return false end
    if not GetItemCount then return false end
    local cnt = GetItemCount(itemID, false, false)
    return cnt and cnt <= 0
end

local function HideButton(btn)
    btn:Hide()
    btn.icon:SetTexture(nil)
    btn._msaCachedKey = nil
    btn._msaStyleKey  = nil
    btn._msaVS        = nil
    btn._msaS         = nil
    btn._msaSID       = nil
    btn._msaIID       = nil
    btn._msaIsItem    = nil
    MSWA_ClearCooldownFrame(btn.cooldown)
    MSWA_StopGlow(btn)
    MSWA_HideReminderLabel(btn)
    MSWA_HideChargeLabel(btn)
    btn.spellID = nil
end

-----------------------------------------------------------
-- SetIconTexture with cache
-----------------------------------------------------------

local function SetIconTexture(btn, key)
    if btn._msaCachedKey == key then return end
    btn._msaCachedKey = key
    btn.icon:SetTexture(MSWA_GetIconForKey(key))
end

-----------------------------------------------------------
-- Text/Stack style with dirty-flag
-----------------------------------------------------------

local function ApplyStylesIfDirty(btn, db, s, key)
    if btn._msaStyleKey == key then return end
    btn._msaStyleKey = key
    MSWA_ApplyTextStyle(btn, db, s)
    MSWA_ApplyStackStyle_Fast(btn, s, db)
end

-----------------------------------------------------------
-- Alpha computation
-----------------------------------------------------------

local function ComputeAlpha(s, isOnCD, inCombat)
    local alpha = 1.0
    if inCombat then
        local ca = s and tonumber(s.combatAlpha)
        if ca then alpha = alpha * ca end
    else
        local oa = s and tonumber(s.oocAlpha)
        if oa then alpha = alpha * oa end
    end
    if isOnCD then
        local cda = s and tonumber(s.cdAlpha)
        if cda then alpha = alpha * cda end
    end
    return alpha
end

-----------------------------------------------------------
-- v7: Item CD helpers (plain Lua values – NO pcall needed)
-- GetItemCooldown returns plain numbers, not secret values.
-- Secret values only affect C_Spell APIs, not item APIs.
-----------------------------------------------------------

local function GetItemCDState(itemID)
    if not GetItemCooldown then return false, 0, 0 end
    local iStart, iDuration = GetItemCooldown(itemID)
    if iStart and iStart > 0 and iDuration and iDuration > 1.5 then
        return true, iStart, iDuration
    end
    return false, 0, 0
end

local function GetItemRemaining(itemID, now)
    if not GetItemCooldown then return 0 end
    local st, dur = GetItemCooldown(itemID)
    if st and st > 0 and dur and dur > 1.5 then
        local r = (st + dur) - now
        return r > 0 and r or 0
    end
    return 0
end

-----------------------------------------------------------
-- v7: Per-button visual state cache
-- Skips Blizzard API calls when values are unchanged.
-----------------------------------------------------------

local function GetOrCreateVS(btn)
    local vs = btn._msaVS
    if not vs then
        vs = { alpha = -1, desat = -1, shown = false }
        btn._msaVS = vs
    end
    return vs
end

local function SetAlphaCached(btn, alpha)
    local vs = GetOrCreateVS(btn)
    if vs.alpha == alpha then return end
    vs.alpha = alpha
    btn:SetAlpha(alpha)
end

local function SetDesatCached(btn, desat)
    local val = desat and 1 or 0
    local vs = GetOrCreateVS(btn)
    if vs.desat == val then return end
    vs.desat = val
    btn.icon:SetDesaturated(desat)
end

local function ShowCached(btn)
    local vs = GetOrCreateVS(btn)
    if vs.shown then return end
    vs.shown = true
    btn:Show()
end

-----------------------------------------------------------
-- v7: Unified mode handlers
-- Each handles ONE aura regardless of source type.
-- Source-specific behaviour via isItem/spellID/itemID.
--
-- flags table modified in place: { cooldown, autoBuff, timerTick }
-- Returns: newIndex (index+1) or nil if button hidden
-----------------------------------------------------------

local function Handle_AutoBuff(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                               groupCtx, now, inCombat, previewMode, selectedKey,
                               autoBuff, isItem, spellID, itemID,
                               flags, hasGetCD, hasGetCDRemaining)
    local isBuffThenCD = (s.auraMode == "BUFF_THEN_CD")
    local ab = autoBuff[key]
    local buffDur = GetEffectiveBuffDuration(s)
    local buffDelay = tonumber(s.autoBuffDelay) or 0
    local timerStart = ab and (ab.startTime + buffDelay) or 0

    local inBuffPhase = false
    if ab and ab.active then
        local totalWindow = buffDelay + buffDur
        if (now - ab.startTime) < totalWindow then
            inBuffPhase = true
            flags.autoBuff = true; flags.timerTick = true
        else
            ab.active = false
        end
    end

    if inBuffPhase then
        btn:ClearAllPoints()
        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
        MSWA_ApplyCooldownFrame(btn.cooldown, timerStart, buffDur, 1)
        local desat = isItem and IsItemZeroCount(s, itemID) or false
        SetDesatCached(btn, desat)
        SetAlphaCached(btn, ComputeAlpha(s, true, inCombat))
        MSWA_UpdateBuffVisual_Fast(btn, s, spellID, isItem, itemID)

        local glowRem = buffDur - (now - timerStart)
        if glowRem < 0 then glowRem = 0 end
        local gs = s.glow
        if gs and gs.enabled then
            MSWA_UpdateGlow_Fast(btn, gs, glowRem, glowRem > 0)
        elseif btn._msaGlowActive then
            MSWA_StopGlow(btn)
        end
        MSWA_ApplyConditionalTextColor_Fast(btn, s, db, glowRem, glowRem > 0)
        MSWA_ApplySwipeDarken_Fast(btn, s)
        flags.cooldown = true
        return index + 1

    elseif isBuffThenCD then
        btn:ClearAllPoints()
        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)

        if isItem then
            local onCD, iStart, iDuration = GetItemCDState(itemID)
            if onCD then
                MSWA_ApplyCooldownFrame(btn.cooldown, iStart, iDuration, 1)
            else
                MSWA_ClearCooldownFrame(btn.cooldown)
            end
        else
            local cdInfo = hasGetCD and C_Spell.GetSpellCooldown(spellID)
            if cdInfo then
                local exp = cdInfo.expirationTime
                if hasGetCDRemaining then
                    local rem = C_Spell.GetSpellCooldownRemaining(spellID)
                    if type(rem) == "number" then exp = now + rem end
                end
                MSWA_ApplyCooldownFrame(btn.cooldown, cdInfo.startTime, cdInfo.duration, cdInfo.modRate, exp, spellID)
            else
                MSWA_ClearCooldownFrame(btn.cooldown)
            end
        end

        MSWA_UpdateBuffVisual_Fast(btn, s, spellID, isItem, itemID)
        local onCD = MSWA_IsCooldownActive(btn)
        if onCD then flags.cooldown = true end

        if onCD then
            local desat = s.grayOnCooldown and true or false
            if isItem and IsItemZeroCount(s, itemID) then desat = true end
            SetDesatCached(btn, desat)
            SetAlphaCached(btn, ComputeAlpha(s, true, inCombat))

            local rem = 0
            local needTime = (s.glow and s.glow.enabled) or s.textColor2Enabled
            if needTime then
                flags.timerTick = true
                if isItem then
                    rem = GetItemRemaining(itemID, now)
                else
                    local r = MSWA_GetSpellGlowRemaining(spellID, now)
                    if r > 0 then rem = r end
                end
            end
            local gs = s.glow
            if gs and gs.enabled then
                MSWA_UpdateGlow_Fast(btn, gs, rem, true)
            elseif btn._msaGlowActive then
                MSWA_StopGlow(btn)
            end
            MSWA_ApplyConditionalTextColor_Fast(btn, s, db, rem, true)
            MSWA_ApplySwipeDarken_Fast(btn, s)
            return index + 1
        elseif previewMode or key == selectedKey then
            local desat = isItem and IsItemZeroCount(s, itemID) or false
            SetDesatCached(btn, desat)
            SetAlphaCached(btn, ComputeAlpha(s, false, inCombat))
            MSWA_UpdateBuffVisual_Fast(btn, s, spellID, isItem, itemID)
            MSWA_StopGlow(btn)
            return index + 1
        else
            MSWA_ClearCooldownFrame(btn.cooldown)
            local desat = isItem and IsItemZeroCount(s, itemID) or false
            SetDesatCached(btn, desat)
            SetAlphaCached(btn, ComputeAlpha(s, false, inCombat))
            MSWA_UpdateBuffVisual_Fast(btn, s, spellID, isItem, itemID)
            MSWA_StopGlow(btn)
            return index + 1
        end

    elseif previewMode or key == selectedKey then
        btn:ClearAllPoints()
        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
        MSWA_ClearCooldownFrame(btn.cooldown)
        SetDesatCached(btn, false)
        SetAlphaCached(btn, ComputeAlpha(s, false, inCombat))
        MSWA_UpdateBuffVisual_Fast(btn, s, spellID, isItem, itemID)
        MSWA_StopGlow(btn)
        return index + 1
    else
        -- Item showOnZeroCount: keep visible but grayed when count=0
        if isItem and IsItemZeroCount(s, itemID) then
            btn:ClearAllPoints()
            PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
            MSWA_ClearCooldownFrame(btn.cooldown)
            SetDesatCached(btn, true)
            SetAlphaCached(btn, ComputeAlpha(s, false, inCombat))
            MSWA_UpdateBuffVisual_Fast(btn, s, spellID, isItem, itemID)
            MSWA_StopGlow(btn)
            return index + 1
        end
        HideButton(btn)
        return nil
    end
end


local function Handle_ReminderBuff(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                                    groupCtx, now, inCombat, previewMode, selectedKey,
                                    autoBuff, isItem, spellID, itemID, flags)
    local ab = autoBuff[key]
    local buffDur = GetEffectiveBuffDuration(s)
    local buffDelay = tonumber(s.autoBuffDelay) or 0

    local inBuffPhase = false
    if ab and ab.active then
        local totalWindow = buffDelay + buffDur
        if (now - ab.startTime) < totalWindow then
            inBuffPhase = true
            flags.autoBuff = true; flags.timerTick = true
        else
            ab.active = false
        end
    end

    if not inBuffPhase then
        btn:ClearAllPoints()
        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
        MSWA_ClearCooldownFrame(btn.cooldown)
        local desat = isItem and IsItemZeroCount(s, itemID) or false
        SetDesatCached(btn, desat)
        SetAlphaCached(btn, ComputeAlpha(s, false, inCombat))
        ClearStackAndCount(btn)
        MSWA_ShowReminderLabel(btn, s, db)

        local gs = s.glow
        if gs and gs.enabled then
            MSWA_UpdateGlow_Fast(btn, gs, 9999, true)
        elseif btn._msaGlowActive then
            MSWA_StopGlow(btn)
        end
        MSWA_ApplyConditionalTextColor_Fast(btn, s, db, 0, false)
        return index + 1

    elseif s.reminderShowTimer then
        btn:ClearAllPoints()
        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
        local timerStart = ab.startTime + buffDelay
        MSWA_ApplyCooldownFrame(btn.cooldown, timerStart, buffDur, 1)
        local desat = isItem and IsItemZeroCount(s, itemID) or false
        SetDesatCached(btn, desat)
        SetAlphaCached(btn, ComputeAlpha(s, true, inCombat))
        ClearStackAndCount(btn)
        MSWA_HideReminderLabel(btn)

        local glowRem = buffDur - (now - timerStart)
        if glowRem < 0 then glowRem = 0 end
        local gs = s.glow
        if gs and gs.enabled then
            MSWA_UpdateGlow_Fast(btn, gs, glowRem, glowRem > 0)
        elseif btn._msaGlowActive then
            MSWA_StopGlow(btn)
        end
        MSWA_ApplyConditionalTextColor_Fast(btn, s, db, glowRem, glowRem > 0)
        MSWA_ApplySwipeDarken_Fast(btn, s)
        flags.cooldown = true
        return index + 1

    elseif previewMode or key == selectedKey then
        btn:ClearAllPoints()
        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
        MSWA_ClearCooldownFrame(btn.cooldown)
        SetDesatCached(btn, false)
        SetAlphaCached(btn, ComputeAlpha(s, false, inCombat))
        MSWA_ShowReminderLabel(btn, s, db)
        MSWA_StopGlow(btn)
        return index + 1
    else
        HideButton(btn)
        return nil
    end
end


local function Handle_Charges(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                               groupCtx, now, inCombat, isItem, itemID, flags)
    MSWA._charges = MSWA._charges or {}
    local maxC = tonumber(s.chargeMax) or 3
    local ch = MSWA._charges[key]
    if not ch then
        ch = { remaining = maxC, rechargeStart = 0 }
        MSWA._charges[key] = ch
    end

    local forceShow = s.chargeForceShow
    local recharging = MSWA_ChargeRechargeTick(key, s, now)
    local rem = ch.remaining

    btn:ClearAllPoints()
    PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)

    if not forceShow and recharging and ch.rechargeStart > 0 then
        local dur = tonumber(s.chargeDuration) or 0
        MSWA_ApplyCooldownFrame(btn.cooldown, ch.rechargeStart, dur, 1)
        flags.cooldown = true
    else
        MSWA_ClearCooldownFrame(btn.cooldown)
    end

    if forceShow then
        SetDesatCached(btn, false)
        SetAlphaCached(btn, 1)
    else
        local desat = rem <= 0
        if isItem and IsItemZeroCount(s, itemID) then desat = true end
        SetDesatCached(btn, desat)
        SetAlphaCached(btn, ComputeAlpha(s, recharging, inCombat))
    end

    MSWA_ShowChargeCount(btn, rem, maxC, s, db)
    ClearStackAndCount(btn)

    local glowRem = 0
    if recharging and ch.rechargeStart > 0 then
        local dur = tonumber(s.chargeDuration) or 0
        glowRem = dur - (now - ch.rechargeStart)
        if glowRem < 0 then glowRem = 0 end
    end
    local gs = s.glow
    if gs and gs.enabled then
        MSWA_UpdateGlow_Fast(btn, gs, glowRem, recharging)
    elseif btn._msaGlowActive then
        MSWA_StopGlow(btn)
    end
    MSWA_ApplyConditionalTextColor_Fast(btn, s, db, glowRem, recharging)
    if not forceShow and recharging then
        MSWA_ApplySwipeDarken_Fast(btn, s)
        flags.autoBuff = true; flags.timerTick = true
    end
    return index + 1
end


-----------------------------------------------------------
-- v7.1: Handle_AuraTrack – Live aura tracking from server
--
-- Reads REAL buff data from C_UnitAuras API.
-- Survives /reload – no client-side timers.
-- Non-secret spells: zero pcall.  Secret: pcall fallback.
-- Shows icon with real remaining duration from server.
-- Optional: show grayed out when buff is missing.
-----------------------------------------------------------

local function Handle_AuraTrack(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                                 groupCtx, now, inCombat, previewMode, selectedKey,
                                 isItem, spellID, itemID, flags)
    -- Query real aura data from server
    local aura = spellID and MSWA_GetPlayerAuraDataBySpellID(spellID)

    if aura then
        btn:ClearAllPoints()
        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)

        -- Apply real cooldown from server aura data (survives /reload)
        if btn.cooldown and aura.duration and aura.expirationTime then
            MSWA_ApplyCooldownFrame(btn.cooldown, nil, aura.duration,
                                     aura.timeMod or 1, aura.expirationTime, spellID)
            flags.cooldown = true
        else
            MSWA_ClearCooldownFrame(btn.cooldown)
        end

        -- Real stacks from server (v8: use pre-fetched aura, zero double lookup)
        MSWA_UpdateBuffVisual_WithAura(btn, s, spellID, aura)

        SetDesatCached(btn, false)
        SetAlphaCached(btn, ComputeAlpha(s, false, inCombat))

        -- Glow / text color based on real remaining time
        local rem = MSWA_GetAuraRemaining(aura, spellID, now)
        local isActive = rem > 0
        local gs = s.glow
        if gs and gs.enabled then
            MSWA_UpdateGlow_Fast(btn, gs, rem, isActive)
            if isActive then flags.timerTick = true end
        elseif btn._msaGlowActive then
            MSWA_StopGlow(btn)
        end
        MSWA_ApplyConditionalTextColor_Fast(btn, s, db, rem, isActive)
        if isActive and s.textColor2Enabled then flags.timerTick = true end
        MSWA_ApplySwipeDarken_Fast(btn, s)
        MSWA_HideReminderLabel(btn)

        return index + 1
    else
        -- Buff not active on player
        local showMissing = s and s.auraTrackShowMissing
        if showMissing or previewMode or key == selectedKey then
            btn:ClearAllPoints()
            PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
            MSWA_ClearCooldownFrame(btn.cooldown)
            SetDesatCached(btn, true)
            SetAlphaCached(btn, ComputeAlpha(s, false, inCombat))
            ClearStackAndCount(btn)
            MSWA_StopGlow(btn)
            -- Show reminder text when buff missing
            if s and s.reminderText and s.reminderText ~= "" then
                MSWA_ShowReminderLabel(btn, s, db)
            else
                MSWA_HideReminderLabel(btn)
            end
            return index + 1
        else
            HideButton(btn)
            return nil
        end
    end
end


local function Handle_Normal(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                              groupCtx, now, inCombat, previewMode, selectedKey,
                              isItem, spellID, itemID, flags,
                              hasGetCD, hasGetCDRemaining)
    btn:ClearAllPoints()
    PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)

    if isItem then
        local onCD, iStart, iDuration = GetItemCDState(itemID)
        if onCD then
            MSWA_ApplyCooldownFrame(btn.cooldown, iStart, iDuration, 1)
        else
            MSWA_ClearCooldownFrame(btn.cooldown)
        end
    else
        local cdInfo = hasGetCD and C_Spell.GetSpellCooldown(spellID)
        if cdInfo then
            local exp = cdInfo.expirationTime
            if hasGetCDRemaining then
                local rem = C_Spell.GetSpellCooldownRemaining(spellID)
                if type(rem) == "number" then exp = now + rem end
            end
            MSWA_ApplyCooldownFrame(btn.cooldown, cdInfo.startTime, cdInfo.duration, cdInfo.modRate, exp, spellID)
        else
            MSWA_ClearCooldownFrame(btn.cooldown)
        end
    end

    MSWA_UpdateBuffVisual_Fast(btn, s, spellID, isItem, itemID)

    local onCD = MSWA_IsCooldownActive(btn)
    if onCD then flags.cooldown = true end

    local desat = false
    if s and s.grayOnCooldown and onCD then desat = true end
    if isItem and IsItemZeroCount(s, itemID) then desat = true end
    SetDesatCached(btn, desat)

    SetAlphaCached(btn, ComputeAlpha(s, onCD, inCombat))

    local rem = 0
    if onCD and s then
        local needTime = (s.glow and s.glow.enabled) or s.textColor2Enabled
        if needTime then
            flags.timerTick = true
            if isItem then
                rem = GetItemRemaining(itemID, now)
            else
                local r = MSWA_GetSpellGlowRemaining(spellID, now)
                if r > 0 then rem = r end
            end
        end
    end

    local gs = s and s.glow
    if gs and gs.enabled then
        MSWA_UpdateGlow_Fast(btn, gs, rem, onCD)
    elseif btn._msaGlowActive then
        MSWA_StopGlow(btn)
    end
    MSWA_ApplyConditionalTextColor_Fast(btn, s, db, rem, onCD)
    MSWA_ApplySwipeDarken_Fast(btn, s)

    return index + 1
end


-----------------------------------------------------------
-- v7: ProcessAura – unified entry point for one aura
-----------------------------------------------------------

local function ProcessAura(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                            groupCtx, now, inCombat, previewMode, selectedKey,
                            autoBuff, isItem, spellID, itemID, flags,
                            hasGetCD, hasGetCDRemaining)

    SetIconTexture(btn, key)
    ShowCached(btn)
    btn.spellID = key

    -- v8: Cache per-button metadata for zero-cost TickVisuals
    btn._msaS      = s
    btn._msaSID    = spellID
    btn._msaIID    = itemID
    btn._msaIsItem = isItem

    ApplyStylesIfDirty(btn, db, s, key)

    -- Clean stale overlays from mode switches (zero cost if nil)
    local mode = s and s.auraMode
    if mode ~= "REMINDER_BUFF" and mode ~= "AURA" and btn._msaReminderLabel then btn._msaReminderLabel:Hide() end
    if mode ~= "CHARGES" and btn._msaChargeLabel then btn._msaChargeLabel:Hide() end

    if mode == "AUTOBUFF" or mode == "BUFF_THEN_CD" then
        return Handle_AutoBuff(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                               groupCtx, now, inCombat, previewMode, selectedKey,
                               autoBuff, isItem, spellID, itemID, flags,
                               hasGetCD, hasGetCDRemaining)
    elseif mode == "REMINDER_BUFF" then
        return Handle_ReminderBuff(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                                    groupCtx, now, inCombat, previewMode, selectedKey,
                                    autoBuff, isItem, spellID, itemID, flags)
    elseif mode == "CHARGES" then
        return Handle_Charges(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                               groupCtx, now, inCombat, isItem, itemID, flags)
    elseif mode == "AURA" then
        return Handle_AuraTrack(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                                 groupCtx, now, inCombat, previewMode, selectedKey,
                                 isItem, spellID, itemID, flags)
    else
        return Handle_Normal(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                              groupCtx, now, inCombat, previewMode, selectedKey,
                              isItem, spellID, itemID, flags,
                              hasGetCD, hasGetCDRemaining)
    end
end


-----------------------------------------------------------
-- UpdateSpells (full redraw – event-driven ONLY)
-----------------------------------------------------------

local function MSWA_UpdateSpells()
    local db            = MSWA_GetDB()
    local tracked       = db.trackedSpells
    local trackedItems  = db.trackedItems or {}
    local settingsTable = db.spellSettings or {}
    local index         = 1
    local frame         = MSWA.frame
    local ICON_SIZE     = MSWA.ICON_SIZE
    local ICON_SPACE    = MSWA.ICON_SPACE
    local MAX_ICONS     = MSWA.MAX_ICONS
    local previewMode   = MSWA.previewMode
    local autoBuff      = MSWA._autoBuff
    local icons         = MSWA.icons
    local now           = GetTime()

    -- Group anchors
    local groupCtx = MSWA._groupLayoutCtx
    if not groupCtx then
        groupCtx = { applied = {}, frames = {}, bounds = {}, used = {} }
        MSWA._groupLayoutCtx = groupCtx
    end
    wipe(groupCtx.applied)
    wipe(groupCtx.bounds)
    wipe(groupCtx.used)

    local optFrame    = MSWA.optionsFrame
    local selectedKey = (optFrame and optFrame:IsShown() and MSWA.selectedSpellID) or nil

    local hasGetCD          = C_Spell and C_Spell.GetSpellCooldown
    local hasGetCDRemaining = C_Spell and C_Spell.GetSpellCooldownRemaining

    local inCombat    = InCombatLockdown and InCombatLockdown() and true or false
    local inEncounter = IsEncounterInProgress and IsEncounterInProgress() and true or false

    -- v7: shared flags table
    local flags = { cooldown = false, autoBuff = false, timerTick = false }

    -----------------------------------------------------------
    -- 1) Spells
    -----------------------------------------------------------
    if hasGetCD then
        for trackedKey, enabled in pairs(tracked) do
            if index > MAX_ICONS then break end
            if enabled then
                local spellID, itemFromSpells
                if type(trackedKey) == "number" then
                    spellID = trackedKey
                elseif MSWA_IsSpellInstanceKey(trackedKey) then
                    spellID = MSWA_KeyToSpellID(trackedKey)
                elseif MSWA_IsItemKey(trackedKey) then
                    itemFromSpells = MSWA_KeyToItemID(trackedKey)
                end

                if spellID then
                    local key = trackedKey
                    local s   = settingsTable[key] or settingsTable[tostring(key)]
                    if MSWA_ShouldLoadAura(s, inCombat, inEncounter) or previewMode or key == selectedKey then
                        local newIdx = ProcessAura(icons[index], s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                                                    groupCtx, now, inCombat, previewMode, selectedKey,
                                                    autoBuff, false, spellID, nil, flags,
                                                    hasGetCD, hasGetCDRemaining)
                        if newIdx then index = newIdx end
                    end

                elseif itemFromSpells then
                    local key = trackedKey
                    local s   = settingsTable[key] or settingsTable[tostring(key)]
                    if MSWA_ShouldLoadAura(s, inCombat, inEncounter) or previewMode or key == selectedKey then
                        local newIdx = ProcessAura(icons[index], s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                                                    groupCtx, now, inCombat, previewMode, selectedKey,
                                                    autoBuff, true, nil, itemFromSpells, flags,
                                                    hasGetCD, hasGetCDRemaining)
                        if newIdx then index = newIdx end
                    end

                elseif (previewMode or trackedKey == selectedKey) and MSWA_IsDraftKey(trackedKey) then
                    local btn = icons[index]
                    local s   = settingsTable[trackedKey] or settingsTable[tostring(trackedKey)]
                    SetIconTexture(btn, trackedKey)
                    ShowCached(btn)
                    btn.spellID = trackedKey
                    btn:ClearAllPoints()
                    PositionButton(btn, s, trackedKey, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                    MSWA_ClearCooldownFrame(btn.cooldown)
                    ApplyStylesIfDirty(btn, db, s, trackedKey)
                    SetDesatCached(btn, false)
                    SetAlphaCached(btn, 0.6)
                    ClearStackAndCount(btn)
                    MSWA_StopGlow(btn)
                    index = index + 1
                end
            end
        end
    end

    -----------------------------------------------------------
    -- 2) Items
    -----------------------------------------------------------
    for itemID, enabled in pairs(trackedItems) do
        if index > MAX_ICONS then break end
        if enabled then
            local key = GetItemKey(itemID)
            local s   = settingsTable[key] or settingsTable[tostring(key)]
            if MSWA_ShouldLoadAura(s, inCombat, inEncounter) or previewMode or key == selectedKey then
                local newIdx = ProcessAura(icons[index], s, key, index, frame, ICON_SIZE, ICON_SPACE, db,
                                            groupCtx, now, inCombat, previewMode, selectedKey,
                                            autoBuff, true, nil, itemID, flags,
                                            hasGetCD, hasGetCDRemaining)
                if newIdx then index = newIdx end
            end
        end
    end

    -----------------------------------------------------------
    -- 2.4) Charge label cleanup
    -----------------------------------------------------------
    for ci = 1, index - 1 do
        local btn = icons[ci]
        if btn and btn.spellID then
            local cs = settingsTable[btn.spellID] or settingsTable[tostring(btn.spellID)]
            if not (cs and cs.auraMode == "CHARGES") and btn._msaChargeLabel then
                btn._msaChargeLabel:Hide()
            end
        end
    end

    -----------------------------------------------------------
    -- 2.5) Finalize group anchor footprints
    -----------------------------------------------------------
    if next(groupCtx.used) ~= nil then
        for gid, b in pairs(groupCtx.bounds) do
            if b and b.init then
                local gf = groupCtx.frames[gid]
                if gf then
                    local w = b.maxR - b.minL
                    local h = b.maxT - b.minB
                    if w < 1 then w = 1 end
                    if h < 1 then h = 1 end
                    gf:SetSize(w, h)
                end
            end
        end
    end
    if type(MSWA_HideUnusedGroupAnchorFrames) == "function" then
        MSWA_HideUnusedGroupAnchorFrames(groupCtx.used)
    end

    -----------------------------------------------------------
    -- 3) Hide remaining buttons
    -----------------------------------------------------------
    local activeCount = index - 1
    for i = index, MAX_ICONS do
        local btn = icons[i]
        if btn.spellID ~= nil or btn:IsShown() then
            HideButton(btn)
            ClearStackAndCount(btn)
        end
    end

    -----------------------------------------------------------
    -- 4) Masque + events: ONLY when count changes
    -----------------------------------------------------------
    if activeCount ~= lastActiveCount then
        MSWA.activeIconCount = activeCount
        MSWA_ReskinMasque(activeCount)
        MSWA_UpdateEventRegistration()
        lastActiveCount = activeCount
    end

    -----------------------------------------------------------
    -- 5) Update engine flags
    -----------------------------------------------------------
    autoBuffActive = flags.autoBuff
    needsTimerTick = flags.timerTick
end

MSWA.UpdateSpells    = MSWA_UpdateSpells
_G.MSWA_UpdateSpells = MSWA_UpdateSpells


-----------------------------------------------------------
-- v8: TickVisuals – MAXIMUM PERFORMANCE timer tick
--
-- Uses per-button cached metadata from ProcessAura:
--   btn._msaS      → settings (no tostring fallback)
--   btn._msaSID    → numeric spellID (no string parsing)
--   btn._msaIID    → numeric itemID
--   btn._msaIsItem → bool
--
-- Inlines MSWA_IsCooldownActive (saves function call).
-- Caches haste once per frame (not per icon).
-- Eliminates select(1, ...) overhead.
--
-- Cost: ~2-3 calls per affected icon vs ~8+ in v7.
-----------------------------------------------------------

local function MSWA_TickVisuals()
    local db            = MSWA_GetDB()
    local icons         = MSWA.icons
    local activeCount   = MSWA.activeIconCount or 0
    local now           = GetTime()
    local autoBuff      = MSWA._autoBuff
    local charges       = MSWA._charges

    -- v8: cache haste ONCE per frame, not per icon
    local hasteCache
    local function GetHastedDuration(s)
        local dur = tonumber(s.autoBuffDuration) or 10
        if dur < 0.1 then dur = 0.1 end
        if s.hasteScaling and UnitSpellHaste then
            if not hasteCache then hasteCache = tonumber(UnitSpellHaste("player")) or 0 end
            if hasteCache > 0 then dur = dur / (1 + hasteCache / 100) end
        end
        return dur
    end

    local anyNeedTick = false

    for i = 1, activeCount do
        local btn = icons[i]
        if not btn then break end

        -- v8: read cached metadata (set during ProcessAura)
        local s = btn._msaS
        if not s then break end

        local gs = s.glow
        local hasGlow      = gs and gs.enabled
        local hasTextColor = s.textColor2Enabled

        if hasGlow or hasTextColor then
            local mode = s.auraMode
            local rem = 0
            local isOnCD = false

            if mode == "AUTOBUFF" or mode == "BUFF_THEN_CD" or mode == "REMINDER_BUFF" then
                local key = btn.spellID
                local ab = autoBuff[key]
                if ab and ab.active then
                    local buffDur = GetHastedDuration(s)
                    local buffDelay = tonumber(s.autoBuffDelay) or 0
                    local timerStart = ab.startTime + buffDelay
                    rem = buffDur - (now - timerStart)
                    if rem < 0 then rem = 0 end
                    isOnCD = rem > 0
                    anyNeedTick = true
                elseif mode == "BUFF_THEN_CD" then
                    if btn._msaIsItem then
                        local iid = btn._msaIID
                        if iid then rem = GetItemRemaining(iid, now) end
                    else
                        local sid = btn._msaSID
                        if sid then
                            rem, isOnCD = MSWA_GetSpellGlowRemaining(sid, now)
                            if not isOnCD then rem = 0 end
                        end
                    end
                    -- v8: inline MSWA_IsCooldownActive
                    if not isOnCD then
                        local cd = btn.cooldown
                        isOnCD = cd and cd.__mswaSet and cd:IsShown() and true or false
                    end
                    if isOnCD then anyNeedTick = true end
                end

            elseif mode == "CHARGES" then
                local key = btn.spellID
                local ch = charges and charges[key]
                if ch and ch.rechargeStart > 0 then
                    local dur = tonumber(s.chargeDuration) or 0
                    rem = dur - (now - ch.rechargeStart)
                    if rem < 0 then rem = 0 end
                    isOnCD = rem > 0
                    anyNeedTick = true
                end

            elseif mode == "AURA" then
                local sid = btn._msaSID
                if sid then
                    local aura = MSWA_GetPlayerAuraDataBySpellID(sid)
                    if aura then
                        rem = MSWA_GetAuraRemaining(aura, sid, now)
                        isOnCD = rem > 0
                        if isOnCD then anyNeedTick = true end
                    end
                end

            else
                -- NORMAL mode
                if btn._msaIsItem then
                    local iid = btn._msaIID
                    if iid then rem = GetItemRemaining(iid, now) end
                else
                    local sid = btn._msaSID
                    if sid then
                        rem, isOnCD = MSWA_GetSpellGlowRemaining(sid, now)
                        if not isOnCD then rem = 0 end
                    end
                end
                -- v8: inline MSWA_IsCooldownActive
                if not isOnCD then
                    local cd = btn.cooldown
                    isOnCD = cd and cd.__mswaSet and cd:IsShown() and true or false
                end
                if isOnCD then anyNeedTick = true end
            end

            if hasGlow then
                MSWA_UpdateGlow_Fast(btn, gs, rem, isOnCD)
            end
            if hasTextColor then
                MSWA_ApplyConditionalTextColor_Fast(btn, s, db, rem, isOnCD)
            end
        end
    end

    needsTimerTick = anyNeedTick
end


-----------------------------------------------------------
-- AutoBuffTick
-----------------------------------------------------------

local function AutoBuffTick(settingsTable, now)
    local anyLeft = false
    local anyExpired = false
    for key, ab in pairs(MSWA._autoBuff) do
        if ab and ab.active then
            local s2 = settingsTable[key] or settingsTable[tostring(key)]
            local dur = GetEffectiveBuffDuration(s2)
            local delay = tonumber(s2 and s2.autoBuffDelay) or 0
            if (now - ab.startTime) < (delay + dur) then
                anyLeft = true
            else
                ab.active = false
                anyExpired = true
            end
        end
    end
    autoBuffActive = anyLeft
    if anyExpired then dirty = true end
end


-----------------------------------------------------------
-- OnUpdate: v7 two-path engine
--
-- Path A (dirty | autoBuffActive): full UpdateSpells
-- Path B (needsTimerTick only):    lightweight TickVisuals
-- Nothing active:                   engine hides → zero CPU
-----------------------------------------------------------

engineFrame:SetScript("OnUpdate", function(self)
    local now = GetTime()

    -- Path A: structural change or autobuff timer
    if dirty or autoBuffActive then
        if forceImmediate or (now - lastFullUpdate) >= THROTTLE_INTERVAL then
            if autoBuffActive then
                AutoBuffTick(MSWA_GetDB().spellSettings or {}, now)
            end
            dirty = false
            forceImmediate = false
            lastFullUpdate = now
            MSWA_UpdateSpells()
        end
        return
    end

    -- Path B: lightweight timer tick (glow/textcolor only)
    if needsTimerTick then
        if (now - lastFullUpdate) >= THROTTLE_INTERVAL then
            lastFullUpdate = now
            MSWA_TickVisuals()
        end
        if not needsTimerTick then
            self:Hide()
        end
        return
    end

    -- Nothing active → zero CPU
    self:Hide()
end)


-----------------------------------------------------------
-- Request / Force
-----------------------------------------------------------

function MSWA_RequestUpdateSpells()
    dirty = true
    engineFrame:Show()
end

function MSWA_ForceUpdateSpells()
    dirty = true
    forceImmediate = true
    engineFrame:Show()
end

function MSWA_InvalidateIconCache()
    WipeIconCache()
    if MSWA.icons then
        for i = 1, MSWA.MAX_ICONS do
            local btn = MSWA.icons[i]
            if btn then
                btn._msaCachedKey = nil
                btn._msaStyleKey  = nil
                btn._msaVS        = nil
                btn._msaS         = nil
                btn._msaSID       = nil
                btn._msaIID       = nil
                btn._msaIsItem    = nil
            end
        end
    end
    lastActiveCount = -1
    MSWA_ForceUpdateSpells()
end


-----------------------------------------------------------
-- Event registration (ONLY called when count changes)
-----------------------------------------------------------

MSWA_UpdateEventRegistration = function()
    local mainFrame = MSWA.frame
    if not mainFrame or not mainFrame.RegisterEvent then return end

    if MSWA.activeIconCount and MSWA.activeIconCount > 0 then
        mainFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        mainFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
        mainFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        mainFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
        mainFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
        mainFrame:RegisterEvent("BAG_UPDATE")
        if mainFrame.RegisterUnitEvent then
            mainFrame:RegisterUnitEvent("UNIT_AURA", "player")
        else
            mainFrame:RegisterEvent("UNIT_AURA")
        end
    else
        mainFrame:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
        mainFrame:UnregisterEvent("PLAYER_TALENT_UPDATE")
        mainFrame:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
        mainFrame:UnregisterEvent("UNIT_INVENTORY_CHANGED")
        mainFrame:UnregisterEvent("BAG_UPDATE_COOLDOWN")
        mainFrame:UnregisterEvent("BAG_UPDATE")
        mainFrame:UnregisterEvent("UNIT_AURA")
    end
end


-----------------------------------------------------------
-- Main event handler
-----------------------------------------------------------

local mainFrame = MSWA.frame

mainFrame:RegisterEvent("PLAYER_LOGIN")
mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

mainFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        MSWA_UpdatePositionFromDB()
        MSWA_RefreshPlayerIdentity()
        WipeIconCache()
        lastActiveCount = -1
        MSWA_ForceUpdateSpells()
        MSWA_ApplyUIFont()
    elseif event == "UNIT_AURA" then
        if arg1 ~= "player" then return end
        MSWA_RequestUpdateSpells()
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 ~= "player" then return end
        MSWA_RequestUpdateSpells()
    else
        MSWA_RequestUpdateSpells()
    end
end)


-----------------------------------------------------------
-- Load filter refresh
-----------------------------------------------------------
do
    local loadFilterFrame = CreateFrame("Frame")
    loadFilterFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    loadFilterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    loadFilterFrame:RegisterEvent("ENCOUNTER_START")
    loadFilterFrame:RegisterEvent("ENCOUNTER_END")
    loadFilterFrame:SetScript("OnEvent", function()
        MSWA_InvalidateIconCache()
        if MSWA_RefreshOptionsList and MSWA.optionsFrame and MSWA.optionsFrame:IsShown() then
            MSWA_RefreshOptionsList()
        end
    end)
end


-----------------------------------------------------------
-- Auto Buff (Spells): cast detection
-----------------------------------------------------------
do
    local abFrame = CreateFrame("Frame")
    if abFrame.RegisterUnitEvent then
        abFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    else
        abFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    end

    abFrame:SetScript("OnEvent", function(self, event, unit, castGUID, castSpellID)
        if unit and unit ~= "player" then return end
        if not castSpellID then return end

        local db = MSWA_GetDB()
        if not db.trackedSpells or not db.spellSettings then return end

        local triggered = false
        local chargeDirty = false
        for trackedKey, enabled in pairs(db.trackedSpells) do
            if enabled then
                local sid
                if type(trackedKey) == "number" then
                    sid = trackedKey
                elseif MSWA_IsSpellInstanceKey(trackedKey) then
                    sid = MSWA_KeyToSpellID(trackedKey)
                end
                if sid == castSpellID then
                    local s = db.spellSettings[trackedKey] or db.spellSettings[tostring(trackedKey)]
                    if s and (s.auraMode == "AUTOBUFF" or s.auraMode == "BUFF_THEN_CD" or s.auraMode == "REMINDER_BUFF") then
                        MSWA._autoBuff[trackedKey] = { active = true, startTime = GetTime() }
                        triggered = true
                    elseif s and s.auraMode == "CHARGES" then
                        if MSWA_ConsumeCharge(trackedKey, s) then
                            chargeDirty = true
                        end
                    end
                end
            end
        end

        if triggered then autoBuffActive = true end
        if triggered or chargeDirty then MSWA_ForceUpdateSpells() end
    end)
end


-----------------------------------------------------------
-- Auto Buff (Items): cooldown-start detection
-----------------------------------------------------------
do
    local itemCDFrame = CreateFrame("Frame")
    itemCDFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    itemCDFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")

    local lastItemCDStart = {}

    local function CheckItemCD(key, itemID, db, now)
        local s = db.spellSettings[key] or db.spellSettings[tostring(key)]
        if not s then return nil end

        local isBuffMode = (s.auraMode == "AUTOBUFF" or s.auraMode == "BUFF_THEN_CD" or s.auraMode == "REMINDER_BUFF")
        local isCharges  = (s.auraMode == "CHARGES")
        if not isBuffMode and not isCharges then return nil end

        local start, duration = GetItemCooldown(itemID)
        local prevStart = lastItemCDStart[key] or 0

        local isActiveCD = start and start > 0 and duration and duration > 1.5
        local isFreshCD = isActiveCD and (start ~= prevStart)

        if isFreshCD then
            if isBuffMode then
                local ab = MSWA._autoBuff[key]
                if not ab or not ab.active then
                    MSWA._autoBuff[key] = { active = true, startTime = now }
                    lastItemCDStart[key] = start
                    return "buff"
                end
            end
            if isCharges then
                if MSWA_ConsumeCharge(key, s) then
                    lastItemCDStart[key] = start
                    return "charge"
                end
            end
        end

        lastItemCDStart[key] = isActiveCD and start or 0
        return nil
    end

    itemCDFrame:SetScript("OnEvent", function()
        if not GetItemCooldown then return end
        local db = MSWA_GetDB()
        if not db.spellSettings then return end

        local buffTriggered = false
        local anyTriggered = false
        local now = GetTime()

        if db.trackedItems then
            for itemID, enabled in pairs(db.trackedItems) do
                if enabled then
                    local key = GetItemKey(itemID)
                    local result = CheckItemCD(key, itemID, db, now)
                    if result then
                        anyTriggered = true
                        if result == "buff" then buffTriggered = true end
                    end
                end
            end
        end

        if db.trackedSpells then
            for trackedKey, enabled in pairs(db.trackedSpells) do
                if enabled and MSWA_IsItemKey(trackedKey) then
                    local itemID = MSWA_KeyToItemID(trackedKey)
                    if itemID then
                        local result = CheckItemCD(trackedKey, itemID, db, now)
                        if result then
                            anyTriggered = true
                            if result == "buff" then buffTriggered = true end
                        end
                    end
                end
            end
        end

        if buffTriggered then autoBuffActive = true end
        if anyTriggered then MSWA_ForceUpdateSpells() end
    end)
end


-----------------------------------------------------------
-- Reminder Buff: death detection
-----------------------------------------------------------
do
    local deathFrame = CreateFrame("Frame")
    deathFrame:RegisterEvent("PLAYER_DEAD")

    deathFrame:SetScript("OnEvent", function()
        local db = MSWA_GetDB()
        if not db.spellSettings then return end

        local cleared = false
        for key, ab in pairs(MSWA._autoBuff) do
            if ab and ab.active then
                local s = db.spellSettings[key] or db.spellSettings[tostring(key)]
                if s and s.auraMode == "REMINDER_BUFF" and not s.reminderPersistDeath then
                    ab.active = false
                    cleared = true
                end
            end
        end

        if cleared then MSWA_ForceUpdateSpells() end
    end)
end
