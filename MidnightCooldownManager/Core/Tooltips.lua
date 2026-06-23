local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]
if not CDM then return end

local IsSafeNumber = CDM.IsSafeNumber
local GameTooltip = _G.GameTooltip
local InCombatLockdown = InCombatLockdown
local pcall = pcall
local pendingInstallFrames = setmetatable({}, { __mode = "k" })
local pendingInstallRegistered = false
local VIEWERS = CDM.CONST and CDM.CONST.VIEWERS or {}

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

local HideTooltip

local function ReadTooltipToggle(key)
    if CDM.db and CDM.db[key] ~= nil then
        return CDM.db[key] == true
    end
    if CDM.defaults and CDM.defaults[key] ~= nil then
        return CDM.defaults[key] == true
    end
    return true
end

local function IsBuffTooltipFrame(frame)
    local viewerName = frame and frame.cdmViewerName
    return viewerName == VIEWERS.BUFF or viewerName == VIEWERS.BUFF_BAR
end

local function IsMCDMTooltipCategoryEnabled(frame)
    if IsBuffTooltipFrame(frame) then
        return ReadTooltipToggle("tooltipsBuffsEnabled")
    end
    return ReadTooltipToggle("tooltipsCooldownsEnabled")
end

local function ShowResolvedTooltip(ownerFrame)
    local tooltip = GameTooltip or _G.GameTooltip
    if not tooltip then return end

    local dataFrame = (ownerFrame and ownerFrame.cdmTooltipOwner) or ownerFrame
    if not IsMCDMTooltipCategoryEnabled(dataFrame) then
        HideTooltip()
        return
    end

    local kind, id = ResolveTooltipIDs(dataFrame)
    if not kind then return end

    tooltip:Hide()
    SetTooltipOwner(tooltip, ownerFrame)

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

HideTooltip = function()
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

    local hitbox = frame.cdmTooltipHitbox
    if not hitbox then
        local ok, created = pcall(CreateFrame, "Frame", nil, frame)
        if not ok or not created then
            QueueInstallAfterCombat(frame, tooltipAnchor)
            return
        end
        hitbox = created
        frame.cdmTooltipHitbox = hitbox
        hitbox.cdmTooltipOwner = frame
    end

    local ok = pcall(hitbox.ClearAllPoints, hitbox)
    if ok then
        ok = pcall(hitbox.SetAllPoints, hitbox, frame)
    end
    if not ok then
        QueueInstallAfterCombat(frame, tooltipAnchor)
        return
    end

    if hitbox.SetFrameLevel and frame.GetFrameLevel then
        pcall(hitbox.SetFrameLevel, hitbox, (frame:GetFrameLevel() or 0) + 20)
    end

    if hitbox.EnableMouse then
        ok = pcall(hitbox.EnableMouse, hitbox, true)
        if not ok then
            QueueInstallAfterCombat(frame, tooltipAnchor)
            return
        end
    end
    if hitbox.SetMouseMotionEnabled then
        ok = pcall(hitbox.SetMouseMotionEnabled, hitbox, true)
        if not ok then
            QueueInstallAfterCombat(frame, tooltipAnchor)
            return
        end
    end

    if hitbox.SetScript then
        ok = pcall(hitbox.SetScript, hitbox, "OnEnter", ShowResolvedTooltip)
        if ok then
            ok = pcall(hitbox.SetScript, hitbox, "OnLeave", HideTooltip)
        end
    else
        ok = false
    end

    if not ok then
        QueueInstallAfterCombat(frame, tooltipAnchor)
        return
    end

    pendingInstallFrames[frame] = nil
    frame.cdmRuntimeTooltipInstalled = true
    hitbox.cdmTooltipAnchor = tooltipAnchor
end

function CDM:RefreshRuntimeTooltip(frame)
    if not frame then return end
    local hitbox = frame.cdmTooltipHitbox
    if hitbox and hitbox:IsMouseOver() then
        ShowResolvedTooltip(hitbox)
    end
end

function CDM:HideRuntimeTooltip()
    HideTooltip()
end
