local ADDON_NAME, ns = ...

-- Player-buff tracking helpers (Midnight/Beta secret-safe)
-- v5: Non-secret whitelist spells skip pcall entirely
-- pcall only where Midnight secret values require it

local PB = ns.PlayerBuffs or {}
ns.PlayerBuffs = PB

local pcall, type = pcall, type

-- v6: Named function for pcall — eliminates closure allocation
local function _expMinusDur(exp, dur)
    return exp - dur
end

local function ClearCooldown(cd)
    if not cd then return end
    cd.__mswaSet = false
    if cd.Clear then
        cd:Clear()
    elseif CooldownFrame_Clear then
        CooldownFrame_Clear(cd)
    elseif cd.SetCooldown then
        cd:SetCooldown(0, 0)
    end
end

local function ApplyCooldownFromAura(cd, aura, spellID)
    if not cd or not aura then return end

    local exp = aura.expirationTime
    local dur = aura.duration
    local mod = aura.timeMod or 1

    -- v5: Non-secret spells → direct calls, zero pcall
    local safe = spellID and MSWA_IsNonSecret(spellID)

    if cd.SetCooldownFromExpirationTime and exp ~= nil and dur ~= nil then
        if safe then
            cd:SetCooldownFromExpirationTime(exp, dur, mod)
            cd.__mswaSet = true; return
        end
        local ok = pcall(cd.SetCooldownFromExpirationTime, cd, exp, dur, mod)
        if ok then cd.__mswaSet = true; return end
    end

    if cd.SetCooldown and exp ~= nil and dur ~= nil then
        if safe then
            local startTime = exp - dur
            cd:SetCooldown(startTime, dur, mod)
            cd.__mswaSet = true; return
        end
        local ok, startTime = pcall(_expMinusDur, exp, dur)
        if ok then
            local ok2 = pcall(cd.SetCooldown, cd, startTime, dur, mod)
            if ok2 then cd.__mswaSet = true; return end
        end
    end

    ClearCooldown(cd)
end

-- Reuse SpellAPI functions (already pcall-safe)
local function GetPlayerAura(spellID)
    return MSWA_GetPlayerAuraDataBySpellID(spellID)
end

local function GetStackText(aura, minCount, spellID)
    return MSWA_GetAuraStackText(aura, minCount, spellID)
end

function PB.UpdateIcon(iconFrame, spellID)
    if not iconFrame or not spellID then return end

    local aura = GetPlayerAura(spellID)

    if aura then
        iconFrame.icon:SetDesaturated(false)
        iconFrame.icon:SetVertexColor(1, 1, 1)

        local stackText = GetStackText(aura, 2, spellID)
        local target = iconFrame.stackText or iconFrame.count
        if target then
            if type(stackText) == "string" then
                target:SetText(stackText); target:Show()
            else
                target:SetText(""); target:Hide()
            end
        end
        if iconFrame.stackText and iconFrame.count and iconFrame.stackText ~= iconFrame.count then
            iconFrame.count:SetText(""); iconFrame.count:Hide()
        end

        if iconFrame.cooldown then
            ApplyCooldownFromAura(iconFrame.cooldown, aura, spellID)
        end
    else
        iconFrame.icon:SetDesaturated(true)
        iconFrame.icon:SetVertexColor(0.35, 0.35, 0.35)

        if iconFrame.count then iconFrame.count:SetText(""); iconFrame.count:Hide() end
        if iconFrame.stackText then iconFrame.stackText:SetText(""); iconFrame.stackText:Hide() end

        if iconFrame.cooldown then
            ClearCooldown(iconFrame.cooldown)
        end
    end
end
