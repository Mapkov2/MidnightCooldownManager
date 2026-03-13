-- ########################################################
-- MSA_Sound.lua
-- Per-aura sound effects on cooldown start / ready
-- Zero cost when no sounds configured (nil-check only).
-- ########################################################

local pairs, type, tostring = pairs, type, tostring
local PlaySoundFile = PlaySoundFile
local wipe = wipe or table.wipe

-----------------------------------------------------------
-- Built-in WoW sounds (always available, no library needed)
-----------------------------------------------------------

local BUILTIN_SOUNDS = {
    { key = "NONE",                label = "-- None --",               path = nil },
    { key = "BLIZZ_READY_CHECK",   label = "Ready Check",             path = "Sound\\Interface\\RaidWarning.ogg" },
    { key = "BLIZZ_ALARM1",        label = "Alarm Clock 1",           path = "Sound\\Interface\\AlarmClockWarning1.ogg" },
    { key = "BLIZZ_ALARM2",        label = "Alarm Clock 2",           path = "Sound\\Interface\\AlarmClockWarning2.ogg" },
    { key = "BLIZZ_ALARM3",        label = "Alarm Clock 3",           path = "Sound\\Interface\\AlarmClockWarning3.ogg" },
    { key = "BLIZZ_LEVELUP",       label = "Level Up",                path = "Sound\\Interface\\LevelUp.ogg" },
    { key = "BLIZZ_MAPPIN",        label = "Map Ping",                path = "Sound\\Interface\\MapPing.ogg" },
    { key = "BLIZZ_PVPFLAG",       label = "PvP Flag Taken",          path = "Sound\\Interface\\PVPFlagTaken.ogg" },
    { key = "BLIZZ_QUESTCOMPLETE", label = "Quest Complete",          path = "Sound\\Interface\\iQuestComplete.ogg" },
    { key = "BLIZZ_POWERAURA",     label = "Power Aura",              path = "Sound\\Spells\\ShaysBell.ogg" },
    { key = "BLIZZ_AGGRO",         label = "Aggro Warning",           path = "Sound\\Interface\\RaidBossWarning.ogg" },
    { key = "BLIZZ_HEROISM",       label = "Heroism",                 path = "Sound\\Spells\\Heroism_Cast.ogg" },
    { key = "BLIZZ_NETHERSTRIKE",  label = "Nether Strike",           path = "Sound\\Spells\\NetherStrike.ogg" },
    { key = "BLIZZ_PVPWARNING",    label = "PvP Warning",             path = "Sound\\Spells\\PVPWarningAlliance.ogg" },
    { key = "BLIZZ_ENERGIZE",      label = "Energize",                path = "Sound\\Spells\\Energize.ogg" },
}

-----------------------------------------------------------
-- Sound channel options
-----------------------------------------------------------

local SOUND_CHANNELS = {
    { key = "Master",   label = "Master" },
    { key = "SFX",      label = "Sound Effects" },
    { key = "Music",    label = "Music" },
    { key = "Ambience", label = "Ambience" },
    { key = "Dialog",   label = "Dialog" },
}

-----------------------------------------------------------
-- Custom addon sounds (Media folder)
-- Path prefix: Interface\AddOns\MidnightSimpleAuras\Media\
-- Add your own .ogg files here:
--   { "FileName.ogg", "Display Name" },
-----------------------------------------------------------

local MEDIA_PATH = "Interface\\AddOns\\MidnightSimpleAuras\\Media\\"

local CUSTOM_ADDON_SOUNDS = {
    { "BrrrCar.ogg",      "BrrrCar" },
    { "Formula_One.ogg",  "Formula One" },
    -- Add more: { "MySound.ogg", "My Sound" },
}

-----------------------------------------------------------
-- Cached choices list (rebuilt once on first access)
-----------------------------------------------------------

local soundChoices      -- array of { key, label, path }
local soundPathCache = {} -- key -> path (fast lookup)

