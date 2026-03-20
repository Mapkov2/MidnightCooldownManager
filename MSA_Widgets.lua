-- ########################################################
-- MSA_Widgets.lua  v2.0
-- MSUF/PeelDamage Midnight themed widget library for MSA
-- Superellipse pill shapes, dark theme, custom controls
-- ########################################################
local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local math_floor, math_max, math_min = math.floor, math.max, math.min
local tinsert = table.insert

MSWA_W = {}
local W = MSWA_W

-- ════════════════════════════════════════════════════════
-- THEME (exact MSUF midnight colors)
-- ════════════════════════════════════════════════════════

local T = {
    bgR = 0.03,  bgG = 0.05,  bgB = 0.12,  bgA = 0.95,
    edgeR = 0.10, edgeG = 0.20, edgeB = 0.45, edgeA = 0.90,
    titleR = 0.75, titleG = 0.88, titleB = 1.00, titleA = 1.00,
    textR = 0.86,  textG = 0.92,  textB = 1.00,  textA = 1.00,
    mutedR = 0.55, mutedG = 0.60, mutedB = 0.68, mutedA = 0.85,
    accentR = 0.30, accentG = 0.60, accentB = 1.00,
    warnR = 1.00,  warnG = 0.40,  warnB = 0.20,
    successR = 0.30, successG = 0.90, successB = 0.40,
}
W.Theme = T

local pillEdgeR = math_min(1, T.edgeR * 1.25)
local pillEdgeG = math_min(1, T.edgeG * 1.25)
local pillEdgeB = math_min(1, T.edgeB * 1.18)
local pillEdgeA = math_min(1, T.edgeA + 0.05)

-- ── Textures ────────────────────────────────────────────
local ADDON_PATH = "Interface\\AddOns\\MidnightSimpleAuras\\"
local SE_TEX     = ADDON_PATH .. "Media\\superellipse.tga"
local CHECK_HOLE = ADDON_PATH .. "Media\\check_hole.tga"
local CHECK_TICK = ADDON_PATH .. "Media\\check_tick.tga"

-- ── Utility ─────────────────────────────────────────────
local function clamp(v, lo, hi) return v < lo and lo or v > hi and hi or v end
W.clamp = clamp

local function LeftJustify(btn, pad)
    pad = pad or 10
    local fs = btn.GetFontString and btn:GetFontString()
    if not fs then return end
    fs:SetJustifyH("LEFT")
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", btn, "LEFT", pad, 0)
    fs:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
end

local function ApplyReadableFont(fs, sizeDelta, forceFlags)
    if not fs then return end
    local ok, font, size, flags = pcall(fs.GetFont, fs)
    if ok and font and size then
        local baseFont = fs._MSWAReadableBaseFont or font
        local baseSize = fs._MSWAReadableBaseSize
        local baseFlags = fs._MSWAReadableBaseFlags

        if not baseSize then
            baseSize = size or 12
            baseFlags = flags or ""
            fs._MSWAReadableBaseFont = baseFont
            fs._MSWAReadableBaseSize = baseSize
            fs._MSWAReadableBaseFlags = baseFlags
        end

        local delta = sizeDelta or 0
        local targetSize = math_max(8, math_floor((baseSize or 12) + delta + 0.5))
        local targetFlags = forceFlags or baseFlags or ""

        if fs._MSWAReadableAppliedSize ~= targetSize or fs._MSWAReadableAppliedFont ~= baseFont or fs._MSWAReadableAppliedFlags ~= targetFlags then
            fs:SetFont(baseFont, targetSize, targetFlags)
            fs._MSWAReadableAppliedFont = baseFont
            fs._MSWAReadableAppliedSize = targetSize
            fs._MSWAReadableAppliedFlags = targetFlags
        end
    end
    if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 0.95) end
    if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
end
W.ApplyReadableFont = ApplyReadableFont

-- ════════════════════════════════════════════════════════
-- SUPERELLIPSE (3-part pill shape, MSUF implementation)
-- ════════════════════════════════════════════════════════

