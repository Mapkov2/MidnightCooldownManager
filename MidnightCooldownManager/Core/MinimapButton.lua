local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]

local ICON_PATH = "Interface\\AddOns\\MidnightCooldownManager\\Media\\MCDM_MinimapIcon.tga"
local LDB_NAME = "MidnightCooldownManager"

local abs = math.abs
local atan = math.atan
local cos = math.cos
local deg = math.deg
local pi = math.pi
local rad = math.rad
local sin = math.sin

local MinimapButton = {
    fallbackButton = nil,
    dataObject = nil,
    dbIconRegistered = false,
    usesDBIcon = false,
}

CDM.MinimapButton = MinimapButton

local function atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end
    if x > 0 then
        return atan(y / x)
    end
    if x < 0 and y >= 0 then
        return atan(y / x) + pi
    end
    if x < 0 and y < 0 then
        return atan(y / x) - pi
    end
    if x == 0 and y > 0 then
        return pi / 2
    end
    if x == 0 and y < 0 then
        return -pi / 2
    end
    return 0
end

local function EnsureMinimapState()
    MidnightCooldownManagerDB = MidnightCooldownManagerDB or {}
    MidnightCooldownManagerDB.global = MidnightCooldownManagerDB.global or {}

    local global = MidnightCooldownManagerDB.global
    if global.showMinimapIcon == nil then
        global.showMinimapIcon = true
    end

    local db = global.minimapIconDB
    if type(db) ~= "table" then
        db = {}
        global.minimapIconDB = db
    end

    if type(db.minimapPos) ~= "number" then
        db.minimapPos = 220
    end
    if type(db.radius) ~= "number" then
        db.radius = 80
    end
    db.hide = not global.showMinimapIcon

    return global, db
end

local function OpenConfig()
    if CDM.RequestConfigOpen then
        CDM:RequestConfigOpen("minimap", nil)
    end
end

local function ToggleMover()
    if CDM.ToggleMoveMode then
        CDM:ToggleMoveMode()
    end
end

local function OnClick(_, button)
    if MinimapButton.wasDragged then
        return
    end
    if button == "RightButton" then
        ToggleMover()
        return
    end
    OpenConfig()
end

local function AddTooltipLines(tooltip)
    tooltip:SetText("Midnight Simple Cooldown", 1, 1, 1)
    tooltip:AddLine("Left-click: Open MCDM", 0.35, 0.82, 1)
    tooltip:AddLine("Right-click: Toggle Move Mode", 0.35, 0.82, 1)
    tooltip:AddLine("Drag: Move minimap icon", 0.65, 0.72, 0.86)
    tooltip:AddLine("/mcdm", 0.65, 0.72, 0.86)
end

local function OnTooltipShow(tooltip)
    if tooltip and tooltip.AddLine and tooltip.SetText then
        AddTooltipLines(tooltip)
    end
end

local function OnEnter(button)
    if not GameTooltip then return end
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    AddTooltipLines(GameTooltip)
    GameTooltip:Show()
end

local function OnLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function PlaceFallbackButton(button)
    local _, db = EnsureMinimapState()
    local minimap = _G.Minimap
    if not minimap or not button then return end

    local angle = rad(db.minimapPos or 220)
    local radius = db.radius or 80
    button:ClearAllPoints()
    button:SetPoint("CENTER", minimap, "CENTER", cos(angle) * radius, sin(angle) * radius)
end

local function UpdateFallbackPositionFromCursor(button)
    local minimap = _G.Minimap
    if not minimap then return end

    local scale = minimap:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    local centerX, centerY = minimap:GetCenter()
    if not cursorX or not cursorY or not centerX or not centerY then return end

    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local deltaX = cursorX - centerX
    local deltaY = cursorY - centerY
    if abs(deltaX) < 0.01 and abs(deltaY) < 0.01 then return end

    local _, db = EnsureMinimapState()
    db.minimapPos = deg(atan2(deltaY, deltaX))
    PlaceFallbackButton(button)
end

function MinimapButton:CreateFallbackButton()
    if self.fallbackButton then
        return self.fallbackButton
    end

    local minimap = _G.Minimap
    if not minimap then return nil end

    local button = CreateFrame("Button", "MCDM_MinimapButton", minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((minimap:GetFrameLevel() or 0) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetClampedToScreen(true)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("CENTER")
    background:SetSize(24, 24)
    background:SetVertexColor(0.02, 0.025, 0.035, 1)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON_PATH)
    icon:SetPoint("CENTER")
    icon:SetSize(22, 22)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT", button, "TOPLEFT", -10, 10)
    border:SetSize(54, 54)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(icon)

    button:SetScript("OnClick", OnClick)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", OnLeave)
    button:SetScript("OnDragStart", function(selfButton)
        MinimapButton.wasDragged = true
        selfButton:SetScript("OnUpdate", UpdateFallbackPositionFromCursor)
    end)
    button:SetScript("OnDragStop", function(selfButton)
        selfButton:SetScript("OnUpdate", nil)
        PlaceFallbackButton(selfButton)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() MinimapButton.wasDragged = false end)
        else
            MinimapButton.wasDragged = false
        end
    end)

    self.fallbackButton = button
    PlaceFallbackButton(button)
    return button
end

function MinimapButton:TryRegisterDBIcon(global, db)
    if self.dbIconRegistered then
        return self.usesDBIcon
    end

    local LDB = LibStub and LibStub("LibDataBroker-1.1", true) or nil
    local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true) or nil
    if not (LDB and DBIcon and LDB.NewDataObject and DBIcon.Register) then
        return false
    end

    self.dataObject = self.dataObject or LDB:NewDataObject(LDB_NAME, {
        type = "launcher",
        text = "MCDM",
        label = "MCDM",
        icon = ICON_PATH,
        OnClick = OnClick,
        OnTooltipShow = OnTooltipShow,
    })

    DBIcon:Register(LDB_NAME, self.dataObject, db)
    self.dbIconRegistered = true
    self.usesDBIcon = true

    if global.showMinimapIcon then
        if DBIcon.Show then DBIcon:Show(LDB_NAME) end
    else
        if DBIcon.Hide then DBIcon:Hide(LDB_NAME) end
    end

    return true
end

function MinimapButton:Refresh()
    local global, db = EnsureMinimapState()

    if self:TryRegisterDBIcon(global, db) then
        if self.fallbackButton then
            self.fallbackButton:Hide()
        end
        return
    end

    local button = self:CreateFallbackButton()
    if not button then return end

    if global.showMinimapIcon then
        button:Show()
        PlaceFallbackButton(button)
    else
        button:Hide()
    end
end

function CDM:InitializeMinimapButton()
    MinimapButton:Refresh()
end

function CDM:SetMinimapIconEnabled(enabled)
    local global, db = EnsureMinimapState()
    global.showMinimapIcon = enabled and true or false
    db.hide = not global.showMinimapIcon

    if MinimapButton.usesDBIcon then
        local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true) or nil
        if DBIcon then
            if global.showMinimapIcon and DBIcon.Show then
                DBIcon:Show(LDB_NAME)
            elseif DBIcon.Hide then
                DBIcon:Hide(LDB_NAME)
            end
        end
    end

    MinimapButton:Refresh()
end

function CDM:IsMinimapIconEnabled()
    local global = EnsureMinimapState()
    return global.showMinimapIcon == true
end

function CDM:RefreshMinimapButton()
    MinimapButton:Refresh()
end

function _G.MCDM_SetMinimapIconEnabled(enabled)
    if CDM.SetMinimapIconEnabled then
        CDM:SetMinimapIconEnabled(enabled)
    end
end