local function RebuildSoundChoices()
    soundChoices = {}
    soundPathCache = {}

    -- 1) Built-ins first
    for _, entry in pairs(BUILTIN_SOUNDS) do
        soundChoices[#soundChoices + 1] = entry
        if entry.path then
            soundPathCache[entry.key] = entry.path
        end
    end

    -- 2) Custom addon sounds (Media folder)
    for i = 1, #CUSTOM_ADDON_SOUNDS do
        local file, label = CUSTOM_ADDON_SOUNDS[i][1], CUSTOM_ADDON_SOUNDS[i][2]
        local key  = "MSA:" .. file
        local path = MEDIA_PATH .. file
        soundChoices[#soundChoices + 1] = { key = key, label = "|cff44ddff" .. label .. "|r", path = path }
        soundPathCache[key] = path
    end

    -- 3) LibSharedMedia sounds (if available)
    local LSM = MSWA and MSWA.LSM
    if LSM and LSM.List then
        local list = LSM:List("sound")
        if type(list) == "table" then
            for i = 1, #list do
                local name = list[i]
                local path = LSM:Fetch("sound", name)
                if name and path then
                    local key = "LSM:" .. name
                    soundChoices[#soundChoices + 1] = { key = key, label = name, path = path }
                    soundPathCache[key] = path
                end
            end
        end
    end
end

-----------------------------------------------------------
-- Public API: choices + channel lists
-----------------------------------------------------------

function MSWA_GetSoundChoices()
    if not soundChoices then RebuildSoundChoices() end
    return soundChoices
end

function MSWA_GetSoundChannels()
    return SOUND_CHANNELS
end

-----------------------------------------------------------
-- Resolve key -> file path (cached)
-----------------------------------------------------------

function MSWA_GetSoundPath(key)
    if not key or key == "NONE" then return nil end
    if not soundChoices then RebuildSoundChoices() end
    return soundPathCache[key]
end

-----------------------------------------------------------
-- Play a sound by key
-----------------------------------------------------------

function MSWA_PlaySound(key, channel)
    local path = MSWA_GetSoundPath(key)
    if not path then return end
    PlaySoundFile(path, channel or "Master")
end

-----------------------------------------------------------
-- Transition detection (called from UpdateEngine)
--
-- Per aura KEY state tracking (not per button).
-- GCD filter: "CD start" only fires when duration > 1.5s,
-- with issecretvalue guard (secret durations = real CDs).
-- Duration query only on actual transitions (rare path).
-----------------------------------------------------------

local _soundState = {}          -- key -> true/false (last known CD state)
local GCD_THRESHOLD = 1.5
local _issv = _G.issecretvalue

-- Query actual CD duration for a key (spell or item).
-- Called ONLY on transitions (rare path), not per-frame.
local function GetKeyDuration(key)
    if type(key) == "number" then
        -- Spell ID
        if C_Spell and C_Spell.GetSpellCooldown then
            local info = C_Spell.GetSpellCooldown(key)
            return info and info.duration
        end
    elseif type(key) == "string" then
        -- Item key: "item:ID" or "item:ID:N"
        local itemID = tonumber(key:match("^item:(%d+)"))
        if itemID and GetItemCooldown then
            local _, dur = GetItemCooldown(itemID)
            return dur
        end
    end
    return nil
end

-- Returns true if duration represents a real cooldown (not GCD).
-- Secret values are trusted as real CDs.
local function IsRealCooldown(duration)
    if not duration then return false end
    if _issv and _issv(duration) then return true end
    return (type(duration) == "number") and (duration > GCD_THRESHOLD)
end

function MSWA_CheckSoundTransition(key, onCD, s)
    -- Fast exit: no sound configured on this aura
    if not s then return end
    local hasStart = s.soundOnStart and s.soundOnStart ~= "NONE"
    local hasReady = s.soundOnReady and s.soundOnReady ~= "NONE"
    if not hasStart and not hasReady then return end

    local prev = _soundState[key]
    local nowCD = onCD and true or false

    -- First encounter for this key: seed state, no sound
    if prev == nil then
        _soundState[key] = nowCD
        return
    end

    if nowCD == prev then return end -- no transition

    _soundState[key] = nowCD

    if nowCD and not prev then
        -- OFF -> ON: verify this is a real CD (not just GCD)
        if hasStart then
            local dur = GetKeyDuration(key)
            if IsRealCooldown(dur) then
                MSWA_PlaySound(s.soundOnStart, s.soundChannel)
            end
        end
    elseif prev and not nowCD then
        -- ON -> OFF: spell ready (no GCD filter needed,
        -- GCD ON-transitions are suppressed above so state
        -- stays false during GCD -> no false "ready" trigger)
        if hasReady then
            MSWA_PlaySound(s.soundOnReady, s.soundChannel)
        end
    end
end

-----------------------------------------------------------
-- Wipe all sound state (call on login / profile switch)
-----------------------------------------------------------

function MSWA_WipeSoundState()
    wipe(_soundState)
end
