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
-- Reminder threshold: now in MSA_BuffBridge.lua (MSWA_ShouldHideByThreshold)
-----------------------------------------------------------
local ShouldHideByThreshold = function(s, auraData, now)
    return MSWA_ShouldHideByThreshold(s, auraData, now)
end

-----------------------------------------------------------
-- Engine frame (hidden = zero CPU)
-----------------------------------------------------------

local engineFrame = CreateFrame("Frame", "MSWA_EngineFrame", UIParent)
engineFrame:Hide()

local dirty              = false
local autoBuffActive     = false
local needsTimerTick     = false   -- retained for compat; timer visuals now use dedicated lightweight tickers
local lastFullUpdate     = 0
local forceImmediate     = false
local lastActiveCount    = 0
local nextSyntheticWake  = 0
local requestPending     = false

local visualTickFrame    = CreateFrame("Frame", "MSWA_VisualTickFrame", UIParent)
local visualTickCount    = 0
local visualTickList     = {}
local visualTickElapsed  = 0
local VISUAL_TICK_RATE   = 0.05

local function GetVisualTimerBucket(seconds, useFineBucket)
    if not seconds or seconds <= 0 then return 0 end
    if useFineBucket and seconds < 10 then
        return math.floor((seconds * 10) + 0.0001)
    end
    return math.floor(seconds)
end

local function QueueSyntheticWakeCandidate(currentWake, wakeAt)
    if type(wakeAt) ~= "number" or wakeAt <= 0 then return currentWake end
    if currentWake == 0 or wakeAt < currentWake then
        return wakeAt
    end
    return currentWake
end

visualTickFrame:Hide()

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

local function RestoreButtonParent(btn, frame, key)
    if not btn then return end
    btn._msaLastAttachLayout = nil
    local desired = frame or MSWA.frame or UIParent
    if btn.GetParent and btn:GetParent() ~= desired then
        btn:SetParent(desired)
    end
    if desired and desired.GetFrameStrata and btn.SetFrameStrata then
        btn:SetFrameStrata(desired:GetFrameStrata())
    end
    if desired and desired.GetFrameLevel and btn.SetFrameLevel then
        btn:SetFrameLevel((desired:GetFrameLevel() or 0) + 1)
    end
    if key and type(MSWA_HideEssentialAttachHost) == "function" then
        MSWA_HideEssentialAttachHost(key)
    elseif key and type(MSWA_UnregisterActiveEssentialAttachment) == "function" then
        MSWA_UnregisterActiveEssentialAttachment(key)
    end
    btn._msaEssentialAttachHost = nil
end

local function CanRepositionButton(btn, key)
    return not (btn and btn._mswaLiveDragging and btn.spellID == key)
end

