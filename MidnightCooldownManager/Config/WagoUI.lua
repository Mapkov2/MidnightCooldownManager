local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]
local ProfileIO = CDM and CDM.ProfileIO

local API = {}
_G["MidnightCooldownManager_API"] = API

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

function API:ExportProfile(profileKey)
    if not MidnightCooldownManagerDB or not MidnightCooldownManagerDB.profiles then return nil end
    local profile = MidnightCooldownManagerDB.profiles[profileKey]
    if not profile then return nil end
    if not ProfileIO or not ProfileIO.ExportProfileEnvelope then return nil end
    local exportProfile = CDM.PrepareProfileDataForExport and CDM:PrepareProfileDataForExport(profile) or profile
    if not exportProfile then return nil end
    return ProfileIO:ExportProfileEnvelope(exportProfile, profileKey)
end

function API:DecodeProfileString(profileString)
    if not ProfileIO or not ProfileIO.DecodeProfileString then return nil, "invalid_profile_data" end
    return ProfileIO:DecodeProfileString(profileString)
end

local function ReportWagoMutationError(prefix, errCode)
    local handler = geterrorhandler and geterrorhandler()
    if handler then
        handler(string.format("%s: %s", tostring(prefix), tostring(errCode)))
    end
end

function API:ImportProfile(profileString, profileKey)
    if InCombatLockdown() then
        ReportWagoMutationError("wago import blocked", "combat_blocked")
        return
    end

    if not ProfileIO or not ProfileIO.DecodePayload then
        ReportWagoMutationError("wago import decode failed", "invalid_profile_data")
        return
    end

    local payload, decodeErr = ProfileIO:DecodePayload(profileString)
    if not payload then
        ReportWagoMutationError("wago import decode failed", decodeErr or "invalid_profile_data")
        return
    end

    if not ProfileIO.BuildImportProfile then
        ReportWagoMutationError("wago import decode failed", "invalid_profile_data")
        return
    end

    local prepared, buildErr = ProfileIO:BuildImportProfile(
        payload,
        AddonName,
        CDM.defaults,
        nil,
        METADATA_KEYS,
        GROUP_MIGRATION_KEYS,
        MidnightCooldownManagerDB and MidnightCooldownManagerDB.profiles,
        COMPATIBLE_SOURCE_ADDONS
    )
    if not prepared then
        ReportWagoMutationError("wago import failed", buildErr and buildErr.code or "invalid_profile_data")
        return
    end

    local targetProfile = (type(profileKey) == "string" and profileKey ~= "" and profileKey) or prepared.profileName
    local ok, importErr = CDM:ImportProfileData(targetProfile, prepared.profileData)
    if not ok then
        ReportWagoMutationError("wago import failed", importErr or "apply_failed")
        return
    end

    local specID = CDM:GetCurrentSpecID()
    if specID then
        if CDM.MarkSpecDataDirty then CDM:MarkSpecDataDirty() end
    end
end

function API:SetProfile(profileKey)
    local ok, errCode = CDM:SetProfile(profileKey)
    if not ok then
        ReportWagoMutationError("wago set profile failed", errCode or "apply_failed")
    end
end

function API:GetProfileKeys()
    local keys = {}
    if MidnightCooldownManagerDB and MidnightCooldownManagerDB.profiles then
        for name in pairs(MidnightCooldownManagerDB.profiles) do
            keys[name] = true
        end
    end
    return keys
end

function API:GetCurrentProfileKey()
    return CDM:GetActiveProfileName() or "Default"
end

function API:OpenConfig()
    if InCombatLockdown() then return end
    if CDM and CDM.RequestConfigOpen then
        CDM:RequestConfigOpen("wago", nil)
    end
end

function API:CloseConfig()
    local frame = _G["MidnightCooldownManagerConfigFrame"]
    if frame and frame:IsShown() then
        frame:Hide()
    end
end
