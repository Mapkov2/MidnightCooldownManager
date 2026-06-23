local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]

CDM.ProfileIO = CDM.ProfileIO or {}
local ProfileIO = CDM.ProfileIO

local WIRE_PREFIX = "!MCDM:"
local LEGACY_WIRE_PREFIXES = {
    "!ACDM:",
}
local COMPATIBLE_SOURCE_ADDONS = {
    Ayije_CDM = true,
}

local function CopyValue(value)
    if type(value) == "table" then
        return CDM:DeepCopy(value)
    end
    return value
end

local function NormalizeWireString(profileString)
    if type(profileString) ~= "string" then return nil end
    if profileString == "" then return nil end

    local normalized = profileString:gsub("[%s%z]", "")
    local prefixes = LEGACY_WIRE_PREFIXES
    local _, prefixEnd = normalized:find(WIRE_PREFIX, 1, true)
    if not prefixEnd then
        for i = 1, #prefixes do
            _, prefixEnd = normalized:find(prefixes[i], 1, true)
            if prefixEnd then break end
        end
    end
    if prefixEnd then
        normalized = normalized:sub(prefixEnd + 1)
    end
    if normalized == "" then
        return nil
    end
    return normalized
end

function ProfileIO:EncodePayload(payload)
    local cbor = C_EncodingUtil.SerializeCBOR(payload)
    if not cbor then return nil end

    local compressed = C_EncodingUtil.CompressString(cbor)
    if not compressed then return nil end

    local base64 = C_EncodingUtil.EncodeBase64(compressed)
    if not base64 then return nil end

    return WIRE_PREFIX .. base64
end

function ProfileIO:DecodePayload(profileString)
    local normalized = NormalizeWireString(profileString)
    if not normalized then
        return nil, "empty"
    end

    local compressed = C_EncodingUtil.DecodeBase64(normalized)
    if not compressed then
        return nil, "invalid_base64"
    end

    local decompressed = C_EncodingUtil.DecompressString(compressed)
    if not decompressed then
        return nil, "decompression_failed"
    end

    local payload = C_EncodingUtil.DeserializeCBOR(decompressed)
    if type(payload) ~= "table" then
        return nil, "invalid_profile_data"
    end

    return payload
end

function ProfileIO:DecodeProfileString(profileString)
    local payload, errCode = self:DecodePayload(profileString)
    if not payload then
        return nil, errCode
    end
    local data
    if type(payload) == "table" and type(payload.data) == "table" and payload.profile_export_version then
        data = payload.data
    else
        data = payload
    end
    if type(data) ~= "table" then
        return nil, "invalid_profile_data"
    end
    return data
end

function ProfileIO:ExportProfileEnvelope(profileData, profileName)
    if type(profileData) ~= "table" then return nil end
    local now = time()
    local payload = {
        profile_export_version = 1,
        name = profileName,
        profileName = profileName,
        data = CDM:DeepCopy(profileData),
        version = 1,
        addon = AddonName,
        timestamp = now,
    }
    return self:EncodePayload(payload)
end