local function PositionButton(btn, s, key, idx, frame, ICON_SIZE, ICON_SPACE, db, groupCtx)
    if s and s.attachToEssential and MSWA_IsTrinketKey and MSWA_IsTrinketKey(key) and type(MSWA_GetAttachedTrinketLayout) == "function" then
        local layout = MSWA_GetAttachedTrinketLayout(key)
        if layout and (layout.anchorTo == btn or layout.viewer == btn) then
            layout = nil
        end
        if not (layout and layout.viewer) then
            local last = btn._msaLastAttachLayout
            if last and last.viewer and last.anchorTo ~= btn and last.viewer ~= btn then
                layout = last
            end
        end
        if layout and layout.viewer then
            local aw = layout.width or ICON_SIZE
            local ah = layout.height or ICON_SIZE
            local viewer = layout.viewer
            local anchorTo = layout.anchorTo or viewer
            if anchorTo == btn then anchorTo = viewer end
            local levelSource = anchorTo or viewer

            if btn.GetParent and btn:GetParent() ~= viewer then
                btn:SetParent(viewer)
            end
            if viewer and viewer.GetFrameStrata and btn.SetFrameStrata then
                btn:SetFrameStrata(viewer:GetFrameStrata())
            end
            if levelSource and levelSource.GetFrameLevel and btn.SetFrameLevel then
                btn:SetFrameLevel((levelSource:GetFrameLevel() or 0) + 2)
            elseif viewer and viewer.GetFrameLevel and btn.SetFrameLevel then
                btn:SetFrameLevel((viewer:GetFrameLevel() or 0) + 2)
            end
            btn._msaEssentialAttachHost = nil
            btn._msaLastAttachLayout = layout
            btn:ClearAllPoints()
            btn:SetPoint(layout.anchorPoint or "LEFT", anchorTo, layout.relativePoint or "RIGHT", layout.offsetX or 0, layout.offsetY or 0)
            btn:SetSize(aw or ICON_SIZE, ah or ICON_SIZE)
            if type(MSWA_RegisterActiveEssentialAttachment) == "function" then
                MSWA_RegisterActiveEssentialAttachment(key, layout)
            end
            if type(MSWA_ApplyEssentialAttachStyle) == "function" then MSWA_ApplyEssentialAttachStyle(btn, true) end
            return
        end
    end

    if btn._msaEssentialAttached and type(MSWA_ApplyEssentialAttachStyle) == "function" then
        MSWA_ApplyEssentialAttachStyle(btn, false)
    end
    RestoreButtonParent(btn, frame, key)

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
    if btn and btn.spellID and type(MSWA_UnregisterActiveEssentialAttachment) == "function" then
        MSWA_UnregisterActiveEssentialAttachment(btn.spellID)
    end
    if btn then btn._msaLastAttachLayout = nil end
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
    if btn and btn.spellID ~= nil and btn.spellID ~= key then
        if btn._msaEssentialAttached and type(MSWA_ApplyEssentialAttachStyle) == "function" then
            MSWA_ApplyEssentialAttachStyle(btn, false)
        end
        RestoreButtonParent(btn, MSWA.frame or UIParent, btn.spellID)
    end
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
    else
        -- Gamz: "When Ready" alpha (0% = hidden when spell available, 100% when on CD)
        local ra = s and tonumber(s.readyAlpha)
        if ra then alpha = alpha * ra end
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

local function ClearDecimalTimer(btn)
    if not btn then return end
    if btn._msaDecimalTimer then
        btn._msaDecimalTimer:Hide()
        btn._msaDecimalTimer._msaLastBucket = nil
    end
    local cd = btn.cooldown
    if cd and cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
end

local function ClearVisualTickList()
    for i = 1, visualTickCount do
        local btn = visualTickList[i]
        if btn then btn._msaVisualTickQueued = nil end
        visualTickList[i] = nil
    end
    visualTickCount = 0
    visualTickElapsed = 0
end

local function QueueVisualTick(btn)
    if not btn or btn._msaVisualTickQueued then return end
    visualTickCount = visualTickCount + 1
    visualTickList[visualTickCount] = btn
    btn._msaVisualTickQueued = true
end

local function GetStoredCooldownRemaining(cd, now)
    if not cd or not cd.__mswaSet or not cd.__mswaDur then return 0, false end

    local _issv = _G.issecretvalue
    local exp = cd.__mswaExp
    local dur = cd.__mswaDur
    local st  = cd.__mswaStart

    if _issv and ((exp and _issv(exp)) or (st and _issv(st)) or _issv(dur)) then
        return -1, true
    end

    if not dur or dur <= 1.5 then return 0, false end

    local remaining = 0
    if exp ~= nil then
        remaining = exp - now
    elseif st ~= nil then
        remaining = (st + dur) - now
    end
    if remaining < 0 then remaining = 0 end
    return remaining, true
end

