local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]

local Resources = CDM.Resources or {}
CDM.Resources = Resources

local floor = math.floor
local min = math.min
local max = math.max
local format = string.format
local type = type
local tonumber = tonumber
local tostring = tostring
local ipairs = ipairs
local pcall = pcall
local wipe = wipe
local CreateFrame = CreateFrame
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitPowerDisplayMod = UnitPowerDisplayMod
local UnitPowerPercent = UnitPowerPercent
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitHealthPercent = UnitHealthPercent
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitCanAttack = UnitCanAttack
local UnitIsFriend = UnitIsFriend
local UnitStagger = UnitStagger
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitAffectingCombat = UnitAffectingCombat
local GetUnitChargedPowerPoints = GetUnitChargedPowerPoints
local IsMounted = IsMounted
local IsResting = IsResting
local IsInGroup = IsInGroup
local IsInInstance = IsInInstance
local IsStealthed = IsStealthed
local GetRuneCooldown = GetRuneCooldown
local GetShapeshiftFormID = GetShapeshiftFormID
local GetTime = GetTime
local C_Timer = C_Timer
local C_UnitAuras = C_UnitAuras
local C_Spell = C_Spell
local C_SpellBook = C_SpellBook
local _issecretvalue = issecretvalue

local MEDIA_ROOT = "Interface\\AddOns\\MidnightCooldownManager\\Media\\ClassPower\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local texturePathCache = {}
local StatusBarInterpolation = _G.Enum and _G.Enum.StatusBarInterpolation
local SMOOTH_INTERP = StatusBarInterpolation and StatusBarInterpolation.ExponentialEaseOut or nil
local ScaleTo100 = _G.CurveConstants and _G.CurveConstants.ScaleTo100
local RoundToNearestString = _G.C_StringUtil and _G.C_StringUtil.RoundToNearestString
local RUNTIME_TICK_INTERVAL = 0.05
local powerPercentMode = nil
local healthPercentMode = nil

local E = Enum and Enum.PowerType
local PT = {
    Mana          = (E and E.Mana) or 0,
    Rage          = (E and E.Rage) or 1,
    Focus         = (E and E.Focus) or 2,
    Energy        = (E and E.Energy) or 3,
    ComboPoints   = (E and E.ComboPoints) or 4,
    Runes         = (E and E.Runes) or 5,
    RunicPower    = (E and E.RunicPower) or 6,
    HolyPower     = (E and E.HolyPower) or 9,
    SoulShards    = (E and E.SoulShards) or 7,
    LunarPower    = (E and E.LunarPower) or 8,
    Maelstrom     = (E and E.Maelstrom) or 11,
    Chi           = (E and E.Chi) or 12,
    Insanity      = (E and E.Insanity) or 13,
    ArcaneCharges = (E and E.ArcaneCharges) or 16,
    Essence       = (E and E.Essence) or 19,
}

local MODE = {
    NONE = 0,
    SEGMENTED = 1,
    FRACTIONAL = 2,
    RUNE = 3,
    AURA_SEGMENTED = 4,
    AURA_SINGLE = 5,
    CONTINUOUS = 6,
    TIMER = 8,
    STAGGER = 9,
}

local SPELL = {
    MAELSTROM_WEAPON = 344179,
    MAELSTROM_WEAPON_TALENT = 187880,
    SOUL_CLEAVE = 228477,
    DARK_HEART = (Constants and Constants.UnitPowerSpellIDs and Constants.UnitPowerSpellIDs.DARK_HEART_SPELL_ID) or 1225789,
    SILENCE_THE_WHISPERS = (Constants and Constants.UnitPowerSpellIDs and Constants.UnitPowerSpellIDs.SILENCE_THE_WHISPERS_SPELL_ID) or 1227702,
    VOID_METAMORPHOSIS = (Constants and Constants.UnitPowerSpellIDs and Constants.UnitPowerSpellIDs.VOID_METAMORPHOSIS_SPELL_ID) or 1217607,
    EBON_MIGHT = 395296,
    ICICLES = 205473,
}

local TIP = {
    TALENT_ID = 260285,
    AURA_ID = 260286,
    MAX_STACKS = 3,
    SPENDERS = {
        [259495] = true, [259387] = true, [271788] = true, [187708] = true,
        [1217525] = true, [320976] = true, [1206791] = true, [271014] = true,
    },
}

local STAGGER = {
    YELLOW = _G.STAGGER_YELLOW_TRANSITION or 0.3,
    RED = _G.STAGGER_RED_TRANSITION or 0.6,
}

local POWER_TOKEN = {
    [PT.Mana] = "MANA",
    [PT.Rage] = "RAGE",
    [PT.Focus] = "FOCUS",
    [PT.Energy] = "ENERGY",
    [PT.ComboPoints] = "COMBO_POINTS",
    [PT.Runes] = "RUNES",
    [PT.RunicPower] = "RUNIC_POWER",
    [PT.HolyPower] = "HOLY_POWER",
    [PT.SoulShards] = "SOUL_SHARDS",
    [PT.LunarPower] = "ASTRAL_POWER",
    [PT.Maelstrom] = "MAELSTROM",
    [PT.Chi] = "CHI",
    [PT.Insanity] = "INSANITY",
    [PT.ArcaneCharges] = "ARCANE_CHARGES",
    [PT.Essence] = "ESSENCE",
    MAELSTROM_WEAPON = "MAELSTROM",
    SOUL_FRAGMENTS = "SOUL_FRAGMENTS",
    SOUL_FRAGMENTS_VENG = "SOUL_FRAGMENTS_VENG",
    WHIRLWIND = "WHIRLWIND",
    TIP_OF_THE_SPEAR = "TIP_OF_THE_SPEAR",
    EBON_MIGHT = "EBON_MIGHT",
    STAGGER = "STAGGER",
    ICICLES = "ICICLES",
}

local VALID_TEXT_MODES = {
    NONE = true,
    PERCENT = true,
    VALUE = true,
    CURMAX = true,
}

local HP_FALLBACK_GREEN = { r = 0.12, g = 0.76, b = 0.28, a = 1 }
local HP_FALLBACK_DARK = { r = 0.07, g = 0.08, b = 0.09, a = 1 }
local HP_GRADIENT_LOW = { r = 0.86, g = 0.16, b = 0.12, a = 1 }
local HP_GRADIENT_MID = { r = 0.95, g = 0.76, b = 0.16, a = 1 }
local HP_GRADIENT_HIGH = { r = 0.16, g = 0.78, b = 0.28, a = 1 }

local FALLBACK_COLORS = {
    MANA = { r = 0.00, g = 0.44, b = 0.87 },
    ENERGY = { r = 1.00, g = 0.82, b = 0.10 },
    RAGE = { r = 0.82, g = 0.12, b = 0.12 },
    FOCUS = { r = 1.00, g = 0.50, b = 0.25 },
    RUNIC_POWER = { r = 0.00, g = 0.82, b = 1.00 },
    COMBO_POINTS = { r = 1.00, g = 0.78, b = 0.16 },
    CHARGED = { r = 0.60, g = 0.20, b = 0.80 },
    HOLY_POWER = { r = 0.95, g = 0.90, b = 0.45 },
    SOUL_SHARDS = { r = 0.58, g = 0.30, b = 1.00 },
    ARCANE_CHARGES = { r = 0.42, g = 0.64, b = 1.00 },
    CHI = { r = 0.48, g = 1.00, b = 0.62 },
    ESSENCE = { r = 0.22, g = 0.78, b = 1.00 },
    ASTRAL_POWER = { r = 0.45, g = 0.64, b = 1.00 },
    INSANITY = { r = 0.48, g = 0.16, b = 0.72 },
    MAELSTROM = { r = 0.20, g = 0.58, b = 1.00 },
    SOUL_FRAGMENTS = { r = 0.00, g = 0.80, b = 0.00 },
    SOUL_FRAGMENTS_VENG = { r = 0.58, g = 0.25, b = 1.00 },
    WHIRLWIND = { r = 0.90, g = 0.28, b = 0.10 },
    TIP_OF_THE_SPEAR = { r = 1.00, g = 0.52, b = 0.18 },
    EBON_MIGHT = { r = 0.78, g = 0.38, b = 1.00 },
    STAGGER = { r = 0.52, g = 1.00, b = 0.52 },
    ICICLES = { r = 0.44, g = 0.82, b = 1.00 },
}

local RUNTIME_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED",
    "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "TRAIT_CONFIG_UPDATED",
    "UPDATE_SHAPESHIFT_FORM",
    "UNIT_DISPLAYPOWER",
    "UNIT_POWER_UPDATE",
    "UNIT_POWER_FREQUENT",
    "UNIT_MAXPOWER",
    "UNIT_POWER_POINT_CHARGE",
    "UNIT_AURA",
    "RUNE_POWER_UPDATE",
    "UNIT_HEALTH",
    "UNIT_MAXHEALTH",
    "UNIT_MAX_HEALTH_MODIFIERS_CHANGED",
    "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_DEAD",
    "PLAYER_ALIVE",
    "UNIT_SPELLCAST_SUCCEEDED",
}

local DYNAMIC_EVENTS = {
    PLAYER_SPECIALIZATION_CHANGED = true,
    ACTIVE_PLAYER_SPECIALIZATION_CHANGED = true,
    PLAYER_TALENT_UPDATE = true,
    TRAIT_CONFIG_UPDATED = true,
    UPDATE_SHAPESHIFT_FORM = true,
    UNIT_DISPLAYPOWER = true,
    UNIT_POWER_UPDATE = true,
    UNIT_POWER_FREQUENT = true,
    UNIT_MAXPOWER = true,
    UNIT_POWER_POINT_CHARGE = true,
    UNIT_AURA = true,
    RUNE_POWER_UPDATE = true,
    UNIT_HEALTH = true,
    UNIT_MAXHEALTH = true,
    UNIT_MAX_HEALTH_MODIFIERS_CHANGED = true,
    UNIT_ENTERED_VEHICLE = true,
    UNIT_EXITED_VEHICLE = true,
    PLAYER_REGEN_ENABLED = true,
    PLAYER_REGEN_DISABLED = true,
    PLAYER_DEAD = true,
    PLAYER_ALIVE = true,
    UNIT_SPELLCAST_SUCCEEDED = true,
}

local UNIT_EVENTS = {
    UNIT_DISPLAYPOWER = true,
    UNIT_ENTERED_VEHICLE = true,
    UNIT_EXITED_VEHICLE = true,
    UNIT_POWER_UPDATE = true,
    UNIT_POWER_FREQUENT = true,
    UNIT_MAXPOWER = true,
    UNIT_POWER_POINT_CHARGE = true,
    UNIT_AURA = true,
    UNIT_HEALTH = true,
    UNIT_MAXHEALTH = true,
    UNIT_MAX_HEALTH_MODIFIERS_CHANGED = true,
    UNIT_SPELLCAST_SUCCEEDED = true,
}

Resources.PT = PT
Resources.MODE = MODE
Resources.POWER_TOKEN = POWER_TOKEN

