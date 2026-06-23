local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local L = Runtime.L
local UI = ns.ConfigUI

local SLIDER_LABEL_W = 130
local SLIDER_W = 220

local OUTLINE_OPTIONS = {
    { value = "",             label = L["None"] },
    { value = "OUTLINE",      label = L["Outline"] },
    { value = "THICKOUTLINE", label = L["Thick Outline"] },
    { value = "SLUG",         label = L["Slug"] },
}

local TEXT_MODES = {
    { value = "NONE",    label = L["None"] },
    { value = "PERCENT", label = L["Percent"] },
    { value = "VALUE",   label = L["Value"] },
    { value = "CURMAX",  label = L["Current / Max"] },
}

local function OutlineLabel(value)
    return UI.GetOptionLabel(OUTLINE_OPTIONS, value, L["Outline"])
end

local function SetDB(key, scope)
    return function(v)
        CDM.db[key] = v
        API:Refresh(scope or "STYLE")
    end
end

local function Slider(page, rc, label, minV, maxV, key, yOff, defaultVal, scope)
    local initial = CDM.db[key]
    if initial == nil then initial = CDM.defaults[key] end
    if initial == nil then initial = defaultVal or 0 end
    local slider = UI.CreateModernSlider(rc, label, minV, maxV, initial, SetDB(key, scope),
        SLIDER_LABEL_W, SLIDER_W)
    slider:SetPoint("TOPLEFT", 0, yOff)
    page.controls[key] = slider
    return slider
end

local function ColorSwatch(rc, label, key, yOff, scope)
    local swatch = UI.CreateColorSwatch(rc, label, key, scope or "STYLE")
    swatch:SetPoint("TOPLEFT", 0, yOff)
    return swatch
end

local function FontDropdown(rc, yOff, page)
    local lbl = rc:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    lbl:SetText(L["Font"])
    lbl:SetPoint("TOPLEFT", 0, yOff)

    local dd = UI.CreateDropdown(rc)
    dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -10)
    dd:SetWidth(220)
    dd:SetDefaultText(CDM.db.textFont or "Friz Quadrata TT")
    UI.SetupMediaDropdown(dd, "font",
        function() return CDM.db.textFont end,
        function(name) CDM.db.textFont = name; API:Refresh("STYLE", "RESOURCES") end,
        function(name) dd:SetDefaultText(name) end)
    page.fontDropdown = dd
end

local function OutlineDropdown(rc, yOff, page)
    local lbl = rc:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    lbl:SetText(L["Font Outline"])
    lbl:SetPoint("TOPLEFT", 0, yOff)

    local dd = UI.CreateDropdown(rc)
    dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -10)
    dd:SetWidth(220)
    dd:SetDefaultText(OutlineLabel(CDM.db.textFontOutline))
    UI.SetupValueDropdown(dd, OUTLINE_OPTIONS,
        function() return CDM.db.textFontOutline end,
        function(value, label)
            CDM.db.textFontOutline = value
            dd:SetDefaultText(label)
            API:Refresh("STYLE", "RESOURCES")
        end)
    page.outlineDropdown = dd
end

local function PositionDropdown(rc, label, key, yOff, positions)
    local lbl = rc:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    lbl:SetText(label)
    lbl:SetPoint("TOPLEFT", 0, yOff)

    local dd = UI.CreateDropdown(rc)
    dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -10)
    dd:SetWidth(180)
    dd:SetDefaultText(CDM.db[key] or CDM.defaults[key] or "CENTER")
    UI.SetupPositionDropdown(dd,
        function() return CDM.db[key] end,
        function(pos)
            CDM.db[key] = pos
            dd:SetDefaultText(pos)
            API:Refresh("STYLE")
        end,
        positions)
    return dd
end

local function ValueDropdown(rc, label, key, yOff, options, width, scope)
    local lbl = rc:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    lbl:SetText(label)
    lbl:SetPoint("TOPLEFT", 0, yOff)
    UI.SetTextSubtle(lbl)

    local current = CDM.db[key]
    if current == nil then current = CDM.defaults[key] end
    local dd = UI.CreateDropdown(rc, width or 180)
    dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -10)
    dd:SetDefaultText(UI.GetOptionLabel(options, current, tostring(current or "")))
    UI.SetupValueDropdown(dd, options,
        function() return CDM.db[key] end,
        function(value, labelText)
            CDM.db[key] = value
            dd:SetDefaultText(labelText or value)
            API:Refresh(scope or "RESOURCES")
        end)
    return dd
