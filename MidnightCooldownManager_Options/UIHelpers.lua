local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local CDM_C = CDM and CDM.CONST or {}
local LSM = LibStub("LibSharedMedia-3.0")

ns.ConfigUI = ns.ConfigUI or {}
local UI = ns.ConfigUI

local WHITE = CDM_C.WHITE
local min = math.min
local max = math.max

local ADDON_MEDIA = "Interface\\AddOns\\MidnightCooldownManager\\Media\\"
local THEME = UI.Theme or {}
UI.Theme = THEME
THEME.media = THEME.media or {
    superellipse = ADDON_MEDIA .. "superellipse.tga",
    sliderThumb = ADDON_MEDIA .. "mcdm_slider_thumb.tga",
    switchTrack = ADDON_MEDIA .. "mcdm_switch_track.tga",
    switchKnob = ADDON_MEDIA .. "mcdm_switch_knob.tga",
    logo = ADDON_MEDIA .. "MCDM_MinimapIcon.tga",
    white = "Interface\\Buttons\\WHITE8X8",
}
THEME.media.sliderThumb = THEME.media.sliderThumb or (ADDON_MEDIA .. "mcdm_slider_thumb.tga")
THEME.media.switchTrack = THEME.media.switchTrack or (ADDON_MEDIA .. "mcdm_switch_track.tga")
THEME.media.switchKnob = THEME.media.switchKnob or (ADDON_MEDIA .. "mcdm_switch_knob.tga")
THEME.colors = THEME.colors or {
    bg = { r = 0.040, g = 0.046, b = 0.064, a = 0.985 },
    shell = { r = 0.026, g = 0.032, b = 0.052, a = 0.955 },
    rail = { r = 0.028, g = 0.036, b = 0.064, a = 0.760 },
    host = { r = 0.030, g = 0.038, b = 0.066, a = 0.680 },
    card = { r = 0.038, g = 0.046, b = 0.072, a = 0.955 },
    popup = { r = 0.008, g = 0.012, b = 0.022, a = 0.950 },
    border = { r = 0.105, g = 0.130, b = 0.220, a = 0.660 },
    borderSoft = { r = 0.105, g = 0.130, b = 0.220, a = 0.300 },
    cardBorder = { r = 0.105, g = 0.130, b = 0.220, a = 0.320 },
    accent = { r = 0.180, g = 0.720, b = 0.900, a = 1.000 },
    accent2 = { r = 0.965, g = 0.760, b = 0.150, a = 1.000 },
    danger = { r = 0.880, g = 0.280, b = 0.280, a = 1.000 },
    success = { r = 0.240, g = 0.820, b = 0.460, a = 1.000 },
    text = { r = 0.880, g = 0.910, b = 1.000, a = 1.000 },
    title = { r = 0.890, g = 0.940, b = 1.000, a = 1.000 },
    muted = { r = 0.690, g = 0.735, b = 0.840, a = 0.900 },
    dim = { r = 0.500, g = 0.580, b = 0.720, a = 0.860 },
    pillBase = { r = 0.050, g = 0.062, b = 0.105, a = 0.880 },
    pillHover = { r = 0.068, g = 0.084, b = 0.140, a = 0.950 },
    pillActive = { r = 0.120, g = 0.185, b = 0.430, a = 0.950 },
    pillEdge = { r = 0.130, g = 0.165, b = 0.290, a = 0.520 },
    pillEdgeHover = { r = 0.150, g = 0.280, b = 0.540, a = 0.660 },
    pillEdgeActive = { r = 0.210, g = 0.420, b = 0.860, a = 0.760 },
    navPillBase = { r = 0.064, g = 0.088, b = 0.170, a = 0.920 },
    navPillHover = { r = 0.094, g = 0.128, b = 0.252, a = 0.960 },
    navPillActive = { r = 0.235, g = 0.375, b = 0.920, a = 0.990 },
    navPillEdge = { r = 0.135, g = 0.180, b = 0.350, a = 0.420 },
    navPillEdgeHover = { r = 0.220, g = 0.350, b = 0.760, a = 0.620 },
    navPillEdgeActive = { r = 0.380, g = 0.560, b = 0.960, a = 0.800 },
    navHeaderText = { r = 0.680, g = 0.780, b = 1.000, a = 0.960 },
    navHeaderHover = { r = 0.780, g = 0.860, b = 1.000, a = 1.000 },
    navArrowOpen = { r = 1.000, g = 0.760, b = 0.250, a = 1.000 },
    navArrowClosed = { r = 1.000, g = 0.560, b = 0.060, a = 1.000 },
}
THEME.colors.ok = THEME.colors.ok or THEME.colors.success
THEME.colors.glassShell = THEME.colors.glassShell or THEME.colors.shell
THEME.colors.glassRail = THEME.colors.glassRail or THEME.colors.rail
THEME.colors.glassHost = THEME.colors.glassHost or THEME.colors.host
THEME.colors.glassStatus = THEME.colors.glassStatus or { r = 0.032, g = 0.040, b = 0.070, a = 0.560 }
THEME.colors.glassPopup = THEME.colors.glassPopup or THEME.colors.popup

THEME.materials = THEME.materials or {
    shell = {
        bg = THEME.colors.glassShell,
        border = THEME.colors.border,
        gradientTop = { r = 0.070, g = 0.096, b = 0.170, a = 0.40 },
        gradientBottom = { r = 0.008, g = 0.012, b = 0.026, a = 0.58 },
        inset = 3,
    },
    rail = {
        bg = THEME.colors.glassRail,
        border = THEME.colors.borderSoft,
        gradientTop = { r = 0.060, g = 0.088, b = 0.170, a = 0.32 },
        gradientBottom = { r = 0.010, g = 0.014, b = 0.030, a = 0.46 },
        inset = 3,
    },
    host = {
        bg = THEME.colors.glassHost,
        border = THEME.colors.borderSoft,
        gradientTop = { r = 0.052, g = 0.080, b = 0.160, a = 0.28 },
        gradientBottom = { r = 0.008, g = 0.012, b = 0.028, a = 0.40 },
        inset = 3,
    },
    status = {
        bg = THEME.colors.glassStatus,
        border = THEME.colors.borderSoft,
        gradientTop = { r = 0.070, g = 0.110, b = 0.220, a = 0.34 },
        gradientBottom = { r = 0.010, g = 0.014, b = 0.030, a = 0.42 },
        inset = 2,
    },
    card = {
        bg = THEME.colors.card,
        border = THEME.colors.cardBorder,
        gradientTop = { r = 0.060, g = 0.080, b = 0.142, a = 0.22 },
        gradientBottom = { r = 0.006, g = 0.010, b = 0.024, a = 0.34 },
        inset = 2,
    },
    popup = {
        bg = THEME.colors.glassPopup,
        border = { r = 0.140, g = 0.220, b = 0.600, a = 0.88 },
        gradientTop = { r = 0.055, g = 0.088, b = 0.175, a = 0.38 },
        gradientBottom = { r = 0.004, g = 0.006, b = 0.014, a = 0.54 },
        inset = 2,
    },
    guide = {
        bg = { r = 0.018, g = 0.052, b = 0.082, a = 0.28 },
        border = { r = 0.180, g = 0.720, b = 0.900, a = 0.82 },
        gradientTop = { r = 0.090, g = 0.220, b = 0.310, a = 0.24 },
        gradientBottom = { r = 0.006, g = 0.020, b = 0.035, a = 0.32 },
        inset = 2,
    },
}

-- Options-only compatibility for pages that still reference CDM_C.GOLD for section headers.
if CDM_C.GOLD then
    CDM_C.GOLD = {
        r = THEME.colors.accent.r,
        g = THEME.colors.accent.g,
        b = THEME.colors.accent.b,
        a = THEME.colors.accent.a,
    }
end

UI.TextColors = {
    white = { r = THEME.colors.text.r, g = THEME.colors.text.g, b = THEME.colors.text.b, a = THEME.colors.text.a },
    muted = { r = THEME.colors.muted.r, g = THEME.colors.muted.g, b = THEME.colors.muted.b, a = THEME.colors.muted.a },
    subtle = { r = THEME.colors.text.r, g = THEME.colors.text.g, b = THEME.colors.text.b, a = 0.82 },
    faint = { r = THEME.colors.dim.r, g = THEME.colors.dim.g, b = THEME.colors.dim.b, a = THEME.colors.dim.a },
    inactive = { r = 0.820, g = 0.890, b = 1.000, a = 0.86 },
    success = { r = THEME.colors.success.r, g = THEME.colors.success.g, b = THEME.colors.success.b, a = THEME.colors.success.a },
    error = { r = THEME.colors.danger.r, g = THEME.colors.danger.g, b = THEME.colors.danger.b, a = THEME.colors.danger.a },
}

local function SetRegionColor(region, color, alphaMult)
    if not (region and color) then return end
    local a = color.a
    if a == nil then a = 1 end
    if alphaMult then a = a * alphaMult end
    if region.SetVertexColor then
        region:SetVertexColor(color.r, color.g, color.b, a)
    elseif region.SetColorTexture then
        region:SetColorTexture(color.r, color.g, color.b, a)
    end
end

local function UseControlTexture(tex, texture)
    if not tex then return tex end
    if tex.SetTexture then tex:SetTexture(texture or THEME.media.white or CDM_C.TEX_WHITE8X8) end
    if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
    return tex
end

local function HideNativeTextures(frame, keep)
    if not (frame and frame.GetRegions) then return end
    keep = keep or {}
    for _, region in ipairs({ frame:GetRegions() }) do
        if not keep[region] and region.SetAlpha then
            region:SetAlpha(0)
        end
    end
end

local function Clamp01(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function ShadeColor(color, amount, alphaMult)
    color = color or THEME.colors.card
    amount = tonumber(amount) or 0
    local r, g, b = color.r or 0, color.g or 0, color.b or 0
    if amount >= 0 then
        r = r + (1 - r) * amount
        g = g + (1 - g) * amount
        b = b + (1 - b) * amount
    else
        local f = 1 + amount
        r, g, b = r * f, g * f, b * f
    end
    return {
        r = Clamp01(r),
        g = Clamp01(g),
        b = Clamp01(b),
        a = Clamp01((color.a == nil and 1 or color.a) * (alphaMult or 1)),
    }
end

local function ApplyTextureGradient(tex, orientation, fromColor, toColor, preserveTexture)
    if not tex then return end
    fromColor = fromColor or THEME.colors.card
    toColor = toColor or fromColor
    orientation = orientation or "VERTICAL"
    if tex.SetTexture and not preserveTexture then
        tex:SetTexture(THEME.media.white or CDM_C.TEX_WHITE8X8)
        if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
    end
    if tex.SetGradientAlpha then
        tex:SetGradientAlpha(orientation,
            fromColor.r or 0, fromColor.g or 0, fromColor.b or 0, fromColor.a or 1,
            toColor.r or 0, toColor.g or 0, toColor.b or 0, toColor.a or 1)
    elseif tex.SetGradient and _G.CreateColor then
        tex:SetGradient(orientation,
            _G.CreateColor(fromColor.r or 0, fromColor.g or 0, fromColor.b or 0, fromColor.a or 1),
            _G.CreateColor(toColor.r or 0, toColor.g or 0, toColor.b or 0, toColor.a or 1))
    elseif tex.SetVertexColor then
        tex:SetVertexColor(
            ((fromColor.r or 0) + (toColor.r or 0)) * 0.5,
            ((fromColor.g or 0) + (toColor.g or 0)) * 0.5,
            ((fromColor.b or 0) + (toColor.b or 0)) * 0.5,
            ((fromColor.a or 1) + (toColor.a or 1)) * 0.5)
    end
end

local function ColorLineTexture(line, color, alpha)
    if not line then return end
    if line.SetTexture then line:SetTexture(THEME.media.white or CDM_C.TEX_WHITE8X8) end
    if line.SetSnapToPixelGrid then line:SetSnapToPixelGrid(true) end
    if line.SetTexelSnappingBias then line:SetTexelSnappingBias(0) end
    if line.SetVertexColor and color then
        line:SetVertexColor(color.r, color.g, color.b, alpha or color.a or 1)
    end
end

function UI.ApplySurface(frame, material)
    if not frame then return frame end
    local spec = type(material) == "table" and material or THEME.materials[material or "card"]
    if type(spec) ~= "table" then
        return UI.ApplyBackdrop(frame, THEME.colors.card, THEME.colors.cardBorder)
    end

    UI.ApplyBackdrop(frame, spec.bg, spec.border)
    if frame.CreateTexture then
        local gradient = frame._mcdmMaterialGradient
        if not gradient then
            gradient = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
            frame._mcdmMaterialGradient = gradient
        end
        gradient:ClearAllPoints()
        local inset = tonumber(spec.inset) or 0
        gradient:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
        gradient:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
        ApplyTextureGradient(gradient, spec.orientation or "VERTICAL", spec.gradientTop, spec.gradientBottom)
        if gradient.SetBlendMode then gradient:SetBlendMode("BLEND") end
        gradient:Show()
    end
    return frame
end

function UI.ApplyMenuAtmosphere(frame, host, nav)
    if not frame or frame._mcdmAtmosphereApplied then return frame end
    frame._mcdmAtmosphereApplied = true
    host = host or frame
    UI.ApplySurface(frame, "shell")
    if host and host ~= frame then UI.ApplySurface(host, "host") end
    if nav then UI.ApplySurface(nav, "rail") end

    if host and host.CreateTexture then
        local wash = host:CreateTexture(nil, "BACKGROUND", nil, 2)
        wash:SetTexture(THEME.media.white or CDM_C.TEX_WHITE8X8)
        wash:SetPoint("TOPLEFT", host, "TOPLEFT", 3, -3)
        wash:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -3, 3)
        ApplyTextureGradient(wash, "VERTICAL",
            { r = 0.060, g = 0.090, b = 0.180, a = 0.070 },
            { r = 0.000, g = 0.000, b = 0.000, a = 0.220 })
        if wash.SetBlendMode then wash:SetBlendMode("BLEND") end

        local logo = host:CreateTexture(nil, "BORDER", nil, 0)
        logo:SetTexture(THEME.media.logo)
        logo:SetSize(120, 120)
        logo:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -12, 12)
        logo:SetVertexColor(0.22, 0.28, 0.42, 0.030)
        if logo.SetBlendMode then logo:SetBlendMode("ADD") end
    end

    if nav and nav.CreateTexture then
        local navWash = nav:CreateTexture(nil, "BORDER", nil, 1)
        navWash:SetTexture(THEME.media.white or CDM_C.TEX_WHITE8X8)
        navWash:SetPoint("TOPLEFT", nav, "TOPLEFT", 3, -3)
        navWash:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -3, 3)
        ApplyTextureGradient(navWash, "VERTICAL",
            { r = 0.060, g = 0.088, b = 0.180, a = 0.085 },
            { r = 0.010, g = 0.014, b = 0.030, a = 0.120 })
    end

    return frame