local state = {
    initialized = false,
    enabled = false,
    frame = nil,
    bars = {},
    ticks = {},
    text = nil,
    maxBars = 0,
    powerFrame = nil,
    hpFrame = nil,
    powerType = nil,
    powerToken = nil,
    mode = MODE.NONE,
    maxPower = 0,
    layoutVersion = 0,
    updateCount = 0,
    fullRefreshes = 0,
    maxPowerFastUpdates = 0,
    maxPowerLayoutRefreshes = 0,
    classLoadSkips = 0,
    powerLoadSkips = 0,
    hpLoadSkips = 0,
    powerPercentReads = 0,
    healthPercentReads = 0,
    lastRefreshReason = "none",
    scheduled = false,
    eventBound = {},
    tickActive = false,
    tickElapsed = 0,
    runeActive = false,
    timerActive = false,
    essenceActive = false,
    playerPowerType = nil,
    playerPowerToken = nil,
    playerPowerMax = nil,
    playerPowerMaxReady = false,
    playerPowerMaxSecret = false,
    playerPowerCurrent = nil,
    playerPowerObservedMax = nil,
    playerHPCurrent = nil,
    playerHPMax = nil,
    resourceR = 1,
    resourceG = 1,
    resourceB = 1,
}

local cfg = {
    classEnabled = true,
    hideEmpty = false,
    hideFull = false,
    showText = false,
    runeShowTime = true,
    filledAlpha = 1,
    emptyAlpha = 0.3,
    showEbonMight = true,
    showStagger = true,
    showEleMaelstrom = false,
    showShadowInsanity = false,
    showChargedComboPoints = true,
    resourceColorOverrides = nil,
    powerColorOverrides = nil,
    powerEnabled = false,
    powerTextMode = "PERCENT",
    powerSmooth = true,
    hpEnabled = false,
    hpTextMode = "PERCENT",
    hpColorMode = "CLASS",
    hpCustomR = 0.12,
    hpCustomG = 0.76,
    hpCustomB = 0.28,
    hpCustomA = 1,
    hpGlobalR = 0.12,
    hpGlobalG = 0.76,
    hpGlobalB = 0.28,
    hpGlobalA = 1,
    hpDarkR = 0.07,
    hpDarkG = 0.08,
    hpDarkB = 0.09,
    hpDarkA = 1,
    hpGradientLowR = 0.86,
    hpGradientLowG = 0.16,
    hpGradientLowB = 0.12,
    hpGradientMidR = 0.95,
    hpGradientMidG = 0.76,
    hpGradientMidB = 0.16,
    hpGradientHighR = 0.16,
    hpGradientHighG = 0.78,
    hpGradientHighB = 0.28,
    hpClassR = 0.12,
    hpClassG = 0.76,
    hpClassB = 0.28,
    classLoad = {},
    powerLoad = {},
    hpLoad = {},
    loadNeedCombat = false,
    loadNeedTarget = false,
    loadNeedGroup = false,
    loadNeedInstance = false,
    loadNeedResting = false,
    loadNeedAura = false,
    loadNeedMount = false,
}

local warrior = {
    MAX_STACKS = 4,
    DURATION = 20,
    CRASHING_THUNDER = 436707,
    UNHINGED = 386628,
    generators = { [190411] = true, [6343] = true, [435222] = true },
    spenders = {
        [23881] = true, [85288] = true, [280735] = true, [202168] = true,
        [184367] = true, [335096] = true, [335097] = true, [5308] = true,
    },
    bladestorms = { [50622] = true, [46924] = true, [227847] = true, [184362] = true, [446035] = true },
    stacks = 0,
    expiresAt = nil,
    noConsumeUntil = 0,
    seen = {},
    seenRing = {},
    seenWrite = 1,
    seenCount = 0,
    timerToken = 0,
}

local chargedComboSlots = {}

local function SafeNumber(value, fallback)
    if value == nil then return fallback end
    if _issecretvalue and _issecretvalue(value) then return fallback end
    local n = tonumber(value)
    if n == nil then return fallback end
    return n
end

local function IsSecret(value)
    return _issecretvalue and _issecretvalue(value) == true
end

local function Clamp(value, fallback, minValue, maxValue)
    value = tonumber(value) or fallback
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function NormalizeTextMode(value)
    value = type(value) == "string" and value:upper() or "PERCENT"
    return VALID_TEXT_MODES[value] and value or "PERCENT"
end

local function Defaults()
    return CDM.defaults or {}
end

local function Read(key)
    local db = CDM.db
    if db and db[key] ~= nil then return db[key] end
    local defaults = CDM.defaults
    return defaults and defaults[key]
end

local LOAD_CONDITION_FIELDS = {
    { suffix = "HideMounted", field = "hideMounted" },
    { suffix = "HideInVehicle", field = "hideInVehicle" },
    { suffix = "HideResting", field = "hideResting" },
    { suffix = "HideInCombat", field = "hideInCombat" },
    { suffix = "HideOutOfCombat", field = "hideOutOfCombat" },
    { suffix = "HideStealthed", field = "hideStealthed" },
    { suffix = "HideSolo", field = "hideSolo" },
    { suffix = "HideInGroup", field = "hideInGroup" },
    { suffix = "HideInInstance", field = "hideInInstance" },
    { suffix = "HideNoTarget", field = "hideNoTarget" },
    { suffix = "HideHasTarget", field = "hideHasTarget" },
    { suffix = "HideNoHostileTarget", field = "hideNoHostileTarget" },
    { suffix = "HideNoFriendlyTarget", field = "hideNoFriendlyTarget" },
}

local function ReadLoadCondition(key, legacyKey)
    local db = CDM.db
    if db and db[key] ~= nil then return db[key] == true end
    if legacyKey and db and db[legacyKey] ~= nil then return db[legacyKey] == true end

    local defaults = CDM.defaults
    if defaults and defaults[key] ~= nil then return defaults[key] == true end
    if legacyKey and defaults and defaults[legacyKey] ~= nil then return defaults[legacyKey] == true end
    return false
end

local function RefreshLoadConditionScope(prefix, target, legacyBySuffix)
    target.active = false
    for _, spec in ipairs(LOAD_CONDITION_FIELDS) do
        local enabled = ReadLoadCondition(prefix .. spec.suffix, legacyBySuffix and legacyBySuffix[spec.suffix])
        target[spec.field] = enabled
        if enabled then
            target.active = true
        end
    end

    target.needCombat = target.hideInCombat or target.hideOutOfCombat
    target.needTarget = target.hideNoTarget or target.hideHasTarget or target.hideNoHostileTarget or target.hideNoFriendlyTarget
    target.needGroup = target.hideSolo or target.hideInGroup
    target.needInstance = target.hideInInstance
    target.needResting = target.hideResting
    target.needAura = target.hideStealthed
    target.needMount = target.hideMounted
    target.needVehicle = target.hideInVehicle
end

local function ScopeNeeds(scope, field)
    return scope and scope.active and scope[field] == true
end

local function ScopeNeedsWhen(enabled, scope, field)
    return enabled == true and ScopeNeeds(scope, field)
end

local function RefreshLoadNeedCache(classEnabled, powerEnabled, hpEnabled)
    cfg.loadNeedCombat = ScopeNeedsWhen(classEnabled, cfg.classLoad, "needCombat")
        or ScopeNeedsWhen(powerEnabled, cfg.powerLoad, "needCombat")
        or ScopeNeedsWhen(hpEnabled, cfg.hpLoad, "needCombat")
    cfg.loadNeedTarget = ScopeNeedsWhen(classEnabled, cfg.classLoad, "needTarget")
        or ScopeNeedsWhen(powerEnabled, cfg.powerLoad, "needTarget")
        or ScopeNeedsWhen(hpEnabled, cfg.hpLoad, "needTarget")
    cfg.loadNeedGroup = ScopeNeedsWhen(classEnabled, cfg.classLoad, "needGroup")
        or ScopeNeedsWhen(powerEnabled, cfg.powerLoad, "needGroup")
        or ScopeNeedsWhen(hpEnabled, cfg.hpLoad, "needGroup")
    cfg.loadNeedInstance = ScopeNeedsWhen(classEnabled, cfg.classLoad, "needInstance")
        or ScopeNeedsWhen(powerEnabled, cfg.powerLoad, "needInstance")
        or ScopeNeedsWhen(hpEnabled, cfg.hpLoad, "needInstance")
    cfg.loadNeedResting = ScopeNeedsWhen(classEnabled, cfg.classLoad, "needResting")
        or ScopeNeedsWhen(powerEnabled, cfg.powerLoad, "needResting")
        or ScopeNeedsWhen(hpEnabled, cfg.hpLoad, "needResting")
    cfg.loadNeedAura = ScopeNeedsWhen(classEnabled, cfg.classLoad, "needAura")
        or ScopeNeedsWhen(powerEnabled, cfg.powerLoad, "needAura")
        or ScopeNeedsWhen(hpEnabled, cfg.hpLoad, "needAura")
    cfg.loadNeedMount = ScopeNeedsWhen(classEnabled, cfg.classLoad, "needMount")
        or ScopeNeedsWhen(powerEnabled, cfg.powerLoad, "needMount")
        or ScopeNeedsWhen(hpEnabled, cfg.hpLoad, "needMount")
    cfg.loadNeedVehicle = ScopeNeedsWhen(classEnabled, cfg.classLoad, "needVehicle")
        or ScopeNeedsWhen(powerEnabled, cfg.powerLoad, "needVehicle")
        or ScopeNeedsWhen(hpEnabled, cfg.hpLoad, "needVehicle")
end

local function CopyColor(color, fallback)
    color = type(color) == "table" and color or fallback
    if type(color) ~= "table" then
        return 1, 1, 1, 1
    end
    return color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1, color.a or color[4] or 1
end

local function RefreshConfigCache()
    cfg.classEnabled = Read("resourceClassEnabled") ~= false
    cfg.hideEmpty = Read("resourceHideWhenEmpty") == true
    cfg.hideFull = Read("resourceHideWhenFull") == true
    cfg.showText = Read("resourceShowText") == true
    cfg.runeShowTime = Read("resourceRuneShowTime") ~= false
    cfg.filledAlpha = Clamp(Read("resourceFilledAlpha"), 1, 0, 1)
    cfg.emptyAlpha = Clamp(Read("resourceEmptyAlpha"), 0.3, 0, 1)
    cfg.showEbonMight = Read("resourceShowEbonMight") ~= false
    cfg.showStagger = Read("resourceShowStagger") ~= false
    cfg.showEleMaelstrom = Read("resourceShowEleMaelstrom") == true
    cfg.showShadowInsanity = Read("resourceShowShadowInsanity") == true
    cfg.showChargedComboPoints = Read("resourceShowChargedComboPoints") ~= false

    local overrides = Read("resourceColorOverrides")
    cfg.resourceColorOverrides = type(overrides) == "table" and overrides or nil
    overrides = Read("resourcePowerBarColorOverrides")
    cfg.powerColorOverrides = type(overrides) == "table" and overrides or nil

    cfg.powerEnabled = Read("resourcePowerBarEnabled") == true
    cfg.powerTextMode = NormalizeTextMode(Read("resourcePowerBarTextMode"))
    cfg.powerSmooth = Read("resourcePowerBarSmooth") ~= false
    cfg.hpEnabled = Read("resourceHPBarEnabled") == true
    cfg.hpTextMode = NormalizeTextMode(Read("resourceHPBarTextMode"))
    cfg.hpColorMode = tostring(Read("resourceHPBarColorMode") or "CLASS"):upper()
    cfg.hpCustomR, cfg.hpCustomG, cfg.hpCustomB, cfg.hpCustomA = CopyColor(Read("resourceHPBarColor"), HP_FALLBACK_GREEN)
    cfg.hpGlobalR, cfg.hpGlobalG, cfg.hpGlobalB, cfg.hpGlobalA = CopyColor(Read("resourceHPBarGlobalColor"), HP_FALLBACK_GREEN)
    cfg.hpDarkR, cfg.hpDarkG, cfg.hpDarkB, cfg.hpDarkA = CopyColor(Read("resourceHPBarDarkColor"), HP_FALLBACK_DARK)
    cfg.hpGradientLowR, cfg.hpGradientLowG, cfg.hpGradientLowB = CopyColor(Read("resourceHPBarGradientLow"), HP_GRADIENT_LOW)
    cfg.hpGradientMidR, cfg.hpGradientMidG, cfg.hpGradientMidB = CopyColor(Read("resourceHPBarGradientMid"), HP_GRADIENT_MID)
    cfg.hpGradientHighR, cfg.hpGradientHighG, cfg.hpGradientHighB = CopyColor(Read("resourceHPBarGradientHigh"), HP_GRADIENT_HIGH)

    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    cfg.hpClassR = c and c.r or 0.12
    cfg.hpClassG = c and c.g or 0.76
    cfg.hpClassB = c and c.b or 0.28

    RefreshLoadConditionScope("resourceLoad", cfg.classLoad, { HideOutOfCombat = "resourceHideOOC" })
    RefreshLoadConditionScope("resourcePowerBarLoad", cfg.powerLoad)
    RefreshLoadConditionScope("resourceHPBarLoad", cfg.hpLoad)
    RefreshLoadNeedCache(cfg.classEnabled, cfg.powerEnabled, cfg.hpEnabled)
