local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]
if not CDM then return end

local MoveMode = {}
CDM.MoveMode = MoveMode

local UIParent = _G.UIParent
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local GetCursorPosition = _G.GetCursorPosition
local IsMouseButtonDown = _G.IsMouseButtonDown
local IsShiftKeyDown = _G.IsShiftKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local GameTooltip = _G.GameTooltip
local C_Spell = _G.C_Spell
local WHITE = "Interface\\Buttons\\WHITE8X8"

local floor = math.floor
local max = math.max
local min = math.min
local abs = math.abs
local ceil = math.ceil

local active = false
local initialized = false
local overlayPool = {}
local activeOverlays = {}
local selectedOverlay = nil
local selectedItemID = nil
local draggingOverlay = nil
local banner = nil
local keyCapture = nil
local lastItems = {}
local previewPool = {}
local activePreviews = {}

local function Round(value)
    value = tonumber(value) or 0
    if value >= 0 then
        return floor(value + 0.5)
    end
    return -floor(abs(value) + 0.5)
end

local function SafeShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function CursorInUIParent()
    if not (UIParent and UIParent.GetEffectiveScale and GetCursorPosition) then return nil, nil end
    local scale = UIParent:GetEffectiveScale() or 1
    if scale == 0 then scale = 1 end
    local x, y = GetCursorPosition()
    return (x or 0) / scale, (y or 0) / scale
end

local function EnsureProfileTable(root, key)
    if type(root[key]) ~= "table" then root[key] = {} end
    return root[key]
end

local function EnsureEditModePosition(viewerName, defaultY)
    local db = CDM.db
    if not db then return nil end
    local editModePositions = EnsureProfileTable(db, "editModePositions")
    local viewerTable = EnsureProfileTable(editModePositions, viewerName)
    local pos = viewerTable.Default
    if type(pos) ~= "table" then
        pos = { point = "CENTER", x = 0, y = defaultY or 0 }
        viewerTable.Default = pos
    end
    pos.point = pos.point or "CENTER"
    pos.x = tonumber(pos.x) or 0
    pos.y = tonumber(pos.y) or 0
    return pos
end

local function ReadDBOffset(xKey, yKey)
    local db = CDM.db or {}
    return tonumber(db[xKey]) or 0, tonumber(db[yKey]) or 0
end

local function WriteDBOffset(xKey, yKey, x, y)
    local db = CDM.db
    if not db then return end
    db[xKey] = Round(x)
    db[yKey] = Round(y)
end

local function ReadGroupOffset(groupData)
    return tonumber(groupData and groupData.offsetX) or 0, tonumber(groupData and groupData.offsetY) or 0
end

local function WriteGroupOffset(groupData, x, y)
    if not groupData then return end
    groupData.offsetX = Round(x)
    groupData.offsetY = Round(y)
end

local function CapturePoint(frame)
    if not (frame and frame.GetPoint and frame:GetNumPoints() and frame:GetNumPoints() > 0) then return nil end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return nil end
    return point, relativeTo or UIParent, relativePoint or point, tonumber(x) or 0, tonumber(y) or 0
end

local function ApplyPreviewPoint(item, dx, dy)
    local frame = item and item.frame
    if not (frame and item.point and frame.ClearAllPoints and frame.SetPoint) then return end
    frame:ClearAllPoints()
    frame:SetPoint(item.point, item.relativeTo or UIParent, item.relativePoint or item.point, item.pointX + dx, item.pointY + dy)
end

local function UpdateItemOffset(item, dx, dy)
    if not item then return end
    local x = Round((item.startOffsetX or 0) + dx)
    local y = Round((item.startOffsetY or 0) + dy)
    if x == item.liveX and y == item.liveY then return end
    item.liveX = x
    item.liveY = y
    item.write(x, y)
    ApplyPreviewPoint(item, dx, dy)
    if item.overlay and item.overlay.value then
        item.overlay.value:SetText(x .. ", " .. y)
    end
end

local function RefreshAfterMove(item)
    if item and item.refresh then item.refresh() end
    if CDM.Refresh then CDM:Refresh("LAYOUT", "RESOURCES", "TRACKERS") end
