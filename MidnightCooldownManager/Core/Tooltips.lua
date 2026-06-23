local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]
if not CDM then return end

local IsSafeNumber = CDM.IsSafeNumber
local GameTooltip = _G.GameTooltip
local InCombatLockdown = InCombatLockdown
local pcall = pcall
local pendingInstallFrames = setmetatable({}, { __mode = "k" })
local pendingInstallRegistered = false

local function ValidID(id)
    return IsSafeNumber(id) and id > 0
end

local function ResolveTooltipIDs(frame)
    if not frame then return nil, nil end

    local itemID = frame.itemID
    if ValidID(itemID) then
        return "item", itemID
    end

    local record = CDM.GetFrameCooldownRecord and CDM:GetFrameCooldownRecord(frame)
    if record then
        itemID = record.itemID
        if ValidID(itemID) then
            return "item", itemID
        end

        local spellID = record.overrideTooltipSpellID
            or record.displaySpellID
            or record.overrideSpellID
            or record.spellID
            or record.baseSpellID
        if ValidID(spellID) then
            return "spell", spellID
        end
    end

    local spellID = frame.spellID or frame.itemSpellID
    if ValidID(spellID) then
        return "spell", spellID
    end

    return nil, nil
end

local function SetTooltipOwner(tooltip, frame)
    local anchor = frame.cdmTooltipAnchor or "ANCHOR_RIGHT"
    tooltip:SetOwner(frame, anchor)
end

local function ShowResolvedTooltip(frame)
    local tooltip = GameTooltip or _G.GameTooltip
    if not tooltip then return end

    local kind, id = ResolveTooltipIDs(frame)
    if not kind then return end

    tooltip:Hide()
    SetTooltipOwner(tooltip, frame)

    local ok
    if kind == "item" then
        if tooltip.SetItemByID then
            ok = pcall(tooltip.SetItemByID, tooltip, id)
        end
        if not ok and tooltip.SetHyperlink then
            ok = pcall(tooltip.SetHyperlink, tooltip, "item:" .. tostring(id))
        end
    elseif tooltip.SetSpellByID then
        ok = pcall(tooltip.SetSpellByID, tooltip, id)
    end

    if ok then
        tooltip:Show()
    else
        tooltip:Hide()
    end
end

local function HideTooltip()
    local tooltip = GameTooltip or _G.GameTooltip
    if tooltip then
        tooltip:Hide()
    end
end

local function RetryPendingInstalls()
    for frame, anchor in pairs(pendingInstallFrames) do
        pendingInstallFrames[frame] = nil
        if frame and frame.IsObjectType then
            CDM:InstallRuntimeTooltip(frame, anchor)
        end
    end
end

local function QueueInstallAfterCombat(frame, anchor)
    pendingInstallFrames[frame] = anchor or "ANCHOR_RIGHT"
    if pendingInstallRegistered then return end
    pendingInstallRegistered = true
    CDM:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        RetryPendingInstalls()
    end)
end

function CDM:InstallRuntimeTooltip(frame, anchor)
    if not frame or frame.cdmRuntimeTooltipInstalled then return end

    if InCombatLockdown and InCombatLockdown()
       and frame.IsProtected and frame:IsProtected() then
        QueueInstallAfterCombat(frame, anchor or frame.cdmTooltipAnchor or "ANCHOR_RIGHT")
        return
    end

    local tooltipAnchor = anchor or frame.cdmTooltipAnchor or "ANCHOR_RIGHT"

    if frame.EnableMouse then
        local ok = pcall(frame.EnableMouse, frame, true)
        if not ok then
            QueueInstallAfterCombat(frame, tooltipAnchor)
            return
        end
    end
    if frame.SetMouseMotionEnabled then
        local ok = pcall(frame.SetMouseMotionEnabled, frame, true)
        if not ok then
            QueueInstallAfterCombat(frame, tooltipAnchor)
            return
        end
    end

    local ok
    if frame.HookScript then
        ok = pcall(frame.HookScript, frame, "OnEnter", ShowResolvedTooltip)
        if ok then
            ok = pcall(frame.HookScript, frame, "OnLeave", HideTooltip)
        end
    else
        ok = pcall(frame.SetScript, frame, "OnEnter", ShowResolvedTooltip)
        if ok then
            ok = pcall(frame.SetScript, frame, "OnLeave", HideTooltip)
        end
    end

    if not ok then
        QueueInstallAfterCombat(frame, tooltipAnchor)
        return
    end

    pendingInstallFrames[frame] = nil
    frame.cdmRuntimeTooltipInstalled = true
    frame.cdmTooltipAnchor = tooltipAnchor
end

function CDM:RefreshRuntimeTooltip(frame)
    if not frame then return end
    if frame.cdmRuntimeTooltipInstalled and frame:IsMouseOver() then
        ShowResolvedTooltip(frame)
    end
end