end

local function SetShown(frame, shown)
    if frame and frame:IsShown() ~= shown then
        frame:SetShown(shown)
    end
end

local function LoadConditionsPass(conds)
    if not (conds and conds.active) then return true end

    if conds.hideMounted and IsMounted and IsMounted() then
        return false
    end
    if conds.hideInVehicle and UnitHasVehicleUI and UnitHasVehicleUI("player") then
        return false
    end
    if conds.hideResting and IsResting and IsResting() then
        return false
    end

    if conds.needCombat then
        local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
        if conds.hideInCombat and inCombat then
            return false
        end
        if conds.hideOutOfCombat and not inCombat then
            return false
        end
    end
    if conds.hideStealthed and IsStealthed and IsStealthed() then
        return false
    end

    if conds.needGroup then
        local grouped = IsInGroup and IsInGroup()
        if conds.hideSolo and not grouped then
            return false
        end
        if conds.hideInGroup and grouped then
            return false
        end
    end

    if conds.needInstance and IsInInstance then
        local inInstance = IsInInstance()
        if inInstance then return false end
    end

    if conds.needTarget then
        local hasTarget = UnitExists and UnitExists("target")
        if conds.hideNoTarget and not hasTarget then
            return false
        end
        if conds.hideHasTarget and hasTarget then
            return false
        end
        if conds.hideNoHostileTarget and not (hasTarget and UnitCanAttack and UnitCanAttack("player", "target")) then
            return false
        end
        if conds.hideNoFriendlyTarget and not (hasTarget and UnitIsFriend and UnitIsFriend("player", "target")) then
            return false
        end
    end

    return true
end

local function SetVertex(tex, r, g, b, a)
    if not tex then return end
    a = a or 1
    if tex._mcdmR == r and tex._mcdmG == g and tex._mcdmB == b and tex._mcdmA == a then return end
    tex:SetVertexColor(r, g, b, a)
    tex._mcdmR, tex._mcdmG, tex._mcdmB, tex._mcdmA = r, g, b, a
end

local function SetBarColor(bar, r, g, b, a)
    if not bar then return end
    a = a or 1
    if bar._mcdmR == r and bar._mcdmG == g and bar._mcdmB == b and bar._mcdmA == a then return end
    bar:SetStatusBarColor(r, g, b, a)
    bar._mcdmR, bar._mcdmG, bar._mcdmB, bar._mcdmA = r, g, b, a
end

local function SetFrameAlpha(frame, alpha)
    if not frame then return end
    alpha = alpha or 1
    if frame._mcdmAlpha == alpha then return end
    frame:SetAlpha(alpha)
    frame._mcdmAlpha = alpha
end

local function SetMinMax(bar, low, high)
    if not bar then return end
    if IsSecret(low) or IsSecret(high) then
        bar:SetMinMaxValues(low, high)
        bar._mcdmMin, bar._mcdmMax = nil, nil
        return
    end
    if bar._mcdmMin == low and bar._mcdmMax == high then return end
    bar:SetMinMaxValues(low, high)
    bar._mcdmMin, bar._mcdmMax = low, high
end

local function SnapBarInterpolation(bar)
    if not (bar and bar._mcdmInterpolating == true) then return false end
    if bar.SetToTargetValue then
        bar:SetToTargetValue()
    end
    bar._mcdmInterpolating = nil
    return true
end

local function SetBarSmoothing(bar, enabled)
    if not bar then return end
    local interp = enabled == true and SMOOTH_INTERP or nil
    if bar._mcdmSmoothInterp ~= interp then
        SnapBarInterpolation(bar)
        bar._mcdmSmoothInterp = interp
    end
end

local function SetValue(bar, value, animate)
    if not bar then return end
    local interp = animate and bar._mcdmSmoothInterp or nil
    if IsSecret(value) then
        if interp then
            bar:SetValue(value, interp)
            bar._mcdmInterpolating = true
        else
            bar:SetValue(value)
        end
        bar._mcdmValue = nil
        return
    end
    if bar._mcdmValue == value then return end
    if interp then
        bar:SetValue(value, interp)
        bar._mcdmInterpolating = true
    else
        bar:SetValue(value)
    end
    bar._mcdmValue = value
end

local function HideText(textFrame)
    if textFrame and textFrame:IsShown() then
        textFrame:Hide()
    end
end

local function ShowText(textFrame, text)
    if not textFrame then return end
    if text == nil then
        HideText(textFrame)
        return
    end
    if IsSecret(text) then
        textFrame:SetFormattedText("%s", text)
        textFrame._mcdmTextValue = nil
    else
        local value = tostring(text)
        if textFrame._mcdmTextValue ~= value then
            textFrame:SetText(value)
            textFrame._mcdmTextValue = value
        end
    end
    if not textFrame:IsShown() then
        textFrame:Show()
    end
end

local function ResolveTexture(key, fallback)
    if key and key ~= "" then
        local cached = texturePathCache[key]
        if cached ~= nil then return cached or fallback or WHITE end
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        local path = LSM and LSM:Fetch("statusbar", key, true)
        texturePathCache[key] = path or false
        if path then return path end
    end
    return fallback or WHITE
end

local function TokenForPower(powerType)
    return POWER_TOKEN[powerType] or (type(powerType) == "string" and powerType or nil)
end

local function ResolveColor(powerType, keyPrefix)
    local token = TokenForPower(powerType)
    local override = keyPrefix == "resourcePowerBarColorOverrides" and cfg.powerColorOverrides or cfg.resourceColorOverrides
    local color = type(override) == "table" and (override[token] or override[powerType]) or nil
    if type(color) == "table" then
        return CopyColor(color)
    end

    local pbc = _G.PowerBarColor
    local pbcColor = token and pbc and pbc[token]
    if not pbcColor and type(powerType) == "number" and pbc then
        pbcColor = pbc[powerType]
    end
    if pbcColor then
        return pbcColor.r or 1, pbcColor.g or 1, pbcColor.b or 1, 1
    end

    local fallback = token and FALLBACK_COLORS[token]
    return CopyColor(fallback, FALLBACK_COLORS.MANA)
end

local function ResolveBgColor()
    return CopyColor(Read("resourceBackgroundColor"), Defaults().resourceBackgroundColor or { r = 0, g = 0, b = 0, a = 0.35 })
end

local function RefreshChargedComboSlots()
    wipe(chargedComboSlots)
    if cfg.showChargedComboPoints == false
        or state.powerType ~= PT.ComboPoints
        or state.mode ~= MODE.SEGMENTED
        or type(GetUnitChargedPowerPoints) ~= "function"
    then
        return nil
    end

    local indices = GetUnitChargedPowerPoints("player")
    if type(indices) ~= "table" then return nil end

    local any
    for i = 1, #indices do
        local slot = SafeNumber(indices[i])
        if slot and slot >= 1 and slot <= 10 then
            chargedComboSlots[slot] = true
            any = true
        end
    end
    return any and chargedComboSlots or nil
end

local function GetSpecIndex()
    return (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()) or GetSpecialization()
end

local function SpellKnown(spellID)
    if not spellID then return false end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID)
    end
    return IsSpellKnown and IsSpellKnown(spellID)
end

local function GetPlayerClass()
    local _, class = UnitClass("player")
    return class
end

local function GetPrimaryPowerType()
    local powerType = UnitPowerType("player")
    return SafeNumber(powerType, PT.Mana) or PT.Mana
end

local function GetPrimaryPowerMeta()
    if not UnitPowerType then return nil, nil end
    local powerType, powerToken = UnitPowerType("player")
    if IsSecret(powerType) then powerType = nil end
    if IsSecret(powerToken) then powerToken = nil end
    return powerType, powerToken
end

local function GetClassResourceType()
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then
        if PlayerVehicleHasComboPoints and PlayerVehicleHasComboPoints() then
            return PT.ComboPoints, MODE.SEGMENTED, false
        end
        return nil, MODE.NONE, false
    end

    local class = GetPlayerClass()
    local spec = GetSpecIndex()

    if class == "DEATHKNIGHT" then
        return PT.Runes, MODE.RUNE, false
    elseif class == "ROGUE" then
        return PT.ComboPoints, MODE.SEGMENTED, false
    elseif class == "PALADIN" then
        return PT.HolyPower, MODE.SEGMENTED, false
    elseif class == "WARLOCK" then
        if spec == 3 then
            return PT.SoulShards, MODE.FRACTIONAL, false
        end
        return PT.SoulShards, MODE.SEGMENTED, false
    elseif class == "EVOKER" then
        if spec == 3 and cfg.showEbonMight then
            return "EBON_MIGHT", MODE.TIMER, true
        end
        return PT.Essence, MODE.SEGMENTED, false
    elseif class == "MAGE" then
        if spec == 1 then return PT.ArcaneCharges, MODE.SEGMENTED, false end
        if spec == 3 then return "ICICLES", MODE.AURA_SEGMENTED, true end
    elseif class == "MONK" then
        if spec == 3 then return PT.Chi, MODE.SEGMENTED, false end
        if spec == 1 and cfg.showStagger then
            return "STAGGER", MODE.STAGGER, false
        end
    elseif class == "DRUID" then
        local form = GetShapeshiftFormID and GetShapeshiftFormID()
        if form == 1 then return PT.ComboPoints, MODE.SEGMENTED, false end
    elseif class == "DEMONHUNTER" then
        if spec == 3 then
            return "SOUL_FRAGMENTS", MODE.AURA_SINGLE, true
        end
        if spec == 2 then
            return "SOUL_FRAGMENTS_VENG", MODE.AURA_SEGMENTED, true
        end
    elseif class == "SHAMAN" then
        if spec == 2 and SpellKnown(SPELL.MAELSTROM_WEAPON_TALENT) then
            return "MAELSTROM_WEAPON", MODE.AURA_SEGMENTED, true
        end
        if spec == 1 and cfg.showEleMaelstrom then
            return PT.Maelstrom, MODE.CONTINUOUS, false
        end
    elseif class == "PRIEST" then
        if spec == 3 and cfg.showShadowInsanity then
            return PT.Insanity, MODE.CONTINUOUS, false
        end
    elseif class == "WARRIOR" then
        return "WHIRLWIND", MODE.AURA_SEGMENTED, false
    elseif class == "HUNTER" then
        if spec == 3 and SpellKnown(TIP.TALENT_ID) then
            return "TIP_OF_THE_SPEAR", MODE.AURA_SEGMENTED, false
        end
    end

    return nil, MODE.NONE, false
