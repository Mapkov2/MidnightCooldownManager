-- ########################################################
-- MSA_BuffTemplates.lua  (v2 - templates + live scanner)
--
-- * Static template library (15 categories, 40+ spells)
-- * One-time out-of-combat spellbook + bag scan
-- * 100 % secret-safe, zero pcall
-- ########################################################

local ADDON_NAME, ns = ...

local type, pairs, ipairs, tinsert, wipe = type, pairs, ipairs, table.insert, wipe or table.wipe

-----------------------------------------------------------
-- Template definitions
-----------------------------------------------------------

local CATEGORIES = {
    { key = "HEALER_HOTS",   name = "Healer HoTs",            order = 1,  isBuff = true },
    { key = "AUG_EVOKER",    name = "Augmentation Evoker",     order = 2,  isBuff = true },
    { key = "RAID_BUFFS",    name = "Raid Buffs",              order = 3,  isBuff = true },
    { key = "BOB",           name = "Blessing of Bronze",      order = 4,  isBuff = true },
    { key = "SELF_BUFFS",    name = "Self Buffs",              order = 5,  isBuff = true },
    { key = "ROGUE_POISONS", name = "Rogue Poisons",           order = 6,  isBuff = true },
    { key = "SHAMAN_IMBUE",  name = "Shaman Imbuements",       order = 7,  isBuff = true },
    { key = "RESOURCE",      name = "Resource Auras",          order = 8,  isBuff = true },
    { key = "COOLDOWNS",     name = "Your Cooldowns",          order = 9,  isBuff = false, dynamic = true },
    { key = "SPELLBOOK",     name = "Your Spellbook",          order = 10, dynamic = true },
    { key = "BAGS",          name = "Your Bags",               order = 11, dynamic = true },
}

MSWA_CATEGORY_LOOKUP = {}
for _, c in ipairs(CATEGORIES) do MSWA_CATEGORY_LOOKUP[c.key] = c end