end

local function SetOverlaySelected(overlay, selected)
    if not overlay then return end
    overlay.selected = selected and true or false
    if overlay.bg then
        if selected then
            overlay.bg:SetVertexColor(0.06, 0.42, 0.72, 0.22)
        else
            overlay.bg:SetVertexColor(0.02, 0.16, 0.28, 0.18)
        end
    end
    if overlay.edge then
        if selected then
            overlay.edge:SetBackdropBorderColor(0.20, 0.80, 1.00, 1)
        else
            overlay.edge:SetBackdropBorderColor(0.08, 0.48, 0.76, 0.86)
        end
    end
    if overlay.EnableKeyboard then overlay:EnableKeyboard(false) end
    if overlay.SetPropagateKeyboardInput then overlay:SetPropagateKeyboardInput(true) end
end

local function FocusKeyCapture()
    if keyCapture and keyCapture.SetFocus then
        keyCapture:Show()
        keyCapture:SetFocus()
    end
end

local function SelectOverlay(overlay)
    if selectedOverlay == overlay then
        SetOverlaySelected(overlay, true)
        FocusKeyCapture()
        return
    end
    SetOverlaySelected(selectedOverlay, false)
    selectedOverlay = overlay
    selectedItemID = overlay and overlay.item and overlay.item.id or selectedItemID
    SetOverlaySelected(selectedOverlay, true)
    FocusKeyCapture()
end

local function StopDrag(applyRefresh)
    local overlay = draggingOverlay
    if not overlay then return end
    draggingOverlay = nil
    overlay:SetScript("OnUpdate", nil)
    local item = overlay.item
    item.dragging = nil
    if applyRefresh and not (InCombatLockdown and InCombatLockdown()) then
        RefreshAfterMove(item)
    end
end

local function DragOnUpdate(self)
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        StopDrag(true)
        return
    end

    local item = self.item
    if not item then return end
    local x, y = CursorInUIParent()
    if not x then return end
    local dx = Round(x - item.cursorStartX)
    local dy = Round(y - item.cursorStartY)
    if dx == item.lastDx and dy == item.lastDy then return end
    item.lastDx = dx
    item.lastDy = dy
    UpdateItemOffset(item, dx, dy)
end

local function BeginDrag(overlay, button)
    if button ~= "LeftButton" then return end
    if InCombatLockdown and InCombatLockdown() then
        MoveMode:Stop("combat")
        return
    end

    SelectOverlay(overlay)

    local item = overlay.item
    if not item then return end
    local point, relativeTo, relativePoint, pointX, pointY = CapturePoint(item.frame)
    local cursorX, cursorY = CursorInUIParent()
    if not (point and cursorX) then return end

    item.point = point
    item.relativeTo = relativeTo
    item.relativePoint = relativePoint
    item.pointX = pointX
    item.pointY = pointY
    item.cursorStartX = cursorX
    item.cursorStartY = cursorY
    item.startOffsetX, item.startOffsetY = item.read()
    item.liveX, item.liveY = item.startOffsetX, item.startOffsetY
    item.lastDx, item.lastDy = 0, 0
    item.dragging = true

    draggingOverlay = overlay
    overlay:SetScript("OnUpdate", DragOnUpdate)
end

local function NudgeSelected(dx, dy)
    local overlay = selectedOverlay
    local item = overlay and overlay.item
    if not item or not item.frame then return end
    if InCombatLockdown and InCombatLockdown() then
        MoveMode:Stop("combat")
        return
    end

    local point, relativeTo, relativePoint, pointX, pointY = CapturePoint(item.frame)
    if not point then return end
    item.point = point
    item.relativeTo = relativeTo
    item.relativePoint = relativePoint
    item.pointX = pointX
    item.pointY = pointY
    item.startOffsetX, item.startOffsetY = item.read()
    item.liveX, item.liveY = item.startOffsetX, item.startOffsetY
    UpdateItemOffset(item, dx, dy)
    RefreshAfterMove(item)
    MoveMode:Refresh()
end