end

local function AnchorTarget(target)
    target = tostring(target or "essential"):lower()
    local viewers = CDM.CONST and CDM.CONST.VIEWERS
    if target == "essential" and CDM.anchorContainers and viewers then
        return CDM.anchorContainers[viewers.ESSENTIAL] or (CDM.GetCooldownViewerFrame and CDM:GetCooldownViewerFrame(viewers.ESSENTIAL))
    elseif target == "utility" and CDM.anchorContainers and viewers then
        return CDM.anchorContainers[viewers.UTILITY] or (CDM.GetCooldownViewerFrame and CDM:GetCooldownViewerFrame(viewers.UTILITY))
    elseif target == "buffs" and CDM.anchorContainers and viewers then
        return CDM.anchorContainers[viewers.BUFF] or (CDM.GetCooldownViewerFrame and CDM:GetCooldownViewerFrame(viewers.BUFF))
    elseif target == "player" then
        return _G.PlayerFrame or _G.UIParent
    end
    return _G.UIParent
end

local function EnsureStatusBar(parent, name)
    local frame = CreateFrame("StatusBar", name, parent)
    frame:SetStatusBarTexture(WHITE)
    frame:SetMinMaxValues(0, 1)
    frame:SetValue(0)
    frame:Hide()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetTexture(WHITE)
    bg:SetVertexColor(0, 0, 0, 0.35)
    frame.bg = bg

    local edge = frame:CreateTexture(nil, "BORDER")
    edge:SetTexture(WHITE)
    edge:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    edge:SetVertexColor(0, 0, 0, 1)
    frame.edge = edge

    return frame
end

local function EnsureContainer()
    if state.frame then return end

    local f = CreateFrame("Frame", "MidnightCDM_ResourceFrame", UIParent, "BackdropTemplate")
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(20)
    f:SetSize(220, 8)
    f:Hide()
    state.frame = f

    local edge = f:CreateTexture(nil, "BORDER")
    edge:SetTexture(WHITE)
    edge:SetVertexColor(0, 0, 0, 1)
    edge:Hide()
    state.edge = edge

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(WHITE)
    bg:SetAllPoints(f)
    bg:SetVertexColor(0, 0, 0, 0.18)
    state.bg = bg

    local textFrame = CreateFrame("Frame", nil, f)
    textFrame:SetAllPoints(f)
    textFrame:SetFrameLevel(f:GetFrameLevel() + 8)
    state.textFrame = textFrame

    local text = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    text:Hide()
    state.text = text

    local power = EnsureStatusBar(UIParent, "MidnightCDM_PlayerPowerBar")
    power:SetFrameStrata("MEDIUM")
    power:SetFrameLevel(f:GetFrameLevel() + 10)
    state.powerFrame = power
    local powerText = power:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    powerText:SetPoint("CENTER", power, "CENTER", 0, 0)
    powerText:SetShadowColor(0, 0, 0, 1)
    powerText:SetShadowOffset(1, -1)
    power.text = powerText

    local hp = EnsureStatusBar(UIParent, "MidnightCDM_PlayerHPBar")
    hp:SetFrameStrata("MEDIUM")
    hp:SetFrameLevel(f:GetFrameLevel() + 9)
    state.hpFrame = hp
    local hpText = hp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hpText:SetPoint("CENTER", hp, "CENTER", 0, 0)
    hpText:SetShadowColor(0, 0, 0, 1)
    hpText:SetShadowOffset(1, -1)
    hp.text = hpText

    state.tickFrame = CreateFrame("Frame")
    state.tickFrame:Hide()
    state.tickFrame:SetScript("OnUpdate", function(_, elapsed)
        Resources:OnRuntimeTick(elapsed)
    end)
end

local function ApplyResourceOutline(outline)
    local edge = state.edge
    if not edge or not state.frame then return end

    outline = Clamp(outline, 1, 0, 8)
    edge:ClearAllPoints()
    if outline > 0 then
        edge:SetPoint("TOPLEFT", state.frame, "TOPLEFT", -outline, outline)
        edge:SetPoint("BOTTOMRIGHT", state.frame, "BOTTOMRIGHT", outline, -outline)
        SetVertex(edge, 0, 0, 0, min(1, 0.45 + outline * 0.08))
        edge:Show()
    else
        edge:Hide()
    end
end

local function EnsureResourceBars(count)
    EnsureContainer()
    count = Clamp(count, 1, 1, 10)
    if count <= state.maxBars then return end

    local fgPath = ResolveTexture(Read("resourceTexture"), WHITE)
    for i = state.maxBars + 1, count do
        local bar = EnsureStatusBar(state.frame, nil)
        bar:SetStatusBarTexture(fgPath)
        local rtxt = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rtxt:SetPoint("CENTER", bar, "CENTER", 0, 0)
        rtxt:SetShadowColor(0, 0, 0, 1)
        rtxt:SetShadowOffset(1, -1)
        rtxt:Hide()
        bar.runeText = rtxt
        state.bars[i] = bar
    end
    state.maxBars = count
end

local function HideExtraBars(fromIndex)
    for i = fromIndex, state.maxBars do
        SetShown(state.bars[i], false)
    end
end

local function LayoutResourceAnchorFrame()
    local width = Clamp(Read("resourceWidth"), 220, 40, 800)
    local height = Clamp(Read("resourceHeight"), 8, 2, 80)
    local bgR, bgG, bgB, bgA = ResolveBgColor()

    state.frame:SetSize(width, height)
    state.frame:ClearAllPoints()
    state.frame:SetPoint(
        Read("resourceAnchorPoint") or "BOTTOM",
        AnchorTarget(Read("resourceAnchorTarget")),
        Read("resourceRelativePoint") or "TOP",
        Read("resourceOffsetX") or 0,
        Read("resourceOffsetY") or 6
    )

    if state.bg then
        SetVertex(state.bg, bgR, bgG, bgB, min(0.9, bgA * 0.65))
    end

    return width, height
end

local function LayoutBars(count)
    EnsureResourceBars(count)

    local width, height = LayoutResourceAnchorFrame()
    local gap = Clamp(Read("resourceGap"), 1, 0, 24)
    local reverse = Read("resourceFillReverse") == true
    local tickWidth = Clamp(Read("resourceTickWidth"), 1, 0, 8)
    local outline = Clamp(Read("resourceOutline"), 1, 0, 8)
    local bgR, bgG, bgB, bgA = ResolveBgColor()
    local fgPath = ResolveTexture(Read("resourceTexture"), WHITE)

    ApplyResourceOutline(outline)

    local segmentWidth = (width - (gap * (count - 1))) / count
    if segmentWidth < 1 then segmentWidth = 1 end

    for i = 1, count do
        local visualIndex = reverse and (count - i + 1) or i
        local bar = state.bars[visualIndex]
        bar:ClearAllPoints()
        bar:SetSize(segmentWidth, height)
        bar:SetPoint("LEFT", state.frame, "LEFT", (i - 1) * (segmentWidth + gap), 0)
        bar:SetStatusBarTexture(fgPath)
        bar.bg:SetTexture(ResolveTexture(Read("resourceBgTexture"), fgPath))
        SetVertex(bar.bg, bgR, bgG, bgB, bgA)
        if bar.edge then bar.edge:Hide() end
        SetShown(bar, true)
    end

    for i = 1, count - 1 do
        local tick = state.ticks[i]
        if not tick then
            tick = state.frame:CreateTexture(nil, "OVERLAY")
            tick:SetTexture(WHITE)
            state.ticks[i] = tick
        end
        tick:ClearAllPoints()
        tick:SetSize(tickWidth, height + (outline * 2))
        tick:SetPoint("LEFT", state.frame, "LEFT", i * segmentWidth + (i - 0.5) * gap - (tickWidth * 0.5), 0)
        SetVertex(tick, 0, 0, 0, tickWidth > 0 and 0.78 or 0)
        tick:SetShown(tickWidth > 0 and gap <= 2)
    end
    for i = count, #state.ticks do
        state.ticks[i]:Hide()
    end

    HideExtraBars(count + 1)
    state.layoutVersion = state.layoutVersion + 1
end

local function ApplyResourceFont()
    local fontPath = (CDM.CONST and CDM.CONST.GetBaseFontPath and CDM.CONST.GetBaseFontPath()) or (CDM.CONST and CDM.CONST.FONT_PATH) or STANDARD_TEXT_FONT
    local outline = (CDM.CONST and CDM.CONST.GetBaseFontOutline and CDM.CONST.GetBaseFontOutline()) or "OUTLINE"
    local size = Clamp(Read("resourceTextSize"), 14, 6, 36)
    if state.text then state.text:SetFont(fontPath, size, outline) end
    for i = 1, state.maxBars do
        local text = state.bars[i] and state.bars[i].runeText
        if text then text:SetFont(fontPath, Clamp(Read("resourceRuneTextSize"), 11, 6, 30), outline) end
    end

    local legacyBarSize = Read("resourceBarTextSize")
    local powerBarSize = Clamp(Read("resourcePowerBarTextSize") or legacyBarSize, 13, 6, 36)
    local hpBarSize = Clamp(Read("resourceHPBarTextSize") or legacyBarSize, 13, 6, 36)
    if state.powerFrame and state.powerFrame.text then state.powerFrame.text:SetFont(fontPath, powerBarSize, outline) end
    if state.hpFrame and state.hpFrame.text then state.hpFrame.text:SetFont(fontPath, hpBarSize, outline) end
end

local function LayoutAuxBar(bar, kind)
    if not bar then return end
    local prefix = kind == "hp" and "resourceHPBar" or "resourcePowerBar"
    local width = Clamp(Read(prefix .. "Width"), kind == "hp" and 220 or 220, 40, 800)
    local height = Clamp(Read(prefix .. "Height"), kind == "hp" and 6 or 8, 2, 80)
    bar:SetSize(width, height)
    bar:ClearAllPoints()

    local anchorTarget = Read(prefix .. "AnchorTarget")
    local target
    if anchorTarget == "resource" and state.frame and state.frame.GetNumPoints and state.frame:GetNumPoints() > 0 then
        target = state.frame
    else
        target = AnchorTarget(anchorTarget == "resource" and Read("resourceAnchorTarget") or (anchorTarget or "essential"))
    end

    bar:SetPoint(
        Read(prefix .. "AnchorPoint") or "BOTTOM",
        target,
        Read(prefix .. "RelativePoint") or "TOP",
        Read(prefix .. "OffsetX") or 0,
        Read(prefix .. "OffsetY") or (kind == "hp" and 18 or 16)
    )

    local tex = ResolveTexture(Read(prefix .. "Texture"), WHITE)
    local bgTex = ResolveTexture(Read(prefix .. "BgTexture"), tex)
    SetBarSmoothing(bar, kind == "power" and cfg.powerSmooth)
    bar:SetStatusBarTexture(tex)
    bar.bg:SetTexture(bgTex)
    local bgR, bgG, bgB, bgA = CopyColor(Read(prefix .. "BackgroundColor"), { r = 0, g = 0, b = 0, a = 0.35 })
    SetVertex(bar.bg, bgR, bgG, bgB, bgA)
    local outline = Clamp(Read(prefix .. "Outline"), 1, 0, 8)
    if outline > 0 then
        bar.edge:SetPoint("TOPLEFT", bar, "TOPLEFT", -outline, outline)
        bar.edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", outline, -outline)
        SetVertex(bar.edge, 0, 0, 0, min(1, 0.45 + outline * 0.08))
        bar.edge:Show()
    else
        bar.edge:Hide()
    end