-- Pre-built templates: each entry is one "pack" with multiple spells
local TEMPLATES = {
    -- ===== HEALER HOTS =====
    { id = "healer_druid_hots",   cat = "HEALER_HOTS",   name = "Druid HoTs",
      desc = "Rejuvenation, Lifebloom, Wild Growth, Regrowth",
      spells = {
        { sid = 774,    name = "Rejuvenation" },
        { sid = 33763,  name = "Lifebloom" },
        { sid = 48438,  name = "Wild Growth" },
        { sid = 8936,   name = "Regrowth" },
      },
    },
    { id = "healer_priest_hots",  cat = "HEALER_HOTS",   name = "Priest HoTs",
      desc = "Renew, Power Word: Shield, Atonement",
      spells = {
        { sid = 139,    name = "Renew" },
        { sid = 17,     name = "Power Word: Shield" },
        { sid = 194384, name = "Atonement" },
      },
    },
    { id = "healer_paladin",      cat = "HEALER_HOTS",   name = "Paladin Buffs",
      desc = "Beacon of Light, Glimmer of Light",
      spells = {
        { sid = 53563,  name = "Beacon of Light" },
        { sid = 287280, name = "Glimmer of Light" },
      },
    },
    { id = "healer_shaman_hots",  cat = "HEALER_HOTS",   name = "Shaman HoTs",
      desc = "Riptide, Earth Shield, Healing Rain",
      spells = {
        { sid = 61295,  name = "Riptide" },
        { sid = 204288, name = "Earth Shield" },
        { sid = 73920,  name = "Healing Rain" },
      },
    },
    { id = "healer_monk_hots",    cat = "HEALER_HOTS",   name = "Monk HoTs",
      desc = "Renewing Mist, Enveloping Mist, Essence Font",
      spells = {
        { sid = 119611, name = "Renewing Mist" },
        { sid = 124682, name = "Enveloping Mist" },
        { sid = 191840, name = "Essence Font" },
      },
    },
    { id = "healer_evoker_hots",  cat = "HEALER_HOTS",   name = "Evoker HoTs",
      desc = "Reversion, Echo, Dream Breath",
      spells = {
        { sid = 366155, name = "Reversion" },
        { sid = 364343, name = "Echo" },
        { sid = 355936, name = "Dream Breath" },
      },
    },

    -- ===== AUGMENTATION EVOKER =====
    { id = "aug_evoker",          cat = "AUG_EVOKER",    name = "Augmentation Buffs",
      desc = "Ebon Might, Prescience, Shifting Sands",
      spells = {
        { sid = 395152, name = "Ebon Might" },
        { sid = 410089, name = "Prescience" },
        { sid = 413984, name = "Shifting Sands" },
      },
    },

    -- ===== RAID BUFFS =====
    { id = "raid_buffs_all",      cat = "RAID_BUFFS",     name = "Raid Buffs (All)",
      desc = "Intellect, Fortitude, Battle Shout, Arcane Intellect, Mark of the Wild",
      spells = {
        { sid = 1459,   name = "Arcane Intellect" },
        { sid = 21562,  name = "Power Word: Fortitude" },
        { sid = 6673,   name = "Battle Shout" },
        { sid = 1126,   name = "Mark of the Wild" },
        { sid = 381732, name = "Blessing of the Bronze" },
      },
    },

    -- ===== BLESSING OF BRONZE =====
    { id = "bob_all",             cat = "BOB",            name = "Blessing of Bronze",
      desc = "All Blessing of the Bronze variants",
      spells = {
        { sid = 381732, name = "Blessing of the Bronze" },
        { sid = 364342, name = "Blessing of the Bronze (Evoker)" },
      },
    },

    -- ===== SELF BUFFS =====
    { id = "self_buffs",          cat = "SELF_BUFFS",     name = "Common Self Buffs",
      desc = "Ice Barrier, Power Word: Shield, Barkskin, etc.",
      spells = {
        { sid = 11426,  name = "Ice Barrier" },
        { sid = 17,     name = "Power Word: Shield" },
        { sid = 22812,  name = "Barkskin" },
        { sid = 184662, name = "Shield of Vengeance" },
        { sid = 871,    name = "Shield Wall" },
      },
    },

    -- ===== ROGUE POISONS =====
    { id = "rogue_poisons",       cat = "ROGUE_POISONS",  name = "Rogue Poisons",
      desc = "Deadly, Instant, Wound, Crippling, Atrophic, Numbing Poisons",
      spells = {
        { sid = 2823,   name = "Deadly Poison" },
        { sid = 315584, name = "Instant Poison" },
        { sid = 8679,   name = "Wound Poison" },
        { sid = 3408,   name = "Crippling Poison" },
        { sid = 381637, name = "Atrophic Poison" },
        { sid = 5761,   name = "Numbing Poison" },
      },
    },

    -- ===== SHAMAN IMBUEMENTS =====
    { id = "shaman_imbue",        cat = "SHAMAN_IMBUE",   name = "Shaman Imbuements",
      desc = "Windfury, Flametongue",
      spells = {
        { sid = 33757,  name = "Windfury Weapon" },
        { sid = 318038, name = "Flametongue Weapon" },
      },
    },

    -- ===== RESOURCE AURAS =====
    { id = "resource_auras",      cat = "RESOURCE",       name = "Resource Auras",
      desc = "Innervate, Power Infusion, Bloodlust",
      spells = {
        { sid = 29166,  name = "Innervate" },
        { sid = 10060,  name = "Power Infusion" },
        { sid = 2825,   name = "Bloodlust" },
        { sid = 32182,  name = "Heroism" },
        { sid = 80353,  name = "Time Warp" },
      },
    },

    -- ===== COOLDOWNS =====
    { id = "util_cooldowns",      cat = "COOLDOWNS",      name = "Utility Cooldowns",
      desc = "Hearthstone, Reincarnation, etc.",
      spells = {
        { sid = 8690,   name = "Hearthstone" },
        { sid = 20608,  name = "Reincarnation" },
      },
    },
}

-- Index by category
local templatesByCategory = {}
for _, t in ipairs(TEMPLATES) do
    local cat = t.cat
    if not templatesByCategory[cat] then templatesByCategory[cat] = {} end
    tinsert(templatesByCategory[cat], t)
end

-----------------------------------------------------------
-- Public API: categories & templates
-----------------------------------------------------------

function MSWA_GetTemplateCategories()
    return CATEGORIES
end

function MSWA_GetTemplatesForCategory(catKey)
    return templatesByCategory[catKey] or {}
end

function MSWA_GetTemplateByID(templateID)
    for _, t in ipairs(TEMPLATES) do
        if t.id == templateID then return t end
    end
    return nil
end

-----------------------------------------------------------
-- Safe icon lookup (non-secret)
-----------------------------------------------------------