function ProfileIO:ExportSegmentedProfile(profileData, selectedCategories, categoryDefs, profileName)
    if type(profileData) ~= "table" then return nil end

    local keySet = {}
    if type(categoryDefs) == "table" then
        for categoryId, categoryDef in pairs(categoryDefs) do
            if (not selectedCategories) or selectedCategories[categoryId] then
                local keys = categoryDef and categoryDef.keys
                if type(keys) == "table" then
                    for _, key in ipairs(keys) do
                        keySet[key] = true
                    end
                end
            end
        end
    end
    if not next(keySet) then
        return nil, "no_categories_selected"
    end

    local filtered = {}
    for key in pairs(keySet) do
        local value = profileData[key]
        if value ~= nil then
            filtered[key] = CopyValue(value)
        end
    end

    local segments = {}
    if type(categoryDefs) == "table" then
        for categoryId in pairs(categoryDefs) do
            if (not selectedCategories) or selectedCategories[categoryId] then
                segments[#segments + 1] = categoryId
            end
        end
        table.sort(segments)
    end

    local now = time()
    local payload = {
        profile_export_version = 1,
        profileName = profileName,
        toc_version = select(4, GetBuildInfo()),
        addon_version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(AddonName, "Version") or nil,
        segments = segments,
        data = filtered,
        addon = AddonName,
        timestamp = now,
    }
    return self:EncodePayload(payload)
end

local function IsValidImportedType(defaults, key, value)
    local defaultValue = defaults and defaults[key]
    if defaultValue == nil then
        return true, nil
    end
    return type(defaultValue) == type(value), type(defaultValue)
end

local function ResolveImportedProfileName(baseName, existingProfiles)
    local profileName = (baseName and baseName ~= "") and baseName or "Imported"
    if not existingProfiles or not existingProfiles[profileName] then
        return profileName
    end
    local rootName = profileName:match("^(.-)%s*%(%d+%)$") or profileName
    local suffix = 0
    profileName = rootName
    while existingProfiles[profileName] do
        suffix = suffix + 1
        profileName = rootName .. " (" .. suffix .. ")"
    end
    return profileName
end

local AYIJE_RESOURCE_SOURCE_KEYS = {
    resourcesEnabled = true,
    resourceBarSettings = true,
    resourceGroupSettings = true,
    unifiedBorder = true,
    moveBuffsDown = true,
    moveBuffsDownOffset = true,
    moveBuffsDownFallback = true,

    resourcesBarHeight = true,
    resourcesBar2Height = true,
    resourcesBarWidth = true,
    resourcesBarTexture = true,
    resourcesBarBackgroundTexture = true,
    resourcesBackgroundColor = true,
    resourcesBarSpacing = true,
    resourcesOffsetX = true,
    resourcesOffsetY = true,
    resourcesBar1TagFontSize = true,
    resourcesBar2TagFontSize = true,
    resourcesManaPercentage = true,
    resourcesSmoothBars = true,

    resourcesManaColor = true,
    resourcesRageColor = true,
    resourcesEnergyColor = true,
    resourcesFocusColor = true,
    resourcesRunicPowerColor = true,
    resourcesLunarPowerColor = true,
    resourcesMaelstromColor = true,
    resourcesInsanityColor = true,
    resourcesFuryColor = true,
    resourcesComboPointsColor = true,
    resourcesComboPointsChargedColor = true,
    resourcesRunesReadyColor = true,
    resourcesSoulShardsColor = true,
    resourcesHolyPowerColor = true,
    resourcesArcaneChargesColor = true,
    resourcesIciclesColor = true,
    resourcesChiColor = true,
    resourcesEssenceColor = true,
    resourcesSoulFragmentsColor = true,
    resourcesDevourerSoulFragmentsColor = true,
    resourcesStaggerLightColor = true,
    resourcesTipOfTheSpearColor = true,

    resourcesManaSettings = true,
    resourcesPrimaryResourceSettings = true,
    resourcesSecondaryResourceSettings = true,
    resourcesTagSettings = true,
    resourcesMoveBuffsDown = true,
    resourcesUnifiedBorder = true,
}

local AYIJE_BAR_TOKEN = {
    Mana = "MANA",
    Rage = "RAGE",
    Energy = "ENERGY",
    Focus = "FOCUS",
    ComboPoints = "COMBO_POINTS",
    Runes = "RUNES",
    RunicPower = "RUNIC_POWER",
    SoulShards = "SOUL_SHARDS",
    LunarPower = "ASTRAL_POWER",
    HolyPower = "HOLY_POWER",
    Maelstrom = "MAELSTROM",
    MaelstromWeapon = "MAELSTROM",
    Chi = "CHI",
    Insanity = "INSANITY",
    ArcaneCharges = "ARCANE_CHARGES",
    Icicles = "ICICLES",
    Fury = "FURY",
    Essence = "ESSENCE",
    SoulFragments = "SOUL_FRAGMENTS",
    DevourerSoulFragments = "SOUL_FRAGMENTS_VENG",
    Stagger = "STAGGER",
    TipOfTheSpear = "TIP_OF_THE_SPEAR",
}

local AYIJE_LEGACY_COLOR_KEY = {
    Mana = "resourcesManaColor",
    Rage = "resourcesRageColor",
    Energy = "resourcesEnergyColor",
    Focus = "resourcesFocusColor",
    RunicPower = "resourcesRunicPowerColor",
    LunarPower = "resourcesLunarPowerColor",
    Maelstrom = "resourcesMaelstromColor",
    MaelstromWeapon = "resourcesMaelstromColor",
    Insanity = "resourcesInsanityColor",
    Fury = "resourcesFuryColor",
    ComboPoints = "resourcesComboPointsColor",
    Runes = "resourcesRunesReadyColor",
    SoulShards = "resourcesSoulShardsColor",
    HolyPower = "resourcesHolyPowerColor",
    ArcaneCharges = "resourcesArcaneChargesColor",
    Icicles = "resourcesIciclesColor",
    Chi = "resourcesChiColor",
    Essence = "resourcesEssenceColor",
    SoulFragments = "resourcesSoulFragmentsColor",
    DevourerSoulFragments = "resourcesDevourerSoulFragmentsColor",
    Stagger = "resourcesStaggerLightColor",
    TipOfTheSpear = "resourcesTipOfTheSpearColor",
}

local AYIJE_CLASS_RESOURCE_BARS = {
    DEATHKNIGHT = { "Runes" },
    ROGUE = { "ComboPoints" },
    PALADIN = { "HolyPower" },
    WARLOCK = { "SoulShards" },
    EVOKER = { "Essence" },
    MAGE = { "ArcaneCharges", "Icicles" },
    MONK = { "Chi", "Stagger" },
    DRUID = { "ComboPoints" },
    DEMONHUNTER = { "SoulFragments", "DevourerSoulFragments" },
    SHAMAN = { "MaelstromWeapon", "Maelstrom" },
    PRIEST = { "Insanity" },
    HUNTER = { "TipOfTheSpear" },
}

local AYIJE_POWER_BARS = {
    WARRIOR = { "Rage" },
    PALADIN = { "Mana" },
    HUNTER = { "Focus" },
    ROGUE = { "Energy" },
    PRIEST = { "Mana" },
    DEATHKNIGHT = { "RunicPower" },
    SHAMAN = { "Mana", "Maelstrom" },
    MAGE = { "Mana" },
    WARLOCK = { "Mana" },
    MONK = { "Energy", "Mana" },
    DRUID = { "Energy", "Rage", "LunarPower", "Mana" },
    DEMONHUNTER = { "Fury" },
    EVOKER = { "Mana" },
}

local AYIJE_CLASS_ORDER = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
    "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER",
}

