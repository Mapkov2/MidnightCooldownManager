local AddonName = "MidnightCooldownManager"
local Runtime = _G[AddonName]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L
local ProfileIO = CDM.ProfileIO

local ConfigKeys = ns.ConfigKeys or {}
local exportCategories = ConfigKeys.categories or {}
local exportCategoryOrder = ConfigKeys.order or {}
local METADATA_KEYS = {
    version = true,
    addon = true,
    timestamp = true,
    name = true,
    profileName = true,
    profile_export_version = true,
    toc_version = true,
    addon_version = true,
    segments = true,
}
local IMPORT_STATUS_SUCCESS_DURATION = 3

local GROUP_MIGRATION_KEYS = {
    "sizeBuffSecondary", "sizeBuffTertiary",
    "buffSecondaryOffsetX", "buffSecondaryOffsetY",
    "buffTertiaryOffsetX", "buffTertiaryOffsetY",
    "buffSecondaryHorizontal", "buffTertiaryHorizontal",
    "countPositionSec", "countOffsetXSec", "countOffsetYSec",
    "countPositionTert", "countOffsetXTert", "countOffsetYTert",
}
local COMPATIBLE_SOURCE_ADDONS = {
    Ayije_CDM = true,
}
local importExportLastStatus = nil
local importExportStatusTimer = nil
local activeStatusFontString = nil

local function CancelImportStatusTimer()
    if importExportStatusTimer then
        importExportStatusTimer:Cancel()
        importExportStatusTimer = nil
    end
end

ns.CancelImportStatusTimer = CancelImportStatusTimer

local function ClearImportStatus(fontString)
    CancelImportStatusTimer()
    importExportLastStatus = nil
    if fontString then
        fontString:SetText("")
        UI.SetTextMuted(fontString)
    end
end

local function ApplyImportStatus(fontString)
    local status = importExportLastStatus
    CancelImportStatusTimer()
    if not fontString then
        return
    end

    if not status or not status.message then
        fontString:SetText("")
        UI.SetTextMuted(fontString)
        return
    end

    if status.expiresAt and status.expiresAt <= GetTime() then
        ClearImportStatus(fontString)
        return
    end

    fontString:SetText(status.message)
    if status.success then
        UI.SetTextSuccess(fontString)
    else
        UI.SetTextError(fontString)
    end

    if status.expiresAt then
        importExportStatusTimer = C_Timer.NewTimer(math.max(0, status.expiresAt - GetTime()), function()
            importExportStatusTimer = nil
            importExportLastStatus = nil
            if fontString then
                fontString:SetText("")
                UI.SetTextMuted(fontString)
            end
        end)
    end
end

local function SetImportStatus(fontString, success, message)
    importExportLastStatus = {
        success = success,
        message = message,
        expiresAt = success and (GetTime() + IMPORT_STATUS_SUCCESS_DURATION) or nil,
    }
    ApplyImportStatus(activeStatusFontString or fontString)
end

local function MapImportErrorCode(errCode)
    if errCode == "invalid_base64" then
        return L["Invalid Base64 encoding"]
    end
    if errCode == "decompression_failed" then
        return L["Decompression failed"]
    end
    if errCode == "combat_blocked" then
        return L["Cannot open config while in combat"]
    end
    if errCode == "invalid_profile_version" then
        return L["Invalid profile version"]
    end
    if errCode == "missing_profile_metadata" then
        return L["Missing profile metadata"]
    end
    if errCode == "wrong_addon" then
        return L["Profile is for a different addon"]
    end
    if errCode == "empty" then
        return L["No import string provided"]
    end
    if errCode == "apply_failed" then
        return L["Failed to import profile"]
    end
    return L["Invalid profile data"]
end

local function GetAyijeProfileNames()
    local names = {}
    local ayijeDB = _G.Ayije_CDMDB
    if type(ayijeDB) ~= "table" or type(ayijeDB.profiles) ~= "table" then
        return names
    end
    for name, profile in pairs(ayijeDB.profiles) do
        if type(name) == "string" and name ~= "" and type(profile) == "table" then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    return names
end

