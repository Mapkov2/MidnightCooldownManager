local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L


local CDM_C = CDM.CONST
local Shared = ns.GroupEditorShared
local BUILTIN_SET = CDM_C.DEFENSIVE_SPELLS_SET
local DEFENSIVE_SPELLS = CDM_C.DEFENSIVE_SPELLS
local _, playerClassTag = UnitClass("player")

local CLASS_LIST = {}
local CLASS_SPECS = {}
local OVERLAY_SWITCH_COLUMN_WIDTH = 68
local OVERLAY_ICON_GAP = 8
do
    local allClasses, allSpecs = Shared.GetClassCatalog()
    for _, classInfo in ipairs(allClasses) do
        if DEFENSIVE_SPELLS[classInfo.classTag] then
            CLASS_LIST[#CLASS_LIST + 1] = classInfo
            CLASS_SPECS[classInfo.classTag] = allSpecs[classInfo.classTag]
        end
    end
end

local function SaveOrder(specID, order)
    if not specID then return end
    if not CDM.db.defensivesOrder then CDM.db.defensivesOrder = {} end
    CDM.db.defensivesOrder[specID] = {}
    for i, id in ipairs(order) do
        CDM.db.defensivesOrder[specID][i] = id
    end
end

local function CreateSpellsOverlay()
    local overlay = UI.CreateModalOverlay()
    local window = overlay.window

    local paddingX = 18
    local paddingY = 14
    local titleOffset = 28
    local windowWidth = 419
    local windowHeight = 524

    window:SetSize(windowWidth, windowHeight)

    local rowHeight = 29
    local contentWidth = windowWidth - paddingX * 2
    local startY = -(paddingY + titleOffset + 14)
    local selectedClassTag = playerClassTag
    local selectedSpecID = API:GetCurrentSpecID()

    local function IsViewingPlayerSpec()
        return selectedClassTag == playerClassTag and selectedSpecID == API:GetCurrentSpecID()
    end

    local listContainer = CreateFrame("Frame", nil, window)
    listContainer:SetSize(contentWidth, 400)
    listContainer:SetPoint("TOPLEFT", paddingX, startY)

    local specDropdown = UI.CreateDropdown(window)
    specDropdown:SetWidth(200)
    specDropdown:SetPoint("TOPRIGHT", window, "TOPRIGHT", -paddingX, -(paddingY + 16))
    specDropdown:SetDefaultText(L["Current Spec"])

    local addLabel = window:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    addLabel:SetText(L["Add Custom Spell"])
    addLabel:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
    addLabel:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", paddingX, paddingY + 36)

    local addRow = CreateFrame("Frame", nil, window)
    addRow:SetSize(400, 26)
    addRow:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", paddingX, paddingY + 8)

    local editBox = UI.CreateModernEditBox(addRow)
    editBox:SetSize(120, 22)
    editBox:SetPoint("LEFT", addRow, "LEFT", 6, 0)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    editBox:SetMaxLetters(7)

    UI.AttachPlaceholder(editBox, L["Spell ID"])

    local addBtn = UI.CreateActionButton(addRow, L["Add"], 70, 22, "primary")
    addBtn:SetSize(60, 22)
    addBtn:SetPoint("LEFT", editBox, "RIGHT", 6, 0)
    addBtn:SetText(L["Add"])

    local statusText = addRow:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    statusText:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
    statusText:SetPoint("RIGHT", window, "RIGHT", -paddingX, 0)
    statusText:SetJustifyH("LEFT")
    statusText:SetWordWrap(false)
    statusText:SetText("")

    local SetStatus = UI.CreateTimedStatus(statusText)

    local RebuildList

    local function SetSelection(classTag, specID)
        selectedClassTag = classTag
        selectedSpecID = specID
        if IsViewingPlayerSpec() then
            specDropdown:SetDefaultText(L["Current Spec"])
        else
            local specName = ""
            local className = ""
            local specs = CLASS_SPECS[classTag]
            if specs then
                for _, s in ipairs(specs) do
                    if s.specID == specID then
                        specName = s.specName
                        break
                    end
                end
            end
            for _, c in ipairs(CLASS_LIST) do
                if c.classTag == classTag then
                    className = c.className
                    break
                end
            end
            specDropdown:SetDefaultText(className .. " - " .. specName)
        end
        RebuildList()
    end

    specDropdown:SetupMenu(function(_, rootDescription)
        rootDescription:CreateRadio(L["Current Spec"], function()
            return IsViewingPlayerSpec()
        end, function()
            SetSelection(playerClassTag, API:GetCurrentSpecID())
        end)
        rootDescription:CreateDivider()
        for _, classInfo in ipairs(CLASS_LIST) do
            local color = RAID_CLASS_COLORS[classInfo.classTag]
            local coloredName = color and color:WrapTextInColorCode(classInfo.className) or classInfo.className
            local submenu = rootDescription:CreateButton(coloredName)
            local specs = CLASS_SPECS[classInfo.classTag]
            if specs then
                for _, specInfo in ipairs(specs) do
                    submenu:CreateRadio(specInfo.specName, function()
                        return selectedClassTag == classInfo.classTag and selectedSpecID == specInfo.specID
                    end, function()
                        SetSelection(classInfo.classTag, specInfo.specID)
                    end)
                end
            end
        end
    end)

    RebuildList = function()
        UI.ClearChildren(listContainer)

        local specID = selectedSpecID
        local isPlayerSpec = IsViewingPlayerSpec()
        local filterFn = isPlayerSpec and API.IsSpecSpell or nil
        local order = API.GetOrderedDefensiveSpells(specID, filterFn, selectedClassTag)
        local y = 0

        for idx, spellID in ipairs(order) do
            local isCustom = not BUILTIN_SET[spellID]

            local row = CreateFrame("Frame", nil, listContainer)
            row:SetSize(contentWidth, rowHeight)
            row:SetPoint("TOPLEFT", 0, -y)

            local arrowContainer = CreateFrame("Frame", nil, row)
            arrowContainer:SetSize(58, 29)
            arrowContainer:SetPoint("TOPLEFT", 4, 0)

            local btnUp = Shared.CreateArrowButton(arrowContainer, "up", 29)
            btnUp:SetPoint("LEFT", arrowContainer, "LEFT", 0, 0)
            if idx == 1 then btnUp:SetEnabled(false) end

            btnUp:SetScript("OnClick", function()
                order[idx], order[idx - 1] = order[idx - 1], order[idx]
                SaveOrder(specID, order)
                if isPlayerSpec and CDM.ReinitDefensiveIcons then API:ReinitDefensiveIcons() end
                RebuildList()
            end)

            local btnDown = Shared.CreateArrowButton(arrowContainer, "down", 29)
            btnDown:SetPoint("LEFT", btnUp, "RIGHT", 0, 0)
            if idx == #order then btnDown:SetEnabled(false) end

            btnDown:SetScript("OnClick", function()
                order[idx], order[idx + 1] = order[idx + 1], order[idx]
                SaveOrder(specID, order)
                if isPlayerSpec and CDM.ReinitDefensiveIcons then API:ReinitDefensiveIcons() end
                RebuildList()
            end)

            local iconAnchor
            if not isCustom then
                local specDisabled = CDM.db.defensivesDisabledSpells and CDM.db.defensivesDisabledSpells[specID]
                local isDisabled = specDisabled and specDisabled[spellID]
                local cb = UI.CreateModernCheckbox(
                    row, "", not isDisabled,
                    function(checked)
                        if not CDM.db.defensivesDisabledSpells then
                            CDM.db.defensivesDisabledSpells = {}
                        end
                        if not CDM.db.defensivesDisabledSpells[specID] then
                            CDM.db.defensivesDisabledSpells[specID] = {}
                        end
                        if checked then
                            CDM.db.defensivesDisabledSpells[specID][spellID] = nil
                        else
                            CDM.db.defensivesDisabledSpells[specID][spellID] = true
                        end
                        API:Refresh("TRACKERS")
                    end
                )
                cb:SetSize(OVERLAY_SWITCH_COLUMN_WIDTH, rowHeight)
                cb:SetPoint("LEFT", arrowContainer, "RIGHT", 4, 0)
                iconAnchor = cb
            else
                local spacer = CreateFrame("Frame", nil, row)
                spacer:SetSize(OVERLAY_SWITCH_COLUMN_WIDTH, rowHeight)
                spacer:SetPoint("LEFT", arrowContainer, "RIGHT", 4, 0)
                iconAnchor = spacer
            end

            local displayID = API.GetEffectiveSpellID(spellID)

            local iconTex = row:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(20, 20)
            iconTex:SetPoint("LEFT", iconAnchor, "RIGHT", OVERLAY_ICON_GAP, 0)
            local texture = C_Spell.GetSpellTexture(displayID)
            if texture then
                iconTex:SetTexture(texture)
                CDM_C.ApplyIconTexCoord(iconTex, CDM_C.GetEffectiveZoomAmount())
            end

            local nameText = row:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
            nameText:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetWordWrap(false)
            if nameText.SetMaxLines then nameText:SetMaxLines(1) end
            if nameText.SetNonSpaceWrap then nameText:SetNonSpaceWrap(false) end
            nameText:SetText(C_Spell.GetSpellName(displayID) or tostring(spellID))

            if isCustom then
                local removeBtn = CreateFrame("Button", nil, row)
                removeBtn:SetSize(16, 16)
                removeBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                nameText:SetPoint("RIGHT", removeBtn, "LEFT", -6, 0)
                Shared.ApplyRemoveButtonText(removeBtn)

                removeBtn:SetScript("OnClick", function()
                    API:RemoveDefensiveSpell(spellID, specID)
                    RebuildList()
                end)
            else
                nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            end

            y = y + rowHeight
        end
    end

    local function DoAddSpell()
        local text = editBox:GetText()
        local spellID = tonumber(text)
        if not spellID or spellID <= 0 then
            SetStatus("|cffff4444" .. L["Enter a valid spell ID"] .. "|r")
            return
        end

        local spellName = C_Spell.GetSpellName(spellID)
        if not spellName then
            SetStatus("|cffff4444" .. L["Unknown spell ID"] .. "|r")
            return
        end

        if IsViewingPlayerSpec() and not API.IsSpecSpell(spellID) then
            SetStatus("|cffff4444" .. L["Not available for spec"] .. "|r")
            return
        end

        local ok = API:AddDefensiveSpell(spellID, selectedSpecID)
        if ok then
            editBox:SetText("")
            SetStatus("|cff44ff44" .. string.format(L["Added: %s"], spellName) .. "|r")
            RebuildList()
        else
            SetStatus("|cffff4444" .. L["Already tracked"] .. "|r")
        end
    end

    addBtn:SetScript("OnClick", DoAddSpell)
    editBox:SetScript("OnEnterPressed", function(self)
        DoAddSpell()
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    overlay:HookScript("OnShow", function()
        selectedClassTag = playerClassTag
        selectedSpecID = API:GetCurrentSpecID()
        specDropdown:SetDefaultText(L["Current Spec"])
        RebuildList()
        SetStatus("")
    end)

    return overlay
end

local function CreateDefensivesTab(page, tabId)
    local scrollChild, scrollFrame = UI.CreateScrollableTab(page, "MidnightCDM_DefensivesScrollFrame", 700, 370)

    local sections = {}
    local function Relayout()
        UI.LayoutAccordionSections(sections, -35, 8, scrollFrame:GetScrollChild(), scrollChild)
    end
    local function AddSection(title, key, height, defaultOpen)
        local section, body = UI.CreateAccordionSection(scrollChild, title, 540, height, "defensives:" .. key, defaultOpen, Relayout)
        sections[#sections + 1] = section
        return section, body
    end

    local enabled = CDM.db.defensivesEnabled ~= false
    local setControlsEnabled
    page.controls.defensivesEnabled = UI.CreateModernCheckbox(
        scrollChild,
        L["Enable Defensives"],
        enabled,
        function(checked)
            CDM.db.defensivesEnabled = checked
            if setControlsEnabled then setControlsEnabled(checked) end
            API:Refresh("TRACKERS")
        end
    )
    page.controls.defensivesEnabled:SetPoint("TOPLEFT", 0, 0)

    local _, spellsBody = AddSection(L["Tracked Spells"], "tracked-spells", 42, true)

    local manageSpellsButton = UI.CreateActionButton(spellsBody, L["Manage Spells"], 140, 24)
    manageSpellsButton:SetSize(160, 22)
    manageSpellsButton:SetText(L["Manage Spells"])
    manageSpellsButton:SetPoint("TOPLEFT", 0, 0)

    local spellsOverlay = CreateSpellsOverlay()
    manageSpellsButton:SetScript("OnClick", function()
        spellsOverlay:Show()
    end)

    local _, iconSizeBody = AddSection(L["Icon Size"], "icon-size", 130, true)

    page.defensivesIconWidthSlider = UI.CreateModernSlider(
        iconSizeBody,
        L["Icon Width"],
        20, 100,
        CDM.db.defensivesIconWidth or 40,
        function(v)
            CDM.db.defensivesIconWidth = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.defensivesIconWidthSlider:SetPoint("TOPLEFT", 0, 0)

    page.defensivesIconHeightSlider = UI.CreateModernSlider(
        iconSizeBody,
        L["Icon Height"],
        20, 100,
        CDM.db.defensivesIconHeight or 36,
        function(v)
            CDM.db.defensivesIconHeight = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.defensivesIconHeightSlider:SetPoint("TOPLEFT", page.defensivesIconWidthSlider, "BOTTOMLEFT", 0, -10)

    local _, positionBody = AddSection(L["Position"], "position", 230, true)

    local lblAnchor = positionBody:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    lblAnchor:SetText(L["Anchor Position (relative to Player Frame)"])
    lblAnchor:SetPoint("TOPLEFT", 0, 0)

    local ddAnchor = UI.CreateDropdown(positionBody)
    ddAnchor:SetPoint("TOPLEFT", lblAnchor, "BOTTOMLEFT", 0, -10)
    ddAnchor:SetWidth(180)
    ddAnchor:SetDefaultText(CDM.db.defensivesAnchorPoint or "TOPLEFT")
    page.defensivesAnchorDropdown = ddAnchor

    UI.SetupPositionDropdown(
        ddAnchor,
        function() return CDM.db.defensivesAnchorPoint or "TOPLEFT" end,
        function(pos)
            CDM.db.defensivesAnchorPoint = pos
            ddAnchor:SetDefaultText(pos)
            API:Refresh("TRACKERS")
        end,
        {"TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT"}
    )

    page.defensivesOffsetXSlider = UI.CreateModernSlider(
        positionBody,
        L["X Offset"],
        -500, 500,
        CDM.db.defensivesOffsetX or 0,
        function(v)
            CDM.db.defensivesOffsetX = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.defensivesOffsetXSlider:SetPoint("TOPLEFT", ddAnchor, "BOTTOMLEFT", 0, -15)

    page.defensivesOffsetYSlider = UI.CreateModernSlider(
        positionBody,
        L["Y Offset"],
        -500, 500,
        CDM.db.defensivesOffsetY or 0,
        function(v)
            CDM.db.defensivesOffsetY = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.defensivesOffsetYSlider:SetPoint("TOPLEFT", page.defensivesOffsetXSlider, "BOTTOMLEFT", 0, -10)

    local _, cooldownBody = AddSection(L["Cooldown"], "cooldown", 70, true)

    page.defensivesCooldownFontSizeSlider = UI.CreateModernSlider(
        cooldownBody,
        L["Font Size"],
        8, 32,
        CDM.db.defensivesCooldownFontSize or 12,
        function(v)
            CDM.db.defensivesCooldownFontSize = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.defensivesCooldownFontSizeSlider:SetPoint("TOPLEFT", 0, 0)

    local _, stacksBody = AddSection(L["Stacks"], "stacks", 280, true)

    page.defensivesChargeFontSizeSlider = UI.CreateModernSlider(
        stacksBody,
        L["Font Size"],
        8, 32,
        CDM.db.defensivesChargeFontSize or 15,
        function(v)
            CDM.db.defensivesChargeFontSize = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.defensivesChargeFontSizeSlider:SetPoint("TOPLEFT", 0, 0)

    local lblChargePos = stacksBody:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    lblChargePos:SetText(L["Text Position"])
    lblChargePos:SetPoint("TOPLEFT", page.defensivesChargeFontSizeSlider, "BOTTOMLEFT", 0, -10)

    local ddChargePos = UI.CreateDropdown(stacksBody)
    ddChargePos:SetPoint("TOPLEFT", lblChargePos, "BOTTOMLEFT", 0, -10)
    ddChargePos:SetWidth(180)
    ddChargePos:SetDefaultText(CDM.db.defensivesChargePosition or "BOTTOMRIGHT")
    page.defensivesChargePosDropdown = ddChargePos

    UI.SetupPositionDropdown(
        ddChargePos,
        function() return CDM.db.defensivesChargePosition or "BOTTOMRIGHT" end,
        function(pos)
            CDM.db.defensivesChargePosition = pos
            ddChargePos:SetDefaultText(pos)
            API:Refresh("TRACKERS")
        end
    )

    page.defensivesChargeOffsetXSlider = UI.CreateModernSlider(
        stacksBody,
        L["Text X Offset"],
        -20, 20,
        CDM.db.defensivesChargeOffsetX or 0,
        function(v)
            CDM.db.defensivesChargeOffsetX = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.defensivesChargeOffsetXSlider:SetPoint("TOPLEFT", ddChargePos, "BOTTOMLEFT", 0, -15)

    page.defensivesChargeOffsetYSlider = UI.CreateModernSlider(
        stacksBody,
        L["Text Y Offset"],
        -20, 20,
        CDM.db.defensivesChargeOffsetY or 0,
        function(v)
            CDM.db.defensivesChargeOffsetY = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.defensivesChargeOffsetYSlider:SetPoint("TOPLEFT", page.defensivesChargeOffsetXSlider, "BOTTOMLEFT", 0, -10)

    setControlsEnabled = UI.SetupModuleToggle(scrollChild, page.controls.defensivesEnabled)
    setControlsEnabled(enabled)
    Relayout()
end

API:RegisterConfigTab("defensives", L["Defensives"], CreateDefensivesTab, 10.1)