end

function UI.ApplyBackdrop(frame, bg, border)
    if not frame then return frame end
    bg = bg or THEME.colors.card
    border = border or THEME.colors.borderSoft
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = CDM_C.TEX_WHITE8X8,
            edgeFile = CDM_C.TEX_WHITE8X8,
            edgeSize = 1,
        })
        frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 1)
        frame:SetBackdropBorderColor(border.r, border.g, border.b, border.a or 1)
        return frame
    end
    if frame.CreateTexture and not frame._mcdmBackdrop then
        local tex = frame:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        frame._mcdmBackdrop = tex
    end
    SetRegionColor(frame._mcdmBackdrop, bg)
    return frame
end

function UI.CreatePanel(parent, name, bg, border)
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    UI.ApplyBackdrop(frame, bg, border)
    return frame
end

local function CreateSuperellipseParts(frame, layer, subLevel)
    local parts = {}
    local coords = {
        { "L", 0.00, 0.25 },
        { "M", 0.25, 0.75 },
        { "R", 0.75, 1.00 },
    }
    for i = 1, #coords do
        local spec = coords[i]
        local tex = frame:CreateTexture(nil, layer, nil, subLevel or 0)
        tex:SetTexture(THEME.media.superellipse)
        tex:SetTexCoord(spec[2], spec[3], 0, 1)
        parts[spec[1]] = tex
    end
    parts._textures = { parts.L, parts.M, parts.R }
    function parts:SetVertexColor(r, g, b, a)
        for i = 1, #self._textures do
            self._textures[i]:SetVertexColor(r, g, b, a or 1)
        end
    end
    return parts
end

local function LayoutSuperellipseParts(parts, frame, inset)
    if not (parts and frame) then return end
    local width = (frame.GetWidth and frame:GetWidth()) or 120
    local height = (frame.GetHeight and frame:GetHeight()) or 22
    local p = tonumber(inset) or 1
    local innerW = math.max(1, width - p * 2)
    local innerH = math.max(1, height - p * 2)
    local capW = math.min(math.floor(innerH * 0.5 + 0.5), math.floor(innerW * 0.5))

    parts.L:ClearAllPoints()
    parts.M:ClearAllPoints()
    parts.R:ClearAllPoints()
    parts.L:SetPoint("TOPLEFT", frame, "TOPLEFT", p, -p)
    parts.L:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", p, p)
    parts.L:SetWidth(capW)
    parts.R:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -p, -p)
    parts.R:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -p, p)
    parts.R:SetWidth(capW)
    parts.M:SetPoint("TOPLEFT", parts.L, "TOPRIGHT", 0, 0)
    parts.M:SetPoint("BOTTOMRIGHT", parts.R, "BOTTOMLEFT", 0, 0)
end

local function IsCompactSkinTarget(frame, maxWidth, maxHeight)
    if not frame then return false end
    local width = frame.GetWidth and frame:GetWidth() or 0
    local height = frame.GetHeight and frame:GetHeight() or 0
    if width <= 0 or height <= 0 then return false end
    return width <= (maxWidth or 520) and height <= (maxHeight or 44)
end

function UI.CreateSuperellipseLayers(frame, key, inset, fillLayer, borderLayer)
    if not (frame and frame.CreateTexture) then return nil, nil end
    key = key or "_mcdmSuperellipse"
    if frame[key .. "Fill"] and frame[key .. "Edge"] then
        return frame[key .. "Fill"], frame[key .. "Edge"]
    end
    local fill = CreateSuperellipseParts(frame, fillLayer or "BACKGROUND", 0)
    local edge = CreateSuperellipseParts(frame, borderLayer or "BORDER", -1)
    local function Layout()
        LayoutSuperellipseParts(fill, frame, tonumber(inset) or 2)
        LayoutSuperellipseParts(edge, frame, math.max(0, (tonumber(inset) or 2) - 1))
    end
    Layout()
    frame:HookScript("OnSizeChanged", Layout)
    frame[key .. "Fill"] = fill
    frame[key .. "Edge"] = edge
    return fill, edge
end

local function ColorParts(parts, color, alphaMult)
    if not (parts and parts._textures and color) then return end
    local a = color.a
    if a == nil then a = 1 end
    if alphaMult then a = a * alphaMult end
    for i = 1, #parts._textures do
        parts._textures[i]:SetVertexColor(color.r, color.g, color.b, a)
    end
end

local function GradientParts(parts, color, amountTop, amountBottom, alphaMult)
    if not (parts and parts._textures and color) then return end
    local top = ShadeColor(color, amountTop or 0.12, alphaMult)
    local bottom = ShadeColor(color, amountBottom or -0.18, alphaMult)
    for i = 1, #parts._textures do
        ApplyTextureGradient(parts._textures[i], "VERTICAL", top, bottom, true)
    end
end

function UI.ColorSuperellipseParts(parts, color, alphaMult)
    ColorParts(parts, color, alphaMult)
end

function UI.StylePanel(frame, bg, border)
    if not frame then return frame end
    bg = bg or THEME.colors.card
    border = border or THEME.colors.cardBorder
    return UI.ApplyBackdrop(frame, bg, border)
end

function UI.CreateDivider(parent, layer, alpha)
    local line = parent:CreateTexture(nil, layer or "ARTWORK")
    line:SetTexture(CDM_C.TEX_WHITE8X8)
    local color = THEME.colors.accent or THEME.colors.borderSoft
    line:SetVertexColor(color.r, color.g, color.b, alpha or 0.34)
    line:SetHeight(1)
    return line
end

UI.AccordionState = UI.AccordionState or {}

local function PaintAccordionSection(section, hover)
    if not section then return end
    local open = section._mcdmOpen
    local fill = open and { r = 0.045, g = 0.056, b = 0.094, a = 0.72 }
        or (hover and { r = 0.040, g = 0.050, b = 0.084, a = 0.58 }
        or { r = 0.026, g = 0.032, b = 0.056, a = 0.42 })
    local edge = open and THEME.colors.pillEdgeHover or THEME.colors.borderSoft
    if section._mcdmHeaderFill then
        ApplyTextureGradient(section._mcdmHeaderFill, "VERTICAL", ShadeColor(fill, 0.10), ShadeColor(fill, -0.18))
    end
    if section._mcdmHeaderEdge then
        section._mcdmHeaderEdge:SetColorTexture(edge.r, edge.g, edge.b, open and 0.55 or (hover and 0.44 or 0.28))
    end
    if section.Arrow then
        local c = open and THEME.colors.navArrowOpen or THEME.colors.navArrowClosed
        section.Arrow:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        if section.Arrow.SetRotation then
            section.Arrow:SetRotation(open and 1.570796 or 0)
        end
    end
    if section.Label then
        local c = open and THEME.colors.text or THEME.colors.muted
        section.Label:SetTextColor(c.r, c.g, c.b, c.a or 1)
    end
end

function UI.CreateAccordionSection(parent, title, width, contentHeight, stateKey, defaultOpen, onToggle)
    local headerH = 28
    local bodyPadY = 12
    local section = UI.CreatePanel(parent, nil, THEME.colors.card, THEME.colors.cardBorder)
    if UI.ApplySurface then UI.ApplySurface(section, "card") end
    section:SetSize(width or 520, headerH + (contentHeight or 120) + bodyPadY)
    section._mcdmContentHeight = contentHeight or 120
    section._mcdmStateKey = stateKey

    local saved = stateKey and UI.AccordionState[stateKey]
    section._mcdmOpen = (saved == nil) and (defaultOpen ~= false) or (saved and true or false)

    local header = CreateFrame("Button", nil, section)
    header:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
    header:SetHeight(headerH)
    header:RegisterForClicks("LeftButtonUp")
    section.Header = header

    local headerFill = header:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerFill:SetAllPoints()
    section._mcdmHeaderFill = headerFill

    local headerEdge = header:CreateTexture(nil, "BORDER", nil, 1)
    headerEdge:SetHeight(1)
    headerEdge:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    headerEdge:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    section._mcdmHeaderEdge = headerEdge

    local arrow = header:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetSize(10, 10)
    arrow:SetPoint("LEFT", header, "LEFT", 12, 0)
    section.Arrow = arrow

    local label = header:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    label:SetPoint("LEFT", arrow, "RIGHT", 10, 0)
    label:SetPoint("RIGHT", header, "RIGHT", -12, 0)
    label:SetJustifyH("LEFT")
    label:SetText(title or "")
    section.Label = label

    local body = CreateFrame("Frame", nil, section)
    body:SetPoint("TOPLEFT", section, "TOPLEFT", 14, -(headerH + bodyPadY))
    body:SetPoint("TOPRIGHT", section, "TOPRIGHT", -14, -(headerH + bodyPadY))
    body:SetHeight(section._mcdmContentHeight)
    section.Body = body

    local function Refresh()
        local h = headerH + (section._mcdmOpen and (section._mcdmContentHeight + bodyPadY) or 0)
        section:SetHeight(h)
        body:SetShown(section._mcdmOpen)
        PaintAccordionSection(section, section._mcdmHover)
    end

    function section:SetContentHeight(height)
        self._mcdmContentHeight = math.max(1, tonumber(height) or self._mcdmContentHeight or 1)
        self.Body:SetHeight(self._mcdmContentHeight)
        Refresh()
    end

    function section:GetEffectiveHeight()
        return self:GetHeight()
    end

    function section:SetOpen(open)
        open = open and true or false
        if self._mcdmOpen == open then return end
        self._mcdmOpen = open
        if self._mcdmStateKey then UI.AccordionState[self._mcdmStateKey] = open end
        Refresh()
        if onToggle then onToggle(self, open) end
    end

    function section:IsOpen()
        return self._mcdmOpen and true or false
    end

    header:SetScript("OnClick", function() section:SetOpen(not section._mcdmOpen) end)
    header:SetScript("OnEnter", function()
        section._mcdmHover = true
        PaintAccordionSection(section, true)
    end)
    header:SetScript("OnLeave", function()
        section._mcdmHover = nil
        PaintAccordionSection(section, false)
    end)

    Refresh()
    return section, body
end

function UI.LayoutAccordionSections(sections, startY, gap, scrollChild, contentFrame, startX)
    local yOff = startY or 0
    local xOff = startX or 0
    gap = gap or 8
    for _, section in ipairs(sections or {}) do
        if not section.IsShown or section:IsShown() then
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", xOff, yOff)
            yOff = yOff - ((section.GetEffectiveHeight and section:GetEffectiveHeight()) or section:GetHeight()) - gap
        end
    end
    if scrollChild and contentFrame then
        UI.FinalizeScroll(scrollChild, contentFrame, yOff)
    end
    return yOff
end

local function PaintButton(btn)
    if not btn then return end
    local colors = THEME.colors
    local enabled = not (btn.IsEnabled and not btn:IsEnabled())
    local active = btn._mcdmActive
    local hover = btn._mcdmHover
    local role = btn._mcdmRole
    local bg, edge, text

    if not enabled then
        bg = { r = 0.075, g = 0.080, b = 0.105, a = 0.55 }
        edge = { r = 0.180, g = 0.210, b = 0.300, a = 0.45 }
        text = { r = 0.50, g = 0.52, b = 0.58, a = 0.95 }
    elseif role == "danger" then
        bg = hover and { r = 0.180, g = 0.040, b = 0.065, a = 0.97 } or { r = 0.140, g = 0.030, b = 0.050, a = 0.94 }
        edge = colors.danger
        text = colors.text
    elseif role == "success" then
        bg = hover and { r = 0.060, g = 0.380, b = 0.180, a = 0.98 } or { r = 0.040, g = 0.280, b = 0.130, a = 0.95 }
        edge = colors.success
        text = { r = 0.92, g = 1.00, b = 0.94, a = 1 }
    elseif role == "primary" then
        bg = hover and { r = 0.200, g = 0.640, b = 0.820, a = 0.99 } or { r = 0.160, g = 0.560, b = 0.720, a = 0.97 }
        edge = { r = 0.220, g = 0.720, b = 0.940, a = 0.85 }
        text = colors.text
    elseif btn._mcdmNavItem then
        if active then
            bg, edge, text = colors.navPillActive, colors.navPillEdgeActive, colors.text
        elseif hover then
            bg, edge, text = colors.navPillHover, colors.navPillEdgeHover, colors.text
        else
            bg, edge, text = colors.navPillBase, colors.navPillEdge, { r = 0.840, g = 0.900, b = 1.000, a = 0.96 }
        end
    elseif active then
        bg, edge, text = colors.pillActive, colors.pillEdgeActive, colors.text
    elseif hover then
        bg, edge, text = colors.pillHover, colors.pillEdgeHover, colors.text
    else
        bg, edge, text = colors.pillBase, colors.pillEdge, { r = 0.820, g = 0.890, b = 1.000, a = 0.94 }
    end

    GradientParts(btn._mcdmFill, bg, 0.14, -0.20)
    ColorParts(btn._mcdmEdge, edge)
    if btn._mcdmLabel and btn._mcdmLabel.SetTextColor then
        btn._mcdmLabel:SetTextColor(text.r, text.g, text.b, text.a or 1)
    end
end

