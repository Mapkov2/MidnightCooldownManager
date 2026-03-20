-- MSA_TargetDebuffs.lua - EQoL GetUnitAuras("target","HARMFUL") pattern

local type = type
local GetTime = GetTime
local wipe = wipe or table.wipe
local _issv = _G.issecretvalue

local _cache = {}
local _tick  = -1
local _pguid = nil
local hasGUA = C_UnitAuras and C_UnitAuras.GetUnitAuras

local gf = CreateFrame("Frame")
gf:RegisterEvent("PLAYER_LOGIN")
gf:RegisterEvent("PLAYER_ENTERING_WORLD")
gf:SetScript("OnEvent", function() _pguid = UnitGUID and UnitGUID("player") end)

local function Rebuild()
    local now = GetTime()
    if now == _tick then return end
    _tick = now
    wipe(_cache)
    if not hasGUA or not UnitExists("target") then return end
    local auras = C_UnitAuras.GetUnitAuras("target", "HARMFUL")
    if type(auras) ~= "table" then return end
    for i = 1, #auras do
        local a = auras[i]
        if a then
            local sid = a.spellId
            if sid and not (_issv and _issv(sid)) and not _cache[sid] then
                _cache[sid] = a
            end
        end
    end
end

function MSWA_InvalidateTargetDebuffCache() _tick = -1 end

function MSWA_GetTargetAuraDataBySpellID(spellID, onlyMine)
    if not spellID then return nil end
    Rebuild()
    local data = _cache[spellID]
    if not data then return nil end
    if onlyMine then
        local src = data.sourceUnit
        if src then
            if _issv and _issv(src) then return data end
            if src ~= "player" then
                if not _pguid then _pguid = UnitGUID and UnitGUID("player") end
                if _pguid and data.casterGUID then
                    if _issv and _issv(data.casterGUID) then return data end
                    if data.casterGUID ~= _pguid then return nil end
                else return nil end
            end
        end
    end
    return data
end