local AYIJE_BAR_COMMON_DEFAULTS = {
    loadMode = "always",
    height = 16,
    width = 0,
    barTexture = "Solid",
    bgTexture = "Solid",
    bgColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.5 },
    anchorPoint = "BOTTOM",
    anchorTargetPoint = "TOP",
    offsetX = 0,
    offsetY = -200,
    barSpacing = 1,
    tagEnabled = true,
    tagFontSize = 15,
    tagAnchor = "CENTER",
    tagOffsetX = 0,
    tagOffsetY = 0,
    tagColor = { r = 1, g = 1, b = 1, a = 1 },
}

local AYIJE_BAR_DEFAULT_OVERRIDES = {
    Mana = {
        color = { r = 0.0, g = 0.56, b = 1.0, a = 1 },
        displayAsPercent = false,
        smoothBars = true,
        loadMode = "conditional",
        load = {
            hideInFeralForm = true,
            spec = { [65] = true, [256] = true, [257] = true, [264] = true, [62] = true, [63] = true, [64] = true, [105] = true, [270] = true, [1468] = true },
        },
    },
    Rage = { color = { r = 0.78, g = 0.26, b = 0.26, a = 1 }, smoothBars = true },
    Energy = { color = { r = 1, g = 1, b = 0.34, a = 1 }, smoothBars = true },
    Focus = { color = { r = 1, g = 0.5, b = 0.25, a = 1 }, smoothBars = true },
    ComboPoints = { color = { r = 1, g = 0.96, b = 0.41, a = 1 }, anchorTo = "Energy" },
    Runes = { color = { r = 0.5, g = 0.8, b = 1, a = 1 }, anchorTo = "RunicPower" },
    RunicPower = { color = { r = 0, g = 0.82, b = 1, a = 1 }, smoothBars = true },
    SoulShards = { color = { r = 0.58, g = 0.51, b = 0.79, a = 1 }, anchorTo = "Mana", offsetY = 1 },
    LunarPower = { color = { r = 0.3, g = 0.52, b = 0.9, a = 1 }, smoothBars = true, anchorTo = "Mana", offsetY = 1 },
    HolyPower = { color = { r = 0.95, g = 0.9, b = 0.6, a = 1 }, anchorTo = "Mana", offsetY = 1 },
    Maelstrom = { color = { r = 0, g = 0.5, b = 1, a = 1 }, smoothBars = true, anchorTo = "Mana", offsetY = 1 },
    MaelstromWeapon = { color = { r = 0, g = 0.5, b = 1, a = 1 }, anchorTo = "Mana", offsetY = 1 },
    Chi = { color = { r = 0.71, g = 1, b = 0.92, a = 1 }, anchorTo = "Energy" },
    Insanity = { color = { r = 0.4, g = 0, b = 0.8, a = 1 }, smoothBars = true, anchorTo = "Mana", offsetY = 1 },
    ArcaneCharges = { color = { r = 0.1, g = 0.1, b = 0.98, a = 1 }, anchorTo = "Mana", offsetY = 1 },
    Icicles = { color = { r = 0.44, g = 0.82, b = 1.0, a = 1 }, anchorTo = "Mana", offsetY = 1 },
    Fury = { color = { r = 0.79, g = 0.26, b = 0.99, a = 1 }, smoothBars = true },
    Essence = { color = { r = 0.16, g = 0.57, b = 0.49, a = 1 }, anchorTo = "Mana", offsetY = 1 },
    SoulFragments = { color = { r = 0.0, g = 0.8, b = 0.0, a = 1 }, anchorTo = "Fury" },
    DevourerSoulFragments = { color = { r = 0.11, g = 0.34, b = 0.71, a = 1 }, anchorTo = "Fury" },
    Stagger = { lightColor = { r = 0.52, g = 0.90, b = 0.52, a = 1 }, anchorTo = "Energy" },
    TipOfTheSpear = { color = { r = 0.9, g = 0.3, b = 0.15, a = 1 }, anchorTo = "Focus" },
}