end

local function FormatShort(value)
    value = SafeNumber(value, 0) or 0
    local abbrev = AbbreviateShortNumber or AbbreviateLargeNumbers
    if type(abbrev) == "function" then
        local text = abbrev(value)
        if text then return text end
    end
    local absValue = value < 0 and -value or value
    local sign = value < 0 and "-" or ""
    if absValue >= 1000000 then
        local n = floor((absValue / 100000) + 0.5) / 10
        if n >= 10 or n == floor(n) then return sign .. floor(n + 0.5) .. "M" end
        return sign .. format("%.1fM", n)
    elseif absValue >= 1000 then
        local n = floor((absValue / 100) + 0.5) / 10
        if n >= 10 or n == floor(n) then return sign .. floor(n + 0.5) .. "K" end
        return sign .. format("%.1fK", n)
    end
    return tostring(floor(value + 0.5))
end

local function FormatBarText(current, maximum, mode)
    mode = mode or "PERCENT"
    local cur = SafeNumber(current)
    local maxValue = SafeNumber(maximum)
    if mode == "NONE" then
        return nil
    elseif mode == "VALUE" then
        return cur and FormatShort(cur) or nil
    elseif mode == "CURMAX" then
        if cur and maxValue then return FormatShort(cur) .. " / " .. FormatShort(maxValue) end
    elseif mode == "PERCENT" then
        if cur and maxValue and maxValue > 0 then return floor((cur / maxValue) * 100 + 0.5) .. "%" end
    end
    return nil
end

local function ProbePowerPercentReader(powerType)
    if not UnitPowerPercent then return nil end
    local ok, value
    if ScaleTo100 then
        ok, value = pcall(UnitPowerPercent, "player", powerType, false, ScaleTo100)
        if ok then
            powerPercentMode = "scale"
            return value
        end
    end
    ok, value = pcall(UnitPowerPercent, "player", powerType, false, true)
    if ok then
        powerPercentMode = "curve"
        return value
    end
    ok, value = pcall(UnitPowerPercent, "player", powerType)
    if ok then
        powerPercentMode = "typed"
        return value
    end
    ok, value = pcall(UnitPowerPercent, "player")
    if ok then
        powerPercentMode = "unit"
        return value
    end
    powerPercentMode = false
    return nil
end

local function ReadPowerPercent(powerType)
    if not UnitPowerPercent then return nil end
    state.powerPercentReads = state.powerPercentReads + 1
    if IsSecret(powerType) then powerType = nil end
    if powerPercentMode == nil then
        return ProbePowerPercentReader(powerType)
    end
    if powerPercentMode == false then return nil end
    if powerPercentMode == "scale" then
        return UnitPowerPercent("player", powerType, false, ScaleTo100)
    elseif powerPercentMode == "curve" then
        return UnitPowerPercent("player", powerType, false, true)
    elseif powerPercentMode == "typed" then
        return UnitPowerPercent("player", powerType)
    end
    return UnitPowerPercent("player")
end

local function ProbeHealthPercentReader()
    if not UnitHealthPercent then return nil end
    local ok, value
    if ScaleTo100 then
        ok, value = pcall(UnitHealthPercent, "player", true, ScaleTo100)
        if ok then
            healthPercentMode = "scale"
            return value
        end
    end
    ok, value = pcall(UnitHealthPercent, "player", true, true)
    if ok then
        healthPercentMode = "curve"
        return value
    end
    ok, value = pcall(UnitHealthPercent, "player", true)
    if ok then
        healthPercentMode = "predicted"
        return value
    end
    ok, value = pcall(UnitHealthPercent, "player")
    if ok then
        healthPercentMode = "unit"
        return value
    end
    healthPercentMode = false
    return nil
end

local function ReadHealthPercent()
    if not UnitHealthPercent then return nil end
    state.healthPercentReads = state.healthPercentReads + 1
    if healthPercentMode == nil then
        return ProbeHealthPercentReader()
    end
    if healthPercentMode == false then return nil end
    if healthPercentMode == "scale" then
        return UnitHealthPercent("player", true, ScaleTo100)
    elseif healthPercentMode == "curve" then
        return UnitHealthPercent("player", true, true)
    elseif healthPercentMode == "predicted" then
        return UnitHealthPercent("player", true)
    end
    return UnitHealthPercent("player")
end

local function FormatPercentText(pct)
    if pct == nil then return nil end
    if IsSecret(pct) then
        if RoundToNearestString then
            local ok, text = pcall(RoundToNearestString, pct)
            if ok and text ~= nil then return tostring(text) .. "%" end
        end
        return tostring(pct) .. "%"
    end

    local n = tonumber(pct)
    if n == nil then return tostring(pct) .. "%" end
    if n <= 1 then n = n * 100 end
    if n < 0 then n = 0 elseif n > 100 then n = 100 end
    return tostring(floor(n + 0.5)) .. "%"
end

local function FormatBarValueForText(value)
    if value == nil then return nil end
    if IsSecret(value) then
        local abbrev = AbbreviateNumbers or BreakUpLargeNumbers or AbbreviateLargeNumbers
        if abbrev then
            local ok, text = pcall(abbrev, value)
            if ok and text ~= nil then return text end
        end
        return value
    end
    local n = tonumber(value)
    if n == nil then return value end
    return FormatShort(n)
end

local function WriteBarText(textFrame, current, maximum, mode, powerType)
    if not textFrame then return end
    mode = mode or "PERCENT"
    if mode == "NONE" then
        HideText(textFrame)
        return
    end

    local currentSecret = IsSecret(current)
    local maximumSecret = IsSecret(maximum)
    if not currentSecret and not maximumSecret then
        local text = FormatBarText(current, maximum, mode)
        if text then
            ShowText(textFrame, text)
        else
            HideText(textFrame)
        end
        return
    end

    if mode == "PERCENT" then
        local pct = ReadPowerPercent(powerType)
        if pct ~= nil then
            ShowText(textFrame, FormatPercentText(pct))
        else
            HideText(textFrame)
        end
    elseif mode == "VALUE" and current ~= nil then
        local currentText = FormatBarValueForText(current)
        if currentText ~= nil then
            ShowText(textFrame, currentText)
        else
            HideText(textFrame)
        end
    elseif mode == "CURMAX" and current ~= nil and maximum ~= nil then
        local currentText = FormatBarValueForText(current)
        local maximumText = FormatBarValueForText(maximum)
        if currentText ~= nil and maximumText ~= nil then
            if IsSecret(currentText) or IsSecret(maximumText) then
                textFrame:SetFormattedText("%s / %s", currentText, maximumText)
                textFrame._mcdmTextValue = nil
                if not textFrame:IsShown() then textFrame:Show() end
            else
                ShowText(textFrame, tostring(currentText) .. " / " .. tostring(maximumText))
            end
        else
            HideText(textFrame)
        end
    else
        HideText(textFrame)
    end
end

local function WriteHealthBarText(textFrame, current, maximum, mode, healthPercent)
    if not textFrame then return end
    mode = mode or "PERCENT"
    if mode == "NONE" then
        HideText(textFrame)
        return
    end

    local currentSecret = IsSecret(current)
    local maximumSecret = IsSecret(maximum)
    if not currentSecret and not maximumSecret then
        local text = FormatBarText(current, maximum, mode)
        if text then
            ShowText(textFrame, text)
        else
            HideText(textFrame)
        end
        return
    end

    if mode == "PERCENT" then
        local pct = healthPercent
        if pct == nil then
            pct = ReadHealthPercent()
        end
        if pct ~= nil then
            ShowText(textFrame, FormatPercentText(pct))
        else
            HideText(textFrame)
        end
    elseif mode == "VALUE" and current ~= nil then
        local currentText = FormatBarValueForText(current)
        if currentText ~= nil then
            ShowText(textFrame, currentText)
        else
            HideText(textFrame)
        end
    elseif mode == "CURMAX" and current ~= nil and maximum ~= nil then
        local currentText = FormatBarValueForText(current)
        local maximumText = FormatBarValueForText(maximum)
        if currentText ~= nil and maximumText ~= nil then
            if IsSecret(currentText) or IsSecret(maximumText) then
                textFrame:SetFormattedText("%s / %s", currentText, maximumText)
                textFrame._mcdmTextValue = nil
                if not textFrame:IsShown() then textFrame:Show() end
            else
                ShowText(textFrame, tostring(currentText) .. " / " .. tostring(maximumText))
            end
        else
            HideText(textFrame)
        end
    else
        HideText(textFrame)
    end
end

function Resources:ResetWarrior()
    warrior.stacks = 0
    warrior.expiresAt = nil
    warrior.noConsumeUntil = 0
    warrior.timerToken = warrior.timerToken + 1
    wipe(warrior.seen)
    wipe(warrior.seenRing)
    warrior.seenWrite = 1
    warrior.seenCount = 0
end

local function WarriorCastSeen(guid)
    if not guid then return false end
    if warrior.seen[guid] then return true end
    if warrior.seenCount >= 32 then
        local old = warrior.seenRing[warrior.seenWrite]
        if old then warrior.seen[old] = nil end
    else
        warrior.seenCount = warrior.seenCount + 1
    end
    warrior.seenRing[warrior.seenWrite] = guid
    warrior.seen[guid] = true
    warrior.seenWrite = (warrior.seenWrite % 32) + 1
    return false
end

local function WarriorStacks()
    if warrior.expiresAt and GetTime() >= warrior.expiresAt then
        warrior.stacks = 0
        warrior.expiresAt = nil
    end
    return warrior.stacks
end

local function ScheduleWarriorExpiry()
    if not warrior.expiresAt then return end
    local remaining = warrior.expiresAt - GetTime()
    if remaining <= 0 then
        Resources:ResetWarrior()
        Resources:UpdateValues()
        return
    end
    warrior.timerToken = warrior.timerToken + 1
    local token = warrior.timerToken
    C_Timer.After(remaining + 0.05, function()
        if token ~= warrior.timerToken then return end
        if warrior.expiresAt and GetTime() >= warrior.expiresAt then
            warrior.stacks = 0
            warrior.expiresAt = nil
            Resources:UpdateValues()
        end
    end)
end

function Resources:HandleWarriorCast(castGUID, spellID)
    if state.powerType ~= "WHIRLWIND" or not spellID then return end
    if WarriorCastSeen(castGUID) then return end
    local known = C_SpellBook and C_SpellBook.IsSpellKnown
    if known and known(warrior.UNHINGED) and warrior.bladestorms[spellID] then
        warrior.noConsumeUntil = GetTime() + 2
    end
    if warrior.generators[spellID] then
        if (spellID == 6343 or spellID == 435222) and known and not known(warrior.CRASHING_THUNDER) then
            return
        end
        warrior.stacks = warrior.MAX_STACKS
        warrior.expiresAt = GetTime() + warrior.DURATION
        ScheduleWarriorExpiry()
        self:UpdateValues()
    elseif warrior.spenders[spellID] then
        if spellID == 23881 and GetTime() < warrior.noConsumeUntil then return end
        if warrior.stacks > 0 then
            warrior.stacks = warrior.stacks - 1
            if warrior.stacks == 0 then warrior.expiresAt = nil end
            self:UpdateValues()
        end
    end
