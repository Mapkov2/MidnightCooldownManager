local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local Pixel = CDM.Pixel
local Snap = Pixel.Snap

local layoutCtx = CDM._LayoutCtx
local PositionFrameAtSlot = layoutCtx.PositionFrameAtSlot
local DeriveSelfPoint = layoutCtx.DeriveSelfPoint

local framePool = {}
local activeFrames = {}
local activeFramesBySpell = {}
local previewEntries = {}
local previewAdjustedLiveFrames = false

local function RestoreLiveFramesIfNeeded()
    if not previewAdjustedLiveFrames then return end
    previewAdjustedLiveFrames = false

    local viewer = CDM:GetCooldownViewerFrame(CDM_C.VIEWERS.BUFF)
    if not viewer then return end
    if CDM.RepositionBuffViewer then
        CDM:RepositionBuffViewer(viewer)
    elseif CDM.ForceReanchor then
        CDM:ForceReanchor(viewer)
    end
end

local function ReleasePreviewFrame(frame)
    if CDM.Glow then
        CDM.Glow:RequestBuffGlow(frame, "buff-preview", false, nil, nil)
    end
    frame:Hide()
    frame:ClearAllPoints()
    frame.cdmAnchor = nil
    if frame:GetParent() ~= UIParent then
        frame:SetParent(UIParent)
    end
    framePool[#framePool + 1] = frame
end

local function ClearPreviewFrames(restoreLiveFrames)
    for i = #activeFrames, 1, -1 do
        ReleasePreviewFrame(activeFrames[i])
        activeFrames[i] = nil
    end
    if restoreLiveFrames then
        RestoreLiveFramesIfNeeded()
    end
end

function CDM:HideBuffGroupSelectionPreview()
    ClearPreviewFrames(true)
end

local function EnsureFont(fontString, size)
    if not fontString then return end
    local fontPath = CDM_C.GetBaseFontPath and CDM_C.GetBaseFontPath() or CDM_C.FONT_PATH or STANDARD_TEXT_FONT
    local outline = CDM_C.GetBaseFontOutline and CDM_C.GetBaseFontOutline() or "OUTLINE"
    fontString:SetFont(fontPath, Pixel.FontSize(size or 12), outline)
end

local function SetTextStyle(fontString, size, color)
    if not fontString then return end
    EnsureFont(fontString, size)
    color = color or CDM_C.WHITE or { r = 1, g = 1, b = 1, a = 1 }
    fontString:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    fontString:SetShadowOffset(0, 0)
    if fontString.SetIgnoreParentScale then
        fontString:SetIgnoreParentScale(true)
    end
end

local function AcquirePreviewFrame(parent)
    local frame = table.remove(framePool)
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetFrameStrata("MEDIUM")
        frame:SetFrameLevel(60)

        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        Pixel.DisableTextureSnap(icon)
        frame.Icon = icon

        local shade = frame:CreateTexture(nil, "OVERLAY", nil, 1)
        shade:SetAllPoints()
        shade:SetColorTexture(0, 0, 0, 0.24)
        frame.previewShade = shade

        local cdText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cdText:SetPoint("CENTER")
        cdText:SetJustifyH("CENTER")
        cdText:SetJustifyV("MIDDLE")
        frame.CooldownText = cdText

        local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        countText:SetJustifyH("CENTER")
        countText:SetJustifyV("MIDDLE")
        frame.CountText = countText

        frame.isBuffGroupSelectionPreview = true
    end

    frame:SetParent(parent or UIParent)
    frame:SetFrameLevel((parent and parent:GetFrameLevel() or 0) + 20)
    activeFrames[#activeFrames + 1] = frame
    return frame
end

local function GetCustomBuffIcon(spellID)
    local registry = CDM.db and CDM.db.customBuffRegistry
    local entry = registry and registry[spellID]
    return entry and entry.icon
end

local function GetPreviewTexture(spellID)
    return GetCustomBuffIcon(spellID)
        or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID))
        or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ResolveOverride(groupData, spellID)
    if CDM.ResolveBuffOverrideEntry then
        return CDM:ResolveBuffOverrideEntry(groupData and groupData.spellOverrides, spellID)
    end
    local overrides = groupData and groupData.spellOverrides
    return overrides and overrides[spellID]