local function OverlayKeyDown(self, key)
    if key == "ESCAPE" then
        MoveMode:Stop("keyboard")
        return
    end

    local dx, dy = 0, 0
    if key == "LEFT" then
        dx = -1
    elseif key == "RIGHT" then
        dx = 1
    elseif key == "UP" then
        dy = 1
    elseif key == "DOWN" then
        dy = -1
    else
        return
    end

    local step = 1
    if IsShiftKeyDown and IsShiftKeyDown() then
        step = 10
    elseif IsControlKeyDown and IsControlKeyDown() then
        step = 5
    end
    NudgeSelected(dx * step, dy * step)
end

local function EnsureKeyCapture()
    if keyCapture then return keyCapture end
    local frame = CreateFrame("Frame", "MidnightCDM_MoveModeKeyCapture", UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(1000)
    frame:SetSize(1, 1)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:EnableKeyboard(true)
    if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(false) end
    frame:SetScript("OnKeyDown", OverlayKeyDown)
    frame:Hide()
    keyCapture = frame
    return frame
end

local function HideKeyCapture()
    if not keyCapture then return end
    if keyCapture.ClearFocus then keyCapture:ClearFocus() end
    keyCapture:Hide()
end

local function AcquirePreviewFrame(parent, kind)
    local frame = previewPool[#previewPool]
    if frame then
        previewPool[#previewPool] = nil
    else
        frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:EnableMouse(false)
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetAllPoints()
        frame.fill = frame:CreateTexture(nil, "ARTWORK")
        frame.fill:SetTexture(WHITE)
        frame.fill:SetPoint("LEFT", frame, "LEFT", 1, 0)
        frame.fill:SetPoint("TOP", frame, "TOP", 1, -1)
        frame.fill:SetPoint("BOTTOM", frame, "BOTTOM", 1, 1)
    end

    frame.kind = kind
    frame:SetParent(parent or UIParent)
    frame:ClearAllPoints()
    frame:SetAlpha(kind == "bar" and 0.80 or 0.72)
    frame:SetFrameLevel(((parent and parent.GetFrameLevel and parent:GetFrameLevel()) or 0) + 1)
    frame:Show()
    activePreviews[#activePreviews + 1] = frame
    return frame
end

local function ReleaseMovePreviews()
    for i = #activePreviews, 1, -1 do
        local frame = activePreviews[i]
        activePreviews[i] = nil
        frame:Hide()
        frame:ClearAllPoints()
        frame:SetParent(UIParent)
        frame.icon:SetTexture(nil)
        frame.icon:SetColorTexture(0, 0, 0, 0)
        frame.fill:SetColorTexture(0, 0, 0, 0)
        previewPool[#previewPool + 1] = frame
    end
end

local function AddPreviewSpellIDs(out, spells)
    if type(spells) ~= "table" then return 0 end
    local count = 0
    for _, sid in ipairs(spells) do
        sid = tonumber(sid)
        if sid and sid > 0 then
            count = count + 1
            out[count] = sid
            if count >= 10 then break end
        end
    end
    return count
end

local previewSpellScratch = {}
local function BuildGroupMovePreview(item)
    local groupData = item and item.groupData
    local container = item and item.frame
    local previewKind = item and item.previewKind
    if not (groupData and container and previewKind) then return end

    local count = AddPreviewSpellIDs(previewSpellScratch, groupData.spells)
    if count <= 0 then
        count = 3
        previewSpellScratch[1], previewSpellScratch[2], previewSpellScratch[3] = 61304, 6262, 20594
    end
    for i = count + 1, #previewSpellScratch do
        previewSpellScratch[i] = nil
    end

    local spacing = Round(groupData.spacing or 4)
    if spacing < 0 then spacing = 0 end

    if previewKind == "bar" then
        local w = Round(groupData.barWidth or groupData.width or 180)
        if w <= 0 then w = 180 end
        local h = Round(groupData.barHeight or groupData.height or 20)
        if h <= 0 then h = 20 end
        local visibleCount = min(count, 4)
        local totalH = (visibleCount * h) + max(0, visibleCount - 1) * spacing
        container:SetSize(max(1, w), max(1, totalH))
        for i = 1, visibleCount do
            local preview = AcquirePreviewFrame(container, "bar")
            preview:SetSize(w, h)
            preview:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -((i - 1) * (h + spacing)))
            preview.icon:SetColorTexture(0.02, 0.04, 0.08, 0.85)
            preview.fill:SetWidth(max(2, floor(w * (0.72 - (i * 0.04)))))
            preview.fill:SetColorTexture(0.20, 0.78, 1.00, 0.70)
        end
        return
    end

    local iconW = Round(groupData.iconWidth or groupData.width or 30)
    local iconH = Round(groupData.iconHeight or groupData.height or 30)
    if iconW <= 0 then iconW = 30 end
    if iconH <= 0 then iconH = 30 end

    local maxPerRow = tonumber(groupData.maxPerRow) or 0
    local visibleCount = min(count, 10)
    local cols = visibleCount
    if maxPerRow > 0 and maxPerRow < cols then cols = maxPerRow end
    if cols < 1 then cols = 1 end
    local rows = ceil(visibleCount / cols)
    local totalW = (cols * iconW) + max(0, cols - 1) * spacing
    local totalH = (rows * iconH) + max(0, rows - 1) * spacing
    container:SetSize(max(1, totalW), max(1, totalH))

    for i = 1, visibleCount do
        local idx = i - 1
        local col = idx % cols
        local row = floor(idx / cols)
        local preview = AcquirePreviewFrame(container, "icon")
        preview:SetSize(iconW, iconH)
        preview:SetPoint("TOPLEFT", container, "TOPLEFT", col * (iconW + spacing), -(row * (iconH + spacing)))
        local texture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(previewSpellScratch[i])
        if texture then
            preview.icon:SetTexture(texture)
        else
            preview.icon:SetColorTexture(0.06, 0.10, 0.16, 0.88)
        end
        preview.icon:SetDesaturation(0.25)
        preview.fill:SetColorTexture(0, 0, 0, 0)
    end
end

local function PaintOverlay(overlay)
    overlay:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = 1,
    })
    overlay:SetBackdropColor(0, 0, 0, 0)
    overlay:SetBackdropBorderColor(0.08, 0.48, 0.76, 0.86)
    overlay.edge = overlay

    local bg = overlay:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(overlay)
    bg:SetTexture(WHITE)
    bg:SetVertexColor(0.02, 0.16, 0.28, 0.18)
    overlay.bg = bg

    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", overlay, "TOPLEFT", 5, -4)
    label:SetPoint("RIGHT", overlay, "RIGHT", -5, 0)
    label:SetJustifyH("LEFT")
    label:SetTextColor(0.25, 0.84, 1.0, 1)
    overlay.label = label

    local value = overlay:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    value:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -5, 4)
    value:SetJustifyH("RIGHT")
    value:SetTextColor(0.76, 0.82, 0.94, 1)
    overlay.value = value
end

local function AcquireOverlay()
    local overlay = overlayPool[#overlayPool]
    if overlay then
        overlayPool[#overlayPool] = nil
    else
        overlay = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
        overlay:SetFrameStrata("TOOLTIP")
        overlay:SetFrameLevel(20)
        overlay:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")
        overlay:EnableMouse(true)
        if overlay.SetPropagateKeyboardInput then overlay:SetPropagateKeyboardInput(true) end
        PaintOverlay(overlay)
        overlay:SetScript("OnMouseDown", BeginDrag)
        overlay:SetScript("OnMouseUp", function(self)
            if draggingOverlay == self then
                StopDrag(true)
            else
                SelectOverlay(self)
            end
        end)
        overlay:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.item and self.item.label or "MCDM Move")
                GameTooltip:AddLine("Drag to move. Arrow keys nudge. Shift = 10 px, Ctrl = 5 px. ESC closes.", 0.75, 0.82, 0.92, true)
                GameTooltip:Show()
            end
        end)
        overlay:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        overlay:SetScript("OnKeyDown", OverlayKeyDown)
    end
    overlay:SetScript("OnUpdate", nil)
    overlay:Show()
    return overlay
end

local function ReleaseOverlays(clearSelection)
    StopDrag(false)
    SetOverlaySelected(selectedOverlay, false)
    selectedOverlay = nil
    if clearSelection then
        selectedItemID = nil
    end

    for i = #activeOverlays, 1, -1 do
        local overlay = activeOverlays[i]
        activeOverlays[i] = nil
        overlay.item = nil
        overlay:ClearAllPoints()
        overlay:Hide()
        overlayPool[#overlayPool + 1] = overlay
    end
end

local function EnsureBanner()
    if banner then return banner end
    local frame = CreateFrame("Frame", "MidnightCDM_MoveModeBanner", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(30)
    frame:SetSize(460, 34)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -72)
    frame:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.01, 0.02, 0.04, 0.90)
    frame:SetBackdropBorderColor(0.10, 0.55, 0.85, 0.92)
    frame:EnableMouse(true)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", frame, "LEFT", 12, 0)
    title:SetTextColor(0.25, 0.84, 1.0, 1)
    title:SetText("MCDM Move Mode")
    frame.title = title

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", title, "RIGHT", 12, 0)
    hint:SetPoint("RIGHT", frame, "RIGHT", -70, 0)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(0.70, 0.76, 0.88, 1)
    hint:SetText("drag handles - arrows nudge - ESC closes - combat closes instantly")
    frame.hint = hint

    local close = CreateFrame("Button", nil, frame, "BackdropTemplate")
    close:SetSize(54, 22)
    close:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
    close:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = 1,
    })
    close:SetBackdropColor(0.05, 0.08, 0.15, 0.94)
    close:SetBackdropBorderColor(0.12, 0.50, 0.78, 0.90)
    close.Text = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    close.Text:SetPoint("CENTER")
    close.Text:SetText("Done")
    close:SetScript("OnClick", function() MoveMode:Stop("button") end)
    frame.close = close

    banner = frame
    return frame
