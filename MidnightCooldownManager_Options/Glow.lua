local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L


local glowTypeOptions = {
    { value = "pixel", label = L["Pixel Glow"] },
    { value = "autocast", label = L["Autocast Glow"] },
    { value = "button", label = L["Button Glow"] },
    { value = "proc", label = L["Proc Glow"] },
}

local typeSections = {}

local function UpdateTypeSections(selectedType)
    for typeId, section in pairs(typeSections) do
        section:SetShown(typeId == selectedType)
    end
end

local function SliderValueToAutocastScale(sliderValue)
    return 1 + ((sliderValue - 1) * 0.25)
end

local function AutocastScaleToSliderValue(scale)
    local normalized = ((scale or 1) - 1) / 0.25
    local sliderValue = math.floor(normalized + 0.5) + 1
    return math.max(1, math.min(9, sliderValue))
end

local function CreateGlowTab(page, tabId)
    local content, scrollFrame = UI.CreateScrollableTab(page, "MidnightCDM_GlowScrollFrame", 700, 560)
    local scrollChild = scrollFrame:GetScrollChild()

    wipe(typeSections)

    local sections = {}
    local function Relayout()
        UI.LayoutAccordionSections(sections, 0, 8, scrollChild, content)
    end
    local function AddSection(title, key, height, defaultOpen)
        local section, body = UI.CreateAccordionSection(content, title, 540, height, "glow:" .. key, defaultOpen, Relayout)
        sections[#sections + 1] = section
        return section, body
    end

    local _, generalBody = AddSection(L["Glow Settings"], "general", 145, true)

    local lblType = generalBody:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    lblType:SetText(L["Glow Type"])
    lblType:SetPoint("TOPLEFT", 0, 0)

    local ddType = UI.CreateDropdown(generalBody)
    ddType:SetPoint("TOPLEFT", lblType, "BOTTOMLEFT", 0, -10)
    ddType:SetWidth(200)

    ddType:SetDefaultText(UI.GetOptionLabel(glowTypeOptions, CDM.db.glowType or "proc", L["Proc Glow"]))

    UI.SetupValueDropdown(
        ddType,
        glowTypeOptions,
        function() return CDM.db.glowType or "proc" end,
        function(value, label)
            CDM.db.glowType = value
            ddType:SetDefaultText(label)
            UpdateTypeSections(value)
            Relayout()
            API:Refresh("STYLE")
        end
    )
    page.typeDropdown = ddType

    page.useColorCheckbox = UI.CreateModernCheckbox(
        generalBody,
        L["Use Custom Color"],
        CDM.db.glowUseCustomColor or false,
        function(checked)
            CDM.db.glowUseCustomColor = checked
            API:Refresh("STYLE")
        end
    )
    page.useColorCheckbox:SetPoint("TOPLEFT", ddType, "BOTTOMLEFT", 0, -15)

    local colorPicker = UI.CreateColorSwatch(generalBody, L["Glow Color"], "glowColor", "STYLE")
    colorPicker:SetPoint("TOPLEFT", page.useColorCheckbox, "BOTTOMLEFT", 0, -10)
    page.colorPicker = colorPicker

    local pixelSection, pixelBody = AddSection(L["Pixel Glow Settings"], "pixel", 405, true)
    typeSections["pixel"] = pixelSection

    page.controls.pixelLines = UI.CreateModernSlider(
        pixelBody, L["Lines"], 1, 20, CDM.db.glowPixelLines or 8,
        function(v) CDM.db.glowPixelLines = v; API:Refresh("STYLE") end
    )
    page.controls.pixelLines:SetPoint("TOPLEFT", 0, 0)

    page.controls.pixelFrequency = UI.CreateModernSliderPrecise(
        pixelBody, L["Frequency"], -2, 2, CDM.db.glowPixelFrequency or 0.2, 0.05, 2,
        function(v) CDM.db.glowPixelFrequency = v; API:Refresh("STYLE") end
    )
    page.controls.pixelFrequency:SetPoint("TOPLEFT", page.controls.pixelLines, "BOTTOMLEFT", 0, -10)

    page.controls.pixelLength = UI.CreateModernSlider(
        pixelBody, L["Length (0=auto)"], 0, 20, CDM.db.glowPixelLength or 0,
        function(v) CDM.db.glowPixelLength = v; API:Refresh("STYLE") end
    )
    page.controls.pixelLength:SetPoint("TOPLEFT", page.controls.pixelFrequency, "BOTTOMLEFT", 0, -10)

    page.controls.pixelThickness = UI.CreateModernSlider(
        pixelBody, L["Thickness"], 1, 10, CDM.db.glowPixelThickness or 2,
        function(v) CDM.db.glowPixelThickness = v; API:Refresh("STYLE") end
    )
    page.controls.pixelThickness:SetPoint("TOPLEFT", page.controls.pixelLength, "BOTTOMLEFT", 0, -10)

    page.controls.pixelXOffset = UI.CreateModernSlider(
        pixelBody, L["X Offset"], -20, 20, CDM.db.glowPixelXOffset or 0,
        function(v) CDM.db.glowPixelXOffset = v; API:Refresh("STYLE") end
    )
    page.controls.pixelXOffset:SetPoint("TOPLEFT", page.controls.pixelThickness, "BOTTOMLEFT", 0, -10)

    page.controls.pixelYOffset = UI.CreateModernSlider(
        pixelBody, L["Y Offset"], -20, 20, CDM.db.glowPixelYOffset or 0,
        function(v) CDM.db.glowPixelYOffset = v; API:Refresh("STYLE") end
    )
    page.controls.pixelYOffset:SetPoint("TOPLEFT", page.controls.pixelXOffset, "BOTTOMLEFT", 0, -10)

    page.controls.pixelBorder = UI.CreateModernCheckbox(
        pixelBody,
        L["Border"],
        CDM.db.glowPixelBorder or false,
        function(checked)
            CDM.db.glowPixelBorder = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.pixelBorder:SetPoint("TOPLEFT", page.controls.pixelYOffset, "BOTTOMLEFT", 0, -15)

    local autocastSection, autocastBody = AddSection(L["Autocast Glow Settings"], "autocast", 310, true)
    autocastSection:Hide()
    typeSections["autocast"] = autocastSection

    page.controls.autocastParticles = UI.CreateModernSlider(
        autocastBody, L["Particles"], 1, 16, CDM.db.glowAutocastParticles or 4,
        function(v) CDM.db.glowAutocastParticles = v; API:Refresh("STYLE") end
    )
    page.controls.autocastParticles:SetPoint("TOPLEFT", 0, 0)

    page.controls.autocastFrequency = UI.CreateModernSliderPrecise(
        autocastBody, L["Frequency"], -2, 2, CDM.db.glowAutocastFrequency or 0.2, 0.05, 2,
        function(v) CDM.db.glowAutocastFrequency = v; API:Refresh("STYLE") end
    )
    page.controls.autocastFrequency:SetPoint("TOPLEFT", page.controls.autocastParticles, "BOTTOMLEFT", 0, -10)

    page.controls.autocastScale = UI.CreateModernSlider(
        autocastBody, L["Scale"], 1, 9, AutocastScaleToSliderValue(CDM.db.glowAutocastScale or 1),
        function(v)
            CDM.db.glowAutocastScale = SliderValueToAutocastScale(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.autocastScale:SetPoint("TOPLEFT", page.controls.autocastFrequency, "BOTTOMLEFT", 0, -10)

    page.controls.autocastXOffset = UI.CreateModernSlider(
        autocastBody, L["X Offset"], -20, 20, CDM.db.glowAutocastXOffset or 0,
        function(v) CDM.db.glowAutocastXOffset = v; API:Refresh("STYLE") end
    )
    page.controls.autocastXOffset:SetPoint("TOPLEFT", page.controls.autocastScale, "BOTTOMLEFT", 0, -10)

    page.controls.autocastYOffset = UI.CreateModernSlider(
        autocastBody, L["Y Offset"], -20, 20, CDM.db.glowAutocastYOffset or 0,
        function(v) CDM.db.glowAutocastYOffset = v; API:Refresh("STYLE") end
    )
    page.controls.autocastYOffset:SetPoint("TOPLEFT", page.controls.autocastXOffset, "BOTTOMLEFT", 0, -10)

    local buttonSection, buttonBody = AddSection(L["Button Glow Settings"], "button", 70, true)
    buttonSection:Hide()
    typeSections["button"] = buttonSection

    page.controls.buttonFrequency = UI.CreateModernSlider(
        buttonBody, L["Frequency (0=default)"], 0, 100, math.floor((CDM.db.glowButtonFrequency or 0) * 100),
        function(v) CDM.db.glowButtonFrequency = v / 100; API:Refresh("STYLE") end
    )
    page.controls.buttonFrequency:SetPoint("TOPLEFT", 0, 0)

    local procSection, procBody = AddSection(L["Proc Glow Settings"], "proc", 190, true)
    procSection:Hide()
    typeSections["proc"] = procSection

    page.controls.procDuration = UI.CreateModernSlider(
        procBody, L["Duration (x10)"], 1, 50, math.floor((CDM.db.glowProcDuration or 1) * 10),
        function(v) CDM.db.glowProcDuration = v / 10; API:Refresh("STYLE") end
    )
    page.controls.procDuration:SetPoint("TOPLEFT", 0, 0)

    page.controls.procXOffset = UI.CreateModernSlider(
        procBody, L["X Offset"], -20, 20, CDM.db.glowProcXOffset or 0,
        function(v) CDM.db.glowProcXOffset = v; API:Refresh("STYLE") end
    )
    page.controls.procXOffset:SetPoint("TOPLEFT", page.controls.procDuration, "BOTTOMLEFT", 0, -10)

    page.controls.procYOffset = UI.CreateModernSlider(
        procBody, L["Y Offset"], -20, 20, CDM.db.glowProcYOffset or 0,
        function(v) CDM.db.glowProcYOffset = v; API:Refresh("STYLE") end
    )
    page.controls.procYOffset:SetPoint("TOPLEFT", page.controls.procXOffset, "BOTTOMLEFT", 0, -10)

    UpdateTypeSections(CDM.db.glowType or "proc")
    Relayout()
end

API:RegisterConfigTab("glow", L["Glow"], CreateGlowTab, 6)