local function CreateSuperellipseLayers(btn, inset)
    if not btn or not btn.CreateTexture then return nil, nil end
    inset = inset or 2

    local fill = {}
    fill.L = btn:CreateTexture(nil, "ARTWORK", nil, 0)
    fill.M = btn:CreateTexture(nil, "ARTWORK", nil, 0)
    fill.R = btn:CreateTexture(nil, "ARTWORK", nil, 0)
    fill.L:SetTexture(SE_TEX); fill.L:SetTexCoord(0.0, 0.25, 0.0, 1.0)
    fill.M:SetTexture(SE_TEX); fill.M:SetTexCoord(0.25, 0.75, 0.0, 1.0)
    fill.R:SetTexture(SE_TEX); fill.R:SetTexCoord(0.75, 1.0, 0.0, 1.0)

    local h = btn:GetHeight() or 22
    local capW = math_max(4, math_floor(h * 0.5))
    fill.L:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
    fill.L:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", inset, inset)
    fill.L:SetWidth(capW)
    fill.R:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -inset, -inset)
    fill.R:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
    fill.R:SetWidth(capW)
    fill.M:SetPoint("TOPLEFT", fill.L, "TOPRIGHT")
    fill.M:SetPoint("BOTTOMRIGHT", fill.R, "BOTTOMLEFT")

    fill._parts = { fill.L, fill.M, fill.R }
    fill.SetVertexColor = function(self, r, g, b, a) for _, p in ipairs(self._parts) do p:SetVertexColor(r, g, b, a) end end
    fill.Hide = function(self) for _, p in ipairs(self._parts) do p:Hide() end end
    fill.Show = function(self) for _, p in ipairs(self._parts) do p:Show() end end
    fill.SetAlpha = function(self, a) for _, p in ipairs(self._parts) do p:SetAlpha(a) end end

    local border = {}
    border.L = btn:CreateTexture(nil, "ARTWORK", nil, -1)
    border.M = btn:CreateTexture(nil, "ARTWORK", nil, -1)
    border.R = btn:CreateTexture(nil, "ARTWORK", nil, -1)
    border.L:SetTexture(SE_TEX); border.L:SetTexCoord(0.0, 0.25, 0.0, 1.0)
    border.M:SetTexture(SE_TEX); border.M:SetTexCoord(0.25, 0.75, 0.0, 1.0)
    border.R:SetTexture(SE_TEX); border.R:SetTexCoord(0.75, 1.0, 0.0, 1.0)

    local bInset = math_max(0, inset - 1)
    border.L:SetPoint("TOPLEFT", btn, "TOPLEFT", bInset, -bInset)
    border.L:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", bInset, bInset)
    border.L:SetWidth(capW + 1)
    border.R:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -bInset, -bInset)
    border.R:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -bInset, bInset)
    border.R:SetWidth(capW + 1)
    border.M:SetPoint("TOPLEFT", border.L, "TOPRIGHT")
    border.M:SetPoint("BOTTOMRIGHT", border.R, "BOTTOMLEFT")

    border._parts = { border.L, border.M, border.R }
    border.SetVertexColor = function(self, r, g, b, a) for _, p in ipairs(self._parts) do p:SetVertexColor(r, g, b, a) end end

    return fill, border
end
W.CreateSuperellipseLayers = CreateSuperellipseLayers

-- ════════════════════════════════════════════════════════
-- BACKDROP
-- ════════════════════════════════════════════════════════

function W.ApplyBackdrop(frame, alphaOverride)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(T.bgR, T.bgG, T.bgB, alphaOverride or T.bgA)
    frame:SetBackdropBorderColor(T.edgeR, T.edgeG, T.edgeB, T.edgeA)
end

-- ════════════════════════════════════════════════════════
-- TEXT HELPERS
-- ════════════════════════════════════════════════════════

function W.SkinTitle(fs) if fs then fs:SetTextColor(T.titleR, T.titleG, T.titleB, T.titleA); ApplyReadableFont(fs, 1) end end
function W.SkinText(fs)  if fs then fs:SetTextColor(T.textR, T.textG, T.textB, T.textA); ApplyReadableFont(fs, 1) end end
function W.SkinMuted(fs) if fs then fs:SetTextColor(T.mutedR, T.mutedG, T.mutedB, T.mutedA); ApplyReadableFont(fs, 1) end end

function W.Title(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 12, y or -10)
    fs:SetText(text or ""); W.SkinTitle(fs); return fs
end