local AYIJE_BAR_PER_CLASS_DEFAULTS = {
    DRUID = {
        Rage = { anchorTo = "Mana", offsetY = 1 },
        Energy = { anchorTo = "Mana", offsetY = 1 },
    },
}

local VALID_ANCHOR_POINTS = {
    TOP = true,
    BOTTOM = true,
    LEFT = true,
    RIGHT = true,
    CENTER = true,
    TOPLEFT = true,
    TOPRIGHT = true,
    BOTTOMLEFT = true,
    BOTTOMRIGHT = true,
}

local function ShallowCopyProfile(profileData)
    local copy = {}
    for key, value in pairs(profileData) do
        copy[key] = value
    end
    return copy
end

local function FiniteNumber(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then
        return nil
    end
    return n
end

local function CopyColorData(color)
    if type(color) ~= "table" then return nil end
    local r = FiniteNumber(color.r)
    local g = FiniteNumber(color.g)
    local b = FiniteNumber(color.b)
    if r == nil or g == nil or b == nil then return nil end
    return {
        r = r,
        g = g,
        b = b,
        a = FiniteNumber(color.a) or 1,
    }
end

local function WriteTranslatedValue(profileData, translated, defaults, key, value)
    if value == nil then return translated end
    local target = translated or profileData
    if target[key] ~= nil then return translated end
    if defaults and defaults[key] ~= nil and type(defaults[key]) ~= type(value) then
        return translated
    end
    if not translated then
        translated = ShallowCopyProfile(profileData)
    end
    translated[key] = CopyValue(value)
    return translated
end

local function WriteTranslatedNumber(profileData, translated, defaults, key, value, minValue)
    local n = FiniteNumber(value)
    if not n then return translated end
    if minValue and n < minValue then return translated end
    return WriteTranslatedValue(profileData, translated, defaults, key, n)
end

local function WriteTranslatedString(profileData, translated, defaults, key, value)
    if type(value) ~= "string" or value == "" then return translated end
    return WriteTranslatedValue(profileData, translated, defaults, key, value)
end

local function WriteTranslatedColor(profileData, translated, defaults, key, value)
    return WriteTranslatedValue(profileData, translated, defaults, key, CopyColorData(value))
end

local function MergeInto(target, source)
    if type(source) ~= "table" then return target end
    if not target then target = {} end
    for key, value in pairs(source) do
        target[key] = value
    end
    return target
end

local function CurrentPlayerClassToken()
    if type(UnitClass) ~= "function" then return nil end
    local _, classToken = UnitClass("player")
    return classToken
end

local function ResolveAyijeDefaultBarSettings(classKey, barKey)
    local ayije = _G.Ayije_CDM
    local merged

    merged = MergeInto(merged, ayije and ayije.RESOURCE_BAR_COMMON_DEFAULTS or AYIJE_BAR_COMMON_DEFAULTS)

    local addonDefaults = ayije and ayije.RESOURCE_BAR_DEFAULTS
    merged = MergeInto(merged, type(addonDefaults) == "table" and addonDefaults[barKey] or AYIJE_BAR_DEFAULT_OVERRIDES[barKey])

    local addonPerClass = ayije and ayije.RESOURCE_BAR_PER_CLASS_DEFAULTS
    local perClass = type(addonPerClass) == "table" and addonPerClass[classKey] or AYIJE_BAR_PER_CLASS_DEFAULTS[classKey]
    merged = MergeInto(merged, type(perClass) == "table" and perClass[barKey] or nil)

    return merged
end

local function MergeAyijeBarSettings(profileData, classKey, barKey)
    local merged = ResolveAyijeDefaultBarSettings(classKey, barKey)
    if not merged then return nil end

    local resourceBarSettings = profileData.resourceBarSettings
    if type(resourceBarSettings) ~= "table" then
        return merged
    end
    local function mergeFrom(groupKey)
        local group = resourceBarSettings[groupKey]
        local settings = type(group) == "table" and group[barKey] or nil
        if type(settings) ~= "table" then return end
        MergeInto(merged, settings)
    end

    mergeFrom("General")
    if classKey and classKey ~= "General" then
        mergeFrom(classKey)
    end
    return merged
end

local function HasExplicitAyijeBarSettings(profileData, classKey, barKey)
    local resourceBarSettings = profileData and profileData.resourceBarSettings
    if type(resourceBarSettings) ~= "table" then return false end

    local general = resourceBarSettings.General
    if type(general) == "table" and type(general[barKey]) == "table" then
        return true
    end

    local classGroup = classKey and resourceBarSettings[classKey]
    return type(classGroup) == "table" and type(classGroup[barKey]) == "table"
end

local function FindAyijeBarSettings(profileData, candidatesByClass, playerClass)
    local function findForClass(classKey)
        local candidates = candidatesByClass[classKey]
        if type(candidates) ~= "table" then return nil, nil end

        for _, barKey in ipairs(candidates) do
            if HasExplicitAyijeBarSettings(profileData, classKey, barKey) then
                local settings = MergeAyijeBarSettings(profileData, classKey, barKey)
                if settings then
                    return settings, barKey
                end
            end
        end

        for _, barKey in ipairs(candidates) do
            local settings = MergeAyijeBarSettings(profileData, classKey, barKey)
            if settings then
                return settings, barKey
            end
        end
        return nil, nil
    end

    if playerClass then
        return findForClass(playerClass)
    end

    for _, classKey in ipairs(AYIJE_CLASS_ORDER) do
        local settings, barKey = findForClass(classKey)
        if settings then
            return settings, barKey
        end
    end
    return nil, nil
end

local function IsAyijeScreenAnchor(anchorTo)
    return anchorTo == nil or anchorTo == "" or anchorTo == "screen" or anchorTo == "ui" or anchorTo == "UIParent"
end

local function ApplyAyijeLoadTranslation(profileData, translated, defaults, settings, enabledKey, loadPrefix, legacyOOCKey)
    if type(settings) ~= "table" then return translated end
    if settings.enabled == false or settings.loadMode == "never" then
        translated = WriteTranslatedValue(profileData, translated, defaults, enabledKey, false)
        return translated
    end
    if settings.loadMode ~= "conditional" or type(settings.load) ~= "table" then
        return translated
    end

    local load = settings.load
    if load.hideMounted == true then
        translated = WriteTranslatedValue(profileData, translated, defaults, loadPrefix .. "HideMounted", true)
    end
    if load.combat == true then
        translated = WriteTranslatedValue(profileData, translated, defaults, loadPrefix .. "HideOutOfCombat", true)
        if legacyOOCKey then
            translated = WriteTranslatedValue(profileData, translated, defaults, legacyOOCKey, true)
        end
    elseif load.combat == false then
        translated = WriteTranslatedValue(profileData, translated, defaults, loadPrefix .. "HideInCombat", true)
    end
    return translated
end

local function ApplyAyijeFreeAnchor(profileData, translated, defaults, settings, prefix)
    if type(settings) ~= "table" then return translated end
    local anchorTo = settings.anchorTo
    local target
    if anchorTo == "essential" then
        target = "essential"
    elseif anchorTo == "playerFrame" then
        target = "player"
    elseif anchorTo == "screen" or anchorTo == "ui" or anchorTo == "UIParent" then
        target = "ui"
    end
    if not target then return translated end

    translated = WriteTranslatedValue(profileData, translated, defaults, prefix .. "AnchorTarget", target)
    if VALID_ANCHOR_POINTS[settings.anchorPoint] then
        translated = WriteTranslatedValue(profileData, translated, defaults, prefix .. "AnchorPoint", settings.anchorPoint)
    end
    if VALID_ANCHOR_POINTS[settings.anchorTargetPoint] then
        translated = WriteTranslatedValue(profileData, translated, defaults, prefix .. "RelativePoint", settings.anchorTargetPoint)
    end
    translated = WriteTranslatedNumber(profileData, translated, defaults, prefix .. "OffsetX", settings.offsetX)
    translated = WriteTranslatedNumber(profileData, translated, defaults, prefix .. "OffsetY", settings.offsetY)
    return translated
end

local function ApplyAyijeStackAnchors(profileData, translated, defaults, classSettings, classBarKey, powerSettings, powerBarKey)
    if type(classSettings) ~= "table" and type(powerSettings) ~= "table" then return translated end

    local spacing = FiniteNumber(classSettings and classSettings.barSpacing) or FiniteNumber(powerSettings and powerSettings.barSpacing) or 1
    local powerHeight = FiniteNumber(powerSettings and powerSettings.height) or 16
    local primary = powerSettings
    local primaryBarKey = powerBarKey
    local classAnchorsToPower = classSettings and classSettings.anchorTo and primaryBarKey and classSettings.anchorTo == primaryBarKey

    if not primary and classSettings then
        primary = classSettings
        primaryBarKey = classBarKey
    end

    if type(primary) == "table" then
        local anchorTo = primary.anchorTo
        if IsAyijeScreenAnchor(anchorTo) then
            translated = WriteTranslatedValue(profileData, translated, defaults, "resourceAnchorTarget", "ui")
            translated = WriteTranslatedValue(profileData, translated, defaults, "resourceAnchorPoint", "BOTTOM")
            translated = WriteTranslatedValue(profileData, translated, defaults, "resourceRelativePoint", "CENTER")
            translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceOffsetX", primary.offsetX)
            if classAnchorsToPower then
                translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceOffsetY", (FiniteNumber(primary.offsetY) or -200) + powerHeight + spacing)
            else
                translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceOffsetY", primary.offsetY)
            end
        elseif anchorTo == "playerFrame" or anchorTo == "essential" then
            translated = ApplyAyijeFreeAnchor(profileData, translated, defaults, primary, "resource")
            if classAnchorsToPower and FiniteNumber(primary.offsetY) then
                translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceOffsetY", primary.offsetY + powerHeight + spacing)
            end
        end
    end

    if type(powerSettings) == "table" and classSettings and (classAnchorsToPower or IsAyijeScreenAnchor(powerSettings.anchorTo)) then
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourcePowerBarAnchorTarget", "resource")
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourcePowerBarAnchorPoint", "TOP")
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourcePowerBarRelativePoint", "BOTTOM")
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourcePowerBarOffsetX", 0)
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourcePowerBarOffsetY", -spacing)
    end

    return translated
end

local function ApplyAyijeClassResourceSettings(profileData, translated, defaults, settings, barKey)
    if type(settings) ~= "table" then return translated end
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceWidth", settings.width, 1)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceHeight", settings.height, 1)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceGap", settings.barSpacing, 0)
    translated = WriteTranslatedString(profileData, translated, defaults, "resourceTexture", settings.barTexture)
    translated = WriteTranslatedString(profileData, translated, defaults, "resourceBgTexture", settings.bgTexture)
    translated = WriteTranslatedColor(profileData, translated, defaults, "resourceBackgroundColor", settings.bgColor)
    if settings.tagEnabled ~= nil then
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourceShowText", settings.tagEnabled == true)
    end
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceTextSize", settings.tagFontSize, 1)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceRuneTextSize", settings.tagFontSize, 1)
    translated = ApplyAyijeFreeAnchor(profileData, translated, defaults, settings, "resource")
    translated = ApplyAyijeLoadTranslation(profileData, translated, defaults, settings, "resourceClassEnabled", "resourceLoad", "resourceHideOOC")

    if barKey == "Maelstrom" then
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourceShowEleMaelstrom", true)
    elseif barKey == "Insanity" then
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourceShowShadowInsanity", true)
    end
    return translated