local function ApplyDecimalTimerText(btn, bs, db, remaining)
    if not btn then return end
    if not btn._msaDecimalTimer then
        btn._msaDecimalTimer = btn:CreateFontString(nil, "OVERLAY")
        btn._msaDecimalTimer:SetPoint("CENTER", btn, "CENTER", 0, 0)
    end

    local fontKey = (bs and bs.textFontKey) or (db and db.fontKey) or "DEFAULT"
    local fontPath = MSWA_GetFontPathFromKey and MSWA_GetFontPathFromKey(fontKey) or STANDARD_TEXT_FONT
    local fontSize = tonumber(bs and bs.textFontSize) or tonumber(db and db.textFontSize) or 12
    local tc = (bs and bs.textColor) or (db and db.textColor)
    local r, g, b = 1, 1, 1
    if tc then
        r = tonumber(tc.r) or 1
        g = tonumber(tc.g) or 1
        b = tonumber(tc.b) or 1
    end

    local timerFS = btn._msaDecimalTimer
    if timerFS._msaFontPath ~= fontPath or timerFS._msaFontSize ~= fontSize then
        timerFS._msaFontPath = fontPath
        timerFS._msaFontSize = fontSize
        timerFS:SetFont(fontPath, fontSize, "OUTLINE")
    end
    if timerFS._msaColorR ~= r or timerFS._msaColorG ~= g or timerFS._msaColorB ~= b then
        timerFS._msaColorR = r
        timerFS._msaColorG = g
        timerFS._msaColorB = b
        timerFS:SetTextColor(r, g, b, 1)
    end

    local bucket = GetVisualTimerBucket(remaining, true)
    if timerFS._msaLastBucket ~= bucket then
        timerFS._msaLastBucket = bucket
        local txt = MSWA_FormatTimer(remaining, true)
        if timerFS._msaLastText ~= txt then
            timerFS._msaLastText = txt
            timerFS:SetText(txt)
        end
    end
    timerFS:Show()

    local cd = btn.cooldown
    if cd and cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
end

local function UpdateVisualTick(now, db, settingsTable)
    local newCount = 0

    for i = 1, visualTickCount do
        local btn = visualTickList[i]
        if btn then btn._msaVisualTickQueued = nil end

        if btn and btn:IsShown() and btn.spellID then
            local key = btn.spellID
            local bs = settingsTable[key] or settingsTable[tostring(key)]
            if bs and bs.displayType ~= "BAR" then
                local cd = btn.cooldown
                local remaining, validTiming = GetStoredCooldownRemaining(cd, now)
                local isOnCooldown = validTiming and remaining > 0
                local needGlow = bs.glow and bs.glow.enabled
                local needText2 = bs.textColor2Enabled and bs.textColor2
                local needDecimal = bs.showDecimal == true

                if isOnCooldown and (needGlow or needText2 or needDecimal) then
                    newCount = newCount + 1
                    visualTickList[newCount] = btn
                    btn._msaVisualTickQueued = true

                    local fineBucket = needDecimal
                    if not fineBucket and needGlow then
                        local cond = bs.glow and bs.glow.condition
                        local val = tonumber(bs.glow and bs.glow.conditionValue) or 0
                        if (cond == "TIMER_BELOW" or cond == "TIMER_ABOVE") and val < 10 then
                            fineBucket = true
                        end
                    end
                    if not fineBucket and needText2 then
                        local cond = bs.textColor2Cond or "TIMER_BELOW"
                        local val = tonumber(bs.textColor2Value) or 0
                        if (cond == "TIMER_BELOW" or cond == "TIMER_ABOVE") and val < 10 then
                            fineBucket = true
                        end
                    end

                    local visualBucket = GetVisualTimerBucket(remaining, fineBucket)
                    if btn._msaVisualBucket ~= visualBucket or btn._msaVisualOnCooldown ~= true then
                        btn._msaVisualBucket = visualBucket
                        btn._msaVisualOnCooldown = true

                        if needDecimal then
                            ApplyDecimalTimerText(btn, bs, db, remaining)
                        else
                            ClearDecimalTimer(btn)
                        end

                        if needGlow then
                            MSWA_UpdateGlow_Fast(btn, bs.glow, remaining, true)
                        elseif btn._msaGlowActive then
                            MSWA_StopGlow(btn)
                        end

                        if needText2 then
                            MSWA_ApplyConditionalTextColor_Fast(btn, bs, db, remaining, true)
                        else
                            MSWA_ApplyConditionalTextColor_Fast(btn, bs, db, 0, false)
                        end
                    end
                else
                    btn._msaVisualBucket = nil
                    btn._msaVisualOnCooldown = nil
                    ClearDecimalTimer(btn)
                    if btn._msaGlowActive then MSWA_StopGlow(btn) end
                    if bs then MSWA_ApplyConditionalTextColor_Fast(btn, bs, db, 0, false) end
                end
            else
                ClearDecimalTimer(btn)
            end
        end
    end

    for i = newCount + 1, visualTickCount do
        visualTickList[i] = nil
    end
    visualTickCount = newCount

    if visualTickCount > 0 then
        visualTickFrame:Show()
    else
        visualTickFrame:Hide()
    end
end