end

local function AuraStacks(spellID)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return 0 end
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    return SafeNumber(aura and aura.applications, 0) or 0
end

local function EbonRemaining()
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return 0 end
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(SPELL.EBON_MIGHT)
    if not aura or not aura.expirationTime then return 0 end
    return max(0, aura.expirationTime - GetTime())
end

local function CalculateCurrent()
    local mode = state.mode
    local powerType = state.powerType

    if mode == MODE.RUNE then
        return nil
    elseif mode == MODE.FRACTIONAL then
        local raw = UnitPower("player", powerType, true)
        local mod = UnitPowerDisplayMod and UnitPowerDisplayMod(powerType) or 1
        raw = SafeNumber(raw, 0) or 0
        mod = SafeNumber(mod, 100) or 100
        if mod <= 0 then mod = 100 end
        return raw / mod
    elseif mode == MODE.AURA_SEGMENTED then
        if powerType == "MAELSTROM_WEAPON" then
            return AuraStacks(SPELL.MAELSTROM_WEAPON)
        elseif powerType == "WHIRLWIND" then
            return WarriorStacks()
        elseif powerType == "TIP_OF_THE_SPEAR" then
            return AuraStacks(TIP.AURA_ID)
        elseif powerType == "SOUL_FRAGMENTS_VENG" then
            local count = C_Spell and C_Spell.GetSpellCastCount and C_Spell.GetSpellCastCount(SPELL.SOUL_CLEAVE)
            return SafeNumber(count, 0) or 0
        elseif powerType == "ICICLES" then
            return AuraStacks(SPELL.ICICLES)
        end
        return 0
    elseif mode == MODE.AURA_SINGLE then
        local inMeta = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(SPELL.VOID_METAMORPHOSIS)
        if inMeta then
            return AuraStacks(SPELL.SILENCE_THE_WHISPERS) > 0 and 1 or 0
        end
        return AuraStacks(SPELL.DARK_HEART) > 0 and 1 or 0
    elseif mode == MODE.TIMER then
        return EbonRemaining()
    elseif mode == MODE.STAGGER then
        return SafeNumber(UnitStagger and UnitStagger("player"), 0) or 0
    elseif mode == MODE.CONTINUOUS or mode == MODE.SEGMENTED then
        return SafeNumber(UnitPower("player", powerType), 0) or 0
    end
    return 0
end

local function MaxForMode(powerType, mode)
    if mode == MODE.RUNE then
        return 6
    elseif mode == MODE.AURA_SINGLE or mode == MODE.CONTINUOUS or mode == MODE.STAGGER or mode == MODE.TIMER then
        return 1
    elseif mode == MODE.AURA_SEGMENTED then
        if powerType == "MAELSTROM_WEAPON" then
            local spellMax = C_Spell and C_Spell.GetSpellMaxCumulativeAuraApplications and C_Spell.GetSpellMaxCumulativeAuraApplications(SPELL.MAELSTROM_WEAPON)
            return Clamp(spellMax, 10, 1, 10)
        elseif powerType == "SOUL_FRAGMENTS_VENG" then
            return 6
        elseif powerType == "WHIRLWIND" then
            return warrior.MAX_STACKS
        elseif powerType == "TIP_OF_THE_SPEAR" then
            return TIP.MAX_STACKS
        elseif powerType == "ICICLES" then
            return 5
        end
        return 10
    end

    local mx = UnitPowerMax("player", powerType)
    mx = SafeNumber(mx)
    if not mx or mx <= 0 then
        if powerType == PT.ComboPoints then return 7 end
        if powerType == PT.Runes then return 6 end
        return 5
    end
    return Clamp(floor(mx), 1, 1, 10)
end

local function ApplyAutoHide(current, maximum)
    if not state.frame then return false end
    if not cfg.classEnabled or not state.powerType or state.mode == MODE.NONE then
        state.frame:Hide()
        return false
    end

    if cfg.hideEmpty and SafeNumber(current, 0) == 0 then
        state.frame:Hide()
        return false
    end
    if cfg.hideFull and SafeNumber(current, 0) >= SafeNumber(maximum, 0) then
        state.frame:Hide()
        return false
    end
    SetFrameAlpha(state.frame, 1)
    return true
end

local function NeedsMaxPowerLayoutRefresh()
    return cfg.classEnabled == true
        and state.powerType ~= nil
        and (state.mode == MODE.SEGMENTED or state.mode == MODE.FRACTIONAL)
end

local function UpdateSegmented(current, maximum, fractional)
    local r, g, b = state.resourceR, state.resourceG, state.resourceB
    local filledAlpha = cfg.filledAlpha
    local emptyAlpha = cfg.emptyAlpha
    local full = fractional and floor(current) or current
    local part = fractional and (current - full) or 0
    local chargedSlots = not fractional and RefreshChargedComboSlots() or nil
    local resetChargedBg = chargedSlots or state.chargedComboBgActive == true
    local chargedR, chargedG, chargedB
    local bgR, bgG, bgB, bgA
    if resetChargedBg then
        bgR, bgG, bgB, bgA = ResolveBgColor()
    end
    if chargedSlots then
        chargedR, chargedG, chargedB = ResolveColor("CHARGED", "resourceColorOverrides")
        state.chargedComboBgActive = true
    elseif resetChargedBg then
        state.chargedComboBgActive = nil
    end

    for i = 1, maximum do
        local bar = state.bars[i]
        if bar then
            SetMinMax(bar, 0, 1)
            local filled = false
            if i <= full then
                SetValue(bar, 1)
                SetFrameAlpha(bar, filledAlpha)
                filled = true
            elseif fractional and i == full + 1 and part > 0.001 then
                SetValue(bar, part)
                SetFrameAlpha(bar, filledAlpha)
                filled = true
            else
                SetValue(bar, 0)
                SetFrameAlpha(bar, emptyAlpha)
            end
            if chargedSlots and chargedSlots[i] then
                SetBarColor(bar, chargedR, chargedG, chargedB, 1)
                if filled then
                    SetVertex(bar.bg, bgR, bgG, bgB, bgA)
                else
                    SetVertex(bar.bg, max(chargedR * 0.45, 0.05), max(chargedG * 0.45, 0.05), max(chargedB * 0.45, 0.05), 1)
                end
            else
                SetBarColor(bar, r, g, b, 1)
                if resetChargedBg then
                    SetVertex(bar.bg, bgR, bgG, bgB, bgA)
                end
            end
        end
    end
end

local function UpdateRune()
    local r, g, b = state.resourceR, state.resourceG, state.resourceB
    local filledAlpha = cfg.filledAlpha
    local emptyAlpha = cfg.emptyAlpha
    local showTime = cfg.runeShowTime
    local anyActive = false
    local readyCount = 0

    for i = 1, 6 do
        local bar = state.bars[i]
        if bar then
            local start, duration, ready = GetRuneCooldown(i)
            duration = SafeNumber(duration, 0) or 0
            start = SafeNumber(start, 0) or 0
            if ready then
                readyCount = readyCount + 1
                SetMinMax(bar, 0, 1)
                SetValue(bar, 1)
                SetFrameAlpha(bar, filledAlpha)
                HideText(bar.runeText)
            else
                anyActive = true
                local elapsed = max(0, GetTime() - start)
                SetMinMax(bar, 0, max(0.01, duration))
                SetValue(bar, elapsed)
                SetFrameAlpha(bar, emptyAlpha)
                if bar.runeText then
                    local remaining = max(0, duration - elapsed)
                    if showTime and remaining > 0.05 then
                        ShowText(bar.runeText, format("%.1f", remaining))
                    else
                        HideText(bar.runeText)
                    end
                end
            end
            SetBarColor(bar, r, g, b, 1)
        end
    end
    state.runeActive = anyActive
    return readyCount, 6
end

local function UpdateContinuous(current, maximum)
    local bar = state.bars[1]
    if not bar then return end
    local r, g, b = state.resourceR, state.resourceG, state.resourceB
    if state.mode == MODE.STAGGER then
        local maxHP = SafeNumber(UnitHealthMax("player"), 1) or 1
        maximum = maxHP > 0 and maxHP or 1
        local pct = maximum > 0 and current / maximum or 0
        if pct >= STAGGER.RED then
            r, g, b = 1.00, 0.42, 0.42
        elseif pct > STAGGER.YELLOW then
            r, g, b = 1.00, 0.98, 0.72
        else
            r, g, b = 0.52, 1.00, 0.52
        end
    elseif state.mode == MODE.TIMER then
        maximum = 20
        current = max(0, min(20, current))
    else
        maximum = SafeNumber(UnitPowerMax("player", state.powerType), 100) or 100
        if maximum <= 0 then maximum = 100 end
    end
    SetMinMax(bar, 0, maximum)
    SetValue(bar, current)
    SetFrameAlpha(bar, cfg.filledAlpha)
    SetBarColor(bar, r, g, b, 1)
end

local function UpdateResourceText(current, maximum)
    local text = state.text
    if not text then return end
    if not cfg.showText then
        HideText(text)
        return
    end
    if state.mode == MODE.RUNE then
        ShowText(text, current or 0)
    elseif state.mode == MODE.TIMER then
        ShowText(text, format("%.1fs", SafeNumber(current, 0) or 0))
    elseif state.mode == MODE.STAGGER then
        ShowText(text, FormatShort(current or 0))
    else
        local n = SafeNumber(current, 0) or 0
        if state.mode == MODE.FRACTIONAL and n ~= floor(n) then
            ShowText(text, format("%.1f", n))
        else
            ShowText(text, floor(n + 0.5))
        end
    end
end

function Resources:UpdateValues()
    if not state.frame or not state.powerType or state.mode == MODE.NONE then return end
    state.updateCount = state.updateCount + 1
    if not LoadConditionsPass(cfg.classLoad) then
        state.classLoadSkips = state.classLoadSkips + 1
        SetShown(state.frame, false)
        SetShown(state.tickFrame, false)
        state.tickActive = false
        state.tickElapsed = 0
        return
    end

    local current
    local maximum = state.maxPower

    if state.mode == MODE.RUNE then
        current, maximum = UpdateRune()
    else
        current = CalculateCurrent()
        if state.mode == MODE.SEGMENTED or state.mode == MODE.AURA_SEGMENTED or state.mode == MODE.AURA_SINGLE then
            UpdateSegmented(SafeNumber(current, 0) or 0, maximum, false)
        elseif state.mode == MODE.FRACTIONAL then
            UpdateSegmented(SafeNumber(current, 0) or 0, maximum, true)
        elseif state.mode == MODE.CONTINUOUS or state.mode == MODE.TIMER or state.mode == MODE.STAGGER then
            UpdateContinuous(SafeNumber(current, 0) or 0, maximum)
        end
    end

    UpdateResourceText(current, maximum)
    SetShown(state.frame, ApplyAutoHide(current, maximum))
    self:SyncTickState()
end

