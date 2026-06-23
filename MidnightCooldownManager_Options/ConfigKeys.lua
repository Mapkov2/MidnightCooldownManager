local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local ns = Runtime._OptionsNS
local CDM = Runtime

ns.ConfigKeys = {
    order = {
        "cooldowngroups",
        "styling",
        "text",
        "bars",
        "racials",
        "defensives",
        "trinkets",
        "externals",
        "resources",
        "glow",
        "fading",
        "assist",
        "positions",
        "buffgroups",
    },
    categories = {
        cooldowngroups = {
            label = "Cooldown Groups",
            keys = {
                "cooldownGroups",
                "ungroupedCooldownOverrides",
                "sizeEssRow1",
                "sizeEssRow2",
                "sizeUtility",
                "sizeBuff",
                "spacing",
                "maxRowEss",
                "utilityWrap",
                "maxRowUtil",
                "utilityUnlock",
                "utilityXOffset",
                "utilityVertical",
            },
        },
        styling = {
            label = "Border & Visual Styling",
            keys = {
                "borderFile",
                "borderSize",
                "borderOffsetX",
                "borderOffsetY",
                "borderColor",
                "zoomIcons",
                "zoomAmount",
                "hideIconOverlay",
                "hideIconOverlayTexture",
                "hideDebuffBorder",
                "hidePandemicIndicator",
                "hideCooldownBling",
                "pandemicCustomizationEnabled",
                "pandemicBorderEnabled",
                "pandemicBorderColorBuffBars",
                "pandemicBorderColor",
                "chargeShowEdge",
                "chargeHideSwipe",
                "chargeHideRechargeTimer",
                "swipeColor",
                "hideGCDSwipe",
                "hideBuffSwipe",
                "disableCooldownDesat",
                "cooldownIconTintEnabled",
                "buffIconTintEnabled",
                "cooldownIconTintColor",
            },
        },
        text = {
            label = "Text & Font Settings",
            keys = {
                "textFont",
                "textFontOutline",
                "cooldownFontSize",
                "cooldownColor",
                "cooldownDecimalThreshold",
                "cooldownColorThresholdEnabled",
                "cooldownColorThreshold",
                "cooldownColorThresholdColor",
                "essRow2CooldownFontSize",
                "utilityCooldownFontSize",
                "chargeFontSize",
                "utilityChargeFontSize",
                "chargeColor",
                "chargePosition",
                "chargeOffsetX",
                "chargeOffsetY",
                "essRow2ChargeFontSize",
                "essRow2ChargeColor",
                "essRow2ChargePosition",
                "essRow2ChargeOffsetX",
                "essRow2ChargeOffsetY",
                "utilityChargeColor",
                "utilityChargePosition",
                "utilityChargeOffsetX",
                "utilityChargeOffsetY",
                "countFontSize",
                "countColor",
                "buffCooldownFontSize",
                "buffCooldownColor",
                "countPositionMain",
                "countOffsetXMain",
                "countOffsetYMain",
                "buffBarNameFontSize",
                "buffBarNameColor",
                "buffBarNameOffsetX",
                "buffBarNameOffsetY",
                "buffBarDurationFontSize",
                "buffBarDurationColor",
                "buffBarDurationPosition",
                "buffBarDurationOffsetX",
                "buffBarDurationOffsetY",
            },
        },
        bars = {
            label = "Buff Bar Settings",
            keys = {
                "buffBarWidth",
                "buffBarHeight",
                "buffBarSpacing",
                "buffBarGrowDirection",
                "buffBarIconPosition",
                "buffBarIconGap",
                "buffBarShowName",
                "buffBarNameMaxChars",
                "buffBarShowDuration",
                "buffBarShowApplications",
                "buffBarApplicationsFontSize",
                "buffBarApplicationsColor",
                "buffBarApplicationsPosition",
                "buffBarApplicationsOffsetX",
                "buffBarApplicationsOffsetY",
                "buffBarTexture",
                "buffBarColor",
                "buffBarBackgroundColor",
                "buffBarFillDirection",
                "barGroups",
                "ungroupedBarOverrides",
            },
        },
        racials = {
            label = "Racials Tracker Settings",
            keys = {
                "racialsEnabled",
                "racialsIconWidth",
                "racialsIconHeight",
                "racialsAnchorPoint",
                "racialsOffsetX",
                "racialsOffsetY",
                "racialsChargeFontSize",
                "racialsCooldownFontSize",
                "racialsChargePosition",
                "racialsChargeOffsetX",
                "racialsChargeOffsetY",
                "racialsUsePartyFrame",
                "racialsPartyFrameSide",
                "racialsPartyFrameOffsetX",
                "racialsPartyFrameOffsetY",
                "racialsRaidFrameAnchorPoint",
                "racialsRaidFrameRelativePoint",
                "racialsRaidFrameOffsetX",
                "racialsRaidFrameOffsetY",
                "racialsChargeColor",
                "racialsShowItemsAtZeroStacks",
                "racialsCustomEntries",
                "racialsOrderPerSpec",
                "racialsDisabled",
            },
        },
        defensives = {
            label = "Defensives Tracker Settings",
            keys = {
                "defensivesEnabled",
                "defensivesIconWidth",
                "defensivesIconHeight",
                "defensivesAnchorPoint",
                "defensivesOffsetX",
                "defensivesOffsetY",
                "defensivesChargeFontSize",
                "defensivesCooldownFontSize",
                "defensivesChargePosition",
                "defensivesChargeOffsetX",
                "defensivesChargeOffsetY",
                "defensivesDisabledSpells",
                "defensivesCustomSpells",
                "defensivesOrder",
            },
        },
        trinkets = {
            label = "Trinkets Tracker Settings",
            keys = {
                "trinketsEnabled",
                "trinketsIconWidth",
                "trinketsIconHeight",
                "trinketsAnchorPoint",
                "trinketsOffsetX",
                "trinketsOffsetY",
                "trinketsCooldownFontSize",
                "trinketsShowPassive",
                "trinketsBlacklist",
                "trinketsMode",
                "trinketsEssentialRow",
                "trinketsEssentialPosition",
            },
        },
        externals = {
            label = "Externals Tracker Settings",
            keys = {
                "externalsEnabled",
                "externalsIconWidth",
                "externalsIconHeight",
                "externalsCooldownFontSize",
                "externalsDisableBlink",
            },
        },
        resources = {
            label = "Class Resources",
            keys = {
                "resourceClassEnabled",
                "resourceWidth",
                "resourceHeight",
                "resourceGap",
                "resourceTickWidth",
                "resourceOutline",
                "resourceAnchorTarget",
                "resourceAnchorPoint",
                "resourceRelativePoint",
                "resourceOffsetX",
                "resourceOffsetY",
                "resourceTexture",
                "resourceBgTexture",
                "resourceBackgroundColor",
                "resourceColorOverrides",
                "resourceShowText",
                "resourceTextSize",
                "resourceRuneTextSize",
                "resourceRuneShowTime",
                "resourceFilledAlpha",
                "resourceEmptyAlpha",
                "resourceFillReverse",
                "resourceHideOOC",
                "resourceHideWhenFull",
                "resourceHideWhenEmpty",
                "resourceLoadHideMounted",
                "resourceLoadHideInVehicle",
                "resourceLoadHideResting",
                "resourceLoadHideInCombat",
                "resourceLoadHideOutOfCombat",
                "resourceLoadHideStealthed",
                "resourceLoadHideSolo",
                "resourceLoadHideInGroup",
                "resourceLoadHideInInstance",
                "resourceLoadHideNoTarget",
                "resourceLoadHideHasTarget",
                "resourceLoadHideNoHostileTarget",
                "resourceLoadHideNoFriendlyTarget",
                "resourceShowStagger",
                "resourceShowEbonMight",
                "resourceShowEleMaelstrom",
                "resourceShowShadowInsanity",
                "resourceShowChargedComboPoints",
                "resourcePowerBarEnabled",
                "resourcePowerBarWidth",
                "resourcePowerBarHeight",
                "resourcePowerBarAnchorTarget",
                "resourcePowerBarAnchorPoint",
                "resourcePowerBarRelativePoint",
                "resourcePowerBarOffsetX",
                "resourcePowerBarOffsetY",
                "resourcePowerBarTexture",
                "resourcePowerBarBgTexture",
                "resourcePowerBarOutline",
                "resourcePowerBarBackgroundColor",
                "resourcePowerBarColorOverrides",
                "resourcePowerBarTextMode",
                "resourcePowerBarTextSize",
                "resourcePowerBarSmooth",
                "resourcePowerBarLoadHideMounted",
                "resourcePowerBarLoadHideInVehicle",
                "resourcePowerBarLoadHideResting",
                "resourcePowerBarLoadHideInCombat",
                "resourcePowerBarLoadHideOutOfCombat",
                "resourcePowerBarLoadHideStealthed",
                "resourcePowerBarLoadHideSolo",
                "resourcePowerBarLoadHideInGroup",
                "resourcePowerBarLoadHideInInstance",
                "resourcePowerBarLoadHideNoTarget",
                "resourcePowerBarLoadHideHasTarget",
                "resourcePowerBarLoadHideNoHostileTarget",
                "resourcePowerBarLoadHideNoFriendlyTarget",
                "resourceHPBarEnabled",
                "resourceHPBarWidth",
                "resourceHPBarHeight",
                "resourceHPBarAnchorTarget",
                "resourceHPBarAnchorPoint",
                "resourceHPBarRelativePoint",
                "resourceHPBarOffsetX",
                "resourceHPBarOffsetY",
                "resourceHPBarTexture",
                "resourceHPBarBgTexture",
                "resourceHPBarOutline",
                "resourceHPBarBackgroundColor",
                "resourceHPBarColorMode",
                "resourceHPBarColor",
                "resourceHPBarGlobalColor",
                "resourceHPBarDarkColor",
                "resourceHPBarGradientLow",
                "resourceHPBarGradientMid",
                "resourceHPBarGradientHigh",
                "resourceHPBarTextMode",
                "resourceHPBarTextSize",
                "resourceHPBarLoadHideMounted",
                "resourceHPBarLoadHideInVehicle",
                "resourceHPBarLoadHideResting",
                "resourceHPBarLoadHideInCombat",
                "resourceHPBarLoadHideOutOfCombat",
                "resourceHPBarLoadHideStealthed",
                "resourceHPBarLoadHideSolo",
                "resourceHPBarLoadHideInGroup",
                "resourceHPBarLoadHideInInstance",
                "resourceHPBarLoadHideNoTarget",
                "resourceHPBarLoadHideHasTarget",
                "resourceHPBarLoadHideNoHostileTarget",
                "resourceHPBarLoadHideNoFriendlyTarget",
            },
        },
        glow = {
            label = "Glow Settings",
            keys = {
                "glowType",
                "glowUseCustomColor",
                "glowColor",
                "glowPixelLines",
                "glowPixelFrequency",
                "glowPixelLength",
                "glowPixelThickness",
                "glowPixelXOffset",
                "glowPixelYOffset",
                "glowPixelBorder",
                "glowAutocastParticles",
                "glowAutocastFrequency",
                "glowAutocastScale",
                "glowAutocastXOffset",
                "glowAutocastYOffset",
                "glowButtonFrequency",
                "glowProcDuration",
                "glowProcXOffset",
                "glowProcYOffset",
            },
        },
        assist = {
            label = "Assist Settings",
            keys = {
                "rotationAssistEnabled",
                "rotationAssistGlowRatio",
                "assistEnabled",
                "assistFontSize",
                "assistColor",
                "assistPosition",
                "assistOffsetX",
                "assistOffsetY",
                "pressOverlayEnabled",
                "pressOverlayTint",
                "pressOverlayTintColor",
                "pressOverlayHighlight",
                "pressOverlayBorder",
                "pressOverlayBorderColor",
            },
        },
        fading = {
            label = "Fading Settings",
            keys = {
                "fadingEnabled",
                "fadingTriggerNoTarget",
                "fadingTriggerOOC",
                "fadingTriggerMounted",
                "fadingOpacity",
                "fadingEssential",
                "fadingUtility",
                "fadingBuffs",
                "fadingBuffBars",
                "fadingRacials",
                "fadingDefensives",
                "fadingTrinkets",
            },
        },
        positions = {
            label = "Positions & Locking",
            keys = {
                "editModePositions",
                "utilityYOffset",
            },
        },
        buffgroups = {
            label = "Buff Groups",
            keys = {
                "buffGroups",
                "ungroupedBuffPins",
                "ungroupedBuffOverrides",
                "spellRegistry",
                "customBuffRegistry",
                "ungroupedCustomBuffOrder",
            },
        },
    },
}