end

local function GetBorderColor(specID, spellID)
    local color = CDM.GetSpellBorderColor and CDM:GetSpellBorderColor(specID, spellID)
    if color then
        return color.r or 1, color.g or 1, color.b or 1, color.a or 1
    end
    if CDM.GetConfiguredBorderColor then
        return CDM.GetConfiguredBorderColor()
    end
    local fallback = CDM.defaults and CDM.defaults.borderColor or { r = 0, g = 0, b = 0, a = 1 }
    return fallback.r or 0, fallback.g or 0, fallback.b or 0, fallback.a or 1
end

local function ApplyPreviewVisual(frame, groupData, spellID, specID)
    local spellOv = ResolveOverride(groupData, spellID)
    local useTextOv = spellOv and spellOv.textOverride
    local iconW = Snap(groupData.iconWidth or 30)
    local iconH = Snap(groupData.iconHeight or 30)

    frame:SetSize(iconW, iconH)
    frame.Icon:SetTexture(GetPreviewTexture(spellID))
    if CDM_C.ApplyIconTexCoord and CDM_C.GetEffectiveZoomAmount then
        CDM_C.ApplyIconTexCoord(frame.Icon, CDM_C.GetEffectiveZoomAmount(), iconW, iconH)
    end

    local hideVisuals = spellOv and spellOv.hideVisuals
    frame.Icon:SetDesaturation(1)
    frame.Icon:SetAlpha(hideVisuals and 0.14 or 0.66)
    frame.previewShade:SetShown(not hideVisuals)

    if CDM.BORDER and CDM.BORDER.CreateBorder then
        frame.cdmBorder = CDM.BORDER:CreateBorder(frame, true)
        if CDM.BORDER.activeBorders then
            CDM.BORDER.activeBorders[frame] = nil
        end
    end
    if frame.cdmBorder then
        frame.cdmBorder:SetBackdropBorderColor(GetBorderColor(specID, spellID))
        frame.cdmBorder:SetAlpha(hideVisuals and 0.45 or 0.9)
    end

    local cooldownSize = (useTextOv and spellOv.cooldownFontSize) or groupData.cooldownFontSize or 12
    local cooldownColor = (useTextOv and spellOv.cooldownColor) or groupData.cooldownColor
        or (CDM.db and CDM.db.buffCooldownColor)
    SetTextStyle(frame.CooldownText, cooldownSize, cooldownColor)
    frame.CooldownText:SetText("1.4")
    frame.CooldownText:SetShown(not (spellOv and spellOv.hideCooldown) and not hideVisuals)

    local countSize = (useTextOv and spellOv.countFontSize) or groupData.countFontSize
        or (CDM.db and CDM.db.countFontSize) or 15
    local countColor = (useTextOv and spellOv.countColor) or groupData.countColor
        or (CDM.db and CDM.db.countColor)
    local countPosition = (useTextOv and spellOv.countPosition) or groupData.countPosition or "BOTTOMRIGHT"
    local countOffsetX = (useTextOv and spellOv.countOffsetX) or groupData.countOffsetX or 0
    local countOffsetY = (useTextOv and spellOv.countOffsetY) or groupData.countOffsetY or 0

    frame.CountText:ClearAllPoints()
    Pixel.SetPoint(frame.CountText, countPosition, frame, countPosition, countOffsetX, countOffsetY)
    SetTextStyle(frame.CountText, countSize, countColor)
    frame.CountText:SetText("2")
    frame.CountText:SetShown(not hideVisuals)

    local glowEnabled = CDM.GetSpellGlowEnabled and CDM:GetSpellGlowEnabled(specID, spellID)
    local glowColor = CDM.GetSpellGlowColor and CDM:GetSpellGlowColor(specID, spellID)
    if CDM.Glow then
        CDM.Glow:RequestBuffGlow(frame, "buff-preview", glowEnabled and not hideVisuals, glowColor, spellID)
    end

    frame:SetAlpha(1)
    frame:Show()
end

local function AddActiveFrameBySpell(spellID, frame)
    if not spellID or not frame or not frame:IsShown() then return end
    if not activeFramesBySpell[spellID] then
        activeFramesBySpell[spellID] = frame
    end
end

