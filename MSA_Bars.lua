-- ########################################################
-- MSA_Bars.lua  v2 - Progress Bar Display
--
-- Layout options:
--   barShowIcon  = true/false
--   barIconPos   = "LEFT" / "RIGHT" / "TOP" / "BOTTOM"
--   barFillDir   = "LR" / "RL" / "BT" / "TB"
--     TB/BT -> vertical bar (btn width/height swap)
--
-- Secret-safe: issecretvalue guards on all timing reads.
-- ########################################################

local GetTime = GetTime
local type, tonumber = type, tonumber

-----------------------------------------------------------
-- Defaults
-----------------------------------------------------------

local DEF_W    = 200
local DEF_H    = 22
local DEF_TEX  = "Interface\\TargetingFrame\\UI-StatusBar"
local SPARK_W  = 14

-----------------------------------------------------------
-- Visible bars + 60fps ticker
-----------------------------------------------------------

local visBars  = {}
local barCount = 0
local ticker   = CreateFrame("Frame", "MSWA_BarTicker", UIParent)
ticker:Hide()

ticker:SetScript("OnUpdate", function(self)
    local now = GetTime()
    local any = false

    for btn in pairs(visBars) do
        local bd = btn._msaBar
        if bd and bd.frame and bd.frame:IsShown() then
            any = true
            local exp, dur = bd._exp or 0, bd._dur or 0
            if dur > 0 and exp > 0 then
                local rem = exp - now
                if rem < 0 then rem = 0 end
                local pct = rem / dur
                if pct > 1 then pct = 1 end

                bd.bar:SetValue(pct)

                -- Spark
                if bd.spark and bd._showSpark then
                    if pct > 0.01 and pct < 0.99 then
                        bd.spark:ClearAllPoints()
                        if bd._isVert then
                            -- Vertical: spark along Y
                            local h = bd.bar:GetHeight()
                            if bd._reversed then
                                -- TB: fills top->bottom, spark moves down
                                bd.spark:SetPoint("CENTER", bd.bar, "TOP", 0, -(h * pct))
                            else
                                -- BT: fills bottom->top, spark moves up
                                bd.spark:SetPoint("CENTER", bd.bar, "BOTTOM", 0, h * pct)
                            end
                        else
                            -- Horizontal
                            local w = bd.bar:GetWidth()
                            if bd._reversed then
                                -- RL: fills right->left, spark moves left
                                bd.spark:SetPoint("CENTER", bd.bar, "RIGHT", -(w * pct), 0)
                            else
                                -- LR: fills left->right
                                bd.spark:SetPoint("CENTER", bd.bar, "LEFT", w * pct, 0)
                            end
                        end
                        bd.spark:Show()
                    else
                        bd.spark:Hide()
                    end
                elseif bd.spark then
                    bd.spark:Hide()
                end
                if bd.timerFS and bd._showTimer then
                    bd.timerFS:SetText(MSWA_FormatTimer(rem, bd._showDecimal))
                end

                -- Conditional text color (matches icon system tc2)
                if bd._tc2Enabled and bd.timerFS then
                    local condActive = false
                    if bd._tc2Cond == "TIMER_BELOW" then
                        condActive = rem <= bd._tc2Val and rem > 0
                    elseif bd._tc2Cond == "TIMER_ABOVE" then
                        condActive = rem >= bd._tc2Val
                    end
                    if condActive then
                        bd.timerFS:SetTextColor(bd._tc2R, bd._tc2G, bd._tc2B, 1)
                    else
                        bd.timerFS:SetTextColor(bd._baseTextR or 1, bd._baseTextG or 1, bd._baseTextB or 1, 1)
                    end
                end
            else
                bd.bar:SetValue(1)
                if bd.spark then bd.spark:Hide() end
                if bd.timerFS then bd.timerFS:SetText("") end
            end
        else
            visBars[btn] = nil
            barCount = barCount - 1
        end
    end
    if not any then barCount = 0; self:Hide() end
end)

-----------------------------------------------------------
-- EnsureBar: create elements (no anchoring - done in Layout)
-----------------------------------------------------------