ns.ConfigSearchCategoryByTab = {
    layout = "cooldowngroups",
    sizes = "cooldowngroups",
    border = "styling",
    text = "text",
    bars = "bars",
    racials = "racials",
    defensives = "defensives",
    trinkets = "trinkets",
    resources = "resources",
    glow = "glow",
    assist = "assist",
    fading = "fading",
    positions = "positions",
    buffgroups = "buffgroups",
}

ns.ConfigSearchKeywords = {
    dashboard = [[
        dashboard overview home status setup checklist start quick actions diagnostics diagnostic smoke smoke test ptr ready
        recovery reset factory reset restore defaults reload rl mover move mode edit mode current profile combat state
        scaling menu scale ui scale size changelog release notes version support github paypal patreon kofi ko fi discord
        runtime tooltip tooltips hover mouseover cooldown tooltip buff tooltip show tooltip hide tooltip
        attribution inspired ayije help links
        uebersicht status startseite pruefung diagnose setup zuruecksetzen werkseinstellungen skalierung unterstuetzung
    ]],
    layout = [[
        cooldown cooldowns cd cds cdm group groups cooldown group cooldown groups essential utility general externals spell
        spells icon icons current spec all specs grouped ungrouped add group add icon custom spell custom cooldown
        reorder move up down priority dummy preview placeholder row rows row 1 row 2 main buffs
        per spell overrides override glow border sound text to speech tts hide cooldown timer hide icon show placeholder
        cooldown color on cooldown color tint black box black icon turn black turn color shadow desaturate desaturation
        gruppe gruppen zauber faehigkeit cooldowngruppe sortieren verschieben schwarz farbe abklingzeit
    ]],
    sizes = [[
        size sizes icon size icon width icon height width height spacing gap padding max row max per row wrap vertical
        essential row utility buffs bars racials defensives trinkets externals cooldown icon buff icon
        groesse breite hoehe abstand zeile umbruch vertikal symbol symbole
    ]],
    positions = [[
        position positions anchor anchors anchor point relative point offset offsets x offset y offset x y lock unlock
        edit mode mover drag move frame frames screen player frame center top bottom left right utility y offset
        positionieren anker verschieben sperren entsperren versatz
    ]],
    buffgroups = [[
        buff buffs aura auras buff group buff groups group groups custom buff custom aura spell id duration static display
        add custom buff ungrouped grouped pin unpin override overrides per spell border glow sound tts text to speech
        cooldown timer hide timer hide icon placeholder show placeholder count stacks applications stack text icon tint
        on cooldown color cooldown color black icon black box turn color dummy preview
        buffgruppe aura gruppe zauber dauer stapel anwendungen schwarz farbe
    ]],
    bars = [[
        bar bars buff bar buff bars group groups custom bar ungrouped grouped duration name applications stacks timer
        width height spacing gap grow direction fill direction left right icon position icon gap texture statusbar
        foreground background color bg alpha name max chars duration text application text reorder preview
        leiste leisten balken buffleiste textur hintergrund fuellrichtung name dauer stapel
    ]],
    border = [[
        border borders look edge outline visual styling appearance border file border size border offset border color
        icon mask default mask remove mask shadow overlay remove shadow zoom icons zoom amount swipe cooldown swipe gcd swipe
        buff swipe bling cooldown bling pandemic indicator debuff border charge edge charge swipe recharge timer
        tint icon tint cooldown tint buff tint black cooldown color on cooldown color
        rahmen umriss rand maske schatten zoom aussehen swipe farbe
    ]],
    text = [[
        text font fonts font preview font dropdown outline font outline cooldown timer cooldown text timer color
        decimal threshold charge count stack stacks applications position top bottom center offset x offset y
        essential utility buff bars bar name duration resource text class resource text power text hp text health text
        schrift schriftart schriftvorschau kontur umriss timer zahlen stapel textposition
    ]],
    glow = [[
        glow glows highlight border pixel glow autocast glow button glow proc glow type custom color glow color
        lines frequency length thickness x offset y offset particles scale pulse shine border glow
        leuchten glow hervorhebung farbe linien frequenz staerke partikel
    ]],
    fading = [[
        fading fade alpha opacity transparency hidden inactive out of combat ooc no target mounted trigger
        essential utility buffs buff bars racials defensives trinkets hide dim
        ausblenden verblassen transparenz deckkraft ausser kampf kein ziel reiten
    ]],
    assist = [[
        assist rotation assist recommendation recommend press overlay keybind overlay tint highlight border glow ratio
        suggestion next spell priority helper icon border color font size position offsets
        assistent rotation empfehlung taste overlay hervorhebung
    ]],
    resources = [[
        class resource class resources resource resources power class power combo points empowered combo points charged combo points
        runes rune recharge holy power chi essence soul shards arcane charges icicles frost mage maelstrom insanity stagger
        ebon might elemental shadow rogue death knight paladin monk evoker warlock mage shaman priest demon hunter druid
        player power power bar player power bar health hp health bar second hp second player hp bar
        load conditions load condition hide condition mounted vehicle resting combat in combat out of combat stealth solo group
        instance target no target hostile target friendly target preview zoom drag arrows arrow keys texture foreground background
        lsm lib shared media outline border color tab colors gradient dark mode global color custom color smooth fill
        resource text power text hp text percent current max value reverse fill hide when full hide when empty
        klassenressource ressourcen combo punkte macht lebensbalken hp balken ziel kampf textur farbe bedingung
    ]],
    racials = [[
        racial racials tracker spell item custom spell custom item healthstone potion racial cooldown spatial rift
        enable disable tracked spells manage spells add custom spell item id spell id cooldown text charge text icon size
        party frame anchoring raid frame anchor position stacks show items at zero stacks order per spec disabled blacklist
        volk racial volksfaehigkeit trank gesundheitsstein item zauber
    ]],
    defensives = [[
        defensive defensives tracker mitigation spell cooldown custom spell tracked spells manage spells personal defensive
        cloak evasion feint wall immunity external self cooldown icon size position charge text cooldown text order disable
        defensiv verteidigung schutzzauber schadensreduktion zauber reihenfolge
    ]],
    trinkets = [[
        trinket trinkets item items tracker equipment slot passive trinkets show passive blacklist mode display mode
        independent essential utility row position cooldown text icon size anchor item id add item manage blacklist
        schmuckstueck trinket item gegenstand passiv blacklist sperrliste
    ]],
    profiles = [[
        profile profiles current profile new profile create copy from copy settings manage rename delete reset profile
        default profile new characters specialization profiles spec profiles auto switch per spec active profile import profile
        profil profile kopieren umbenennen loeschen zuruecksetzen spezialisation spec
    ]],
    importexport = [[
        import export import export share string wago curse backup restore profile string ayije acdm legacy
        ayije import saved profiles loaded profiles ayije cdmdb ayije_cdmdb paste clear migrate migration compatibility
        class resources import resources power bar hp bar cooldown groups buff groups bars
        importieren exportieren teilen profil backup migrieren ayije
    ]],
}

do
    local defaults = CDM.defaults
    if not defaults then return end

    local keysInCategories = {}
    for catName, catDef in pairs(ns.ConfigKeys.categories) do
        for _, key in ipairs(catDef.keys) do
            if keysInCategories[key] then
                print("|cffff6600[MCDM] ConfigKeys: '" .. key .. "' in both '" .. keysInCategories[key] .. "' and '" .. catName .. "'|r")
            end
            keysInCategories[key] = catName
        end
    end

    for key in pairs(defaults) do
        if not keysInCategories[key] then
            print("|cffff6600[MCDM] ConfigKeys: default key '" .. key .. "' not in any export category|r")
        end
    end

    for key, catName in pairs(keysInCategories) do
        if defaults[key] == nil then
            print("|cffff6600[MCDM] ConfigKeys: export key '" .. key .. "' (in '" .. catName .. "') has no default|r")
        end
    end
end
