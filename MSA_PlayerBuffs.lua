-- ########################################################
-- MSA_PlayerBuffs.lua  (v5 - stubs only)
--
-- All buff tracking events and cache logic have been moved
-- to MSA_BuffBridge.lua (event-driven architecture).
--
-- This file retains only:
--   1) Stub functions referenced by Options/legacy code
--   2) Legacy compat: ns.PlayerBuffs.UpdateIcon
-- ########################################################

local ADDON_NAME, ns = ...
local type = type

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
        -- Cooldown: secret-safe via BuffBridge
        local cd = iconFrame.cooldown
        if cd then
            MSWA_ApplyAuraCooldown(cd, auraData)
        end
    else
        iconFrame.icon:SetDesaturated(true)
        iconFrame.icon:SetVertexColor(0.35, 0.35, 0.35)
        if iconFrame.count then iconFrame.count:SetText(""); iconFrame.count:Hide() end
        if iconFrame.stackText then iconFrame.stackText:SetText(""); iconFrame.stackText:Hide() end
        if iconFrame.cooldown then MSWA_ClearCooldownFrame(iconFrame.cooldown) end
    end
end
