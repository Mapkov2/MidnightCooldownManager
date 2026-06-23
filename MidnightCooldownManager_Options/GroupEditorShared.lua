local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM_C = Runtime and Runtime.CONST or {}
local UI = ns.ConfigUI
local ui = UI
local L = Runtime.L

ns.GroupEditorShared = ns.GroupEditorShared or {}
local Shared = ns.GroupEditorShared

local CLASS_LIST = {}
local CLASS_SPECS = {}

for i = 1, GetNumClasses() do
    local className, classTag, classID = GetClassInfo(i)
    if classTag then
        local color = RAID_CLASS_COLORS[classTag]
        CLASS_LIST[#CLASS_LIST + 1] = {
            classTag = classTag,
            className = className,
            classID = classID,
            r = color and color.r or 1,
            g = color and color.g or 1,
            b = color and color.b or 1,
        }
        local specs = {}
        for j = 1, GetNumSpecializationsForClassID(classID) do
            local specID, specName = GetSpecializationInfoForClassID(classID, j)
            if specID then
                specs[#specs + 1] = { specID = specID, specName = specName }
            end
        end
        CLASS_SPECS[classTag] = specs
    end
end

table.sort(CLASS_LIST, function(a, b) return a.className < b.className end)

function Shared.GetClassCatalog()
    return CLASS_LIST, CLASS_SPECS
end

local function GetSpecLabel(specID)
    for _, classInfo in ipairs(CLASS_LIST) do
        local specs = CLASS_SPECS[classInfo.classTag]
        if specs then
            for _, specInfo in ipairs(specs) do
                if specInfo.specID == specID then
                    return classInfo.className .. " - " .. specInfo.specName
                end
            end
        end
    end
    return nil
end

Shared.GROW_OPTIONS = {
    { label = "Right", value = "RIGHT" },
    { label = "Left", value = "LEFT" },
    { label = "Up", value = "UP" },
    { label = "Down", value = "DOWN" },
    { label = "Center Horizontal", value = "CENTER_H" },
    { label = "Center Vertical", value = "CENTER_V" },
}

function Shared.GetGrowLabel(growValue)
    return UI.GetOptionLabel(Shared.GROW_OPTIONS, growValue, growValue or "RIGHT")
end

local ARROW_LABELS = {
    up = "^",
    down = "v",
    left = "<",
    right = ">",
}

function Shared.SetArrowButtonDirection(btn, direction)
    if not btn then return end
    btn._mcdmArrowDirection = direction
    local text = ARROW_LABELS[direction] or ">"
    if btn._mcdmLabel then
        btn._mcdmLabel:SetText(text)
    elseif btn.SetText then
        btn:SetText(text)
    end
end

function Shared.CreateArrowButton(parent, direction, size)
    local btn = CreateFrame("Button", nil, parent)
    size = size or 24
    btn:SetSize(size, size)
    UI.StyleButton(btn)
    local text = btn._mcdmLabel or btn:GetFontString()
    if text then
        text:ClearAllPoints()
        text:SetPoint("CENTER")
        text:SetJustifyH("CENTER")
        text:SetFontObject("MidnightCDM_Font14")
        btn._mcdmLabel = text
    end
    Shared.SetArrowButtonDirection(btn, direction)
    return btn
end

function Shared.ApplyRemoveButtonText(btn)
    UI.StyleButton(btn, "danger")
    local text = btn._mcdmLabel or btn:GetFontString()
    if not text then
        text = btn:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
        btn:SetFontString(text)
    end
    text:ClearAllPoints()
    text:SetPoint("CENTER")
    text:SetJustifyH("CENTER")
    text:SetFontObject("MidnightCDM_Font14")
    text:SetText("X")
    btn._mcdmLabel = text
    btn:SetFontString(text)
    return text
end

function Shared.IsUsableSpellID(spellID)
    return API.IsSafeNumber(spellID) and spellID > 0 and spellID == math.floor(spellID)
end

function Shared.GetDisplaySpellID(spellID)
    if C_Spell.GetSpellTexture(spellID) then return spellID end
    local base = API.NormalizeToBase and API.NormalizeToBase(spellID)
    if base and base ~= spellID then return base end
    return spellID
end

function Shared.GetCooldownInfoByID(cooldownID)
    if not cooldownID then return nil end
    local entry = API.GetCooldownIndexEntryByID and API:GetCooldownIndexEntryByID(cooldownID)
    if entry then return entry.cooldownInfo, entry end
    if API.GetCooldownInfoByID then
        return API:GetCooldownInfoByID(cooldownID), nil
    end
    return nil, nil
end

function Shared.GetCooldownDisplaySpellID(info)
    if not info then return nil end
    if API.GetCooldownInfoDisplaySpellID then
        return API:GetCooldownInfoDisplaySpellID(info)
    end
    if Shared.IsUsableSpellID(info.overrideTooltipSpellID) then return info.overrideTooltipSpellID end
    if Shared.IsUsableSpellID(info.overrideSpellID) then return info.overrideSpellID end
    if Shared.IsUsableSpellID(info.spellID) then return info.spellID end
    if type(info.linkedSpellIDs) == "table" then
        for _, linkedID in ipairs(info.linkedSpellIDs) do
            if Shared.IsUsableSpellID(linkedID) then
                return linkedID
            end
        end
    end
    return nil
end

function Shared.ShouldShowCooldownInfo(info, opts)
    if not info then return false end
    if info.isInvisible and not (opts and opts.includeInvisible) then return false end
    return true
end

function Shared.MarkTooltipOverride(tooltipOverrideMap, info)
    if type(tooltipOverrideMap) ~= "table" or not info then return end

    local tooltipID = info.overrideTooltipSpellID
    if not Shared.IsUsableSpellID(tooltipID) then return end

    local spellID = info.spellID
    if Shared.IsUsableSpellID(spellID) and tooltipID ~= spellID then
        tooltipOverrideMap[spellID] = tooltipID
    end

    local overrideID = info.overrideSpellID
    if Shared.IsUsableSpellID(overrideID) and tooltipID ~= overrideID then
        tooltipOverrideMap[overrideID] = tooltipID
    end
end

function Shared.ForEachCooldownViewerInfoInCategories(categories, callback, opts)
    if type(callback) ~= "function" then return end
    if not API.ForEachCooldownViewerInfo then return end

    local categorySet = {}
    for _, category in ipairs(categories or {}) do
        if category then categorySet[category] = true end
    end

    return API:ForEachCooldownViewerInfo(function(cooldownID, info, category, entry)
        if categorySet[category] and Shared.ShouldShowCooldownInfo(info, opts) then
            return callback(cooldownID, info, category, entry)
        end
    end)
end

function Shared.ForEachCooldownViewerInfoByKind(kind, callback, opts)
    if type(callback) ~= "function" then return end
    if API.ForEachCooldownViewerInfoByKind then
        return API:ForEachCooldownViewerInfoByKind(kind, callback, opts)
    end
end

function Shared.GetFrameCooldownRecord(frame)
    return API.GetFrameCooldownRecord and API:GetFrameCooldownRecord(frame) or nil
end

function Shared.GetFrameCooldownID(frame)
    local record = Shared.GetFrameCooldownRecord(frame)
    if record and record.cooldownID then return record.cooldownID, record end
    if API.GetFrameCooldownID then
        return API:GetFrameCooldownID(frame), record
    end
    return nil, record
end

function Shared.GetFrameDisplaySpellID(frame)
    local record = Shared.GetFrameCooldownRecord(frame)
    if record then
        local displayID = record.displaySpellID
            or record.overrideTooltipSpellID
            or record.overrideSpellID
            or record.spellID
            or record.baseSpellID
        if Shared.IsUsableSpellID(displayID) then
            return displayID, record
        end
    end

    local preferred = API.GetPreferredBuffGroupSpellID and API:GetPreferredBuffGroupSpellID(frame)
    if Shared.IsUsableSpellID(preferred) then return preferred, record end

    local base = API.GetBaseSpellID and API:GetBaseSpellID(frame)
    if Shared.IsUsableSpellID(base) then return base, record end

    return nil, record
end

function Shared.MarkFrameSpellCandidates(targetSet, frame)
    if type(targetSet) ~= "table" or not frame then return end
    if API.ForEachFrameSpellCandidate then
        API:ForEachFrameSpellCandidate(frame, function(candidateID)
            if Shared.IsUsableSpellID(candidateID) then
                targetSet[candidateID] = true
            end
        end)
    end
end

function Shared.GetUniqueGroupName(groups, baseName)
    if not groups then return baseName end
    local nameSet = {}
    for _, group in ipairs(groups) do
        if group.name then
            nameSet[group.name] = true
        end
    end
    if not nameSet[baseName] then return baseName end
    for i = 1, 99 do
        local candidate = baseName .. " (" .. i .. ")"
        if not nameSet[candidate] then
            return candidate
        end
    end
    return baseName .. " (" .. time() .. ")"
end

function Shared.MarkEquivalentSpellIDs(targetSet, spellID)
    if type(targetSet) ~= "table" or not Shared.IsUsableSpellID(spellID) then return end
    targetSet[spellID] = true
end

function Shared.HasEquivalentSpellID(targetSet, spellID)
    if type(targetSet) ~= "table" or not Shared.IsUsableSpellID(spellID) then
        return false
    end
    return targetSet[spellID] or false
end

function Shared.RemoveSpellFromGroupList(spellList, spellID)
    if type(spellList) ~= "table" or not Shared.IsUsableSpellID(spellID) then
        return nil
    end
    for i = #spellList, 1, -1 do
        if Shared.IsUsableSpellID(spellList[i]) and spellList[i] == spellID then
            return table.remove(spellList, i)
        end
    end
    return nil
end

function Shared.AddSpellToGroupList(spellList, spellID)
    if type(spellList) ~= "table" or not Shared.IsUsableSpellID(spellID) then
        return nil
    end
    Shared.RemoveSpellFromGroupList(spellList, spellID)
    spellList[#spellList + 1] = spellID
    return spellID
end

local function GetOverrideStorageKey(spellID, normalizeToBase)
    if API.GetBuffOverrideStorageKey then
        return API:GetBuffOverrideStorageKey(spellID)
    end
end

function Shared.EnsureResolvedOverrideEntry(overrideMap, spellID, normalizeToBase)
    if type(overrideMap) ~= "table" or not Shared.IsUsableSpellID(spellID) then
        return nil
    end
    if API.EnsureBuffOverrideEntry then
        return API:EnsureBuffOverrideEntry(overrideMap, spellID)
    end
    local storageKey = GetOverrideStorageKey(spellID, normalizeToBase)
    if not Shared.IsUsableSpellID(storageKey) then
        return nil
    end
    if type(overrideMap[storageKey]) ~= "table" then
        overrideMap[storageKey] = {}
    end
    return overrideMap[storageKey]
end

function Shared.GetMergedOverrideEntry(overrideMap, spellID)
    if API.GetMergedBuffOverrideEntry then
        return API:GetMergedBuffOverrideEntry(overrideMap, spellID)
    end
    return nil
end

function Shared.ExtractMergedOverrideEntry(overrideMap, spellID)
    if API.ExtractMergedBuffOverrideEntry then
        return API:ExtractMergedBuffOverrideEntry(overrideMap, spellID)
    end
    return nil
end

function Shared.StoreMergedOverrideEntry(overrideMap, spellID, incoming, normalizeToBase)
    if type(overrideMap) ~= "table" or type(incoming) ~= "table" or not Shared.IsUsableSpellID(spellID) then
        return
    end
    if API.StoreMergedBuffOverrideEntry then
        API:StoreMergedBuffOverrideEntry(overrideMap, spellID, incoming)
        return
    end
    local storageKey = GetOverrideStorageKey(spellID, normalizeToBase)
    if Shared.IsUsableSpellID(storageKey) then
        overrideMap[storageKey] = incoming
    end
end

function Shared.CreateRightPanelManager(rightPanel, placeholder, destroyFrame)
    local rightContentFrame = nil
    local rightScrollFrame = nil
    local rightPanelDropdowns = {}

    local function CloseDropdownMenus()
        if UI and UI.CloseAllDropdownMenus then
            UI.CloseAllDropdownMenus()
        end
        for _, dropdown in ipairs(rightPanelDropdowns) do
            if dropdown and dropdown.CloseMenu then
                dropdown:CloseMenu()
            end
        end
    end

    local function Reset(showPlaceholder)
        CloseDropdownMenus()
        table.wipe(rightPanelDropdowns)
        if rightContentFrame then
            destroyFrame(rightContentFrame)
            rightContentFrame = nil
        end
        if rightScrollFrame then
            destroyFrame(rightScrollFrame)
            rightScrollFrame = nil
        end
        placeholder:SetShown(showPlaceholder)
    end

    return {
        RegisterDropdown = function(dropdown)
            if dropdown then
                rightPanelDropdowns[#rightPanelDropdowns + 1] = dropdown
            end
            return dropdown
        end,
        CreateScrollContent = function(minHeight)
            Reset(false)

            local sf = CreateFrame("ScrollFrame", nil, rightPanel, "ScrollFrameTemplate")
            sf:SetAllPoints()
            sf:Show()
            sf:HookScript("OnVerticalScroll", CloseDropdownMenus)
            sf:HookScript("OnHide", CloseDropdownMenus)
            if UI.StyleScrollFrame then UI.StyleScrollFrame(sf) end
            rightScrollFrame = sf

            local rc = CreateFrame("Frame", nil, sf)
            rc:SetWidth(sf:GetWidth() > 0 and sf:GetWidth() - 20 or 400)
            rc:SetHeight(minHeight or 400)
            sf:SetScrollChild(rc)
            rc:Show()
            rightContentFrame = rc
            return sf, rc
        end,
        Clear = function()
            Reset(true)
        end,
        CloseDropdownMenus = CloseDropdownMenus,
    }
end

function Shared.CreateDragDropController(config)
    local dragState = {
        active = false,
        spellID = nil,
        sourceGroup = nil,
        dragFrame = nil,
    }
    local dropTargets = {}
    local dragFrameCache = nil

    local function HideHighlights()
        for _, target in ipairs(dropTargets) do
            if target.frame.highlight then
                target.frame.highlight:Hide()
            end
        end
    end

    local function GetOrCreateDragFrame(spellID)
        if not dragFrameCache then
            dragFrameCache = CreateFrame("Frame", nil, UIParent)
            dragFrameCache:SetSize(28, 28)
            dragFrameCache:SetFrameStrata("TOOLTIP")
            local icon = dragFrameCache:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            dragFrameCache.icon = icon
            dragFrameCache:SetAlpha(0.8)
        end
        local tex = C_Spell.GetSpellTexture(Shared.GetDisplaySpellID(spellID))
        if tex then
            dragFrameCache.icon:SetTexture(tex)
        else
            dragFrameCache.icon:SetColorTexture(0.3, 0.3, 0.3)
        end
        CDM_C.ApplyIconTexCoord(dragFrameCache.icon, CDM_C.GetEffectiveZoomAmount())
        return dragFrameCache
    end

    return {
        RegisterDropTarget = function(frame, groupIndex)
            dropTargets[#dropTargets + 1] = { frame = frame, groupIndex = groupIndex }
        end,
        ClearDropTargets = function()
            table.wipe(dropTargets)
        end,
        StartDrag = function(spellID, sourceGroup)
            if dragState.active then return end
            dragState.active = true
            dragState.spellID = spellID
            dragState.sourceGroup = sourceGroup

            local df = GetOrCreateDragFrame(spellID)
            dragState.dragFrame = df
            df:Show()
            local cachedScale = UIParent:GetEffectiveScale()
            df:SetScript("OnUpdate", function()
                local x, y = GetCursorPosition()
                df:ClearAllPoints()
                df:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / cachedScale, y / cachedScale)
                for _, target in ipairs(dropTargets) do
                    if target.frame.highlight then
                        target.frame.highlight:SetShown(target.frame:IsMouseOver())
                    end
                end
            end)
        end,
        EndDrag = function()
            if not dragState.active then return end

            local spellID = dragState.spellID
            local sourceGroup = dragState.sourceGroup

            if dragState.dragFrame then
                dragState.dragFrame:SetScript("OnUpdate", nil)
                dragState.dragFrame:Hide()
                dragState.dragFrame = nil
            end

            local targetGroupIndex = nil
            local hitDropTarget = false
            for _, target in ipairs(dropTargets) do
                if target.frame:IsMouseOver() then
                    targetGroupIndex = target.groupIndex
                    hitDropTarget = true
                    break
                end
            end

            HideHighlights()

            dragState.active = false
            dragState.spellID = nil
            dragState.sourceGroup = nil

            if config and config.onDrop then
                config.onDrop(spellID, sourceGroup, targetGroupIndex, hitDropTarget)
            end
        end,
        CancelDrag = function()
            if not dragState.active then return end
            if dragState.dragFrame then
                dragState.dragFrame:SetScript("OnUpdate", nil)
                dragState.dragFrame:Hide()
                dragState.dragFrame = nil
            end
            HideHighlights()
            dragState.active = false
            dragState.spellID = nil
            dragState.sourceGroup = nil
        end,
    }
end

local HEADER_SCROLL_LEFT_PAD = 60
local HEADER_VISIBLE_W = 226
local HEADER_GROUP_H = 28
local HEADER_DELETE_BTN_SIZE = 20
local HEADER_EXPAND_BTN_SIZE = 20
local ROW_MOVE_BTN_GAP = 2
local ROW_AFTER_MOVE_BTNS_GAP = 8

function Shared.LayoutGroupEditorRow(widget, showMoveButtons)
    if not widget or not widget.root then return end

    local row = widget.root
    local btnUp = widget.btnUp
    local btnDown = widget.btnDown
    local iconContainer = widget.iconContainer

    if btnUp and btnDown then
        btnUp:ClearAllPoints()
        btnDown:ClearAllPoints()
        if showMoveButtons then
            btnUp:SetPoint("LEFT", row, "LEFT", 0, 0)
            btnDown:SetPoint("LEFT", btnUp, "RIGHT", ROW_MOVE_BTN_GAP, 0)
        else
            btnUp:SetPoint("RIGHT", row, "LEFT", 0, 0)
            btnDown:SetPoint("RIGHT", row, "LEFT", 0, 0)
        end
    end

    if iconContainer then
        iconContainer:ClearAllPoints()
        if showMoveButtons and btnUp and btnDown then
            local arrowWidth = btnUp:GetWidth() or 0
            iconContainer:SetPoint("LEFT", row, "LEFT", arrowWidth * 2 + ROW_MOVE_BTN_GAP + ROW_AFTER_MOVE_BTNS_GAP, 0)
        else
            iconContainer:SetPoint("LEFT", row, "LEFT", 0, 0)
        end
    end
end

local function PaintExpandableHeader(header, isSelected)
    if not header then return end
    local colors = UI.Theme and UI.Theme.colors or {}
    local fill = isSelected and colors.pillActive or colors.pillBase
    local edge = isSelected and colors.pillEdgeActive or colors.pillEdge
    if UI.ColorSuperellipseParts then
        UI.ColorSuperellipseParts(header.fill, fill)
        UI.ColorSuperellipseParts(header.edge, edge)
    end
    if header.nameText then
        if isSelected then
            UI.SetTextWhite(header.nameText)
        else
            UI.SetTextMuted(header.nameText)
        end
    end
end

function Shared.CreateExpandableHeader(parent, yOff, isExpanded, displayName, isSelected)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(HEADER_VISIBLE_W, HEADER_GROUP_H)
    row:SetPoint("TOPLEFT", HEADER_SCROLL_LEFT_PAD, yOff)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local fill, edge = UI.CreateSuperellipseLayers(row, "_mcdmGroupHeader", 2, "BACKGROUND", "BORDER")

    local nameText = row:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    nameText:SetPoint("LEFT", row, "LEFT", 11, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -(HEADER_DELETE_BTN_SIZE + HEADER_EXPAND_BTN_SIZE + 13), 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetText(displayName)

    local deleteBtn = CreateFrame("Button", nil, row)
    deleteBtn:SetSize(HEADER_DELETE_BTN_SIZE, HEADER_DELETE_BTN_SIZE)
    deleteBtn:SetPoint("RIGHT", row, "RIGHT", -3, 0)
    deleteBtn:SetFrameLevel(row:GetFrameLevel() + 4)
    Shared.ApplyRemoveButtonText(deleteBtn)

    local expandBtn = Shared.CreateArrowButton(row, isExpanded and "down" or "right", HEADER_EXPAND_BTN_SIZE)
    expandBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -3, 0)
    expandBtn:SetFrameLevel(row:GetFrameLevel() + 3)

    local header = {
        row = row,
        bgLeft = row,
        bgRight = expandBtn,
        bgMiddle = nil,
        fill = fill,
        edge = edge,
        nameText = nameText,
        deleteBtn = deleteBtn,
        selectBtn = row,
        expandBtn = expandBtn,
    }

    PaintExpandableHeader(header, isSelected)
    return header
end

function Shared.ConfigureExpandableHeader(header, yOff, isExpanded, displayName, isSelected)
    if not header then return end

    header.row:SetSize(HEADER_VISIBLE_W, HEADER_GROUP_H)
    header.row:ClearAllPoints()
    header.row:SetPoint("TOPLEFT", HEADER_SCROLL_LEFT_PAD, yOff)

    header.deleteBtn:ClearAllPoints()
    header.deleteBtn:SetPoint("RIGHT", header.row, "RIGHT", -3, 0)
    header.expandBtn:ClearAllPoints()
    header.expandBtn:SetPoint("RIGHT", header.deleteBtn, "LEFT", -3, 0)
    Shared.SetArrowButtonDirection(header.expandBtn, isExpanded and "down" or "right")

    header.nameText:Show()
    header.nameText:ClearAllPoints()
    header.nameText:SetPoint("LEFT", header.row, "LEFT", 11, 0)
    header.nameText:SetPoint("RIGHT", header.expandBtn, "LEFT", -7, 0)
    header.nameText:SetText(displayName)
    PaintExpandableHeader(header, isSelected)

    header.deleteBtn:Show()
    header.selectBtn:Show()
    if header.selectBtn ~= header.row then
        header.selectBtn:ClearAllPoints()
        header.selectBtn:SetAllPoints(header.row)
        header.selectBtn:SetFrameLevel(header.row:GetFrameLevel() + 1)
    else
        header.selectBtn:EnableMouse(true)
        header.selectBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    header.expandBtn:SetFrameLevel(header.row:GetFrameLevel() + 3)
    header.deleteBtn:SetFrameLevel(header.row:GetFrameLevel() + 4)
    header.expandBtn:Show()
end

function Shared.SetupRenameEditBox(headerRow, bgLeft, bgRight, nameText, currentName, onCommit, onCancel)
    nameText:Hide()
    local editBox = UI.CreateModernEditBox(headerRow, 140, 18)
    editBox:SetPoint("LEFT", bgLeft, "LEFT", 4, 0)
    editBox:SetPoint("RIGHT", bgRight, "LEFT", -4, 0)
    editBox:SetHeight(18)
    editBox:SetJustifyH("LEFT")
    editBox:SetTextInsets(6, 6, 0, 0)
    editBox:SetText(currentName)
    editBox:SetAutoFocus(true)
    editBox:HighlightText()
    editBox:SetFrameLevel(headerRow:GetFrameLevel() + 3)

    local committed = false
    local function DoCommit(self)
        if committed then return end
        committed = true
        local newName = self:GetText()
        self:SetScript("OnEditFocusLost", nil)
        self:Hide()
        if newName and newName ~= "" then
            onCommit(newName)
        else
            onCancel()
        end
    end
    editBox:SetScript("OnEnterPressed", DoCommit)
    editBox:SetScript("OnEscapePressed", function(self)
        if committed then return end
        committed = true
        self:SetScript("OnEditFocusLost", nil)
        self:Hide()
        onCancel()
    end)
    editBox:SetScript("OnEditFocusLost", DoCommit)
    return editBox
end

function Shared.BuildGroupContextMenu(rootDescription, labels, onRename, onDuplicate, onCopyToSpec)
    rootDescription:CreateButton(labels.rename, onRename)
    rootDescription:CreateButton(labels.duplicate, onDuplicate)
    local copyMenu = rootDescription:CreateButton(labels.copyTo)
    for _, classInfo in ipairs(CLASS_LIST) do
        local color = RAID_CLASS_COLORS[classInfo.classTag]
        local coloredName = color and color:WrapTextInColorCode(classInfo.className) or classInfo.className
        local classMenu = copyMenu:CreateButton(coloredName)
        local specs = CLASS_SPECS[classInfo.classTag]
        if specs then
            for _, specInfo in ipairs(specs) do
                classMenu:CreateButton(specInfo.specName, function()
                    onCopyToSpec(specInfo.specID)
                end)
            end
        end
    end
end

local HIDE_BY_DEFAULT_FLAG = Enum.CooldownSetSpellFlags and Enum.CooldownSetSpellFlags.HideByDefault

function Shared.IsHiddenByDefault(info)
    return info and info.flags and HIDE_BY_DEFAULT_FLAG and FlagsUtil and FlagsUtil.IsSet
        and FlagsUtil.IsSet(info.flags, HIDE_BY_DEFAULT_FLAG) or false
end

function Shared.GetConfiguredBorderColor()
    if Runtime.GetConfiguredBorderColor then
        return Runtime.GetConfiguredBorderColor()
    end
    return 0, 0, 0, 1
end

function Shared.ApplyConfiguredBorderColor(border)
    if not (border and border.SetBackdropBorderColor) then return end
    local r, g, b, a = Shared.GetConfiguredBorderColor()
    border:SetBackdropBorderColor(r, g, b, a)
end

local PREVIEW_FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local VALID_PREVIEW_POINTS = {
    CENTER = true,
    TOP = true,
    BOTTOM = true,
    LEFT = true,
    RIGHT = true,
    TOPLEFT = true,
    TOPRIGHT = true,
    BOTTOMLEFT = true,
    BOTTOMRIGHT = true,
}

local function PreviewNumber(value, fallback)
    local n = tonumber(value)
    if not n then return fallback end
    return n
end

local function PreviewColor(value, fallback)
    if type(value) == "table" then
        return {
            r = value.r or (fallback and fallback.r) or 1,
            g = value.g or (fallback and fallback.g) or 1,
            b = value.b or (fallback and fallback.b) or 1,
            a = value.a or (fallback and fallback.a) or 1,
        }
    end
    fallback = fallback or CDM_C.WHITE or { r = 1, g = 1, b = 1, a = 1 }
    return {
        r = fallback.r or 1,
        g = fallback.g or 1,
        b = fallback.b or 1,
        a = fallback.a or 1,
    }
end

local function PreviewPoint(point, fallback)
    point = point and string.upper(tostring(point)) or nil
    if point and VALID_PREVIEW_POINTS[point] then return point end
    return fallback or "BOTTOMRIGHT"
end

local function PreviewFontSize(size)
    local px = PreviewNumber(size, 12)
    if Runtime.Pixel and Runtime.Pixel.FontSize then
        return Runtime.Pixel.FontSize(px)
    end
    return px
end

local function PreviewFontPath()
    if CDM_C.GetBaseFontPath then
        return CDM_C.GetBaseFontPath()
    end
    return CDM_C.FONT_PATH or STANDARD_TEXT_FONT
end

local function PreviewFontOutline()
    if CDM_C.GetBaseFontOutline then
        return CDM_C.GetBaseFontOutline()
    end
    if CDM_C.ResolveOutlineFlags and Runtime.db then
        return CDM_C.ResolveOutlineFlags(Runtime.db.textFontOutline or "OUTLINE")
    end
    return "OUTLINE"
end

local function GetPreviewFallbackFontObject()
    if _G["MidnightCDM_Font12"] then return _G["MidnightCDM_Font12"] end
    if _G["GameFontNormal"] then return _G["GameFontNormal"] end

    local fontObject = _G["MidnightCDM_PreviewFont"] or CreateFont("MidnightCDM_PreviewFont")
    if fontObject then
        fontObject:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    end
    return fontObject
end

local function EnsurePreviewFont(fontString, size)
    if not fontString then return end

    local fallbackFont = GetPreviewFallbackFontObject()
    if fallbackFont and fontString.SetFontObject then
        fontString:SetFontObject(fallbackFont)
    end

    local fontSize = math.max(1, tonumber(PreviewFontSize(size)) or 12)
    local outline = PreviewFontOutline()
    local fontPath = PreviewFontPath()
    if type(fontPath) == "string" and fontPath ~= "" then
        fontString:SetFont(fontPath, fontSize, outline)
    end

    if fontString.GetFont and not fontString:GetFont() then
        fontString:SetFont(STANDARD_TEXT_FONT, fontSize, outline)
    end

    if fontString.GetFont and not fontString:GetFont() and fallbackFont and fontString.SetFontObject then
        fontString:SetFontObject(fallbackFont)
    end
end

local function StylePreviewText(fontString, size, color)
    if not fontString then return end
    EnsurePreviewFont(fontString, size)
    local c = PreviewColor(color)
    fontString:SetTextColor(c.r, c.g, c.b, c.a or 1)
    fontString:SetShadowOffset(0, 0)
    if fontString.SetIgnoreParentScale then
        fontString:SetIgnoreParentScale(true)
    end
end

local function SetPreviewText(fontString, value, size)
    EnsurePreviewFont(fontString, size or 12)
    if fontString.GetFont and not fontString:GetFont() then
        return
    end
    fontString:SetText(value or "")
end

local function ResolvePreviewTexture(spellID, texture)
    if texture then return texture end
    if spellID and C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID) or PREVIEW_FALLBACK_ICON
    end
    return PREVIEW_FALLBACK_ICON
end

function Shared.ApplyDummyIconPreview(iconFrame, opts)
    if not iconFrame then return end
    opts = opts or {}

    local width = math.max(16, PreviewNumber(opts.width, iconFrame:GetWidth() or 36))
    local height = math.max(16, PreviewNumber(opts.height, iconFrame:GetHeight() or 36))
    iconFrame:SetSize(width, height)

    local iconTex = opts.iconTextureRegion or iconFrame._mcdmPreviewIcon
    if not iconTex then
        iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints()
    end
    iconFrame._mcdmPreviewIcon = iconTex
    iconTex:SetTexture(ResolvePreviewTexture(opts.displaySpellID, opts.texture))
    if CDM_C.ApplyIconTexCoord and CDM_C.GetEffectiveZoomAmount then
        CDM_C.ApplyIconTexCoord(iconTex, CDM_C.GetEffectiveZoomAmount())
    end
    iconTex:SetDesaturated(opts.inactive and true or false)
    iconTex:SetAlpha(opts.inactive and 0.62 or 1)

    if not iconFrame.cdmBorder and Runtime.BORDER and Runtime.BORDER.CreateBorder then
        iconFrame.cdmBorder = Runtime.BORDER:CreateBorder(iconFrame, true)
        if Runtime.BORDER.activeBorders then
            Runtime.BORDER.activeBorders[iconFrame] = nil
        end
    end

    if iconFrame.cdmBorder then
        local borderColor = opts.borderColor
        if borderColor and iconFrame.cdmBorder.SetBackdropBorderColor then
            iconFrame.cdmBorder:SetBackdropBorderColor(borderColor.r or 1, borderColor.g or 1, borderColor.b or 1, borderColor.a or 1)
        else
            Shared.ApplyConfiguredBorderColor(iconFrame.cdmBorder)
        end
        iconFrame.cdmBorder:SetAlpha(opts.inactive and 0.7 or 1)
    end

    local glow = iconFrame._mcdmPreviewGlow
    if not glow then
        glow = iconFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
        glow:SetTexture(CDM_C.TEX_WHITE8X8 or "Interface\\Buttons\\WHITE8X8")
        iconFrame._mcdmPreviewGlow = glow
    end
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", -4, 4)
    glow:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 4, -4)
    local glowColor = PreviewColor(opts.glowColor, Runtime.db and Runtime.db.glowColor or CDM_C.GOLD)
    glow:SetVertexColor(glowColor.r, glowColor.g, glowColor.b, 0.26)
    glow:SetShown(opts.glowEnabled and true or false)

    local shade = iconFrame._mcdmPreviewInactiveShade
    if not shade then
        shade = iconFrame:CreateTexture(nil, "OVERLAY", nil, 1)
        shade:SetAllPoints()
        shade:SetColorTexture(0, 0, 0, 0.22)
        iconFrame._mcdmPreviewInactiveShade = shade
    end
    shade:SetShown(opts.inactive and true or false)

    local cdText = iconFrame._mcdmPreviewCooldownText
    if not cdText then
        cdText = iconFrame:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font12")
        cdText:SetJustifyH("CENTER")
        cdText:SetJustifyV("MIDDLE")
        iconFrame._mcdmPreviewCooldownText = cdText
    end
    cdText:ClearAllPoints()
    cdText:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    StylePreviewText(cdText, opts.cooldownFontSize or 12, opts.cooldownColor)
    SetPreviewText(cdText, opts.cooldownText or "1.4", opts.cooldownFontSize or 12)
    cdText:SetShown(not opts.hideCooldown)

    local secondaryText = iconFrame._mcdmPreviewSecondaryText
    if not secondaryText then
        secondaryText = iconFrame:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font12")
        secondaryText:SetJustifyH("CENTER")
        secondaryText:SetJustifyV("MIDDLE")
        iconFrame._mcdmPreviewSecondaryText = secondaryText
    end
    local point = PreviewPoint(opts.secondaryPosition, "BOTTOMRIGHT")
    secondaryText:ClearAllPoints()
    secondaryText:SetPoint(point, iconFrame, point, PreviewNumber(opts.secondaryOffsetX, 0), PreviewNumber(opts.secondaryOffsetY, 0))
    StylePreviewText(secondaryText, opts.secondaryFontSize or 15, opts.secondaryColor)
    SetPreviewText(secondaryText, opts.secondaryText or "2", opts.secondaryFontSize or 15)
    secondaryText:SetShown(not opts.hideSecondary)
end

function Shared.CreateDummyIconPreview(parent, opts)
    opts = opts or {}
    local iconFrame = CreateFrame("Frame", nil, parent)
    iconFrame:SetSize(opts.width or 36, opts.height or 36)
    local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints()
    iconFrame._mcdmPreviewIcon = iconTex
    opts.iconTextureRegion = iconTex
    Shared.ApplyDummyIconPreview(iconFrame, opts)
    return iconFrame
end

function Shared.RenderGroupPreview(body, gd, opts)
    opts = opts or {}
    local tf = opts.textFields or {}
    local spells = type(gd.spells) == "table" and gd.spells or {}
    local iconW = math.max(16, PreviewNumber(gd.iconWidth, 30))
    local iconH = math.max(16, PreviewNumber(gd.iconHeight, 30))
    local spacing = PreviewNumber(gd.spacing, 4)
    local availableW = PreviewNumber(opts.width, 520)
    local grow = gd.grow or "RIGHT"
    local vertical = grow == "UP" or grow == "DOWN" or grow == "CENTER_V"
    local maxIcons
    if vertical then
        maxIcons = opts.maxVerticalIcons or 4
    else
        maxIcons = math.max(1, math.floor((availableW + math.max(0, spacing)) / math.max(1, iconW + math.max(0, spacing))))
        maxIcons = math.min(maxIcons, opts.maxIcons or 8)
    end
    local minIcons = math.max(1, PreviewNumber(opts.minIcons, 1))
    local count = math.max(minIcons, math.min(#spells, maxIcons))
    count = math.min(count, maxIcons)
    local stepX = iconW + spacing
    local stepY = iconH + spacing

    for i = 1, count do
        local rawID = spells[i]
        local displayID = rawID and ((opts.resolveSpellID and opts.resolveSpellID(rawID)) or Shared.GetDisplaySpellID(rawID)) or nil
        local preview = Shared.CreateDummyIconPreview(body, {
            width = iconW,
            height = iconH,
            displaySpellID = displayID,
            inactive = true,
            cooldownText = opts.cooldownText or "1.4",
            secondaryText = opts.secondaryText or "2",
            cooldownFontSize = gd.cooldownFontSize or 12,
            cooldownColor = gd.cooldownColor,
            secondaryFontSize = gd[tf.sizeKey] or tf.sizeDefault or 15,
            secondaryColor = gd[tf.colorKey],
            secondaryPosition = gd[tf.posKey] or tf.posDefault or "BOTTOMRIGHT",
            secondaryOffsetX = gd[tf.xKey] or 0,
            secondaryOffsetY = gd[tf.yKey] or 0,
        })
        if vertical then
            local index = (grow == "UP") and (count - i) or (i - 1)
            preview:SetPoint("TOPLEFT", 0, -(index * stepY))
        else
            local index = (grow == "LEFT") and (count - i) or (i - 1)
            preview:SetPoint("TOPLEFT", index * stepX, 0)
        end
    end

    if vertical then
        return (count * iconH) + ((count - 1) * spacing) + 8
    end
    return iconH + 8
end

function Shared.RenderSpellPicker(config)
    local _, rc = config.createRightScrollContent(config.minHeight or 400)

    local header = rc:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font18")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetText(config.headerText)
    header:SetTextColor(config.headerColor.r, config.headerColor.g, config.headerColor.b, 1)

    local yOff = -34
    if config.helpText then
        local helpText = rc:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font12")
        helpText:SetPoint("TOPLEFT", 0, yOff)
        helpText:SetPoint("TOPRIGHT", rc, "TOPRIGHT", config.helpButtonText and -136 or -8, yOff)
        helpText:SetJustifyH("LEFT")
        helpText:SetWordWrap(true)
        helpText:SetText(config.helpText)
        UI.SetTextMuted(helpText)

        local helpHeight = helpText:GetStringHeight()
        if config.helpButtonText and config.onHelpButton then
            local helpButton = UI.CreateActionButton(rc, config.helpButtonText, 124, 22)
            helpButton:SetPoint("TOPRIGHT", rc, "TOPRIGHT", 0, yOff + 2)
            helpButton:SetScript("OnClick", config.onHelpButton)
            helpHeight = math.max(helpHeight, 22)
        end

        yOff = yOff - helpHeight - 18
    end

    if config.isCacheMissing then
        local msg = rc:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
        msg:SetPoint("TOPLEFT", 0, yOff)
        msg:SetText(config.cacheMissingText)
        UI.SetTextMuted(msg)
        rc:SetHeight(math.abs(yOff) + msg:GetStringHeight() + 34)
    elseif not config.spells or #config.spells == 0 then
        local msg = rc:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
        msg:SetPoint("TOPLEFT", 0, yOff)
        msg:SetPoint("TOPRIGHT", rc, "TOPRIGHT", -8, yOff)
        msg:SetJustifyH("LEFT")
        msg:SetWordWrap(true)
        msg:SetText(config.emptyText)
        UI.SetTextMuted(msg)
        rc:SetHeight(math.abs(yOff) + msg:GetStringHeight() + 34)
    else
        for _, entry in ipairs(config.spells) do
            local row = CreateFrame("Button", nil, rc)
            row:SetSize(300, 30)
            row:SetPoint("TOPLEFT", 0, yOff)

            local iconTex = row:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(24, 24)
            iconTex:SetPoint("LEFT", 0, 0)
            if entry.icon then
                iconTex:SetTexture(entry.icon)
            end

            local label = row:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
            label:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
            label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            label:SetJustifyH("LEFT")
            if config.currentSpecID == config.playerSpecID and entry.isKnown == false then
                label:SetTextColor(0.5, 0.5, 0.5, 1)
            end
            label:SetText(entry.name)

            local sid = entry.spellID
            local cdID = entry.cdID
            row:SetScript("OnClick", function()
                config.onSelect(sid, cdID)
            end)

            yOff = yOff - 30
        end

        rc:SetHeight(math.abs(yOff) + 10)
    end

    local doneBtn = UI.CreateActionButton(rc, config.doneText or "Back", 80, 22)
    doneBtn:SetPoint("TOPRIGHT", rc, "TOPRIGHT", 0, 0)
    doneBtn:SetScript("OnClick", config.onDone)

    return rc
end

Shared.LEFT_INSET = 35
Shared.LEFT_WIDTH = 240
Shared.SCROLL_LEFT_PAD = 60
Shared.RIGHT_X = 35 + 240 + 40
Shared.SLIDER_LABEL_W = 120
Shared.SLIDER_W = 200

function Shared.DestroyFrame(frame)
    if not frame then return end
    frame:Hide()
    frame:SetParent(nil)
end

function Shared.CreateSlider(parent, label, minVal, maxVal, currentVal, onChange)
    return UI.CreateModernSlider(parent, label, minVal, maxVal, currentVal, onChange, Shared.SLIDER_LABEL_W, Shared.SLIDER_W)
end

function Shared.SaveVisualRefresh(scope)
    API:MarkSpecDataDirty()
    API:Refresh(scope)
end

function Shared.BuildTextOverrideWidgets(rc, yOff, cfg)
    local CreateSlider = Shared.CreateSlider
    local existingOv = cfg.existingOv
    local ensureOv = cfg.ensureOv
    local save = cfg.save
    local f = cfg.fields
    local d = cfg.defaults

    if cfg.showHeader then
        yOff = yOff - 10
        local ovHeader = rc:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font18")
        ovHeader:SetPoint("TOPLEFT", 0, yOff)
        ovHeader:SetText(L["Text Overrides"])
        ovHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        yOff = yOff - 34
    end

    local useTextOv = existingOv and existingOv.textOverride
    local textOvCheckbox = UI.CreateModernCheckbox(rc,
        L["Override Text Settings"],
        useTextOv or false,
        function(checked)
            local ov = ensureOv()
            if not ov then return end
            ov.textOverride = checked or nil
            save()
            if cfg.onToggle then cfg.onToggle(checked) end
        end
    )
    textOvCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 36

    if useTextOv then
        local ov = existingOv or {}
        local function write(key, value)
            local o = ensureOv()
            if o then o[key] = value end
            save()
        end
        local function writeColor(key, r, g, b, a)
            local o = ensureOv()
            if o then o[key] = cfg.colorAlpha and { r = r, g = g, b = b, a = a or 1 } or { r = r, g = g, b = b } end
            save()
        end

        local cdFS = CreateSlider(rc, L["Cooldown Size"], 6, 32,
            ov[f.cdSize] or d[f.cdSize], function(v) write(f.cdSize, v) end)
        cdFS:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local cdColorLabel = rc:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
        cdColorLabel:SetText(L["Cooldown Color"])
        cdColorLabel:SetPoint("TOPLEFT", 0, yOff)
        local cdColorPicker = UI.CreateSimpleColorPicker(rc,
            ov[f.cdColor] or d[f.cdColor] or { r = 1, g = 1, b = 1 },
            function(r, g, b, a) writeColor(f.cdColor, r, g, b, a) end,
            cfg.colorAlpha and true or false)
        cdColorPicker:SetPoint("LEFT", cdColorLabel, "RIGHT", 6, 0)
        yOff = yOff - 30

        local chargeFS = CreateSlider(rc, L["Charge Size"], 6, 32,
            ov[f.chargeSize] or d[f.chargeSize], function(v) write(f.chargeSize, v) end)
        chargeFS:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local chargeColorLabel = rc:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
        chargeColorLabel:SetText(L["Charge Color"])
        chargeColorLabel:SetPoint("TOPLEFT", 0, yOff)
        local chargeColorPicker = UI.CreateSimpleColorPicker(rc,
            ov[f.chargeColor] or d[f.chargeColor] or { r = 1, g = 1, b = 1 },
            function(r, g, b, a) writeColor(f.chargeColor, r, g, b, a) end,
            cfg.colorAlpha and true or false)
        chargeColorPicker:SetPoint("LEFT", chargeColorLabel, "RIGHT", 6, 0)
        yOff = yOff - 30

        local posLabel = rc:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
        posLabel:SetText(L["Position"])
        posLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 22
        local posDropdown = cfg.createDropdown(rc)
        posDropdown:SetWidth(180)
        posDropdown:SetPoint("TOPLEFT", 0, yOff)
        posDropdown:SetDefaultText(ov[f.chargePos] or d[f.chargePos] or "BOTTOMRIGHT")
        UI.SetupPositionDropdown(posDropdown,
            function() return ov[f.chargePos] or d[f.chargePos] or "BOTTOMRIGHT" end,
            function(val) write(f.chargePos, val) end
        )
        yOff = yOff - 40

        local xSlider = CreateSlider(rc, L["X Offset"], -20, 20,
            ov[f.chargeX] or d[f.chargeX] or 0, function(v) write(f.chargeX, v) end)
        xSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local ySlider = CreateSlider(rc, L["Y Offset"], -20, 20,
            ov[f.chargeY] or d[f.chargeY] or 0, function(v) write(f.chargeY, v) end)
        ySlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50
    end

    return yOff
end

function Shared.CreateQueueLeftPanelRefresh(containerFrame, getRefreshAllFn)
    local queued = false
    return function(delay)
        if queued then return end
        queued = true
        C_Timer.After(delay or 0.1, function()
            queued = false
            if containerFrame:IsShown() and getRefreshAllFn() then
                getRefreshAllFn()()
            end
        end)
    end
end

local function ResolveWidgetRoot(widget)
    if type(widget) ~= "table" then
        return widget
    end
    return widget.root or widget.row or widget.frame
end

function Shared.CreateWidgetPool(factory, reset)
    local active = {}
    local inactive = {}

    local function ReleaseInternal(widget)
        if not widget then return end
        if reset then
            reset(widget)
        end
        local root = ResolveWidgetRoot(widget)
        if root then
            root:Hide()
            root:ClearAllPoints()
        end
        inactive[#inactive + 1] = widget
    end

    return {
        Acquire = function(_, parent)
            local widget = table.remove(inactive)
            if not widget then
                widget = factory(parent)
            end

            local root = ResolveWidgetRoot(widget)
            if root and root:GetParent() ~= parent then
                root:SetParent(parent)
            end
            if root then
                root:Show()
            end

            active[#active + 1] = widget
            return widget
        end,
        ReleaseAll = function(_)
            for i = #active, 1, -1 do
                local widget = active[i]
                active[i] = nil
                ReleaseInternal(widget)
            end
        end,
    }
end

function Shared.CreateViewerSettingsCallbacks(queueFn)
    local owners = {}
    local api = API

    local function Register()
        if not (api and api.RegisterCooldownViewerSettingsCallback) then return end
        if owners[1] then return end
        local o1, o2, o3, o4 = {}, {}, {}, {}
        owners[1], owners[2], owners[3], owners[4] = o1, o2, o3, o4
        api:RegisterCooldownViewerSettingsCallback("onShow", function() queueFn(0.2) end, o1)
        api:RegisterCooldownViewerSettingsCallback("onHide", function() queueFn(0.2) end, o2)
        api:RegisterCooldownViewerSettingsCallback("onDataChanged", function() queueFn(0.2) end, o3)
        api:RegisterCooldownViewerSettingsCallback("onPendingChanges", function() queueFn(0.3) end, o4)
    end

    local function Unregister()
        if not (api and api.UnregisterCooldownViewerSettingsCallback) then return end
        if not owners[1] then return end
        api:UnregisterCooldownViewerSettingsCallback("onShow", owners[1])
        api:UnregisterCooldownViewerSettingsCallback("onHide", owners[2])
        api:UnregisterCooldownViewerSettingsCallback("onDataChanged", owners[3])
        api:UnregisterCooldownViewerSettingsCallback("onPendingChanges", owners[4])
        table.wipe(owners)
    end

    return Register, Unregister
end

function Shared.CreateSpecDropdown(parent, anchorPoint, anchorX, anchorY, config)
    local L = Runtime.L

    local dropdown = UI.CreateDropdown(parent, 200)
    dropdown:SetPoint(anchorPoint, parent, anchorPoint, anchorX, anchorY)

    local function GetText()
        local cur = config.getCurrentSpecID()
        if cur == config.getPlayerSpecID() then return L["Current Spec"] end
        if cur then return GetSpecLabel(cur) or L["Current Spec"] end
        return L["Current Spec"]
    end

    local function SetSelection(specID)
        C_Timer.After(0, function()
            if not parent:IsShown() then return end
            config.onSelectionChange(specID)
            dropdown:OverrideText(GetText())
        end)
    end

    local function RefreshText()
        dropdown:OverrideText(GetText())
    end

    dropdown:SetDefaultText(GetText())
    dropdown:SetupMenu(function(_, rootDescription)
        rootDescription:CreateRadio(L["Current Spec"], function()
            return config.getCurrentSpecID() == config.getPlayerSpecID()
        end, function()
            SetSelection(config.getPlayerSpecID())
        end)
        rootDescription:CreateDivider()
        for _, classInfo in ipairs(CLASS_LIST) do
            local color = RAID_CLASS_COLORS[classInfo.classTag]
            local coloredName = color and color:WrapTextInColorCode(classInfo.className) or classInfo.className
            local submenu = rootDescription:CreateButton(coloredName)
            local specs = CLASS_SPECS[classInfo.classTag]
            if specs then
                for _, specInfo in ipairs(specs) do
                    submenu:CreateRadio(specInfo.specName, function()
                        return config.getCurrentSpecID() == specInfo.specID
                    end, function()
                        SetSelection(specInfo.specID)
                    end)
                end
            end
        end
    end)

    return dropdown, RefreshText
end

function Shared.CreateGroupEditorPools(parent, config)
    local CDM = Runtime
    local leftWidth = Shared.LEFT_WIDTH
    local iconSize = config and config.iconSize or 30
    local rowHeight = config and config.rowHeight or 36
    local arrowSize = config and config.arrowSize or 29
    local highlightAlpha = config and config.highlightAlpha or 0.2
    local resetBorder = config and config.resetBorder

    local headerPool = Shared.CreateWidgetPool(function(p)
        local header = Shared.CreateExpandableHeader(p, 0, false, "", false)
        header.root = header.row
        return header
    end, function(header)
        header.nameText:Show()
        header.selectBtn:SetScript("OnClick", nil)
        header.deleteBtn:SetScript("OnClick", nil)
        header.expandBtn:SetScript("OnClick", nil)
    end)

    local groupContainerPool = Shared.CreateWidgetPool(function(p)
        local gc = CreateFrame("Frame", nil, p)
        gc:SetSize(leftWidth, 10)
        local hl = gc:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints()
        hl:SetColorTexture(0.2, 0.4, 0.8, highlightAlpha)
        hl:Hide()
        gc.highlight = hl
        return { root = gc, highlight = hl }
    end, function(widget)
        widget.highlight:Hide()
    end)

    local emptyRowPool = Shared.CreateWidgetPool(function(p)
        local f = CreateFrame("Frame", nil, p)
        f:SetSize(leftWidth, rowHeight)
        local t = f:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
        t:SetPoint("LEFT", 10, 0)
        return { root = f, text = t }
    end, function(widget)
        widget.text:SetText("")
    end)

    local spellRowPool = Shared.CreateWidgetPool(function(p)
        local row = CreateFrame("Frame", nil, p)
        row:SetSize(leftWidth - 20, rowHeight)

        local btnUp = Shared.CreateArrowButton(row, "up", arrowSize)
        btnUp:SetFrameLevel(row:GetFrameLevel() + 5)

        local btnDown = Shared.CreateArrowButton(row, "down", arrowSize)
        btnDown:SetFrameLevel(row:GetFrameLevel() + 5)

        local iconContainer = CreateFrame("Frame", nil, row)
        iconContainer:SetSize(iconSize, iconSize)
        local iconTex = iconContainer:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints()
        CDM_C.ApplyIconTexCoord(iconTex, CDM_C.GetEffectiveZoomAmount())

        if CDM.BORDER and CDM.BORDER.CreateBorder then
            iconContainer.cdmBorder = CDM.BORDER:CreateBorder(iconContainer)
            if CDM.BORDER.activeBorders then
                CDM.BORDER.activeBorders[iconContainer] = nil
            end
        end

        local removeBtn = CreateFrame("Button", nil, row)
        removeBtn:SetSize(16, 16)
        removeBtn:SetPoint("RIGHT", -6, 0)
        removeBtn:SetFrameLevel(row:GetFrameLevel() + 2)
        local removeBtnText = Shared.ApplyRemoveButtonText(removeBtn)

        local nameText = row:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font12")
        nameText:SetJustifyH("LEFT")

        local clickBtn = CreateFrame("Button", nil, row)
        clickBtn:SetAllPoints()
        clickBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        clickBtn:RegisterForDrag("LeftButton")
        clickBtn:SetFrameLevel(row:GetFrameLevel() + 1)

        local widget = {
            root = row,
            btnUp = btnUp,
            btnDown = btnDown,
            iconContainer = iconContainer,
            iconTex = iconTex,
            removeBtn = removeBtn,
            removeBtnText = removeBtnText,
            nameText = nameText,
            clickBtn = clickBtn,
        }
        Shared.LayoutGroupEditorRow(widget, false)

        return widget
    end, function(widget)
        widget.btnUp:Hide()
        widget.btnUp:SetScript("OnClick", nil)
        widget.btnDown:Hide()
        widget.btnDown:SetScript("OnClick", nil)
        widget.removeBtn:Hide()
        widget.removeBtn:SetScript("OnClick", nil)
        widget.clickBtn:SetScript("OnClick", nil)
        widget.clickBtn:SetScript("OnDragStart", nil)
        widget.clickBtn:SetScript("OnDragStop", nil)
        widget.nameText:SetText("")
        widget.iconTex:SetTexture(nil)
        widget.iconTex:SetDesaturated(false)
        widget.iconTex:SetAlpha(1)
        Shared.LayoutGroupEditorRow(widget, false)
        if widget.iconContainer.cdmBorder then
            widget.iconContainer.cdmBorder:SetAlpha(1)
            if resetBorder then
                resetBorder(widget.iconContainer.cdmBorder)
            end
        end
    end)

    return headerPool, groupContainerPool, emptyRowPool, spellRowPool
end

function Shared.CreateBarRowPool(_, config)
    local CDM = Runtime
    local leftWidth = Shared.LEFT_WIDTH
    local rowHeight = config and config.rowHeight or 36
    local barHeight = config and config.barHeight or 30
    local iconSize = config and config.iconSize or 30
    local arrowSize = config and config.arrowSize or 29

    return Shared.CreateWidgetPool(function(p)
        local row = CreateFrame("Frame", nil, p)
        row:SetSize(leftWidth - 20, rowHeight)

        local btnUp = Shared.CreateArrowButton(row, "up", arrowSize)
        btnUp:SetFrameLevel(row:GetFrameLevel() + 5)

        local btnDown = Shared.CreateArrowButton(row, "down", arrowSize)
        btnDown:SetFrameLevel(row:GetFrameLevel() + 5)

        local iconContainer = CreateFrame("Frame", nil, row)
        iconContainer:SetSize(iconSize, iconSize)
        local iconTex = iconContainer:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints()
        CDM_C.ApplyIconTexCoord(iconTex, CDM_C.GetEffectiveZoomAmount())

        if CDM.BORDER and CDM.BORDER.CreateBorder then
            iconContainer.cdmBorder = CDM.BORDER:CreateBorder(iconContainer)
            if CDM.BORDER.activeBorders then
                CDM.BORDER.activeBorders[iconContainer] = nil
            end
        end

        local bar = CreateFrame("StatusBar", nil, row)
        bar:SetHeight(barHeight)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)

        local barBg = bar:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints()

        local nameText = bar:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font12")
        nameText:SetPoint("LEFT", bar, "LEFT", 6, 0)
        nameText:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
        nameText:SetJustifyH("LEFT")

        if CDM.BORDER and CDM.BORDER.CreateBorder then
            bar.cdmBorder = CDM.BORDER:CreateBorder(bar)
            if CDM.BORDER.activeBorders then
                CDM.BORDER.activeBorders[bar] = nil
            end
        end

        local clickBtn = CreateFrame("Button", nil, row)
        clickBtn:SetAllPoints()
        clickBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        clickBtn:RegisterForDrag("LeftButton")
        clickBtn:SetFrameLevel(row:GetFrameLevel() + 1)

        local removeBtn = CreateFrame("Button", nil, row)
        removeBtn:SetSize(16, 16)
        removeBtn:SetPoint("RIGHT", -6, 0)
        removeBtn:SetFrameLevel(clickBtn:GetFrameLevel() + 1)
        local removeBtnText = Shared.ApplyRemoveButtonText(removeBtn)

        bar:SetPoint("LEFT", iconContainer, "RIGHT", 4, 0)
        bar:SetPoint("RIGHT", removeBtn, "LEFT", -4, 0)

        local widget = {
            root = row,
            btnUp = btnUp,
            btnDown = btnDown,
            iconContainer = iconContainer,
            iconTex = iconTex,
            bar = bar,
            barBg = barBg,
            nameText = nameText,
            removeBtn = removeBtn,
            removeBtnText = removeBtnText,
            clickBtn = clickBtn,
        }
        Shared.LayoutGroupEditorRow(widget, false)

        return widget
    end, function(widget)
        widget.btnUp:Hide()
        widget.btnUp:SetScript("OnClick", nil)
        widget.btnDown:Hide()
        widget.btnDown:SetScript("OnClick", nil)
        widget.removeBtn:Hide()
        widget.removeBtn:SetScript("OnClick", nil)
        widget.clickBtn:SetScript("OnClick", nil)
        widget.clickBtn:SetScript("OnDragStart", nil)
        widget.clickBtn:SetScript("OnDragStop", nil)
        widget.nameText:SetText("")
        widget.iconTex:SetTexture(nil)
        widget.iconTex:SetDesaturated(false)
        widget.iconTex:SetAlpha(1)
        Shared.LayoutGroupEditorRow(widget, false)
        widget.bar:SetAlpha(1)
        widget.barBg:SetAlpha(1)
    end)
end

function Shared.AcquireEmptyRow(pool, parent, text)
    local widget = pool:Acquire(parent)
    widget.root:SetPoint("TOPLEFT", 0, 0)
    widget.text:SetText(text)
    UI.SetTextFaint(widget.text)
    return widget
end

function Shared.CreateGroupEditorHelpers(config)
    local CDM = Runtime
    local dbKey = config.dbKey
    local ungroupedDbKey = config.ungroupedDbKey
    local getCurrentSpecID = config.getCurrentSpecID
    local setCurrentSpecID = config.setCurrentSpecID
    local getPlayerSpecID = config.getPlayerSpecID
    local setPlayerSpecID = config.setPlayerSpecID
    local normalizeToBase = config.normalizeToBase
    local extraCloneFields = config.extraCloneFields

    local function RefreshCurrentSpecID()
        local si = GetSpecialization()
        local newPlayerSpec = si and GetSpecializationInfo(si) or nil
        local wasViewingPlayer = (getCurrentSpecID() == getPlayerSpecID()) or (getCurrentSpecID() == nil)
        setPlayerSpecID(newPlayerSpec)
        if wasViewingPlayer then setCurrentSpecID(newPlayerSpec) end
    end

    local function EnsureGroups()
        local specID = getCurrentSpecID()
        if not specID then return nil end
        if not CDM.db[dbKey] then CDM.db[dbKey] = {} end
        if not CDM.db[dbKey][specID] then CDM.db[dbKey][specID] = {} end
        return CDM.db[dbKey][specID]
    end

    local function GetSpecGroups()
        local specID = getCurrentSpecID()
        if not specID then return nil end
        local tbl = CDM.db[dbKey]
        return tbl and tbl[specID]
    end

    local function EnsureUngroupedOverrides()
        local specID = getCurrentSpecID()
        if not specID then return nil end
        if not CDM.db[ungroupedDbKey] then CDM.db[ungroupedDbKey] = {} end
        if not CDM.db[ungroupedDbKey][specID] then CDM.db[ungroupedDbKey][specID] = {} end
        return CDM.db[ungroupedDbKey][specID]
    end

    local function GetUngroupedOverride(spellID)
        local specID = getCurrentSpecID()
        if not specID then return nil end
        local specOv = CDM.db[ungroupedDbKey] and CDM.db[ungroupedDbKey][specID]
        return Shared.GetMergedOverrideEntry(specOv, spellID)
    end

    local function HelpersEnsureResolvedOverrideEntry(overrideMap, spellID)
        return Shared.EnsureResolvedOverrideEntry(overrideMap, spellID, normalizeToBase)
    end

    local function HelpersExtractMergedOverrideEntry(overrideMap, spellID)
        return Shared.ExtractMergedOverrideEntry(overrideMap, spellID)
    end

    local function HelpersStoreMergedOverrideEntry(overrideMap, spellID, incoming)
        Shared.StoreMergedOverrideEntry(overrideMap, spellID, incoming, normalizeToBase)
    end

    local function HelpersEnsureSpellOverride(groupIndex, spellID)
        local groups = GetSpecGroups()
        if not groups or not groups[groupIndex] then return nil end
        local gd = groups[groupIndex]
        if not gd.spellOverrides then gd.spellOverrides = {} end
        return HelpersEnsureResolvedOverrideEntry(gd.spellOverrides, spellID)
    end

    local function HelpersEnsureUngroupedOverrideEntry(spellID)
        local specOv = EnsureUngroupedOverrides()
        if not specOv then return nil end
        return HelpersEnsureResolvedOverrideEntry(specOv, spellID)
    end

    local function HelpersCreateLayoutOnlyGroupClone(groups, groupData)
        local clone = {
            name = Shared.GetUniqueGroupName(groups, groupData.name or "Group"),
            spells = {},
            grow = groupData.grow,
            spacing = groupData.spacing,
            iconWidth = groupData.iconWidth,
            iconHeight = groupData.iconHeight,
            cooldownFontSize = groupData.cooldownFontSize,
            anchorTarget = groupData.anchorTarget,
            anchorPoint = groupData.anchorPoint,
            anchorRelativeTo = groupData.anchorRelativeTo,
            offsetX = groupData.offsetX,
            offsetY = groupData.offsetY,
        }
        if groupData.cooldownColor then
            clone.cooldownColor = { r = groupData.cooldownColor.r, g = groupData.cooldownColor.g, b = groupData.cooldownColor.b, a = groupData.cooldownColor.a }
        end
        if extraCloneFields then
            for _, key in ipairs(extraCloneFields) do
                local val = groupData[key]
                if type(val) == "table" and val.r ~= nil then
                    clone[key] = { r = val.r, g = val.g, b = val.b, a = val.a }
                else
                    clone[key] = val
                end
            end
        end
        return clone
    end

    local function HelpersCopyGroupSettingsToSpec(groupData, targetSpecID)
        if not CDM.db[dbKey] then CDM.db[dbKey] = {} end
        if not CDM.db[dbKey][targetSpecID] then CDM.db[dbKey][targetSpecID] = {} end
        local targetGroups = CDM.db[dbKey][targetSpecID]
        targetGroups[#targetGroups + 1] = HelpersCreateLayoutOnlyGroupClone(targetGroups, groupData)
    end

    local function HelpersDuplicateGroup(groupData, specGroups)
        specGroups[#specGroups + 1] = HelpersCreateLayoutOnlyGroupClone(specGroups, groupData)
        return #specGroups
    end

    return {
        RefreshCurrentSpecID = RefreshCurrentSpecID,
        EnsureGroups = EnsureGroups,
        GetSpecGroups = GetSpecGroups,
        EnsureUngroupedOverrides = EnsureUngroupedOverrides,
        GetUngroupedOverride = GetUngroupedOverride,
        EnsureResolvedOverrideEntry = HelpersEnsureResolvedOverrideEntry,
        ExtractMergedOverrideEntry = HelpersExtractMergedOverrideEntry,
        StoreMergedOverrideEntry = HelpersStoreMergedOverrideEntry,
        EnsureSpellOverride = HelpersEnsureSpellOverride,
        EnsureUngroupedOverrideEntry = HelpersEnsureUngroupedOverrideEntry,
        CreateLayoutOnlyGroupClone = HelpersCreateLayoutOnlyGroupClone,
        CopyGroupSettingsToSpec = HelpersCopyGroupSettingsToSpec,
        DuplicateGroup = HelpersDuplicateGroup,
    }
end

function Shared.RenderGroupSettingsPanel(config)
    local rc = config.rc
    local gd = config.gd
    local groupIndex = config.groupIndex
    local registerDropdown = config.registerDropdown
    local save = config.saveAndRefresh
    local slider = config.createSlider
    local L = config.L
    local tf = config.textFields
    local statePrefix = config.statePrefix or "group-settings"
    local sectionW = math.max(540, math.min(680, (rc.GetWidth and rc:GetWidth() or 0) - 6))
    local sections = {}
    local Relayout

    local nameHeader = rc:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font18")
    nameHeader:SetPoint("TOPLEFT", 0, 0)
    nameHeader:SetText(gd.name or ("Group " .. groupIndex))
    nameHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)

    local function AddSection(title, key, height, defaultOpen)
        local section, body = UI.CreateAccordionSection(rc, title, sectionW, height, statePrefix .. ":" .. tostring(groupIndex) .. ":" .. key, defaultOpen, function()
            if Relayout then Relayout() end
        end)
        sections[#sections + 1] = section
        return section, body
    end

    Relayout = function()
        local bottom = UI.LayoutAccordionSections(sections, -40, 8)
        rc:SetHeight(math.abs(bottom) + 24)
    end

    local previewSection, previewBody = AddSection((L and L["Preview"]) or "Preview", "preview", 70, true)
    previewSection:SetContentHeight(Shared.RenderGroupPreview(previewBody, gd, {
        textFields = tf,
        width = sectionW - 28,
        resolveSpellID = config.resolveSpellID,
        secondaryText = config.previewSecondaryText,
        minIcons = config.previewMinIcons,
    }))

    local layoutSection, layoutBody = AddSection(L["Layout"], "layout", 280, true)
    local yOff = 0

    local growLabel = layoutBody:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    growLabel:SetText(L["Grow Direction"])
    growLabel:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 22

    local growDropdown = registerDropdown(UI.CreateDropdown(layoutBody, 180, Shared.GetGrowLabel(gd.grow or "RIGHT")))
    growDropdown:SetPoint("TOPLEFT", 0, yOff)
    UI.SetupValueDropdown(growDropdown, Shared.GROW_OPTIONS,
        function() return gd.grow or "RIGHT" end,
        function(val) gd.grow = val; save() end
    )
    yOff = yOff - 40

    if config.preSpacingSection then
        yOff = config.preSpacingSection(layoutBody, yOff)
    end

    local spacingSlider = slider(layoutBody, L["Spacing"], -1, 50, gd.spacing or 4, function(v)
        gd.spacing = v; save()
    end)
    spacingSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    local widthSlider = slider(layoutBody, L["Icon Width"], 16, 100, gd.iconWidth or 30, function(v)
        gd.iconWidth = v; save()
    end)
    widthSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    local heightSlider = slider(layoutBody, L["Icon Height"], 16, 100, gd.iconHeight or 30, function(v)
        gd.iconHeight = v; save()
    end)
    heightSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    if config.postSizeSection then
        yOff = config.postSizeSection(layoutBody, yOff)
    end
    layoutSection:SetContentHeight(math.abs(yOff) + 4)

    local textSection, textBody = AddSection(L["Text"], "text", 330, true)
    yOff = 0

    local cdFSSlider = slider(textBody, L["Cooldown Size"], 6, 32, gd.cooldownFontSize or 12, function(v)
        gd.cooldownFontSize = v; save()
    end)
    cdFSSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    local cdColorLabel = textBody:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    cdColorLabel:SetText(L["Color"])
    cdColorLabel:SetPoint("TOPLEFT", 0, yOff)
    local cdColorInit = gd.cooldownColor or { r = 1, g = 1, b = 1 }
    local cdColorPicker = UI.CreateSimpleColorPicker(textBody, cdColorInit, function(r, g, b, a)
        if not gd.cooldownColor then gd.cooldownColor = { r = 1, g = 1, b = 1, a = 1 } end
        gd.cooldownColor.r, gd.cooldownColor.g, gd.cooldownColor.b = r, g, b
        gd.cooldownColor.a = a or 1
        save()
    end, true)
    cdColorPicker:SetPoint("LEFT", cdColorLabel, "RIGHT", 6, 0)
    yOff = yOff - 30

    local secFSSlider = slider(textBody, L["Charge Size"], 6, 32, gd[tf.sizeKey] or tf.sizeDefault, function(v)
        gd[tf.sizeKey] = v; save()
    end)
    secFSSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    local secColorLabel = textBody:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    secColorLabel:SetText(L["Color"])
    secColorLabel:SetPoint("TOPLEFT", 0, yOff)
    local secColorInit = gd[tf.colorKey] or { r = 1, g = 1, b = 1 }
    local secColorPicker = UI.CreateSimpleColorPicker(textBody, secColorInit, function(r, g, b, a)
        if not gd[tf.colorKey] then gd[tf.colorKey] = { r = 1, g = 1, b = 1, a = 1 } end
        gd[tf.colorKey].r, gd[tf.colorKey].g, gd[tf.colorKey].b = r, g, b
        gd[tf.colorKey].a = a or 1
        save()
    end, true)
    secColorPicker:SetPoint("LEFT", secColorLabel, "RIGHT", 6, 0)
    yOff = yOff - 30

    local secPosLabel = textBody:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    secPosLabel:SetText(L["Position"])
    secPosLabel:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 22

    local secPosDropdown = registerDropdown(UI.CreateDropdown(textBody, 180, gd[tf.posKey] or tf.posDefault))
    secPosDropdown:SetPoint("TOPLEFT", 0, yOff)
    UI.SetupPositionDropdown(secPosDropdown,
        function() return gd[tf.posKey] or tf.posDefault end,
        function(val) gd[tf.posKey] = val; save() end
    )
    yOff = yOff - 40

    local secXSlider = slider(textBody, L["X Offset"], -20, 20, gd[tf.xKey] or 0, function(v)
        gd[tf.xKey] = v; save()
    end)
    secXSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    local secYSlider = slider(textBody, L["Y Offset"], -20, 20, gd[tf.yKey] or 0, function(v)
        gd[tf.yKey] = v; save()
    end)
    secYSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50
    textSection:SetContentHeight(math.abs(yOff) + 4)

    local anchorSection, anchorBody = AddSection(L["Anchor"], "anchor", 300, true)
    yOff = 0

    local anchorTargetLabel = anchorBody:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    anchorTargetLabel:SetText(L["Anchor To"])
    anchorTargetLabel:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 22

    local UpdateAnchorVisibility
    local xSlider, ySlider
    local anchorTargetDropdown = registerDropdown(UI.CreateDropdown(anchorBody, 180))
    anchorTargetDropdown:SetPoint("TOPLEFT", 0, yOff)
    local currentTarget = gd.anchorTarget or "screen"
    local anchorTargets = config.anchorTargets
    local targetLabelMap = {}
    for _, entry in ipairs(anchorTargets) do
        targetLabelMap[entry.value] = entry.label
    end
    anchorTargetDropdown:SetDefaultText(targetLabelMap[currentTarget] or targetLabelMap.screen or "Screen")
    UI.SetupValueDropdown(anchorTargetDropdown, anchorTargets,
        function() return gd.anchorTarget or "screen" end,
        function(val)
            local prev = gd.anchorTarget or "screen"
            gd.anchorTarget = val
            gd.anchorPoint = gd.anchorPoint or "CENTER"
            gd.anchorRelativeTo = gd.anchorRelativeTo or "CENTER"
            if val ~= prev then
                gd.offsetX = 0
                gd.offsetY = 0
                xSlider:UpdateUIValue(0)
                ySlider:UpdateUIValue(0)
            end
            save()
            UpdateAnchorVisibility()
        end
    )
    yOff = yOff - 40
    local yAfterTarget = yOff

    local anchorLabel = anchorBody:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    anchorLabel:SetText(L["Anchor Point"])
    anchorLabel:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 22

    local anchorDropdown = registerDropdown(UI.CreateDropdown(anchorBody, 180, gd.anchorPoint or "CENTER"))
    anchorDropdown:SetPoint("TOPLEFT", 0, yOff)
    UI.SetupPositionDropdown(anchorDropdown,
        function() return gd.anchorPoint or "CENTER" end,
        function(val) gd.anchorPoint = val; save() end
    )
    yOff = yOff - 40

    local relLabel = anchorBody:CreateFontString(nil, "OVERLAY", "MidnightCDM_Font14")
    relLabel:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 22

    local relDropdown = registerDropdown(UI.CreateDropdown(anchorBody, 180, gd.anchorRelativeTo or "CENTER"))
    relDropdown:SetPoint("TOPLEFT", 0, yOff)
    UI.SetupPositionDropdown(relDropdown,
        function() return gd.anchorRelativeTo or "CENTER" end,
        function(val) gd.anchorRelativeTo = val; save() end
    )
    yOff = yOff - 40
    local yAfterConditional = yOff

    xSlider = slider(anchorBody, L["X Offset"], -840, 840, gd.offsetX or 0, function(v)
        gd.offsetX = v; save()
    end)
    xSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    ySlider = slider(anchorBody, L["Y Offset"], -470, 470, gd.offsetY or 0, function(v)
        gd.offsetY = v; save()
    end)
    ySlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    local anchorRelLabels = config.anchorRelLabels or {}
    UpdateAnchorVisibility = function()
        local isScreen = (gd.anchorTarget or "screen") == "screen"
        anchorLabel:SetShown(not isScreen)
        anchorDropdown:SetShown(not isScreen)
        relLabel:SetShown(not isScreen)
        relDropdown:SetShown(not isScreen)
        if not isScreen then
            local target = gd.anchorTarget
            relLabel:SetText(anchorRelLabels[target] or (L["Essential Viewer Point"]))
            anchorDropdown:SetDefaultText(gd.anchorPoint or "CENTER")
            relDropdown:SetDefaultText(gd.anchorRelativeTo or "CENTER")
        end
        local sliderY = isScreen and yAfterTarget or yAfterConditional
        xSlider:ClearAllPoints(); xSlider:SetPoint("TOPLEFT", 0, sliderY)
        ySlider:ClearAllPoints(); ySlider:SetPoint("TOPLEFT", 0, sliderY - 50)
        anchorSection:SetContentHeight(math.abs(sliderY - 100) + 4)
        if Relayout then Relayout() end
    end
    UpdateAnchorVisibility()
    Relayout()
end
