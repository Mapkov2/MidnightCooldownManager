-- ########################################################
-- MSA_NonSecretSpells.lua
--
-- Whitelist of spell IDs that Blizzard has marked as
-- non-secret in Midnight 12.0.  For these spells, aura
-- data fields (duration, expirationTime, stacks, etc.)
-- are plain Lua values — NO pcall needed for comparisons.
--
-- Structure: flat hash set  →  O(1) lookup, zero GC
-- Maintenance: add/remove IDs here, rest of addon adapts.
-- ########################################################

local NON_SECRET = {}

-----------------------------------------------------------
-- Healer HoTs / Absorbs
-----------------------------------------------------------

-- Preservation Evoker
NON_SECRET[355941] = true   -- Dream Breath
NON_SECRET[363502] = true   -- Dream Flight
NON_SECRET[364343] = true   -- Echo
NON_SECRET[366155] = true   -- Reversion
NON_SECRET[367364] = true   -- Echo Reversion
NON_SECRET[373267] = true   -- Lifebind
NON_SECRET[376788] = true   -- Echo Dream Breath

-- Augmentation Evoker
NON_SECRET[360827] = true   -- Blistering Scales
NON_SECRET[395152] = true   -- Ebon Might
NON_SECRET[410089] = true   -- Prescience
NON_SECRET[410263] = true   -- Inferno's Blessing
NON_SECRET[410686] = true   -- Symbiotic Bloom
NON_SECRET[413984] = true   -- Shifting Sands

-- Resto Druid
NON_SECRET[774]    = true   -- Rejuv
NON_SECRET[8936]   = true   -- Regrowth
NON_SECRET[33763]  = true   -- Lifebloom
NON_SECRET[48438]  = true   -- Wild Growth
NON_SECRET[155777] = true   -- Germination

-- Disc Priest
NON_SECRET[17]      = true  -- Power Word: Shield
NON_SECRET[194384]  = true  -- Atonement
NON_SECRET[1253593] = true  -- Void Shield

-- Holy Priest
NON_SECRET[139]   = true    -- Renew
NON_SECRET[41635] = true    -- Prayer of Mending
NON_SECRET[77489] = true    -- Echo of Light

-- Mistweaver Monk
NON_SECRET[115175] = true   -- Soothing Mist
NON_SECRET[119611] = true   -- Renewing Mist
NON_SECRET[124682] = true   -- Enveloping Mist
NON_SECRET[450769] = true   -- Aspect of Harmony

-- Restoration Shaman
NON_SECRET[974]    = true   -- Earth Shield
NON_SECRET[383648] = true   -- Earth Shield (alt ID)
NON_SECRET[61295]  = true   -- Riptide

-- Holy Paladin
NON_SECRET[53563]   = true  -- Beacon of Light
NON_SECRET[156322]  = true  -- Eternal Flame
NON_SECRET[156910]  = true  -- Beacon of Faith
NON_SECRET[1244893] = true  -- Beacon of the Savior

-----------------------------------------------------------
-- Long-term Raid Buffs
-----------------------------------------------------------
NON_SECRET[1126]   = true   -- Mark of the Wild
NON_SECRET[1459]   = true   -- Arcane Intellect
NON_SECRET[6673]   = true   -- Battle Shout
NON_SECRET[21562]  = true   -- Power Word: Fortitude
NON_SECRET[369459] = true   -- Source of Magic
NON_SECRET[462854] = true   -- Skyfury
NON_SECRET[474754] = true   -- Symbiotic Relationship

-----------------------------------------------------------
-- Blessing of the Bronze Auras (per-class variants)
-----------------------------------------------------------
NON_SECRET[381732] = true   -- Death Knight
NON_SECRET[381741] = true   -- Demon Hunter
NON_SECRET[381746] = true   -- Druid
NON_SECRET[381748] = true   -- Evoker
NON_SECRET[381749] = true   -- Hunter
NON_SECRET[381750] = true   -- Mage
NON_SECRET[381751] = true   -- Monk
NON_SECRET[381752] = true   -- Paladin
NON_SECRET[381753] = true   -- Priest
NON_SECRET[381754] = true   -- Rogue
NON_SECRET[381756] = true   -- Shaman
NON_SECRET[381757] = true   -- Warlock
NON_SECRET[381758] = true   -- Warrior

-----------------------------------------------------------
-- Long-term Self Buffs
-----------------------------------------------------------
NON_SECRET[433568] = true   -- Rite of Sanctification
NON_SECRET[433583] = true   -- Rite of Adjuration

-----------------------------------------------------------
-- Rogue Poisons
-----------------------------------------------------------
NON_SECRET[2823]   = true   -- Deadly Poison
NON_SECRET[8679]   = true   -- Wound Poison
NON_SECRET[3408]   = true   -- Crippling Poison
NON_SECRET[5761]   = true   -- Numbing Poison
NON_SECRET[315584] = true   -- Instant Poison
NON_SECRET[381637] = true   -- Atrophic Poison
NON_SECRET[381664] = true   -- Amplifying Poison

-----------------------------------------------------------
-- Shaman Imbuements
-----------------------------------------------------------
NON_SECRET[319773] = true   -- Windfury Weapon
NON_SECRET[319778] = true   -- Flametongue Weapon
NON_SECRET[382021] = true   -- Earthliving Weapon
NON_SECRET[382022] = true   -- Earthliving Weapon (alt)
NON_SECRET[457496] = true   -- Tidecaller's Guard
NON_SECRET[457481] = true   -- Tidecaller's Guard (alt)
NON_SECRET[462757] = true   -- Thunderstrike Ward
NON_SECRET[462742] = true   -- Thunderstrike Ward (alt)

-----------------------------------------------------------
-- Resource-like Auras
-----------------------------------------------------------
NON_SECRET[205473] = true   -- Mage Icicles
NON_SECRET[260286] = true   -- Hunter Tip of the Spear

-----------------------------------------------------------
-- Cooldowns
-----------------------------------------------------------
NON_SECRET[8690]  = true    -- Hearthstone
NON_SECRET[20608] = true    -- Shaman Reincarnation

-----------------------------------------------------------
-- Public API
-----------------------------------------------------------

-- O(1) lookup. Returns true if spellID values are plain
-- Lua (safe for direct comparison), false/nil if secret.
function MSWA_IsNonSecret(spellID)
    return NON_SECRET[spellID]
end

-- Expose table for bulk iteration (export/debug tools)
MSWA_NON_SECRET_SPELLS = NON_SECRET