function MSWA_EnsureBar(btn)
    if btn._msaBar then return btn._msaBar end

    local bd = { _exp = 0, _dur = 0, _showTimer = true, _isVert = false, _reversed = false }

    local f = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    f:SetAllPoints(btn)
    f:SetFrameLevel(btn:GetFrameLevel() + 2)
    bd.frame = f

    -- Border + BG
    bd.border = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    bd.border:SetPoint("TOPLEFT", -1, 1)
    bd.border:SetPoint("BOTTOMRIGHT", 1, -1)
    bd.border:SetColorTexture(0, 0, 0, 0.95)

    bd.bg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    bd.bg:SetAllPoints(f)
    bd.bg:SetColorTexture(0.06, 0.06, 0.06, 0.85)

    -- Icon elements (positioned in Layout)
    bd.iconBG = f:CreateTexture(nil, "ARTWORK")
    bd.iconBG:SetColorTexture(0, 0, 0, 0.9)

    bd.iconTex = f:CreateTexture(nil, "ARTWORK", nil, 1)
    bd.iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- StatusBar (positioned in Layout)
    bd.bar = CreateFrame("StatusBar", nil, f)
    bd.bar:SetMinMaxValues(0, 1)
    bd.bar:SetValue(1)
    bd.bar:SetStatusBarTexture(DEF_TEX)
    bd.bar:SetStatusBarColor(0.9, 0.7, 0.0)

    bd.barBG = bd.bar:CreateTexture(nil, "BACKGROUND")
    bd.barBG:SetAllPoints()
    bd.barBG:SetTexture(DEF_TEX)
    bd.barBG:SetVertexColor(0.12, 0.12, 0.12, 0.7)

    -- Spark
    bd.spark = bd.bar:CreateTexture(nil, "OVERLAY")
    bd.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    bd.spark:SetBlendMode("ADD")
    bd.spark:Hide()

    -- Name text
    bd.nameFS = bd.bar:CreateFontString(nil, "OVERLAY")
    bd.nameFS:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    bd.nameFS:SetWordWrap(false)

    -- Timer text
    bd.timerFS = bd.bar:CreateFontString(nil, "OVERLAY")
    bd.timerFS:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")

    -- Stack text
    bd.stackFS = f:CreateFontString(nil, "OVERLAY")
    bd.stackFS:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    bd.stackFS:SetJustifyH("RIGHT")
    bd.stackFS:SetTextColor(1, 0.82, 0)
    bd.stackFS:Hide()

    f:Hide()
    btn._msaBar = bd
    return bd
end

-----------------------------------------------------------
-- Layout: position icon + bar based on settings
-- Called every ApplyStyle (settings may have changed)
-----------------------------------------------------------