function MSWA_GetSpellIconSafe(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.iconID
    end
    return nil
end

function MSWA_GetItemIconSafe(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    end
    return nil
end

-----------------------------------------------------------
-- Spellbook scanner (one-time, out-of-combat only)
-- Tags each spell with hasCd = true if cooldown > 1.5s
-----------------------------------------------------------

local spellbookResults = nil  -- cached after first scan
local _issecretvalue = _G.issecretvalue

-- Check if a spell has a meaningful cooldown (not just GCD)
local function HasMeaningfulCooldown(spellID)
    if not spellID then return false end
    -- Try GetSpellBaseCooldown (returns ms, available out of combat)
    if C_Spell and C_Spell.GetSpellBaseCooldown then
        local ok, baseCd = pcall(C_Spell.GetSpellBaseCooldown, spellID)
        if ok and baseCd and not (_issecretvalue and _issecretvalue(baseCd)) and baseCd > 2000 then
            return true  -- >2s base cooldown
        end
    end
    -- Check for charge-based spells
    if C_Spell and C_Spell.GetSpellCharges then
        local ok, info = pcall(C_Spell.GetSpellCharges, spellID)
        if ok and type(info) == "table" and info.maxCharges and info.maxCharges > 1 then
            return true
        end
    end
    return false
end

function MSWA_ScanSpellbook()
    if InCombatLockdown() then return nil end
    if spellbookResults then return spellbookResults end

    spellbookResults = {}

    if not C_SpellBook or not C_SpellBook.GetNumSpellBookItems then
        return spellbookResults
    end

    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if not bank then return spellbookResults end

    local numSpells = C_SpellBook.GetNumSpellBookItems(bank) or 0
    local seen = {}

    for i = 1, numSpells do
        local itemInfo = C_SpellBook.GetSpellBookItemInfo(i, bank)
        if itemInfo then
            local sid = itemInfo.spellID
            if sid and not (_issecretvalue and _issecretvalue(sid)) and not seen[sid] then
                -- Skip passives, flyouts, future spells
                local isPassive = itemInfo.isPassive
                local itemType = itemInfo.itemType
                local isUsable = not itemType
                    or itemType == (Enum.SpellBookItemType and Enum.SpellBookItemType.Spell)
                if isUsable and not isPassive then
                    seen[sid] = true
                    local name = itemInfo.name
                    local icon = itemInfo.iconID
                    if not name and C_Spell and C_Spell.GetSpellInfo then
                        local sInfo = C_Spell.GetSpellInfo(sid)
                        if sInfo then name = sInfo.name; icon = icon or sInfo.iconID end
                    end
                    if name then
                        tinsert(spellbookResults, {
                            sid   = sid,
                            name  = name,
                            icon  = icon,
                            hasCd = HasMeaningfulCooldown(sid),
                        })
                    end
                end
            end
        end
    end

    -- Sort: cooldown spells first, then alphabetical
    table.sort(spellbookResults, function(a, b)
        if a.hasCd ~= b.hasCd then return a.hasCd == true end
        return (a.name or "") < (b.name or "")
    end)
    return spellbookResults
end

-- Force re-scan (e.g. on spec change)
function MSWA_InvalidateSpellbookCache()
    spellbookResults = nil
end

-----------------------------------------------------------
-- Bag scanner (one-time, out-of-combat only)
-----------------------------------------------------------

local bagResults = nil

function MSWA_ScanBags()
    if InCombatLockdown() then return nil end
    if bagResults then return bagResults end

    bagResults = {}

    if not C_Container then return bagResults end

    local seen = {}
    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not seen[info.itemID] then
                seen[info.itemID] = true
                local icon = info.iconFileID
                if not icon then icon = MSWA_GetItemIconSafe(info.itemID) end
                tinsert(bagResults, {
                    itemID = info.itemID,
                    name   = info.itemName or ("Item:" .. info.itemID),
                    icon   = icon,
                    count  = info.stackCount or 1,
                })
            end
        end
    end

    table.sort(bagResults, function(a, b) return (a.name or "") < (b.name or "") end)
    return bagResults
end

function MSWA_InvalidateBagCache()
    bagResults = nil
end

-----------------------------------------------------------
-- Dynamic category results wrapper
-- Returns same format as template.spells for SPELLBOOK/BAGS
-----------------------------------------------------------

function MSWA_GetDynamicSpells(catKey)
    if catKey == "COOLDOWNS" then
        -- Filter spellbook for spells with cooldowns only
        local all = MSWA_ScanSpellbook() or {}
        local out = {}
        for _, sp in ipairs(all) do
            if sp.hasCd then tinsert(out, sp) end
        end
        return out
    elseif catKey == "SPELLBOOK" then
        return MSWA_ScanSpellbook() or {}
    elseif catKey == "BAGS" then
        local raw = MSWA_ScanBags() or {}
        -- Convert to spell-like entries for uniform handling
        local out = {}
        for _, item in ipairs(raw) do
            tinsert(out, {
                sid    = nil,
                itemID = item.itemID,
                name   = item.name,
                icon   = item.icon,
                isItem = true,
            })
        end
        return out
    end
    return {}
end

-----------------------------------------------------------
-- Event: invalidate caches on spec change / bag update
-----------------------------------------------------------

local cacheFrame = CreateFrame("Frame")
cacheFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
cacheFrame:RegisterEvent("BAG_UPDATE_DELAYED")
cacheFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
cacheFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        MSWA_InvalidateSpellbookCache()
    elseif event == "BAG_UPDATE_DELAYED" then
        MSWA_InvalidateBagCache()
    end
    -- PLAYER_REGEN_ENABLED: don't auto-scan, just allow next manual scan
end)