function W.Label(parent, text, anchor, relFrame, relPoint, x, y, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint(anchor or "TOPLEFT", relFrame or parent, relPoint or "TOPLEFT", x or 0, y or 0)
    fs:SetText(text or ""); W.SkinText(fs); return fs
end

function W.MutedLabel(parent, text, anchor, relFrame, relPoint, x, y)
    local fs = W.Label(parent, text, anchor, relFrame, relPoint, x, y, "GameFontHighlightSmall")
    W.SkinMuted(fs); return fs
end

function W.SectionHeader(parent, text, relFrame, yOffset)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", relFrame or parent, relFrame and "BOTTOMLEFT" or "TOPLEFT", 0, yOffset or -16)
    label:SetText(text or ""); W.SkinTitle(label)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    line:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    line:SetColorTexture(T.edgeR, T.edgeG, T.edgeB, 0.3)
    return label, line
end

function W.Divider(parent, x1, y, x2)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", x1 or 0, y or 0)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x2 or 0, y or 0)
    line:SetColorTexture(T.edgeR, T.edgeG, T.edgeB, 0.4); return line
end

-- ════════════════════════════════════════════════════════
-- TOOLTIP
-- ════════════════════════════════════════════════════════

function W.AddTooltip(widget, title, body)
    if not widget or not widget.HookScript then return end
    widget:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title then GameTooltip:SetText(title, 1, 1, 1) end
        if body  then GameTooltip:AddLine(body, 0.80, 0.86, 1.00, true) end
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ════════════════════════════════════════════════════════
-- BUTTON (Midnight superellipse pill)
-- ════════════════════════════════════════════════════════

function W.Button(parent, text, w, h, onClick, tipTitle, tipBody)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w or 120, h or 24)
    if text then btn:SetText(text) end

    if btn.Left   then btn.Left:Hide() end
    if btn.Middle then btn.Middle:Hide() end
    if btn.Right  then btn.Right:Hide() end
    for _, r in pairs({ btn:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" and r.GetTexture then
            local tex = r:GetTexture()
            if type(tex) == "string" and (tex:find("UI%-Panel%-Button") or tex:find("UIPanelButton")) then r:SetAlpha(0); r:Hide() end
        end
    end
    pcall(function()
        local nt = btn:GetNormalTexture();  if nt then nt:SetAlpha(0) end; btn:SetNormalTexture(nil)
        local pt = btn:GetPushedTexture();  if pt then pt:SetAlpha(0) end; btn:SetPushedTexture(nil)
    end)

    local fill, border = CreateSuperellipseLayers(btn, 1)
    fill:SetVertexColor(T.bgR + 0.04, T.bgG + 0.04, T.bgB + 0.04, 0.95)
    border:SetVertexColor(pillEdgeR, pillEdgeG, pillEdgeB, pillEdgeA)
    btn._fill = fill; btn._border = border

    local fs = btn:GetFontString()
    if fs then fs:SetTextColor(T.textR, T.textG, T.textB, T.textA); ApplyReadableFont(fs, 1) end

    btn:SetScript("OnEnter", function(self)
        if self._fill then self._fill:SetVertexColor(0.10, 0.15, 0.25, 0.98) end
        if self._border then self._border:SetVertexColor(T.accentR, T.accentG, T.accentB, 1) end
    end)
    btn:SetScript("OnLeave", function(self)
        if self._fill then self._fill:SetVertexColor(T.bgR + 0.04, T.bgG + 0.04, T.bgB + 0.04, 0.95) end
        if self._border then self._border:SetVertexColor(pillEdgeR, pillEdgeG, pillEdgeB, pillEdgeA) end
    end)
    if onClick then btn:SetScript("OnClick", onClick) end
    if tipTitle then W.AddTooltip(btn, tipTitle, tipBody) end
    return btn
end

-- ════════════════════════════════════════════════════════
-- NAV BUTTON (sidebar/vertical tab navigation)
-- ════════════════════════════════════════════════════════

function W.NavButton(parent, text, w, h, isChild, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w or 130, h or 22)
    if text then btn:SetText(text) end
    LeftJustify(btn, isChild and 16 or 10)

    for _, key in ipairs({ "Left", "Middle", "Right" }) do if btn[key] then btn[key]:Hide() end end
    pcall(function()
        local nt = btn:GetNormalTexture();  if nt then nt:SetAlpha(0) end; btn:SetNormalTexture(nil)
        local pt = btn:GetPushedTexture();  if pt then pt:SetAlpha(0) end; btn:SetPushedTexture(nil)
        local ht = btn:GetHighlightTexture(); if ht then ht:SetAlpha(0) end; btn:SetHighlightTexture(nil)
        local dt = btn:GetDisabledTexture(); if dt then dt:SetAlpha(0) end; btn:SetDisabledTexture(nil)
    end)

    local fill, border = CreateSuperellipseLayers(btn, 2)
    fill:SetVertexColor(0.09, 0.10, 0.12, isChild and 0.82 or 0.92)
    border:SetVertexColor(pillEdgeR, pillEdgeG, pillEdgeB, 0.80)
    btn._fill = fill; btn._border = border; btn._isActive = false

    local active = {}
    active.L = btn:CreateTexture(nil, "ARTWORK", nil, 2)
    active.M = btn:CreateTexture(nil, "ARTWORK", nil, 2)
    active.R = btn:CreateTexture(nil, "ARTWORK", nil, 2)
    active.L:SetTexture(SE_TEX); active.L:SetTexCoord(0.0, 0.25, 0.0, 1.0); active.L:SetAllPoints(fill.L)
    active.M:SetTexture(SE_TEX); active.M:SetTexCoord(0.25, 0.75, 0.0, 1.0); active.M:SetAllPoints(fill.M)
    active.R:SetTexture(SE_TEX); active.R:SetTexCoord(0.75, 1.0, 0.0, 1.0); active.R:SetAllPoints(fill.R)
    active._parts = { active.L, active.M, active.R }
    for _, p in ipairs(active._parts) do p:SetVertexColor(0.16, 0.36, 0.80, 0.55); p:Hide() end
    btn._active = active

    local fs = btn:GetFontString()
    if fs then fs:SetTextColor(isChild and 0.80 or 0.82, isChild and 0.88 or 0.90, 1.00, isChild and 0.92 or 1.00); ApplyReadableFont(fs, 1) end

    function btn:SetActive(val)
        self._isActive = val
        local fs2 = self:GetFontString()
        if val then
            for _, p in ipairs(self._active._parts) do p:Show() end
            self._fill:SetVertexColor(0.12, 0.22, 0.40, 0.98)
            self._border:SetVertexColor(T.accentR, T.accentG, T.accentB, 1)
            if fs2 then fs2:SetTextColor(0.92, 0.96, 1.00, 1.00); ApplyReadableFont(fs2, 1) end
        else
            for _, p in ipairs(self._active._parts) do p:Hide() end
            self._fill:SetVertexColor(0.09, 0.10, 0.12, isChild and 0.82 or 0.92)
            self._border:SetVertexColor(pillEdgeR, pillEdgeG, pillEdgeB, 0.80)
            if fs2 then fs2:SetTextColor(isChild and 0.80 or 0.82, isChild and 0.88 or 0.90, 1.00, isChild and 0.92 or 1.00); ApplyReadableFont(fs2, 1) end
        end
    end

    btn:SetScript("OnEnter", function(self)
        if self._isActive then return end
        self._fill:SetVertexColor(0.10, 0.11, 0.13, 0.99)
        self._border:SetVertexColor(0.22, 0.45, 0.90, 0.95)
    end)
    btn:SetScript("OnLeave", function(self)
        if self._isActive then return end
        self._fill:SetVertexColor(0.09, 0.10, 0.12, isChild and 0.82 or 0.92)
        self._border:SetVertexColor(pillEdgeR, pillEdgeG, pillEdgeB, 0.80)
    end)
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

-- ════════════════════════════════════════════════════════
-- CHECKBOX (superellipse themed tick)
-- ════════════════════════════════════════════════════════

function W.Checkbox(parent, text, getValue, setValue, tipTitle, tipBody)
    local size = 18
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size + 6 + (text and 220 or 0), size + 4)
    frame:EnableMouse(true)

    local box = frame:CreateTexture(nil, "ARTWORK")
    box:SetPoint("LEFT", frame, "LEFT", 0, 0)
    box:SetSize(size, size); box:SetTexture(CHECK_HOLE)
    box:SetVertexColor(0.12, 0.14, 0.20, 0.95)

    local tick = frame:CreateTexture(nil, "OVERLAY")
    tick:SetPoint("CENTER", box, "CENTER", 0, 0)
    tick:SetSize(size - 2, size - 2); tick:SetTexture(CHECK_TICK)
    tick:SetVertexColor(T.accentR, T.accentG, T.accentB, 1)

    local label
    if text then
        label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", box, "RIGHT", 6, 0)
        label:SetText(text); W.SkinText(label)
    end
    frame._box = box; frame._tick = tick; frame._label = label; frame._checked = false

    function frame:SetChecked(val)
        self._checked = val and true or false
        if self._checked then self._tick:Show(); self._box:SetVertexColor(0.15, 0.25, 0.50, 0.98)
        else self._tick:Hide(); self._box:SetVertexColor(0.12, 0.14, 0.20, 0.95) end
    end
    function frame:GetChecked() return self._checked end

    if getValue then frame:SetChecked(getValue()) end

    frame:SetScript("OnMouseDown", function(self)
        self:SetChecked(not self._checked)
        if setValue then setValue(self._checked) end
    end)
    frame:SetScript("OnEnter", function(self)
        self._box:SetVertexColor(0.18, 0.22, 0.35, 1)
        if tipTitle then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(tipTitle, 1, 1, 1)
            if tipBody then GameTooltip:AddLine(tipBody, 0.80, 0.86, 1.00, true) end; GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function(self)
        if self._checked then self._box:SetVertexColor(0.15, 0.25, 0.50, 0.98)
        else self._box:SetVertexColor(0.12, 0.14, 0.20, 0.95) end
        GameTooltip:Hide()
    end)
    return frame
end

-- ════════════════════════════════════════════════════════
-- EDITBOX (themed input)
-- ════════════════════════════════════════════════════════

function W.EditBox(parent, w, h, numeric)
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    eb:SetSize(w or 80, h or 22); eb:SetAutoFocus(false)
    if numeric then eb:SetNumeric(true) end
    eb:SetMaxLetters(64); eb:SetFontObject("GameFontHighlightSmall"); eb:SetJustifyH("LEFT"); ApplyReadableFont(eb, 1)
    eb:EnableMouse(true)
    eb:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8", edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 1, insets = { left = 2, right = 2, top = 1, bottom = 1 },
    })
    eb:SetBackdropColor(0.06, 0.08, 0.14, 0.95)
    eb:SetBackdropBorderColor(T.edgeR, T.edgeG, T.edgeB, 0.7)
    eb:SetTextColor(T.textR, T.textG, T.textB, T.textA)
    eb:SetTextInsets(4, 4, 0, 0)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText(); self:SetBackdropBorderColor(T.accentR, T.accentG, T.accentB, 1) end)
    eb:HookScript("OnEditFocusLost", function(self) self:HighlightText(0, 0); self:SetBackdropBorderColor(T.edgeR, T.edgeG, T.edgeB, 0.7) end)
    return eb