local function ApplyLayout(bd, s)
    local showIcon = (s.barShowIcon ~= false)
    local iconPos  = s.barIconPos or "LEFT"
    local fillDir  = s.barFillDir or "LR"
    local isVert   = (fillDir == "TB" or fillDir == "BT")
    local reversed = (fillDir == "RL" or fillDir == "TB")

    bd._isVert   = isVert
    bd._reversed = reversed

    local bw = tonumber(s.barWidth)  or DEF_W
    local bh = tonumber(s.barHeight) or DEF_H

    -- For vertical bars: swap so barWidth = narrow, barHeight = tall
    local btnW, btnH
    if isVert then
        btnW = bh   -- narrow dimension
        btnH = bw   -- tall dimension
    else
        btnW = bw
        btnH = bh
    end
    bd._btnW = btnW
    bd._btnH = btnH

    -- Icon size
    local pad  = 2
    local icoSz
    if isVert then
        icoSz = btnW - (pad * 2)
    else
        icoSz = btnH - (pad * 2)
    end
    if icoSz < 4 then icoSz = 4 end

    -- Clear all dynamic anchors
    bd.iconTex:ClearAllPoints()
    bd.iconBG:ClearAllPoints()
    bd.bar:ClearAllPoints()
    bd.nameFS:ClearAllPoints()
    bd.timerFS:ClearAllPoints()
    bd.stackFS:ClearAllPoints()

    -- StatusBar orientation + fill
    if isVert then
        bd.bar:SetOrientation("VERTICAL")
    else
        bd.bar:SetOrientation("HORIZONTAL")
    end
    if bd.bar.SetReverseFill then
        bd.bar:SetReverseFill(reversed)
    end

    -- Icon
    if showIcon then
        bd.iconTex:SetSize(icoSz, icoSz)
        bd.iconBG:SetSize(icoSz + 2, icoSz + 2)
        bd.iconTex:Show()
        bd.iconBG:Show()

        local f = bd.frame
        if iconPos == "RIGHT" then
            bd.iconTex:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -pad)
            bd.iconBG:SetPoint("CENTER", bd.iconTex, "CENTER", 0, 0)
            bd.bar:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -(pad+1))
            bd.bar:SetPoint("BOTTOMRIGHT", bd.iconTex, "BOTTOMLEFT", -3, -1)
        elseif iconPos == "TOP" then
            bd.iconTex:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad)
            bd.iconBG:SetPoint("CENTER", bd.iconTex, "CENTER", 0, 0)
            bd.bar:SetPoint("TOPLEFT", bd.iconTex, "BOTTOMLEFT", -1, -3)
            bd.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad)
        elseif iconPos == "BOTTOM" then
            bd.iconTex:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", pad, pad)
            bd.iconBG:SetPoint("CENTER", bd.iconTex, "CENTER", 0, 0)
            bd.bar:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -(pad+1))
            bd.bar:SetPoint("BOTTOMRIGHT", bd.iconTex, "TOPRIGHT", 1, 3)
        else -- LEFT (default)
            bd.iconTex:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad)
            bd.iconBG:SetPoint("CENTER", bd.iconTex, "CENTER", 0, 0)
            bd.bar:SetPoint("TOPLEFT", bd.iconTex, "TOPRIGHT", 3, -1)
            bd.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad)
        end

        bd.stackFS:SetPoint("BOTTOMRIGHT", bd.iconTex, "BOTTOMRIGHT", 0, 0)
    else
        -- No icon
        bd.iconTex:Hide()
        bd.iconBG:Hide()
        bd.bar:SetPoint("TOPLEFT", bd.frame, "TOPLEFT", pad, -(pad+1))
        bd.bar:SetPoint("BOTTOMRIGHT", bd.frame, "BOTTOMRIGHT", -pad, pad)
        bd.stackFS:SetPoint("BOTTOMRIGHT", bd.bar, "BOTTOMRIGHT", -2, 2)
    end

    -- Spark size
    if bd.spark then
        if isVert then
            bd.spark:SetSize(btnW * 1.6, SPARK_W)
            -- Rotate spark for vertical (90deg)
            bd.spark:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
        else
            bd.spark:SetSize(SPARK_W, btnH * 1.6)
            bd.spark:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1) -- default
        end
    end

    -- Text anchoring
    if isVert then
        -- Vertical: name top, timer bottom (both centered)
        bd.nameFS:SetPoint("TOP", bd.bar, "TOP", 0, -3)
        bd.nameFS:SetPoint("LEFT", bd.bar, "LEFT", 2, 0)
        bd.nameFS:SetPoint("RIGHT", bd.bar, "RIGHT", -2, 0)
        bd.nameFS:SetJustifyH("CENTER")

        bd.timerFS:SetPoint("BOTTOM", bd.bar, "BOTTOM", 0, 3)
        bd.timerFS:SetJustifyH("CENTER")
    else
        -- Horizontal: name left, timer right
        bd.nameFS:SetPoint("LEFT", bd.bar, "LEFT", 4, 0)
        bd.nameFS:SetPoint("RIGHT", bd.bar, "RIGHT", -45, 0)
        bd.nameFS:SetJustifyH("LEFT")

        bd.timerFS:SetPoint("RIGHT", bd.bar, "RIGHT", -4, 0)
        bd.timerFS:SetJustifyH("RIGHT")
    end
end

-----------------------------------------------------------
-- ApplyStyle: colors, font, texture + layout
-----------------------------------------------------------