end

local function ApplyAyijePowerBarSettings(profileData, translated, defaults, settings)
    if type(settings) ~= "table" then return translated end
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourcePowerBarWidth", settings.width, 1)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourcePowerBarHeight", settings.height, 1)
    translated = WriteTranslatedString(profileData, translated, defaults, "resourcePowerBarTexture", settings.barTexture)
    translated = WriteTranslatedString(profileData, translated, defaults, "resourcePowerBarBgTexture", settings.bgTexture)
    translated = WriteTranslatedColor(profileData, translated, defaults, "resourcePowerBarBackgroundColor", settings.bgColor)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourcePowerBarTextSize", settings.tagFontSize, 1)
    if settings.tagEnabled == false then
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourcePowerBarTextMode", "NONE")
    elseif settings.tagEnabled == true then
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourcePowerBarTextMode", settings.displayAsPercent == true and "PERCENT" or "VALUE")
    elseif settings.displayAsPercent ~= nil then
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourcePowerBarTextMode", settings.displayAsPercent == true and "PERCENT" or "VALUE")
    end
    if settings.smoothBars ~= nil then
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourcePowerBarSmooth", settings.smoothBars ~= false)
    end
    translated = ApplyAyijeFreeAnchor(profileData, translated, defaults, settings, "resourcePowerBar")
    translated = ApplyAyijeLoadTranslation(profileData, translated, defaults, settings, "resourcePowerBarEnabled", "resourcePowerBarLoad")
    return translated