end

-- ════════════════════════════════════════════════════════
-- SLIDER (with editable input box)
-- ════════════════════════════════════════════════════════

local sliderUID = 0

function W.Slider(parent, label, min, max, step, getValue, setValue, tipTitle, tipBody)
    sliderUID = sliderUID + 1
    local container = CreateFrame("Frame", nil, parent); container:SetSize(280, 40)
    local labelFS = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelFS:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0); labelFS:SetText(label or ""); W.SkinText(labelFS)

    local sn = "MSASlider" .. sliderUID
    local slider = CreateFrame("Slider", sn, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", labelFS, "BOTTOMLEFT", 0, -6); slider:SetSize(170, 16)
    slider:SetMinMaxValues(min or 0, max or 100); slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true); slider:EnableMouse(true)
    local low = _G[sn.."Low"]; if low then low:SetText(""); low:Hide() end
    local high = _G[sn.."High"]; if high then high:SetText(""); high:Hide() end
    local txt = _G[sn.."Text"]; if txt then txt:SetText(""); txt:Hide() end

    local ib = CreateFrame("EditBox", nil, container, "BackdropTemplate")
    ib:SetSize(48, 18); ib:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    ib:SetAutoFocus(false); ib:SetNumeric(false); ib:SetMaxLetters(6)
    ib:SetFontObject("GameFontHighlightSmall"); ib:SetJustifyH("CENTER"); ib:EnableMouse(true); ApplyReadableFont(ib, 1)
    ib:SetBackdrop({ bgFile="Interface/Buttons/WHITE8X8", edgeFile="Interface/Buttons/WHITE8X8", edgeSize=1, insets={left=1,right=1,top=1,bottom=1} })
    ib:SetBackdropColor(0.06, 0.08, 0.14, 0.95); ib:SetBackdropBorderColor(T.edgeR, T.edgeG, T.edgeB, 0.7)
    ib:SetTextColor(T.textR, T.textG, T.textB, T.textA)

    container._label = labelFS; container._input = ib; container._slider = slider; container._updating = false

    local function Fmt(v) if step and step < 1 then return ("%d%%"):format(v*100) end; return tostring(math_floor(v+0.5)) end

    function container:Refresh()
        if not getValue then return end; self._updating = true
        local v = getValue(); self._slider:SetValue(clamp(v, min or 0, max or 100)); self._input:SetText(Fmt(v)); self._updating = false
    end

    slider:SetScript("OnValueChanged", function(_, value)
        if container._updating then return end
        local c2 = clamp(value, min or 0, max or 100)
        if step and step >= 1 then c2 = math_floor(c2+0.5) end
        ib:SetText(Fmt(c2)); if setValue then setValue(c2) end
    end)

    local function Commit()
        if container._updating then return end
        local raw = ib:GetText():gsub("%%",""); local num = tonumber(raw)
        if not num then container:Refresh(); return end
        if step and step < 1 then num = num/100 end
        if step and step >= 1 then num = math_floor(num+0.5) end
        container._updating = true; slider:SetValue(clamp(num, min or 0, max or 100)); ib:SetText(Fmt(num)); container._updating = false
        if setValue then setValue(num) end
    end
    ib:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Commit() end)
    ib:SetScript("OnEscapePressed", function(self) self:ClearFocus(); container:Refresh() end)
    ib:SetScript("OnEditFocusLost", Commit)
    ib:SetScript("OnEditFocusGained", function(self) self:HighlightText(); self:SetBackdropBorderColor(T.accentR, T.accentG, T.accentB, 1) end)
    ib:HookScript("OnEditFocusLost", function(self) self:HighlightText(0,0); self:SetBackdropBorderColor(T.edgeR, T.edgeG, T.edgeB, 0.7) end)
    if getValue then container:Refresh() end
    if tipTitle then W.AddTooltip(slider, tipTitle, tipBody) end
    return container