visualTickFrame:SetScript("OnUpdate", function(self, elapsed)
    if visualTickCount <= 0 then
        self:Hide()
        return
    end
    if dirty or autoBuffActive then return end

    visualTickElapsed = visualTickElapsed + (elapsed or 0)
    if visualTickElapsed < VISUAL_TICK_RATE then return end
    visualTickElapsed = 0

    local db = MSWA_GetDB()
    UpdateVisualTick(GetTime(), db, db.spellSettings or {})
end)

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

    ClearVisualTickList()
    if MSWA_BeginCDMAuraCycle then MSWA_BeginCDMAuraCycle() end

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
    local foundNextSyntheticWake = 0

    -----------------------------------------------------------
    -- 1) Spells
    -----------------------------------------------------------
    if hasGetCD then
        for trackedKey, enabled in pairs(tracked) do
            if index > MAX_ICONS then break end
            if enabled then
                local spellID
                local itemFromSpells   -- item instance keys (item:ID:N) stored in trackedSpells
                local isTrinket
                if type(trackedKey) == "number" then
                    spellID = trackedKey
                elseif MSWA_IsSpellInstanceKey(trackedKey) then
                    spellID = MSWA_KeyToSpellID(trackedKey)
                elseif MSWA_IsItemKey(trackedKey) then
                    itemFromSpells = MSWA_KeyToItemID(trackedKey)
                elseif MSWA_IsTrinketKey(trackedKey) then
                    -- Trinket slot: resolve to equipped item ID (may be nil if empty)
                    local slot = MSWA_KeyToTrinketSlot(trackedKey)
                    itemFromSpells = slot and MSWA_GetTrinketItemID(slot)
                    isTrinket = true  -- always enter item path, even if slot empty
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
                        local canPosition = CanRepositionButton(btn, key)
                        if canPosition then btn:ClearAllPoints() end

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
                                    foundNextSyntheticWake = QueueSyntheticWakeCandidate(foundNextSyntheticWake, ab.startTime + totalWindow)
                                else
                                    ab.active = false
                                end
                            end

                            if inBuffPhase then
                                -- === BUFF PHASE (identical for AUTOBUFF & BUFF_THEN_CD) ===
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end

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
                                MSWA_CheckSoundTransition(key, onCD, s)

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
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                                    foundNextSyntheticWake = QueueSyntheticWakeCandidate(foundNextSyntheticWake, ab.startTime + totalWindow)
                                else
                                    ab.active = false
                                end
                            end

                            if not inBuffPhase then
                                -- BUFF MISSING -> show reminder
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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

                            if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end

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
                                foundNextSyntheticWake = QueueSyntheticWakeCandidate(foundNextSyntheticWake, ch.rechargeStart + (tonumber(s.chargeDuration) or 0))
                            end
                            index = index + 1

                        elseif s and s.auraMode == "BUFF_AURA" then
                            -- ========== BUFF AURA MODE (event-driven cache via BuffBridge) ==========
                            local auraData, buffActive = MSWA_ResolveBuffAura(s, spellID)
                            local showMe = buffActive or s.showWhenAbsent or previewMode or key == selectedKey
                            if showMe and buffActive and ShouldHideByThreshold(s, auraData, now) then showMe = false end

                            if showMe then
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
                                if buffActive then
                                    MSWA_ApplyAuraCooldown(btn.cooldown, auraData)
                                    if s.showStacks ~= false and not (s.hideStacksOnCooldown and MSWA_IsCooldownActive(btn)) then
                                        local sText = MSWA_GetAuraStackText(auraData, 2)
                                        local sTarget = btn.stackText or btn.count
                                        if sText and sTarget then sTarget:SetText(sText); sTarget:Show() else ClearStackAndCount(btn) end
                                    else ClearStackAndCount(btn) end
                                    btn.icon:SetDesaturated(false)
                                    btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                else
                                    MSWA_ClearCooldownFrame(btn.cooldown); ClearStackAndCount(btn)
                                    btn.icon:SetDesaturated(s.desaturateOnAbsent ~= false)
                                    btn:SetAlpha(tonumber(s.alphaOnAbsent) or 0.45)
                                end
                                local glowVal = buffActive and 9999 or 0
                                local gs = s.glow
                                if gs and gs.enabled then MSWA_UpdateGlow_Fast(btn, gs, glowVal, buffActive)
                                elseif btn._msaGlowActive then MSWA_StopGlow(btn) end
                                MSWA_ApplyConditionalTextColor_Fast(btn, s, db, glowVal, buffActive)
                                if btn._msaReminderLabel then btn._msaReminderLabel:Hide() end
                                if btn._msaChargeLabel then btn._msaChargeLabel:Hide() end
                                index = index + 1
                            else HideButton(btn) end

                        else
                            -- ========== NORMAL SPELL MODE ==========
                            if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end

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
                            MSWA_CheckSoundTransition(key, onCD, s)

                            if s and s.grayOnCooldown then
                                btn.icon:SetDesaturated(onCD)
                            else
                                btn.icon:SetDesaturated(false)
                            end

                            local rem = 0
                            if onCD and s then
                                local gs2 = s.glow
                                if (gs2 and gs2.enabled) or s.textColor2Enabled then
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

                elseif itemFromSpells or isTrinket then
                    -- ========== ITEM INSTANCE (item:ID:N or trinket:SLOT in trackedSpells) ==========
                    local itemID = itemFromSpells  -- may be nil for empty trinket slot
                    local key = trackedKey
                    local s   = settingsTable[key] or settingsTable[tostring(key)]
                    local shouldLoad = MSWA_ShouldLoadAura(s, inCombat, inEncounter)
                    local showSelection = previewMode or key == selectedKey
                    local suppressEmptyAttachedTrinket = isTrinket and s and s.attachToEssential and not itemID and not showSelection

                    if (shouldLoad or showSelection) and not suppressEmptyAttachedTrinket then
                        local btn = icons[index]
                        SetIconTexture(btn, key)
                        btn:Show()
                        btn.spellID = key
                        local canPosition = CanRepositionButton(btn, key)
                        if canPosition then btn:ClearAllPoints() end

                        ApplyStylesIfDirty(btn, db, s, key)

                        -- Clean stale overlays from mode switches (zero cost if nil)
                        if (not s or s.auraMode ~= "REMINDER_BUFF") and btn._msaReminderLabel then btn._msaReminderLabel:Hide() end
                        if (not s or s.auraMode ~= "CHARGES") and btn._msaChargeLabel then btn._msaChargeLabel:Hide() end

                        if s and s.auraMode == "BUFF_AURA" then
                            -- ========== ITEM INSTANCE: BUFF AURA (event-driven cache via BuffBridge) ==========
                            local auraData, buffActive = MSWA_ResolveBuffAura(s, itemID)
                            local showMe = buffActive or s.showWhenAbsent or previewMode or key == selectedKey
                            if showMe and buffActive and ShouldHideByThreshold(s, auraData, now) then showMe = false end
                            if showMe then
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
                                if buffActive then
                                    MSWA_ApplyAuraCooldown(btn.cooldown, auraData)
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
                                    foundNextSyntheticWake = QueueSyntheticWakeCandidate(foundNextSyntheticWake, ab.startTime + totalWindow)
                                else
                                    ab.active = false
                                end
                            end

                            if inBuffPhase then
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end

                                if itemID and GetItemCooldown then
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
                                MSWA_CheckSoundTransition(key, onCD, s)

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
                                    -- icon timer visuals handled by visualTickFrame
                                    if need and itemID and GetItemCooldown then
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
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
                                MSWA_ClearCooldownFrame(btn.cooldown)
                                btn.icon:SetDesaturated(false)
                                if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                                btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                                MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)
                                MSWA_StopGlow(btn)
                                index = index + 1
                            else
                                if IsItemZeroCount(s, itemID) then
                                    if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                                    foundNextSyntheticWake = QueueSyntheticWakeCandidate(foundNextSyntheticWake, ab.startTime + totalWindow)
                                else
                                    ab.active = false
                                end
                            end

                            if not inBuffPhase then
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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

                                if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                                    foundNextSyntheticWake = QueueSyntheticWakeCandidate(foundNextSyntheticWake, ch.rechargeStart + (tonumber(s.chargeDuration) or 0))
                                end
                                index = index + 1
                            else
                            -- ========== ITEM INSTANCE: NORMAL COOLDOWN MODE ==========
                            if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end

                            if itemID and GetItemCooldown then
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
                            MSWA_CheckSoundTransition(key, onCD, s)

                            if s and s.grayOnCooldown then
                                btn.icon:SetDesaturated(onCD)
                            else
                                btn.icon:SetDesaturated(false)
                            end
                            if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                            -- Empty trinket slot: show dimmed
                            if isTrinket and not itemID then btn.icon:SetDesaturated(true) end

                            btn:SetAlpha(ComputeAlpha(s, onCD, inCombat))

                            local rem = 0
                            if onCD and s then
                                local need = (s.glow and s.glow.enabled) or s.textColor2Enabled
                                    -- icon timer visuals handled by visualTickFrame
                                if need and itemID and GetItemCooldown then
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
                    local canPosition = CanRepositionButton(btn, trackedKey)
                    if canPosition then btn:ClearAllPoints() end
                    if canPosition then PositionButton(btn, s, trackedKey, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                local canPosition = CanRepositionButton(btn, key)
                if canPosition then btn:ClearAllPoints() end

                ApplyStylesIfDirty(btn, db, s, key)

                -- Clean stale overlays from mode switches (zero cost if nil)
                if (not s or s.auraMode ~= "REMINDER_BUFF") and btn._msaReminderLabel then btn._msaReminderLabel:Hide() end
                if (not s or s.auraMode ~= "CHARGES") and btn._msaChargeLabel then btn._msaChargeLabel:Hide() end

                if s and s.auraMode == "BUFF_AURA" then
                    -- ========== ITEM: BUFF AURA (event-driven cache via BuffBridge) ==========
                    local auraData, buffActive = MSWA_ResolveBuffAura(s, itemID)
                    local showMe = buffActive or s.showWhenAbsent or previewMode or key == selectedKey
                    if showMe then
                        if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
                        if buffActive then
                            MSWA_ApplyAuraCooldown(btn.cooldown, auraData)
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
                            foundNextSyntheticWake = QueueSyntheticWakeCandidate(foundNextSyntheticWake, ab.startTime + totalWindow)
                        else
                            ab.active = false
                        end
                    end

                    if inBuffPhase then
                        if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                        if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end

                        if itemID and GetItemCooldown then
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
                        MSWA_CheckSoundTransition(key, onCD, s)

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
                                    -- icon timer visuals handled by visualTickFrame
                            if need and itemID and GetItemCooldown then
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
                        if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
                        MSWA_ClearCooldownFrame(btn.cooldown)
                        btn.icon:SetDesaturated(false)
                        if IsItemZeroCount(s, itemID) then btn.icon:SetDesaturated(true) end
                        btn:SetAlpha(ComputeAlpha(s, false, inCombat))
                        MSWA_UpdateBuffVisual_Fast(btn, s, nil, true, itemID)
                        MSWA_StopGlow(btn)
                        index = index + 1
                    else
                        if IsItemZeroCount(s, itemID) then
                            if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                            foundNextSyntheticWake = QueueSyntheticWakeCandidate(foundNextSyntheticWake, ab.startTime + totalWindow)
                        else
                            ab.active = false
                        end
                    end

                    if not inBuffPhase then
                        if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                        if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                        if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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

                        if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end
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
                            foundNextSyntheticWake = QueueSyntheticWakeCandidate(foundNextSyntheticWake, ch.rechargeStart + (tonumber(s.chargeDuration) or 0))
                        end
                        index = index + 1
                    else
                    -- ========== NORMAL ITEM COOLDOWN MODE ==========
                    if canPosition then PositionButton(btn, s, key, index, frame, ICON_SIZE, ICON_SPACE, db, groupCtx) end

                    if itemID and GetItemCooldown then
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
                    MSWA_CheckSoundTransition(key, onCD, s)

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
                                    -- icon timer visuals handled by visualTickFrame
                        if need and itemID and GetItemCooldown then
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
        for i = 1, index - 1 do
            local btn = icons[i]
            if btn and btn:IsShown() then
                local bkey = btn.spellID
                local bs = bkey and settingsTable[bkey]
                if bs and bs.displayType == "BAR" then
                    local bInfo = btn._msaBarInfo
                    if not bInfo then
                        bInfo = { isActive = true, name = nil, expires = 0, duration = 0, stacks = nil, absentAlpha = 0.45, isSecret = false }
                        btn._msaBarInfo = bInfo
                    else
                        bInfo.isActive = true
                        bInfo.name = nil
                        bInfo.expires = 0
                        bInfo.duration = 0
                        bInfo.stacks = nil
                        bInfo.absentAlpha = 0.45
                        bInfo.isSecret = false
                    end

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
                            -- trinket:SLOT key
                            if MSWA_IsTrinketKey(bkey) then
                                bInfo.name = MSWA_GetDisplayNameForKey(bkey)
                            else
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
                    end
                    if not bInfo.name or bInfo.name == "" then bInfo.name = tostring(bkey) end

                    -- Timing: depends on auraMode
                    local mode = bs.auraMode

                    if mode == "BUFF_AURA" then
                        MSWA_CollectBuffAuraBarInfo(bInfo, bs, bkey, previewMode)

                    elseif mode == "AUTOBUFF" or mode == "BUFF_THEN_CD" then
                        local ab = autoBuff and autoBuff[bkey]
                        if ab and ab.active then
                            local delay = tonumber(bs.autoBuffDelay) or 0
                            local bdur = tonumber(bs.autoBuffDuration) or 10
                            local tStart = ab.startTime + delay
                            bInfo.expires  = tStart + bdur
                            bInfo.duration = bdur
                        elseif mode == "BUFF_THEN_CD" then
                            -- CD phase: spell CD or trinket item CD
                            local numSID = tonumber(bkey)
                            if numSID and C_Spell and C_Spell.GetSpellCooldown then
                                local cdI = C_Spell.GetSpellCooldown(numSID)
                                if cdI and cdI.duration and cdI.duration > 1.5 then
                                    bInfo.expires  = cdI.startTime + cdI.duration
                                    bInfo.duration = cdI.duration
                                end
                            elseif MSWA_IsTrinketKey(bkey) and GetItemCooldown then
                                local slot = MSWA_KeyToTrinketSlot(bkey)
                                local tItemID = slot and MSWA_GetTrinketItemID(slot)
                                if tItemID then
                                    local start, duration = GetItemCooldown(tItemID)
                                    local ok2, isActive = pcall(_itemCDCheck, start, duration)
                                    if ok2 and isActive then
                                        bInfo.expires  = start + duration
                                        bInfo.duration = duration
                                    end
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
                        elseif MSWA_IsTrinketKey(bkey) then
                            -- Trinket item CD
                            local slot = MSWA_KeyToTrinketSlot(bkey)
                            local tItemID = slot and MSWA_GetTrinketItemID(slot)
                            if tItemID and GetItemCooldown then
                                local st, dur = GetItemCooldown(tItemID)
                                if st and dur and dur > 1.5 then
                                    bInfo.expires  = st + dur
                                    bInfo.duration = dur
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

                    -- BAR visuals are driven by MSA_Bars.lua's own lightweight ticker.

                    -- Item count stacks for bar display
                    if not bInfo.stacks and GetItemCount then
                        local iid = tonumber(bkey) == nil and tostring(bkey):match("^item:(%d+)")
                        iid = iid and tonumber(iid)
                        if iid then
                            local cnt = GetItemCount(iid, false, false)
                            if type(cnt) == "number" and cnt > 0 then
                                bInfo.stacks = tostring(cnt)
                            end
                        end
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
    -- 2c) Icon lightweight timer visuals
    -- Bars use MSA_Bars.lua's ticker. Icon-only dynamic visuals
    -- (decimal timer / glow / conditional text color) are queued
    -- here and updated by visualTickFrame without re-running the
    -- full aura engine every 0.1 sec.
    -----------------------------------------------------------
    for i = 1, index - 1 do
        local btn = icons[i]
        if btn and btn:IsShown() then
            local bkey = btn.spellID
            local bs = bkey and (settingsTable[bkey] or settingsTable[tostring(bkey)])
            if bs and bs.displayType ~= "BAR" then
                local cd = btn.cooldown
                local remaining, validTiming = GetStoredCooldownRemaining(cd, now)
                local isOnCooldown = validTiming and remaining > 0
                local needGlow = bs.glow and bs.glow.enabled
                local needText2 = bs.textColor2Enabled and bs.textColor2
                local needDecimal = bs.showDecimal == true

                if isOnCooldown and (needGlow or needText2 or needDecimal) then
                    QueueVisualTick(btn)
                    if needDecimal then
                        ApplyDecimalTimerText(btn, bs, db, remaining)
                    else
                        ClearDecimalTimer(btn)
                    end
                else
                    ClearDecimalTimer(btn)
                end
            else
                ClearDecimalTimer(btn)
            end
        end
    end

    if visualTickCount > 0 then
        visualTickFrame:Show()
    else
        visualTickFrame:Hide()
    end

    -----------------------------------------------------------
    -- 3) Hide remaining buttons
    -----------------------------------------------------------
    local activeCount = index - 1
    for i = index, MAX_ICONS do
        local btn = icons[i]
        if btn.spellID ~= nil or btn:IsShown() then
            local oldKey = btn.spellID
            btn:Hide()
            btn.icon:SetTexture(nil)
            btn._msaCachedKey = nil
            btn._msaStyleKey  = nil
            MSWA_ClearCooldownFrame(btn.cooldown)
            MSWA_StopGlow(btn)
            MSWA_HideReminderLabel(btn)
            MSWA_HideChargeLabel(btn)
            if MSWA_CleanupBar then MSWA_CleanupBar(btn) end
            if btn._msaEssentialAttached and type(MSWA_ApplyEssentialAttachStyle) == "function" then
                MSWA_ApplyEssentialAttachStyle(btn, false)
            end
            RestoreButtonParent(btn, frame, oldKey)
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
    nextSyntheticWake = foundNextSyntheticWake
    -- Full-engine timer ticks were the source of persistent 1ms spikes.
    -- Icon visuals now use visualTickFrame and bars use MSA_Bars.lua.
    needsTimerTick = false
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

    if needsTimerTick and not dirty then
        dirty = true
    end

    local shouldRun = false
    if dirty then
        shouldRun = forceImmediate or (now - lastFullUpdate) >= THROTTLE_INTERVAL
    elseif autoBuffActive then
        local wakeAt = nextSyntheticWake
        if wakeAt and wakeAt > 0 then
            shouldRun = now >= (wakeAt - 0.02)
        else
            shouldRun = (now - lastFullUpdate) >= 0.25
        end
    end

    if shouldRun then
        dirty = false
        forceImmediate = false
        lastFullUpdate = now
        MSWA_UpdateSpells()
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
    if engineFrame:IsShown() or requestPending then return end
    requestPending = true

    local function FlushQueuedRequest()
        requestPending = false
        if dirty or autoBuffActive or needsTimerTick then
            engineFrame:Show()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, FlushQueuedRequest)
    else
        FlushQueuedRequest()
    end