local function ApplyStyle(bd, s, db)
    -- Layout first (sets orientation, anchors, sizes)
    ApplyLayout(bd, s)

    -- BG
    bd.bg:SetColorTexture(0.06, 0.06, 0.06, tonumber(s.barBgAlpha) or 0.85)

    -- Texture MUST be set BEFORE color (SetStatusBarTexture
    -- replaces the fill region and can reset vertex color)
    local tex = s.barTexture or DEF_TEX
    bd.bar:SetStatusBarTexture(tex)
    bd.barBG:SetTexture(tex)

    -- Re-assert MinMaxValues after orientation change
    bd.bar:SetMinMaxValues(0, 1)

    -- Color (AFTER texture so it sticks)
    local c = s.barColor
    if c and type(c) == "table" then
        bd.bar:SetStatusBarColor(c.r or 0.9, c.g or 0.7, c.b or 0.0, c.a or 1)
    else
        bd.bar:SetStatusBarColor(0.9, 0.7, 0.0)
    end

    -- Toggles
    bd._showTimer = (s.barShowTimer ~= false)
    bd._showSpark = (s.barShowSpark ~= false)
    bd._showDecimal = (s.showDecimal == true)
    if bd.timerFS then if bd._showTimer then bd.timerFS:Show() else bd.timerFS:Hide() end end
    if bd.nameFS then if s.barShowName ~= false then bd.nameFS:Show() else bd.nameFS:Hide() end end

    -- Font: same resolution chain as icon text system
    -- Face: per-aura textFontKey -> global fontKey -> DEFAULT
    local fontKey = (s and s.textFontKey) or (db and db.fontKey) or "DEFAULT"
    local fp = MSWA_GetFontPathFromKey and MSWA_GetFontPathFromKey(fontKey) or STANDARD_TEXT_FONT
    -- Size: barFontSize (explicit override) -> textFontSize -> db.textFontSize -> 12
    local fs = tonumber(s.barFontSize) or tonumber(s.textFontSize) or tonumber(db and db.textFontSize) or 12
    -- Vertical bars with narrow width: smaller font
    if bd._isVert and (bd._btnW or 22) < 30 then
        fs = fs - 2
        if fs < 7 then fs = 7 end
    end
    bd.nameFS:SetFont(fp, fs, "OUTLINE")
    bd.timerFS:SetFont(fp, fs, "OUTLINE")

    -- Stack font: stackFontKey -> fontKey -> DEFAULT, stackFontSize -> 10
    if bd.stackFS then
        local sfk = (s and s.stackFontKey) or (db and db.stackFontKey) or (db and db.fontKey) or "DEFAULT"
        local sfp = MSWA_GetFontPathFromKey and MSWA_GetFontPathFromKey(sfk) or fp
        local sfs = tonumber(s and s.stackFontSize) or tonumber(db and db.stackFontSize) or 10
        if sfs < 6 then sfs = 6 elseif sfs > 48 then sfs = 48 end
        bd.stackFS:SetFont(sfp, sfs, "OUTLINE")
        local sc = (s and s.stackColor) or (db and db.stackColor)
        if sc then
            bd.stackFS:SetTextColor(tonumber(sc.r) or 1, tonumber(sc.g) or 0.82, tonumber(sc.b) or 0, 1)
        end
    end

    -- Text color: same chain as icon system (textColor per-aura -> global)
    local tc = (s and s.textColor) or (db and db.textColor)
    local tr, tg, tb = 1, 1, 1
    if tc then tr = tonumber(tc.r) or 1; tg = tonumber(tc.g) or 1; tb = tonumber(tc.b) or 1 end
    bd.nameFS:SetTextColor(tr, tg, tb, 1)
    bd.timerFS:SetTextColor(tr, tg, tb, 1)

    -- Store for conditional coloring updates from ticker
    bd._baseTextR = tr
    bd._baseTextG = tg
    bd._baseTextB = tb

    -- Conditional text color 2 config (cached for ticker use)
    if s and s.textColor2Enabled and s.textColor2 then
        bd._tc2Enabled = true
        bd._tc2Cond = s.textColor2Cond or "TIMER_BELOW"
        bd._tc2Val  = tonumber(s.textColor2Value) or 5
        bd._tc2R = tonumber(s.textColor2.r) or 1
        bd._tc2G = tonumber(s.textColor2.g) or 0
        bd._tc2B = tonumber(s.textColor2.b) or 0
    else
        bd._tc2Enabled = false
    end
