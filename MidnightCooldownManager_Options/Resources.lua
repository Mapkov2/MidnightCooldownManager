local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI

local TEXT_MODES = {
    { label = "None", value = "NONE" },
    { label = "Percent", value = "PERCENT" },
    { label = "Value", value = "VALUE" },
    { label = "Current / Max", value = "CURMAX" },
}

local ANCHOR_TARGETS = {
    { label = "Essential Cooldowns", value = "essential" },
    { label = "Utility Cooldowns", value = "utility" },
    { label = "Buffs", value = "buffs" },
    { label = "Player Frame", value = "player" },
    { label = "Screen", value = "ui" },
}

local AUX_ANCHOR_TARGETS = {
    { label = "Class Resource", value = "resource" },
    { label = "Essential Cooldowns", value = "essential" },
    { label = "Utility Cooldowns", value = "utility" },
    { label = "Player Frame", value = "player" },
    { label = "Screen", value = "ui" },
}

local WIDTH_SOURCE_OPTIONS = {
    { label = "Free", value = "free" },
    { label = "Essential Cooldowns", value = "essential" },
    { label = "Utility Cooldowns", value = "utility" },
    { label = "Buff Icons", value = "buffs" },
    { label = "Buff Bars", value = "buffbars" },
    { label = "Cooldown Group", value = "cooldownGroup" },
    { label = "Buff Group", value = "buffGroup" },
    { label = "Custom Bar Group", value = "barGroup" },
}

local WIDTH_SOURCE_OPTIONS_WITH_CLASS = {
    { label = "Free", value = "free" },
    { label = "Class Resource", value = "class" },
    { label = "Essential Cooldowns", value = "essential" },
    { label = "Utility Cooldowns", value = "utility" },
    { label = "Buff Icons", value = "buffs" },
    { label = "Buff Bars", value = "buffbars" },
    { label = "Cooldown Group", value = "cooldownGroup" },
    { label = "Buff Group", value = "buffGroup" },
    { label = "Custom Bar Group", value = "barGroup" },
}

local WIDTH_GROUP_SOURCE = {
    cooldownGroup = true,
    buffGroup = true,
    barGroup = true,
}

local HP_COLOR_MODES = {
    { label = "Class Color", value = "CLASS" },
    { label = "Global Color", value = "GLOBAL" },
    { label = "Health Gradient", value = "GRADIENT" },
    { label = "Custom", value = "CUSTOM" },
    { label = "Dark", value = "DARK" },
}

local LOAD_CONDITION_TABS = {
    { id = "class", label = "Class Resource", prefix = "resourceLoad", legacyOOC = "resourceHideOOC" },
    { id = "power", label = "Power Bar", prefix = "resourcePowerBarLoad" },
    { id = "hp", label = "HP Bar", prefix = "resourceHPBarLoad" },
}

local LOAD_CONDITIONS = {
    { suffix = "HideMounted", label = "Mounted" },
    { suffix = "HideInVehicle", label = "In vehicle" },
    { suffix = "HideResting", label = "Resting" },
    { suffix = "HideInCombat", label = "In combat" },
    { suffix = "HideOutOfCombat", label = "Out of combat" },
    { suffix = "HideStealthed", label = "Stealthed" },
    { suffix = "HideSolo", label = "Solo" },
    { suffix = "HideInGroup", label = "In group" },
    { suffix = "HideInInstance", label = "In instance" },
    { suffix = "HideNoTarget", label = "No target" },
    { suffix = "HideHasTarget", label = "Has target" },
    { suffix = "HideNoHostileTarget", label = "No hostile target" },
    { suffix = "HideNoFriendlyTarget", label = "No friendly target" },
}

local RESOURCE_COLOR_TABS = {
    { id = "class", label = "Class Resource" },
    { id = "power", label = "Power Bar" },
    { id = "hp", label = "HP Bar" },
}

local CLASS_RESOURCE_COLOR_ROWS = {
    { token = "COMBO_POINTS", label = "Combo Points", fallback = { 1.00, 0.78, 0.16 } },
    { token = "CHARGED", label = "Empowered / Charged", fallback = { 0.60, 0.20, 0.80 } },
    { token = "RUNES", label = "Runes", fallback = { 0.00, 0.82, 1.00 } },
    { token = "HOLY_POWER", label = "Holy Power", fallback = { 0.95, 0.90, 0.45 } },
    { token = "SOUL_SHARDS", label = "Soul Shards", fallback = { 0.58, 0.30, 1.00 } },
    { token = "ARCANE_CHARGES", label = "Arcane Charges", fallback = { 0.42, 0.64, 1.00 } },
    { token = "ICICLES", label = "Icicles", fallback = { 0.44, 0.82, 1.00 } },
    { token = "CHI", label = "Chi", fallback = { 0.48, 1.00, 0.62 } },
    { token = "ESSENCE", label = "Essence", fallback = { 0.22, 0.78, 1.00 } },
    { token = "MAELSTROM", label = "Maelstrom", fallback = { 0.20, 0.58, 1.00 } },
    { token = "INSANITY", label = "Insanity", fallback = { 0.48, 0.16, 0.72 } },
    { token = "SOUL_FRAGMENTS", label = "Soul Fragments", fallback = { 0.00, 0.80, 0.00 } },
    { token = "SOUL_FRAGMENTS_VENG", label = "Vengeance Fragments", fallback = { 0.58, 0.25, 1.00 } },
    { token = "WHIRLWIND", label = "Whirlwind", fallback = { 0.90, 0.28, 0.10 } },
    { token = "TIP_OF_THE_SPEAR", label = "Tip of the Spear", fallback = { 1.00, 0.52, 0.18 } },
    { token = "EBON_MIGHT", label = "Ebon Might", fallback = { 0.78, 0.38, 1.00 } },
    { token = "STAGGER", label = "Stagger", fallback = { 0.52, 1.00, 0.52 } },
}

local POWER_BAR_COLOR_ROWS = {
    { token = "MANA", label = "Mana", fallback = { 0.00, 0.44, 0.87 } },
    { token = "RAGE", label = "Rage", fallback = { 1.00, 0.00, 0.00 } },
    { token = "FOCUS", label = "Focus", fallback = { 1.00, 0.50, 0.25 } },
    { token = "ENERGY", label = "Energy", fallback = { 1.00, 0.86, 0.10 } },
    { token = "LUNAR_POWER", label = "Astral Power", fallback = { 0.30, 0.52, 0.90 } },
    { token = "INSANITY", label = "Insanity", fallback = { 0.48, 0.16, 0.72 } },
    { token = "MAELSTROM", label = "Maelstrom", fallback = { 0.20, 0.58, 1.00 } },
    { token = "FURY", label = "Fury", fallback = { 0.78, 0.26, 0.99 } },
    { token = "PAIN", label = "Pain", fallback = { 1.00, 0.61, 0.00 } },
    { token = "ESSENCE", label = "Essence", fallback = { 0.22, 0.78, 1.00 } },
}

local WHITE = "Interface\\Buttons\\WHITE8X8"
local texturePathCache = {}
local floor = math.floor
local min = math.min
local max = math.max
local PREVIEW_ZOOM_MIN = 0.6
local PREVIEW_ZOOM_MAX = 1.8
local PREVIEW_RESOURCE_BASE_Y = 44

local PREVIEW_SPECS = {
    { key = "current", label = "Current Character", token = "CURRENT", mode = "current", classToken = nil, segments = 5, value = 3 },
    { key = "deathknight_runes", label = "Death Knight - Runes", token = "RUNES", mode = "rune", classToken = "DEATHKNIGHT", segments = 6, value = 4, previewText = "4" },
    { key = "rogue_combo", label = "Rogue - Combo Points", token = "COMBO_POINTS", mode = "segmented", classToken = "ROGUE", segments = 7, value = 5, previewText = "5", chargedSlots = { [1] = true, [2] = true } },
    { key = "druid_cat", label = "Druid - Cat Combo Points", token = "COMBO_POINTS", mode = "segmented", classToken = "DRUID", segments = 5, value = 4, previewText = "4" },
    { key = "paladin_holy", label = "Paladin - Holy Power", token = "HOLY_POWER", mode = "segmented", classToken = "PALADIN", segments = 5, value = 3, previewText = "3" },
    { key = "warlock_soul", label = "Warlock - Soul Shards", token = "SOUL_SHARDS", mode = "segmented", classToken = "WARLOCK", segments = 5, value = 3, previewText = "3" },
    { key = "warlock_destro", label = "Warlock - Destruction Shards", token = "SOUL_SHARDS", mode = "fractional", classToken = "WARLOCK", segments = 5, value = 3.4, previewText = "3.4" },
    { key = "evoker_essence", label = "Evoker - Essence", token = "ESSENCE", mode = "segmented", classToken = "EVOKER", segments = 6, value = 4, previewText = "4" },
    { key = "evoker_ebon", label = "Evoker - Ebon Might", token = "EBON_MIGHT", mode = "timer", classToken = "EVOKER", segments = 1, value = 0.58, previewText = "11.6s" },
    { key = "mage_arcane", label = "Mage - Arcane Charges", token = "ARCANE_CHARGES", mode = "segmented", classToken = "MAGE", segments = 4, value = 3, previewText = "3" },
    { key = "mage_frost", label = "Mage - Icicles", token = "ICICLES", mode = "segmented", classToken = "MAGE", segments = 5, value = 3, previewText = "3" },
    { key = "monk_chi", label = "Monk - Chi", token = "CHI", mode = "segmented", classToken = "MONK", segments = 6, value = 4, previewText = "4" },
    { key = "monk_stagger", label = "Monk - Stagger", token = "STAGGER", mode = "continuous", classToken = "MONK", segments = 1, value = 0.42, previewText = "42%" },
    { key = "dh_fragments", label = "Demon Hunter - Soul Fragment", token = "SOUL_FRAGMENTS", mode = "single", classToken = "DEMONHUNTER", segments = 1, value = 1, previewText = "1" },
    { key = "dh_vengeance", label = "Demon Hunter - Vengeance Fragments", token = "SOUL_FRAGMENTS_VENG", mode = "segmented", classToken = "DEMONHUNTER", segments = 6, value = 4, previewText = "4" },
    { key = "shaman_enh", label = "Shaman - Maelstrom Weapon", token = "MAELSTROM", mode = "segmented", classToken = "SHAMAN", segments = 10, value = 7, previewText = "7" },
    { key = "shaman_ele", label = "Shaman - Elemental Maelstrom", token = "MAELSTROM", mode = "continuous", classToken = "SHAMAN", segments = 1, value = 0.68, previewText = "68%" },
    { key = "priest_shadow", label = "Priest - Shadow Insanity", token = "INSANITY", mode = "continuous", classToken = "PRIEST", segments = 1, value = 0.62, previewText = "62%" },
    { key = "warrior_ww", label = "Warrior - Whirlwind Stacks", token = "WHIRLWIND", mode = "segmented", classToken = "WARRIOR", segments = 4, value = 2, previewText = "2" },
    { key = "hunter_tip", label = "Hunter - Tip of the Spear", token = "TIP_OF_THE_SPEAR", mode = "segmented", classToken = "HUNTER", segments = 3, value = 2, previewText = "2" },
}

