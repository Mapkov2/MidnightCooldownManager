-- ########################################################
-- MSA_PlayerBuffs.lua  (v3 - minimal event relay)
--
-- Buff tracking is done DIRECTLY in UpdateEngine hot-path
-- via C_UnitAuras.GetAuraDataBySpellID() - like WeakAuras.
--
-- This file only provides:
--   1) UNIT_AURA event relay -> triggers UpdateEngine redraw
--   2) Legacy compat: ns.PlayerBuffs.UpdateIcon
--   3) Stub functions so Options code doesn't error
--
-- Zero pcall. Zero state. Zero registration.
-- ########################################################

local ADDON_NAME, ns = ...
local type = type

-----------------------------------------------------------
-- Event relay: UNIT_AURA on player -> trigger redraw
-----------------------------------------------------------

local relay = CreateFrame("Frame", "MSWA_BuffEventFrame", UIParent)
relay:RegisterEvent("UNIT_AURA")
relay:RegisterEvent("PLAYER_ENTERING_WORLD")

relay:SetScript("OnEvent", function(_, event, arg1)
    if event == "UNIT_AURA" then
        if arg1 == "player" then
            -- Invalidate per-frame cache so next poll gets fresh data
            if MSWA_InvalidateBuffCache then MSWA_InvalidateBuffCache() end
            if MSWA_RequestUpdateSpells then MSWA_RequestUpdateSpells() end
        end
        return
    end
    -- PLAYER_ENTERING_WORLD: trigger initial draw
    if MSWA_InvalidateBuffCache then MSWA_InvalidateBuffCache() end
    if MSWA_RequestUpdateSpells then
        MSWA_RequestUpdateSpells()
    end
end)

-----------------------------------------------------------
-- Stub functions (Options code references these)
-----------------------------------------------------------

function MSWA_RegisterBuffWatch()   end
function MSWA_UnregisterBuffWatch() end
function MSWA_ClearAllBuffWatches() end
function MSWA_FullBuffRescan()      end
function MSWA_BuffBootstrap()       end

-----------------------------------------------------------
-- Legacy compat: ns.PlayerBuffs.UpdateIcon
-----------------------------------------------------------

local PB = ns.PlayerBuffs or {}
ns.PlayerBuffs = PB

function PB.UpdateIcon(iconFrame, spellID)
    if not iconFrame or not spellID then return end

    local auraData = MSWA_GetPlayerAuraDataBySpellID(spellID)
    if auraData then
        iconFrame.icon:SetDesaturated(false)
        iconFrame.icon:SetVertexColor(1, 1, 1)
        -- Stacks via wrapper
        local sText = MSWA_GetAuraStackText(auraData, 2)
        local target = iconFrame.stackText or iconFrame.count
        if target then
            if sText then target:SetText(sText); target:Show()
            else target:SetText(""); target:Hide() end
        end
        -- Cooldown: EQoL issecretvalue pattern
        local cd = iconFrame.cooldown
        if cd then
            local dur = auraData.duration
            local exp = auraData.expirationTime
            local isSecret = MSWA_IsSecretValue(dur) or MSWA_IsSecretValue(exp)
            if isSecret and cd.SetCooldownFromExpirationTime then
                cd:SetCooldownFromExpirationTime(exp, dur, auraData.timeMod)
                cd.__mswaSet = true
            elseif dur and dur > 0 and exp then
                cd:SetCooldown(exp - dur, dur)
                cd.__mswaSet = true
            else
                MSWA_ClearCooldownFrame(cd)
            end
        end
    else
        iconFrame.icon:SetDesaturated(true)
        iconFrame.icon:SetVertexColor(0.35, 0.35, 0.35)
        if iconFrame.count then iconFrame.count:SetText(""); iconFrame.count:Hide() end
        if iconFrame.stackText then iconFrame.stackText:SetText(""); iconFrame.stackText:Hide() end
        if iconFrame.cooldown then MSWA_ClearCooldownFrame(iconFrame.cooldown) end
    end
end