end

-----------------------------------------------------------
-- ShowBar
-----------------------------------------------------------

local function ShowBar(btn, bd, s, db)
    ApplyStyle(bd, s, db)

    -- Resize btn (layout already computed dimensions)
    btn:SetSize(bd._btnW or DEF_W, bd._btnH or DEF_H)

    -- Copy texture
    local tex = btn.icon:GetTexture()
    if tex then bd.iconTex:SetTexture(tex) end

    -- Hide icon-mode elements
    btn.icon:SetAlpha(0)
    if btn.cooldown then
        btn.cooldown:SetAlpha(0)
        if btn.cooldown.SetHideCountdownNumbers then btn.cooldown:SetHideCountdownNumbers(true) end
    end
    if btn.count then btn.count:Hide() end
    if btn.stackText then btn.stackText:Hide() end
    if btn.border then btn.border:SetAlpha(0) end

    bd.frame:Show()

    if not visBars[btn] then
        visBars[btn] = true
        barCount = barCount + 1
    end
    ticker:Show()
end

-----------------------------------------------------------
-- MSWA_HideBar / CleanupBar / IsBarMode
-----------------------------------------------------------

function MSWA_HideBar(btn)
    local bd = btn._msaBar
    if bd and bd.frame then bd.frame:Hide() end

    if visBars[btn] then
        visBars[btn] = nil
        barCount = barCount - 1
        if barCount <= 0 then barCount = 0; ticker:Hide() end
    end

    btn.icon:SetAlpha(1)
    if btn.cooldown then
        btn.cooldown:SetAlpha(1)
        if btn.cooldown.SetHideCountdownNumbers then btn.cooldown:SetHideCountdownNumbers(false) end
    end
    if btn.border then btn.border:SetAlpha(1) end
end

function MSWA_CleanupBar(btn)
    if btn._msaBar then MSWA_HideBar(btn) end
end

function MSWA_IsBarMode(s)
    return s and s.displayType == "BAR"
end

-----------------------------------------------------------
-- MSWA_UpdateBarDisplay
-----------------------------------------------------------

function MSWA_UpdateBarDisplay(btn, s, db, info)
    if not MSWA_IsBarMode(s) then
        if btn._msaBar and btn._msaBar.frame and btn._msaBar.frame:IsShown() then
            MSWA_HideBar(btn)
        end
        return false
    end

    local bd = MSWA_EnsureBar(btn)
    ShowBar(btn, bd, s, db)

    if bd.nameFS then bd.nameFS:SetText(info.name or "") end

    if info.isActive ~= false then
        bd.frame:SetAlpha(btn:GetAlpha())
        if info.isSecret then
            bd._exp = 0; bd._dur = 0
        else
            local e = tonumber(info.expires) or 0
            local d = tonumber(info.duration) or 0
            if d > 0 and e > 0 then
                bd._exp = e; bd._dur = d
            else
                bd._exp = 0; bd._dur = 0
            end
        end
        bd.iconTex:SetDesaturated(false)
        bd.iconTex:SetAlpha(1)
        bd.bar:SetAlpha(1)
        bd.barBG:SetAlpha(0.7)
    else
        bd._exp = 0; bd._dur = 0
        bd.iconTex:SetDesaturated(true)
        bd.iconTex:SetAlpha(0.6)
        bd.bar:SetValue(0)
        bd.bar:SetAlpha(0.3)
        bd.barBG:SetAlpha(0.3)
        if bd.spark then bd.spark:Hide() end
        if bd.timerFS then bd.timerFS:SetText("") end
        bd.frame:SetAlpha(tonumber(info.absentAlpha) or 0.45)
    end

    if bd.stackFS then
        if info.stacks and info.stacks ~= "" then
            bd.stackFS:SetText(info.stacks); bd.stackFS:Show()
        else
            bd.stackFS:SetText(""); bd.stackFS:Hide()
        end
    end

    return true
end
