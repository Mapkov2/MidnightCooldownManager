-- ########################################################
-- MSA_UpdateEngine.lua  (v6 - zero idle CPU)
--
-- Perf fixes vs v5:
--   * Removed blanket anyCooldownActive -> dirty loop
--     (was running engine at 10 Hz for ALL CDs even without
--      time-dependent visuals like glow/textcolor conditions)
--   * New needsTimerTick flag: engine only ticks when auras
--     with active CDs also have glow or textColor2 enabled
--   * Normal CDs = zero engine cost after initial render
--     (Blizzard's CooldownFrame handles swipe natively)
--   * AutoBuff/Charges already covered by autoBuffActive
--
-- Prior v5 fixes preserved:
--   * pcall closures eliminated - use pcall(f, a, b) directly
--   * GetTime() cached once per OnUpdate frame
--   * AutoBuffTick throttled to 10 Hz (was 60 Hz)
--   * Text/Stack style dirty-flagged via _msaStyleKey
--   * Glow remaining calc shares cached now-time
--   * db fetched once, passed through everywhere
-- ########################################################

local pairs, type, pcall, tonumber, tostring = pairs, type, pcall, tonumber, tostring
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
-- Reminder threshold helper for BUFF_AURA
-- Returns true if aura should be HIDDEN (above threshold).
-- Safe: secret values -> never hide, absent -> never hide.
-----------------------------------------------------------

local _issv_engine = _G.issecretvalue

local function ShouldHideByThreshold(s, auraData, now)
    if not s or not s.reminderThresholdMin then return false end
    local thresh = tonumber(s.reminderThresholdMin)
    if not thresh or thresh <= 0 then return false end

    -- No aura data = absent -> never hide (show as reminder)
    if not auraData then return false end

    local exp = auraData.expirationTime
    local dur = auraData.duration

    -- Secret values -> can't check, always show
    if _issv_engine then
        if (exp and _issv_engine(exp)) or (dur and _issv_engine(dur)) then
            return false
        end
    end

    -- Permanent buff (duration=0) -> always show (no timer = always remind)
    if not dur or dur == 0 then return false end
    if not exp or exp == 0 then return false end

    local remaining = exp - now
    if remaining <= 0 then return false end  -- expired -> show

    -- Hide if remaining time is ABOVE threshold (buff still healthy)
    return remaining > (thresh * 60)
end

-----------------------------------------------------------
-- Engine frame (hidden = zero CPU)
-----------------------------------------------------------

local engineFrame = CreateFrame("Frame", "MSWA_EngineFrame", UIParent)
engineFrame:Hide()

local dirty              = false
local autoBuffActive     = false
local needsTimerTick     = false   -- true ONLY when time-dependent visuals need per-tick updates
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

-----------------------------------------------------------
-- Zero-count: keep item visible but grayed when count == 0
-- Returns true if zero-count gray was applied (additive)
-----------------------------------------------------------

local function IsItemZeroCount(s, itemID)
    if not s or not s.showOnZeroCount or not itemID then return false end
    if not GetItemCount then return false end
    local cnt = GetItemCount(itemID, false, false)
    return type(cnt) == "number" and cnt <= 0
end

local function HideButton(btn)
    btn:Hide()
    btn.icon:SetTexture(nil)
    btn._msaCachedKey = nil
    btn._msaStyleKey  = nil
    MSWA_ClearCooldownFrame(btn.cooldown)
    MSWA_StopGlow(btn)
    MSWA_HideReminderLabel(btn)
    MSWA_HideChargeLabel(btn)
    if MSWA_CleanupBar then MSWA_CleanupBar(btn) end
    if btn._msaDecimalTimer then btn._msaDecimalTimer:Hide() end
    btn.spellID = nil
end

-----------------------------------------------------------
-- SetIconTexture with cache (skip GetSpellInfo if same key)
-----------------------------------------------------------

local function SetIconTexture(btn, key)
    if btn._msaCachedKey == key then return end
    btn._msaCachedKey = key
    btn.icon:SetTexture(MSWA_GetIconForKey(key))
end

-----------------------------------------------------------
-- Text/Stack style with dirty-flag (skip when key matches)
-- v5: Avoids redundant SetFont/SetTextColor/ClearAllPoints
-- per icon per frame when settings haven't changed.
-----------------------------------------------------------

local function ApplyStylesIfDirty(btn, db, s, key)
    if btn._msaStyleKey == key then return end
    btn._msaStyleKey = key
    MSWA_ApplyTextStyle(btn, db, s)
    MSWA_ApplyStackStyle_Fast(btn, s, db)
end

-----------------------------------------------------------
-- Alpha computation: cdAlpha, oocAlpha, combatAlpha
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
-- pcall helpers for secret-value comparison (no closure!)
-- v5: Named functions instead of pcall(function() ... end)
-----------------------------------------------------------

local function _itemCDCheck(start, duration)
    if start and start > 0 and duration and duration > 1.5 then
        return true
    end
    return false
end

local function _itemCDRemaining(start, duration, now)
    if start and start > 0 and duration and duration > 1.5 then
        local r = (start + duration) - now
        return r > 0 and r or 0
    end
    return 0
end

-----------------------------------------------------------
-- UpdateSpells (the main hot loop)
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

    -- v5: cache GetTime once for entire update
    local now = GetTime()

    -- Group anchors - reuse tables to avoid churn
    local groupCtx = MSWA._groupLayoutCtx
    if not groupCtx then
        groupCtx = { applied = {}, frames = {}, bounds = {}, used = {} }
        MSWA._groupLayoutCtx = groupCtx
    end
    wipe(groupCtx.applied)
    wipe(groupCtx.bounds)
    wipe(groupCtx.used)

    local optFrame      = MSWA.optionsFrame
    local selectedKey   = (optFrame and optFrame:IsShown() and MSWA.selectedSpellID) or nil

    -- Cache API availability once
    local hasGetCD          = C_Spell and C_Spell.GetSpellCooldown
    local hasGetCDRemaining = C_Spell and C_Spell.GetSpellCooldownRemaining

    -- Cache combat/encounter state ONCE
    local inCombat    = InCombatLockdown and InCombatLockdown() and true or false
    local inEncounter = IsEncounterInProgress and IsEncounterInProgress() and true or false

    -- v6: track inline (eliminates post-loop iterations)
    -- foundNeedsTimerTick = true when ANY visible aura needs per-tick updates
    -- (autobuff/charges ticking, glow conditions, conditional text color)
    local foundCooldownActive  = false
    local foundAutoBuffActive  = false
    local foundNeedsTimerTick  = false

    -----------------------------------------------------------
    -- 1) Spells
    -----------------------------------------------------------
    if hasGetCD then
        for trackedKey, enabled in pairs(tracked) do
            if index > MAX_ICONS then break end
            if enabled then
                local spellID
                local itemFromSpells   -- item instance keys (item:ID:N) stored in trackedSpells
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
                    local shouldLoad = MSWA_ShouldLoadAura(s, inCombat, inEncounter)

                    if shouldLoad or previewMode or key == selectedKey then
                        local btn = icons[index]

                        SetIconTexture(btn, key)
                        btn:Show()
                        btn.spellID = key
                        btn:ClearAllPoints()

                        ApplyStylesIfDirty(btn, db, s, key)

                        -- Clean stale overlays from mode switches (zero cost if nil)
                        if (not s or s.auraMode ~= "REMINDER_BUFF") and btn._msaReminderLabel then btn._msaReminderLabel:Hide() end
                        if (not s or s.auraMode ~= "CHARGES") and btn._msaChargeLabel then btn._msaChargeLabel:Hide() end

                        if s and (s.auraMode == "AUTOBUFF" or s.auraMode == "BUFF_THEN_CD") then
                            -- ========== SPELL AUTO BUFF / BUFF_THEN_CD MODE ==========
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
                                    foundAutoBuffActive = true; foundNeedsTimerTick = true
                                else
                                    ab.active = false
                                end
                            end

                            if inBuffPhase then
                                -- === BUFF PHASE (identical for AUTOBUFF & BUFF_THEN_CD) ===
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                                MSWA_ApplyCooldownFrame(btn.cooldown, timerStart, buffDur, 1)
                                btn.icon:SetDesaturated(false)
                                btn:SetAlpha(ComputeAlpha(s, true, inCombat))
                                MSWA_UpdateBuffVisual_Fast(btn, s, spellID, false, nil)

                                local glowRem = buffDur - (now - timerStart)
                                if glowRem < 0 then glowRem = 0 end
                                local gs = s and s.glow
                                if gs and gs.enabled then
                                    MSWA_UpdateGlow_Fast(btn, gs, glowRem, glowRem > 0)
                                elseif btn._msaGlowActive then
                                    MSWA_StopGlow(btn)
                                end
                                MSWA_ApplyConditionalTextColor_Fast(btn, s, db, glowRem, glowRem > 0)
                                MSWA_ApplySwipeDarken_Fast(btn, s)
                                foundCooldownActive = true
                                index = index + 1

                            elseif isBuffThenCD then
                                -- === BUFF_THEN_CD: buff expired -> show remaining spell CD ===
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)

                                local cdInfo = C_Spell.GetSpellCooldown(spellID)
                                if cdInfo then
                                    local exp = cdInfo.expirationTime
                                    if hasGetCDRemaining then
                                        local rem = C_Spell.GetSpellCooldownRemaining(spellID)
                                        if type(rem) == "number" then
                                            exp = now + rem
                                        end
                                    end
                                    MSWA_ApplyCooldownFrame(btn.cooldown, cdInfo.startTime, cdInfo.duration, cdInfo.modRate, exp)
                                else
                                    MSWA_ClearCooldownFrame(btn.cooldown)
                                end

                                MSWA_UpdateBuffVisual_Fast(btn, s, spellID, false, nil)

                                local onCD = MSWA_IsCooldownActive(btn)
                                if onCD then foundCooldownActive = true end

                                if onCD then
                                    if s.grayOnCooldown then
                                        btn.icon:SetDesaturated(true)
                                    else
                                        btn.icon:SetDesaturated(false)
                                    end
                                    btn:SetAlpha(ComputeAlpha(s, true, inCombat))

                                    local rem = 0
                                    local gs2 = s.glow
                                    if (gs2 and gs2.enabled) or s.textColor2Enabled then
                                        foundNeedsTimerTick = true
                                        local r = select(1, MSWA_GetSpellGlowRemaining(spellID))
                                        if type(r) == "number" and r > 0 then
                                            rem = r
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
                                    index = index + 1
                                elseif previewMode or key == selectedKey then
                                    btn.icon:SetDesaturated(false)
                                    btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                    MSWA_UpdateBuffVisual_Fast(btn, s, spellID, false, nil)
                                    MSWA_StopGlow(btn)
                                    index = index + 1
                                else
                                    -- BUFF_THEN_CD: CD ready -> keep visible idle
                                    MSWA_ClearCooldownFrame(btn.cooldown)
                                    btn.icon:SetDesaturated(false)
                                    btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                    MSWA_UpdateBuffVisual_Fast(btn, s, spellID, false, nil)
                                    MSWA_StopGlow(btn)
                                    index = index + 1
                                end

                            elseif previewMode or key == selectedKey then
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                                MSWA_ClearCooldownFrame(btn.cooldown)
                                btn.icon:SetDesaturated(false)
                                btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                MSWA_UpdateBuffVisual_Fast(btn, s, spellID, false, nil)
                                MSWA_StopGlow(btn)
                                index = index + 1
                            else
                                HideButton(btn)
                            end

                        elseif s and s.auraMode == "REMINDER_BUFF" then
                            -- ========== REMINDER BUFF MODE ==========
                            -- Inverted AUTOBUFF: show alert when buff MISSING,
                            -- optionally show timer when buff active.
                            -- 100% secret-safe: reuses AUTOBUFF cast-detection
                            -- (UNIT_SPELLCAST_SUCCEEDED) + user-supplied duration.
                            -- Zero API comparisons.
                            local ab = autoBuff[key]
                            local buffDur = GetEffectiveBuffDuration(s)
                            local buffDelay = tonumber(s.autoBuffDelay) or 0

                            local inBuffPhase = false
                            if ab and ab.active then
                                local totalWindow = buffDelay + buffDur
                                if (now - ab.startTime) < totalWindow then
                                    inBuffPhase = true
                                    foundAutoBuffActive = true; foundNeedsTimerTick = true
                                else
                                    ab.active = false
                                end
                            end

                            if not inBuffPhase then
                                -- BUFF MISSING -> show reminder
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                                MSWA_ClearCooldownFrame(btn.cooldown)
                                btn.icon:SetDesaturated(false)
                                btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                ClearStackAndCount(btn)
                                MSWA_ShowReminderLabel(btn, s, db)

                                local gs = s.glow
                                if gs and gs.enabled then
                                    MSWA_UpdateGlow_Fast(btn, gs, 9999, true)
                                elseif btn._msaGlowActive then
                                    MSWA_StopGlow(btn)
                                end
                                MSWA_ApplyConditionalTextColor_Fast(btn, s, db, 0, false)
                                index = index + 1

                            elseif s.reminderShowTimer then
                                -- BUFF ACTIVE + show countdown timer
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                                local timerStart = ab.startTime + buffDelay
                                MSWA_ApplyCooldownFrame(btn.cooldown, timerStart, buffDur, 1)
                                btn.icon:SetDesaturated(false)
                                btn:SetAlpha(ComputeAlpha(s, true, inCombat))
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
                                foundCooldownActive = true
                                index = index + 1

                            elseif previewMode or key == selectedKey then
                                -- Preview: show idle
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                                MSWA_ClearCooldownFrame(btn.cooldown)
                                btn.icon:SetDesaturated(false)
                                btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                MSWA_ShowReminderLabel(btn, s, db)
                                MSWA_StopGlow(btn)
                                index = index + 1
                            else
                                -- BUFF ACTIVE + hide reminder
                                HideButton(btn)
                            end

                        elseif s and s.auraMode == "CHARGES" then
                            -- ========== SPELL CHARGES MODE ==========
                            -- User-defined charges: cast consumes, timer recharges.
                            -- 100% secret-safe - zero API reads for charge state.
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

                            PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)

                            -- Cooldown swipe: show recharge timer (skip in forceShow)
                            if not forceShow and recharging and ch.rechargeStart > 0 then
                                local dur = tonumber(s.chargeDuration) or 0
                                MSWA_ApplyCooldownFrame(btn.cooldown, ch.rechargeStart, dur, 1)
                                foundCooldownActive = true
                            else
                                MSWA_ClearCooldownFrame(btn.cooldown)
                            end

                            -- forceShow: always normal icon, full alpha
                            if forceShow then
                                btn.icon:SetDesaturated(false)
                                btn:SetAlpha(1)
                            else
                                btn.icon:SetDesaturated(rem <= 0)
                                btn:SetAlpha(ComputeAlpha(s, recharging, inCombat))
                            end

                            -- Charge counter label
                            MSWA_ShowChargeCount(btn, rem, maxC, s, db)
                            ClearStackAndCount(btn)

                            -- Glow
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
                                foundAutoBuffActive = true; foundNeedsTimerTick = true
                            end
                            index = index + 1

                        elseif s and s.auraMode == "BUFF_AURA" then
                            -- ========== BUFF AURA MODE (direct poll, like WeakAuras/EQoL) ==========
                            -- Uses GetPlayerAuraBySpellID -> nil = absent, table = active
                            -- issecretvalue pattern from EQoL for field access
                            local buffSID = s.auraSpellID or spellID
                            local auraData = MSWA_GetPlayerAuraDataBySpellID(buffSID)
                            local buffActive = (auraData ~= nil)
                            local showWhenAbsent = s.showWhenAbsent
                            local showMe = buffActive or showWhenAbsent or previewMode or key == selectedKey

                            -- Reminder threshold: hide if buff is healthy (remaining > threshold)
                            if showMe and buffActive and ShouldHideByThreshold(s, auraData, now) then
                                showMe = false
                            end

                            if showMe then
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)

                                if buffActive then
                                    -- Cooldown sweep (EQoL pattern):
                                    -- Secret fields -> SetCooldownFromExpirationTime (designed for secrets)
                                    -- Non-secret fields -> read normally, use SetCooldown for precision
                                    -- Duration 0 (permanent buffs like poisons) -> no sweep needed
                                    local cd = btn.cooldown
                                    if cd then
                                        local dur = auraData.duration
                                        local exp = auraData.expirationTime
                                        local isSecret = MSWA_IsSecretValue and (MSWA_IsSecretValue(dur) or MSWA_IsSecretValue(exp))
                                        if isSecret then
                                            -- Secret: pass directly to Blizzard API
                                            if cd.SetCooldownFromExpirationTime then
                                                cd:SetCooldownFromExpirationTime(exp, dur, auraData.timeMod)
                                                cd.__mswaSet = true
                                            end
                                        elseif dur and dur > 0 and exp then
                                            -- Non-secret with duration: normal cooldown
                                            MSWA_ApplyCooldownFrame(cd, exp - dur, dur, auraData.timeMod or 1, exp)
                                        else
                                            -- Permanent buff (duration=0): no sweep
                                            MSWA_ClearCooldownFrame(cd)
                                        end
                                    end
                                    -- Stacks (v6: use styled target, respect hideStacksOnCooldown)
                                    if s.showStacks ~= false and not (s.hideStacksOnCooldown and MSWA_IsCooldownActive(btn)) then
                                        local sText = MSWA_GetAuraStackText(auraData, 2)
                                        local sTarget = btn.stackText or btn.count
                                        if sText and sTarget then
                                            sTarget:SetText(sText); sTarget:Show()
                                        else
                                            ClearStackAndCount(btn)
                                        end
                                    else
                                        ClearStackAndCount(btn)
                                    end
                                    btn.icon:SetDesaturated(false)
                                    btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                else
                                    -- Absent state
                                    MSWA_ClearCooldownFrame(btn.cooldown)
                                    ClearStackAndCount(btn)
                                    btn.icon:SetDesaturated(s.desaturateOnAbsent ~= false)
                                    btn:SetAlpha(tonumber(s.alphaOnAbsent) or 0.45)
                                end

                                -- Glow: active/absent
                                local glowVal = buffActive and 9999 or 0
                                local gs = s.glow
                                if gs and gs.enabled then
                                    MSWA_UpdateGlow_Fast(btn, gs, glowVal, buffActive)
                                elseif btn._msaGlowActive then
                                    MSWA_StopGlow(btn)
                                end
                                MSWA_ApplyConditionalTextColor_Fast(btn, s, db, glowVal, buffActive)
                                if btn._msaReminderLabel then btn._msaReminderLabel:Hide() end
                                if btn._msaChargeLabel then btn._msaChargeLabel:Hide() end
                                index = index + 1
                            else
                                HideButton(btn)
                            end

                        else
                            -- ========== NORMAL SPELL MODE ==========
                            PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)

                            local cdInfo = C_Spell.GetSpellCooldown(spellID)
                            if cdInfo then
                                local exp = cdInfo.expirationTime
                                if hasGetCDRemaining then
                                    local rem = C_Spell.GetSpellCooldownRemaining(spellID)
                                    if type(rem) == "number" then
                                        exp = now + rem
                                    end
                                end
                                MSWA_ApplyCooldownFrame(btn.cooldown, cdInfo.startTime, cdInfo.duration, cdInfo.modRate, exp)
                            else
                                MSWA_ClearCooldownFrame(btn.cooldown)
                            end

                            MSWA_UpdateBuffVisual_Fast(btn, s, spellID, false, nil)

                            local onCD = MSWA_IsCooldownActive(btn)
                            if onCD then foundCooldownActive = true end

                            if s and s.grayOnCooldown then
                                btn.icon:SetDesaturated(onCD)
                            else
                                btn.icon:SetDesaturated(false)
                            end

                            local rem = 0
                            if onCD and s then
                                local gs2 = s.glow
                                if (gs2 and gs2.enabled) or s.textColor2Enabled then
                                        foundNeedsTimerTick = true
                                    local r = select(1, MSWA_GetSpellGlowRemaining(spellID))
                                    if type(r) == "number" and r > 0 then
                                        rem = r
                                    end
                                end
                            end

                            btn:SetAlpha(ComputeAlpha(s, onCD, inCombat))

                            local gs = s and s.glow
                            if gs and gs.enabled then
                                MSWA_UpdateGlow_Fast(btn, gs, rem, onCD)
                            elseif btn._msaGlowActive then
                                MSWA_StopGlow(btn)
                            end
                            MSWA_ApplyConditionalTextColor_Fast(btn, s, db, rem, onCD)
                            MSWA_ApplySwipeDarken_Fast(btn, s)

                            index = index + 1
                        end
                    end

                elseif itemFromSpells then
                    -- ========== ITEM INSTANCE (item:ID:N in trackedSpells) ==========
                    local itemID = itemFromSpells
                    local key = trackedKey
                    local s   = settingsTable[key] or settingsTable[tostring(key)]
                    local shouldLoad = MSWA_ShouldLoadAura(s, inCombat, inEncounter)

                    if shouldLoad or previewMode or key == selectedKey then
                        local btn = icons[index]
                        SetIconTexture(btn, key)
                        btn:Show()
                        btn.spellID = key
                        btn:ClearAllPoints()

                        ApplyStylesIfDirty(btn, db, s, key)

                        -- Clean stale overlays from mode switches (zero cost if nil)
                        if (not s or s.auraMode ~= "REMINDER_BUFF") and btn._msaReminderLabel then btn._msaReminderLabel:Hide() end
                        if (not s or s.auraMode ~= "CHARGES") and btn._msaChargeLabel then btn._msaChargeLabel:Hide() end

                        if s and s.auraMode == "BUFF_AURA" then
                            -- ========== ITEM INSTANCE: BUFF AURA (direct poll) ==========
                            local buffSID = s.auraSpellID or itemID
                            local auraData = MSWA_GetPlayerAuraDataBySpellID(buffSID)
                            local buffActive = (auraData ~= nil)
                            local showMe = buffActive or s.showWhenAbsent or previewMode or key == selectedKey

                            -- Reminder threshold: hide if buff is healthy (remaining > threshold)
                            if showMe and buffActive and ShouldHideByThreshold(s, auraData, now) then
                                showMe = false
                            end
                            if showMe then
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                                if buffActive then
                                    local cd = btn.cooldown
                                    if cd then
                                        local dur = auraData.duration
                                        local exp = auraData.expirationTime
                                        local isSecret = MSWA_IsSecretValue and (MSWA_IsSecretValue(dur) or MSWA_IsSecretValue(exp))
                                        if isSecret and cd.SetCooldownFromExpirationTime then
                                            cd:SetCooldownFromExpirationTime(exp, dur, auraData.timeMod); cd.__mswaSet = true
                                        elseif dur and dur > 0 and exp then
                                            MSWA_ApplyCooldownFrame(cd, exp - dur, dur, auraData.timeMod or 1, exp)
                                        else MSWA_ClearCooldownFrame(cd) end
                                    end
                                    if s.showStacks ~= false and not (s.hideStacksOnCooldown and MSWA_IsCooldownActive(btn)) then
                                        local sText = MSWA_GetAuraStackText(auraData, 2)
                                        local sTarget = btn.stackText or btn.count
                                        if sText and sTarget then sTarget:SetText(sText); sTarget:Show() else ClearStackAndCount(btn) end
                                    else ClearStackAndCount(btn) end
                                    btn.icon:SetDesaturated(false); btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                else
                                    MSWA_ClearCooldownFrame(btn.cooldown); ClearStackAndCount(btn)
                                    btn.icon:SetDesaturated(s.desaturateOnAbsent ~= false); btn:SetAlpha(tonumber(s.alphaOnAbsent) or 0.45)
                                end
                                local gs = s.glow; local glowVal = buffActive and 9999 or 0
                                if gs and gs.enabled then MSWA_UpdateGlow_Fast(btn, gs, glowVal, buffActive)
                                elseif btn._msaGlowActive then MSWA_StopGlow(btn) end
                                MSWA_ApplyConditionalTextColor_Fast(btn, s, db, glowVal, buffActive)
                                if btn._msaReminderLabel then btn._msaReminderLabel:Hide() end
                                if btn._msaChargeLabel then btn._msaChargeLabel:Hide() end
                                index = index + 1
                            else HideButton(btn) end

                        elseif s and (s.auraMode == "AUTOBUFF" or s.auraMode == "BUFF_THEN_CD") then
                            -- ========== ITEM INSTANCE: AUTO BUFF / BUFF_THEN_CD ==========
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
                                    foundAutoBuffActive = true; foundNeedsTimerTick = true
                                else
                                    ab.active = false
                                end
                            end

                            if inBuffPhase then
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                                MSWA_ApplyCooldownFrame(btn.cooldown, timerStart, buffDur, 1)
                                btn.icon:SetDesaturated(false)
                                if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                                btn:SetAlpha(ComputeAlpha(s, true, inCombat))
                                MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)

                                local glowRem = buffDur - (now - timerStart)
                                if glowRem < 0 then glowRem = 0 end
                                local gs = s and s.glow
                                if gs and gs.enabled then
                                    MSWA_UpdateGlow_Fast(btn, gs, glowRem, glowRem > 0)
                                elseif btn._msaGlowActive then
                                    MSWA_StopGlow(btn)
                                end
                                MSWA_ApplyConditionalTextColor_Fast(btn, s, db, glowRem, glowRem > 0)
                                MSWA_ApplySwipeDarken_Fast(btn, s)
                                foundCooldownActive = true
                                index = index + 1

                            elseif isBuffThenCD then
                                -- === BUFF_THEN_CD: buff expired -> show remaining item CD ===
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)

                                if GetItemCooldown then
                                    local iStart, iDuration = GetItemCooldown(itemID)
                                    local ok, onCD = pcall(_itemCDCheck, iStart, iDuration)
                                    if ok and onCD then
                                        MSWA_ApplyCooldownFrame(btn.cooldown, iStart, iDuration, 1)
                                    else
                                        MSWA_ClearCooldownFrame(btn.cooldown)
                                    end
                                else
                                    MSWA_ClearCooldownFrame(btn.cooldown)
                                end

                                MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)

                                local onCD = MSWA_IsCooldownActive(btn)
                                if onCD then foundCooldownActive = true end

                                if onCD then
                                    if s.grayOnCooldown then
                                        btn.icon:SetDesaturated(true)
                                    else
                                        btn.icon:SetDesaturated(false)
                                    end
                                    if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                                    btn:SetAlpha(ComputeAlpha(s, true, inCombat))

                                    local rem = 0
                                    local need = (s.glow and s.glow.enabled) or s.textColor2Enabled
                                    if need then foundNeedsTimerTick = true end
                                    if need and GetItemCooldown then
                                        local st, dur = GetItemCooldown(itemID)
                                        local ok2, r = pcall(_itemCDRemaining, st, dur, now)
                                        if ok2 and type(r) == "number" then
                                            rem = r
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
                                    index = index + 1
                                elseif previewMode or key == selectedKey then
                                    btn.icon:SetDesaturated(false)
                                    if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                                    btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                    MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)
                                    MSWA_StopGlow(btn)
                                    index = index + 1
                                else
                                    -- BUFF_THEN_CD: CD ready -> keep visible idle
                                    MSWA_ClearCooldownFrame(btn.cooldown)
                                    btn.icon:SetDesaturated(false)
                                    if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                                    btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                    MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)
                                    MSWA_StopGlow(btn)
                                    index = index + 1
                                end

                            elseif previewMode or key == selectedKey then
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                                MSWA_ClearCooldownFrame(btn.cooldown)
                                btn.icon:SetDesaturated(false)
                                if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                                btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)
                                MSWA_StopGlow(btn)
                                index = index + 1
                            else
                                if IsItemZeroCount(s, itemID) then
                                    PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                                    MSWA_ClearCooldownFrame(btn.cooldown)
                                    btn.icon:SetDesaturated(true)
                                    btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                    MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)
                                    MSWA_StopGlow(btn)
                                    index = index + 1
                                else
                                    HideButton(btn)
                                end
                            end

                        elseif s and s.auraMode == "REMINDER_BUFF" then
                            -- ========== ITEM INSTANCE: REMINDER BUFF ==========
                            local ab = autoBuff[key]
                            local buffDur = GetEffectiveBuffDuration(s)
                            local buffDelay = tonumber(s.autoBuffDelay) or 0

                            local inBuffPhase = false
                            if ab and ab.active then
                                local totalWindow = buffDelay + buffDur
                                if (now - ab.startTime) < totalWindow then
                                    inBuffPhase = true
                                    foundAutoBuffActive = true; foundNeedsTimerTick = true
                                else
                                    ab.active = false
                                end
                            end

                            if not inBuffPhase then
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                                MSWA_ClearCooldownFrame(btn.cooldown)
                                btn.icon:SetDesaturated(false)
                                if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                                btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                ClearStackAndCount(btn)
                                MSWA_ShowReminderLabel(btn, s, db)

                                local gs = s.glow
                                if gs and gs.enabled then
                                    MSWA_UpdateGlow_Fast(btn, gs, 9999, true)
                                elseif btn._msaGlowActive then
                                    MSWA_StopGlow(btn)
                                end
                                MSWA_ApplyConditionalTextColor_Fast(btn, s, db, 0, false)
                                index = index + 1

                            elseif s.reminderShowTimer then
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                                local timerStart = ab.startTime + buffDelay
                                MSWA_ApplyCooldownFrame(btn.cooldown, timerStart, buffDur, 1)
                                btn.icon:SetDesaturated(false)
                                if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                                btn:SetAlpha(ComputeAlpha(s, true, inCombat))
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
                                foundCooldownActive = true
                                index = index + 1

                            elseif previewMode or key == selectedKey then
                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                                MSWA_ClearCooldownFrame(btn.cooldown)
                                btn.icon:SetDesaturated(false)
                                btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                MSWA_ShowReminderLabel(btn, s, db)
                                MSWA_StopGlow(btn)
                                index = index + 1
                            else
                                HideButton(btn)
                            end

                        else
                            -- ========== ITEM INSTANCE: NORMAL COOLDOWN MODE ==========
                            -- (with optional CHARGES support)
                            if s and s.auraMode == "CHARGES" then
                                MSWA._charges = MSWA._charges or {}
                                local maxC = tonumber(s.chargeMax) or 3
                                local ch = MSWA._charges[key]
                                if not ch then
                                    ch = { remaining = maxC, rechargeStart = 0 }
                                    MSWA._charges[key] = ch
                                end
                                local recharging = MSWA_ChargeRechargeTick(key, s, now)
                                local rem = ch.remaining

                                PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                                if recharging and ch.rechargeStart > 0 then
                                    local dur = tonumber(s.chargeDuration) or 0
                                    MSWA_ApplyCooldownFrame(btn.cooldown, ch.rechargeStart, dur, 1)
                                    foundCooldownActive = true
                                else
                                    MSWA_ClearCooldownFrame(btn.cooldown)
                                end
                                btn.icon:SetDesaturated(rem <= 0)
                                if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                                btn:SetAlpha(ComputeAlpha(s, recharging, inCombat))
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
                                if recharging then
                                    MSWA_ApplySwipeDarken_Fast(btn, s)
                                    foundAutoBuffActive = true; foundNeedsTimerTick = true
                                end
                                index = index + 1
                            else
                            -- ========== ITEM INSTANCE: NORMAL COOLDOWN MODE ==========
                            PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)

                            if GetItemCooldown then
                                local iStart, iDuration = GetItemCooldown(itemID)
                                local ok, onCD = pcall(_itemCDCheck, iStart, iDuration)
                                if ok and onCD then
                                    MSWA_ApplyCooldownFrame(btn.cooldown, iStart, iDuration, 1)
                                else
                                    MSWA_ClearCooldownFrame(btn.cooldown)
                                end
                            else
                                MSWA_ClearCooldownFrame(btn.cooldown)
                            end

                            MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)

                            local onCD = MSWA_IsCooldownActive(btn)
                            if onCD then foundCooldownActive = true end

                            if s and s.grayOnCooldown then
                                btn.icon:SetDesaturated(onCD)
                            else
                                btn.icon:SetDesaturated(false)
                            end
                            if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end

                            btn:SetAlpha(ComputeAlpha(s, onCD, inCombat))

                            local rem = 0
                            if onCD and s then
                                local need = (s.glow and s.glow.enabled) or s.textColor2Enabled
                                    if need then foundNeedsTimerTick = true end
                                if need and GetItemCooldown then
                                    local st, dur = GetItemCooldown(itemID)
                                    local ok2, r = pcall(_itemCDRemaining, st, dur, now)
                                    if ok2 and type(r) == "number" then
                                        rem = r
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

                            index = index + 1
                            end -- end CHARGES else (normal item CD)
                        end
                    end

                elseif (previewMode or trackedKey == selectedKey) and MSWA_IsDraftKey(trackedKey) then
                    local btn = icons[index]
                    local s   = settingsTable[trackedKey] or settingsTable[tostring(trackedKey)]
                    SetIconTexture(btn, trackedKey)
                    btn:Show()
                    btn.spellID = trackedKey
                    btn:ClearAllPoints()
                    PositionButton(btn, s, trackedKey, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                    MSWA_ClearCooldownFrame(btn.cooldown)
                    ApplyStylesIfDirty(btn, db, s, trackedKey)
                    btn.icon:SetDesaturated(false)
                    btn:SetAlpha(0.6)
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
            local shouldLoad = MSWA_ShouldLoadAura(s, inCombat, inEncounter)

            if shouldLoad or previewMode or key == selectedKey then
                local btn = icons[index]
                SetIconTexture(btn, key)
                btn:Show()
                btn.spellID = key
                btn:ClearAllPoints()

                ApplyStylesIfDirty(btn, db, s, key)

                -- Clean stale overlays from mode switches (zero cost if nil)
                if (not s or s.auraMode ~= "REMINDER_BUFF") and btn._msaReminderLabel then btn._msaReminderLabel:Hide() end
                if (not s or s.auraMode ~= "CHARGES") and btn._msaChargeLabel then btn._msaChargeLabel:Hide() end

                if s and s.auraMode == "BUFF_AURA" then
                    -- ========== ITEM: BUFF AURA (EQoL GetUnitAuras pattern) ==========
                    local buffSID = s.auraSpellID or itemID
                    local auraData = MSWA_GetPlayerAuraDataBySpellID(buffSID)
                    local buffActive = (auraData ~= nil)
                    local showMe = buffActive or s.showWhenAbsent or previewMode or key == selectedKey
                    if showMe then
                        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                        if buffActive then
                            local cd = btn.cooldown
                            if cd then
                                local dur = auraData.duration
                                local exp = auraData.expirationTime
                                local isSecret = MSWA_IsSecretValue(dur) or MSWA_IsSecretValue(exp)
                                if isSecret and cd.SetCooldownFromExpirationTime then
                                    cd:SetCooldownFromExpirationTime(exp, dur, auraData.timeMod); cd.__mswaSet = true
                                elseif dur and dur > 0 and exp then
                                    MSWA_ApplyCooldownFrame(cd, exp - dur, dur, auraData.timeMod or 1, exp)
                                else MSWA_ClearCooldownFrame(cd) end
                            end
                            if s.showStacks ~= false and not (s.hideStacksOnCooldown and MSWA_IsCooldownActive(btn)) then
                                local sText = MSWA_GetAuraStackText(auraData, 2)
                                local sTarget = btn.stackText or btn.count
                                if sText and sTarget then sTarget:SetText(sText); sTarget:Show() else ClearStackAndCount(btn) end
                            else ClearStackAndCount(btn) end
                            btn.icon:SetDesaturated(false); btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                        else
                            MSWA_ClearCooldownFrame(btn.cooldown); ClearStackAndCount(btn)
                            btn.icon:SetDesaturated(s.desaturateOnAbsent ~= false); btn:SetAlpha(tonumber(s.alphaOnAbsent) or 0.45)
                        end
                        local gs = s.glow; local glowVal = buffActive and 9999 or 0
                        if gs and gs.enabled then MSWA_UpdateGlow_Fast(btn, gs, glowVal, buffActive)
                        elseif btn._msaGlowActive then MSWA_StopGlow(btn) end
                        MSWA_ApplyConditionalTextColor_Fast(btn, s, db, glowVal, buffActive)
                        if btn._msaReminderLabel then btn._msaReminderLabel:Hide() end
                        if btn._msaChargeLabel then btn._msaChargeLabel:Hide() end
                        index = index + 1
                    else HideButton(btn) end

                elseif s and (s.auraMode == "AUTOBUFF" or s.auraMode == "BUFF_THEN_CD") then
                    -- ========== ITEM AUTO BUFF / BUFF_THEN_CD MODE ==========
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
                            foundAutoBuffActive = true; foundNeedsTimerTick = true
                        else
                            ab.active = false
                        end
                    end

                    if inBuffPhase then
                        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                        MSWA_ApplyCooldownFrame(btn.cooldown, timerStart, buffDur, 1)
                        btn.icon:SetDesaturated(false)
                        if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                        btn:SetAlpha(ComputeAlpha(s, true, inCombat))
                        MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)

                        local glowRem = buffDur - (now - timerStart)
                        if glowRem < 0 then glowRem = 0 end
                        local gs = s and s.glow
                        if gs and gs.enabled then
                            MSWA_UpdateGlow_Fast(btn, gs, glowRem, glowRem > 0)
                        elseif btn._msaGlowActive then
                            MSWA_StopGlow(btn)
                        end
                        MSWA_ApplyConditionalTextColor_Fast(btn, s, db, glowRem, glowRem > 0)
                        MSWA_ApplySwipeDarken_Fast(btn, s)
                        foundCooldownActive = true
                        index = index + 1

                    elseif isBuffThenCD then
                        -- === BUFF_THEN_CD: buff expired -> show remaining item CD ===
                        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)

                        if GetItemCooldown then
                            local iStart, iDuration = GetItemCooldown(itemID)
                            local ok, onCD = pcall(_itemCDCheck, iStart, iDuration)
                            if ok and onCD then
                                MSWA_ApplyCooldownFrame(btn.cooldown, iStart, iDuration, 1)
                            else
                                MSWA_ClearCooldownFrame(btn.cooldown)
                            end
                        else
                            MSWA_ClearCooldownFrame(btn.cooldown)
                        end

                        MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)

                        local onCD = MSWA_IsCooldownActive(btn)
                        if onCD then foundCooldownActive = true end

                        if onCD then
                            if s.grayOnCooldown then
                                btn.icon:SetDesaturated(true)
                            else
                                btn.icon:SetDesaturated(false)
                            end
                            if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                            btn:SetAlpha(ComputeAlpha(s, true, inCombat))

                            local rem = 0
                            local need = (s.glow and s.glow.enabled) or s.textColor2Enabled
                                    if need then foundNeedsTimerTick = true end
                            if need and GetItemCooldown then
                                local st, dur = GetItemCooldown(itemID)
                                local ok2, r = pcall(_itemCDRemaining, st, dur, now)
                                if ok2 and type(r) == "number" then
                                    rem = r
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
                            index = index + 1
                        elseif previewMode or key == selectedKey then
                            btn.icon:SetDesaturated(false)
                            if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                            btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                            MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)
                            MSWA_StopGlow(btn)
                            index = index + 1
                        else
                            -- BUFF_THEN_CD: CD ready -> keep visible idle
                            MSWA_ClearCooldownFrame(btn.cooldown)
                            btn.icon:SetDesaturated(false)
                            if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                            btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                            MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)
                            MSWA_StopGlow(btn)
                            index = index + 1
                        end

                    elseif previewMode or key == selectedKey then
                        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                        MSWA_ClearCooldownFrame(btn.cooldown)
                        btn.icon:SetDesaturated(false)
                        if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                        btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                        MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)
                        MSWA_StopGlow(btn)
                        index = index + 1
                    else
                        if IsItemZeroCount(s, itemID) then
                            PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                            MSWA_ClearCooldownFrame(btn.cooldown)
                            btn.icon:SetDesaturated(true)
                            btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                            MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)
                            MSWA_StopGlow(btn)
                            index = index + 1
                        else
                            HideButton(btn)
                        end
                    end

                elseif s and s.auraMode == "REMINDER_BUFF" then
                    -- ========== ITEM: REMINDER BUFF ==========
                    local ab = autoBuff[key]
                    local buffDur = GetEffectiveBuffDuration(s)
                    local buffDelay = tonumber(s.autoBuffDelay) or 0

                    local inBuffPhase = false
                    if ab and ab.active then
                        local totalWindow = buffDelay + buffDur
                        if (now - ab.startTime) < totalWindow then
                            inBuffPhase = true
                            foundAutoBuffActive = true; foundNeedsTimerTick = true
                        else
                            ab.active = false
                        end
                    end

                    if not inBuffPhase then
                        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                        MSWA_ClearCooldownFrame(btn.cooldown)
                        btn.icon:SetDesaturated(false)
                        if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                        btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                        ClearStackAndCount(btn)
                        MSWA_ShowReminderLabel(btn, s, db)

                        local gs = s.glow
                        if gs and gs.enabled then
                            MSWA_UpdateGlow_Fast(btn, gs, 9999, true)
                        elseif btn._msaGlowActive then
                            MSWA_StopGlow(btn)
                        end
                        MSWA_ApplyConditionalTextColor_Fast(btn, s, db, 0, false)
                        index = index + 1

                    elseif s.reminderShowTimer then
                        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                        local timerStart = ab.startTime + buffDelay
                        MSWA_ApplyCooldownFrame(btn.cooldown, timerStart, buffDur, 1)
                        btn.icon:SetDesaturated(false)
                        if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                        btn:SetAlpha(ComputeAlpha(s, true, inCombat))
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
                        foundCooldownActive = true
                        index = index + 1

                    elseif previewMode or key == selectedKey then
                        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                        MSWA_ClearCooldownFrame(btn.cooldown)
                        btn.icon:SetDesaturated(false)
                        btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                        MSWA_ShowReminderLabel(btn, s, db)
                        MSWA_StopGlow(btn)
                        index = index + 1
                    else
                        HideButton(btn)
                    end

                else
                    -- ========== NORMAL ITEM COOLDOWN MODE ==========
                    -- (with optional CHARGES support)
                    if s and s.auraMode == "CHARGES" then
                        MSWA._charges = MSWA._charges or {}
                        local maxC = tonumber(s.chargeMax) or 3
                        local ch = MSWA._charges[key]
                        if not ch then
                            ch = { remaining = maxC, rechargeStart = 0 }
                            MSWA._charges[key] = ch
                        end
                        local recharging = MSWA_ChargeRechargeTick(key, s, now)
                        local rem = ch.remaining

                        PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
                        if recharging and ch.rechargeStart > 0 then
                            local dur = tonumber(s.chargeDuration) or 0
                            MSWA_ApplyCooldownFrame(btn.cooldown, ch.rechargeStart, dur, 1)
                            foundCooldownActive = true
                        else
                            MSWA_ClearCooldownFrame(btn.cooldown)
                        end
                        btn.icon:SetDesaturated(rem <= 0)
                        if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                        btn:SetAlpha(ComputeAlpha(s, recharging, inCombat))
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
                        if recharging then
                            MSWA_ApplySwipeDarken_Fast(btn, s)
                            foundAutoBuffActive = true; foundNeedsTimerTick = true
                        end
                        index = index + 1
                    else
                    -- ========== NORMAL ITEM COOLDOWN MODE ==========
                    PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)

                    if GetItemCooldown then
                        local iStart, iDuration = GetItemCooldown(itemID)
                        -- v5: no closure - pcall on named function
                        local ok, onCD = pcall(_itemCDCheck, iStart, iDuration)
                        if ok and onCD then
                            MSWA_ApplyCooldownFrame(btn.cooldown, iStart, iDuration, 1)
                        else
                            MSWA_ClearCooldownFrame(btn.cooldown)
                        end
                    else
                        MSWA_ClearCooldownFrame(btn.cooldown)
                    end

                    MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)

                    local onCD = MSWA_IsCooldownActive(btn)
                    if onCD then foundCooldownActive = true end

                    if s and s.grayOnCooldown then
                        btn.icon:SetDesaturated(onCD)
                    else
                        btn.icon:SetDesaturated(false)
                    end
                    if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end

                    btn:SetAlpha(ComputeAlpha(s, onCD, inCombat))

                    local rem = 0
                    if onCD and s then
                        local need = (s.glow and s.glow.enabled) or s.textColor2Enabled
                                    if need then foundNeedsTimerTick = true end
                        if need and GetItemCooldown then
                            -- v5: no closure - pcall on named function
                            local st, dur = GetItemCooldown(itemID)
                            local ok2, r = pcall(_itemCDRemaining, st, dur, now)
                            if ok2 and type(r) == "number" then
                                rem = r
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

                    index = index + 1
                    end -- end CHARGES else (normal item CD)
                end
            end
        end
    end

    -----------------------------------------------------------
    -- 2.4) Charge label cleanup: hide labels on non-CHARGES
    -- buttons (the CHARGES mode blocks handle showing inline)
    -----------------------------------------------------------
    for ci = 1, index - 1 do
        local btn = icons[ci]
        if btn and btn.spellID then
            local ck  = btn.spellID
            local cs  = settingsTable[ck] or settingsTable[tostring(ck)]
            if not (cs and cs.auraMode == "CHARGES") then
                if btn._msaChargeLabel then btn._msaChargeLabel:Hide() end
            end
        end
    end

    -----------------------------------------------------------
    -- 2.5) Finalize group anchor footprints
    -----------------------------------------------------------
    if groupCtx and next(groupCtx.used) ~= nil then
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
        MSWA_HideUnusedGroupAnchorFrames(groupCtx and groupCtx.used)
    end

    -----------------------------------------------------------
    -- 2b) Bar post-processing: convert visible icons to bars
    -- Runs AFTER all mode branches so icon state is final.
    -- Re-reads timing from APIs (buff cache is per-frame,
    -- CD calls are trivial). ZERO changes to mode branches.
    -----------------------------------------------------------
    if MSWA_IsBarMode then
        local _issv = _G.issecretvalue
        for i = 1, index - 1 do
            local btn = icons[i]
            if btn and btn:IsShown() then
                local bkey = btn.spellID
                local bs = bkey and settingsTable[bkey]
                if bs and bs.displayType == "BAR" then
                    local bInfo = { isActive = true, name = nil, expires = 0, duration = 0, stacks = nil, absentAlpha = 0.45, isSecret = false }

                    -- Name: customName > spellName > key
                    local cn = db.customNames and db.customNames[bkey]
                    if cn and cn ~= "" then
                        bInfo.name = cn
                    else
                        -- Extract numeric spellID from any key format
                        local numKey = tonumber(bkey)
                        if numKey then
                            -- Plain numeric spell ID
                            bInfo.name = MSWA_GetSpellName and MSWA_GetSpellName(numKey)
                        else
                            local bkeyStr = tostring(bkey)
                            -- spell:ID:N instance key
                            local sid = bkeyStr:match("^spell:(%d+)")
                            if sid then
                                sid = tonumber(sid)
                                if sid then bInfo.name = MSWA_GetSpellName and MSWA_GetSpellName(sid) end
                            else
                                -- item:ID or item:ID:N
                                local iid = bkeyStr:match("^item:(%d+)")
                                iid = iid and tonumber(iid)
                                if iid then
                                    if C_Item and C_Item.GetItemNameByID then
                                        bInfo.name = C_Item.GetItemNameByID(iid)
                                    end
                                end
                            end
                        end
                    end
                    if not bInfo.name or bInfo.name == "" then bInfo.name = tostring(bkey) end

                    -- Timing: depends on auraMode
                    local mode = bs.auraMode

                    if mode == "BUFF_AURA" then
                        local sid = bs.auraSpellID or tonumber(bkey)
                        local ad = sid and MSWA_GetPlayerAuraDataBySpellID and MSWA_GetPlayerAuraDataBySpellID(sid)
                        if ad then
                            local e = ad.expirationTime
                            local d = ad.duration
                            if e and d then
                                if (_issv and _issv(e)) or (_issv and _issv(d)) then
                                    bInfo.isSecret = true
                                else
                                    bInfo.expires  = e
                                    bInfo.duration = d
                                end
                            end
                            bInfo.stacks = MSWA_GetAuraStackText and MSWA_GetAuraStackText(ad, 2)
                        else
                            bInfo.isActive = (bs.showWhenAbsent == true or previewMode)
                            if not bInfo.isActive then bInfo.isActive = false end
                            bInfo.absentAlpha = tonumber(bs.alphaOnAbsent) or 0.45
                        end

                    elseif mode == "AUTOBUFF" or mode == "BUFF_THEN_CD" then
                        local ab = autoBuff and autoBuff[bkey]
                        if ab and ab.active then
                            local delay = tonumber(bs.autoBuffDelay) or 0
                            local bdur = tonumber(bs.autoBuffDuration) or 10
                            local tStart = ab.startTime + delay
                            bInfo.expires  = tStart + bdur
                            bInfo.duration = bdur
                        elseif mode == "BUFF_THEN_CD" then
                            -- CD phase
                            local numSID = tonumber(bkey)
                            if numSID and C_Spell and C_Spell.GetSpellCooldown then
                                local cdI = C_Spell.GetSpellCooldown(numSID)
                                if cdI and cdI.duration and cdI.duration > 1.5 then
                                    bInfo.expires  = cdI.startTime + cdI.duration
                                    bInfo.duration = cdI.duration
                                end
                            end
                        end

                    elseif mode == "CHARGES" then
                        local numSID = tonumber(bkey)
                        if numSID and C_Spell and C_Spell.GetSpellCharges then
                            local ok2, cInfo = pcall(C_Spell.GetSpellCharges, numSID)
                            if ok2 and type(cInfo) == "table" and cInfo.cooldownStartTime and cInfo.cooldownDuration and cInfo.cooldownDuration > 0 then
                                bInfo.expires  = cInfo.cooldownStartTime + cInfo.cooldownDuration
                                bInfo.duration = cInfo.cooldownDuration
                            end
                        end

                    elseif mode == "REMINDER_BUFF" then
                        -- Reminder: no timing, just active/absent handled by icon state
                        bInfo.expires  = 0
                        bInfo.duration = 0

                    else
                        -- Normal CD mode
                        local numKey = tonumber(bkey)
                        if numKey then
                            -- Spell CD
                            if C_Spell and C_Spell.GetSpellCooldown then
                                local cdI = C_Spell.GetSpellCooldown(numKey)
                                if cdI and cdI.duration and cdI.duration > 1.5 then
                                    bInfo.expires  = cdI.startTime + cdI.duration
                                    bInfo.duration = cdI.duration
                                end
                            end
                        else
                            -- Item CD
                            local iid = bkey and tostring(bkey):match("^item:(%d+)")
                            iid = iid and tonumber(iid)
                            if iid and GetItemCooldown then
                                local st, dur = GetItemCooldown(iid)
                                if st and dur and dur > 1.5 then
                                    bInfo.expires  = st + dur
                                    bInfo.duration = dur
                                end
                            end
                        end
                    end

                    -- Bars need timer tick for smooth animation
                    if bInfo.isActive ~= false and (bInfo.duration or 0) > 0 then
                        foundNeedsTimerTick = true
                    end

                    MSWA_UpdateBarDisplay(btn, bs, db, bInfo)

                elseif btn._msaBar and btn._msaBar.frame and btn._msaBar.frame:IsShown() then
                    -- Was bar, now icon mode again
                    MSWA_HideBar(btn)
                end
            end
        end
    end

    -----------------------------------------------------------
    -- 2c) Icon decimal timer: custom timer text for showDecimal
    -- Post-processing: for visible ICON-mode buttons with
    -- showDecimal, overlay a custom timer FontString and hide
    -- Blizzard's built-in countdown numbers.
    -- Uses cd.__mswaExp / cd.__mswaDur stored by MSWA_ApplyCooldownFrame
    -- (GetTime-based seconds, NOT milliseconds) - fully reliable.
    -----------------------------------------------------------
    if MSWA_FormatTimer then
        local _issv2 = _G.issecretvalue
        for i = 1, index - 1 do
            local btn = icons[i]
            if btn and btn:IsShown() then
                local bkey = btn.spellID
                local bs = bkey and settingsTable[bkey]
                -- Skip BAR mode (bars handle their own timer)
                if bs and bs.displayType ~= "BAR" and bs.showDecimal then
                    local cd = btn.cooldown
                    local remaining = 0

                    -- Read remaining from stored timing (set by MSWA_ApplyCooldownFrame)
                    if cd and cd.__mswaSet and cd.__mswaDur then
                        local exp = cd.__mswaExp
                        local dur = cd.__mswaDur
                        local st  = cd.__mswaStart

                        -- Secret guard (NEVER arithmetic on secret values)
                        if _issv2 and ((exp and _issv2(exp)) or (st and _issv2(st)) or _issv2(dur)) then
                            remaining = -1  -- secret -> skip
                        elseif dur > 1.5 then
                            if exp ~= nil then
                                remaining = exp - now
                            elseif st ~= nil then
                                remaining = (st + dur) - now
                            end
                            if remaining and remaining < 0 then remaining = 0 end
                        end
                    end

                    if remaining > 0 then
                        -- Lazy-create decimal timer FontString
                        if not btn._msaDecimalTimer then
                            btn._msaDecimalTimer = btn:CreateFontString(nil, "OVERLAY")
                            btn._msaDecimalTimer:SetPoint("CENTER", btn, "CENTER", 0, 0)
                        end
                        -- Style: match icon text settings
                        local fontKey = (bs.textFontKey) or (db.fontKey) or "DEFAULT"
                        local fp = MSWA_GetFontPathFromKey and MSWA_GetFontPathFromKey(fontKey) or STANDARD_TEXT_FONT
                        local fs = tonumber(bs.textFontSize) or tonumber(db.textFontSize) or 12
                        local tc = bs.textColor or db.textColor
                        local r, g, b = 1, 1, 1
                        if tc then r = tonumber(tc.r) or 1; g = tonumber(tc.g) or 1; b = tonumber(tc.b) or 1 end
                        btn._msaDecimalTimer:SetFont(fp, fs, "OUTLINE")
                        btn._msaDecimalTimer:SetTextColor(r, g, b, 1)
                        btn._msaDecimalTimer:SetText(MSWA_FormatTimer(remaining, true))
                        btn._msaDecimalTimer:Show()
                        -- Hide Blizzard countdown numbers
                        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
                        foundNeedsTimerTick = true
                    elseif btn._msaDecimalTimer then
                        btn._msaDecimalTimer:Hide()
                        if cd and cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
                    end
                elseif btn._msaDecimalTimer then
                    -- showDecimal off or bar mode: restore Blizzard numbers
                    btn._msaDecimalTimer:Hide()
                    local cd = btn.cooldown
                    if cd and cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
                end
            end
        end
    end

    -----------------------------------------------------------
    -- 3) Hide remaining buttons
    -----------------------------------------------------------
    local activeCount = index - 1
    for i = index, MAX_ICONS do
        local btn = icons[i]
        if btn.spellID ~= nil or btn:IsShown() then
            btn:Hide()
            btn.icon:SetTexture(nil)
            btn._msaCachedKey = nil
            btn._msaStyleKey  = nil
            MSWA_ClearCooldownFrame(btn.cooldown)
            MSWA_StopGlow(btn)
            MSWA_HideReminderLabel(btn)
            MSWA_HideChargeLabel(btn)
            if MSWA_CleanupBar then MSWA_CleanupBar(btn) end
            btn.spellID = nil
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
    -- 5+6) v6: inline-tracked flags - no post-loop scan needed.
    -- foundNeedsTimerTick was set inline wherever:
    --   * autoBuffActive modes (buff/charge timers ticking)
    --   * CDs with glow conditions or conditional text color
    -- Normal CDs without these features = zero engine cost
    -- (Blizzard's CooldownFrame handles swipe natively).
    -----------------------------------------------------------
    autoBuffActive = foundAutoBuffActive
    needsTimerTick = foundNeedsTimerTick
end

-- Export globally
MSWA.UpdateSpells    = MSWA_UpdateSpells
_G.MSWA_UpdateSpells = MSWA_UpdateSpells

-----------------------------------------------------------
-- Lightweight autobuff tick (only checks for expiry)
-- v5: throttled to 10 Hz alongside main update
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
-- OnUpdate: 10 Hz throttled
-- v6: engine ONLY runs when there's actual work:
--   * dirty flag (event-driven changes)
--   * autoBuffActive (buff/charge timers ticking)
--   * needsTimerTick (glow/textcolor conditions on active CDs)
-- Normal CDs without glow/textcolor = zero engine cost.
-----------------------------------------------------------

engineFrame:SetScript("OnUpdate", function(self)
    local now = GetTime()

    -- needsTimerTick: glow/textcolor conditions need periodic re-eval
    if needsTimerTick and not dirty then
        dirty = true
    end

    if dirty or autoBuffActive then
        if forceImmediate or (now - lastFullUpdate) >= THROTTLE_INTERVAL then
            -- v5: AutoBuffTick runs at same 10 Hz rate, not every frame
            if autoBuffActive then
                AutoBuffTick(MSWA_GetDB().spellSettings or {}, now)
            end
            dirty = false
            forceImmediate = false
            lastFullUpdate = now
            MSWA_UpdateSpells()
        end
    end

    if not dirty and not autoBuffActive and not needsTimerTick then
        self:Hide()
    end
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
    -- Clear texture + style caches on all buttons
    if MSWA.icons then
        for i = 1, MSWA.MAX_ICONS do
            local btn = MSWA.icons[i]
            if btn then
                btn._msaCachedKey = nil
                btn._msaStyleKey  = nil
            end
        end
    end
    lastActiveCount = -1   -- Force Masque reskin + event re-reg
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
-- Load filter refresh (combat/encounter state changes)
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

        if triggered then
            autoBuffActive = true
        end
        if triggered or chargeDirty then
            MSWA_ForceUpdateSpells()
        end
    end)
end

-----------------------------------------------------------
-- Auto Buff (Items): cooldown-start detection
-- Scans both trackedItems and trackedSpells (item instances)
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

        local ok, isActiveCD = pcall(_itemCDCheck, start, duration)
        local isFreshCD = ok and isActiveCD and (start ~= prevStart)

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

        lastItemCDStart[key] = (ok and isActiveCD) and start or 0
        return nil
    end

    itemCDFrame:SetScript("OnEvent", function()
        if not GetItemCooldown then return end
        local db = MSWA_GetDB()
        if not db.spellSettings then return end

        local buffTriggered = false
        local anyTriggered = false
        local now = GetTime()

        -- Check trackedItems (item:ID keys)
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

        -- Check trackedSpells for item instance keys (item:ID:N)
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

        if buffTriggered then
            autoBuffActive = true
        end
        if anyTriggered then
            MSWA_ForceUpdateSpells()
        end
    end)
end

-----------------------------------------------------------
-- Reminder Buff: death detection
-- Clears autoBuff entries for REMINDER_BUFF auras that
-- do NOT persist through death (group buffs, MotW, etc.)
-- Poisons/flasks with persistDeath=true are unaffected.
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

        if cleared then
            MSWA_ForceUpdateSpells()
        end
    end)
end