end

local function OverlaySizeForTarget(frame)
    local w = frame.GetWidth and frame:GetWidth() or 1
    local h = frame.GetHeight and frame:GetHeight() or 1
    return max(126, Round(w) + 12), max(42, Round(h) + 12)
end

local function AttachOverlay(item)
    local overlay = AcquireOverlay()
    overlay.item = item
    item.overlay = overlay
    local w, h = OverlaySizeForTarget(item.frame)
    overlay:SetSize(w, h)
    overlay:ClearAllPoints()
    overlay:SetPoint("CENTER", item.frame, "CENTER", 0, 0)
    overlay.label:SetText(item.label)
    local x, y = item.read()
    overlay.value:SetText(Round(x) .. ", " .. Round(y))
    SetOverlaySelected(overlay, false)
    activeOverlays[#activeOverlays + 1] = overlay
    return overlay
end

local function AddItem(items, item)
    if not (item and item.frame and SafeShown(item.frame) and item.read and item.write) then return end
    local point = CapturePoint(item.frame)
    if not point then return end
    items[#items + 1] = item
end

local function AddDBItem(items, id, label, frame, xKey, yKey, refresh)
    AddItem(items, {
        id = id,
        label = label,
        frame = frame,
        read = function() return ReadDBOffset(xKey, yKey) end,
        write = function(x, y) WriteDBOffset(xKey, yKey, x, y) end,
        refresh = refresh,
    })
end

local function AddPositionItem(items, id, label, viewerName, defaultY, refresh)
    local frame = CDM.anchorContainers and CDM.anchorContainers[viewerName]
    local pos = EnsureEditModePosition(viewerName, defaultY)
    if not pos then return end
    AddItem(items, {
        id = id,
        label = label,
        frame = frame,
        read = function() return tonumber(pos.x) or 0, tonumber(pos.y) or 0 end,
        write = function(x, y) pos.x = Round(x); pos.y = Round(y) end,
        refresh = refresh,
    })
end

local function GroupName(groupData, fallback)
    local name = groupData and (groupData.name or groupData.label)
    if name and name ~= "" then return tostring(name) end
    return fallback
end

local function AddGroupItems(items, kind, sets, containers, refresh, previewKind)
    if not (sets and sets.groups and containers) then return end
    for index, groupData in ipairs(sets.groups) do
        local frame = containers[index]
        AddItem(items, {
            id = kind .. ":" .. index,
            label = kind .. ": " .. GroupName(groupData, "Group " .. index),
            frame = frame,
            groupData = groupData,
            previewKind = previewKind,
            read = function() return ReadGroupOffset(groupData) end,
            write = function(x, y) WriteGroupOffset(groupData, x, y) end,
            refresh = refresh,
        })
    end
end

local function PrepareContainers()
    if CDM.RefreshSpecData then CDM:RefreshSpecData() end
    if CDM.UpdateEssentialContainerPosition then CDM:UpdateEssentialContainerPosition() end
    if CDM.UpdateBuffContainerPosition then CDM:UpdateBuffContainerPosition() end
    if CDM.UpdateBuffBarContainerPosition then CDM:UpdateBuffBarContainerPosition() end
    if CDM.UpdateUtilityContainerPosition then CDM:UpdateUtilityContainerPosition() end
    if CDM.UpdateAllCooldownGroupContainers then CDM:UpdateAllCooldownGroupContainers() end
    if CDM.UpdateAllBuffGroupContainers then CDM:UpdateAllBuffGroupContainers() end
    if CDM.UpdateAllBarGroupContainers then CDM:UpdateAllBarGroupContainers() end
    if CDM.RefreshResources then CDM:RefreshResources() end
end

local function CollectItems()
    wipe(lastItems)
    local items = lastItems
    local viewers = CDM.CONST and CDM.CONST.VIEWERS or {}

    AddPositionItem(items, "viewer:essential", "Essential cooldowns", viewers.ESSENTIAL, -201, function()
        if CDM.UpdateEssentialContainerPosition then CDM:UpdateEssentialContainerPosition() end
    end)
    AddDBItem(items, "viewer:utility", "Utility cooldowns", CDM.anchorContainers and CDM.anchorContainers[viewers.UTILITY], "utilityXOffset", "utilityYOffset", function()
        if CDM.UpdateUtilityContainerPosition then CDM:UpdateUtilityContainerPosition() end
    end)
    AddPositionItem(items, "viewer:buffs", "Buff icons", viewers.BUFF, -149, function()
        if CDM.UpdateBuffContainerPosition then CDM:UpdateBuffContainerPosition() end
    end)
    AddPositionItem(items, "viewer:bars", "Buff bars", viewers.BUFF_BAR, -324, function()
        if CDM.UpdateBuffBarContainerPosition then CDM:UpdateBuffBarContainerPosition() end
    end)

    AddGroupItems(items, "Cooldown group", CDM.CooldownGroupSets, CDM.cooldownGroupContainers, function()
        if CDM.UpdateAllCooldownGroupContainers then CDM:UpdateAllCooldownGroupContainers() end
    end, "icon")
    AddGroupItems(items, "Buff group", CDM.BuffGroupSets, CDM.buffGroupContainers, function()
        if CDM.UpdateAllBuffGroupContainers then CDM:UpdateAllBuffGroupContainers() end
    end, "icon")
    AddGroupItems(items, "Bar group", CDM.BarGroupSets, CDM.barGroupContainers, function()
        if CDM.UpdateAllBarGroupContainers then CDM:UpdateAllBarGroupContainers() end
    end, "bar")

    local db = CDM.db or {}
    if db.racialsUsePartyFrame then
        AddDBItem(items, "tracker:racials", "Racials", _G.CDM_RacialsContainer, "racialsPartyFrameOffsetX", "racialsPartyFrameOffsetY", function()
            if CDM.UpdateRacials then CDM:UpdateRacials() end
        end)
    else
        AddDBItem(items, "tracker:racials", "Racials", _G.CDM_RacialsContainer, "racialsOffsetX", "racialsOffsetY", function()
            if CDM.UpdateRacials then CDM:UpdateRacials() end
        end)
    end
    AddDBItem(items, "tracker:defensives", "Defensives", _G.CDM_DefensivesContainer, "defensivesOffsetX", "defensivesOffsetY", function()
        if CDM.UpdateDefensives then CDM:UpdateDefensives() end
    end)
    if not CDM.GetTrinketMode or CDM.GetTrinketMode() == "independent" then
        AddDBItem(items, "tracker:trinkets", "Trinkets", _G.CDM_TrinketsContainer, "trinketsOffsetX", "trinketsOffsetY", function()
            if CDM.UpdateTrinkets then CDM:UpdateTrinkets() end
        end)
    end

    AddDBItem(items, "resource:class", "Class resource", _G.MidnightCDM_ResourceFrame, "resourceOffsetX", "resourceOffsetY", function()
        if CDM.RefreshResources then CDM:RefreshResources() end
    end)
    AddDBItem(items, "resource:power", "Player power bar", _G.MidnightCDM_PlayerPowerBar, "resourcePowerBarOffsetX", "resourcePowerBarOffsetY", function()
        if CDM.RefreshResources then CDM:RefreshResources() end
    end)
    AddDBItem(items, "resource:hp", "Second HP bar", _G.MidnightCDM_PlayerHPBar, "resourceHPBarOffsetX", "resourceHPBarOffsetY", function()
        if CDM.RefreshResources then CDM:RefreshResources() end
    end)

    return items
end

function MoveMode:Refresh()
    if not active then return end
    local restoreSelectedID = selectedItemID
    ReleaseOverlays(false)
    ReleaseMovePreviews()
    PrepareContainers()
    local items = CollectItems()
    local restoreOverlay
    for i = 1, #items do
        local item = items[i]
        BuildGroupMovePreview(item)
        local overlay = AttachOverlay(item)
        if restoreSelectedID and item.id == restoreSelectedID then
            restoreOverlay = overlay
        end
    end
    if restoreOverlay or activeOverlays[1] then
        SelectOverlay(restoreOverlay or activeOverlays[1])
    end
    if banner and banner.hint then
        banner.hint:SetText("handles: " .. tostring(#activeOverlays) .. " - drag handles - arrows nudge - ESC closes - combat closes instantly")
    end
end

function MoveMode:Start()
    if active then
        self:Refresh()
        return true
    end
    if InCombatLockdown and InCombatLockdown() then
        if CDM.PrintError then CDM.PrintError("Move Mode cannot start in combat.") end
        return false
    end
    active = true
    EnsureKeyCapture()
    EnsureBanner():Show()
    self:Refresh()
    FocusKeyCapture()
    if CDM.NotifyMoveModeChanged then CDM:NotifyMoveModeChanged(true) end
    if CDM.Print then CDM.Print("Move Mode enabled. Drag handles, use arrow keys to nudge, ESC closes.") end
    return true
end

function MoveMode:Stop(reason)
    if not active then return false end
    active = false
    ReleaseOverlays(true)
    ReleaseMovePreviews()
    HideKeyCapture()
    if banner then banner:Hide() end
    if not (InCombatLockdown and InCombatLockdown()) then
        PrepareContainers()
    end
    if CDM.NotifyMoveModeChanged then CDM:NotifyMoveModeChanged(false, reason) end
    if reason == "combat" then
        if CDM.Print then CDM.Print("Move Mode closed because combat started.") end
    end
    return true
end

function MoveMode:Toggle()
    if active then
        return self:Stop("toggle")
    end
    return self:Start()
end

function MoveMode:IsActive()
    return active
end

function CDM:StartMoveMode()
    return MoveMode:Start()
end

function CDM:StopMoveMode()
    return MoveMode:Stop("api")
end

function CDM:ToggleMoveMode()
    return MoveMode:Toggle()
end

function CDM:IsMoveModeActive()
    return MoveMode:IsActive()
end

function CDM:InitializeMoveMode()
    if initialized then return end
    initialized = true
    if self.RegisterCombatStateHandler then
        self:RegisterCombatStateHandler(function(isInCombat)
            if isInCombat and active then
                MoveMode:Stop("combat")
            end
        end)
    end
end