local PREVIEW_SPEC_BY_KEY = {}
local PREVIEW_SPEC_OPTIONS = {}
for _, spec in ipairs(PREVIEW_SPECS) do
    PREVIEW_SPEC_BY_KEY[spec.key] = spec
    PREVIEW_SPEC_OPTIONS[#PREVIEW_SPEC_OPTIONS + 1] = { label = spec.label, value = spec.key }
end

local PREVIEW_LAYERS = {
    { key = "guides", label = "Guides" },
    { key = "border", label = "Border" },
    { key = "reference", label = "Reference" },
    { key = "resource", label = "Resource" },
    { key = "resourceText", label = "Res Text" },
    { key = "power", label = "Power Bar" },
    { key = "powerText", label = "Power Txt" },
    { key = "hp", label = "HP Bar" },
    { key = "hpText", label = "HP Text" },
    { key = "bounds", label = "Bounds" },
}

local function SaveAndRefresh()
    API:Refresh("RESOURCES")
end

local function ReadMediaValue(key, fallback)
    if CDM.db and CDM.db[key] ~= nil then return CDM.db[key] end
    if CDM.defaults and CDM.defaults[key] ~= nil then return CDM.defaults[key] end
    return fallback
end

local function ResolveStatusbarTexture(name, fallback)
    if name and name ~= "" then
        local cached = texturePathCache[name]
        if cached ~= nil then return cached or fallback or WHITE end
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        local path = LSM and LSM:Fetch("statusbar", name, true)
        texturePathCache[name] = path or false
        if path then return path end
    end
    return fallback or WHITE
end

local function SetDB(key, value)
    CDM.db[key] = value
    SaveAndRefresh()
end

local function ColorFromTable(color, fallback)
    color = type(color) == "table" and color or fallback
    fallback = type(fallback) == "table" and fallback or { r = 1, g = 1, b = 1, a = 1 }
    return {
        r = color.r or color[1] or fallback.r or fallback[1] or 1,
        g = color.g or color[2] or fallback.g or fallback[2] or 1,
        b = color.b or color[3] or fallback.b or fallback[3] or 1,
        a = color.a or color[4] or fallback.a or fallback[4] or 1,
    }
end

local function TokenFallbackColor(token, classToken, fallback)
    local pbc = _G.PowerBarColor
    local c = token and pbc and pbc[token]
    if c then return c.r or 1, c.g or 1, c.b or 1, 1 end
    local class = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if class then return class.r, class.g, class.b, 1 end
    fallback = fallback or { 0.20, 0.58, 1.00, 1 }
    return fallback[1] or fallback.r or 1,
        fallback[2] or fallback.g or 1,
        fallback[3] or fallback.b or 1,
        fallback[4] or fallback.a or 1
end

local function GetOverrideTable(key)
    if type(CDM.db[key]) ~= "table" then
        CDM.db[key] = {}
    end
    return CDM.db[key]
end

local function GetOverrideColor(key, token)
    local tbl = CDM.db and CDM.db[key]
    return type(tbl) == "table" and type(tbl[token]) == "table" and tbl[token] or nil
end

local function ReadBool(key)
    if CDM.db and CDM.db[key] ~= nil then
        return CDM.db[key] == true
    end
    return CDM.defaults and CDM.defaults[key] == true
end

local function ReadValue(key, fallback)
    if CDM.db and CDM.db[key] ~= nil then
        return CDM.db[key]
    end
    if CDM.defaults and CDM.defaults[key] ~= nil then
        return CDM.defaults[key]
    end
    return fallback
end

local function ReadLoadCondition(prefix, suffix, legacyKey)
    local key = prefix .. suffix
    if CDM.db and CDM.db[key] ~= nil then
        return CDM.db[key] == true
    end
    if legacyKey and CDM.db and CDM.db[legacyKey] ~= nil then
        return CDM.db[legacyKey] == true
    end
    if CDM.defaults and CDM.defaults[key] ~= nil then
        return CDM.defaults[key] == true
    end
    if legacyKey and CDM.defaults and CDM.defaults[legacyKey] ~= nil then
        return CDM.defaults[legacyKey] == true
    end
    return false
end

local function SetLoadCondition(prefix, suffix, checked)
    CDM.db[prefix .. suffix] = checked and true or false
    SaveAndRefresh()
end

local function CreateDropdown(parent, label, width, options, key, scope)
    local text = parent:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    text:SetText(label)
    UI.SetTextSubtle(text)

    local current = CDM.db[key]
    local dd = UI.CreateDropdown(parent, width or 190)
    UI.SetupValueDropdown(dd, options, function()
        return CDM.db[key]
    end, function(value, labelText)
        CDM.db[key] = value
        dd:SetDefaultText(labelText or value)
        API:Refresh(scope or "RESOURCES")
    end)
    dd:SetDefaultText(UI.GetOptionLabel(options, current, tostring(current or "")))
    return text, dd
end

local function NormalizeWidthSource(mode, allowClass)
    mode = type(mode) == "string" and mode or "free"
    if mode == "manual" or mode == "custom" then mode = "free" end
    if mode == "buff" then mode = "buffs" end
    if mode == "bars" or mode == "buffBar" then mode = "buffbars" end
    if mode == "class" and not allowClass then mode = "free" end
    if mode == "class"
        or mode == "free"
        or mode == "essential"
        or mode == "utility"
        or mode == "buffs"
        or mode == "buffbars"
        or WIDTH_GROUP_SOURCE[mode]
    then
        return mode
    end
    return "free"
end

local function WidthGroupSets(mode)
    if mode == "cooldownGroup" then
        return CDM.CooldownGroupSets
    elseif mode == "buffGroup" then
        return CDM.BuffGroupSets
    elseif mode == "barGroup" then
        return CDM.BarGroupSets
    end
    return nil
end

local function WidthGroupLabel(group, index)
    if type(group) == "table" then
        local name = group.name or group.label or group.title
        if name and name ~= "" then return tostring(name) end
    end
    return "Group " .. tostring(index or 1)
end

local function BuildWidthGroupOptions(mode)
    local sets = WidthGroupSets(mode)
    local groups = sets and sets.groups
    local options = {}
    if type(groups) == "table" then
        for index, group in ipairs(groups) do
            options[#options + 1] = { label = WidthGroupLabel(group, index), value = index }
        end
    end
    if #options == 0 then
        options[1] = { label = "Group 1", value = 1 }
    end
    return options
end

local function RefreshWidthGroupDropdown(label, dropdown, modeKey, indexKey)
    if not dropdown then return end
    local mode = NormalizeWidthSource(ReadValue(modeKey, "free"), true)
    local enabled = WIDTH_GROUP_SOURCE[mode] == true
    local index = tonumber(ReadValue(indexKey, 1)) or 1
    local options = BuildWidthGroupOptions(mode)

    dropdown:SetAlpha(enabled and 1 or 0.45)
    dropdown:EnableMouse(enabled)
    if label and label.SetAlpha then label:SetAlpha(enabled and 1 or 0.55) end
    if dropdown.SetDefaultText then
        dropdown:SetDefaultText(enabled and UI.GetOptionLabel(options, index, "Group " .. tostring(index)) or "Not used")
    end
end

local function AddWidthSourceRows(parent, y, modeKey, indexKey, allowClass, onChange)
    local options = allowClass and WIDTH_SOURCE_OPTIONS_WITH_CLASS or WIDTH_SOURCE_OPTIONS

    local sourceLabel = parent:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    sourceLabel:SetText("Width Source")
    UI.SetTextSubtle(sourceLabel)
    sourceLabel:SetPoint("TOPLEFT", 0, y)

    local sourceDD = UI.CreateDropdown(parent, 220)
    sourceDD:SetPoint("LEFT", sourceLabel, "RIGHT", 16, 0)

    local groupLabel = parent:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    groupLabel:SetText("Source Group")
    UI.SetTextSubtle(groupLabel)
    groupLabel:SetPoint("TOPLEFT", 0, y - 34)

    local groupDD = UI.CreateDropdown(parent, 220)
    groupDD:SetPoint("LEFT", groupLabel, "RIGHT", 16, 0)

    UI.SetupValueDropdown(sourceDD, options, function()
        return NormalizeWidthSource(ReadValue(modeKey, "free"), allowClass)
    end, function(value, labelText)
        CDM.db[modeKey] = NormalizeWidthSource(value, allowClass)
        sourceDD:SetDefaultText(labelText or UI.GetOptionLabel(options, CDM.db[modeKey], tostring(CDM.db[modeKey] or "")))
        RefreshWidthGroupDropdown(groupLabel, groupDD, modeKey, indexKey)
        SaveAndRefresh()
        if type(onChange) == "function" then onChange() end
    end)

    UI.SetupValueDropdown(groupDD, function()
        return BuildWidthGroupOptions(NormalizeWidthSource(ReadValue(modeKey, "free"), true))
    end, function()
        return tonumber(ReadValue(indexKey, 1)) or 1
    end, function(value, labelText)
        CDM.db[indexKey] = tonumber(value) or 1
        groupDD:SetDefaultText(labelText or ("Group " .. tostring(CDM.db[indexKey])))
        SaveAndRefresh()
        if type(onChange) == "function" then onChange() end
    end)

    sourceDD:SetDefaultText(UI.GetOptionLabel(options, NormalizeWidthSource(ReadValue(modeKey, "free"), allowClass), "Free"))
    RefreshWidthGroupDropdown(groupLabel, groupDD, modeKey, indexKey)
    return y - 76
end

local function CreatePreview(parent)
    local frame = UI.CreatePanel(parent, nil, { r = 0.010, g = 0.014, b = 0.026, a = 0.86 }, UI.Theme.colors.borderSoft)
    frame:SetSize(900, 418)
    frame.previewKey = "current"
    frame.previewZoom = 1
    frame.layerVisibility = {}
    frame.layerAvailability = {}
    for _, def in ipairs(PREVIEW_LAYERS) do
        frame.layerVisibility[def.key] = true
    end

    local function Clamp(value, fallback, minValue, maxValue)
        value = tonumber(value) or fallback
        if value < minValue then return minValue end
        if value > maxValue then return maxValue end
        return value
    end

    local function LayerOn(key)
        return frame.layerVisibility[key] ~= false and frame.layerAvailability[key] ~= false
    end

    local function SetTextureColor(tex, r, g, b, a)
        if not tex then return end
        tex:SetTexture(WHITE)
        tex:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    end

    local function TokenColor(token, classToken, fallback)
        local colors = {
            COMBO_POINTS = { 1.00, 0.78, 0.16 },
            CHARGED = { 0.60, 0.20, 0.80 },
            RUNES = { 0.00, 0.82, 1.00 },
            HOLY_POWER = { 0.95, 0.90, 0.45 },
            SOUL_SHARDS = { 0.58, 0.30, 1.00 },
            ARCANE_CHARGES = { 0.42, 0.64, 1.00 },
            ICICLES = { 0.44, 0.82, 1.00 },
            CHI = { 0.48, 1.00, 0.62 },
            ESSENCE = { 0.22, 0.78, 1.00 },
            MAELSTROM = { 0.20, 0.58, 1.00 },
            INSANITY = { 0.48, 0.16, 0.72 },
            SOUL_FRAGMENTS = { 0.00, 0.80, 0.00 },
            SOUL_FRAGMENTS_VENG = { 0.58, 0.25, 1.00 },
            WHIRLWIND = { 0.90, 0.28, 0.10 },
            TIP_OF_THE_SPEAR = { 1.00, 0.52, 0.18 },
            EBON_MIGHT = { 0.78, 0.38, 1.00 },
            STAGGER = { 0.52, 1.00, 0.52 },
        }
        local value = token and colors[token]
        return TokenFallbackColor(token, classToken, value or fallback or { 0.20, 0.58, 1.00 })
    end

    local function PreviewOverrideColor(token, overrideKey, classToken, fallback)
        local override = GetOverrideColor(overrideKey, token)
        if override then
            local color = ColorFromTable(override, fallback)
            return color.r, color.g, color.b, color.a
        end
        return TokenColor(token, classToken, fallback)
    end

    local function DBColor(key, fallback)
        local color = (CDM.db and CDM.db[key]) or (CDM.defaults and CDM.defaults[key]) or fallback
        color = type(color) == "table" and color or fallback
        return color.r or color[1] or fallback.r or 1,
            color.g or color[2] or fallback.g or 1,
            color.b or color[3] or fallback.b or 1,
            color.a or color[4] or fallback.a or 1
    end

    local function LerpColor(a, b, t)
        return (a or 0) + (((b or 0) - (a or 0)) * t)
    end

    local function PreviewHPColor(value)
        local mode = tostring((CDM.db and CDM.db.resourceHPBarColorMode) or (CDM.defaults and CDM.defaults.resourceHPBarColorMode) or "CLASS"):upper()
        if mode == "CUSTOM" then
            return DBColor("resourceHPBarColor", { r = 0.12, g = 0.76, b = 0.28, a = 1 })
        elseif mode == "GLOBAL" then
            return DBColor("resourceHPBarGlobalColor", { r = 0.12, g = 0.76, b = 0.28, a = 1 })
        elseif mode == "DARK" then
            return DBColor("resourceHPBarDarkColor", { r = 0.07, g = 0.08, b = 0.09, a = 1 })
        elseif mode == "GRADIENT" then
            local pct = max(0, min(1, tonumber(value) or 1))
            local lr, lg, lb = DBColor("resourceHPBarGradientLow", { r = 0.86, g = 0.16, b = 0.12, a = 1 })
            local mr, mg, mb = DBColor("resourceHPBarGradientMid", { r = 0.95, g = 0.76, b = 0.16, a = 1 })
            local hr, hg, hb = DBColor("resourceHPBarGradientHigh", { r = 0.16, g = 0.78, b = 0.28, a = 1 })
            if pct <= 0.5 then
                local t = pct * 2
                return LerpColor(lr, mr, t), LerpColor(lg, mg, t), LerpColor(lb, mb, t), 1
            end
            local t = (pct - 0.5) * 2
            return LerpColor(mr, hr, t), LerpColor(mg, hg, t), LerpColor(mb, hb, t), 1
        end
        return TokenColor(nil, (UnitClass and select(2, UnitClass("player"))) or nil, { 0.42, 0.72, 0.32 })
    end

    local function CreateBorderBox(parentFrame)
        local box = CreateFrame("Frame", nil, parentFrame)
        box:Hide()
        box.lines = {}
        for i = 1, 4 do
            local line = box:CreateTexture(nil, "OVERLAY")
            line:SetTexture(WHITE)
            box.lines[i] = line
        end
        function box:SetBoxColor(r, g, b, a)
            for i = 1, 4 do
                box.lines[i]:SetVertexColor(r, g, b, a or 1)
            end
        end
        function box:Place(target, pad, thickness)
            if not target then self:Hide(); return end
            pad = pad or 0
            thickness = thickness or 1
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", target, "TOPLEFT", -pad, pad)
            self:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", pad, -pad)
            self.lines[1]:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
            self.lines[1]:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
            self.lines[1]:SetHeight(thickness)
            self.lines[2]:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
            self.lines[2]:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
            self.lines[2]:SetHeight(thickness)
            self.lines[3]:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
            self.lines[3]:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
            self.lines[3]:SetWidth(thickness)
            self.lines[4]:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
            self.lines[4]:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
            self.lines[4]:SetWidth(thickness)
            self:Show()
        end
        return box
    end

    local function CreateMeter(parentFrame)
        local bar = CreateFrame("StatusBar", nil, parentFrame)
        bar:SetStatusBarTexture(WHITE)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints()
        SetTextureColor(bar.bg, 0, 0, 0, 0.35)
        bar.text = bar:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font12")
        bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        bar.text:SetShadowColor(0, 0, 0, 1)
        bar.text:SetShadowOffset(1, -1)
        bar.text:Hide()
        bar.border = CreateBorderBox(bar)
        return bar
    end

    local function ResolveCurrentSpec()
        local diag = CDM.GetResourceDiagnostics and CDM:GetResourceDiagnostics() or nil
        local maxPower = tonumber(diag and diag.maxPower) or 0
        local modeID = tonumber(diag and diag.mode) or 0
        local token = diag and diag.powerToken or nil
        if maxPower <= 0 or not token then
            return { key = "current", label = "Current Character", token = token or "NONE", mode = "none", segments = 0, value = 0, noResource = true }
        end
        local mode = "segmented"
        if modeID == 2 then mode = "fractional"
        elseif modeID == 3 then mode = "rune"
        elseif modeID == 5 then mode = "single"
        elseif modeID == 6 or modeID == 8 or modeID == 9 then mode = "continuous" end
        return {
            key = "current",
            label = "Current Character",
            token = token,
            mode = mode,
            segments = max(1, min(10, floor(maxPower + 0.5))),
            value = max(1, floor(maxPower * 0.68 + 0.5)),
            previewText = tostring(floor(maxPower * 0.68 + 0.5)),
        }
    end

    local title = frame:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -10)
    title:SetText("Class Resources Preview")
    UI.SetTextColor(title, UI.Theme.colors.accent)

    local hint = frame:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font12")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    hint:SetPoint("RIGHT", frame, "RIGHT", -332, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Ctrl+wheel zoom - right/Ctrl-drag pans - drag bars - arrows move selected")
    UI.SetTextMuted(hint)

    local label = frame:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font12")
    label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -286, -10)
    label:SetText("Preview Resource")
    UI.SetTextSubtle(label)

    local previewDropdown = UI.CreateDropdown(frame, 260)
    UI.SetupValueDropdown(previewDropdown, PREVIEW_SPEC_OPTIONS, function()
        return frame.previewKey or "current"
    end, function(value, labelText)
        frame.previewKey = PREVIEW_SPEC_BY_KEY[value] and value or "current"
        previewDropdown:SetDefaultText(labelText or (PREVIEW_SPEC_BY_KEY[frame.previewKey] and PREVIEW_SPEC_BY_KEY[frame.previewKey].label) or "Current Character")
        frame:RefreshPreview()
    end)
    previewDropdown:SetPoint("LEFT", label, "RIGHT", 10, 0)
    previewDropdown:SetDefaultText("Current Character")

    local summary = frame:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font12")
    summary:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -4)
    summary:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    summary:SetJustifyH("LEFT")
    UI.SetTextMuted(summary)
    frame.summary = summary

    local canvas = UI.CreatePanel(frame, nil, { r = 0.000, g = 0.000, b = 0.000, a = 1.000 }, UI.Theme.colors.borderSoft)
    canvas:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -88)
    canvas:SetSize(748, 300)
    if canvas.SetClipsChildren then canvas:SetClipsChildren(true) end
    frame.canvas = canvas

    local stage = CreateFrame("Frame", nil, canvas)
    stage:SetSize(748, 300)
    stage:SetPoint("CENTER", canvas, "CENTER", 0, 0)
    frame.stage = stage
    frame.panX = 0
    frame.panY = 0

    local function ApplyStageTransform()
        local zoom = Clamp(frame.previewZoom or 1, 1, PREVIEW_ZOOM_MIN, PREVIEW_ZOOM_MAX)
        frame.previewZoom = zoom
        frame.panX = tonumber(frame.panX) or 0
        frame.panY = tonumber(frame.panY) or 0
        stage:ClearAllPoints()
        stage:SetPoint("CENTER", canvas, "CENTER", frame.panX, frame.panY)
        if stage.SetScale then stage:SetScale(zoom) end
        if frame.zoomText then frame.zoomText:SetText(floor(zoom * 100 + 0.5) .. "%") end
    end

    local toolbar = CreateFrame("Frame", nil, canvas)
    toolbar:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -8, -7)
    toolbar:SetSize(286, 24)
    frame.toolbar = toolbar

    local function MakeToolButton(text, width, onClick)
        local btn = UI.CreateModernButton(toolbar, text, width or 52, 22)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    local animate = MakeToolButton("Animate", 70, function()
        frame.animating = not frame.animating
        frame.animationElapsed = 0
        frame:RefreshPreview()
    end)
    animate:SetPoint("RIGHT", toolbar, "RIGHT", -198, 0)
    frame.animateButton = animate

    local zoomOut = MakeToolButton("-", 24, function()
        frame.previewZoom = Clamp((frame.previewZoom or 1) - 0.1, 1, PREVIEW_ZOOM_MIN, PREVIEW_ZOOM_MAX)
        frame:RefreshPreview()
    end)
    zoomOut:SetPoint("LEFT", animate, "RIGHT", 8, 0)

    local zoomText = toolbar:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font12")
    zoomText:SetPoint("LEFT", zoomOut, "RIGHT", 6, 0)
    zoomText:SetSize(58, 18)
    zoomText:SetJustifyH("CENTER")
    UI.SetTextSubtle(zoomText)
    frame.zoomText = zoomText

    local fit = MakeToolButton("Fit", 34, function()
        frame.previewZoom = 1
        frame.panX = 0
        frame.panY = 0
        frame:RefreshPreview()
    end)
    fit:SetPoint("LEFT", zoomText, "RIGHT", 6, 0)

    local one = MakeToolButton("1:1", 34, function()
        frame.previewZoom = 1
        frame.panX = 0
        frame.panY = 0
        frame:RefreshPreview()
    end)
    one:SetPoint("LEFT", fit, "RIGHT", 4, 0)

    local zoomIn = MakeToolButton("+", 24, function()
        frame.previewZoom = Clamp((frame.previewZoom or 1) + 0.1, 1, PREVIEW_ZOOM_MIN, PREVIEW_ZOOM_MAX)
        frame:RefreshPreview()
    end)
    zoomIn:SetPoint("LEFT", one, "RIGHT", 4, 0)

    local pinned = UI.CreateModernButton(frame, "Pinned", 74, 22, "primary")
    pinned:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -12, -38)
    pinned:Disable()

    local ref = UI.CreatePanel(stage, nil, { r = 0.170, g = 0.170, b = 0.055, a = 0.75 }, { r = 0.40, g = 0.55, b = 0.80, a = 0.9 })
    ref:SetSize(300, 42)
    ref:SetPoint("CENTER", stage, "CENTER", 0, -64)
    ref.label = ref:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font12")
    ref.label:SetPoint("LEFT", ref, "LEFT", 10, 0)
    ref.label:SetText("Player frame reference")
    UI.SetTextSubtle(ref.label)
    frame.reference = ref

    local resource = CreateFrame("Frame", nil, stage, "BackdropTemplate")
    resource:SetSize(220, 8)
    resource.bars = {}
    resource.ticks = {}
    for i = 1, 10 do
        resource.bars[i] = CreateMeter(resource)
    end
    resource.border = CreateBorderBox(resource)
    resource.text = resource:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    resource.text:SetPoint("CENTER", resource, "CENTER", 0, 0)
    resource.text:SetShadowColor(0, 0, 0, 1)
    resource.text:SetShadowOffset(1, -1)
    resource:EnableMouse(false)
    frame.resource = resource

    local power = CreateMeter(stage)
    power:EnableMouse(false)
    frame.power = power

    local hp = CreateMeter(stage)
    hp:EnableMouse(false)
    frame.hp = hp

    frame.bounds = {
        reference = CreateBorderBox(stage),
        resource = CreateBorderBox(stage),
        power = CreateBorderBox(stage),
        hp = CreateBorderBox(stage),
    }
    frame.guides = {
        resource = CreateBorderBox(stage),
        power = CreateBorderBox(stage),
        hp = CreateBorderBox(stage),
    }
    for _, box in pairs(frame.bounds) do box:SetBoxColor(1.00, 0.18, 0.10, 0.85) end
    for _, box in pairs(frame.guides) do box:SetBoxColor(0.30, 0.78, 1.00, 0.85) end

    local noResource = canvas:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    noResource:SetPoint("CENTER", canvas, "CENTER", 0, 32)
    noResource:SetText("Class resource is disabled for this preview resource.")
    UI.SetTextMuted(noResource)
    frame.noResource = noResource

    local selectionText = canvas:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font12")
    selectionText:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", 10, 8)
    selectionText:SetText("")
    UI.SetTextMuted(selectionText)
    frame.selectionText = selectionText

    local sidebar = UI.CreatePanel(frame, nil, { r = 0.018, g = 0.022, b = 0.040, a = 0.88 }, UI.Theme.colors.borderSoft)
    sidebar:SetPoint("TOPLEFT", canvas, "TOPRIGHT", 8, 0)
    sidebar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 30)
    frame.sidebar = sidebar

    local layersTitle = sidebar:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font12")
    layersTitle:SetPoint("TOP", sidebar, "TOP", 0, -7)
    layersTitle:SetText("LAYERS")
    UI.SetTextMuted(layersTitle)

    frame.layerButtons = {}
    for i, def in ipairs(PREVIEW_LAYERS) do
        local btn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        btn:SetSize(82, 18)
        btn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -24 - ((i - 1) * 20))
        btn:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        btn.key = def.key
        btn.text = btn:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font12")
        btn.text:SetPoint("LEFT", btn, "LEFT", 6, 0)
        btn.text:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
        btn.text:SetJustifyH("LEFT")
        btn:SetScript("OnClick", function(self)
            if frame.layerAvailability[self.key] == false then return end
            frame.layerVisibility[self.key] = frame.layerVisibility[self.key] == false
            frame:RefreshPreview()
        end)
        frame.layerButtons[#frame.layerButtons + 1] = btn
    end

    local function RefreshLayerButtons()
        for index, btn in ipairs(frame.layerButtons) do
            local available = frame.layerAvailability[btn.key] ~= false
            local on = frame.layerVisibility[btn.key] ~= false and available
            btn.text:SetText((btn.key == "power" and not available) and "Power OFF"
                or (btn.key == "hp" and not available) and "HP Bar OFF"
                or (btn.key == "resourceText" and not available) and "Res Text OFF"
                or (btn.key == "powerText" and not available) and "Power Txt OFF"
                or (btn.key == "hpText" and not available) and "HP Txt OFF"
                or (PREVIEW_LAYERS[index] and PREVIEW_LAYERS[index].label)
                or btn.key)
            if on then
                btn:SetBackdropColor(0.04, 0.08, 0.16, 0.88)
                btn:SetBackdropBorderColor(0.12, 0.34, 0.70, 0.82)
                btn.text:SetTextColor(0.85, 0.90, 1.00, 1)
            elseif available then
                btn:SetBackdropColor(0.02, 0.025, 0.04, 0.76)
                btn:SetBackdropBorderColor(0.08, 0.10, 0.16, 0.76)
                btn.text:SetTextColor(0.52, 0.58, 0.70, 0.95)
            else
                btn:SetBackdropColor(0.018, 0.020, 0.030, 0.46)
                btn:SetBackdropBorderColor(0.05, 0.06, 0.08, 0.46)
                btn.text:SetTextColor(0.32, 0.34, 0.40, 0.70)
            end
        end
    end

    local DRAG_DEFS = {
        resource = { label = "Class Resource", xKey = "resourceOffsetX", yKey = "resourceOffsetY", fallbackX = 0, fallbackY = 18, minX = -800, maxX = 800, minY = -800, maxY = 800 },
        power = { label = "Player Power", xKey = "resourcePowerBarOffsetX", yKey = "resourcePowerBarOffsetY", fallbackX = 0, fallbackY = -4, minX = -800, maxX = 800, minY = -800, maxY = 800 },
        hp = { label = "Second HP", xKey = "resourceHPBarOffsetX", yKey = "resourceHPBarOffsetY", fallbackX = 0, fallbackY = -18, minX = -800, maxX = 800, minY = -800, maxY = 800 },
    }

    local function OffsetValue(def, axis)
        local key = axis == "x" and def.xKey or def.yKey
        local fallbackKey = axis == "x" and def.fallbackX or def.fallbackY
        local value = CDM.db and tonumber(CDM.db[key])
        if value == nil and CDM.defaults then value = tonumber(CDM.defaults[key]) end
        return value or fallbackKey or 0
    end

    local function ClearTextFocus()
        local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if focus and focus.ClearFocus then focus:ClearFocus() end
    end

    local keyCapture
    local arrowOwner
    local SetPreviewOffsets
    local ARROW_BINDING_PREFIXES = { "", "SHIFT-", "CTRL-", "CTRL-SHIFT-", "SHIFT-CTRL-" }
    local ARROW_DIRECTIONS = {
        { "LEFT", -1, 0 },
        { "RIGHT", 1, 0 },
        { "UP", 0, 1 },
        { "DOWN", 0, -1 },
    }

    local function IsTextInputFocused()
        local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        return focus and focus.IsObjectType and focus:IsObjectType("EditBox")
    end

    local function NudgeStep()
        if IsControlKeyDown and IsControlKeyDown() then return 10 end
        if IsShiftKeyDown and IsShiftKeyDown() then return 5 end
        return 1
    end

    local function NudgeSelected(dx, dy)
        local selected = frame.selectedPreviewKind
        local def = selected and DRAG_DEFS[selected]
        if not def or IsTextInputFocused() then return false end
        local step = NudgeStep()
        SetPreviewOffsets(selected, OffsetValue(def, "x") + ((tonumber(dx) or 0) * step), OffsetValue(def, "y") + ((tonumber(dy) or 0) * step), true)
        if keyCapture and keyCapture.SetFocus then keyCapture:SetFocus() end
        return true
    end
    frame._mcdmNudgeSelected = NudgeSelected

    local function SetArrowBindings(enabled)
        if InCombatLockdown and InCombatLockdown() then return end
        arrowOwner = arrowOwner or _G.MidnightCDM_ResourcesPreview_NudgeOwner
        if arrowOwner and ClearOverrideBindings then ClearOverrideBindings(arrowOwner) end
        if arrowOwner and arrowOwner.Hide then arrowOwner:Hide() end
        _G.MidnightCDM_ResourcesPreview_ActiveNudgeFrame = nil
        if not enabled or not frame.selectedPreviewKind then return end

        if not arrowOwner then
            arrowOwner = CreateFrame("Frame", "MidnightCDM_ResourcesPreview_NudgeOwner", UIParent or frame)
            _G.MidnightCDM_ResourcesPreview_NudgeOwner = arrowOwner
        end
        _G.MidnightCDM_ResourcesPreview_ActiveNudgeFrame = frame
        arrowOwner:Show()

        for i = 1, #ARROW_DIRECTIONS do
            local dir = ARROW_DIRECTIONS[i]
            local btnName = "MidnightCDM_ResourcesPreview_Nudge" .. dir[1]
            local btn = _G[btnName]
            if not btn then
                btn = CreateFrame("Button", btnName, arrowOwner, "SecureActionButtonTemplate")
                btn:SetSize(1, 1)
                btn:Hide()
                btn:SetScript("OnClick", function(self)
                    local active = _G.MidnightCDM_ResourcesPreview_ActiveNudgeFrame
                    if active and active._mcdmNudgeSelected then
                        active._mcdmNudgeSelected(self._mcdmDx or 0, self._mcdmDy or 0)
                    end
                end)
            end
            btn._mcdmDx, btn._mcdmDy = dir[2], dir[3]
            if SetOverrideBindingClick then
                for j = 1, #ARROW_BINDING_PREFIXES do
                    SetOverrideBindingClick(arrowOwner, false, ARROW_BINDING_PREFIXES[j] .. dir[1], btnName)
                end
            end
        end
    end

    local function RefreshSelectionState()
        local selected = frame.selectedPreviewKind
        for kind, box in pairs(frame.guides) do
            if selected == kind then
                box:SetBoxColor(1.00, 0.82, 0.15, 0.98)
            else
                box:SetBoxColor(0.30, 0.78, 1.00, 0.85)
            end
        end
        if frame.previewHandles then
            for kind, handle in pairs(frame.previewHandles) do
                if selected == kind then
                    handle:SetBackdropColor(1.00, 0.82, 0.15, 0.12)
                    handle:SetBackdropBorderColor(1.00, 0.82, 0.15, 0.98)
                elseif handle._mcdmHover then
                    handle:SetBackdropColor(0.30, 0.78, 1.00, 0.10)
                    handle:SetBackdropBorderColor(0.30, 0.78, 1.00, 0.92)
                else
                    handle:SetBackdropColor(0.30, 0.78, 1.00, 0.04)
                    handle:SetBackdropBorderColor(0.30, 0.78, 1.00, 0.66)
                end
            end
        end
        local def = selected and DRAG_DEFS[selected]
        frame.selectionText:SetText(def and ("Selected: " .. def.label .. "  |  arrows nudge, Shift=5, Ctrl=10") or "")
    end

    local function SetSelection(kind, skipRefresh)
        frame.selectedPreviewKind = DRAG_DEFS[kind] and kind or nil
        if frame.selectedPreviewKind then ClearTextFocus() end
        if keyCapture then
            keyCapture:SetShown(frame.selectedPreviewKind ~= nil)
            if keyCapture.SetPropagateKeyboardInput then keyCapture:SetPropagateKeyboardInput(frame.selectedPreviewKind == nil) end
            if frame.selectedPreviewKind and keyCapture.SetFocus then keyCapture:SetFocus() end
        end
        SetArrowBindings(frame.selectedPreviewKind ~= nil)
        RefreshSelectionState()
        if not skipRefresh and frame.RefreshPreview then frame:RefreshPreview() end
    end

    function SetPreviewOffsets(kind, x, y, commit)
        local def = DRAG_DEFS[kind]
        if not def then return end
        CDM.db[def.xKey] = UI.RoundToInt(Clamp(x, def.fallbackX, def.minX, def.maxX))
        CDM.db[def.yKey] = UI.RoundToInt(Clamp(y, def.fallbackY, def.minY, def.maxY))
        if commit then SaveAndRefresh() end
        if frame.RefreshPreview then frame:RefreshPreview() end
    end

    local captureParent = UIParent or frame
    local capture = CreateFrame("Frame", nil, captureParent)
    capture:SetAllPoints(captureParent)
    capture:SetFrameStrata("TOOLTIP")
    capture:EnableMouse(true)
    capture:Hide()
    frame.capture = capture

    keyCapture = CreateFrame("Frame", nil, captureParent)
    keyCapture:SetAllPoints(captureParent)
    keyCapture:SetFrameStrata("TOOLTIP")
    keyCapture:SetFrameLevel((capture.GetFrameLevel and capture:GetFrameLevel() or 0) + 1)
    keyCapture:EnableMouse(false)
    keyCapture:EnableKeyboard(true)
    if keyCapture.SetPropagateKeyboardInput then keyCapture:SetPropagateKeyboardInput(true) end
    keyCapture:Hide()
    frame.keyCapture = keyCapture

    local function StopPreviewInteraction(commit)
        local dragged = frame.dragKind
        frame.dragKind = nil
        frame.panning = false
        capture:Hide()
        if dragged and commit then SaveAndRefresh() end
    end

    local function PreviewMouseUpdate()
        if not frame.dragKind and not frame.panning then return end
        local cursorX, cursorY = GetCursorPosition()
        local effectiveScale = (canvas.GetEffectiveScale and canvas:GetEffectiveScale()) or 1
        if effectiveScale <= 0 then effectiveScale = 1 end

        if frame.panning then
            frame.panX = (frame.panStartX or 0) + ((cursorX - (frame.panStartCursorX or cursorX)) / effectiveScale)
            frame.panY = (frame.panStartY or 0) + ((cursorY - (frame.panStartCursorY or cursorY)) / effectiveScale)
            ApplyStageTransform()
            return
        end

        local def = DRAG_DEFS[frame.dragKind]
        if not def then return end
        local zoom = frame.previewZoom or 1
        if zoom <= 0 then zoom = 1 end
        local dx = (cursorX - (frame.dragStartCursorX or cursorX)) / effectiveScale / zoom
        local dy = (cursorY - (frame.dragStartCursorY or cursorY)) / effectiveScale / zoom
        SetPreviewOffsets(frame.dragKind, (frame.dragStartOffsetX or 0) + dx, (frame.dragStartOffsetY or 0) + dy, false)
    end

    capture:SetScript("OnUpdate", PreviewMouseUpdate)
    capture:SetScript("OnMouseUp", function()
        StopPreviewInteraction(true)
    end)

    local function BeginPan()
        StopPreviewInteraction(false)
        local cursorX, cursorY = GetCursorPosition()
        frame.panning = true
        frame.panStartCursorX = cursorX
        frame.panStartCursorY = cursorY
        frame.panStartX = frame.panX or 0
        frame.panStartY = frame.panY or 0
        capture:Show()
    end

    local function BeginElementDrag(kind)
        local def = DRAG_DEFS[kind]
        if not def then return end
        StopPreviewInteraction(false)
        SetSelection(kind, true)
        local cursorX, cursorY = GetCursorPosition()
        frame.dragKind = kind
        frame.dragStartCursorX = cursorX
        frame.dragStartCursorY = cursorY
        frame.dragStartOffsetX = OffsetValue(def, "x")
        frame.dragStartOffsetY = OffsetValue(def, "y")
        capture:Show()
    end

    local function CreatePreviewHandle(kind)
        local handle = CreateFrame("Button", nil, stage, "BackdropTemplate")
        handle.kind = kind
        handle:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        handle:SetFrameLevel((stage:GetFrameLevel() or 0) + 80)
        handle:EnableMouse(true)
        handle:EnableKeyboard(true)
        if handle.SetPropagateKeyboardInput then handle:SetPropagateKeyboardInput(false) end
        handle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        handle:SetScript("OnEnter", function(self)
            self._mcdmHover = true
            RefreshSelectionState()
        end)
        handle:SetScript("OnLeave", function(self)
            self._mcdmHover = nil
            RefreshSelectionState()
        end)
        handle:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" and IsControlKeyDown and IsControlKeyDown() then
                BeginPan()
            elseif button == "LeftButton" then
                BeginElementDrag(kind)
            elseif button == "RightButton" then
                BeginPan()
            end
        end)
        handle:SetScript("OnMouseUp", function()
            StopPreviewInteraction(true)
        end)
        handle:SetScript("OnClick", function(_, button)
            if button == "LeftButton" then SetSelection(kind) end
        end)
        handle:Hide()
        return handle
    end

    frame.previewHandles = {
        resource = CreatePreviewHandle("resource"),
        power = CreatePreviewHandle("power"),
        hp = CreatePreviewHandle("hp"),
    }

    local function PlacePreviewHandle(kind, target, visible)
        local handle = frame.previewHandles and frame.previewHandles[kind]
        if not handle then return end
        if visible and target and target:IsShown() and LayerOn("guides") then
            handle:ClearAllPoints()
            handle:SetPoint("TOPLEFT", target, "TOPLEFT", -13, 13)
            handle:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 13, -13)
            handle:Show()
        else
            handle:Hide()
        end
    end

    canvas:EnableMouse(true)
    canvas:EnableMouseWheel(true)
    canvas:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" or (button == "LeftButton" and IsControlKeyDown and IsControlKeyDown()) then
            BeginPan()
        elseif button == "LeftButton" then
            SetSelection(nil)
        end
    end)
    canvas:SetScript("OnMouseWheel", function(_, delta)
        if not (IsControlKeyDown and IsControlKeyDown()) then return end
        frame.previewZoom = Clamp((frame.previewZoom or 1) + ((delta or 0) > 0 and 0.1 or -0.1), 1, PREVIEW_ZOOM_MIN, PREVIEW_ZOOM_MAX)
        frame:RefreshPreview()
    end)

    local NUDGE_KEYS = {
        LEFT = { -1, 0 },
        LEFTARROW = { -1, 0 },
        RIGHT = { 1, 0 },
        RIGHTARROW = { 1, 0 },
        UP = { 0, 1 },
        UPARROW = { 0, 1 },
        DOWN = { 0, -1 },
        DOWNARROW = { 0, -1 },
    }

    local function HandlePreviewKey(owner, key)
        local delta = NUDGE_KEYS[key]
        local selected = frame.selectedPreviewKind
        if not delta or not selected then
            if owner.SetPropagateKeyboardInput then owner:SetPropagateKeyboardInput(true) end
            return
        end
        local def = DRAG_DEFS[selected]
        if not def then return end
        local step = NudgeStep()
        SetPreviewOffsets(selected, OffsetValue(def, "x") + (delta[1] * step), OffsetValue(def, "y") + (delta[2] * step), true)
        if owner.SetPropagateKeyboardInput then owner:SetPropagateKeyboardInput(false) end
    end

    frame:EnableKeyboard(true)
    if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(true) end
    frame:SetScript("OnKeyDown", HandlePreviewKey)
    frame:SetScript("OnKeyUp", function(self)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
    end)
    canvas:EnableKeyboard(true)
    if canvas.SetPropagateKeyboardInput then canvas:SetPropagateKeyboardInput(true) end
    canvas:SetScript("OnKeyDown", HandlePreviewKey)
    canvas:SetScript("OnKeyUp", function(self)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
    end)
    keyCapture:SetScript("OnKeyDown", HandlePreviewKey)
    keyCapture:SetScript("OnKeyUp", function(self)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(frame.selectedPreviewKind == nil) end
    end)
    for _, handle in pairs(frame.previewHandles) do
        handle:SetScript("OnKeyDown", HandlePreviewKey)
        handle:SetScript("OnKeyUp", function(self)
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
        end)
    end

    local function SetMeterBorder(meter, visible, outlineKey)
        if not meter or not meter.border then return end
        if visible then
            local key = outlineKey or "resourceOutline"
            meter.border:SetBoxColor(0, 0, 0, 0.90)
            meter.border:Place(meter, Clamp(CDM.db[key] or CDM.defaults[key] or 1, 1, 0, 8), 1)
        else
            meter.border:Hide()
        end
    end

    local function CurrentAnimatedValue(spec)
        if not frame.animating then return spec.value end
        local t = tonumber(frame.animationElapsed) or 0
        local wave = (math.sin(t * 1.85) + 1) * 0.5
        if spec.mode == "continuous" or spec.mode == "timer" then
            return 0.12 + (wave * 0.84)
        end
        return max(0, min(spec.segments or 1, floor((spec.segments or 1) * wave + 0.5)))
    end

    local function PreviewClampWidth(width, fallback)
        width = tonumber(width) or tonumber(fallback) or 220
        if width < 90 then return 90 end
        if width > 560 then return 560 end
        return width
    end

    local function PreviewFrameWidth(sourceFrame)
        if not (sourceFrame and sourceFrame.GetWidth) then return nil end
        local width = tonumber(sourceFrame:GetWidth())
        return width and width > 1 and width or nil
    end

    local function PreviewIconGroupWidth(group)
        if type(group) ~= "table" then return nil end
        local spells = group.spells
        local count = type(spells) == "table" and #spells or 0
        if count <= 0 then count = 1 end
        local iconW = tonumber(group.iconWidth or group.width) or 30
        local spacing = tonumber(group.spacing) or 1
        local maxPerRow = tonumber(group.maxPerRow) or count
        if maxPerRow <= 0 or maxPerRow > count then maxPerRow = count end
        return (iconW * maxPerRow) + (max(0, maxPerRow - 1) * spacing)
    end

    local function PreviewBarGroupWidth(group)
        if type(group) ~= "table" then return nil end
        local width = tonumber(group.barWidth or group.width)
        if not width or width <= 0 then
            width = CDM.CalculateEssentialRow1Width and CDM.CalculateEssentialRow1Width() or nil
        end
        if width and CDM.IsBarCenterGrow and CDM.IsBarCenterGrow(group.grow) then
            local limit = tonumber(group.wrapLimit) or 2
            if limit < 2 then limit = 2 elseif limit > 5 then limit = 5 end
            local spacing = tonumber(group.hSpacing) or 1
            width = (limit * width) + ((limit - 1) * spacing)
        end
        return width
    end

    local function PreviewGroupWidth(mode, sourceIndex)
        local index = tonumber(sourceIndex) or 1
        if index < 1 then index = 1 end
        local sets = WidthGroupSets(mode)
        local containers = mode == "cooldownGroup" and CDM.cooldownGroupContainers
            or mode == "buffGroup" and CDM.buffGroupContainers
            or mode == "barGroup" and CDM.barGroupContainers
            or nil
        local frameWidth = PreviewFrameWidth(containers and containers[index])
        if frameWidth then return frameWidth end
        local group = sets and sets.groups and sets.groups[index]
        return mode == "barGroup" and PreviewBarGroupWidth(group) or PreviewIconGroupWidth(group)
    end

    local function PreviewAnchorWidth(mode)
        local viewers = CDM.CONST and CDM.CONST.VIEWERS
        local anchors = CDM.anchorContainers
        if mode == "essential" then
            return PreviewFrameWidth(anchors and viewers and anchors[viewers.ESSENTIAL])
                or (CDM.CalculateEssentialRow1Width and CDM.CalculateEssentialRow1Width())
                or PreviewFrameWidth(ref)
        elseif mode == "utility" then
            return PreviewFrameWidth(anchors and viewers and anchors[viewers.UTILITY])
        elseif mode == "buffs" then
            return PreviewFrameWidth(anchors and viewers and anchors[viewers.BUFF])
        elseif mode == "buffbars" then
            return PreviewFrameWidth(anchors and viewers and anchors[viewers.BUFF_BAR])
        end
        return nil
    end

    local function PreviewWidth(widthKey, modeKey, indexKey, fallback, classWidth)
        local manual = PreviewClampWidth(ReadValue(widthKey, fallback), fallback)
        local mode = NormalizeWidthSource(ReadValue(modeKey, "free"), classWidth ~= nil)
        local sourceWidth
        if mode == "class" then
            sourceWidth = classWidth
        elseif WIDTH_GROUP_SOURCE[mode] then
            sourceWidth = PreviewGroupWidth(mode, ReadValue(indexKey, 1))
        else
            sourceWidth = PreviewAnchorWidth(mode)
        end
        return sourceWidth and PreviewClampWidth(sourceWidth, manual) or manual
    end

    local function RenderResource(spec)
        local classEnabled = ReadBool("resourceClassEnabled")
        local hasResource = classEnabled and spec and not spec.noResource and spec.mode ~= "none"
        frame.layerAvailability.resource = hasResource
        frame.layerAvailability.resourceText = hasResource and CDM.db.resourceShowText == true
        frame.noResource:SetShown(not hasResource)
        if not hasResource then
            resource:Hide()
            if resource.border then resource.border:Hide() end
            frame.bounds.resource:Hide()
            frame.guides.resource:Hide()
            PlacePreviewHandle("resource", resource, false)
            return false
        end

        local count = max(1, min(10, tonumber(spec.segments) or 1))
        local mode = spec.mode or "segmented"
        local continuous = mode == "continuous" or mode == "timer" or mode == "single"
        local width = PreviewWidth("resourceWidth", "resourceWidthMode", "resourceWidthSourceIndex", 220)
        local height = max(2, tonumber(CDM.db.resourceHeight) or 8)
        local gap = max(0, tonumber(CDM.db.resourceGap) or 1)
        local value = CurrentAnimatedValue(spec)
        local r, g, b = PreviewOverrideColor(spec.token, "resourceColorOverrides", spec.classToken)
        local chargedR, chargedG, chargedB = PreviewOverrideColor("CHARGED", "resourceColorOverrides", nil, { 0.60, 0.20, 0.80, 1 })
        local bgR, bgG, bgB, bgA = DBColor("resourceBackgroundColor", { r = 0, g = 0, b = 0, a = 0.35 })
        local fgPath = ResolveStatusbarTexture(ReadMediaValue("resourceTexture", "Solid"), WHITE)
        local bgPath = ResolveStatusbarTexture(ReadMediaValue("resourceBgTexture", ""), fgPath)

        if continuous then count = 1 end
        resource:SetSize(width, height)
        resource:ClearAllPoints()
        resource:SetPoint("BOTTOM", ref, "TOP", tonumber(CDM.db.resourceOffsetX) or 0, PREVIEW_RESOURCE_BASE_Y + (tonumber(ReadValue("resourceOffsetY", 18)) or 18))
        resource:SetShown(LayerOn("resource"))
        SetMeterBorder(resource, LayerOn("resource") and LayerOn("border"), "resourceOutline")

        local barW = continuous and width or ((width - ((count - 1) * gap)) / count)
        if barW < 1 then barW = 1 end
        for i = 1, 10 do
            local bar = resource.bars[i]
            if i <= count and LayerOn("resource") then
                bar:ClearAllPoints()
                bar:SetSize(barW, height)
                bar:SetPoint("LEFT", resource, "LEFT", (i - 1) * (barW + gap), 0)
                bar:SetStatusBarTexture(fgPath)
                bar.bg:SetTexture(bgPath)
                local charged = spec.token == "COMBO_POINTS"
                    and ReadBool("resourceShowChargedComboPoints")
                    and spec.chargedSlots
                    and spec.chargedSlots[i] == true
                bar:SetStatusBarColor(charged and chargedR or r, charged and chargedG or g, charged and chargedB or b, 1)
                if charged and not (i <= value) then
                    bar.bg:SetVertexColor(max(chargedR * 0.45, 0.05), max(chargedG * 0.45, 0.05), max(chargedB * 0.45, 0.05), 1)
                else
                    bar.bg:SetVertexColor(bgR, bgG, bgB, bgA)
                end
                bar:SetMinMaxValues(0, 1)
                if continuous then
                    bar:SetValue(max(0, min(1, tonumber(value) or 0)))
                    bar:SetAlpha(1)
                elseif mode == "fractional" then
                    local full = floor(value)
                    local part = value - full
                    bar:SetValue(i <= full and 1 or (i == full + 1 and part or 0))
                    bar:SetAlpha(i <= full or i == full + 1 and part > 0 and 1 or 0.30)
                else
                    bar:SetValue(i <= value and 1 or 0)
                    bar:SetAlpha(i <= value and 1 or 0.30)
                end
                if bar.border then bar.border:Hide() end
                bar.text:SetShown(mode == "rune" and CDM.db.resourceRuneShowTime ~= false and i > value and LayerOn("resourceText"))
                if bar.text:IsShown() then bar.text:SetText(string.format("%.1f", 6 - i + 0.3)) end
                bar:Show()
            else
                bar:Hide()
            end
        end

        resource.text:SetShown(LayerOn("resourceText"))
        resource.text:SetText(spec.previewText or tostring(value))
        frame.bounds.resource:SetShown(false)
        frame.guides.resource:SetShown(false)
        if LayerOn("bounds") and LayerOn("resource") then frame.bounds.resource:Place(resource, 7, 1) end
        if LayerOn("guides") and LayerOn("resource") then frame.guides.resource:Place(resource, 13, 1) end
        PlacePreviewHandle("resource", resource, LayerOn("resource"))
        return true
    end

    local function RenderPower(resourceShown)
        local show = ReadBool("resourcePowerBarEnabled")
        frame.layerAvailability.power = show
        frame.layerAvailability.powerText = show and tostring(CDM.db.resourcePowerBarTextMode or "PERCENT"):upper() ~= "NONE"
        if not show then
            power:Hide()
            frame.bounds.power:Hide()
            frame.guides.power:Hide()
            PlacePreviewHandle("power", power, false)
            return false
        end
        local width = PreviewWidth("resourcePowerBarWidth", "resourcePowerBarWidthMode", "resourcePowerBarWidthSourceIndex", 220, resourceShown and PreviewFrameWidth(resource) or nil)
        local height = max(2, tonumber(CDM.db.resourcePowerBarHeight) or 8)
        local value = frame.animating and (0.22 + ((math.sin((frame.animationElapsed or 0) * 1.25) + 1) * 0.35)) or 0.66
        local pType = UnitPowerType and UnitPowerType("player") or 0
        local token = (pType == 3 and "ENERGY") or (pType == 1 and "RAGE") or "MANA"
        local r, g, b = PreviewOverrideColor(token, "resourcePowerBarColorOverrides", nil, { 0.20, 0.58, 1.00 })
        local bgR, bgG, bgB, bgA = DBColor("resourcePowerBarBackgroundColor", { r = 0, g = 0, b = 0, a = 0.35 })
        local fgPath = ResolveStatusbarTexture(ReadMediaValue("resourcePowerBarTexture", "Solid"), WHITE)
        local bgPath = ResolveStatusbarTexture(ReadMediaValue("resourcePowerBarBgTexture", ""), fgPath)
        power:SetSize(width, height)
        power:ClearAllPoints()
        if resourceShown then
            power:SetPoint("TOP", resource, "BOTTOM", tonumber(CDM.db.resourcePowerBarOffsetX) or 0, tonumber(CDM.db.resourcePowerBarOffsetY) or -4)
        else
            power:SetPoint("TOP", ref, "BOTTOM", tonumber(CDM.db.resourcePowerBarOffsetX) or 0, -18 + (tonumber(CDM.db.resourcePowerBarOffsetY) or -4))
        end
        power:SetMinMaxValues(0, 1)
        power:SetValue(value)
        power:SetStatusBarTexture(fgPath)
        power.bg:SetTexture(bgPath)
        power:SetStatusBarColor(r, g, b, 1)
        power.bg:SetVertexColor(bgR, bgG, bgB, bgA)
        power.text:SetShown(LayerOn("powerText"))
        power.text:SetText(floor(value * 100 + 0.5) .. "%")
        power:SetShown(LayerOn("power"))
        SetMeterBorder(power, LayerOn("border"), "resourcePowerBarOutline")
        if LayerOn("bounds") and LayerOn("power") then frame.bounds.power:Place(power, 7, 1) else frame.bounds.power:Hide() end
        if LayerOn("guides") and LayerOn("power") then frame.guides.power:Place(power, 13, 1) else frame.guides.power:Hide() end
        PlacePreviewHandle("power", power, LayerOn("power"))
        return true
    end

    local function RenderHP(powerShown, resourceShown)
        local show = ReadBool("resourceHPBarEnabled")
        frame.layerAvailability.hp = show
        frame.layerAvailability.hpText = show and tostring(CDM.db.resourceHPBarTextMode or "PERCENT"):upper() ~= "NONE"
        if not show then
            hp:Hide()
            frame.bounds.hp:Hide()
            frame.guides.hp:Hide()
            PlacePreviewHandle("hp", hp, false)
            return false
        end
        local width = PreviewWidth("resourceHPBarWidth", "resourceHPBarWidthMode", "resourceHPBarWidthSourceIndex", 220, resourceShown and PreviewFrameWidth(resource) or nil)
        local height = max(2, tonumber(CDM.db.resourceHPBarHeight) or 6)
        local value = frame.animating and (0.36 + ((math.sin((frame.animationElapsed or 0) * 0.85) + 1) * 0.28)) or 0.82
        local r, g, b = PreviewHPColor(value)
        local bgR, bgG, bgB, bgA = DBColor("resourceHPBarBackgroundColor", { r = 0, g = 0, b = 0, a = 0.35 })
        local fgPath = ResolveStatusbarTexture(ReadMediaValue("resourceHPBarTexture", "Solid"), WHITE)
        local bgPath = ResolveStatusbarTexture(ReadMediaValue("resourceHPBarBgTexture", ""), fgPath)
        hp:SetSize(width, height)
        hp:ClearAllPoints()
        local hpOffsetY = tonumber(CDM.db.resourceHPBarOffsetY) or -18
        if powerShown then
            hp:SetPoint("TOP", power, "BOTTOM", tonumber(CDM.db.resourceHPBarOffsetX) or 0, hpOffsetY)
        elseif resourceShown then
            hp:SetPoint("TOP", resource, "BOTTOM", tonumber(CDM.db.resourceHPBarOffsetX) or 0, hpOffsetY)
        else
            hp:SetPoint("TOP", ref, "BOTTOM", tonumber(CDM.db.resourceHPBarOffsetX) or 0, hpOffsetY)
        end
        hp:SetMinMaxValues(0, 1)
        hp:SetValue(value)
        hp:SetStatusBarTexture(fgPath)
        hp.bg:SetTexture(bgPath)
        hp:SetStatusBarColor(r, g, b, 1)
        hp.bg:SetVertexColor(bgR, bgG, bgB, bgA)
        hp.text:SetShown(LayerOn("hpText"))
        hp.text:SetText(floor(value * 100 + 0.5) .. "%")
        hp:SetShown(LayerOn("hp"))
        SetMeterBorder(hp, LayerOn("border"), "resourceHPBarOutline")
        if LayerOn("bounds") and LayerOn("hp") then frame.bounds.hp:Place(hp, 7, 1) else frame.bounds.hp:Hide() end
        if LayerOn("guides") and LayerOn("hp") then frame.guides.hp:Place(hp, 13, 1) else frame.guides.hp:Hide() end
        PlacePreviewHandle("hp", hp, LayerOn("hp"))
        return true
    end

    function frame:RefreshPreview()
        local spec = self.previewKey == "current" and ResolveCurrentSpec() or PREVIEW_SPEC_BY_KEY[self.previewKey] or ResolveCurrentSpec()
        ApplyStageTransform()
        if self.animateButton and self.animateButton.SetText then self.animateButton:SetText(self.animating and "Stop" or "Animate") end

        frame.layerAvailability.guides = true
        frame.layerAvailability.border = true
        frame.layerAvailability.reference = true
        frame.layerAvailability.bounds = true

        ref:SetShown(LayerOn("reference"))
        ref.label:SetText((spec and spec.label) or "Player frame reference")
        if LayerOn("bounds") and LayerOn("reference") then frame.bounds.reference:Place(ref, 7, 1) else frame.bounds.reference:Hide() end

        local resourceShown = RenderResource(spec)
        local powerShown = RenderPower(resourceShown)
        local hpShown = RenderHP(powerShown, resourceShown)
        RefreshSelectionState()

        local parts = {}
        if resourceShown then parts[#parts + 1] = "Class Resource" end
        if powerShown then parts[#parts + 1] = "Player Power" end
        if hpShown then parts[#parts + 1] = "Second HP" end
        self.summary:SetText("Shown here: " .. (#parts > 0 and table.concat(parts, " + ") or "Player frame reference only") ..
            "   token=" .. tostring(spec and spec.token or "none") ..
            "   HP default: off   Extra mana bar: excluded")
        RefreshLayerButtons()
    end

    frame:SetScript("OnUpdate", function(self, elapsed)
        if not self.animating then return end
        self.animationElapsed = (self.animationElapsed or 0) + (tonumber(elapsed) or 0)
        self.animationAccum = (self.animationAccum or 0) + (tonumber(elapsed) or 0)
        if self.animationAccum < 0.033 then return end
        self.animationAccum = 0
        self:RefreshPreview()
    end)
    frame:SetScript("OnHide", function(self)
        StopPreviewInteraction(true)
        SetSelection(nil, true)
        self.animating = false
        self.animationElapsed = 0
    end)

    frame:RefreshPreview()
    return frame
end

local function CreateResourcesTab(page)
    local scrollChild, scrollFrame = UI.CreateScrollableTab(page, "MidnightCDM_ResourcesScrollFrame", 1450, 980)
    local scrollFrameChild = scrollFrame:GetScrollChild()

    local header = UI.CreateHeader(scrollChild, "Class Resources")
    header:SetPoint("TOPLEFT", 0, 0)

    local preview = CreatePreview(scrollChild)
    preview:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12)

    local sections = {}
    local function Relayout()
        UI.LayoutAccordionSections(sections, -460, 8)
        local total = 460
        for _, section in ipairs(sections) do
            total = total + section:GetEffectiveHeight() + 8
        end
        UI.FinalizeScroll(scrollFrameChild, scrollChild, -total)
        preview:RefreshPreview()
    end

    local function AddSection(title, key, height, defaultOpen)
        local section, body = UI.CreateAccordionSection(scrollChild, title, 700, height, "resources:" .. key, defaultOpen, Relayout)
        sections[#sections + 1] = section
        return section, body
    end

    local function AddColorRow(parent, labelText, key, yValue)
        local label = parent:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
        label:SetPoint("TOPLEFT", 0, yValue)
        label:SetText(labelText)
        UI.SetTextSubtle(label)

        local picker = UI.CreateSimpleColorPicker(parent, CDM.db[key] or CDM.defaults[key], function(r, g, b, a)
            CDM.db[key] = { r = r, g = g, b = b, a = a or 1 }
            SaveAndRefresh()
            preview:RefreshPreview()
        end, true)
        picker:SetPoint("LEFT", label, "LEFT", 180, 0)
        return yValue - 30
    end

    local function AddStatusbarTextureRow(parent, labelText, key, yValue, emptyLabel)
        local label = parent:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
        label:SetPoint("TOPLEFT", 0, yValue)
        label:SetText(labelText)
        UI.SetTextSubtle(label)

        local dropdown = UI.CreateDropdown(parent, 220)
        dropdown._mcdmEmptyMediaLabel = emptyLabel
        UI.SetupMediaDropdown(dropdown, "statusbar", function()
            return ReadMediaValue(key, emptyLabel and "" or "Solid")
        end, function(value)
            CDM.db[key] = value
            SaveAndRefresh()
            preview:RefreshPreview()
        end)
        dropdown:SetPoint("LEFT", label, "LEFT", 180, 0)
        return yValue - 38
    end

    local function AddOverrideColorRow(parent, labelText, overrideKey, token, fallback, xValue, yValue)
        local label = parent:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
        label:SetPoint("TOPLEFT", xValue, yValue)
        label:SetText(labelText)
        UI.SetTextSubtle(label)

        local override = GetOverrideColor(overrideKey, token)
        local fallbackR, fallbackG, fallbackB, fallbackA = TokenFallbackColor(token, nil, fallback)
        local color = ColorFromTable(override, { r = fallbackR, g = fallbackG, b = fallbackB, a = fallbackA })
        local picker = UI.CreateSimpleColorPicker(parent, color, function(r, g, b, a)
            local tbl = GetOverrideTable(overrideKey)
            tbl[token] = { r = r, g = g, b = b, a = a or 1 }
            SaveAndRefresh()
            preview:RefreshPreview()
        end, true)
        picker:SetPoint("LEFT", label, "LEFT", 170, 0)

        return picker
    end

    local function BuildOverrideColorPage(parent, title, bgKey, overrideKey, rows)
        local intro = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        intro:SetPoint("TOPLEFT", 4, -2)
        intro:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
        intro:SetJustifyH("LEFT")
        intro:SetText(title)
        UI.SetTextSubtle(intro)

        local yStart = -34
        AddColorRow(parent, "Background Color", bgKey, yStart)
        yStart = yStart - 42

        local colW = 330
        local rowH = 31
        for i, def in ipairs(rows) do
            local index = i - 1
            local col = index % 2
            local row = floor(index / 2)
            AddOverrideColorRow(parent, def.label, overrideKey, def.token, def.fallback, 4 + (col * colW), yStart - (row * rowH))
        end
    end

    local function BuildHPColorPage(parent)
        local label = parent:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
        label:SetText("Color Mode")
        UI.SetTextSubtle(label)
        label:SetPoint("TOPLEFT", 4, -4)
        local dd = UI.CreateDropdown(parent, 170)
        UI.SetupValueDropdown(dd, HP_COLOR_MODES, function()
            return CDM.db.resourceHPBarColorMode or CDM.defaults.resourceHPBarColorMode
        end, function(value, labelText)
            CDM.db.resourceHPBarColorMode = value
            dd:SetDefaultText(labelText or value)
            SaveAndRefresh()
            preview:RefreshPreview()
        end)
        local currentMode = CDM.db.resourceHPBarColorMode or CDM.defaults.resourceHPBarColorMode
        dd:SetDefaultText(UI.GetOptionLabel(HP_COLOR_MODES, currentMode, tostring(currentMode or "")))
        dd:SetPoint("LEFT", label, "RIGHT", 16, 0)

        local yValue = -46
        yValue = AddColorRow(parent, "Custom Color", "resourceHPBarColor", yValue)
        yValue = AddColorRow(parent, "Global Color", "resourceHPBarGlobalColor", yValue)
        yValue = AddColorRow(parent, "Dark Color", "resourceHPBarDarkColor", yValue)
        yValue = AddColorRow(parent, "Gradient Low", "resourceHPBarGradientLow", yValue)
        yValue = AddColorRow(parent, "Gradient Mid", "resourceHPBarGradientMid", yValue)
        yValue = AddColorRow(parent, "Gradient High", "resourceHPBarGradientHigh", yValue)
        AddColorRow(parent, "Background Color", "resourceHPBarBackgroundColor", yValue)
    end

    local function BuildColorPage(parent, tabInfo)
        if tabInfo.id == "class" then
            BuildOverrideColorPage(parent, "Override class-resource colors. Empty defaults use Blizzard PowerBarColor where available.", "resourceBackgroundColor", "resourceColorOverrides", CLASS_RESOURCE_COLOR_ROWS)
        elseif tabInfo.id == "power" then
            BuildOverrideColorPage(parent, "Override Player Power bar colors. Empty defaults use Blizzard PowerBarColor where available.", "resourcePowerBarBackgroundColor", "resourcePowerBarColorOverrides", POWER_BAR_COLOR_ROWS)
        elseif tabInfo.id == "hp" then
            BuildHPColorPage(parent)
        end
    end

    local function BuildLoadConditionPage(parent, tabInfo)
        local intro = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        intro:SetPoint("TOPLEFT", 4, -2)
        intro:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
        intro:SetJustifyH("LEFT")
        intro:SetText("Hide this element when one of the selected states is active.")
        UI.SetTextSubtle(intro)

        local colW = 218
        for i, spec in ipairs(LOAD_CONDITIONS) do
            local col = (i - 1) % 3
            local row = floor((i - 1) / 3)
            local legacyKey = tabInfo.legacyOOC and spec.suffix == "HideOutOfCombat" and tabInfo.legacyOOC or nil
            local cb = UI.CreateModernCheckbox(parent, spec.label, ReadLoadCondition(tabInfo.prefix, spec.suffix, legacyKey), function(checked)
                SetLoadCondition(tabInfo.prefix, spec.suffix, checked)
            end)
            cb:SetSize(colW - 12, 26)
            cb:SetPoint("TOPLEFT", 4 + (col * colW), -34 - (row * 31))
        end
    end

    local classSection, classBody = AddSection("Class Resource Bar", "class", 310, true)
    local y = 0

    local classEnabled = UI.CreateModernCheckbox(classBody, "Enable Class Resources", ReadBool("resourceClassEnabled"), function(checked)
        CDM.db.resourceClassEnabled = checked
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    classEnabled:SetPoint("TOPLEFT", 0, y)
    y = y - 34

    local showText = UI.CreateModernCheckbox(classBody, "Show Resource Text", CDM.db.resourceShowText == true, function(checked)
        CDM.db.resourceShowText = checked
        SaveAndRefresh()
    end)
    showText:SetPoint("TOPLEFT", 0, y)
    y = y - 34

    local runeText = UI.CreateModernCheckbox(classBody, "Show Rune Recharge Text", CDM.db.resourceRuneShowTime ~= false, function(checked)
        CDM.db.resourceRuneShowTime = checked
        SaveAndRefresh()
    end)
    runeText:SetPoint("TOPLEFT", 0, y)
    y = y - 34

    local reverse = UI.CreateModernCheckbox(classBody, "Reverse Fill", CDM.db.resourceFillReverse == true, function(checked)
        CDM.db.resourceFillReverse = checked
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    reverse:SetPoint("TOPLEFT", 0, y)
    y = y - 42

    y = AddStatusbarTextureRow(classBody, "Texture", "resourceTexture", y)
    y = AddStatusbarTextureRow(classBody, "Background Texture", "resourceBgTexture", y, "Inherit Foreground")
    y = y - 6

    y = AddWidthSourceRows(classBody, y, "resourceWidthMode", "resourceWidthSourceIndex", false, function()
        preview:RefreshPreview()
    end)

    local width = UI.CreateModernSlider(classBody, "Free Width", 40, 800, CDM.db.resourceWidth or 220, function(v)
        CDM.db.resourceWidth = UI.RoundToInt(v)
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    width:SetPoint("TOPLEFT", 0, y)
    y = y - 45

    local height = UI.CreateModernSlider(classBody, "Height", 2, 40, CDM.db.resourceHeight or 8, function(v)
        CDM.db.resourceHeight = UI.RoundToInt(v)
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    height:SetPoint("TOPLEFT", 0, y)
    y = y - 45

    local gap = UI.CreateModernSlider(classBody, "Gap", 0, 16, CDM.db.resourceGap or 1, function(v)
        CDM.db.resourceGap = UI.RoundToInt(v)
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    gap:SetPoint("TOPLEFT", 0, y)
    y = y - 45

    classSection:SetContentHeight(math.abs(y) + 4)

    local outlineSection, outlineBody = AddSection("Outline", "outline", 168, false)
    y = 0
    local resourceOutline = UI.CreateModernSlider(outlineBody, "Class Resource", 0, 8, CDM.db.resourceOutline or CDM.defaults.resourceOutline or 1, function(v)
        CDM.db.resourceOutline = UI.RoundToInt(v)
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    resourceOutline:SetPoint("TOPLEFT", 0, y)
    y = y - 45

    local powerOutline = UI.CreateModernSlider(outlineBody, "Player Power", 0, 8, CDM.db.resourcePowerBarOutline or CDM.defaults.resourcePowerBarOutline or 1, function(v)
        CDM.db.resourcePowerBarOutline = UI.RoundToInt(v)
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    powerOutline:SetPoint("TOPLEFT", 0, y)
    y = y - 45

    local hpOutline = UI.CreateModernSlider(outlineBody, "Second HP", 0, 8, CDM.db.resourceHPBarOutline or CDM.defaults.resourceHPBarOutline or 1, function(v)
        CDM.db.resourceHPBarOutline = UI.RoundToInt(v)
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    hpOutline:SetPoint("TOPLEFT", 0, y)
    y = y - 45
    outlineSection:SetContentHeight(math.abs(y) + 4)

    local colorSection, colorBody = AddSection("Colors", "colors", 356, false)
    local colorTabs = UI.CreateSubTabBar(colorBody, RESOURCE_COLOR_TABS, "class")
    for _, tabInfo in ipairs(RESOURCE_COLOR_TABS) do
        BuildColorPage(colorTabs.subPages[tabInfo.id], tabInfo)
    end
    colorSection:SetContentHeight(356)

    local behaviorSection, behaviorBody = AddSection("Behavior", "behavior", 230, false)
    y = 0
    local defs = {
        { key = "resourceHideWhenFull", label = "Hide When Full" },
        { key = "resourceHideWhenEmpty", label = "Hide When Empty" },
        { key = "resourceShowStagger", label = "Show Brewmaster Stagger" },
        { key = "resourceShowEbonMight", label = "Show Augmentation Ebon Might" },
        { key = "resourceShowEleMaelstrom", label = "Show Elemental Maelstrom" },
        { key = "resourceShowShadowInsanity", label = "Show Shadow Insanity" },
        { key = "resourceShowChargedComboPoints", label = "Show Empowered Combo Points" },
    }
    for _, def in ipairs(defs) do
        local cb = UI.CreateModernCheckbox(behaviorBody, def.label, CDM.db[def.key] == true or (CDM.db[def.key] == nil and CDM.defaults[def.key] == true), function(checked)
            CDM.db[def.key] = checked
            SaveAndRefresh()
        end)
        cb:SetPoint("TOPLEFT", 0, y)
        y = y - 30
    end
    behaviorSection:SetContentHeight(math.abs(y) + 4)

    local loadSection, loadBody = AddSection("Load Conditions", "load", 258, false)
    local loadTabs = UI.CreateSubTabBar(loadBody, LOAD_CONDITION_TABS, "class")
    for _, tabInfo in ipairs(LOAD_CONDITION_TABS) do
        BuildLoadConditionPage(loadTabs.subPages[tabInfo.id], tabInfo)
    end
    loadSection:SetContentHeight(258)

    local anchorSection, anchorBody = AddSection("Layout", "layout", 280, false)
    y = 0
    local label, dd = CreateDropdown(anchorBody, "Anchor Target", 210, ANCHOR_TARGETS, "resourceAnchorTarget")
    label:SetPoint("TOPLEFT", 0, y)
    dd:SetPoint("LEFT", label, "RIGHT", 16, 0)
    y = y - 38

    label, dd = CreateDropdown(anchorBody, "Anchor Point", 160, (function()
        local opts = {}
        for _, pos in ipairs(UI.PositionOptions) do opts[#opts + 1] = { label = pos, value = pos } end
        return opts
    end)(), "resourceAnchorPoint")
    label:SetPoint("TOPLEFT", 0, y)
    dd:SetPoint("LEFT", label, "RIGHT", 16, 0)
    y = y - 38

    label, dd = CreateDropdown(anchorBody, "Relative Point", 160, (function()
        local opts = {}
        for _, pos in ipairs(UI.PositionOptions) do opts[#opts + 1] = { label = pos, value = pos } end
        return opts
    end)(), "resourceRelativePoint")
    label:SetPoint("TOPLEFT", 0, y)
    dd:SetPoint("LEFT", label, "RIGHT", 16, 0)
    y = y - 45

    local xSlider = UI.CreateModernSlider(anchorBody, "X Offset", -800, 800, CDM.db.resourceOffsetX or 0, function(v)
        CDM.db.resourceOffsetX = UI.RoundToInt(v)
        SaveAndRefresh()
    end)
    xSlider:SetPoint("TOPLEFT", 0, y)
    y = y - 45

    local ySlider = UI.CreateModernSlider(anchorBody, "Y Offset", -800, 800, CDM.db.resourceOffsetY or CDM.defaults.resourceOffsetY or 18, function(v)
        CDM.db.resourceOffsetY = UI.RoundToInt(v)
        SaveAndRefresh()
    end)
    ySlider:SetPoint("TOPLEFT", 0, y)
    y = y - 45
    anchorSection:SetContentHeight(math.abs(y) + 4)

    local powerSection, powerBody = AddSection("Player Power Bar", "power", 250, true)
    y = 0
    local powerEnabled = UI.CreateModernCheckbox(powerBody, "Enable Player Power Bar", ReadBool("resourcePowerBarEnabled"), function(checked)
        CDM.db.resourcePowerBarEnabled = checked
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    powerEnabled:SetPoint("TOPLEFT", 0, y)
    y = y - 38
    local powerSmooth = UI.CreateModernCheckbox(powerBody, "Smooth Fill", ReadBool("resourcePowerBarSmooth"), function(checked)
        CDM.db.resourcePowerBarSmooth = checked
        SaveAndRefresh()
    end)
    powerSmooth:SetPoint("TOPLEFT", 0, y)
    y = y - 38
    y = AddStatusbarTextureRow(powerBody, "Texture", "resourcePowerBarTexture", y)
    y = AddStatusbarTextureRow(powerBody, "Background Texture", "resourcePowerBarBgTexture", y, "Inherit Foreground")
    y = y - 6
    y = AddWidthSourceRows(powerBody, y, "resourcePowerBarWidthMode", "resourcePowerBarWidthSourceIndex", true, function()
        preview:RefreshPreview()
    end)

    local pw = UI.CreateModernSlider(powerBody, "Free Width", 40, 800, CDM.db.resourcePowerBarWidth or 220, function(v)
        CDM.db.resourcePowerBarWidth = UI.RoundToInt(v)
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    pw:SetPoint("TOPLEFT", 0, y)
    y = y - 45
    local ph = UI.CreateModernSlider(powerBody, "Height", 2, 40, CDM.db.resourcePowerBarHeight or 8, function(v)
        CDM.db.resourcePowerBarHeight = UI.RoundToInt(v)
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    ph:SetPoint("TOPLEFT", 0, y)
    y = y - 45
    label, dd = CreateDropdown(powerBody, "Text", 170, TEXT_MODES, "resourcePowerBarTextMode")
    label:SetPoint("TOPLEFT", 0, y)
    dd:SetPoint("LEFT", label, "RIGHT", 16, 0)
    y = y - 38
    label, dd = CreateDropdown(powerBody, "Anchor Target", 210, AUX_ANCHOR_TARGETS, "resourcePowerBarAnchorTarget")
    label:SetPoint("TOPLEFT", 0, y)
    dd:SetPoint("LEFT", label, "RIGHT", 16, 0)
    y = y - 45
    local po = UI.CreateModernSlider(powerBody, "Y Offset", -200, 200, CDM.db.resourcePowerBarOffsetY or CDM.defaults.resourcePowerBarOffsetY or -4, function(v)
        CDM.db.resourcePowerBarOffsetY = UI.RoundToInt(v)
        SaveAndRefresh()
    end)
    po:SetPoint("TOPLEFT", 0, y)
    y = y - 45
    powerSection:SetContentHeight(math.abs(y) + 4)

    local hpSection, hpBody = AddSection("Second Player HP Bar", "hp", 300, false)
    y = 0
    local hpEnabled = UI.CreateModernCheckbox(hpBody, "Enable Second Player HP Bar", ReadBool("resourceHPBarEnabled"), function(checked)
        CDM.db.resourceHPBarEnabled = checked
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    hpEnabled:SetPoint("TOPLEFT", 0, y)
    y = y - 38
    y = AddStatusbarTextureRow(hpBody, "Texture", "resourceHPBarTexture", y)
    y = AddStatusbarTextureRow(hpBody, "Background Texture", "resourceHPBarBgTexture", y, "Inherit Foreground")
    y = y - 6
    y = AddWidthSourceRows(hpBody, y, "resourceHPBarWidthMode", "resourceHPBarWidthSourceIndex", true, function()
        preview:RefreshPreview()
    end)

    local hw = UI.CreateModernSlider(hpBody, "Free Width", 40, 800, CDM.db.resourceHPBarWidth or 220, function(v)
        CDM.db.resourceHPBarWidth = UI.RoundToInt(v)
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    hw:SetPoint("TOPLEFT", 0, y)
    y = y - 45
    local hh = UI.CreateModernSlider(hpBody, "Height", 2, 40, CDM.db.resourceHPBarHeight or 6, function(v)
        CDM.db.resourceHPBarHeight = UI.RoundToInt(v)
        SaveAndRefresh()
        preview:RefreshPreview()
    end)
    hh:SetPoint("TOPLEFT", 0, y)
    y = y - 45
    label, dd = CreateDropdown(hpBody, "Text", 170, TEXT_MODES, "resourceHPBarTextMode")
    label:SetPoint("TOPLEFT", 0, y)
    dd:SetPoint("LEFT", label, "RIGHT", 16, 0)
    y = y - 38
    label, dd = CreateDropdown(hpBody, "Anchor Target", 210, AUX_ANCHOR_TARGETS, "resourceHPBarAnchorTarget")
    label:SetPoint("TOPLEFT", 0, y)
    dd:SetPoint("LEFT", label, "RIGHT", 16, 0)
    y = y - 45
    local ho = UI.CreateModernSlider(hpBody, "Y Offset", -200, 200, CDM.db.resourceHPBarOffsetY or CDM.defaults.resourceHPBarOffsetY or -18, function(v)
        CDM.db.resourceHPBarOffsetY = UI.RoundToInt(v)
        SaveAndRefresh()
    end)
    ho:SetPoint("TOPLEFT", 0, y)
    y = y - 45
    hpSection:SetContentHeight(math.abs(y) + 4)

    page.Refresh = function()
        preview:RefreshPreview()
    end

    Relayout()
end

API:RegisterConfigTab("resources", "Class Resources", CreateResourcesTab, 10.6)