local function FormatImportSuccessMessage(prepared)
    local msg
    if prepared.compatibleSource and prepared.sourceAddon == "Ayije_CDM" then
        msg = string.format("Imported %d Ayije-compatible settings as '%s'", prepared.importedCount, prepared.profileName)
    else
        msg = string.format(L["Imported %d settings as '%s'"], prepared.importedCount, prepared.profileName)
    end
    if prepared.skippedCount and prepared.skippedCount > 0 then
        msg = msg .. string.format(" (%d skipped)", prepared.skippedCount)
    end
    if prepared.compatibleSource and prepared.unsupportedCount and prepared.unsupportedCount > 0 then
        msg = msg .. string.format(" (%d unsupported Ayije settings ignored)", prepared.unsupportedCount)
    end
    return msg
end

local function ApplyPreparedImport(prepared)
    local ok, importErr = API:ImportProfileData(prepared.profileName, prepared.profileData)
    if not ok then
        local mapped = MapImportErrorCode(importErr)
        return false, mapped or importErr or L["Failed to import profile"]
    end

    if API.MarkSpecDataDirty then
        API:MarkSpecDataDirty()
    end

    return true, FormatImportSuccessMessage(prepared)
end

local function GetCategoryOrder()
    if exportCategoryOrder and #exportCategoryOrder > 0 then
        return exportCategoryOrder
    end

    local ordered = {}
    for categoryId in pairs(exportCategories) do
        ordered[#ordered + 1] = categoryId
    end
    table.sort(ordered)
    return ordered
end

function API:ExportProfile(categories)
    if not ProfileIO or not ProfileIO.ExportSegmentedProfile then
        return nil
    end

    local profileData = CDM.PrepareProfileDataForExport and CDM:PrepareProfileDataForExport(CDM.db) or CDM.db
    if not profileData then
        return nil
    end

    local exportString, errCode = ProfileIO:ExportSegmentedProfile(
        profileData,
        categories,
        exportCategories,
        CDM.activeProfileName
    )

    if exportString then
        return exportString
    end

    if errCode == "no_categories_selected" then
        print("|cffff0000[CDM Export]|r " .. L["Select at least one category to export."])
    end
    return nil
end

function API:ImportProfile(encodedString)
    if not encodedString or encodedString == "" then
        return false, L["No import string provided"]
    end

    if not ProfileIO then
        return false, L["Invalid profile data"]
    end

    local payload, decodeErr = ProfileIO:DecodePayload(encodedString)
    if not payload then
        return false, MapImportErrorCode(decodeErr)
    end

    local prepared, buildErr = ProfileIO:BuildImportProfile(
        payload,
        AddonName,
        CDM.defaults,
        exportCategories,
        METADATA_KEYS,
        GROUP_MIGRATION_KEYS,
        MidnightCooldownManagerDB and MidnightCooldownManagerDB.profiles,
        COMPATIBLE_SOURCE_ADDONS
    )
    if not prepared then
        local code = buildErr and buildErr.code
        if code == "missing_profile_metadata" then
            return false, MapImportErrorCode(code)
        end
        if code == "wrong_addon" then
            return false, string.format(L["Profile is for a different addon: %s"], tostring(buildErr.addon))
        end
        return false, MapImportErrorCode(code)
    end

    return ApplyPreparedImport(prepared)
end

function API:ImportAyijeProfile(profileName)
    if not profileName or profileName == "" then
        return false, "Select an Ayije profile"
    end
    if not ProfileIO or not ProfileIO.BuildImportProfile then
        return false, L["Invalid profile data"]
    end

    local ayijeDB = _G.Ayije_CDMDB
    if type(ayijeDB) ~= "table" or type(ayijeDB.profiles) ~= "table" then
        return false, "Ayije_CDMDB is not loaded. Enable Ayije CDM once and reload."
    end

    local profileData = ayijeDB.profiles[profileName]
    if type(profileData) ~= "table" then
        return false, "Ayije profile not found"
    end

    local payload = {
        profile_export_version = 1,
        profileName = profileName,
        name = profileName,
        version = 1,
        addon = "Ayije_CDM",
        data = profileData,
    }

    local prepared, buildErr = ProfileIO:BuildImportProfile(
        payload,
        AddonName,
        CDM.defaults,
        exportCategories,
        METADATA_KEYS,
        GROUP_MIGRATION_KEYS,
        MidnightCooldownManagerDB and MidnightCooldownManagerDB.profiles,
        COMPATIBLE_SOURCE_ADDONS
    )
    if not prepared then
        local code = buildErr and buildErr.code
        if code == "wrong_addon" then
            return false, string.format(L["Profile is for a different addon: %s"], tostring(buildErr.addon))
        end
        return false, MapImportErrorCode(code)
    end

    return ApplyPreparedImport(prepared)
end

local function CreateImportExportTab(page, tabId)
    local content, scrollFrame = UI.CreateScrollableTab(page, "MidnightCDM_ImportExportScrollFrame", 720, 760)
    local scrollFrameChild = scrollFrame and scrollFrame.GetScrollChild and scrollFrame:GetScrollChild()
    page = content

    local exportHeader = UI.CreateHeader(page, L["Export Profile"])
    exportHeader:SetPoint("TOPLEFT", 0, 0)

    local exportDesc = page:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    exportDesc:SetPoint("TOPLEFT", exportHeader, "BOTTOMLEFT", 0, -15)
    exportDesc:SetText(L["Select categories to include, then click Export."])
    UI.SetTextMuted(exportDesc)

    local checkboxes = {}
    local sortedCategories = GetCategoryOrder()
    local categoryCount = 0
    local columnWidth = 155
    local labelWidth = 115
    local rowHeight = 36

    for i, categoryId in ipairs(sortedCategories) do
        local categoryDef = exportCategories[categoryId]
        if categoryDef then
            categoryCount = categoryCount + 1
            local checkbox = UI.CreateModernCheckbox(
                page,
                categoryDef.label,
                true,
                nil
            )

            local col = (categoryCount - 1) % 3
            local row = math.floor((categoryCount - 1) / 3)
            checkbox:SetPoint("TOPLEFT", exportDesc, "BOTTOMLEFT", col * columnWidth, -12 - (row * rowHeight))
            checkbox:SetSize(columnWidth - 10, rowHeight)
            if checkbox.label then
                checkbox.label:SetWidth(labelWidth)
                checkbox.label:SetJustifyH("LEFT")
                checkbox.label:SetWordWrap(true)
            end

            checkboxes[categoryId] = checkbox
        end
    end

    local exportBtn = UI.CreateActionButton(page, L["Export"], 120, 24, "primary")
    exportBtn:SetSize(120, 26)
    local rowCount = math.max(1, math.ceil(categoryCount / 3))
    local exportBtnYOffset = -12 - (rowCount * rowHeight) - 8
    exportBtn:SetPoint("TOPLEFT", exportDesc, "BOTTOMLEFT", 0, exportBtnYOffset)
    exportBtn:SetText(L["Export"])

    local exportBoxLabel = page:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    exportBoxLabel:SetPoint("TOPLEFT", exportBtn, "BOTTOMLEFT", 0, -16)
    exportBoxLabel:SetText(L["Export String (Ctrl+C to copy):"])
    UI.SetTextMuted(exportBoxLabel)

    local exportBoxFrame, exportEditBox = UI.CreateScrollableEditBox(page, 420, 80, 380)
    exportBoxFrame:SetPoint("TOPLEFT", exportBoxLabel, "BOTTOMLEFT", 0, -4)

    exportBtn:SetScript("OnClick", function()
        local selectedCategories = {}
        for categoryId, checkbox in pairs(checkboxes) do
            if checkbox:GetChecked() then
                selectedCategories[categoryId] = true
            end
        end

        local exportString = API:ExportProfile(selectedCategories)
        if exportString then
            exportEditBox:SetText(exportString)
            exportEditBox:HighlightText()
            exportEditBox:SetFocus()
            CDM.PrintSuccess(L["Profile exported! Copy the string above."])
        else
            exportEditBox:SetText("")
            CDM.PrintError(L["Export failed."])
        end
    end)

    local importHeader = UI.CreateHeader(page, L["Import Profile"], exportBoxFrame, -15)

    local importDesc = page:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    importDesc:SetPoint("TOPLEFT", importHeader, "BOTTOMLEFT", 0, -15)
    importDesc:SetText("Paste an MCDM or Ayije CDM export string below and click Import.")
    UI.SetTextMuted(importDesc)

    local importBoxFrame, importEditBox = UI.CreateScrollableEditBox(page, 420, 80, 380)
    importBoxFrame:SetPoint("TOPLEFT", importDesc, "BOTTOMLEFT", 0, -8)

    local importBtn = UI.CreateActionButton(page, L["Import"], 120, 24, "primary")
    importBtn:SetSize(120, 26)
    importBtn:SetPoint("TOPLEFT", importBoxFrame, "BOTTOMLEFT", 0, -6)
    importBtn:SetText(L["Import"])

    local importStatus = page:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    importStatus:SetPoint("LEFT", importBtn, "RIGHT", 12, 0)
    importStatus:SetText("")
    UI.SetTextMuted(importStatus)
    activeStatusFontString = importStatus
    ApplyImportStatus(importStatus)

    importBtn:SetScript("OnClick", function()
        local importString = importEditBox:GetText()
        local success, message = API:ImportProfile(importString)
        SetImportStatus(importStatus, success, message)
    end)

    local clearBtn = UI.CreateActionButton(page, L["Clear"], 100, 24)
    clearBtn:SetSize(80, 26)
    clearBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)
    clearBtn:SetText(L["Clear"])
    clearBtn:SetScript("OnClick", function()
        importEditBox:SetText("")
        ClearImportStatus(importStatus)
    end)

    importStatus:ClearAllPoints()
    importStatus:SetPoint("LEFT", clearBtn, "RIGHT", 12, 0)

    local ayijeHeader = UI.CreateHeader(page, "Ayije Saved Profiles", importBtn, -24)

    local ayijeDesc = page:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    ayijeDesc:SetPoint("TOPLEFT", ayijeHeader, "BOTTOMLEFT", 0, -12)
    ayijeDesc:SetText("Import a loaded Ayije_CDMDB profile without pasting an export string.")
    UI.SetTextMuted(ayijeDesc)

    local ayijeDropdown = UI.CreateDropdown(page, 220, "Select Ayije profile...")
    ayijeDropdown:SetPoint("TOPLEFT", ayijeDesc, "BOTTOMLEFT", 0, -8)

    local ayijeImportBtn
    local selectedAyijeProfile = nil

    local function RefreshAyijeDropdown()
        local names = GetAyijeProfileNames()
        local selectedExists = false
        for _, name in ipairs(names) do
            if name == selectedAyijeProfile then
                selectedExists = true
                break
            end
        end
        if not selectedExists then
            selectedAyijeProfile = nil
        end

        ayijeDropdown:SetDefaultText(selectedAyijeProfile or (#names > 0 and "Select Ayije profile..." or "No loaded Ayije profiles"))
        ayijeDropdown:SetupMenu(function(_, rootDescription)
            if #names == 0 then
                rootDescription:CreateButton("No loaded Ayije profiles", function() end)
                return
            end
            for _, name in ipairs(names) do
                rootDescription:CreateRadio(name, function()
                    return selectedAyijeProfile == name
                end, function()
                    selectedAyijeProfile = name
                    ayijeDropdown:SetDefaultText(name)
                end)
            end
        end)

        if ayijeImportBtn then
            ayijeImportBtn:SetEnabled(#names > 0)
        end
    end

    ayijeImportBtn = UI.CreateActionButton(page, "Import Ayije", 120, 24, "primary")
    ayijeImportBtn:SetSize(120, 26)
    ayijeImportBtn:SetPoint("LEFT", ayijeDropdown, "RIGHT", 8, 0)
    ayijeImportBtn:SetScript("OnClick", function()
        local success, message = API:ImportAyijeProfile(selectedAyijeProfile)
        SetImportStatus(importStatus, success, message)
        if success then
            RefreshAyijeDropdown()
        end
    end)

    RefreshAyijeDropdown()

    if UI.FinalizeScroll and scrollFrameChild then
        UI.FinalizeScroll(scrollFrameChild, page, -640)
    end
end

API:RegisterConfigTab("importexport", L["Import/Export"], CreateImportExportTab, 12)