function Resources:UpdatePlayerPower(forceMeta)
    local bar = state.powerFrame
    if not bar then return end
    if not cfg.powerEnabled then
        SetShown(bar, false)
        state.playerPowerCurrent = nil
        state.playerPowerObservedMax = nil
        return
    end
    if not LoadConditionsPass(cfg.powerLoad) then
        state.powerLoadSkips = state.powerLoadSkips + 1
        SetShown(bar, false)
        state.playerPowerCurrent = nil
        state.playerPowerObservedMax = nil
        return
    end

    local powerType, powerToken
    local mx = state.playerPowerMax
    local metaChanged = false
    if forceMeta == true or state.playerPowerMaxReady ~= true then
        powerType, powerToken = GetPrimaryPowerMeta()
        if powerType ~= state.playerPowerType or powerToken ~= state.playerPowerToken then
            metaChanged = true
        end
        if powerType ~= nil then
            mx = UnitPowerMax("player", powerType)
        else
            mx = UnitPowerMax("player")
        end
        if not IsSecret(mx) and mx == nil then mx = 1 end
        local safeMax = SafeNumber(mx)
        if safeMax ~= nil and safeMax <= 0 then mx = 1 end
        state.playerPowerType = powerType
        state.playerPowerToken = powerToken
        state.playerPowerMax = mx
        state.playerPowerMaxReady = true
        state.playerPowerMaxSecret = IsSecret(mx)
    else
        powerType = state.playerPowerType
        powerToken = state.playerPowerToken
    end

    local cur
    if powerType ~= nil then
        cur = UnitPower("player", powerType)
    else
        cur = UnitPower("player")
    end
    if not IsSecret(cur) and cur == nil then cur = 0 end
    local comparableCur = not IsSecret(cur) and tonumber(cur) or nil
    local comparableMax = not IsSecret(mx) and tonumber(mx) or nil
    if forceMeta ~= true
        and not metaChanged
        and comparableCur ~= nil
        and comparableMax ~= nil
        and state.playerPowerCurrent == comparableCur
        and state.playerPowerObservedMax == comparableMax
        and bar:IsShown() then
        return
    end
    state.playerPowerCurrent = comparableCur
    state.playerPowerObservedMax = comparableMax
    if forceMeta == true or metaChanged or bar._mcdmPowerMinMaxReady ~= true then
        SetMinMax(bar, 0, mx or 1)
        bar._mcdmPowerMinMaxReady = true
    end
    SetValue(bar, cur, forceMeta ~= true)
    if forceMeta == true then
        SnapBarInterpolation(bar)
    end
    if metaChanged or bar._mcdmPowerColorReady ~= true then
        local r, g, b = ResolveColor(powerToken or powerType, "resourcePowerBarColorOverrides")
        SetBarColor(bar, r, g, b, 1)
        bar._mcdmPowerColorReady = true
    end
    WriteBarText(bar.text, cur, mx, cfg.powerTextMode, powerType)
    SetShown(bar, true)
end

local function Lerp(a, b, t)
    return (a or 0) + (((b or 0) - (a or 0)) * t)
end

local function HealthFraction(hp, maxHP, healthPercent)
    if not IsSecret(hp) and not IsSecret(maxHP) then
        local h = tonumber(hp)
        local m = tonumber(maxHP)
        if h and m and m > 0 then
            local pct = h / m
            if pct < 0 then return 0 end
            if pct > 1 then return 1 end
            return pct
        end
    end

    local pct = healthPercent
    if pct == nil then
        pct = ReadHealthPercent()
    end
    if pct ~= nil and not IsSecret(pct) then
        local n = tonumber(pct)
        if n then
            if n > 1 then n = n / 100 end
            if n < 0 then return 0 end
            if n > 1 then return 1 end
            return n
        end
    end
    return nil
end

local function ResolveHPGradientColor(hp, maxHP, healthPercent)
    local pct = HealthFraction(hp, maxHP, healthPercent) or 1
    if pct <= 0.5 then
        local t = pct * 2
        return Lerp(cfg.hpGradientLowR, cfg.hpGradientMidR, t),
            Lerp(cfg.hpGradientLowG, cfg.hpGradientMidG, t),
            Lerp(cfg.hpGradientLowB, cfg.hpGradientMidB, t)
    end
    local t = (pct - 0.5) * 2
    return Lerp(cfg.hpGradientMidR, cfg.hpGradientHighR, t),
        Lerp(cfg.hpGradientMidG, cfg.hpGradientHighG, t),
        Lerp(cfg.hpGradientMidB, cfg.hpGradientHighB, t)
end

local function ResolveHPBarColor(hp, maxHP, healthPercent)
    local mode = cfg.hpColorMode
    if mode == "CUSTOM" then
        return cfg.hpCustomR, cfg.hpCustomG, cfg.hpCustomB, cfg.hpCustomA
    elseif mode == "GLOBAL" then
        return cfg.hpGlobalR, cfg.hpGlobalG, cfg.hpGlobalB, cfg.hpGlobalA
    elseif mode == "DARK" then
        return cfg.hpDarkR, cfg.hpDarkG, cfg.hpDarkB, cfg.hpDarkA
    elseif mode == "GRADIENT" then
        return ResolveHPGradientColor(hp, maxHP, healthPercent)
    end
    return cfg.hpClassR, cfg.hpClassG, cfg.hpClassB, 1
end

function Resources:UpdatePlayerHP(force)
    local bar = state.hpFrame
    if not bar then return end
    if not cfg.hpEnabled then
        SetShown(bar, false)
        state.playerHPCurrent = nil
        state.playerHPMax = nil
        return
    end
    if not LoadConditionsPass(cfg.hpLoad) then
        state.hpLoadSkips = state.hpLoadSkips + 1
        SetShown(bar, false)
        state.playerHPCurrent = nil
        state.playerHPMax = nil
        return
    end
    local hp = UnitHealth("player")
    local maxHP = UnitHealthMax("player")
    if not IsSecret(maxHP) then
        if maxHP == nil then
            maxHP = 1
        else
            local safeMax = tonumber(maxHP) or 1
            if safeMax <= 0 then maxHP = 1 end
        end
    end
    if not IsSecret(hp) and hp == nil then hp = 0 end
    local hpSecret = IsSecret(hp)
    local maxSecret = IsSecret(maxHP)
    local healthPercent
    if hpSecret or maxSecret then
        if cfg.hpColorMode == "GRADIENT" or cfg.hpTextMode == "PERCENT" then
            healthPercent = ReadHealthPercent()
        end
    end
    local comparableHP = not hpSecret and tonumber(hp) or nil
    local comparableMax = not maxSecret and tonumber(maxHP) or nil
    if force ~= true
        and comparableHP ~= nil
        and comparableMax ~= nil
        and state.playerHPCurrent == comparableHP
        and state.playerHPMax == comparableMax
        and bar:IsShown() then
        return
    end
    state.playerHPCurrent = comparableHP
    state.playerHPMax = comparableMax
    SetMinMax(bar, 0, maxHP or 1)
    SetValue(bar, hp or 0)
    local r, g, b, a = ResolveHPBarColor(hp, maxHP, healthPercent)
    SetBarColor(bar, r, g, b, a or 1)
    WriteHealthBarText(bar.text, hp, maxHP, cfg.hpTextMode, healthPercent)
    SetShown(bar, true)
end

function Resources:SyncTickState()
    local tickNeeded = state.runeActive == true or state.mode == MODE.TIMER
    SetShown(state.tickFrame, tickNeeded)
    if tickNeeded and state.tickActive ~= true then
        state.tickElapsed = RUNTIME_TICK_INTERVAL
    elseif not tickNeeded then
        state.tickElapsed = 0
    end
    state.tickActive = tickNeeded
end

function Resources:OnRuntimeTick(elapsed)
    state.tickElapsed = (state.tickElapsed or 0) + (elapsed or 0)
    if state.tickElapsed < RUNTIME_TICK_INTERVAL then return end
    state.tickElapsed = 0
    if state.mode == MODE.RUNE or state.mode == MODE.TIMER then
        self:UpdateValues()
    end
end

function Resources:UpdateConditionVisibility()
    if state.powerType and state.mode ~= MODE.NONE then
        self:UpdateValues()
    elseif state.frame then
        state.frame:Hide()
    end
    if cfg.powerEnabled then
        self:UpdatePlayerPower(false)
    end
    if cfg.hpEnabled then
        self:UpdatePlayerHP()
    end
end

local function SetRuntimeEvent(eventName, enabled, unit)
    local frame = state.eventFrame
    if not (frame and eventName) then return end
    enabled = enabled == true
    if state.eventBound[eventName] == enabled then return end
    state.eventBound[eventName] = enabled
    if enabled then
        if unit then
            frame:RegisterUnitEvent(eventName, unit)
        else
            frame:RegisterEvent(eventName)
        end
    else
        frame:UnregisterEvent(eventName)
    end
end

function Resources:RefreshEventBindings()
    local classActive = cfg.classEnabled and state.powerType ~= nil and state.mode ~= MODE.NONE and state.maxPower > 0
    local mode = state.mode
    local standardPower = classActive and (mode == MODE.SEGMENTED or mode == MODE.FRACTIONAL or mode == MODE.CONTINUOUS)
    local auraPower = classActive and (mode == MODE.AURA_SINGLE or mode == MODE.TIMER
        or (mode == MODE.AURA_SEGMENTED and (state.powerType == "MAELSTROM_WEAPON" or state.powerType == "TIP_OF_THE_SPEAR" or state.powerType == "ICICLES")))
    local runePower = classActive and mode == MODE.RUNE
    local stagger = classActive and mode == MODE.STAGGER
    local spellTracked = classActive and (state.powerType == "WHIRLWIND" or state.powerType == "TIP_OF_THE_SPEAR" or state.powerType == "SOUL_FRAGMENTS_VENG")
    local needsHealth = cfg.hpEnabled or stagger
    local needsPowerBar = cfg.powerEnabled
    local needsFrequentPowerBar = needsPowerBar and cfg.powerSmooth == true
    local needsClassMetadata = cfg.classEnabled == true
    RefreshLoadNeedCache(classActive, cfg.powerEnabled, cfg.hpEnabled)

    SetRuntimeEvent("PLAYER_SPECIALIZATION_CHANGED", needsClassMetadata)
    SetRuntimeEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", needsClassMetadata)
    SetRuntimeEvent("PLAYER_TALENT_UPDATE", needsClassMetadata)
    SetRuntimeEvent("TRAIT_CONFIG_UPDATED", needsClassMetadata)
    SetRuntimeEvent("UPDATE_SHAPESHIFT_FORM", needsClassMetadata)
    SetRuntimeEvent("UNIT_DISPLAYPOWER", needsClassMetadata or needsPowerBar, "player")
    SetRuntimeEvent("UNIT_POWER_UPDATE", standardPower or needsPowerBar, "player")
    SetRuntimeEvent("UNIT_POWER_FREQUENT", needsFrequentPowerBar, "player")
    SetRuntimeEvent("UNIT_MAXPOWER", standardPower or needsPowerBar, "player")
    SetRuntimeEvent("UNIT_POWER_POINT_CHARGE", classActive and mode == MODE.SEGMENTED, "player")
    SetRuntimeEvent("UNIT_AURA", auraPower or cfg.loadNeedAura, "player")
    SetRuntimeEvent("RUNE_POWER_UPDATE", runePower)
    SetRuntimeEvent("UNIT_HEALTH", needsHealth, "player")
    SetRuntimeEvent("UNIT_MAXHEALTH", needsHealth, "player")
    SetRuntimeEvent("UNIT_MAX_HEALTH_MODIFIERS_CHANGED", needsHealth, "player")
    SetRuntimeEvent("UNIT_SPELLCAST_SUCCEEDED", spellTracked, "player")
    SetRuntimeEvent("PLAYER_REGEN_ENABLED", cfg.loadNeedCombat)
    SetRuntimeEvent("PLAYER_REGEN_DISABLED", cfg.loadNeedCombat)
    SetRuntimeEvent("PLAYER_TARGET_CHANGED", cfg.loadNeedTarget)
    SetRuntimeEvent("GROUP_ROSTER_UPDATE", cfg.loadNeedGroup)
    SetRuntimeEvent("PLAYER_UPDATE_RESTING", cfg.loadNeedResting)
    SetRuntimeEvent("ZONE_CHANGED_NEW_AREA", cfg.loadNeedInstance)
    SetRuntimeEvent("PLAYER_MOUNT_DISPLAY_CHANGED", cfg.loadNeedMount)
    SetRuntimeEvent("UNIT_ENTERED_VEHICLE", cfg.loadNeedVehicle, "player")
    SetRuntimeEvent("UNIT_EXITED_VEHICLE", cfg.loadNeedVehicle, "player")
    SetRuntimeEvent("PLAYER_DEAD", cfg.hpEnabled or spellTracked)
    SetRuntimeEvent("PLAYER_ALIVE", cfg.hpEnabled or spellTracked)