local function CollectActiveGroupFrames(groupIndex)
    table.wipe(activeFramesBySpell)

    if CDM.ForEachActiveFrame and CDM.CheckBuffRegistryMatch then
        CDM:ForEachActiveFrame({ CDM_C.VIEWERS.BUFF }, function(frame)
            if frame:IsShown() then
                local matchType, matchID, matchedGroupIndex = CDM.CheckBuffRegistryMatch(frame)
                if matchType == "buffgroup" and matchedGroupIndex == groupIndex then
                    AddActiveFrameBySpell(matchID or frame.cdmBuffCategorySpellID, frame)
                end
            end
        end)
    end

    local customBuffs = CDM.CustomBuffs
    local grouped = CDM.BuffGroupSets and CDM.BuffGroupSets.grouped
    if customBuffs and customBuffs.activeBuffs and grouped then
        for spellID, buffData in pairs(customBuffs.activeBuffs) do
            local frame = buffData and buffData.frame
            if grouped[spellID] == groupIndex then
                AddActiveFrameBySpell(spellID, frame)
            end
        end
    end
end

local function BuildPreviewEntries(groupData, selectedSpellID)
    table.wipe(previewEntries)
    for _, spellID in ipairs(groupData.spells or {}) do
        local liveFrame = activeFramesBySpell[spellID]
        if selectedSpellID then
            if spellID == selectedSpellID or liveFrame then
                previewEntries[#previewEntries + 1] = {
                    spellID = spellID,
                    frame = liveFrame,
                    isPreview = not liveFrame,
                }
            end
        else
            previewEntries[#previewEntries + 1] = {
                spellID = spellID,
                frame = liveFrame,
                isPreview = not liveFrame,
            }
        end
    end
end

local function HasPreviewEntry()
    for _, entry in ipairs(previewEntries) do
        if entry.isPreview then
            return true
        end
    end
    return false
end

local function PositionPreviewEntries(container, groupData, specID)
    local grow = groupData.grow
    if grow ~= "RIGHT" and grow ~= "LEFT" and grow ~= "UP" and grow ~= "DOWN" and grow ~= "CENTER_H" and grow ~= "CENTER_V" then
        grow = "RIGHT"
    end

    local iconW = Snap(groupData.iconWidth or 30)
    local iconH = Snap(groupData.iconHeight or 30)
    local spacing = Snap(groupData.spacing or 4)
    local anchorPoint = groupData.anchorPoint or "CENTER"
    local selfPoint = DeriveSelfPoint(anchorPoint, grow)
    local layoutCount = #previewEntries
    if layoutCount <= 0 then return end

    container:SetSize(iconW, iconH)

    for index, entry in ipairs(previewEntries) do
        local frame = entry.frame
        if entry.isPreview then
            frame = AcquirePreviewFrame(container)
            ApplyPreviewVisual(frame, groupData, entry.spellID, specID)
        else
            previewAdjustedLiveFrames = true
        end

        if frame then
            PositionFrameAtSlot(frame, container, index - 1, iconW, iconH, spacing, grow, layoutCount, anchorPoint, selfPoint)
        end
    end
end

local function AbortPreview()
    RestoreLiveFramesIfNeeded()
end

function CDM:ShowBuffGroupSelectionPreview(groupIndex, selectedSpellID, specID)
    ClearPreviewFrames(true)

    local currentSpecID = self.GetCurrentSpecID and self:GetCurrentSpecID() or nil
    if specID and currentSpecID and specID ~= currentSpecID then AbortPreview(); return end

    local sets = self.BuffGroupSets
    local groups = sets and sets.groups
    local groupData = groupIndex and groups and groups[groupIndex]
    if type(groupData) ~= "table" or type(groupData.spells) ~= "table" then AbortPreview(); return end

    if self.UpdateBuffGroupContainerPosition then
        self:UpdateBuffGroupContainerPosition(groupIndex)
    end

    local containers = self.buffGroupContainers
    local container = containers and containers[groupIndex]
    if not container or not container:IsShown() then AbortPreview(); return end

    CollectActiveGroupFrames(groupIndex)
    BuildPreviewEntries(groupData, selectedSpellID)
    if not HasPreviewEntry() then AbortPreview(); return end

    PositionPreviewEntries(container, groupData, specID or currentSpecID)
end