end

local function Checkbox(page, rc, label, key, yOff, scope)
    local initial = CDM.db[key]
    if initial == nil then initial = CDM.defaults[key] end
    local chk = UI.CreateModernCheckbox(rc, label, initial == true, function(checked)
        CDM.db[key] = checked and true or false
        API:Refresh(scope or "RESOURCES")
    end)
    chk:SetPoint("TOPLEFT", 0, yOff)
    page.controls[key] = chk
    return chk
end

local BAR_TEXT_POSITIONS = { "LEFT", "CENTER", "RIGHT" }

local function CreateAccordionFlow(rc, sc, prefix)
    local sections = {}
    local function Relayout()
        UI.LayoutAccordionSections(sections, 0, 8, sc, rc)
    end
    local function AddSection(title, key, defaultOpen)
        local section, body = UI.CreateAccordionSection(rc, title, 540, 120, "text:" .. prefix .. ":" .. key, defaultOpen, Relayout)
        sections[#sections + 1] = section
        return section, body
    end
    return AddSection, Relayout
end

local function BuildGlobal(subPage, page)
    local rc, sc = UI.MakeSubPageScroll(subPage, "MidnightCDM_Text_GlobalScrollFrame")
    local AddSection, Relayout = CreateAccordionFlow(rc, sc, "global")

    local globalSection, globalBody = AddSection(L["Global"], "global", true)
    local yOff = 0

    FontDropdown(globalBody, yOff, page); yOff = yOff - 55
    OutlineDropdown(globalBody, yOff, page); yOff = yOff - 65
    globalSection:SetContentHeight(math.abs(yOff) + 4)

    local timerSection, timerBody = AddSection(L["Cooldown Timer"], "timer", true)
    yOff = 0
    ColorSwatch(timerBody, L["Color"], "cooldownColor", yOff); yOff = yOff - 45
    timerSection:SetContentHeight(math.abs(yOff) + 4)

    local formatSection, formatBody = AddSection(L["Cooldown Countdown Format"], "format", true)
    yOff = 0

    local decSlider = UI.CreateModernSliderPrecise(formatBody,
        L["Show decimals below (seconds, 0 = off)"], 0, 10,
        CDM.db.cooldownDecimalThreshold, 0.5, 1,
        function(v)
            CDM.db.cooldownDecimalThreshold = v
            API:Refresh("STYLE")
        end)
    decSlider:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 60
    formatSection:SetContentHeight(math.abs(yOff) + 4)

    local thresholdSection, thresholdBody = AddSection(L["Threshold Color"], "threshold", true)
    yOff = 0

    local chk = UI.CreateModernCheckbox(thresholdBody, L["Color countdown below threshold"],
        CDM.db.cooldownColorThresholdEnabled,
        function(checked)
            CDM.db.cooldownColorThresholdEnabled = checked
            API:Refresh("STYLE")
        end)
    chk:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 35

    local thrSlider = UI.CreateModernSliderPrecise(thresholdBody,
        L["Threshold (seconds)"], 1, 30,
        CDM.db.cooldownColorThreshold, 0.5, 1,
        function(v)
            CDM.db.cooldownColorThreshold = v
            API:Refresh("STYLE")
        end)
    thrSlider:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 60

    ColorSwatch(thresholdBody, L["Color"], "cooldownColorThresholdColor", yOff); yOff = yOff - 45
    thresholdSection:SetContentHeight(math.abs(yOff) + 4)
    Relayout()
end

local function BuildEssential(subPage, page)
    local rc, sc = UI.MakeSubPageScroll(subPage, "MidnightCDM_Text_EssentialScrollFrame")
    local AddSection, Relayout = CreateAccordionFlow(rc, sc, "essential")

    local timerSection, timerBody = AddSection(L["Cooldown Timer"], "timer", true)
    local yOff = 0
    Slider(page, timerBody, L["Row 1 Font Size"], 8, 32, "cooldownFontSize", yOff, 12); yOff = yOff - 60
    Slider(page, timerBody, L["Row 2 Font Size"], 8, 32, "essRow2CooldownFontSize", yOff, 12); yOff = yOff - 60
    timerSection:SetContentHeight(math.abs(yOff) + 4)

    local row1Section, row1Body = AddSection(L["Row 1 - Stacks (Charges)"], "row1-stacks", true)
    yOff = 0
    Slider(page, row1Body, L["Font Size"], 8, 32, "chargeFontSize", yOff, 12); yOff = yOff - 60
    ColorSwatch(row1Body, L["Color"], "chargeColor", yOff); yOff = yOff - 45
    PositionDropdown(row1Body, L["Position"], "chargePosition", yOff); yOff = yOff - 60
    Slider(page, row1Body, L["X Offset"], -50, 50, "chargeOffsetX", yOff, 0); yOff = yOff - 50
    Slider(page, row1Body, L["Y Offset"], -50, 50, "chargeOffsetY", yOff, 0); yOff = yOff - 50
    row1Section:SetContentHeight(math.abs(yOff) + 4)

    local row2Section, row2Body = AddSection(L["Row 2 - Stacks (Charges)"], "row2-stacks", true)
    yOff = 0
    Slider(page, row2Body, L["Font Size"], 8, 32, "essRow2ChargeFontSize", yOff, 15); yOff = yOff - 60
    ColorSwatch(row2Body, L["Color"], "essRow2ChargeColor", yOff); yOff = yOff - 45
    PositionDropdown(row2Body, L["Position"], "essRow2ChargePosition", yOff); yOff = yOff - 60
    Slider(page, row2Body, L["X Offset"], -50, 50, "essRow2ChargeOffsetX", yOff, 0); yOff = yOff - 50
    Slider(page, row2Body, L["Y Offset"], -50, 50, "essRow2ChargeOffsetY", yOff, 0); yOff = yOff - 50
    row2Section:SetContentHeight(math.abs(yOff) + 4)
    Relayout()
end

local function BuildUtility(subPage, page)
    local rc, sc = UI.MakeSubPageScroll(subPage, "MidnightCDM_Text_UtilityScrollFrame")
    local AddSection, Relayout = CreateAccordionFlow(rc, sc, "utility")

    local timerSection, timerBody = AddSection(L["Cooldown Timer"], "timer", true)
    local yOff = 0
    Slider(page, timerBody, L["Font Size"], 8, 32, "utilityCooldownFontSize", yOff, 12); yOff = yOff - 60
    timerSection:SetContentHeight(math.abs(yOff) + 4)

    local stacksSection, stacksBody = AddSection(L["Stacks (Charges)"], "stacks", true)
    yOff = 0
    Slider(page, stacksBody, L["Font Size"], 8, 32, "utilityChargeFontSize", yOff, 12); yOff = yOff - 60
    ColorSwatch(stacksBody, L["Color"], "utilityChargeColor", yOff); yOff = yOff - 45
    PositionDropdown(stacksBody, L["Position"], "utilityChargePosition", yOff); yOff = yOff - 60
    Slider(page, stacksBody, L["X Offset"], -50, 50, "utilityChargeOffsetX", yOff, 0); yOff = yOff - 50
    Slider(page, stacksBody, L["Y Offset"], -50, 50, "utilityChargeOffsetY", yOff, 0); yOff = yOff - 50
    stacksSection:SetContentHeight(math.abs(yOff) + 4)
    Relayout()
end

local function BuildBuffIcons(subPage, page)
    local rc, sc = UI.MakeSubPageScroll(subPage, "MidnightCDM_Text_BuffIconsScrollFrame")
    local AddSection, Relayout = CreateAccordionFlow(rc, sc, "bufficons")

    local timerSection, timerBody = AddSection(L["Cooldown Timer"], "timer", true)
    local yOff = 0

    Slider(page, timerBody, L["Font Size"], 8, 32, "buffCooldownFontSize", yOff, 15); yOff = yOff - 60
    ColorSwatch(timerBody, L["Color"], "buffCooldownColor", yOff); yOff = yOff - 45
    timerSection:SetContentHeight(math.abs(yOff) + 4)

    local stacksSection, stacksBody = AddSection(L["Stacks (Charges)"], "stacks", true)
    yOff = 0
    Slider(page, stacksBody, L["Font Size"], 8, 32, "countFontSize", yOff, 15); yOff = yOff - 60
    ColorSwatch(stacksBody, L["Color"], "countColor", yOff); yOff = yOff - 45
    PositionDropdown(stacksBody, L["Position"], "countPositionMain", yOff); yOff = yOff - 60
    Slider(page, stacksBody, L["X Offset"], -20, 20, "countOffsetXMain", yOff, 0); yOff = yOff - 50
    Slider(page, stacksBody, L["Y Offset"], -20, 20, "countOffsetYMain", yOff, 4); yOff = yOff - 50
    stacksSection:SetContentHeight(math.abs(yOff) + 4)
    Relayout()
end

local function BuildBuffBars(subPage, page)
    local rc, sc = UI.MakeSubPageScroll(subPage, "MidnightCDM_Text_BuffBarsScrollFrame")
    local AddSection, Relayout = CreateAccordionFlow(rc, sc, "buffbars")

    local nameSection, nameBody = AddSection(L["Name Text"], "name", true)
    local yOff = 0

    Slider(page, nameBody, L["Font Size"], 8, 24, "buffBarNameFontSize", yOff, 15); yOff = yOff - 60
    ColorSwatch(nameBody, L["Color"], "buffBarNameColor", yOff); yOff = yOff - 45
    Slider(page, nameBody, L["X Offset"], -50, 50, "buffBarNameOffsetX", yOff, 2); yOff = yOff - 50
    Slider(page, nameBody, L["Y Offset"], -20, 20, "buffBarNameOffsetY", yOff, 0); yOff = yOff - 50
    nameSection:SetContentHeight(math.abs(yOff) + 4)

    local durationSection, durationBody = AddSection(L["Duration Text"], "duration", true)
    yOff = 0
    Slider(page, durationBody, L["Font Size"], 8, 24, "buffBarDurationFontSize", yOff, 15); yOff = yOff - 60
    ColorSwatch(durationBody, L["Color"], "buffBarDurationColor", yOff); yOff = yOff - 45
    PositionDropdown(durationBody, L["Anchor"], "buffBarDurationPosition", yOff, BAR_TEXT_POSITIONS); yOff = yOff - 60
    Slider(page, durationBody, L["X Offset"], -50, 50, "buffBarDurationOffsetX", yOff, -2); yOff = yOff - 50
    Slider(page, durationBody, L["Y Offset"], -20, 20, "buffBarDurationOffsetY", yOff, 0); yOff = yOff - 50
    durationSection:SetContentHeight(math.abs(yOff) + 4)

    local stacksSection, stacksBody = AddSection(L["Stack Count Text"], "stacks", true)
    yOff = 0
    Slider(page, stacksBody, L["Font Size"], 8, 24, "buffBarApplicationsFontSize", yOff, 15); yOff = yOff - 60
    ColorSwatch(stacksBody, L["Color"], "buffBarApplicationsColor", yOff); yOff = yOff - 45
    PositionDropdown(stacksBody, L["Anchor"], "buffBarApplicationsPosition", yOff, BAR_TEXT_POSITIONS); yOff = yOff - 60
    Slider(page, stacksBody, L["X Offset"], -50, 50, "buffBarApplicationsOffsetX", yOff, 0); yOff = yOff - 50
    Slider(page, stacksBody, L["Y Offset"], -50, 50, "buffBarApplicationsOffsetY", yOff, 0); yOff = yOff - 50
    stacksSection:SetContentHeight(math.abs(yOff) + 4)
    Relayout()
end

local function BuildClassResourceText(subPage, page)
    local rc, sc = UI.MakeSubPageScroll(subPage, "MidnightCDM_Text_ClassResourceScrollFrame")
    local AddSection, Relayout = CreateAccordionFlow(rc, sc, "class-resource")

    local resourceSection, resourceBody = AddSection(L["Class Resource Text"], "resource", true)
    local yOff = 0
    Checkbox(page, resourceBody, L["Show Resource Text"], "resourceShowText", yOff); yOff = yOff - 35
    Slider(page, resourceBody, L["Resource Font Size"], 6, 36, "resourceTextSize", yOff, 14, "RESOURCES"); yOff = yOff - 60
    Checkbox(page, resourceBody, L["Show Rune Recharge Text"], "resourceRuneShowTime", yOff); yOff = yOff - 35
    Slider(page, resourceBody, L["Rune Recharge Font Size"], 6, 30, "resourceRuneTextSize", yOff, 11, "RESOURCES"); yOff = yOff - 60
    resourceSection:SetContentHeight(math.abs(yOff) + 4)
    Relayout()
end

local function BuildPowerBarText(subPage, page)
    local rc, sc = UI.MakeSubPageScroll(subPage, "MidnightCDM_Text_PowerBarScrollFrame")
    local AddSection, Relayout = CreateAccordionFlow(rc, sc, "power-bar")

    local textSection, textBody = AddSection(L["Player Power Bar Text"], "text", true)
    local yOff = 0
    ValueDropdown(textBody, L["Text"], "resourcePowerBarTextMode", yOff, TEXT_MODES, 180, "RESOURCES"); yOff = yOff - 60
    Slider(page, textBody, L["Font Size"], 6, 36, "resourcePowerBarTextSize", yOff, 13, "RESOURCES"); yOff = yOff - 60
    textSection:SetContentHeight(math.abs(yOff) + 4)
    Relayout()
end

local function BuildHPBarText(subPage, page)
    local rc, sc = UI.MakeSubPageScroll(subPage, "MidnightCDM_Text_HPBarScrollFrame")
    local AddSection, Relayout = CreateAccordionFlow(rc, sc, "hp-bar")

    local textSection, textBody = AddSection(L["Second Player HP Bar Text"], "text", true)
    local yOff = 0
    ValueDropdown(textBody, L["Text"], "resourceHPBarTextMode", yOff, TEXT_MODES, 180, "RESOURCES"); yOff = yOff - 60
    Slider(page, textBody, L["Font Size"], 6, 36, "resourceHPBarTextSize", yOff, 13, "RESOURCES"); yOff = yOff - 60
    textSection:SetContentHeight(math.abs(yOff) + 4)
    Relayout()
end

local SUB_TAB_IDS = { "global", "essential", "utility", "bufficons", "buffbars", "classresource", "powerbar", "hpbar" }

local function CreateTextTab(page, tabId)
    local subTabs = UI.CreateSubTabBar(page, {
        { id = "global",    label = L["Global"] },
        { id = "essential", label = L["Essential"] },
        { id = "utility",   label = L["Utility"] },
        { id = "bufficons", label = L["Buff Icons"] },
        { id = "buffbars",  label = L["Buff Bars"] },
        { id = "classresource", label = L["Class Res"] },
        { id = "powerbar",  label = L["Power Bar"] },
        { id = "hpbar",     label = L["HP Bar"] },
    }, "global")

    local divider = UI.CreateDivider(page)
    local dividerH = 1
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", subTabs.barFrame, "BOTTOMLEFT", -30, 0)
    divider:SetPoint("TOPRIGHT", subTabs.barFrame, "BOTTOMRIGHT", 30, 0)
    divider:SetHeight(dividerH)

    for _, id in ipairs(SUB_TAB_IDS) do
        local pg = subTabs.subPages[id]
        pg:ClearAllPoints()
        pg:SetPoint("TOPLEFT", subTabs.barFrame, "BOTTOMLEFT", -30, -15)
        pg:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 20)
    end

    BuildGlobal(subTabs.subPages.global, page)
    BuildEssential(subTabs.subPages.essential, page)
    BuildUtility(subTabs.subPages.utility, page)
    BuildBuffIcons(subTabs.subPages.bufficons, page)
    BuildBuffBars(subTabs.subPages.buffbars, page)
    BuildClassResourceText(subTabs.subPages.classresource, page)
    BuildPowerBarText(subTabs.subPages.powerbar, page)
    BuildHPBarText(subTabs.subPages.hpbar, page)
end

API:RegisterConfigTab("text", L["Text"], CreateTextTab, 5)