end

function Resources:FullRefresh(reason)
    EnsureContainer()
    RefreshConfigCache()
    state.fullRefreshes = state.fullRefreshes + 1
    state.lastRefreshReason = reason or "refresh"
    state.scheduled = false

    local classEnabled = cfg.classEnabled
    local powerType, mode = nil, MODE.NONE
    if classEnabled then
        powerType, mode = GetClassResourceType()
    end

    state.powerType = powerType
    state.powerToken = TokenForPower(powerType)
    state.mode = mode or MODE.NONE
    state.maxPower = powerType and MaxForMode(powerType, state.mode) or 0
    state.resourceR, state.resourceG, state.resourceB = ResolveColor(powerType or PT.Mana)
    self:RefreshEventBindings()

    ApplyResourceFont()
    LayoutResourceAnchorFrame()

    if powerType and state.mode ~= MODE.NONE and state.maxPower > 0 then
        LayoutBars(state.maxPower)
        self:UpdateValues()
    else
        if state.frame then state.frame:Hide() end
        state.runeActive = false
    end

    LayoutAuxBar(state.powerFrame, "power")
    LayoutAuxBar(state.hpFrame, "hp")
    if state.powerFrame then state.powerFrame._mcdmPowerColorReady = nil end
    self:UpdatePlayerPower(true)
    self:UpdatePlayerHP(true)
    self:SyncTickState()
end

function Resources:ScheduleFullRefresh(reason)
    state.lastRefreshReason = reason or state.lastRefreshReason
    if state.scheduled then return end
    state.scheduled = true
    C_Timer.After(0, function()
        if not state.initialized then return end
        self:FullRefresh(state.lastRefreshReason)
    end)
end

function Resources:Refresh()
    self:FullRefresh("manual")
end

function Resources:HandleEvent(event, arg1, arg2, arg3)
    if event == "PLAYER_ENTERING_WORLD" then
        self:ScheduleFullRefresh(event)
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
        or event == "PLAYER_TALENT_UPDATE"
        or event == "TRAIT_CONFIG_UPDATED"
        or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "UNIT_DISPLAYPOWER" then
        if arg1 == nil or arg1 == "player" then
            self:ScheduleFullRefresh(event)
        end
        return
    end

    if event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
        if arg1 ~= "player" then return end
        local token = arg2
        if state.powerToken == token or state.mode == MODE.CONTINUOUS or state.mode == MODE.SEGMENTED or state.mode == MODE.FRACTIONAL then
            self:UpdateValues()
        end
        if cfg.powerEnabled then self:UpdatePlayerPower(false) end
        return
    end

    if event == "UNIT_MAXPOWER" then
        if arg1 == "player" then
            state.playerPowerMaxReady = false
            if NeedsMaxPowerLayoutRefresh() then
                state.maxPowerLayoutRefreshes = state.maxPowerLayoutRefreshes + 1
                self:ScheduleFullRefresh(event)
            else
                state.maxPowerFastUpdates = state.maxPowerFastUpdates + 1
                if state.mode == MODE.CONTINUOUS then
                    self:UpdateValues()
                end
                if cfg.powerEnabled then
                    self:UpdatePlayerPower(true)
                end
            end
        end
        return
    end

    if event == "UNIT_AURA" then
        if arg1 == "player" and (state.mode == MODE.AURA_SEGMENTED or state.mode == MODE.AURA_SINGLE or state.mode == MODE.TIMER or state.mode == MODE.STAGGER or cfg.loadNeedAura) then
            self:UpdateConditionVisibility()
        end
        return
    end

    if event == "RUNE_POWER_UPDATE" then
        if state.mode == MODE.RUNE then
            self:UpdateValues()
        end
        return
    end

    if event == "UNIT_POWER_POINT_CHARGE" then
        if arg1 == "player" and state.mode == MODE.SEGMENTED then
            self:UpdateValues()
        end
        return
    end

    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_MAX_HEALTH_MODIFIERS_CHANGED" then
        if arg1 == "player" then
            if state.mode == MODE.STAGGER then self:UpdateValues() end
            if cfg.hpEnabled then self:UpdatePlayerHP() end
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        self:UpdateConditionVisibility()
        return
    end

    if event == "PLAYER_TARGET_CHANGED"
        or event == "GROUP_ROSTER_UPDATE"
        or event == "PLAYER_UPDATE_RESTING"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "PLAYER_MOUNT_DISPLAY_CHANGED"
        or event == "UNIT_ENTERED_VEHICLE"
        or event == "UNIT_EXITED_VEHICLE" then
        self:UpdateConditionVisibility()
        return
    end

    if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" then
        self:ResetWarrior()
        self:UpdateValues()
        if cfg.hpEnabled then self:UpdatePlayerHP() end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg1 == "player" then
            self:HandleWarriorCast(arg2, arg3)
            if state.powerType == "TIP_OF_THE_SPEAR" and TIP.SPENDERS[arg3] then
                self:UpdateValues()
            elseif state.powerType == "SOUL_FRAGMENTS_VENG" then
                self:UpdateValues()
            end
        end
    end
end

function Resources:Initialize()
    if state.initialized then return end
    state.initialized = true
    EnsureContainer()

    local eventFrame = CreateFrame("Frame")
    state.eventFrame = eventFrame
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        Resources:HandleEvent(event, ...)
    end)
    for _, eventName in ipairs(RUNTIME_EVENTS) do
        if not DYNAMIC_EVENTS[eventName] then
            if UNIT_EVENTS[eventName] then
                eventFrame:RegisterUnitEvent(eventName, "player")
            else
                eventFrame:RegisterEvent(eventName)
            end
            state.eventBound[eventName] = true
        end
    end

    self:ScheduleFullRefresh("initialize")
end

local function CountBoundRuntimeEvents()
    local count = 0
    for _, enabled in pairs(state.eventBound) do
        if enabled == true then
            count = count + 1
        end
    end
    return count
end

local boundEventScratch = {}
local function BuildBoundRuntimeEventList()
    wipe(boundEventScratch)
    for eventName, enabled in pairs(state.eventBound) do
        if enabled == true then
            boundEventScratch[#boundEventScratch + 1] = eventName
        end
    end
    table.sort(boundEventScratch)
    if #boundEventScratch == 0 then
        return "none"
    end
    return table.concat(boundEventScratch, ",")
end

function Resources:GetDiagnostics()
    return {
        initialized = state.initialized,
        powerType = state.powerType,
        powerToken = state.powerToken,
        mode = state.mode,
        maxPower = state.maxPower,
        classEnabled = cfg.classEnabled,
        powerBarEnabled = cfg.powerEnabled,
        hpBarDefaultEnabled = (CDM.defaults and CDM.defaults.resourceHPBarEnabled) == true,
        hasClassFrame = state.frame ~= nil,
        hasPowerBar = state.powerFrame ~= nil,
        hasHPBar = state.hpFrame ~= nil,
        playerPowerType = state.playerPowerType,
        playerPowerToken = state.playerPowerToken,
        playerPowerMaxReady = state.playerPowerMaxReady,
        playerPowerMaxSecret = state.playerPowerMaxSecret,
        playerPowerTextMode = cfg.powerTextMode,
        playerPowerSmooth = cfg.powerSmooth and SMOOTH_INTERP ~= nil,
        playerPowerSmoothConfig = cfg.powerSmooth == true,
        playerPowerSmoothAPI = SMOOTH_INTERP ~= nil,
        playerPowerPercentMode = powerPercentMode == nil and "unprobed" or tostring(powerPercentMode),
        playerHealthPercentMode = healthPercentMode == nil and "unprobed" or tostring(healthPercentMode),
        classLoadActive = cfg.classLoad and cfg.classLoad.active or false,
        powerLoadActive = cfg.powerLoad and cfg.powerLoad.active or false,
        hpLoadActive = cfg.hpLoad and cfg.hpLoad.active or false,
        loadNeedCombat = cfg.loadNeedCombat,
        loadNeedTarget = cfg.loadNeedTarget,
        loadNeedGroup = cfg.loadNeedGroup,
        loadNeedInstance = cfg.loadNeedInstance,
        loadNeedResting = cfg.loadNeedResting,
        loadNeedAura = cfg.loadNeedAura,
        loadNeedMount = cfg.loadNeedMount,
        loadNeedVehicle = cfg.loadNeedVehicle,
        resourceAuraMode = state.mode == MODE.AURA_SEGMENTED or state.mode == MODE.AURA_SINGLE or state.mode == MODE.TIMER or state.mode == MODE.STAGGER,
        boundRuntimeEvents = CountBoundRuntimeEvents(),
        boundRuntimeEventList = BuildBoundRuntimeEventList(),
        unitPowerFrequentBound = state.eventBound.UNIT_POWER_FREQUENT == true,
        unitAuraBound = state.eventBound.UNIT_AURA == true,
        displayPowerEventBound = state.eventBound.UNIT_DISPLAYPOWER == true,
        specEventBound = state.eventBound.PLAYER_SPECIALIZATION_CHANGED == true
            and state.eventBound.ACTIVE_PLAYER_SPECIALIZATION_CHANGED == true
            and state.eventBound.PLAYER_TALENT_UPDATE == true
            and state.eventBound.TRAIT_CONFIG_UPDATED == true,
        shapeshiftEventBound = state.eventBound.UPDATE_SHAPESHIFT_FORM == true,
        mountEventBound = state.eventBound.PLAYER_MOUNT_DISPLAY_CHANGED == true,
        vehicleEventBound = state.eventBound.UNIT_ENTERED_VEHICLE == true or state.eventBound.UNIT_EXITED_VEHICLE == true,
        classShown = state.frame and state.frame:IsShown() or false,
        powerBarShown = state.powerFrame and state.powerFrame:IsShown() or false,
        hpBarShown = state.hpFrame and state.hpFrame:IsShown() or false,
        updateCount = state.updateCount,
        fullRefreshes = state.fullRefreshes,
        maxPowerFastUpdates = state.maxPowerFastUpdates,
        maxPowerLayoutRefreshes = state.maxPowerLayoutRefreshes,
        classLoadSkips = state.classLoadSkips,
        powerLoadSkips = state.powerLoadSkips,
        hpLoadSkips = state.hpLoadSkips,
        powerPercentReads = state.powerPercentReads,
        healthPercentReads = state.healthPercentReads,
        lastRefreshReason = state.lastRefreshReason,
        tickActive = state.tickActive,
    }
end

function CDM:InitializeResources()
    Resources:Initialize()
end

function CDM:RefreshResources()
    Resources:Refresh()
end

function CDM:GetResourceDiagnostics()
    return Resources:GetDiagnostics()
end
