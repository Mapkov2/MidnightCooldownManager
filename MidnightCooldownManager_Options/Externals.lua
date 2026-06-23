local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L


function ns._CreateExternalsPanel(page, parentPage)
    local divider = UI.CreateDivider(page)
    divider:SetPoint("TOP", page, "TOP", 0, 0)

    local content = CreateFrame("Frame", nil, page)
    content:SetPoint("TOPLEFT", 35, -40)
    content:SetPoint("BOTTOMRIGHT", -25, 20)

    local sections = {}
    local function Relayout()
        UI.LayoutAccordionSections(sections, -35, 8)
    end
    local function AddSection(title, key, height)
        local section, body = UI.CreateAccordionSection(content, title, 540, height, "externals:" .. key, true, Relayout)
        sections[#sections + 1] = section
        return section, body
    end

    local enabled = CDM.db.externalsEnabled ~= false
    local setControlsEnabled
    page.controls.externalsEnabled = UI.CreateModernCheckbox(
        content,
        L["Enable Externals"],
        enabled,
        function(checked)
            CDM.db.externalsEnabled = checked
            if setControlsEnabled then setControlsEnabled(checked) end
            API:Refresh("TRACKERS")
        end
    )
    page.controls.externalsEnabled:SetPoint("TOPLEFT", 0, 0)

    local _, iconSizeBody = AddSection(L["Icon Size"], "icon-size", 130)

    page.controls.externalsIconWidthSlider = UI.CreateModernSlider(
        iconSizeBody,
        L["Icon Width"],
        20, 100,
        CDM.db.externalsIconWidth or 30,
        function(v)
            CDM.db.externalsIconWidth = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.controls.externalsIconWidthSlider:SetPoint("TOPLEFT", 0, 0)

    page.controls.externalsIconHeightSlider = UI.CreateModernSlider(
        iconSizeBody,
        L["Icon Height"],
        20, 100,
        CDM.db.externalsIconHeight or 30,
        function(v)
            CDM.db.externalsIconHeight = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.controls.externalsIconHeightSlider:SetPoint("TOPLEFT", page.controls.externalsIconWidthSlider, "BOTTOMLEFT", 0, -10)

    local _, cooldownBody = AddSection(L["Cooldown"], "cooldown", 120)

    page.controls.externalsCooldownFontSizeSlider = UI.CreateModernSlider(
        cooldownBody,
        L["Font Size"],
        8, 32,
        CDM.db.externalsCooldownFontSize or 15,
        function(v)
            CDM.db.externalsCooldownFontSize = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.controls.externalsCooldownFontSizeSlider:SetPoint("TOPLEFT", 0, 0)

    local blinkDefault = CDM.db.externalsDisableBlink
    if blinkDefault == nil then blinkDefault = true end
    page.controls.externalsDisableBlinkCheckbox = UI.CreateModernCheckbox(
        cooldownBody,
        L["Disable Blink"],
        blinkDefault,
        function(checked)
            CDM.db.externalsDisableBlink = checked
            API:Refresh("TRACKERS")
        end
    )
    page.controls.externalsDisableBlinkCheckbox:SetPoint("TOPLEFT", page.controls.externalsCooldownFontSizeSlider, "BOTTOMLEFT", 0, -10)

    setControlsEnabled = UI.SetupModuleToggle(content, page.controls.externalsEnabled)
    setControlsEnabled(enabled)
    Relayout()
end