function UI.StyleButton(btn, role, isNav)
    if not btn then return btn end
    if btn._mcdmButtonSkinned then
        if role then btn._mcdmRole = role end
        if isNav ~= nil then btn._mcdmNavItem = isNav and true or nil end
        PaintButton(btn)
        return btn
    end

    local label = btn.GetFontString and btn:GetFontString()
    if not label then
        label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", btn, "LEFT", 10, 0)
        label:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
        label:SetJustifyH("CENTER")
        if btn.SetFontString then btn:SetFontString(label) end
    end
    HideNativeTextures(btn, { [label] = true })
    btn._mcdmFill, btn._mcdmEdge = UI.CreateSuperellipseLayers(btn, "_mcdmBtn", 2, "BACKGROUND", "BORDER")
    btn._mcdmLabel = label
    btn._mcdmRole = role or btn._mcdmRole
    btn._mcdmNavItem = isNav and true or btn._mcdmNavItem
    btn._mcdmButtonSkinned = true

    if label.ClearAllPoints then
        label:ClearAllPoints()
        label:SetPoint("LEFT", btn, "LEFT", btn._mcdmNavItem and 12 or 10, 0)
        label:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
        label:SetJustifyH(btn._mcdmNavItem and "LEFT" or "CENTER")
    end
    label:SetFontObject("GameFontHighlightSmall")

    function btn:SetActive(active)
        self._mcdmActive = active and true or nil
        PaintButton(self)
    end
    function btn:RefreshVisual()
        PaintButton(self)
    end
    function btn:SetEnabled(enabled)
        if enabled then
            if self.Enable then self:Enable() end
        else
            if self.Disable then self:Disable() end
        end
        PaintButton(self)
    end

    btn:HookScript("OnEnter", function(self) self._mcdmHover = true; PaintButton(self) end)
    btn:HookScript("OnLeave", function(self) self._mcdmHover = nil; PaintButton(self) end)
    btn:HookScript("OnEnable", PaintButton)
    btn:HookScript("OnDisable", PaintButton)
    PaintButton(btn)
    return btn
end

function UI.CreateModernButton(parent, text, width, height, role)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 120, height or 24)
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", btn, "LEFT", 10, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
    label:SetJustifyH("CENTER")
    if btn.SetFontString then btn:SetFontString(label) end
    btn:SetText(text or "")
    UI.StyleButton(btn, role)
    return btn
end

local function PaintCloseButton(btn, hover, down)
    if not btn then return end
    local alpha = (btn.IsEnabled and not btn:IsEnabled()) and 0.42 or 1
    local fillColor
    if down then
        fillColor = { r = 0.310, g = 0.050, b = 0.070, a = 0.98 * alpha }
    elseif hover then
        fillColor = { r = 0.230, g = 0.045, b = 0.065, a = 0.96 * alpha }
    else
        fillColor = { r = 0.075, g = 0.080, b = 0.125, a = 0.92 * alpha }
    end
    ColorParts(btn._mcdmCloseFill, fillColor)
    ColorParts(btn._mcdmCloseEdge, (hover or down) and THEME.colors.danger or THEME.colors.borderSoft, alpha)

    local lr, lg, lb = 1.00, hover and 0.88 or 0.72, hover and 0.86 or 0.78
    if btn._mcdmCloseLineA and btn._mcdmCloseLineA.SetVertexColor then btn._mcdmCloseLineA:SetVertexColor(lr, lg, lb, alpha) end
    if btn._mcdmCloseLineB and btn._mcdmCloseLineB.SetVertexColor then btn._mcdmCloseLineB:SetVertexColor(lr, lg, lb, alpha) end
end

function UI.CreateCloseButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(24, 24)
    btn._mcdmCloseFill, btn._mcdmCloseEdge = UI.CreateSuperellipseLayers(btn, "_mcdmClose", 2, "BACKGROUND", "BORDER")

    local lineA = btn:CreateTexture(nil, "ARTWORK")
    ColorLineTexture(lineA, THEME.colors.text, 0.85)
    lineA:SetSize(12, 2)
    lineA:SetPoint("CENTER", btn, "CENTER", 0, 0)
    if lineA.SetRotation then lineA:SetRotation(0.785398) end

    local lineB = btn:CreateTexture(nil, "ARTWORK")
    ColorLineTexture(lineB, THEME.colors.text, 0.85)
    lineB:SetSize(12, 2)
    lineB:SetPoint("CENTER", btn, "CENTER", 0, 0)
    if lineB.SetRotation then lineB:SetRotation(-0.785398) end

    btn._mcdmCloseLineA = lineA
    btn._mcdmCloseLineB = lineB
    btn:SetScript("OnEnter", function(self) self._mcdmCloseHover = true; PaintCloseButton(self, true, self._mcdmCloseDown) end)
    btn:SetScript("OnLeave", function(self) self._mcdmCloseHover = nil; self._mcdmCloseDown = nil; PaintCloseButton(self, false, false) end)
    btn:SetScript("OnMouseDown", function(self) self._mcdmCloseDown = true; PaintCloseButton(self, self._mcdmCloseHover, true) end)
    btn:SetScript("OnMouseUp", function(self) self._mcdmCloseDown = nil; PaintCloseButton(self, self._mcdmCloseHover, false) end)
    btn:SetScript("OnEnable", function(self) PaintCloseButton(self, self._mcdmCloseHover, self._mcdmCloseDown) end)
    btn:SetScript("OnDisable", function(self) PaintCloseButton(self, false, false) end)
    PaintCloseButton(btn, false, false)
    return btn
end

local function PaintWindowControlButton(btn, hover, down)
    if not btn then return end
    local alpha = (btn.IsEnabled and not btn:IsEnabled()) and 0.42 or 1
    local fillColor
    if down then
        fillColor = { r = 0.050, g = 0.070, b = 0.130, a = 0.98 * alpha }
    elseif hover then
        fillColor = { r = 0.075, g = 0.095, b = 0.175, a = 0.96 * alpha }
    else
        fillColor = { r = 0.075, g = 0.080, b = 0.125, a = 0.92 * alpha }
    end
    ColorParts(btn._mcdmControlFill, fillColor)
    ColorParts(btn._mcdmControlEdge, (hover or down) and THEME.colors.accent or THEME.colors.borderSoft, (hover or down) and (0.86 * alpha) or (0.70 * alpha))

    local active = hover or down
    local lineColor = active and THEME.colors.accent or { r = 0.62, g = 0.74, b = 0.98, a = 0.88 }
    local lineAlpha = active and alpha or (0.88 * alpha)
    if btn._mcdmControlLines then
        for i = 1, #btn._mcdmControlLines do
            local line = btn._mcdmControlLines[i]
            if line and line.SetVertexColor then
                line:SetVertexColor(lineColor.r, lineColor.g, lineColor.b, lineAlpha)
            end
        end
    end
end

local function SetWindowControlIcon(btn, kind)
    if not btn then return end
    btn._mcdmControlKind = kind
    btn._mcdmControlLines = btn._mcdmControlLines or {}
    for i = 1, #btn._mcdmControlLines do
        btn._mcdmControlLines[i]:Hide()
    end

    local function Line(index, w, h, x, y)
        local line = btn._mcdmControlLines[index]
        if not line then
            line = btn:CreateTexture(nil, "ARTWORK")
            ColorLineTexture(line, THEME.colors.accent, 0.88)
            btn._mcdmControlLines[index] = line
        end
        line:ClearAllPoints()
        line:SetSize(w, h)
        line:SetPoint("CENTER", btn, "CENTER", x, y)
        if line.SetRotation then line:SetRotation(0) end
        line:Show()
        return line
    end

    if kind == "minimize" then
        Line(1, 12, 2, 0, -5)
    elseif kind == "restore" then
        Line(1, 9, 2, -2, 4)
        Line(2, 2, 8, 3, 0)
        Line(3, 9, 2, 2, 1)
        Line(4, 9, 2, 2, -5)
        Line(5, 2, 8, -3, -2)
        Line(6, 2, 8, 7, -2)
    else
        Line(1, 12, 2, 0, 5)
        Line(2, 12, 2, 0, -5)
        Line(3, 2, 12, -5, 0)
        Line(4, 2, 12, 5, 0)
    end
    PaintWindowControlButton(btn, btn._mcdmControlHover, btn._mcdmControlDown)
end

function UI.CreateWindowControlButton(parent, kind)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(24, 24)
    btn._mcdmControlFill, btn._mcdmControlEdge = UI.CreateSuperellipseLayers(btn, "_mcdmControl", 2, "BACKGROUND", "BORDER")
    btn.SetWindowControlIcon = SetWindowControlIcon
    btn:SetScript("OnEnter", function(self)
        self._mcdmControlHover = true
        PaintWindowControlButton(self, true, self._mcdmControlDown)
    end)
    btn:SetScript("OnLeave", function(self)
        self._mcdmControlHover = nil
        self._mcdmControlDown = nil
        PaintWindowControlButton(self, false, false)
    end)
    btn:SetScript("OnMouseDown", function(self)
        self._mcdmControlDown = true
        PaintWindowControlButton(self, self._mcdmControlHover, true)
    end)
    btn:SetScript("OnMouseUp", function(self)
        self._mcdmControlDown = nil
        PaintWindowControlButton(self, self._mcdmControlHover, false)
    end)
    btn:SetScript("OnEnable", function(self)
        PaintWindowControlButton(self, self._mcdmControlHover, self._mcdmControlDown)
    end)
    btn:SetScript("OnDisable", function(self)
        PaintWindowControlButton(self, false, false)
    end)
    SetWindowControlIcon(btn, kind or "maximize")
    return btn
end

function UI.RefreshWindowControls(frame)
    if not frame then return end
    if frame.maximizeButton and frame.maximizeButton.SetWindowControlIcon then
        frame.maximizeButton:SetWindowControlIcon(frame._mcdmWindowState == "maximized" and "restore" or "maximize")
    end
end

function UI.CreateActionButton(parent, text, width, height, role)
    return UI.CreateModernButton(parent, text, width, height, role)
end

function UI.CreateNavButton(parent, text, width, height)
    local btn = UI.CreateModernButton(parent, text, width, height)
    btn._mcdmNavItem = true
    btn._mcdmLabel:SetJustifyH("LEFT")
    btn._mcdmLabel:ClearAllPoints()
    btn._mcdmLabel:SetPoint("LEFT", btn, "LEFT", 12, 0)
    btn._mcdmLabel:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
    PaintButton(btn)
    return btn
end

function UI.SkinEditBox(editBox)
    if not editBox or editBox._mcdmEditBoxSkinned then return editBox end
    editBox._mcdmEditBoxSkinned = true
    local fontString = editBox.GetFontString and editBox:GetFontString()
    HideNativeTextures(editBox, fontString and { [fontString] = true } or nil)
    if editBox.SetBackdrop then
        UI.ApplyBackdrop(editBox, { r = 0.020, g = 0.024, b = 0.046, a = 0.96 }, THEME.colors.borderSoft)
    else
        local bg = editBox:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.020, 0.024, 0.046, 0.96)
        editBox._mcdmEditBg = bg
    end
    local fill, edge = UI.CreateSuperellipseLayers(editBox, "_mcdmEdit", 2, "BACKGROUND", "BORDER")
    editBox._mcdmEditFill = fill
    editBox._mcdmEditEdge = edge
    if editBox.SetBackdropColor then
        editBox:SetBackdropColor(0, 0, 0, 0)
        editBox:SetBackdropBorderColor(0, 0, 0, 0)
    end
    GradientParts(fill, { r = 0.020, g = 0.024, b = 0.046, a = 0.96 }, 0.10, -0.16)
    ColorParts(edge, THEME.colors.borderSoft)
    if editBox.SetTextColor then
        editBox:SetTextColor(THEME.colors.text.r, THEME.colors.text.g, THEME.colors.text.b, THEME.colors.text.a)
    end
    if editBox.SetTextInsets then
        editBox:SetTextInsets(8, 8, 0, 0)
    end
    editBox:HookScript("OnEditFocusGained", function(self)
        GradientParts(self._mcdmEditFill, { r = 0.026, g = 0.036, b = 0.070, a = 0.98 }, 0.12, -0.14)
        ColorParts(self._mcdmEditEdge, THEME.colors.accent)
    end)
    editBox:HookScript("OnEditFocusLost", function(self)
        GradientParts(self._mcdmEditFill, { r = 0.020, g = 0.024, b = 0.046, a = 0.96 }, 0.10, -0.16)
        ColorParts(self._mcdmEditEdge, THEME.colors.borderSoft)
    end)
    return editBox
end

function UI.CreateModernEditBox(parent, width, height)
    local editBox = CreateFrame("EditBox", nil, parent)
    editBox:SetSize(width or 140, height or 22)
    editBox:SetFontObject("MidnightCDM_Font14")
    editBox:SetAutoFocus(false)
    editBox:SetTextInsets(8, 8, 0, 0)
    UI.SkinEditBox(editBox)
    return editBox
end

local function PaintCheckbox(checkButton)
    if not checkButton then return end
    local enabled = not (checkButton.IsEnabled and not checkButton:IsEnabled())
    local checked = checkButton.GetChecked and checkButton:GetChecked()
    local hover = checkButton._mcdmCheckboxHover
    local fill
    local edge

    if not enabled then
        fill = { r = 0.045, g = 0.050, b = 0.070, a = 0.54 }
        edge = { r = 0.130, g = 0.150, b = 0.220, a = 0.34 }
    elseif checked then
        fill = hover and { r = 0.115, g = 0.320, b = 0.470, a = 0.98 } or { r = 0.075, g = 0.245, b = 0.365, a = 0.96 }
        edge = THEME.colors.accent
    elseif hover then
        fill = THEME.colors.pillHover
        edge = THEME.colors.pillEdgeHover
    else
        fill = { r = 0.020, g = 0.024, b = 0.046, a = 0.96 }
        edge = THEME.colors.borderSoft
    end

    GradientParts(checkButton._mcdmCheckboxFill, fill, 0.10, -0.18)
    ColorParts(checkButton._mcdmCheckboxEdge, edge)
    if checkButton._mcdmCheckboxMark and checkButton._mcdmCheckboxMark.SetVertexColor then
        local c = enabled and THEME.colors.text or THEME.colors.dim
        checkButton._mcdmCheckboxMark:SetVertexColor(c.r, c.g, c.b, checked and (c.a or 1) or 0)
    end