end

function MSWA_ForceUpdateSpells()
    dirty = true
    forceImmediate = true
    requestPending = false
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

--- Invalidate only trinket icon textures (gear swap).
--- Clears cached key on buttons tracking trinket:13 / trinket:14
--- so SetIconTexture refreshes their equipped item texture.
function MSWA_InvalidateTrinketIcons()
    if not MSWA.icons then return end
    for i = 1, MSWA.MAX_ICONS do
        local btn = MSWA.icons[i]
        if btn and MSWA_IsTrinketKey(btn.spellID) then
            btn._msaCachedKey = nil
            btn._msaStyleKey  = nil
        end
    end
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
    else
        mainFrame:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
        mainFrame:UnregisterEvent("PLAYER_TALENT_UPDATE")
        mainFrame:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
        mainFrame:UnregisterEvent("UNIT_INVENTORY_CHANGED")
        mainFrame:UnregisterEvent("BAG_UPDATE_COOLDOWN")
        mainFrame:UnregisterEvent("BAG_UPDATE")
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

        -- Check trackedSpells for item instance keys (item:ID:N) and trinket keys
        if db.trackedSpells then
            for trackedKey, enabled in pairs(db.trackedSpells) do
                if enabled then
                    local itemID
                    if MSWA_IsItemKey(trackedKey) then
                        itemID = MSWA_KeyToItemID(trackedKey)
                    elseif MSWA_IsTrinketKey(trackedKey) then
                        local slot = MSWA_KeyToTrinketSlot(trackedKey)
                        itemID = slot and MSWA_GetTrinketItemID(slot)
                    end
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