end

-- ════════════════════════════════════════════════════════
-- DROPDOWN (custom scroll-list, no UIDropDownMenu)
-- ════════════════════════════════════════════════════════

local openDropdown = nil

function W.CloseAllDropdowns()
    if openDropdown and openDropdown._listFrame then openDropdown._listFrame:Hide() end; openDropdown = nil
end

function W.Dropdown(parent, label, w, getOptions, getValue, setValue, tipTitle)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(w or 200, label and 40 or 22)

    if label then
        local lfs = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lfs:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0); lfs:SetText(label); W.SkinText(lfs)
        container._label = lfs
    end

    local btn = CreateFrame("Frame", nil, container, "BackdropTemplate")
    btn:SetSize(w or 200, 22); btn:EnableMouse(true)
    btn:SetPoint("TOPLEFT", container._label or container, container._label and "BOTTOMLEFT" or "TOPLEFT", 0, container._label and -2 or 0)
    btn:SetBackdrop({ bgFile="Interface/Buttons/WHITE8X8", edgeFile="Interface/Buttons/WHITE8X8", edgeSize=1, insets={left=1,right=1,top=1,bottom=1} })
    btn:SetBackdropColor(0.06, 0.08, 0.14, 0.95); btn:SetBackdropBorderColor(pillEdgeR, pillEdgeG, pillEdgeB, 0.8)

    local selFS = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selFS:SetPoint("LEFT", btn, "LEFT", 8, 0); selFS:SetPoint("RIGHT", btn, "RIGHT", -20, 0); selFS:SetJustifyH("LEFT"); W.SkinText(selFS)
    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0); arrow:SetText("v"); W.SkinMuted(arrow)

    container._btn = btn; container._selectedFS = selFS; container._listFrame = nil

    function container:SetValue(val)
        if setValue then setValue(val) end
        local options = getOptions and getOptions() or {}
        for _, opt in ipairs(options) do
            local ov = type(opt) == "table" and opt.value or opt
            if tostring(ov) == tostring(val) then selFS:SetText(type(opt) == "table" and opt.text or tostring(opt)); return end
        end
        selFS:SetText(tostring(val))
    end

    function container:Refresh()
        if not getValue then return end; local v = getValue()
        local options = getOptions and getOptions() or {}
        for _, opt in ipairs(options) do
            local ov = type(opt) == "table" and opt.value or opt
            if tostring(ov) == tostring(v) then selFS:SetText(type(opt) == "table" and opt.text or tostring(opt)); return end
        end
        selFS:SetText(tostring(v))
    end

    local function ToggleList()
        if container._listFrame and container._listFrame:IsShown() then container._listFrame:Hide(); openDropdown = nil; return end
        if openDropdown and openDropdown ~= container and openDropdown._listFrame then openDropdown._listFrame:Hide() end
        openDropdown = container

        local options = getOptions and getOptions() or {}
        local current = getValue and getValue() or ""

        if not container._listFrame then
            local list = CreateFrame("Frame", nil, btn, "BackdropTemplate")
            list:SetFrameStrata("FULLSCREEN_DIALOG"); list:SetFrameLevel(btn:GetFrameLevel() + 50)
            list:SetBackdrop({ bgFile="Interface/Buttons/WHITE8X8", edgeFile="Interface/Buttons/WHITE8X8", edgeSize=1, insets={left=1,right=1,top=1,bottom=1} })
            list:SetBackdropColor(0.02, 0.03, 0.06, 0.98); list:SetBackdropBorderColor(pillEdgeR, pillEdgeG, pillEdgeB, 1)
            list:SetClampedToScreen(true)
            local sc = CreateFrame("ScrollFrame", nil, list)
            sc:SetPoint("TOPLEFT", 2, -2); sc:SetPoint("BOTTOMRIGHT", -2, 2)
            local ct = CreateFrame("Frame", nil, sc); ct:SetSize(1, 1); sc:SetScrollChild(ct)
            sc:EnableMouseWheel(true)
            sc:SetScript("OnMouseWheel", function(self, delta)
                local cur = self:GetVerticalScroll(); local maxS = math_max(0, ct:GetHeight() - self:GetHeight())
                self:SetVerticalScroll(clamp(cur - delta * 20, 0, maxS))
            end)
            container._listFrame = list; container._listScroll = sc; container._listContent = ct; container._listRows = {}
        end

        local list, sc, ct = container._listFrame, container._listScroll, container._listContent
        local rowH = 20; local maxVis = math_min(#options, 10); local listH = maxVis * rowH + 4
        list:SetSize(w or 200, listH); list:ClearAllPoints(); list:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        ct:SetWidth((w or 200) - 4); sc:SetVerticalScroll(0)

        for i, opt in ipairs(options) do
            local row = container._listRows[i]
            if not row then
                row = CreateFrame("Frame", nil, ct); row:SetHeight(rowH); row:EnableMouse(true)
                row.text = row:CreateFontString(nil, "OVERLAY"); row.text:SetFont(STANDARD_TEXT_FONT, 12, "")
                row.text:SetPoint("LEFT", 8, 0); row.text:SetPoint("RIGHT", -8, 0); row.text:SetJustifyH("LEFT")
                row.sel = row:CreateTexture(nil, "BACKGROUND"); row.sel:SetAllPoints(); row.sel:SetColorTexture(T.accentR, T.accentG, T.accentB, 0.3)
                row.hov = row:CreateTexture(nil, "BACKGROUND", nil, 1); row.hov:SetAllPoints(); row.hov:SetColorTexture(1,1,1,0)
                row:SetScript("OnEnter", function(self) self.hov:SetColorTexture(1,1,1,0.06) end)
                row:SetScript("OnLeave", function(self) self.hov:SetColorTexture(1,1,1,0) end)
                container._listRows[i] = row
            end
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", ct, "TOPLEFT", 0, -((i-1)*rowH)); row:SetPoint("RIGHT", ct, "RIGHT", 0, 0)
            local optText = type(opt) == "table" and opt.text or tostring(opt)
            local optVal  = type(opt) == "table" and opt.value or opt
            row.text:SetText(optText); W.SkinText(row.text); row.sel:SetShown(tostring(optVal) == tostring(current))
            row:SetScript("OnMouseDown", function() container:SetValue(optVal); list:Hide(); openDropdown = nil end)
            row:Show()
        end
        for i = #options + 1, #container._listRows do container._listRows[i]:Hide() end
        ct:SetHeight(#options * rowH); list:Show()
    end

    btn:SetScript("OnMouseDown", ToggleList)
    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(T.accentR, T.accentG, T.accentB, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(pillEdgeR, pillEdgeG, pillEdgeB, 0.8) end)
    if getValue then container:Refresh() end
    if tipTitle then W.AddTooltip(btn, tipTitle) end
    return container
end

-- ════════════════════════════════════════════════════════
-- COLOR SWATCH
-- ════════════════════════════════════════════════════════

function W.ColorSwatch(parent, label, getColor, setColor)
    local container = CreateFrame("Frame", nil, parent); container:SetSize(200, 20)
    local swatch = CreateFrame("Frame", nil, container, "BackdropTemplate")
    swatch:SetSize(18, 18); swatch:SetPoint("LEFT", container, "LEFT", 0, 0); swatch:EnableMouse(true)
    swatch:SetBackdrop({ bgFile="Interface/Buttons/WHITE8X8", edgeFile="Interface/Buttons/WHITE8X8", edgeSize=1, insets={left=0,right=0,top=0,bottom=0} })
    swatch:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    if label then local lfs = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lfs:SetPoint("LEFT", swatch, "RIGHT", 8, 0); lfs:SetText(label); W.SkinText(lfs) end
    container._swatch = swatch

    function container:Refresh()
        if getColor then local c = getColor(); if c then swatch:SetBackdropColor(c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1, 1) end end
    end

    swatch:SetScript("OnMouseDown", function()
        local c = getColor and getColor() or {1,1,1}
        local oR, oG, oB = c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1
        local function OnC() local nr,ng,nb = ColorPickerFrame:GetColorRGB(); if setColor then setColor({nr,ng,nb}) end; container:Refresh() end
        local function OnX() if setColor then setColor({oR,oG,oB}) end; container:Refresh() end
        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({ r=oR, g=oG, b=oB, hasOpacity=false, swatchFunc=OnC, cancelFunc=OnX })
        elseif ColorPickerFrame then
            ColorPickerFrame.hasOpacity=false; ColorPickerFrame.previousValues={oR,oG,oB}
            ColorPickerFrame.func=OnC; ColorPickerFrame.cancelFunc=OnX
            ColorPickerFrame:SetColorRGB(oR,oG,oB); ColorPickerFrame:Hide(); ColorPickerFrame:Show()
        end
    end)
    container:Refresh(); return container
end

-- ════════════════════════════════════════════════════════
-- MODE CARD (selectable option, for aura mode grid)
-- ════════════════════════════════════════════════════════

function W.ModeCard(parent, text, desc, w, h, onClick)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(w or 150, h or 44); card:EnableMouse(true)
    card:SetBackdrop({ bgFile="Interface/Buttons/WHITE8X8", edgeFile="Interface/Buttons/WHITE8X8", edgeSize=1, insets={left=1,right=1,top=1,bottom=1} })
    card:SetBackdropColor(0.06, 0.08, 0.14, 0.90); card:SetBackdropBorderColor(T.edgeR, T.edgeG, T.edgeB, 0.6)

    local tfs = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tfs:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6); tfs:SetText(text or ""); W.SkinText(tfs); card._titleFS = tfs
    if desc then
        local dfs = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dfs:SetPoint("TOPLEFT", tfs, "BOTTOMLEFT", 0, -2); dfs:SetPoint("RIGHT", card, "RIGHT", -6, 0)
        dfs:SetText(desc); W.SkinMuted(dfs); dfs:SetJustifyH("LEFT"); card._descFS = dfs
    end
    card._selected = false

    function card:SetSelected(val)
        self._selected = val and true or false
        if self._selected then self:SetBackdropColor(0.12, 0.22, 0.40, 0.95); self:SetBackdropBorderColor(T.accentR, T.accentG, T.accentB, 1)
        else self:SetBackdropColor(0.06, 0.08, 0.14, 0.90); self:SetBackdropBorderColor(T.edgeR, T.edgeG, T.edgeB, 0.6) end
    end
    card:SetScript("OnEnter", function(self) if not self._selected then self:SetBackdropBorderColor(T.accentR*0.7, T.accentG*0.7, T.accentB*0.7, 0.9) end end)
    card:SetScript("OnLeave", function(self) if not self._selected then self:SetBackdropBorderColor(T.edgeR, T.edgeG, T.edgeB, 0.6) end end)
    card:SetScript("OnMouseDown", function(self) if onClick then onClick(self) end end)
    return card
end

-- ════════════════════════════════════════════════════════
-- SCROLLABLE PAGE (standard page frame with scroll)
-- ════════════════════════════════════════════════════════

function W.ScrollPage(host)
    local f = CreateFrame("Frame", nil, host); f:SetAllPoints(host); W.ApplyBackdrop(f, 0.35)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0); scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    local c = CreateFrame("Frame", nil, scroll); c:SetSize(1, 900); scroll:SetScrollChild(c); c:SetWidth(400)
    f:HookScript("OnShow", function() local w = scroll:GetWidth(); c:SetWidth(w > 1 and w or 400) end)
    f._scroll = scroll; f._content = c; return f
end

-- ════════════════════════════════════════════════════════
-- LAYOUT HELPER
-- ════════════════════════════════════════════════════════

function W.Layout(parent, startX, startY, rowH, gap)
    local L = { parent = parent, x = startX or 12, y = startY or -12, rowH = rowH or 24, gap = gap or 6 }
    function L:Row(h, g) local x, y = self.x, self.y; self.y = self.y - (h or self.rowH) - (g or self.gap); return x, y end
    function L:Skip(dy) self.y = self.y - (dy or self.gap) end
    function L:At(dx, dy) return self.x + (dx or 0), self.y + (dy or 0) end
    function L:GetY() return self.y end
    return L
end