end

local function ApplyAyijeHPFallbackSettings(profileData, translated, defaults, powerSettings, classSettings)
    local source = type(powerSettings) == "table" and powerSettings or classSettings
    if type(source) ~= "table" then return translated end

    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceHPBarWidth", source.width, 1)
    translated = WriteTranslatedString(profileData, translated, defaults, "resourceHPBarTexture", source.barTexture)
    translated = WriteTranslatedString(profileData, translated, defaults, "resourceHPBarBgTexture", source.bgTexture)
    translated = WriteTranslatedColor(profileData, translated, defaults, "resourceHPBarBackgroundColor", source.bgColor)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceHPBarTextSize", source.tagFontSize, 1)
    translated = WriteTranslatedValue(profileData, translated, defaults, "resourceHPBarAnchorTarget", "resource")
    translated = WriteTranslatedValue(profileData, translated, defaults, "resourceHPBarAnchorPoint", "TOP")
    translated = WriteTranslatedValue(profileData, translated, defaults, "resourceHPBarRelativePoint", "BOTTOM")

    local powerHeight = FiniteNumber(powerSettings and powerSettings.height) or 16
    local spacing = FiniteNumber(classSettings and classSettings.barSpacing) or FiniteNumber(powerSettings and powerSettings.barSpacing) or 1
    translated = WriteTranslatedValue(profileData, translated, defaults, "resourceHPBarOffsetX", 0)
    translated = WriteTranslatedValue(profileData, translated, defaults, "resourceHPBarOffsetY", -(powerHeight + spacing + 1))
    return translated
