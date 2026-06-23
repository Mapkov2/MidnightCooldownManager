local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L


local function CreateAssistTab(page, tabId)
    local scrollChild, scrollFrame = UI.CreateScrollableTab(page, "MidnightCDM_AssistScrollFrame", 700, 370)

    local sections = {}
    local function Relayout()
        UI.LayoutAccordionSections(sections, 0, 8, scrollFrame:GetScrollChild(), scrollChild)
    end
    local function AddSection(title, key, height, defaultOpen)
        local section, body = UI.CreateAccordionSection(scrollChild, title, 540, height, "assist:" .. key, defaultOpen, Relayout)
        sections[#sections + 1] = section
        return section, body
    end

    local _, poBody = AddSection(L["Press Overlay"], "press-overlay", 315, true)

    local setPOControlsEnabled
    page.controls.pressOverlayEnabled = UI.CreateModernCheckbox(
        poBody,
        L["Enable Press Overlay"],
        CDM.db.pressOverlayEnabled or false,
        function(checked)
            CDM.db.pressOverlayEnabled = checked
            if setPOControlsEnabled then setPOControlsEnabled(checked) end
            API:Refresh("STYLE")
        end
    )
    page.controls.pressOverlayEnabled:SetPoint("TOPLEFT", 0, 0)

    local settingExclusive = false
    local function SetExclusiveStyle(activeKey)
        if settingExclusive then return end
        settingExclusive = true
        local keys = { "pressOverlayTint", "pressOverlayHighlight", "pressOverlayBorder" }
        for _, key in ipairs(keys) do
            CDM.db[key] = (key == activeKey)
        end
        if page.controls.pressOverlayTint then
            page.controls.pressOverlayTint:SetChecked(activeKey == "pressOverlayTint")
        end
        if page.controls.pressOverlayHighlight then
            page.controls.pressOverlayHighlight:SetChecked(activeKey == "pressOverlayHighlight")
        end
        if page.controls.pressOverlayBorder then
            page.controls.pressOverlayBorder:SetChecked(activeKey == "pressOverlayBorder")
        end
        settingExclusive = false
        API:Refresh("STYLE")
    end

    page.controls.pressOverlayTint = UI.CreateModernCheckbox(
        poBody,
        L["Color Tint"],
        CDM.db.pressOverlayTint or false,
        function(checked)
            if checked then SetExclusiveStyle("pressOverlayTint") end
        end
    )
    page.controls.pressOverlayTint:SetPoint("TOPLEFT", page.controls.pressOverlayEnabled, "BOTTOMLEFT", 0, -10)

    page.pressOverlayTintColorPicker = UI.CreateColorSwatch(poBody, L["Tint Color"], "pressOverlayTintColor", "STYLE")
    page.pressOverlayTintColorPicker:SetPoint("TOPLEFT", page.controls.pressOverlayTint, "BOTTOMLEFT", 0, -10)

    page.controls.pressOverlayHighlight = UI.CreateModernCheckbox(
        poBody,
        L["Highlight"],
        CDM.db.pressOverlayHighlight or false,
        function(checked)
            if checked then SetExclusiveStyle("pressOverlayHighlight") end
        end
    )
    page.controls.pressOverlayHighlight:SetPoint("TOPLEFT", page.pressOverlayTintColorPicker, "BOTTOMLEFT", 0, -10)

    page.controls.pressOverlayBorder = UI.CreateModernCheckbox(
        poBody,
        L["Border"],
        CDM.db.pressOverlayBorder or false,
        function(checked)
            if checked then SetExclusiveStyle("pressOverlayBorder") end
        end
    )
    page.controls.pressOverlayBorder:SetPoint("TOPLEFT", page.controls.pressOverlayHighlight, "BOTTOMLEFT", 0, -10)

    for _, ctrl in ipairs({ page.controls.pressOverlayTint, page.controls.pressOverlayHighlight, page.controls.pressOverlayBorder }) do
        local cb = ctrl.checkbox
        local origScript = cb:GetScript("OnClick")
        cb:SetScript("OnClick", function(self)
            if not self:GetChecked() then
                self:SetChecked(true)
                return
            end
            origScript(self)
        end)
    end

    page.pressOverlayBorderColorPicker = UI.CreateColorSwatch(poBody, L["Border Color"], "pressOverlayBorderColor", "STYLE")
    page.pressOverlayBorderColorPicker:SetPoint("TOPLEFT", page.controls.pressOverlayBorder, "BOTTOMLEFT", 0, -10)

    local poControls = {
        page.controls.pressOverlayTint, page.pressOverlayTintColorPicker,
        page.controls.pressOverlayHighlight,
        page.controls.pressOverlayBorder, page.pressOverlayBorderColorPicker,
    }

    local poOverlay = CreateFrame("Frame", nil, poBody)
    poOverlay:SetPoint("TOPLEFT", page.controls.pressOverlayTint, "TOPLEFT")
    poOverlay:SetPoint("BOTTOMRIGHT", page.pressOverlayBorderColorPicker, "BOTTOMRIGHT")
    local poMaxLevel = 0
    for _, ctrl in ipairs(poControls) do
        local lvl = ctrl:GetFrameLevel()
        if lvl > poMaxLevel then poMaxLevel = lvl end
    end
    poOverlay:SetFrameLevel(poMaxLevel + 10)
    poOverlay:EnableMouse(true)
    poOverlay:Hide()

    setPOControlsEnabled = function(en)
        local alpha = en and 1 or 0.35
        for _, ctrl in ipairs(poControls) do
            ctrl:SetAlpha(alpha)
        end
        poOverlay:SetShown(not en)
    end
    setPOControlsEnabled(CDM.db.pressOverlayEnabled or false)

    local _, raBody = AddSection(L["Rotation Assist"], "rotation-assist", 120, true)

    local setRAControlsEnabled
    page.controls.rotationAssistEnabled = UI.CreateModernCheckbox(
        raBody,
        L["Enable Rotation Assist"],
        CDM.db.rotationAssistEnabled or false,
        function(checked)
            CDM.db.rotationAssistEnabled = checked
            if setRAControlsEnabled then setRAControlsEnabled(checked) end
            API:Refresh("STYLE")
        end
    )
    page.controls.rotationAssistEnabled:SetPoint("TOPLEFT", 0, 0)

    page.controls.rotationAssistGlowRatio = UI.CreateModernSliderPrecise(
        raBody, L["Highlight Size"], 0.2, 0.4, CDM.db.rotationAssistGlowRatio or 0.33, 0.01, 2,
        function(v)
            CDM.db.rotationAssistGlowRatio = v
            API:Refresh("STYLE")
        end
    )
    page.controls.rotationAssistGlowRatio:SetPoint("TOPLEFT", page.controls.rotationAssistEnabled, "BOTTOMLEFT", 0, -15)

    local raOverlay = CreateFrame("Frame", nil, raBody)
    raOverlay:SetPoint("TOPLEFT", page.controls.rotationAssistGlowRatio, "TOPLEFT")
    raOverlay:SetPoint("BOTTOMRIGHT", page.controls.rotationAssistGlowRatio, "BOTTOMRIGHT")
    raOverlay:SetFrameLevel(page.controls.rotationAssistGlowRatio:GetFrameLevel() + 10)
    raOverlay:EnableMouse(true)
    raOverlay:Hide()

    setRAControlsEnabled = function(en)
        page.controls.rotationAssistGlowRatio:SetAlpha(en and 1 or 0.35)
        raOverlay:SetShown(not en)
    end
    setRAControlsEnabled(CDM.db.rotationAssistEnabled or false)

    local _, kbBody = AddSection(L["Keybindings"], "keybindings", 360, true)

    local setKBControlsEnabled
    page.controls.assistEnabled = UI.CreateModernCheckbox(
        kbBody,
        L["Enable Keybind Text"],
        CDM.db.assistEnabled or false,
        function(checked)
            CDM.db.assistEnabled = checked
            if setKBControlsEnabled then setKBControlsEnabled(checked) end
            API:Refresh("STYLE")
        end
    )
    page.controls.assistEnabled:SetPoint("TOPLEFT", 0, 0)

    page.controls.assistFontSize = UI.CreateModernSlider(
        kbBody, L["Font Size"], 1, 30, CDM.db.assistFontSize or 15,
        function(v)
            CDM.db.assistFontSize = v
            API:Refresh("STYLE")
        end
    )
    page.controls.assistFontSize:SetPoint("TOPLEFT", page.controls.assistEnabled, "BOTTOMLEFT", 0, -15)

    page.assistColorPicker = UI.CreateColorSwatch(kbBody, L["Color"], "assistColor", "STYLE")
    page.assistColorPicker:SetPoint("TOPLEFT", page.controls.assistFontSize, "BOTTOMLEFT", 0, -15)

    local lblPos = kbBody:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    lblPos:SetText(L["Position"])
    lblPos:SetPoint("TOPLEFT", page.assistColorPicker, "BOTTOMLEFT", 0, -15)

    local ddPos = UI.CreateDropdown(kbBody)
    ddPos:SetPoint("TOPLEFT", lblPos, "BOTTOMLEFT", 0, -10)
    ddPos:SetWidth(180)
    ddPos:SetDefaultText(CDM.db.assistPosition or "TOPRIGHT")
    page.assistPosDropdown = ddPos

    UI.SetupPositionDropdown(
        ddPos,
        function() return CDM.db.assistPosition end,
        function(pos)
            CDM.db.assistPosition = pos
            ddPos:SetDefaultText(pos)
            API:Refresh("STYLE")
        end
    )

    page.controls.assistOffsetX = UI.CreateModernSlider(
        kbBody, L["X Offset"], -20, 20, CDM.db.assistOffsetX or 0,
        function(v)
            CDM.db.assistOffsetX = v
            API:Refresh("STYLE")
        end
    )
    page.controls.assistOffsetX:SetPoint("TOPLEFT", ddPos, "BOTTOMLEFT", 0, -15)

    page.controls.assistOffsetY = UI.CreateModernSlider(
        kbBody, L["Y Offset"], -20, 20, CDM.db.assistOffsetY or 0,
        function(v)
            CDM.db.assistOffsetY = v
            API:Refresh("STYLE")
        end
    )
    page.controls.assistOffsetY:SetPoint("TOPLEFT", page.controls.assistOffsetX, "BOTTOMLEFT", 0, -15)

    local kbControls = {
        page.controls.assistFontSize, page.assistColorPicker,
        ddPos, page.controls.assistOffsetX, page.controls.assistOffsetY,
    }
    local kbRegions = { lblPos }

    local kbOverlay = CreateFrame("Frame", nil, kbBody)
    kbOverlay:SetPoint("TOPLEFT", page.controls.assistFontSize, "TOPLEFT")
    kbOverlay:SetPoint("BOTTOMRIGHT", page.controls.assistOffsetY, "BOTTOMRIGHT")
    local maxLevel = 0
    for _, ctrl in ipairs(kbControls) do
        local lvl = ctrl:GetFrameLevel()
        if lvl > maxLevel then maxLevel = lvl end
    end
    kbOverlay:SetFrameLevel(maxLevel + 10)
    kbOverlay:EnableMouse(true)
    kbOverlay:Hide()

    setKBControlsEnabled = function(en)
        local alpha = en and 1 or 0.35
        for _, ctrl in ipairs(kbControls) do
            ctrl:SetAlpha(alpha)
        end
        for _, region in ipairs(kbRegions) do
            region:SetAlpha(alpha)
        end
        kbOverlay:SetShown(not en)
    end
    setKBControlsEnabled(CDM.db.assistEnabled or false)
    Relayout()
end

API:RegisterConfigTab("assist", L["Assist"], CreateAssistTab, 7.5)