end

function UI.StyleCheckbox(checkButton)
    if not checkButton then return checkButton end
    if checkButton._mcdmSwitchSkinned and UI.StyleSwitch then
        return UI.StyleSwitch(checkButton)
    end
    if checkButton._mcdmCheckboxSkinned then
        PaintCheckbox(checkButton)
        return checkButton
    end

    HideNativeTextures(checkButton)
    checkButton._mcdmCheckboxFill, checkButton._mcdmCheckboxEdge =
        UI.CreateSuperellipseLayers(checkButton, "_mcdmCheckbox", 2, "BACKGROUND", "BORDER")

    local mark = checkButton.GetCheckedTexture and checkButton:GetCheckedTexture()
    if not mark then
        mark = checkButton:CreateTexture(nil, "ARTWORK", nil, 3)
        if checkButton.SetCheckedTexture then
            checkButton:SetCheckedTexture(mark)
        end
    end
    mark:ClearAllPoints()
    mark:SetPoint("CENTER", checkButton, "CENTER", 0, 0)
    mark:SetSize(14, 14)
    if mark.SetAtlas then
        pcall(mark.SetAtlas, mark, "checkmark-minimal")
    elseif mark.SetTexture then
        mark:SetTexture(CDM_C.TEX_WHITE8X8)
    end
    if mark.SetAlpha then mark:SetAlpha(1) end
    checkButton._mcdmCheckboxMark = mark
    checkButton._mcdmCheckboxSkinned = true
    function checkButton:RefreshVisual()
        PaintCheckbox(self)
    end

    checkButton:HookScript("OnEnter", function(self)
        self._mcdmCheckboxHover = true
        PaintCheckbox(self)
    end)
    checkButton:HookScript("OnLeave", function(self)
        self._mcdmCheckboxHover = nil
        PaintCheckbox(self)
    end)
    checkButton:HookScript("OnClick", PaintCheckbox)
    checkButton:HookScript("OnEnable", PaintCheckbox)
    checkButton:HookScript("OnDisable", PaintCheckbox)
    hooksecurefunc(checkButton, "SetChecked", PaintCheckbox)
    PaintCheckbox(checkButton)
    return checkButton
end

local function PaintSwitch(checkButton)
    if not checkButton then return end
    local enabled = not (checkButton.IsEnabled and not checkButton:IsEnabled())
    local checked = checkButton.GetChecked and checkButton:GetChecked()
    local hover = checkButton._mcdmSwitchHover and true or false
    local pressed = checkButton._mcdmSwitchPressed and true or false
    local alpha = enabled and 1 or 0.45
    local bg = checked and { r = 0.020, g = 0.090, b = 0.135, a = 0.96 }
        or { r = 0.014, g = 0.022, b = 0.048, a = 0.96 }
    local edge = checked and { r = 0.160, g = 0.560, b = 0.760, a = 0.86 }
        or { r = 0.095, g = 0.145, b = 0.255, a = 0.82 }
    local mul = enabled and (pressed and 1.14 or hover and 1.08 or 1) or 1

    local fillColor = {
        r = min(bg.r * mul, 1),
        g = min(bg.g * mul, 1),
        b = min(bg.b * mul, 1),
        a = bg.a,
    }
    local edgeColor = {
        r = min(edge.r * mul, 1),
        g = min(edge.g * mul, 1),
        b = min(edge.b * mul, 1),
        a = edge.a,
    }
    if checkButton._mcdmSwitchFillTexture then
        SetRegionColor(checkButton._mcdmSwitchFillTexture, fillColor, alpha)
    else
        ColorParts(checkButton._mcdmSwitchFill, fillColor, alpha)
    end
    if checkButton._mcdmSwitchEdgeTexture then
        SetRegionColor(checkButton._mcdmSwitchEdgeTexture, edgeColor, alpha)
    else
        ColorParts(checkButton._mcdmSwitchEdge, edgeColor, alpha)
    end

    local knob = checkButton._mcdmSwitchKnob
    if knob then
        UseControlTexture(knob, THEME.media.switchKnob or THEME.media.sliderThumb or THEME.media.superellipse or THEME.media.white)
        knob:ClearAllPoints()
        knob:SetPoint(checked and "RIGHT" or "LEFT", checkButton, checked and "RIGHT" or "LEFT", checked and -2 or 2, 0)
        knob:SetSize((pressed and enabled) and 19 or 18, (pressed and enabled) and 19 or 18)
        if checked then
            knob:SetVertexColor(0.380, 0.760, 0.900, 1.00 * alpha)
        else
            knob:SetVertexColor(0.680, 0.760, 0.940, 1.00 * alpha)
        end
        if knob.SetAlpha then knob:SetAlpha(alpha) end
        knob:Show()
    end
    if checkButton._mcdmSwitchLabel and checkButton._mcdmSwitchLabel.SetTextColor then
        local c = enabled and (hover and THEME.colors.title or THEME.colors.text) or THEME.colors.dim
        checkButton._mcdmSwitchLabel:SetTextColor(c.r, c.g, c.b, c.a or 1)
    end
end