end

local function BuildAyijeColorOverrides(profileData, playerClass)
    local overrides
    local function add(barKey, color)
        local token = AYIJE_BAR_TOKEN[barKey]
        if not token then return end
        local copied = CopyColorData(color)
        if not copied then return end
        if not overrides then overrides = {} end
        overrides[token] = copied
    end

    for barKey in pairs(AYIJE_BAR_TOKEN) do
        local defaults = ResolveAyijeDefaultBarSettings(playerClass or "General", barKey)
        if defaults then
            add(barKey, defaults.color or defaults.lightColor)
        end
    end

    local resourceBarSettings = profileData.resourceBarSettings
    if type(resourceBarSettings) == "table" then
        for _, group in pairs(resourceBarSettings) do
            if type(group) == "table" then
                for barKey, settings in pairs(group) do
                    if type(settings) == "table" then
                        add(barKey, settings.color or settings.lightColor)
                    end
                end
            end
        end
    end

    for barKey, legacyKey in pairs(AYIJE_LEGACY_COLOR_KEY) do
        add(barKey, profileData[legacyKey])
    end
    local chargedColor = CopyColorData(profileData.resourcesComboPointsChargedColor)
    if chargedColor then
        if not overrides then overrides = {} end
        overrides.CHARGED = chargedColor
    end
    return overrides
end

local function ApplyAyijeLegacyFlatResources(profileData, translated, defaults)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceWidth", profileData.resourcesBarWidth, 1)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourcePowerBarWidth", profileData.resourcesBarWidth, 1)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceHeight", profileData.resourcesBar2Height or profileData.resourcesBarHeight, 1)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourcePowerBarHeight", profileData.resourcesBarHeight, 1)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceGap", profileData.resourcesBarSpacing, 0)
    translated = WriteTranslatedString(profileData, translated, defaults, "resourceTexture", profileData.resourcesBarTexture)
    translated = WriteTranslatedString(profileData, translated, defaults, "resourcePowerBarTexture", profileData.resourcesBarTexture)
    translated = WriteTranslatedString(profileData, translated, defaults, "resourceBgTexture", profileData.resourcesBarBackgroundTexture)
    translated = WriteTranslatedString(profileData, translated, defaults, "resourcePowerBarBgTexture", profileData.resourcesBarBackgroundTexture)
    translated = WriteTranslatedColor(profileData, translated, defaults, "resourceBackgroundColor", profileData.resourcesBackgroundColor)
    translated = WriteTranslatedColor(profileData, translated, defaults, "resourcePowerBarBackgroundColor", profileData.resourcesBackgroundColor)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceOffsetX", profileData.resourcesOffsetX)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceOffsetY", profileData.resourcesOffsetY)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourcePowerBarTextSize", profileData.resourcesBar1TagFontSize, 1)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceTextSize", profileData.resourcesBar2TagFontSize or profileData.resourcesBar1TagFontSize, 1)
    translated = WriteTranslatedNumber(profileData, translated, defaults, "resourceRuneTextSize", profileData.resourcesBar2TagFontSize or profileData.resourcesBar1TagFontSize, 1)
    if profileData.resourcesManaPercentage ~= nil then
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourcePowerBarTextMode", profileData.resourcesManaPercentage == true and "PERCENT" or "VALUE")
    end
    if profileData.resourcesSmoothBars ~= nil then
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourcePowerBarSmooth", profileData.resourcesSmoothBars ~= false)
    end
    return translated
end

