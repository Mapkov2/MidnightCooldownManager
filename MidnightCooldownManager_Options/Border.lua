local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local function BuildBorders(subPage, page)
    local rc, sc = UI.MakeSubPageScroll(subPage, "MidnightCDM_Border_BordersScrollFrame")
    local sections = {}
    local Relayout
    local function AddSection(title, key, height, defaultOpen)
        local section, body = UI.CreateAccordionSection(rc, title, 540, height, "border:borders:" .. key, defaultOpen, function()
            if Relayout then Relayout() end
        end)
        sections[#sections + 1] = section
        return section, body
    end

    local borderSection, borderBody = AddSection(L["Border Settings"], "settings", 390, true)
    local yOff = 0

    local lblDropdown = borderBody:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    lblDropdown:SetText(L["Border Texture"])
    lblDropdown:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 25

    local ddBorder = UI.CreateDropdown(borderBody)
    ddBorder:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 40
    ddBorder:SetWidth(220)
    ddBorder:SetDefaultText(CDM.db.borderFile or L["Select Border..."])
    page.dropdown = ddBorder

    UI.SetupMediaDropdown(
        ddBorder,
        "border",
        function() return CDM.db.borderFile end,
        function(name)
            CDM.db.borderFile = name
            API:Refresh("STYLE")
        end,
        function(name)
            ddBorder:SetDefaultText(name)
        end
    )

    local colorPicker = UI.CreateColorSwatch(borderBody, L["Border Color"], "borderColor", "STYLE")
    colorPicker:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 45
    page.colorPicker = colorPicker

    page.controls.b0 = UI.CreateModernSlider(borderBody, L["Border Size"], 1, 50, CDM.db.borderSize, function(v) CDM.db.borderSize = v; API:Refresh("STYLE") end)
    page.controls.b0:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 60

    page.controls.b1 = UI.CreateModernSlider(borderBody, L["Border Offset X"], -50, 50, CDM.db.borderOffsetX, function(v) CDM.db.borderOffsetX = v; API:Refresh("STYLE") end)
    page.controls.b1:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 60

    page.controls.b2 = UI.CreateModernSlider(borderBody, L["Border Offset Y"], -50, 50, CDM.db.borderOffsetY, function(v) CDM.db.borderOffsetY = v; API:Refresh("STYLE") end)
    page.controls.b2:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 60

    local function UpdateZoomLayout(showSlider)
        if showSlider then
            page.zoomSlider:Show()
            page.hideOverlayCheckbox:ClearAllPoints()
            page.hideOverlayCheckbox:SetPoint("TOPLEFT", page.zoomSlider, "BOTTOMLEFT", -20, -10)
        else
            page.zoomSlider:Hide()
            page.hideOverlayCheckbox:ClearAllPoints()
            page.hideOverlayCheckbox:SetPoint("TOPLEFT", page.zoomCheckbox, "BOTTOMLEFT", 0, -5)
        end
        borderSection:SetContentHeight(showSlider and 490 or 430)
        if Relayout then Relayout() end
    end

    page.zoomCheckbox = UI.CreateModernCheckbox(
        borderBody,
        L["Zoom Icons"],
        CDM.db.zoomIcons,
        function(checked)
            CDM.db.zoomIcons = checked
            UpdateZoomLayout(checked)
            API:Refresh("STYLE")
        end
    )
    page.zoomCheckbox:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 35

    page.zoomSlider = UI.CreateModernSliderPrecise(borderBody, L["Zoom Amount"], 0, 0.3, CDM.db.zoomAmount or 0.08, 0.01, 2, function(v)
        CDM.db.zoomAmount = v
        API:Refresh("STYLE")
    end)
    page.zoomSlider:SetPoint("TOPLEFT", page.zoomCheckbox, "BOTTOMLEFT", 20, -5)

    page.hideOverlayCheckbox = UI.CreateModernCheckbox(
        borderBody,
        L["Remove Shadow Overlay"],
        CDM.db.hideIconOverlay ~= false,
        function(checked)
            CDM.db.hideIconOverlay = checked
            API:Refresh("STYLE")
        end
    )
    yOff = yOff - 30

    page.hideOverlayTextureCheckbox = UI.CreateModernCheckbox(
        borderBody,
        L["Remove Default Icon Mask"],
        CDM.db.hideIconOverlayTexture ~= false,
        function(checked)
            CDM.db.hideIconOverlayTexture = checked
            API:Refresh("STYLE")
        end
    )
    page.hideOverlayTextureCheckbox:SetPoint("TOPLEFT", page.hideOverlayCheckbox, "BOTTOMLEFT", 0, -5)
    yOff = yOff - 35

    UpdateZoomLayout(CDM.db.zoomIcons)

    local visualSection, visualBody = AddSection(L["Visual Elements"], "visual", 92, true)
    yOff = 0

    local reloadWarning = visualBody:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    reloadWarning:SetPoint("TOPLEFT", 0, yOff)
    reloadWarning:SetText(L["* These options require /reload to take effect"])
    UI.SetTextMuted(reloadWarning)
    yOff = yOff - 28

    page.hideDebuffBorderCheckbox = UI.CreateModernCheckbox(
        visualBody,
        L["Hide Debuff Border (red outline on harmful effects)"],
        CDM.db.hideDebuffBorder or false,
        function(checked)
            CDM.db.hideDebuffBorder = checked
        end
    )
    page.hideDebuffBorderCheckbox:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 30

    page.hideCooldownBlingCheckbox = UI.CreateModernCheckbox(
        visualBody,
        L["Hide Cooldown Bling (flash animation on cooldown completion)"],
        CDM.db.hideCooldownBling or false,
        function(checked)
            CDM.db.hideCooldownBling = checked
        end
    )
    page.hideCooldownBlingCheckbox:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 30

    visualSection:SetContentHeight(math.abs(yOff) + 4)
    Relayout = function()
        UI.LayoutAccordionSections(sections, 0, 8, sc, rc)
    end
    Relayout()
end

local function BuildLook(subPage, page)
    local rc, sc = UI.MakeSubPageScroll(subPage, "MidnightCDM_Border_LookScrollFrame")
    local sections = {}
    local Relayout
    local function AddSection(title, key, height, defaultOpen)
        local section, body = UI.CreateAccordionSection(rc, title, 540, height, "border:look:" .. key, defaultOpen, function()
            if Relayout then Relayout() end
        end)
        sections[#sections + 1] = section
        return section, body
    end

    local swipeSection, swipeBody = AddSection(L["Cooldown Swipe"], "swipe", 300, true)
    local yOff = 0

    local hideGCDSwipeCheckbox = UI.CreateModernCheckbox(
        swipeBody,
        L["Hide GCD Swipe"],
        CDM.db.hideGCDSwipe,
        function(checked)
            CDM.db.hideGCDSwipe = checked
            API:Refresh("STYLE")
        end
    )
    hideGCDSwipeCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    local hideBuffSwipeCheckbox = UI.CreateModernCheckbox(
        swipeBody,
        L["Hide Buff Swipe"],
        CDM.db.hideBuffSwipe,
        function(checked)
            CDM.db.hideBuffSwipe = checked
            if CDM.CustomBuffs and CDM.CustomBuffs.iconFrames then
                for _, frame in pairs(CDM.CustomBuffs.iconFrames) do
                    if frame.Cooldown then
                        frame.Cooldown:SetDrawSwipe(not checked)
                    end
                end
            end
            API:Refresh("STYLE")
        end
    )
    hideBuffSwipeCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    local swipeColorLabel = swipeBody:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    swipeColorLabel:SetText(L["Swipe Color"])
    swipeColorLabel:SetPoint("TOPLEFT", 0, yOff)

    local swipeInit = CDM.db.swipeColor or { r = 0, g = 0, b = 0, a = 0.6 }
    local swipeColorPicker = UI.CreateSimpleColorPicker(swipeBody, swipeInit, function(r, g, b)
        CDM.db.swipeColor = { r = r, g = g, b = b, a = CDM.db.swipeColor and CDM.db.swipeColor.a or 0.6 }
        API:Refresh("STYLE")
    end)
    swipeColorPicker:SetPoint("LEFT", swipeColorLabel, "RIGHT", 6, 0)
    yOff = yOff - 25

    local swipeAlphaSlider = UI.CreateModernSlider(swipeBody, L["Swipe Opacity"], 0, 100,
        math.floor((swipeInit.a or 0.6) * 100),
        function(v)
            local sc2 = CDM.db.swipeColor or { r = 0, g = 0, b = 0, a = 0.6 }
            CDM.db.swipeColor = { r = sc2.r, g = sc2.g, b = sc2.b, a = v / 100 }
            API:Refresh("STYLE")
        end)
    swipeAlphaSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 45

    local disableDesatCheckbox = UI.CreateModernCheckbox(
        swipeBody,
        L["Don't desaturate on cooldown"],
        CDM.db.disableCooldownDesat or false,
        function(checked)
            CDM.db.disableCooldownDesat = checked
            API:Refresh("STYLE")
        end
    )
    disableDesatCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 40

    local cooldownTintCheckbox = UI.CreateModernCheckbox(
        swipeBody,
        L["Color cooldown icons while on cooldown"],
        CDM.db.cooldownIconTintEnabled or false,
        function(checked)
            CDM.db.cooldownIconTintEnabled = checked
            API:Refresh("STYLE")
        end
    )
    cooldownTintCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    local buffTintCheckbox = UI.CreateModernCheckbox(
        swipeBody,
        L["Color buff icons while timer is active"],
        CDM.db.buffIconTintEnabled or false,
        function(checked)
            CDM.db.buffIconTintEnabled = checked
            API:Refresh("STYLE")
        end
    )
    buffTintCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 35

    local tintColorPicker = UI.CreateColorSwatch(swipeBody, L["Cooldown Icon Color"], "cooldownIconTintColor", "STYLE")
    tintColorPicker:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 45

    swipeSection:SetContentHeight(math.abs(yOff) + 4)

    local chargeSection, chargeBody = AddSection(L["Charge Cooldowns"], "charges", 100, true)
    yOff = 0

    local showEdgeCheckbox = UI.CreateModernCheckbox(
        chargeBody,
        L["Show Edge"],
        CDM.db.chargeShowEdge or false,
        function(checked)
            CDM.db.chargeShowEdge = checked
            API:Refresh("STYLE")
        end
    )
    showEdgeCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    local hideSwipeCheckbox = UI.CreateModernCheckbox(
        chargeBody,
        L["Hide Swipe"],
        CDM.db.chargeHideSwipe or false,
        function(checked)
            CDM.db.chargeHideSwipe = checked
            API:Refresh("STYLE")
        end
    )
    hideSwipeCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    local hideRechargeTimerCheckbox = UI.CreateModernCheckbox(
        chargeBody,
        L["Hide recharge timer"],
        CDM.db.chargeHideRechargeTimer or false,
        function(checked)
            CDM.db.chargeHideRechargeTimer = checked
            API:Refresh("STYLE")
        end
    )
    hideRechargeTimerCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 40
    chargeSection:SetContentHeight(math.abs(yOff) + 4)

    local pandemicSection, pandemicBody = AddSection(L["Pandemic Display"], "pandemic", 180, false)
    yOff = 0

    local hidePandemicCheckbox
    local enableCustomizationCheckbox
    local pandemicBorderCheckbox
    local pandemicBorderColorBuffBarsCheckbox
    local pandemicBorderColor

    local function UpdatePandemicEnableState()
        local hideEnabled = CDM.db.hidePandemicIndicator == true
        local customizationEnabled = hideEnabled and (CDM.db.pandemicCustomizationEnabled == true)

        enableCustomizationCheckbox:SetEnabled(hideEnabled)
        pandemicBorderCheckbox:SetEnabled(customizationEnabled)

        local borderColorEnabled = customizationEnabled and (CDM.db.pandemicBorderEnabled == true)
        pandemicBorderColorBuffBarsCheckbox:SetEnabled(borderColorEnabled)
        pandemicBorderColor:SetEnabled(borderColorEnabled)
    end

    hidePandemicCheckbox = UI.CreateModernCheckbox(
        pandemicBody,
        L["Hide Blizzard's Pandemic Indicator (animated refresh window border)"],
        CDM.db.hidePandemicIndicator or false,
        function(checked)
            CDM.db.hidePandemicIndicator = checked
            UpdatePandemicEnableState()
            API:Refresh("STYLE")
        end
    )
    hidePandemicCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    enableCustomizationCheckbox = UI.CreateModernCheckbox(
        pandemicBody,
        L["Enable Pandemic Customization"],
        CDM.db.pandemicCustomizationEnabled or false,
        function(checked)
            CDM.db.pandemicCustomizationEnabled = checked
            UpdatePandemicEnableState()
            API:Refresh("STYLE")
        end
    )
    enableCustomizationCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 40

    pandemicBorderCheckbox = UI.CreateModernCheckbox(
        pandemicBody,
        L["Custom Pandemic Border"],
        CDM.db.pandemicBorderEnabled or false,
        function(checked)
            CDM.db.pandemicBorderEnabled = checked
            UpdatePandemicEnableState()
            API:Refresh("STYLE")
        end
    )
    pandemicBorderCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    pandemicBorderColorBuffBarsCheckbox = UI.CreateModernCheckbox(
        pandemicBody,
        L["Color Buff Bars Borders"],
        CDM.db.pandemicBorderColorBuffBars or false,
        function(checked)
            CDM.db.pandemicBorderColorBuffBars = checked
            API:Refresh("STYLE")
        end
    )
    pandemicBorderColorBuffBarsCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    pandemicBorderColor = UI.CreateColorSwatch(pandemicBody, L["Color"], "pandemicBorderColor", "STYLE")
    pandemicBorderColor:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50
    pandemicSection:SetContentHeight(math.abs(yOff) + 4)

    UpdatePandemicEnableState()

    Relayout = function()
        UI.LayoutAccordionSections(sections, 0, 8, sc, rc)
    end
    Relayout()
end

local SUB_TAB_IDS = { "borders", "look" }

local function CreateBorderTab(page, tabId)
    local subTabs = UI.CreateSubTabBar(page, {
        { id = "borders", label = L["Borders"] },
        { id = "look",    label = L["Look"] },
    }, "borders")

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

    BuildBorders(subTabs.subPages.borders, page)
    BuildLook(subTabs.subPages.look, page)
end

API:RegisterConfigTab("border", L["Borders & Look"], CreateBorderTab, 4)
