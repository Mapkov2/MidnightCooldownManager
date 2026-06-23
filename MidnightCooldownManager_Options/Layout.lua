local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local function CreateLayoutTab(page, tabId)
    local tabBar = UI.CreateSubTabBar(page, {
        { id = "cooldowns", label = L["Cooldowns"] },
        { id = "general", label = L["General"] },
        { id = "externals", label = L["Externals"] },
    }, "cooldowns")

    local subPages = tabBar.subPages

    if ns._CreateCooldownGroupsPanel then
        ns._CreateCooldownGroupsPanel(subPages.cooldowns, page)
    end

    local generalPage = subPages.general

    local divider = UI.CreateDivider(generalPage)
    divider:SetPoint("TOP", generalPage, "TOP", 0, 0)

    local content, scrollFrame = UI.CreateScrollableTab(generalPage, "MidnightCDM_LayoutGeneralScrollFrame", 520)
    local scrollChild = scrollFrame:GetScrollChild()

    local sections = {}
    local utilitySection
    local function Relayout()
        UI.LayoutAccordionSections(sections, 0, 8, scrollChild, content)
    end
    local function AddSection(title, key, height, defaultOpen)
        local section, body = UI.CreateAccordionSection(content, title, 540, height, "layout:general:" .. key, defaultOpen, Relayout)
        sections[#sections + 1] = section
        return section, body
    end

    local _, layoutBody = AddSection(L["Layout Settings"], "layout", 70, true)

    generalPage.controls.l1 = UI.CreateModernSlider(layoutBody, L["Icon Spacing"], -1, 30, CDM.db.spacing, function(v) CDM.db.spacing = v; API:Refresh("LAYOUT") end)
    generalPage.controls.l1:SetPoint("TOPLEFT", 0, 0)

    local _, essBody = AddSection(L["Essential"], "essential", 70, true)

    local maxRowEssSlider = UI.CreateModernSlider(essBody, L["Max Icons Per Row"], 1, 20, CDM.db.maxRowEss, function(v)
        CDM.db.maxRowEss = v; API:Refresh("LAYOUT")
    end)
    maxRowEssSlider:SetPoint("TOPLEFT", 0, 0)

    local utilityBody
    utilitySection, utilityBody = AddSection(L["Utility"], "utility", 250, true)

    local wrapCheckbox, utilWrapSlider, unlockCheckbox, xOffsetSlider, verticalCheckbox

    local function UpdateUtilityHeight()
        local height = 42
        if CDM.db.utilityWrap then
            height = CDM.db.utilityUnlock and 240 or 145
        end
        utilitySection:SetContentHeight(height)
        Relayout()
    end

    local function UpdateUnlockControls()
        local wrapOn = CDM.db.utilityWrap == true
        local unlockOn = CDM.db.utilityUnlock == true
        utilWrapSlider:SetShown(wrapOn)
        unlockCheckbox:SetShown(wrapOn)
        xOffsetSlider:SetShown(wrapOn and unlockOn)
        verticalCheckbox:SetShown(wrapOn and unlockOn)
        UpdateUtilityHeight()
    end

    wrapCheckbox = UI.CreateModernCheckbox(
        utilityBody,
        L["Wrap Utility Bar"],
        CDM.db.utilityWrap,
        function(checked)
            CDM.db.utilityWrap = checked
            UpdateUnlockControls()
            API:Refresh("LAYOUT")
        end
    )
    wrapCheckbox:SetPoint("TOPLEFT", 0, 0)

    utilWrapSlider = UI.CreateModernSlider(utilityBody, L["Utility Max Icons Per Row"], 1, 20, CDM.db.maxRowUtil, function(v)
        CDM.db.maxRowUtil = v; API:Refresh("LAYOUT")
    end)
    utilWrapSlider:SetPoint("TOPLEFT", wrapCheckbox, "BOTTOMLEFT", 0, -10)

    unlockCheckbox = UI.CreateModernCheckbox(
        utilityBody,
        L["Unlock Utility Bar"],
        CDM.db.utilityUnlock,
        function(checked)
            CDM.db.utilityUnlock = checked
            UpdateUnlockControls()
            API:Refresh("LAYOUT")
        end
    )
    unlockCheckbox:SetPoint("TOPLEFT", utilWrapSlider, "BOTTOMLEFT", 0, -10)

    xOffsetSlider = UI.CreateModernSlider(utilityBody, L["Utility X Offset"], -600, 600, CDM.db.utilityXOffset, function(v)
        CDM.db.utilityXOffset = v; API:Refresh("LAYOUT")
    end)
    xOffsetSlider:SetPoint("TOPLEFT", unlockCheckbox, "BOTTOMLEFT", 0, -10)

    verticalCheckbox = UI.CreateModernCheckbox(
        utilityBody,
        L["Display Vertical"],
        CDM.db.utilityVertical,
        function(checked)
            CDM.db.utilityVertical = checked
            UpdateUnlockControls()
            API:Refresh("LAYOUT")
        end
    )
    verticalCheckbox:SetPoint("TOPLEFT", xOffsetSlider, "BOTTOMLEFT", 0, -10)

    UpdateUnlockControls()
    generalPage:HookScript("OnShow", Relayout)

    if ns._CreateExternalsPanel then
        ns._CreateExternalsPanel(subPages.externals, page)
    end
end

API:RegisterConfigTab("layout", L["Layout"], CreateLayoutTab, 2)