local function BuildAyijeCompatibleProfileData(profileData, defaults)
    local translated

    if profileData.resourcesEnabled ~= nil then
        local enabled = profileData.resourcesEnabled ~= false
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourceClassEnabled", enabled)
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourcePowerBarEnabled", enabled)
    end

    local playerClass = CurrentPlayerClassToken()
    local classSettings, classBarKey = FindAyijeBarSettings(profileData, AYIJE_CLASS_RESOURCE_BARS, playerClass)
    translated = ApplyAyijeClassResourceSettings(profileData, translated, defaults, classSettings, classBarKey)

    local powerSettings, powerBarKey = FindAyijeBarSettings(profileData, AYIJE_POWER_BARS, playerClass)
    translated = ApplyAyijePowerBarSettings(profileData, translated, defaults, powerSettings)
    translated = ApplyAyijeStackAnchors(profileData, translated, defaults, classSettings, classBarKey, powerSettings, powerBarKey)
    translated = ApplyAyijeHPFallbackSettings(profileData, translated, defaults, powerSettings, classSettings)

    local colorOverrides = BuildAyijeColorOverrides(profileData, playerClass)
    if colorOverrides then
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourceColorOverrides", colorOverrides)
        translated = WriteTranslatedValue(profileData, translated, defaults, "resourcePowerBarColorOverrides", colorOverrides)
    end

    translated = ApplyAyijeLegacyFlatResources(profileData, translated, defaults)
    return translated or profileData, AYIJE_RESOURCE_SOURCE_KEYS
end

function ProfileIO:BuildImportProfile(payload, addonName, defaults, categoryDefs, metadataKeys, migrationKeys, existingProfiles, compatibleSourceAddons)
    local profileData, envelope
    if type(payload) == "table" and type(payload.data) == "table" and payload.profile_export_version then
        profileData = payload.data
        envelope = payload
    else
        profileData = payload
    end
    if type(profileData) ~= "table" then
        return nil, { code = "invalid_profile_data" }
    end

    addonName = addonName or AddonName
    local sourceAddon = payload.addon

    if not envelope then
        if payload.version == nil or payload.addon == nil then
            return nil, { code = "missing_profile_metadata" }
        end
        if type(payload.version) ~= "number" or payload.version < 1 then
            return nil, { code = "invalid_profile_version" }
        end
    elseif payload.profile_export_version and (type(payload.profile_export_version) ~= "number" or payload.profile_export_version < 1) then
        return nil, { code = "invalid_profile_version" }
    end

    if not sourceAddon then
        return nil, { code = "missing_profile_metadata" }
    end

    compatibleSourceAddons = compatibleSourceAddons or COMPATIBLE_SOURCE_ADDONS
    local compatibleSource = sourceAddon ~= addonName and compatibleSourceAddons and compatibleSourceAddons[sourceAddon] == true
    if sourceAddon ~= addonName and not compatibleSource then
        return nil, { code = "wrong_addon", addon = tostring(sourceAddon) }
    end

    defaults = defaults or {}
    metadataKeys = metadataKeys or {}
    migrationKeys = migrationKeys or {}

    local validKeys = {}
    if type(metadataKeys) == "table" then
        for key in pairs(metadataKeys) do
            validKeys[key] = true
        end
    end
    if type(categoryDefs) == "table" then
        for _, categoryDef in pairs(categoryDefs) do
            local keys = categoryDef and categoryDef.keys
            if type(keys) == "table" then
                for _, key in ipairs(keys) do
                    validKeys[key] = true
                end
            end
        end
    end
    for key in pairs(defaults) do
        validKeys[key] = true
    end

    local compatibleKnownKeys
    if compatibleSource and sourceAddon == "Ayije_CDM" then
        profileData, compatibleKnownKeys = BuildAyijeCompatibleProfileData(profileData, defaults)
    end

    local newProfile = {}
    local importedCount = 0
    local skippedCount = 0
    local unsupportedCount = 0
    for key, value in pairs(profileData) do
        if validKeys[key] and not metadataKeys[key] then
            local isValidType = IsValidImportedType(defaults, key, value)
            if isValidType then
                newProfile[key] = CopyValue(value)
                importedCount = importedCount + 1
            else
                skippedCount = skippedCount + 1
            end
        elseif not metadataKeys[key] and not (compatibleKnownKeys and compatibleKnownKeys[key]) then
            unsupportedCount = unsupportedCount + 1
        end
    end

    for _, key in ipairs(migrationKeys) do
        if profileData[key] ~= nil and newProfile[key] == nil then
            newProfile[key] = CopyValue(profileData[key])
            importedCount = importedCount + 1
        end
    end

    local requestedName = payload.profileName or payload.name or "Imported"
    local profileName = ResolveImportedProfileName(requestedName, existingProfiles)

    return {
        profileName = profileName,
        profileData = newProfile,
        importedCount = importedCount,
        skippedCount = skippedCount,
        unsupportedCount = unsupportedCount,
        sourceAddon = sourceAddon,
        compatibleSource = compatibleSource == true,
    }
end
