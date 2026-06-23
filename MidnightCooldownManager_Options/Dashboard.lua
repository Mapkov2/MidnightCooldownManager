local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end

local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI

local dashboardPage = nil
local dashboardWidgets = nil

local function CountEntries(tbl)
    if type(tbl) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local function CountList(tbl)
    if type(tbl) ~= "table" then return 0 end
    local count = 0
    for i = 1, #tbl do
        if tbl[i] ~= nil then
            count = count + 1
        end
    end
    if count > 0 then return count end
    return CountEntries(tbl)
end

local function SetText(widget, text)
    if widget and widget.SetText then
        widget:SetText(text or "")
    end
end

local function ColorText(fontString, color)
    if not (fontString and color) then return end
    fontString:SetTextColor(color.r, color.g, color.b, color.a or 1)
end

local function GetAddonMetadata(field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, value = pcall(C_AddOns.GetAddOnMetadata, "MidnightCooldownManager", field)
        if ok then return value end
    end
    if GetAddOnMetadata then
        local ok, value = pcall(GetAddOnMetadata, "MidnightCooldownManager", field)
        if ok then return value end
    end
    return nil
end

local function GetBuildText()
    local version, build, _, toc = GetBuildInfo()
    if version and build then
        return tostring(version) .. " / " .. tostring(build) .. " / " .. tostring(toc or "?")
    end
    return "unknown"
end

local function GetSpecInfo()
    if not (GetSpecialization and GetSpecializationInfo) then
        return nil, "Unknown"
    end
    local specIndex = GetSpecialization()
    if not specIndex then
        return nil, "Unknown"
    end
    local specID, specName = GetSpecializationInfo(specIndex)
    return specID, specName or "Unknown"
end

local function CountSpecGroups(db, key, specID)
    local allGroups = db and db[key]
    if type(allGroups) ~= "table" then return 0 end
    if specID and type(allGroups[specID]) == "table" then
        return CountList(allGroups[specID])
    end
    return CountEntries(allGroups)
end

local function OpenTab(tabId)
    if tabId and ns.ConfigSelectCategory then
        ns.ConfigSelectCategory(tabId)
    end
end

local function OpenNativeSettings()
    if API.ToggleCooldownViewerSettingsPanel then
        API:ToggleCooldownViewerSettingsPanel()
    end
end

local function OpenEditModeOverlay()
    if not ns.CreateEditModeOverlay then return end
    local overlay = ns._DashboardEditModeOverlay
    if not overlay then
        overlay = ns.CreateEditModeOverlay()
        ns._DashboardEditModeOverlay = overlay
    end
    overlay:Show()
end

local function RunSmokeDiagnostic()
    if CDM.RunCooldownSmokeDiagnostic then
        CDM:RunCooldownSmokeDiagnostic()
    elseif CDM.Print then
        CDM.Print("Smoke diagnostic is not available.")
    end
end

local function GetChangelogData()
    return CDM.Changelog or _G.MCDM_Changelog
end

local function BuildChangelogText()
    local data = GetChangelogData()
    if type(data) ~= "table" or type(data.entries) ~= "table" then
        return "No changelog data is loaded."
    end

    local lines = {}
    lines[#lines + 1] = "Midnight Simple Cooldown Changelog"
    if data.rangeLabel then
        lines[#lines + 1] = data.rangeLabel
    end
    lines[#lines + 1] = ""

    for _, entry in ipairs(data.entries) do
        lines[#lines + 1] = tostring(entry.version or "Unknown") .. (entry.date and (" - " .. tostring(entry.date)) or "")
        lines[#lines + 1] = string.rep("=", 36)
        if type(entry.sections) == "table" then
            for _, section in ipairs(entry.sections) do
                lines[#lines + 1] = ""
                lines[#lines + 1] = tostring(section.title or "Changes")
                if type(section.bullets) == "table" then
                    for _, bullet in ipairs(section.bullets) do
                        lines[#lines + 1] = "- " .. tostring(bullet)
                    end
                end
            end
        end
        lines[#lines + 1] = ""
    end

    return table.concat(lines, "\n")
end

local changelogOverlay
local function ShowChangelog()
    if not changelogOverlay then
        changelogOverlay = UI.CreateModalOverlay()
        local window = changelogOverlay.window
        window:SetSize(640, 500)

        local title = window:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font18")
        title:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -18)
        title:SetPoint("RIGHT", window, "RIGHT", -54, 0)
        title:SetJustifyH("LEFT")
        title:SetText("Changelog")
        ColorText(title, UI.Theme.colors.title)

        local subtitle = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        subtitle:SetPoint("RIGHT", window, "RIGHT", -18, 0)
        subtitle:SetJustifyH("LEFT")
        subtitle:SetText("Release notes for the current Midnight Simple Cooldown build.")
        UI.SetTextSubtle(subtitle)

        local scroll = CreateFrame("ScrollFrame", nil, window)
        scroll:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -72)
        scroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -34, 54)
        UI.StyleScrollFrame(scroll)

        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetJustifyH("LEFT")
        editBox:SetJustifyV("TOP")
        editBox:SetMaxLetters(200000)
        editBox:EnableMouse(true)
        editBox:SetWidth(570)
        if editBox.SetFont then editBox:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "") end
        if editBox.SetTextInsets then editBox:SetTextInsets(8, 8, 8, 8) end
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scroll:SetScrollChild(editBox)

        local selectButton = UI.CreateModernButton(window, "Select Text", 110, 24, "primary")
        selectButton:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 18, 18)
        selectButton:SetScript("OnClick", function()
            editBox:SetFocus()
            editBox:HighlightText()
        end)

        local closeButton = UI.CreateModernButton(window, "Close", 90, 24)
        closeButton:SetPoint("LEFT", selectButton, "RIGHT", 10, 0)
        closeButton:SetScript("OnClick", function()
            changelogOverlay:Hide()
        end)

        changelogOverlay.TextBox = editBox
    end

    local text = BuildChangelogText()
    changelogOverlay.TextBox:SetText(text)
    local lines = 1
    for _ in tostring(text):gmatch("\n") do lines = lines + 1 end
    changelogOverlay.TextBox:SetHeight(math.max(390, (lines * 14) + 24))
    changelogOverlay.TextBox:SetCursorPosition(0)
    changelogOverlay:Show()
end

local function CreatePanel(parent, width, height)
    local panel = UI.CreatePanel(parent, nil, UI.Theme.colors.card, UI.Theme.colors.cardBorder)
    if UI.ApplySurface then UI.ApplySurface(panel, "card") end
    panel:SetSize(width, height)
    return panel
end

local function CreateTitle(parent, text, x, y)
    local title = parent:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font18")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 16, y or -14)
    title:SetText(text or "")
    ColorText(title, UI.Theme.colors.title)
    return title
end

local function CreateSubtitle(parent, anchor, text)
    local subtitle = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    subtitle:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(text or "")
    UI.SetTextSubtle(subtitle)
    return subtitle
end

local function CreateStatusPill(parent, text, kind)
    local pill = UI.CreatePanel(parent, nil, UI.Theme.colors.pillBase, UI.Theme.colors.pillEdge)
    pill:SetSize(46, 18)

    local label = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", pill, "CENTER", 0, 0)
    label:SetText(text or "")
    pill.Label = label

    function pill:SetKind(nextKind, nextText)
        local colors = UI.Theme.colors
        local bg, border, txt
        if nextKind == "ok" then
            bg = { r = 0.026, g = 0.145, b = 0.074, a = 0.92 }
            border = { r = colors.success.r, g = colors.success.g, b = colors.success.b, a = 0.78 }
            txt = colors.success
        elseif nextKind == "warn" then
            bg = { r = 0.155, g = 0.105, b = 0.020, a = 0.92 }
            border = { r = colors.accent2.r, g = colors.accent2.g, b = colors.accent2.b, a = 0.78 }
            txt = colors.accent2
        elseif nextKind == "bad" then
            bg = { r = 0.145, g = 0.035, b = 0.046, a = 0.92 }
            border = { r = colors.danger.r, g = colors.danger.g, b = colors.danger.b, a = 0.78 }
            txt = colors.danger
        else
            bg = colors.pillBase
            border = colors.pillEdge
            txt = colors.dim
        end
        if UI.ApplyBackdrop then UI.ApplyBackdrop(self, bg, border) end
        self.Label:SetText(nextText or text or "")
        ColorText(self.Label, txt)
    end

    pill:SetKind(kind or "off", text)
    return pill
end

local function CreateHeaderMetric(parent, titleText, valueText)
    local card = CreatePanel(parent, 166, 58)

    local title = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -9)
    title:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    title:SetJustifyH("LEFT")
    title:SetText(titleText or "")
    UI.SetTextFaint(title)

    local value = card:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    value:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 12, 9)
    value:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    value:SetJustifyH("LEFT")
    value:SetText(valueText or "")
    UI.SetTextWhite(value)

    card.Title = title
    card.Value = value
    return card
end

local function CreateOverviewRow(parent, y, labelText, valueText)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    label:SetWidth(118)
    label:SetJustifyH("LEFT")
    label:SetText(labelText or "")
    UI.SetTextFaint(label)

    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("LEFT", label, "RIGHT", 10, 0)
    value:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    value:SetJustifyH("LEFT")
    value:SetText(valueText or "")
    UI.SetTextSubtle(value)
    return value
end

local function CreateChecklistRow(parent, y, labelText, descText, actionText, onClick)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    row:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
    row:SetHeight(42)

    local pill = CreateStatusPill(row, "OK", "ok")
    pill:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.Pill = pill

    local label = row:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    label:SetPoint("TOPLEFT", pill, "TOPRIGHT", 10, 1)
    label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -72, 1)
    label:SetJustifyH("LEFT")
    label:SetText(labelText or "")
    UI.SetTextWhite(label)

    local desc = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -1)
    desc:SetPoint("TOPRIGHT", row, "TOPRIGHT", -72, -18)
    desc:SetJustifyH("LEFT")
    desc:SetText(descText or "")
    UI.SetTextFaint(desc)

    local action = UI.CreateModernButton(row, actionText or "open", 62, 20)
    action:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    action:SetScript("OnClick", onClick or function() end)
    row.Action = action
    return row
end

local function CreateQuickAction(parent, text, tabId, x, y, role, onClick)
    local button = UI.CreateModernButton(parent, text, 154, 24, role)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetScript("OnClick", onClick or function() OpenTab(tabId) end)
    return button
end

local function GetDiagnostics()
    if type(CDM.GetCooldownDiagnostics) ~= "function" then return nil end
    local ok, diag = pcall(CDM.GetCooldownDiagnostics, CDM)
    if ok and type(diag) == "table" then
        return diag
    end
    return nil
end

local function CountActiveViewerFrames()
    if not (CDM.ForEachActiveFrame and CDM.CONST and CDM.CONST.ALL_VIEWER_NAMES) then
        return 0
    end
    local active = 0
    CDM:ForEachActiveFrame(CDM.CONST.ALL_VIEWER_NAMES, function()
        active = active + 1
    end)
    return active
end

local function SetChecklistState(row, ok, doneText, startText)
    if not row then return end
    if ok then
        row.Pill:SetKind("ok", "OK")
        row.Action:SetText(doneText or "done")
        if row.Action.SetActive then row.Action:SetActive(false) end
    else
        row.Pill:SetKind("warn", "!")
        row.Action:SetText(startText or "start")
        if row.Action.SetActive then row.Action:SetActive(true) end
    end
end

local function RefreshDashboard()
    if not dashboardWidgets then return end

    local widgets = dashboardWidgets
    local db = CDM.db or {}
    local specID, specName = GetSpecInfo()
    local profile = (API.GetActiveProfileName and API:GetActiveProfileName()) or "Default"
    local editMode = CDM.isEditModeActive and "On" or "Off"
    local inCombat = InCombatLockdown and InCombatLockdown()
    local diag = GetDiagnostics()
    local compat = diag and diag.compat or {}
    local index = diag and diag.index or {}
    local resources = diag and diag.resources or {}
    local dataReady = (CDM.IsCooldownViewerDataReady and CDM:IsCooldownViewerDataReady()) or (diag and diag.dataReady == true)
    local groupCooldowns = CountSpecGroups(db, "cooldownGroups", specID)
    local groupBuffs = CountSpecGroups(db, "buffGroups", specID)
    local groupBars = CountSpecGroups(db, "barGroups", specID)
    local groupTotal = groupCooldowns + groupBuffs + groupBars
    local activeFrames = CountActiveViewerFrames()
    local apiOk = compat.hasCooldownInfoAPI ~= false and compat.hasCategorySetAPI ~= false

    SetText(widgets.profile.Value, tostring(profile))
    SetText(widgets.status.Value, inCombat and "In Combat" or "Out of Combat")
    ColorText(widgets.status.Value, inCombat and UI.Theme.colors.danger or UI.Theme.colors.success)
    SetText(widgets.editMode.Value, editMode)
    SetText(widgets.spec.Value, tostring(specName or "Unknown"))

    SetText(widgets.overviewProfile, tostring(profile))
    SetText(widgets.overviewSpec, tostring(specName or "Unknown") .. (specID and ("  /  " .. tostring(specID)) or ""))
    SetText(widgets.overviewVersion, tostring(GetAddonMetadata("Version") or "unknown") .. "  /  TOC " .. tostring(GetAddonMetadata("Interface") or "unknown"))
    SetText(widgets.overviewBuild, GetBuildText())
    SetText(widgets.overviewData, (dataReady and "Ready" or "Waiting") ..
        "  /  cooldowns " .. tostring(index.totalCooldowns or 0) ..
        "  /  gen " .. tostring(index.compatGeneration or compat.generation or "?"))
    SetText(widgets.overviewViewers, tostring(activeFrames) .. " active frames")
    SetText(widgets.overviewGroups, "Cooldown " .. groupCooldowns .. "  /  Buff " .. groupBuffs .. "  /  Bars " .. groupBars)
    SetText(widgets.overviewResources, "Class " .. tostring(resources.classEnabled ~= false) ..
        "  /  Power " .. tostring(resources.powerBarEnabled ~= false) ..
        "  /  HP default off")

    if widgets.editButton then
        widgets.editButton:SetText("Edit Mode: " .. editMode)
        if widgets.editButton.SetActive then
            widgets.editButton:SetActive(CDM.isEditModeActive)
        end
    end

    SetChecklistState(widgets.checkProfile, profile ~= nil and profile ~= "", "done", "open")
    SetChecklistState(widgets.checkData, dataReady and apiOk, "done", "check")
    SetChecklistState(widgets.checkGroups, groupTotal > 0, "done", "start")
    SetChecklistState(widgets.checkResources, resources.initialized ~= false, "done", "open")
    SetChecklistState(widgets.checkImport, true, "ready", "open")
    if widgets.changelogVersion then
        local changelog = GetChangelogData()
        SetText(widgets.changelogVersion, "Current: " .. tostring((changelog and changelog.currentVersion) or GetAddonMetadata("Version") or "unknown"))
    end
end

function ns.RefreshDashboard()
    RefreshDashboard()
end

local function CreateDashboardTab(page)
    dashboardPage = page
    dashboardWidgets = {}

    local content = UI.CreateScrollableTab(page, "MidnightCDM_DashboardScrollFrame", 760, 820)
    local widgets = dashboardWidgets

    local hero = CreatePanel(content, 808, 88)
    hero:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

    local title = CreateTitle(hero, "Dashboard", 16, -14)
    CreateSubtitle(hero, title, "Review Midnight Simple Cooldown setup, check runtime status, and jump into the main tools.")

    local blizzButton = UI.CreateModernButton(hero, "Blizzard Settings", 148, 24)
    blizzButton:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -166, -24)
    blizzButton:SetScript("OnClick", OpenNativeSettings)

    widgets.editButton = UI.CreateModernButton(hero, "Edit Mode: Off", 140, 24, "primary")
    widgets.editButton:SetPoint("LEFT", blizzButton, "RIGHT", 10, 0)
    widgets.editButton:SetScript("OnClick", OpenEditModeOverlay)

    widgets.profile = CreateHeaderMetric(content, "Profile", "")
    widgets.profile:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 0, -12)
    widgets.status = CreateHeaderMetric(content, "Status", "")
    widgets.status:SetPoint("LEFT", widgets.profile, "RIGHT", 8, 0)
    widgets.editMode = CreateHeaderMetric(content, "Edit Mode", "")
    widgets.editMode:SetPoint("LEFT", widgets.status, "RIGHT", 8, 0)
    widgets.spec = CreateHeaderMetric(content, "Spec", "")
    widgets.spec:SetPoint("LEFT", widgets.editMode, "RIGHT", 8, 0)

    local overview = CreatePanel(content, 526, 282)
    overview:SetPoint("TOPLEFT", widgets.profile, "BOTTOMLEFT", 0, -14)

    local overviewTitle = CreateTitle(overview, "MSC Overview", 16, -13)
    CreateSubtitle(overview, overviewTitle, "Current profile, viewer data, custom groups, and resource runtime.")

    widgets.overviewProfile = CreateOverviewRow(overview, -70, "Profile", "")
    widgets.overviewSpec = CreateOverviewRow(overview, -96, "Spec", "")
    widgets.overviewVersion = CreateOverviewRow(overview, -122, "Addon", "")
    widgets.overviewBuild = CreateOverviewRow(overview, -148, "Client", "")
    widgets.overviewData = CreateOverviewRow(overview, -174, "CDM data", "")
    widgets.overviewViewers = CreateOverviewRow(overview, -200, "Viewers", "")
    widgets.overviewGroups = CreateOverviewRow(overview, -226, "Groups", "")
    widgets.overviewResources = CreateOverviewRow(overview, -252, "Resources", "")

    local checklist = CreatePanel(content, 274, 282)
    checklist:SetPoint("TOPLEFT", overview, "TOPRIGHT", 8, 0)

    local checklistTitle = CreateTitle(checklist, "Setup Checklist", 16, -13)
    CreateSubtitle(checklist, checklistTitle, "Useful for first-run orientation.")

    widgets.checkProfile = CreateChecklistRow(checklist, -60, "Profile ready", "Active profile is loaded.", "done", function() OpenTab("profiles") end)
    widgets.checkData = CreateChecklistRow(checklist, -100, "Cooldown data", "Viewer cache and 12.1 data path.", "check", RunSmokeDiagnostic)
    widgets.checkGroups = CreateChecklistRow(checklist, -140, "Custom groups", "Cooldown, buff and bar setup.", "start", function() OpenTab("layout") end)
    widgets.checkResources = CreateChecklistRow(checklist, -180, "Resources", "Class, power and HP bars.", "open", function() OpenTab("resources") end)
    widgets.checkImport = CreateChecklistRow(checklist, -220, "Ayije import", "Legacy profile import is available.", "open", function() OpenTab("importexport") end)

    local quick = CreatePanel(content, 526, 132)
    quick:SetPoint("TOPLEFT", overview, "BOTTOMLEFT", 0, -14)

    local quickTitle = quick:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    quickTitle:SetPoint("TOPLEFT", quick, "TOPLEFT", 16, -12)
    quickTitle:SetText("Quick Actions")
    UI.SetTextWhite(quickTitle)

    CreateQuickAction(quick, "Cooldown Groups", "layout", 16, -42, "primary")
    CreateQuickAction(quick, "Buff Groups", "buffgroups", 184, -42)
    CreateQuickAction(quick, "Bars", "bars", 352, -42)
    CreateQuickAction(quick, "Class Resources", "resources", 16, -76)
    CreateQuickAction(quick, "Borders & Look", "border", 184, -76)
    CreateQuickAction(quick, "Import / Export", "importexport", 352, -76)

    local recovery = CreatePanel(content, 274, 132)
    recovery:SetPoint("TOPLEFT", checklist, "BOTTOMLEFT", 0, -14)

    local recoveryTitle = recovery:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    recoveryTitle:SetPoint("TOPLEFT", recovery, "TOPLEFT", 16, -12)
    recoveryTitle:SetText("Maintenance")
    UI.SetTextWhite(recoveryTitle)

    local recoveryText = recovery:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    recoveryText:SetPoint("TOPLEFT", recoveryTitle, "BOTTOMLEFT", 0, -8)
    recoveryText:SetPoint("RIGHT", recovery, "RIGHT", -16, 0)
    recoveryText:SetJustifyH("LEFT")
    recoveryText:SetText("Open profile tools, run the smoke diagnostic, or jump to Blizzard's native CDM page.")
    UI.SetTextSubtle(recoveryText)

    CreateQuickAction(recovery, "Profiles", "profiles", 16, -82)
    CreateQuickAction(recovery, "Smoke", nil, 184, -82, nil, RunSmokeDiagnostic):SetWidth(74)

    local changelog = CreatePanel(content, 808, 126)
    changelog:SetPoint("TOPLEFT", quick, "BOTTOMLEFT", 0, -14)

    local changelogTitle = changelog:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    changelogTitle:SetPoint("TOPLEFT", changelog, "TOPLEFT", 16, -12)
    changelogTitle:SetText("Changelog")
    UI.SetTextWhite(changelogTitle)

    local changelogText = changelog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    changelogText:SetPoint("TOPLEFT", changelogTitle, "BOTTOMLEFT", 0, -8)
    changelogText:SetPoint("RIGHT", changelog, "RIGHT", -172, 0)
    changelogText:SetJustifyH("LEFT")
    changelogText:SetText("Review the current release notes before publishing or testing a new build.")
    UI.SetTextSubtle(changelogText)

    widgets.changelogVersion = changelog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    widgets.changelogVersion:SetPoint("TOPLEFT", changelogText, "BOTTOMLEFT", 0, -10)
    widgets.changelogVersion:SetPoint("RIGHT", changelog, "RIGHT", -172, 0)
    widgets.changelogVersion:SetJustifyH("LEFT")
    UI.SetTextFaint(widgets.changelogVersion)

    local changelogButton = UI.CreateModernButton(changelog, "View Changelog", 136, 24, "primary")
    changelogButton:SetPoint("RIGHT", changelog, "RIGHT", -16, 0)
    changelogButton:SetScript("OnClick", ShowChangelog)

    page.Refresh = RefreshDashboard
    page:SetScript("OnShow", RefreshDashboard)
    RefreshDashboard()
end

API:RegisterConfigTab("dashboard", "Dashboard", CreateDashboardTab, 0)
