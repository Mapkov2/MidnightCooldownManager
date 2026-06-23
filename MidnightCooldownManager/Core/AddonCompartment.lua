local AddonName = "MidnightCooldownManager"

function MCDM_AddonCompartment_OnClick()
    local CDM = _G[AddonName]
    if CDM and CDM.RequestConfigOpen then
        CDM:RequestConfigOpen("compartment", nil)
    end
end

function MCDM_AddonCompartment_OnEnter(button)
    if not GameTooltip or not button then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText("Midnight Simple Cooldown", 1, 1, 1)
    GameTooltip:AddLine("/mcdm", 0.35, 0.82, 1)
    GameTooltip:AddLine("/mcdm move", 0.35, 0.82, 1)
    GameTooltip:Show()
end

function MCDM_AddonCompartment_OnLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end