function UI.StyleSwitch(checkButton)
    if not checkButton then return checkButton end
    if checkButton._mcdmSwitchSkinned then
        PaintSwitch(checkButton)
        return checkButton
    end

    HideNativeTextures(checkButton)
    checkButton:SetSize(44, 22)
    if checkButton.SetHitRectInsets then
        checkButton:SetHitRectInsets(-2, -2, -4, -4)
    end
    local edge = UseControlTexture(checkButton:CreateTexture(nil, "BACKGROUND", nil, 0), THEME.media.switchTrack or THEME.media.superellipse or THEME.media.white)
    edge:SetAllPoints(checkButton)
    checkButton._mcdmSwitchEdgeTexture = edge

    local fill = UseControlTexture(checkButton:CreateTexture(nil, "BACKGROUND", nil, 1), THEME.media.switchTrack or THEME.media.superellipse or THEME.media.white)
    fill:SetPoint("TOPLEFT", checkButton, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", checkButton, "BOTTOMRIGHT", -1, 1)
    checkButton._mcdmSwitchFillTexture = fill

    local knob = UseControlTexture(checkButton:CreateTexture(nil, "OVERLAY", nil, 4), THEME.media.switchKnob or THEME.media.sliderThumb or THEME.media.superellipse or THEME.media.white)
    checkButton._mcdmSwitchKnob = knob
    checkButton._mcdmSwitchSkinned = true
    if not checkButton._mcdmSwitchRawSetChecked then
        local rawSetChecked = checkButton.SetChecked
        checkButton._mcdmSwitchRawSetChecked = rawSetChecked
        checkButton.SetChecked = function(self, value)
            rawSetChecked(self, value and true or false)
            PaintSwitch(self)
        end
    end

    function checkButton:RefreshVisual()
        PaintSwitch(self)
    end

    checkButton:HookScript("OnShow", function(self)
        HideNativeTextures(self)
        PaintSwitch(self)
    end)
    checkButton:HookScript("OnEnter", function(self)
        self._mcdmSwitchHover = true
        PaintSwitch(self)
    end)
    checkButton:HookScript("OnLeave", function(self)
        self._mcdmSwitchHover = nil
        self._mcdmSwitchPressed = nil
        PaintSwitch(self)
    end)
    checkButton:HookScript("OnMouseDown", function(self)
        self._mcdmSwitchPressed = true
        PaintSwitch(self)
    end)
    checkButton:HookScript("OnMouseUp", function(self)
        self._mcdmSwitchPressed = nil
        PaintSwitch(self)
    end)
    checkButton:HookScript("OnClick", PaintSwitch)
    checkButton:HookScript("OnEnable", PaintSwitch)
    checkButton:HookScript("OnDisable", function(self)
        self._mcdmSwitchHover = nil
        self._mcdmSwitchPressed = nil
        PaintSwitch(self)
    end)
    PaintSwitch(checkButton)
    return checkButton
end

function UI.StyleScrollFrame(scrollFrame)
    if not scrollFrame or scrollFrame._mcdmScrollSkinned then return scrollFrame end
    scrollFrame._mcdmScrollSkinned = true

    local bar = scrollFrame.ScrollBar
    if not bar and scrollFrame.GetName then
        local name = scrollFrame:GetName()
        bar = name and _G[name .. "ScrollBar"]
    end
    if not bar then return scrollFrame end

    local thumb = bar.GetThumbTexture and bar:GetThumbTexture() or bar.ThumbTexture
    if thumb and thumb.SetTexture then
        thumb:SetTexture(CDM_C.TEX_WHITE8X8)
        thumb:SetVertexColor(THEME.colors.accent.r, THEME.colors.accent.g, THEME.colors.accent.b, 0.78)
        if thumb.SetWidth then thumb:SetWidth(5) end
    end

    HideNativeTextures(bar, thumb and { [thumb] = true } or nil)
    if bar.SetBackdrop then
        UI.ApplyBackdrop(bar, { r = 0.018, g = 0.022, b = 0.040, a = 0.60 }, THEME.colors.borderSoft)
    end
    return scrollFrame
end

local function PaintDropdown(dropdown, hover)
    if not dropdown then return end
    local fill = dropdown._mcdmDropdownFill
    local edge = dropdown._mcdmDropdownEdge
    local bg = hover and THEME.colors.pillHover or { r = 0.020, g = 0.024, b = 0.046, a = 0.96 }
    local br = hover and THEME.colors.pillEdgeHover or THEME.colors.borderSoft
    GradientParts(fill, bg, 0.12, -0.18)
    ColorParts(edge, br)
    if dropdown._mcdmDropdownChevron then
        local c = hover and THEME.colors.accent or THEME.colors.dim
        dropdown._mcdmDropdownChevron:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    end
end

function UI.StyleDropdown(dropdown)
    if not dropdown then return dropdown end
    if dropdown._mcdmDropdownSkinned then
        PaintDropdown(dropdown, dropdown._mcdmDropdownHover)
        return dropdown
    end

    HideNativeTextures(dropdown)
    dropdown._mcdmDropdownFill, dropdown._mcdmDropdownEdge =
        UI.CreateSuperellipseLayers(dropdown, "_mcdmDropdown", 2, "BACKGROUND", "BORDER")

    if dropdown.GetRegions then
        for _, region in ipairs({ dropdown:GetRegions() }) do
            if region and region.SetTextColor then
                if region.SetAlpha then region:SetAlpha(1) end
                if region.Show then region:Show() end
                region:SetTextColor(THEME.colors.text.r, THEME.colors.text.g, THEME.colors.text.b, THEME.colors.text.a)
                if region.SetPoint and region.ClearAllPoints then
                    region:ClearAllPoints()
                    region:SetPoint("LEFT", dropdown, "LEFT", 10, 0)
                    region:SetPoint("RIGHT", dropdown, "RIGHT", -28, 0)
                    if region.SetJustifyH then region:SetJustifyH("LEFT") end
                end
            end
        end
    end

    local chevron = dropdown:CreateTexture(nil, "ARTWORK", nil, 4)
    chevron:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    chevron:SetSize(11, 11)
    chevron:SetPoint("RIGHT", dropdown, "RIGHT", -10, 0)
    if chevron.SetRotation then chevron:SetRotation(1.570796) end
    dropdown._mcdmDropdownChevron = chevron
    dropdown._mcdmDropdownSkinned = true

    dropdown:HookScript("OnEnter", function(self)
        self._mcdmDropdownHover = true
        PaintDropdown(self, true)
    end)
    dropdown:HookScript("OnLeave", function(self)
        self._mcdmDropdownHover = nil
        PaintDropdown(self, false)
    end)
    dropdown:HookScript("OnEnable", function(self) PaintDropdown(self, self._mcdmDropdownHover) end)
    dropdown:HookScript("OnDisable", function(self) PaintDropdown(self, false) end)

    PaintDropdown(dropdown, false)
    return dropdown
end

local activeDropdown

local function CloseDropdown(dropdown)
    dropdown = dropdown or activeDropdown
    if dropdown and dropdown._mcdmMenuFrame then dropdown._mcdmMenuFrame:Hide() end
    if activeDropdown == dropdown then activeDropdown = nil end
end

local function FetchMediaPath(mediaType, name, noError)
    if not (LSM and mediaType and name) then return nil end
    local ok, path = pcall(LSM.Fetch, LSM, mediaType, name, noError == true)
    return ok and path or nil
end

local function ApplyDropdownTextFont(fontString, fontPath, size, outline)
    if not fontString then return false end
    size = size or 13
    outline = outline or ""
    if fontPath and fontString.SetFont then
        local ok = fontString:SetFont(fontPath, size, outline)
        if ok then return true end
    end
    if fontString.SetFontObject then
        fontString:SetFontObject("MidnightCDM_Font12")
    end
    return false
end

local function ApplyDropdownSelectedFontPreview(dropdown, text)
    if not (dropdown and dropdown._mcdmFontPreview and dropdown._mcdmText) then return end
    local fontName = text or dropdown:GetDefaultText()
    local fontPath = FetchMediaPath("font", fontName, true)
    ApplyDropdownTextFont(dropdown._mcdmText, fontPath, 13, dropdown._mcdmFontPreviewOutline)
end

local function DecorateMenuNode(node)
    function node:CreateButton(text, callback)
        local child = { kind = "button", text = text or "", callback = callback, items = {}, parent = self }
        DecorateMenuNode(child)
        self.items[#self.items + 1] = child
        return child
    end
    function node:CreateRadio(text, isSelected, callback)
        local child = { kind = "radio", text = text or "", isSelected = isSelected, callback = callback, items = {}, parent = self }
        DecorateMenuNode(child)
        self.items[#self.items + 1] = child
        return child
    end
    function node:CreateDivider()
        local child = { kind = "divider" }
        self.items[#self.items + 1] = child
        return child
    end
    function node:SetScrollMode(height)
        self.scrollMode = tonumber(height) or 500
    end
end

local function CreateMenuRoot()
    local root = { kind = "root", items = {} }
    DecorateMenuNode(root)
    return root
end

local function MenuNodeHasSelected(node)
    if not node then return false end
    if node.kind == "radio" and type(node.isSelected) == "function" then
        local ok, selected = pcall(node.isSelected)
        if ok and selected == true then return true end
    end
    if not node.items then return false end
    for i = 1, #node.items do
        if MenuNodeHasSelected(node.items[i]) then return true end
    end
    return false
end

local function FlattenMenu(node, out, depth, expanded, prefix)
    if not node or not node.items then return end
    depth = depth or 0
    expanded = expanded or {}
    prefix = prefix or ""
    for i = 1, #node.items do
        local item = node.items[i]
        local path = prefix ~= "" and (prefix .. "." .. i) or tostring(i)
        local hasChildren = item.items and #item.items > 0
        local open = hasChildren and (expanded[path] == true or MenuNodeHasSelected(item)) or false
        item._mcdmPath = path
        item._mcdmDepth = depth
        item._mcdmHasChildren = hasChildren == true
        item._mcdmExpanded = open == true
        out[#out + 1] = item
        if hasChildren and open then
            FlattenMenu(item, out, depth + 1, expanded, path)
        end
    end
end

local function PaintDropdownItem(button)
    if not button then return end
    if button._mcdmDivider then
        if button.line then button.line:SetVertexColor(THEME.colors.borderSoft.r, THEME.colors.borderSoft.g, THEME.colors.borderSoft.b, 0.55) end
        return
    end
    local selected = button._mcdmSelected == true
    local hover = button._mcdmHover == true
    if selected then
        button:SetBackdropColor(0.11, 0.28, 0.62, 0.94)
        button:SetBackdropBorderColor(THEME.colors.accent.r, THEME.colors.accent.g, THEME.colors.accent.b, 0.86)
        button.text:SetTextColor(1, 1, 1, 1)
    elseif hover then
        button:SetBackdropColor(0.055, 0.080, 0.145, 0.94)
        button:SetBackdropBorderColor(0.18, 0.34, 0.70, 0.74)
        button.text:SetTextColor(0.90, 0.94, 1.00, 1)
    else
        button:SetBackdropColor(0.014, 0.018, 0.033, 0.96)
        button:SetBackdropBorderColor(0.04, 0.06, 0.10, 0.70)
        button.text:SetTextColor(THEME.colors.text.r, THEME.colors.text.g, THEME.colors.text.b, THEME.colors.text.a or 1)
    end
end

local function EnsureDropdownMenu(dropdown)
    if dropdown._mcdmMenuFrame then return dropdown._mcdmMenuFrame end

    local menu = CreateFrame("Frame", nil, UIParent or dropdown, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(930)
    menu:SetBackdrop({ bgFile = CDM_C.TEX_WHITE8X8, edgeFile = CDM_C.TEX_WHITE8X8, edgeSize = 1 })
    menu:SetBackdropColor(0.010, 0.014, 0.026, 0.98)
    menu:SetBackdropBorderColor(0.10, 0.16, 0.28, 0.95)
    if menu.SetClampedToScreen then menu:SetClampedToScreen(true) end
    menu:EnableMouse(true)
    menu:Hide()

    local scroll = CreateFrame("ScrollFrame", nil, menu)
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -4, 4)
    scroll:EnableMouseWheel(true)

    local child = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(child)
    menu.scroll = scroll
    menu.child = child
    menu.buttons = {}

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = self._mcdmMaxScroll or 0
        if maxScroll <= 0 then return end
        local nextValue = (self:GetVerticalScroll() or 0) - ((delta or 0) * 28)
        if nextValue < 0 then nextValue = 0 elseif nextValue > maxScroll then nextValue = maxScroll end
        self:SetVerticalScroll(nextValue)
    end)
    menu:SetScript("OnHide", function()
        dropdown._mcdmDropdownOpen = nil
        PaintDropdown(dropdown, dropdown._mcdmDropdownHover)
        if activeDropdown == dropdown then activeDropdown = nil end
    end)

    dropdown._mcdmMenuFrame = menu
    return menu
end

local function EnsureDropdownButton(menu, index)
    local button = menu.buttons[index]
    if button then return button end

    button = CreateFrame("Button", nil, menu.child, "BackdropTemplate")
    button:SetBackdrop({ bgFile = CDM_C.TEX_WHITE8X8, edgeFile = CDM_C.TEX_WHITE8X8, edgeSize = 1 })
    button.text = button:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font12")
    button.text:SetPoint("LEFT", button, "LEFT", 8, 0)
    button.text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    button.text:SetJustifyH("LEFT")
    button.line = button:CreateTexture(nil, "ARTWORK")
    button.line:SetTexture(CDM_C.TEX_WHITE8X8)
    button.line:SetPoint("LEFT", button, "LEFT", 6, 0)
    button.line:SetPoint("RIGHT", button, "RIGHT", -6, 0)
    button.line:SetHeight(1)
    button:SetScript("OnEnter", function(self)
        self._mcdmHover = true
        PaintDropdownItem(self)
    end)
    button:SetScript("OnLeave", function(self)
        self._mcdmHover = nil
        PaintDropdownItem(self)
    end)
    menu.buttons[index] = button
    return button
end

local function IsMenuItemSelected(item)
    if item and type(item.isSelected) == "function" then
        local ok, selected = pcall(item.isSelected)
        return ok and selected == true
    end
    return false
end

local function RenderDropdownMenu(dropdown)
    local root = CreateMenuRoot()
    if type(dropdown._mcdmSetupMenu) == "function" then
        dropdown._mcdmSetupMenu(dropdown, root)
    end

    local rows = {}
    dropdown._mcdmExpandedMenuItems = dropdown._mcdmExpandedMenuItems or {}
    FlattenMenu(root, rows, 0, dropdown._mcdmExpandedMenuItems)
    if #rows == 0 then
        rows[1] = { kind = "button", text = "No options", items = {}, _mcdmDepth = 0 }
    end

    local menu = EnsureDropdownMenu(dropdown)
    local width = (dropdown.GetWidth and dropdown:GetWidth()) or dropdown._mcdmDropdownWidth or 190
    if width < 120 then width = 120 end

    local itemHeight = 22
    local dividerHeight = 9
    local contentHeight = 0
    for i = 1, #rows do
        contentHeight = contentHeight + (rows[i].kind == "divider" and dividerHeight or itemHeight)
    end
    local requestedMax = tonumber(root.scrollMode) or 360
    local maxHeight = max(80, min(520, requestedMax))
    local menuHeight = min(contentHeight + 8, maxHeight)
    menu:SetSize(width, menuHeight)
    menu.child:SetSize(width - 8, max(contentHeight, menuHeight - 8))
    menu.scroll._mcdmMaxScroll = max(0, contentHeight - (menuHeight - 8))
    menu.scroll:SetVerticalScroll(0)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -3)

    local y = 0
    for i = 1, max(#rows, #menu.buttons) do
        local button = menu.buttons[i]
        if i <= #rows then
            local item = rows[i]
            button = EnsureDropdownButton(menu, i)
            local height = item.kind == "divider" and dividerHeight or itemHeight
            button:SetSize(width - 8, height - 2)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", menu.child, "TOPLEFT", 0, -y)
            y = y + height

            button._mcdmDivider = item.kind == "divider"
            button._mcdmSelected = item.kind == "radio" and IsMenuItemSelected(item)
            button._mcdmCallback = item.callback
            button.line:SetShown(item.kind == "divider")
            button.text:SetShown(item.kind ~= "divider")
            if item.kind ~= "divider" then
                local depth = tonumber(item._mcdmDepth) or 0
                local prefix = ""
                if item.kind == "radio" then prefix = button._mcdmSelected and "* " or "  " end
                if item.items and #item.items > 0 then prefix = prefix .. (item._mcdmExpanded and "v " or "> ") end
                ApplyDropdownTextFont(button.text, item._mcdmFontPath, item._mcdmFontPreviewSize or 13, item._mcdmFontPreviewOutline)
                button.text:ClearAllPoints()
                button.text:SetPoint("LEFT", button, "LEFT", 8 + (depth * 14), 0)
                button.text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
                button.text:SetText(prefix .. tostring(item.text or ""))
            end
            button._mcdmPath = item._mcdmPath
            button._mcdmHasChildren = item._mcdmHasChildren == true
            button:SetScript("OnClick", function(self)
                if self._mcdmHasChildren and type(self._mcdmCallback) ~= "function" then
                    local path = self._mcdmPath
                    if path then
                        dropdown._mcdmExpandedMenuItems = dropdown._mcdmExpandedMenuItems or {}
                        dropdown._mcdmExpandedMenuItems[path] = dropdown._mcdmExpandedMenuItems[path] ~= true
                    end
                    RenderDropdownMenu(dropdown):Show()
                    return
                end
                local cb = self._mcdmCallback
                if type(cb) == "function" then
                    cb()
                    CloseDropdown(dropdown)
                end
            end)
            PaintDropdownItem(button)
            button:Show()
        elseif button then
            button:Hide()
        end
    end

    return menu
end

function UI.CreateDropdown(parent, width, defaultText)
    local dropdown = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dropdown:SetSize(width or 190, 24)
    dropdown._mcdmDropdownWidth = width or 190

    dropdown._mcdmText = dropdown:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font12")
    dropdown._mcdmText:SetPoint("LEFT", dropdown, "LEFT", 10, 0)
    dropdown._mcdmText:SetPoint("RIGHT", dropdown, "RIGHT", -28, 0)
    dropdown._mcdmText:SetJustifyH("LEFT")
    dropdown._mcdmText:SetText(defaultText or "")
    dropdown._mcdmText:SetTextColor(THEME.colors.text.r, THEME.colors.text.g, THEME.colors.text.b, THEME.colors.text.a or 1)

    function dropdown:SetDefaultText(text)
        self._mcdmText:SetText(text or "")
        ApplyDropdownSelectedFontPreview(self, text)
    end
    function dropdown:OverrideText(text)
        self:SetDefaultText(text)
    end
    function dropdown:GetDefaultText()
        return self._mcdmText:GetText()
    end
    function dropdown:SetupMenu(callback)
        self._mcdmSetupMenu = callback
    end
    function dropdown:CloseMenu()
        CloseDropdown(self)
    end
    function dropdown:OpenMenu()
        if activeDropdown and activeDropdown ~= self then CloseDropdown(activeDropdown) end
        activeDropdown = self
        self._mcdmDropdownOpen = true
        PaintDropdown(self, true)
        RenderDropdownMenu(self):Show()
    end

    dropdown:SetScript("OnClick", function(self)
        if self._mcdmMenuFrame and self._mcdmMenuFrame:IsShown() then
            CloseDropdown(self)
        else
            self:OpenMenu()
        end
    end)
    dropdown:SetScript("OnHide", function(self)
        CloseDropdown(self)
    end)

    UI.StyleDropdown(dropdown)
    return dropdown
end

function UI.StyleFrameTree(root, depth, visited)
    if not (root and root.GetChildren) then return end
    depth = tonumber(depth) or 0
    if depth > 12 then return end
    visited = visited or {}
    if visited[root] then return end
    visited[root] = true
    for _, child in ipairs({ root:GetChildren() }) do
        local objectType = child.GetObjectType and child:GetObjectType()
        if objectType == "ScrollFrame" then
            UI.StyleScrollFrame(child)
        elseif objectType == "Slider" then
            UI.StyleSlider(child)
        elseif objectType == "CheckButton" and child._mcdmSwitchSkinned then
            UI.StyleSwitch(child)
        elseif objectType == "CheckButton" and IsCompactSkinTarget(child, 48, 48) then
            UI.StyleCheckbox(child)
        elseif (child.SetupMenu or child.SetDefaultText) and IsCompactSkinTarget(child, 520, 44) then
            UI.StyleDropdown(child)
        elseif objectType == "Button" and child.GetFontString and child:GetFontString()
            and IsCompactSkinTarget(child, 520, 44) then
            UI.StyleButton(child)
        elseif objectType == "EditBox" and IsCompactSkinTarget(child, 520, 44) then
            UI.SkinEditBox(child)
        end
        UI.StyleFrameTree(child, depth + 1, visited)
    end
end

local colorSwatchesByKey = {}

local function BroadcastSwatchColor(key, r, g, b, a)
    local swatches = colorSwatchesByKey[key]
    if not swatches then return end
    for swatchFrame in pairs(swatches) do
        swatchFrame:UpdateColor(r, g, b, a)
    end
end

local function TriggerConfigRefresh(scope)
    API:Refresh(scope)
end

function UI.CreateColorSwatch(parent, label, key, scope)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(250, 30)

    local text = frame:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    text:SetPoint("LEFT", 0, 0)
    text:SetText(label)
    UI.SetTextSubtle(text)

    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetSize(20, 20)
    button:SetPoint("LEFT", 140, 0)
    button:SetBackdrop({
        edgeFile = CDM_C.TEX_WHITE8X8, edgeSize = 1,
        bgFile = CDM_C.TEX_WHITE8X8,
    })

    local color = CDM.db[key] or CDM.defaults[key] or CDM.defaults.borderColor
    button:SetBackdropColor(color.r, color.g, color.b, color.a)
    button:SetBackdropBorderColor(THEME.colors.borderSoft.r, THEME.colors.borderSoft.g, THEME.colors.borderSoft.b, 1)

    if not colorSwatchesByKey[key] then
        colorSwatchesByKey[key] = setmetatable({}, { __mode = "k" })
    end
    colorSwatchesByKey[key][frame] = true

    function frame:UpdateColor(r, g, b, a)
        button:SetBackdropColor(r, g, b, a)
        if frame.OnChange then
            frame.OnChange(r, g, b, a)
        end
    end

    local enabledFlag = true

    button:SetScript("OnClick", function()
        if not enabledFlag then return end
        local color = CDM.db[key] or CDM.defaults[key] or CDM.defaults.borderColor
        local function ApplyPickedColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            CDM.db[key] = { r = r, g = g, b = b, a = a }
            BroadcastSwatchColor(key, r, g, b, a)
            TriggerConfigRefresh(scope)
        end

        local info = {
            swatchFunc = ApplyPickedColor,
            opacityFunc = ApplyPickedColor,
            cancelFunc = function(prev)
                CDM.db[key] = prev
                BroadcastSwatchColor(key, prev.r, prev.g, prev.b, prev.a)
                TriggerConfigRefresh(scope)
            end,
            r = color.r, g = color.g, b = color.b, opacity = color.a,
            hasOpacity = true,
            previousValues = { r = color.r, g = color.g, b = color.b, a = color.a }
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    function frame:SetEnabled(enabled)
        enabledFlag = enabled and true or false
        button:EnableMouse(enabledFlag)
        local v = enabledFlag and 1 or 0.5
        text:SetTextColor(v, v, v, 1)
        frame:SetAlpha(enabledFlag and 1 or 0.5)
    end

    return frame
end

local function CreateSectionHeader(parent, text, anchorFrame, yOffset, fontObject, anchoredOffset, topOffset)
    local header = parent:CreateFontString(nil, "ARTWORK", fontObject)
    if anchorFrame then
        header:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, yOffset or anchoredOffset)
    else
        header:SetPoint("TOPLEFT", 0, yOffset or topOffset)
    end
    header:SetText(text)
    header:SetTextColor(THEME.colors.accent.r, THEME.colors.accent.g, THEME.colors.accent.b, THEME.colors.accent.a or 1)
    return header
end

function UI.CreateSimpleColorPicker(parent, initialColor, onChange, hasOpacity)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(20, 20)
    button:SetBackdrop({
        edgeFile = CDM_C.TEX_WHITE8X8, edgeSize = 1,
        bgFile = CDM_C.TEX_WHITE8X8,
    })

    local color = initialColor
        and { r = initialColor.r, g = initialColor.g, b = initialColor.b, a = initialColor.a or 1 }
        or { r = 1, g = 1, b = 1, a = 1 }

    local function DrawSwatch()
        local drawA = hasOpacity and color.a or 1
        button:SetBackdropColor(color.r, color.g, color.b, drawA)
    end

    DrawSwatch()
    button:SetBackdropBorderColor(THEME.colors.borderSoft.r, THEME.colors.borderSoft.g, THEME.colors.borderSoft.b, 1)

    function button:UpdateColor(r, g, b, a)
        color.r, color.g, color.b = r, g, b
        if a ~= nil then color.a = a end
        DrawSwatch()
    end

    button:SetScript("OnClick", function()
        local prevR, prevG, prevB, prevA = color.r, color.g, color.b, color.a
        local info = {
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = hasOpacity and ColorPickerFrame:GetColorAlpha() or 1
                button:UpdateColor(r, g, b, a)
                if onChange then onChange(r, g, b, a) end
            end,
            opacityFunc = function()
                if not hasOpacity then return end
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                button:UpdateColor(r, g, b, a)
                if onChange then onChange(r, g, b, a) end
            end,
            cancelFunc = function()
                button:UpdateColor(prevR, prevG, prevB, prevA)
                if onChange then onChange(prevR, prevG, prevB, prevA) end
            end,
            r = color.r, g = color.g, b = color.b,
            hasOpacity = hasOpacity and true or false,
            opacity = color.a,
            previousValues = { r = prevR, g = prevG, b = prevB, opacity = prevA },
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    return button
end

local SLIDER_STYLE_KEEP_KEYS = {
    "_mcdmTrack", "_mcdmTrackTop", "_mcdmTrackBottom", "_mcdmFill", "_mcdmFillGlow", "_mcdmThumb",
}
local SLIDER_NATIVE_SUFFIXES = { "Left", "Middle", "Right", "Text", "Low", "High" }

local function IsTextureRegion(region)
    if not region then return false end
    if region.IsObjectType then return region:IsObjectType("Texture") and true or false end
    return region.GetObjectType and region:GetObjectType() == "Texture"
end

local function HideNativeSliderParts(slider)
    if not slider then return end
    local keep = {}
    local nativeThumb = slider.GetThumbTexture and slider:GetThumbTexture()
    if nativeThumb then keep[nativeThumb] = true end
    for i = 1, #SLIDER_STYLE_KEEP_KEYS do
        local region = slider[SLIDER_STYLE_KEEP_KEYS[i]]
        if region then keep[region] = true end
    end
    if slider.GetRegions then
        for _, region in ipairs({ slider:GetRegions() }) do
            if IsTextureRegion(region) and not keep[region] then
                if region.SetAlpha then region:SetAlpha(0) end
                if region.Hide then region:Hide() end
            end
        end
    end
    local name = slider.GetName and slider:GetName()
    if name then
        for _, suffix in ipairs(SLIDER_NATIVE_SUFFIXES) do
            local region = _G[name .. suffix]
            if region then
                if region.SetText then region:SetText("") end
                if region.SetAlpha then region:SetAlpha(0) end
                if region.Hide then region:Hide() end
            end
        end
    end
end

local function SliderValuePercent(slider)
    if not (slider and slider.GetMinMaxValues and slider.GetValue) then return 0 end
    local minV, maxV = slider:GetMinMaxValues()
    local span = (tonumber(maxV) or 0) - (tonumber(minV) or 0)
    if span <= 0 then return 0 end
    local pct = ((tonumber(slider:GetValue()) or 0) - (tonumber(minV) or 0)) / span
    if pct < 0 then return 0 end
    if pct > 1 then return 1 end
    return pct
end

local function UpdateSliderVisual(slider)
    if not slider then return end
    local width = (slider.GetWidth and slider:GetWidth()) or 0
    local pct = SliderValuePercent(slider)
    local fillW = math.max(1, math.floor(math.max(1, width - 2) * pct + 0.5))
    if slider._mcdmFill then slider._mcdmFill:SetWidth(fillW) end
    if slider._mcdmFillGlow then slider._mcdmFillGlow:SetWidth(fillW) end
    if slider._mcdmThumb then
        local x = 1 + math.max(1, width - 2) * pct
        slider._mcdmThumb:ClearAllPoints()
        slider._mcdmThumb:SetPoint("CENTER", slider, "LEFT", x, 0)
        slider._mcdmThumb:Show()
    end
end

function UI.StyleSlider(slider)
    if not slider then return slider end
    if slider.SetOrientation then slider:SetOrientation("HORIZONTAL") end
    if slider.SetThumbTexture and slider.GetThumbTexture and not slider:GetThumbTexture() then
        slider:SetThumbTexture(THEME.media.white or CDM_C.TEX_WHITE8X8)
    end
    HideNativeSliderParts(slider)

    if not slider._mcdmTrack and slider.CreateTexture then
        local track = slider:CreateTexture(nil, "BACKGROUND", nil, 1)
        track:SetHeight(8)
        track:SetPoint("LEFT", slider, "LEFT", 0, 0)
        track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
        slider._mcdmTrack = track

        local top = slider:CreateTexture(nil, "BORDER", nil, 1)
        top:SetHeight(1)
        top:SetPoint("LEFT", track, "LEFT", 0, 0)
        top:SetPoint("RIGHT", track, "RIGHT", 0, 0)
        top:SetPoint("TOP", track, "TOP", 0, 0)
        slider._mcdmTrackTop = top

        local bottom = slider:CreateTexture(nil, "BORDER", nil, 1)
        bottom:SetHeight(1)
        bottom:SetPoint("LEFT", track, "LEFT", 0, 0)
        bottom:SetPoint("RIGHT", track, "RIGHT", 0, 0)
        bottom:SetPoint("BOTTOM", track, "BOTTOM", 0, 0)
        slider._mcdmTrackBottom = bottom

        local fill = slider:CreateTexture(nil, "ARTWORK", nil, 1)
        fill:SetHeight(4)
        fill:SetPoint("LEFT", slider, "LEFT", 1, 0)
        slider._mcdmFill = fill

        local glow = slider:CreateTexture(nil, "OVERLAY", nil, 1)
        glow:SetHeight(8)
        glow:SetPoint("LEFT", slider, "LEFT", 1, 0)
        slider._mcdmFillGlow = glow

        local thumb = slider:CreateTexture(nil, "OVERLAY", nil, 4)
        thumb:SetTexture(THEME.media.sliderThumb or THEME.media.superellipse or THEME.media.white)
        thumb:SetTexCoord(0, 1, 0, 1)
        slider._mcdmThumb = thumb
    end

    local enabled = not (slider.IsEnabled and not slider:IsEnabled())
    local hover = slider._mcdmSliderHover and true or false
    local active = enabled and slider._mcdmSliderActive and true or false
    local alpha = enabled and 1 or 0.45
    local accent = THEME.colors.accent
    local edge = THEME.colors.border or THEME.colors.borderSoft

    if slider._mcdmTrack then
        local base = active and { r = 0.045, g = 0.058, b = 0.098, a = 0.98 * alpha }
            or { r = 0.035, g = 0.043, b = 0.078, a = 0.98 * alpha }
        ApplyTextureGradient(slider._mcdmTrack, "VERTICAL", ShadeColor(base, 0.10), ShadeColor(base, -0.18))
        slider._mcdmTrack:Show()
    end
    if slider._mcdmTrackTop then
        slider._mcdmTrackTop:SetColorTexture(edge.r, edge.g, edge.b, (active and 1.00 or hover and 0.88 or 0.58) * alpha)
        slider._mcdmTrackTop:Show()
    end
    if slider._mcdmTrackBottom then
        slider._mcdmTrackBottom:SetColorTexture(edge.r, edge.g, edge.b, (active and 0.54 or 0.34) * alpha)
        slider._mcdmTrackBottom:Show()
    end
    if slider._mcdmFill then
        local fillAlpha = (active and 1.00 or hover and 0.92 or 0.76) * alpha
        ApplyTextureGradient(slider._mcdmFill, "HORIZONTAL",
            { r = math.min(accent.r * 1.24, 1), g = math.min(accent.g * 1.14, 1), b = math.min(accent.b * 1.10, 1), a = fillAlpha },
            { r = accent.r * 0.72, g = accent.g * 0.82, b = accent.b * 0.90, a = fillAlpha * 0.88 })
        slider._mcdmFill:Show()
    end
    if slider._mcdmFillGlow then
        slider._mcdmFillGlow:SetColorTexture(accent.r, accent.g, accent.b, (active and 0.28 or hover and 0.16 or 0.08) * alpha)
        slider._mcdmFillGlow:Show()
    end

    local nativeThumb = slider.GetThumbTexture and slider:GetThumbTexture()
    if nativeThumb then
        if nativeThumb.SetSize then nativeThumb:SetSize(18, 18) end
        if nativeThumb.SetAlpha then nativeThumb:SetAlpha(0.001) end
        if nativeThumb.Show then nativeThumb:Show() end
    end
    if slider._mcdmThumb then
        local size = active and 20 or (hover and 19 or 18)
        slider._mcdmThumb:SetSize(size, size)
        slider._mcdmThumb:SetVertexColor(
            math.min(accent.r * (active and 1.12 or hover and 1.06 or 1), 1),
            math.min(accent.g * (active and 1.12 or hover and 1.06 or 1), 1),
            math.min(accent.b * (active and 1.12 or hover and 1.06 or 1), 1),
            alpha)
    end

    UpdateSliderVisual(slider)
    if slider.HookScript and not slider._mcdmSliderStyleHooks then
        slider._mcdmSliderStyleHooks = true
        slider:HookScript("OnEnter", function(self) self._mcdmSliderHover = true; UI.StyleSlider(self) end)
        slider:HookScript("OnLeave", function(self) self._mcdmSliderHover = nil; UI.StyleSlider(self) end)
        slider:HookScript("OnEnable", function(self) UI.StyleSlider(self) end)
        slider:HookScript("OnDisable", function(self) self._mcdmSliderHover = nil; self._mcdmSliderActive = nil; UI.StyleSlider(self) end)
        slider:HookScript("OnSizeChanged", UpdateSliderVisual)
        slider:HookScript("OnValueChanged", UpdateSliderVisual)
    end
    return slider
end

local function CreateMCDMStyleSlider(parent, label, minVal, maxVal, currentVal, step, formatValue, parseValue, onValueChanged, labelWidth, sliderWidth)
    minVal = tonumber(minVal) or 0
    maxVal = tonumber(maxVal) or minVal
    if maxVal < minVal then minVal, maxVal = maxVal, minVal end
    step = tonumber(step) or 1
    if step <= 0 then step = 1 end
    currentVal = tonumber(currentVal) or minVal
    local rowW = math.max(72, tonumber(sliderWidth) or tonumber(labelWidth) or 280)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(rowW, 48)

    panel.Label = panel:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    panel.Label:SetPoint("TOPLEFT", 0, 0)
    panel.Label:SetText(label)
    panel.Label:SetWidth(rowW)
    panel.Label:SetJustifyH("LEFT")
    UI.SetTextSubtle(panel.Label)

    local stepW, editW, gap, valueGap = 18, 52, 2, 8
    local minTrackW, compactMinTrackW = 96, 48
    local clusterW = valueGap + stepW + gap + editW + gap + stepW
    local compactClusterW = valueGap + editW

    panel.Slider = CreateFrame("Slider", nil, panel)
    panel.Slider:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -22)
    panel.Slider:SetSize(math.max(compactMinTrackW, rowW - clusterW), 22)
    panel.Slider:SetMinMaxValues(minVal, maxVal)
    panel.Slider:SetValueStep(step)
    if panel.Slider.SetObeyStepOnDrag then panel.Slider:SetObeyStepOnDrag(true) end
    if panel.Slider.SetStepsPerPage then panel.Slider:SetStepsPerPage(1) end
    panel.Slider._mcdmStep = step
    UI.StyleSlider(panel.Slider)

    local minus = UI.CreateModernButton(panel, "-", stepW, 20)
    minus:SetPoint("LEFT", panel.Slider, "RIGHT", valueGap, 0)
    if minus._mcdmLabel then
        minus._mcdmLabel:ClearAllPoints()
        minus._mcdmLabel:SetPoint("CENTER")
        minus._mcdmLabel:SetJustifyH("CENTER")
    end
    panel.Minus = minus

    local input = CreateFrame("EditBox", nil, panel)
    input:SetSize(editW, 20)
    input:SetPoint("LEFT", minus, "RIGHT", gap, 0)
    input:SetFontObject("MidnightCDM_Font14")
    input:SetJustifyH("CENTER")
    input:SetTextInsets(0, 0, 0, 0)
    input:SetAutoFocus(false)
    UI.SkinEditBox(input)
    panel.Input = input

    local plus = UI.CreateModernButton(panel, "+", stepW, 20)
    plus:SetPoint("LEFT", input, "RIGHT", gap, 0)
    if plus._mcdmLabel then
        plus._mcdmLabel:ClearAllPoints()
        plus._mcdmLabel:SetPoint("CENTER")
        plus._mcdmLabel:SetJustifyH("CENTER")
    end
    panel.Plus = plus

    local function LayoutSlider(totalWidth)
        totalWidth = math.max(72, tonumber(totalWidth) or rowW)
        rowW = totalWidth
        panel:SetSize(rowW, 48)
        panel.Label:SetWidth(rowW)

        local tiny = totalWidth < (compactMinTrackW + compactClusterW)
        local compact = tiny or totalWidth < (minTrackW + clusterW)
        local activeClusterW = tiny and 0 or (compact and compactClusterW or clusterW)
        local trackMin = compact and compactMinTrackW or minTrackW
        local trackW = math.max(trackMin, math.floor(totalWidth - activeClusterW + 0.5))

        panel.Slider:SetSize(trackW, 22)
        minus:ClearAllPoints()
        input:ClearAllPoints()
        plus:ClearAllPoints()

        if compact then
            minus:Hide()
        else
            minus:Show()
            minus:SetPoint("LEFT", panel.Slider, "RIGHT", valueGap, 0)
        end

        if tiny then
            input:Hide()
        else
            input:Show()
            input:SetPoint("LEFT", compact and panel.Slider or minus, "RIGHT", compact and valueGap or gap, 0)
        end

        if compact then
            plus:Hide()
        else
            plus:Show()
            plus:SetPoint("LEFT", input, "RIGHT", gap, 0)
        end

        UpdateSliderVisual(panel.Slider)
    end

    panel.Slider._mcdmSetLayoutWidth = LayoutSlider
    LayoutSlider(rowW)

    local suppressOnValueChanged = false
    local settingValue = false

    local function Quantize(value)
        value = tonumber(value) or minVal
        if value < minVal then value = minVal end
        if value > maxVal then value = maxVal end
        value = minVal + (math.floor(((value - minVal) / step) + 0.5) * step)
        if value < minVal then value = minVal end
        if value > maxVal then value = maxVal end
        return value
    end

    formatValue = formatValue or function(value)
        return tostring(math.floor(value + 0.5))
    end
    parseValue = parseValue or function(text) return tonumber(text) end

    local function SetDisplayValue(value)
        if not input:HasFocus() then
            input:SetText(formatValue(value))
        end
    end

    local function SetSliderValue(value, suppressCallback)
        local quantized = Quantize(value)
        suppressOnValueChanged = suppressCallback and true or false
        settingValue = true
        panel.Slider:SetValue(quantized)
        settingValue = false
        suppressOnValueChanged = false
        SetDisplayValue(quantized)
        UpdateSliderVisual(panel.Slider)
        return quantized
    end

    panel.Slider:SetScript("OnValueChanged", function(_, value)
        local quantized = Quantize(value)
        if not settingValue and math.abs((tonumber(value) or 0) - quantized) > 0.000001 then
            SetSliderValue(quantized, suppressOnValueChanged)
            return
        end
        SetDisplayValue(quantized)
        UpdateSliderVisual(panel.Slider)
        if not suppressOnValueChanged and onValueChanged then
            onValueChanged(quantized)
        end
    end)

    local function StepMultiplier()
        if IsControlKeyDown and IsControlKeyDown() then return 10 end
        if IsShiftKeyDown and IsShiftKeyDown() then return 5 end
        return 1
    end

    local function StepBy(direction)
        if panel.Slider.IsEnabled and not panel.Slider:IsEnabled() then return end
        SetSliderValue((tonumber(panel.Slider:GetValue()) or minVal) + (step * StepMultiplier() * direction), false)
    end

    local function ValueFromCursor()
        if not (GetCursorPosition and panel.Slider.GetLeft and panel.Slider.GetWidth) then return nil end
        local left = panel.Slider:GetLeft()
        local width = panel.Slider:GetWidth()
        if not left or not width or width <= 0 then return nil end
        local cursorX = GetCursorPosition()
        local scale = (panel.Slider.GetEffectiveScale and panel.Slider:GetEffectiveScale()) or 1
        if not scale or scale == 0 then scale = 1 end
        local pct = ((cursorX / scale) - left) / width
        if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
        return Quantize(minVal + ((maxVal - minVal) * pct))
    end

    local function SetValueFromCursor()
        if panel.Slider.IsEnabled and not panel.Slider:IsEnabled() then return end
        local value = ValueFromCursor()
        if value ~= nil then SetSliderValue(value, false) end
    end

    local function StopDrag()
        panel.Slider._mcdmSliderActive = nil
        panel.Slider:SetScript("OnUpdate", nil)
        UI.StyleSlider(panel.Slider)
    end

    local function DragUpdate()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            StopDrag()
            return
        end
        SetValueFromCursor()
    end

    panel.Slider:SetScript("OnMouseDown", function(_, button)
        if button and button ~= "LeftButton" then return end
        panel.Slider._mcdmSliderActive = true
        UI.StyleSlider(panel.Slider)
        SetValueFromCursor()
        panel.Slider:SetScript("OnUpdate", DragUpdate)
    end)
    panel.Slider:SetScript("OnMouseUp", function(_, button)
        if button and button ~= "LeftButton" then return end
        StopDrag()
    end)
    panel.Slider:HookScript("OnHide", StopDrag)
    panel.Slider:HookScript("OnShow", function()
        LayoutSlider(rowW)
        UI.StyleSlider(panel.Slider)
    end)
    panel.Slider:EnableMouseWheel(true)
    panel.Slider:SetScript("OnMouseWheel", function(_, delta)
        if not delta or delta == 0 then return end
        StepBy(delta > 0 and 1 or -1)
    end)
    minus:SetScript("OnClick", function() StepBy(-1) end)
    plus:SetScript("OnClick", function() StepBy(1) end)

    input:SetScript("OnEnterPressed", function(self)
        local parsed = parseValue(self:GetText())
        if parsed ~= nil then
            local quantized = SetSliderValue(parsed, false)
            self:SetText(formatValue(quantized))
        end
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self)
        self:SetText(formatValue(Quantize(panel.Slider:GetValue())))
        self:ClearFocus()
    end)
    input:SetScript("OnEditFocusLost", function(self)
        self:SetText(formatValue(Quantize(panel.Slider:GetValue())))
    end)

    function panel:UpdateUIValue(value)
        local quantized = SetSliderValue(value, true)
        input:SetText(formatValue(quantized))
    end

    panel:UpdateUIValue(currentVal)
    return panel
end

function UI.CreateModernSlider(parent, label, minVal, maxVal, currentVal, onValueChanged, labelWidth, sliderWidth)
    return CreateMCDMStyleSlider(parent, label, minVal, maxVal, currentVal, 1, nil, nil, onValueChanged, labelWidth, sliderWidth)
end

function UI.CreateModernSliderPrecise(parent, label, minVal, maxVal, currentVal, step, decimals, onValueChanged)
    local valueDecimals = tonumber(decimals) or 2
    if valueDecimals < 0 then valueDecimals = 0 end
    local valueStep = tonumber(step) or 0.05
    if valueStep <= 0 then valueStep = 0.05 end
    local function FormatValue(value)
        local asString = string.format("%." .. valueDecimals .. "f", value)
        asString = asString:gsub("(%..-)0+$", "%1")
        asString = asString:gsub("%.$", "")
        return asString
    end
    return CreateMCDMStyleSlider(parent, label, minVal, maxVal, currentVal, valueStep, FormatValue, nil, onValueChanged, nil, nil)
end

function UI.RoundToInt(value)
    local num = tonumber(value)
    if not num then return 0 end
    return math.floor(num + 0.5)
end

function UI.CreateModernCheckbox(parent, label, initialValue, onChange)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(400, 26)

    local checkbox = CreateFrame("CheckButton", nil, frame)
    checkbox:SetSize(44, 22)
    checkbox:SetPoint("LEFT", 0, 0)

    UI.StyleSwitch(checkbox)

    local text = frame:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    text:SetPoint("LEFT", checkbox, "RIGHT", 9, 0)
    text:SetText(label)
    UI.SetTextSubtle(text)
    checkbox._mcdmSwitchLabel = text

    checkbox:SetChecked(initialValue or false)
    if checkbox.RefreshVisual then
        checkbox:RefreshVisual()
    end

    checkbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        if onChange then
            onChange(checked)
        end
        if self.RefreshVisual then self:RefreshVisual() end
    end)

    local function ClickSwitchProxy(button)
        button = button or "LeftButton"
        if button ~= "LeftButton" then return end
        if checkbox.IsEnabled and not checkbox:IsEnabled() then return end
        checkbox:SetChecked(not (checkbox:GetChecked() and true or false))
        local click = checkbox.GetScript and checkbox:GetScript("OnClick")
        if type(click) == "function" then
            click(checkbox, "LeftButton", true)
        elseif checkbox.RefreshVisual then
            checkbox:RefreshVisual()
        end
    end

    frame.checkbox = checkbox
    frame.label = text
    frame:EnableMouse(false)
    frame:SetScript("OnEnter", function()
        checkbox._mcdmSwitchHover = true
        if checkbox.RefreshVisual then checkbox:RefreshVisual() end
        UI.SetTextColor(text, UI.TextColors.white)
    end)
    frame:SetScript("OnLeave", function()
        checkbox._mcdmSwitchHover = nil
        checkbox._mcdmSwitchPressed = nil
        if checkbox.RefreshVisual then checkbox:RefreshVisual() end
        UI.SetTextSubtle(text)
    end)
    local labelHit = CreateFrame("Button", nil, frame)
    labelHit:SetPoint("TOPLEFT", text, "TOPLEFT", -2, 4)
    labelHit:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", 2, -4)
    labelHit:SetFrameLevel(math.max(frame:GetFrameLevel(), checkbox:GetFrameLevel()) + 2)
    if labelHit.RegisterForClicks then
        labelHit:RegisterForClicks("LeftButtonUp")
    end
    labelHit:SetScript("OnEnter", function()
        if checkbox.IsEnabled and not checkbox:IsEnabled() then
            if checkbox.RefreshVisual then checkbox:RefreshVisual() end
            return
        end
        checkbox._mcdmSwitchHover = true
        if checkbox.RefreshVisual then checkbox:RefreshVisual() end
        UI.SetTextColor(text, UI.TextColors.white)
    end)
    labelHit:SetScript("OnLeave", function()
        checkbox._mcdmSwitchHover = nil
        checkbox._mcdmSwitchPressed = nil
        if checkbox.RefreshVisual then checkbox:RefreshVisual() end
        UI.SetTextSubtle(text)
    end)
    labelHit:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        if checkbox.IsEnabled and not checkbox:IsEnabled() then return end
        checkbox._mcdmSwitchPressed = true
        if checkbox.RefreshVisual then checkbox:RefreshVisual() end
    end)
    labelHit:SetScript("OnMouseUp", function(_, button)
        checkbox._mcdmSwitchPressed = nil
        if checkbox.RefreshVisual then checkbox:RefreshVisual() end
    end)
    labelHit:SetScript("OnClick", function(_, button)
        ClickSwitchProxy(button)
    end)
    frame.labelHit = labelHit

    function frame:SetChecked(checked)
        checkbox:SetChecked(checked)
        if checkbox.RefreshVisual then checkbox:RefreshVisual() end
    end

    function frame:GetChecked()
        return checkbox:GetChecked()
    end

    function frame:SetEnabled(enabled)
        if enabled then
            checkbox:Enable()
            UI.SetTextSubtle(text)
            frame:SetAlpha(1)
            if labelHit.EnableMouse then labelHit:EnableMouse(true) end
            if checkbox.RefreshVisual then checkbox:RefreshVisual() end
        else
            checkbox:Disable()
            text:SetTextColor(0.5, 0.5, 0.5, 1)
            frame:SetAlpha(0.5)
            if labelHit.EnableMouse then labelHit:EnableMouse(false) end
            if checkbox.RefreshVisual then checkbox:RefreshVisual() end
        end
    end

    return frame
end

function UI.CreateHeader(parent, text, anchorFrame, yOffset)
    return CreateSectionHeader(parent, text, anchorFrame, yOffset, "MidnightCDM_Font18", -15, -10)
end

function UI.CreateSubHeader(parent, text, anchorFrame, yOffset)
    return CreateSectionHeader(parent, text, anchorFrame, yOffset, "MidnightCDM_Font14", -12, -10)
end

UI.TextColors = UI.TextColors or {
    white = { r = WHITE.r, g = WHITE.g, b = WHITE.b, a = WHITE.a or 1 },
    muted = { r = 0.7, g = 0.7, b = 0.7, a = 1 },
    subtle = { r = 0.8, g = 0.8, b = 0.8, a = 1 },
    faint = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
    inactive = { r = 0.82, g = 0.82, b = 0.82, a = 1 },
    success = { r = 0.5, g = 1, b = 0.5, a = 1 },
    error = { r = 1, g = 0.3, b = 0.3, a = 1 },
}

function UI.SetTextColor(fontString, color)
    if not fontString or not color then return end
    fontString:SetTextColor(color.r, color.g, color.b, color.a or 1)
end

function UI.SetTextMuted(fontString)
    UI.SetTextColor(fontString, UI.TextColors.muted)
end

function UI.SetTextSubtle(fontString)
    UI.SetTextColor(fontString, UI.TextColors.subtle)
end

function UI.SetTextFaint(fontString)
    UI.SetTextColor(fontString, UI.TextColors.faint)
end

function UI.SetTextInactive(fontString)
    UI.SetTextColor(fontString, UI.TextColors.inactive)
end

function UI.SetTextWhite(fontString)
    UI.SetTextColor(fontString, UI.TextColors.white)
end

function UI.SetTextSuccess(fontString)
    UI.SetTextColor(fontString, UI.TextColors.success)
end

function UI.SetTextError(fontString)
    UI.SetTextColor(fontString, UI.TextColors.error)
end

function UI.CloseAllDropdownMenus()
    if Menu and Menu.GetManager then
        Menu.GetManager():CloseMenus()
    end
end

function UI.AttachCloseMenusOnScroll(scrollFrame)
    if not scrollFrame or scrollFrame.cdmCloseMenusOnScrollHooked then
        return
    end

    scrollFrame.cdmCloseMenusOnScrollHooked = true
    scrollFrame:HookScript("OnVerticalScroll", function()
        UI.CloseAllDropdownMenus()
    end)
    scrollFrame:HookScript("OnHide", function()
        UI.CloseAllDropdownMenus()
    end)
end

function UI.EnableClipping(frame)
    if frame and frame.SetClipsChildren then
        frame:SetClipsChildren(true)
    end
    return frame
end

function UI.CreateScrollableTab(page, frameName, contentHeight, contentWidth)
    UI.EnableClipping(page)
    local scrollFrame = CreateFrame("ScrollFrame", frameName, page, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -20)
    scrollFrame:SetPoint("BOTTOMRIGHT", -16, 24)
    UI.EnableClipping(scrollFrame)
    UI.AttachCloseMenusOnScroll(scrollFrame)
    UI.StyleScrollFrame(scrollFrame)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(contentWidth or 460, (contentHeight or 800) + 32)
    scrollFrame:SetScrollChild(scrollChild)

    local contentContainer = CreateFrame("Frame", nil, scrollChild)
    contentContainer:SetPoint("TOPLEFT", 35, -20)
    contentContainer:SetPoint("TOPRIGHT", -25, -20)
    contentContainer:SetHeight(contentHeight or 800)

    return contentContainer, scrollFrame
end

local SCROLL_BOTTOM_PAD = 20

function UI.MakeSubPageScroll(subPage, frameName)
    UI.EnableClipping(subPage)
    local sf = CreateFrame("ScrollFrame", frameName, subPage, "ScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", -16, 0)
    UI.EnableClipping(sf)
    UI.AttachCloseMenusOnScroll(sf)
    UI.StyleScrollFrame(sf)

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(540)
    sf:SetScrollChild(sc)

    local rc = CreateFrame("Frame", nil, sc)
    rc:SetPoint("TOPLEFT", 30, 0)
    rc:SetPoint("TOPRIGHT", -20, 0)
    return rc, sc
end

function UI.FinalizeScroll(sc, rc, yOff)
    local h = math.abs(yOff) + SCROLL_BOTTOM_PAD
    sc:SetHeight(h)
    rc:SetHeight(h)
end

function UI.CreateVerticalLayout(startY)
    local layout = { y = startY or 0 }
    function layout:Next(spacing)
        self.y = self.y - spacing
        return self.y
    end
    return layout
end

UI.PositionOptions = {
    "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT",
    "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT",
}

function UI.SetupValueDropdown(dropdown, options, getValue, setValue)
    UI.StyleDropdown(dropdown)
    if dropdown.SetDefaultText then
        local opts = (type(options) == "function" and options() or options) or {}
        local value = getValue()
        dropdown:SetDefaultText(UI.GetOptionLabel(opts, value, tostring(value or "")))
    end
    dropdown:SetupMenu(function(_, rootDescription)
        local opts = (type(options) == "function" and options() or options) or {}
        for _, opt in ipairs(opts) do
            rootDescription:CreateRadio(opt.label, function() return getValue() == opt.value end, function()
                setValue(opt.value, opt.label)
                if dropdown.SetDefaultText then dropdown:SetDefaultText(opt.label or tostring(opt.value or "")) end
            end)
        end
    end)
end

function UI.SetupPositionDropdown(dropdown, getValue, setValue, positions)
    UI.StyleDropdown(dropdown)
    local options = positions or UI.PositionOptions
    if dropdown.SetDefaultText then dropdown:SetDefaultText(getValue() or "") end
    dropdown:SetupMenu(function(_, rootDescription)
        for _, pos in ipairs(options) do
            rootDescription:CreateRadio(pos, function() return getValue() == pos end, function()
                setValue(pos)
                if dropdown.SetDefaultText then dropdown:SetDefaultText(pos) end
            end)
        end
    end)
end

local lsmListCache = {}

local function GetCachedMediaList(mediaType)
    if lsmListCache[mediaType] then return lsmListCache[mediaType] end
    local raw = LSM:List(mediaType) or {}
    local sorted = {}
    for i, name in ipairs(raw) do sorted[i] = name end
    table.sort(sorted)
    local deduped = {}
    local seenPaths = {}
    for _, name in ipairs(sorted) do
        local path = LSM:Fetch(mediaType, name)
        if not path or not seenPaths[path] then
            if path then seenPaths[path] = true end
            deduped[#deduped + 1] = name
        end
    end
    lsmListCache[mediaType] = deduped
    return deduped
end

function UI.SetupMediaDropdown(dropdown, mediaType, getValue, setValue, setText)
    UI.StyleDropdown(dropdown)
    dropdown._mcdmFontPreview = mediaType == "font" or nil
    dropdown._mcdmFontPreviewOutline = ""
    local emptyLabel = dropdown._mcdmEmptyMediaLabel
    local function UpdateDropdownText(value)
        if setText then
            setText(value)
        elseif dropdown.SetDefaultText then
            dropdown:SetDefaultText((value == nil or value == "") and emptyLabel or value or "")
        end
    end
    if dropdown.SetDefaultText then
        local value = getValue()
        dropdown:SetDefaultText((value == nil or value == "") and emptyLabel or value or "")
    end
    dropdown:SetupMenu(function(_, rootDescription)
        rootDescription:SetScrollMode(500)
        if emptyLabel then
            rootDescription:CreateRadio(emptyLabel, function()
                local value = getValue()
                return value == nil or value == ""
            end, function()
                setValue("")
                UpdateDropdownText("")
            end)
            rootDescription:CreateDivider()
        end
        local list = GetCachedMediaList(mediaType)
        for _, name in ipairs(list) do
            local item = rootDescription:CreateRadio(name, function() return getValue() == name end, function()
                setValue(name)
                UpdateDropdownText(name)
            end)
            if mediaType == "font" then
                item._mcdmFontPath = FetchMediaPath("font", name, true)
                item._mcdmFontPreviewSize = 13
                item._mcdmFontPreviewOutline = ""
            end
        end
    end)
end

do
    local function HideAndOrphan(...)
        for i = 1, select("#", ...) do
            local child = select(i, ...)
            child:Hide()
            child:SetParent(nil)
        end
    end
    function UI.ClearChildren(frame)
        HideAndOrphan(frame:GetChildren())
    end
end

function UI.CreateScrollableEditBox(parent, width, height, editWidth)
    local boxFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    boxFrame:SetSize(width, height)
    UI.ApplyBackdrop(boxFrame, { r = 0.020, g = 0.024, b = 0.046, a = 0.88 }, THEME.colors.borderSoft)

    local scrollFrame = CreateFrame("ScrollFrame", nil, boxFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)
    UI.StyleScrollFrame(scrollFrame)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("MidnightCDM_Font14")
    editBox:SetWidth(editWidth or (width - 40))
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    if editBox.SetTextColor then
        editBox:SetTextColor(THEME.colors.text.r, THEME.colors.text.g, THEME.colors.text.b, THEME.colors.text.a)
    end
    scrollFrame:SetScrollChild(editBox)

    local function FocusEditBox()
        editBox:SetFocus()
    end
    boxFrame:EnableMouse(true)
    boxFrame:SetScript("OnMouseDown", FocusEditBox)
    scrollFrame:SetScript("OnMouseDown", FocusEditBox)

    return boxFrame, editBox
end

function UI.SetupModuleToggle(parent, enableCheckbox)
    local overlayLevel = parent:GetFrameLevel() + 100
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(overlayLevel)
    overlay:EnableMouse(true)
    overlay:Hide()

    enableCheckbox:SetFrameLevel(overlayLevel + 10)

    local function SetEnabled(en)
        local alpha = 0.35
        if en then
            alpha = 1
        end

        for _, child in ipairs({ parent:GetChildren() }) do
            if child ~= enableCheckbox and child ~= overlay then
                child:SetAlpha(alpha)
            end
        end
        for _, region in ipairs({ parent:GetRegions() }) do
            region:SetAlpha(alpha)
        end
        overlay:SetShown(not en)
    end

    return SetEnabled
end

function UI.CreateModalOverlay()
    local overlay = CreateFrame("Frame", nil, ns.ConfigFrame, "BackdropTemplate")
    overlay:SetPoint("TOPLEFT", ns.ConfigFrame, "TOPLEFT", 12, -42)
    overlay:SetPoint("BOTTOMRIGHT", ns.ConfigFrame, "BOTTOMRIGHT", -12, 12)
    overlay:SetFrameStrata("DIALOG")
    overlay:SetFrameLevel(ns.ConfigFrame:GetFrameLevel() + 50)
    overlay:EnableMouse(true)
    overlay:Hide()

    local overlayBg = overlay:CreateTexture(nil, "BACKGROUND")
    overlayBg:SetAllPoints()
    overlayBg:SetColorTexture(0, 0, 0, 0.52)

    local window = UI.CreatePanel(overlay, nil, THEME.colors.popup, { r = 0.140, g = 0.220, b = 0.600, a = 0.88 })
    window:EnableMouse(true)
    window:SetFrameStrata("DIALOG")
    window:SetFrameLevel(overlay:GetFrameLevel() + 5)
    window:SetPoint("CENTER", ns.ConfigFrame, "CENTER")
    window:SetScript("OnMouseDown", function() end)

    local closeButton = CreateFrame("Button", nil, window)
    closeButton:SetSize(20, 20)
    closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -8, -8)
    UI.StyleButton(closeButton, "danger")
    local lineA = closeButton:CreateTexture(nil, "OVERLAY")
    lineA:SetTexture(CDM_C.TEX_WHITE8X8)
    lineA:SetSize(10, 2)
    lineA:SetPoint("CENTER")
    lineA:SetRotation(0.785398)
    lineA:SetColorTexture(1, 1, 1, 0.95)
    local lineB = closeButton:CreateTexture(nil, "OVERLAY")
    lineB:SetTexture(CDM_C.TEX_WHITE8X8)
    lineB:SetSize(10, 2)
    lineB:SetPoint("CENTER")
    lineB:SetRotation(-0.785398)
    lineB:SetColorTexture(1, 1, 1, 0.95)
    closeButton:SetScript("OnClick", function() overlay:Hide() end)
    window.CloseButton = closeButton

    overlay:SetScript("OnMouseDown", function() overlay:Hide() end)
    overlay:SetScript("OnShow", function()
        window:Show()
        C_Timer.After(0, function()
            if window:IsShown() then
                UI.StyleFrameTree(window)
            end
        end)
    end)
    window:HookScript("OnHide", function() overlay:Hide() end)

    overlay.window = window
    return overlay
end

function UI.CreateTimedStatus(fontString, duration)
    local timer
    duration = duration or 2
    return function(text)
        fontString:SetText(text)
        if timer then timer:Cancel() end
        if text ~= "" then
            timer = C_Timer.NewTimer(duration, function() fontString:SetText("") end)
        end
    end
end

function UI.AttachPlaceholder(editBox, text)
    UI.SkinEditBox(editBox)
    local ph = editBox:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    ph:SetPoint("LEFT", editBox, "LEFT", 8, 0)
    ph:SetText(text)
    ph:SetTextColor(THEME.colors.dim.r, THEME.colors.dim.g, THEME.colors.dim.b, 0.72)
    editBox:HookScript("OnTextChanged", function(self)
        ph:SetShown(self:GetText() == "")
    end)
    return ph
end

function UI.GetOptionLabel(options, value, default)
    for _, opt in ipairs(options) do
        if opt.value == value then return opt.label end
    end
    return default or value
end

function UI.CreateSubTabBar(parent, tabs, initialTab)
    local TAB_HEIGHT = 28
    local barFrame = CreateFrame("Frame", nil, parent)
    barFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -10)
    barFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -10)
    barFrame:SetHeight(TAB_HEIGHT)

    local subPages = {}
    local tabButtons = {}
    local selectedTab = nil

    local function SelectTab(id)
        if selectedTab == id then return end
        selectedTab = id
        for _, info in ipairs(tabs) do
            local btn = tabButtons[info.id]
            local pg = subPages[info.id]
            if info.id == id then
                btn:SetActive(true)
                pg:Show()
            else
                btn:SetActive(false)
                pg:Hide()
            end
        end
    end

    local prevBtn
    for _, info in ipairs(tabs) do
        local btn = UI.CreateModernButton(barFrame, info.label, 92, 24)
        btn._mcdmSolidPill = true
        local label = btn._mcdmLabel
        local textWidth = label and label:GetStringWidth() or 52
        btn:SetWidth(math.max(textWidth + 34, 84))

        if prevBtn then
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
        else
            btn:SetPoint("LEFT", barFrame, "LEFT", 0, 0)
        end
        prevBtn = btn

        btn:SetScript("OnClick", function() SelectTab(info.id) end)
        tabButtons[info.id] = btn

        local pg = CreateFrame("Frame", nil, parent)
        pg:SetPoint("TOPLEFT", barFrame, "BOTTOMLEFT", -12, -8)
        pg:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        pg:Hide()
        pg.controls = {}
        subPages[info.id] = pg
    end

    SelectTab(initialTab or tabs[1].id)

    return {
        selectTab = SelectTab,
        subPages = subPages,
        barFrame = barFrame,
        tabButtons = tabButtons,
    }
end
