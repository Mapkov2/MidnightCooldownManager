local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L


local function CreateFadingTab(page, tabId)
    local scrollChild, scrollFrame = UI.CreateScrollableTab(page, "MidnightCDM_FadingScrollFrame", 620, 560)
    local scrollFrameChild = scrollFrame:GetScrollChild()

    local mainHeader = UI.CreateHeader(scrollChild, L["Fading"])
    mainHeader:SetPoint("TOPLEFT", 0, 0)

    local setControlsEnabled
    page.controls.fadingEnabled = UI.CreateModernCheckbox(
        scrollChild,
        L["Enable Fading"],
        CDM.db.fadingEnabled or false,
        function(checked)
            CDM.db.fadingEnabled = checked
            if setControlsEnabled then setControlsEnabled(checked) end
            API:Refresh("STYLE")
        end
    )
    page.controls.fadingEnabled:SetPoint("TOPLEFT", mainHeader, "BOTTOMLEFT", 0, -15)

    local sectionHost = CreateFrame("Frame", nil, scrollChild)
    sectionHost:SetPoint("TOPLEFT", page.controls.fadingEnabled, "BOTTOMLEFT", 0, -15)
    sectionHost:SetSize(540, 520)

    local sections = {}
    local Relayout
    local function AddSection(title, key, height, defaultOpen)
        local section, body = UI.CreateAccordionSection(sectionHost, title, 540, height, "fading:" .. key, defaultOpen, function()
            if Relayout then Relayout() end
        end)
        sections[#sections + 1] = section
        return section, body
    end

    local triggerSection, triggerBody = AddSection(L["Fade Triggers"], "triggers", 135, true)
    local yOff = 0

    local noTargetCb, oocCb

    local function CreateExclusiveTrigger(key, otherKey, getOtherCb)
        return function(checked)
            CDM.db[key] = checked
            if checked then
                CDM.db[otherKey] = false
                getOtherCb():SetChecked(false)
            end
            API:Refresh("STYLE")
        end
    end

    noTargetCb = UI.CreateModernCheckbox(
        triggerBody,
        L["Fade when no target"],
        CDM.db.fadingTriggerNoTarget ~= false,
        CreateExclusiveTrigger("fadingTriggerNoTarget", "fadingTriggerOOC", function() return oocCb end)
    )
    noTargetCb:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30
    page.controls.noTargetCheckbox = noTargetCb

    oocCb = UI.CreateModernCheckbox(
        triggerBody,
        L["Fade out of combat"],
        CDM.db.fadingTriggerOOC or false,
        CreateExclusiveTrigger("fadingTriggerOOC", "fadingTriggerNoTarget", function() return noTargetCb end)
    )
    oocCb:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30
    page.controls.oocCheckbox = oocCb

    page.controls.mountedCheckbox = UI.CreateModernCheckbox(
        triggerBody,
        L["Fade when mounted"],
        CDM.db.fadingTriggerMounted or false,
        function(checked)
            CDM.db.fadingTriggerMounted = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.mountedCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 40

    page.controls.fadingOpacity = UI.CreateModernSlider(
        triggerBody, L["Faded Opacity"], 0, 100, CDM.db.fadingOpacity or 0,
        function(v)
            CDM.db.fadingOpacity = v
            API:Refresh("STYLE")
        end
    )
    page.controls.fadingOpacity:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50
    triggerSection:SetContentHeight(math.abs(yOff) + 4)

    local targetsSection, targetsBody = AddSection(L["Apply Fading To"], "targets", 225, true)
    yOff = 0

    local targetDefs = {
        { key = "fadingEssential",  label = L["Essential"] },
        { key = "fadingUtility",    label = L["Utility"] },
        { key = "fadingBuffs",      label = L["Buffs"] },
        { key = "fadingBuffBars",   label = L["Buff Bars"] },
        { key = "fadingRacials",    label = L["Racials"] },
        { key = "fadingDefensives", label = L["Defensives"] },
        { key = "fadingTrinkets",   label = L["Trinkets"] },
    }

    for _, def in ipairs(targetDefs) do
        local cb = UI.CreateModernCheckbox(
            targetsBody,
            def.label,
            CDM.db[def.key] ~= false,
            function(checked)
                CDM.db[def.key] = checked
                API:Refresh("STYLE")
            end
        )
        cb:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 30
        page.controls[def.key] = cb
    end
    targetsSection:SetContentHeight(math.abs(yOff) + 4)

    Relayout = function()
        UI.LayoutAccordionSections(sections, 0, 8)
        local total = 0
        for _, section in ipairs(sections) do
            if not section.IsShown or section:IsShown() then
                total = total + section:GetEffectiveHeight() + 8
            end
        end
        sectionHost:SetHeight(math.max(1, total))
        UI.FinalizeScroll(scrollFrameChild, scrollChild, -(95 + math.max(1, total)))
    end
    Relayout()

    setControlsEnabled = UI.SetupModuleToggle(scrollChild, page.controls.fadingEnabled)
    setControlsEnabled(CDM.db.fadingEnabled or false)
end

API:RegisterConfigTab("fading", L["Fading"], CreateFadingTab, 7)
