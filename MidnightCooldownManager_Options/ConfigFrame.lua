local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local L = Runtime.L
local CDM_C = CDM and CDM.CONST or {}
local UI = ns.ConfigUI
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local ConfigFrame = nil
local categories = {}
local buttons = {}
local currentTab = nil
local ADDON_NAME = "MidnightCooldownManager"
local versionText = nil
local statusText = nil
local editModeBtn = nil
local discordText = nil
local twitchText = nil
local footerRefreshRegistered = false
local treeSkinRefreshRegistered = false
local lastFooterFont = nil
local combatCloseRegistered = false
local minimizedBar = nil
local navRows = {}
local navGroups = {}
local navSearchBox = nil
local navScrollFrame = nil
local navScrollChild = nil
local treeSkinPending = false
local WINDOW_W, WINDOW_H = 1060, 650
local DEFAULT_WINDOW_W, DEFAULT_WINDOW_H = 1060, 650
local MIN_WINDOW_W, MIN_WINDOW_H = 760, 500
local MAX_WINDOW_W, MAX_WINDOW_H = 1600, 1100
local NAV_W = 174
local SNAP_EDGE_PX = 24
local SNAP_FRAME_EDGE_PX = 4
local SNAP_SCREEN_MARGIN = 14
local MINIMIZED_WINDOW_W, MINIMIZED_WINDOW_H = 300, 32
local SCROLL_FRAME_NAMES = {
    racials = "MidnightCDM_RacialsScrollFrame",
    defensives = "MidnightCDM_DefensivesScrollFrame",
    trinkets = "MidnightCDM_TrinketsScrollFrame",
    sizes = "MidnightCDM_SizesScrollFrame",
    positions = "MidnightCDM_PositionsScrollFrame",
    glow = "MidnightCDM_GlowScrollFrame",
    fading = "MidnightCDM_FadingScrollFrame",
    bars = "MidnightCDM_BarsScrollFrame",
    buffgroups = "MidnightCDM_BuffGroupsLeftScroll",
    resources = "MidnightCDM_ResourcesScrollFrame",
    profiles = "MidnightCDM_ProfilesScrollFrame",
    importexport = "MidnightCDM_ImportExportScrollFrame",
}

local THEME = UI.Theme
local COLORS = THEME and THEME.colors or {}
local floor = math.floor
local max = math.max
local min = math.min

local function ClampNumber(value, minValue, maxValue, fallback)
    value = tonumber(value) or fallback or minValue
    if value < minValue then
        value = minValue
    elseif value > maxValue then
        value = maxValue
    end
    return floor(value + 0.5)
end

local function EnsureGlobalOptionsState()
    if type(MidnightCooldownManagerDB) ~= "table" then return nil end
    MidnightCooldownManagerDB.global = MidnightCooldownManagerDB.global or {}
    local global = MidnightCooldownManagerDB.global
    global.optionsWindow = global.optionsWindow or {}
    return global.optionsWindow
end

local function WindowMaxBounds()
    local maxW, maxH = MAX_WINDOW_W, MAX_WINDOW_H
    local parent = _G.UIParent
    if parent and parent.GetWidth and parent.GetHeight then
        maxW = min(maxW, floor((parent:GetWidth() or maxW) - 28))
        maxH = min(maxH, floor((parent:GetHeight() or maxH) - 28))
    end
    return max(MIN_WINDOW_W, maxW), max(MIN_WINDOW_H, maxH)
end

local function ApplyWindowResizeBounds(frame)
    if not frame then return end
    local maxW, maxH = WindowMaxBounds()
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_WINDOW_W, MIN_WINDOW_H, maxW, maxH)
    else
        if frame.SetMinResize then frame:SetMinResize(MIN_WINDOW_W, MIN_WINDOW_H) end
        if frame.SetMaxResize then frame:SetMaxResize(maxW, maxH) end
    end
end

local function SetWindowMetrics(width, height)
    local maxW, maxH = WindowMaxBounds()
    WINDOW_W = ClampNumber(width, MIN_WINDOW_W, maxW, DEFAULT_WINDOW_W)
    WINDOW_H = ClampNumber(height, MIN_WINDOW_H, maxH, DEFAULT_WINDOW_H)
end

local function WindowVisualScale(frame)
    local parent = _G.UIParent
    if not (frame and frame.GetEffectiveScale and parent and parent.GetEffectiveScale) then return 1 end
    local uiScale = parent:GetEffectiveScale() or 1
    if uiScale == 0 then uiScale = 1 end
    return (frame:GetEffectiveScale() or uiScale) / uiScale
end

local function CursorPositionInUIParent()
    local parent = _G.UIParent
    if not (parent and parent.GetEffectiveScale and _G.GetCursorPosition) then return nil, nil end
    local scale = parent:GetEffectiveScale() or 1
    if scale == 0 then scale = 1 end
    local x, y = _G.GetCursorPosition()
    return (x or 0) / scale, (y or 0) / scale
end

local function CaptureWindowLayout(frame)
    if not (frame and frame.GetLeft and frame.GetTop and frame.GetWidth and frame.GetHeight) then return nil end
    local parent = _G.UIParent
    return {
        x = frame:GetLeft() or SNAP_SCREEN_MARGIN,
        yTop = frame:GetTop() or ((parent and parent.GetHeight and parent:GetHeight()) or DEFAULT_WINDOW_H) - SNAP_SCREEN_MARGIN,
        w = frame:GetWidth() or WINDOW_W,
        h = frame:GetHeight() or WINDOW_H,
    }
end

local function SaveWindowLayout(frame)
    local state = EnsureGlobalOptionsState()
    local layout = CaptureWindowLayout(frame)
    if not (state and layout) then return end
    SetWindowMetrics(layout.w, layout.h)
    state.x = floor((layout.x or SNAP_SCREEN_MARGIN) + 0.5)
    state.yTop = floor((layout.yTop or DEFAULT_WINDOW_H) + 0.5)
    state.w = WINDOW_W
    state.h = WINDOW_H
end

local function ReadSavedWindowLayout()
    local state = EnsureGlobalOptionsState()
    local maxW, maxH = WindowMaxBounds()
    if type(state) ~= "table" then
        return { w = DEFAULT_WINDOW_W, h = DEFAULT_WINDOW_H }
    end
    local layout = {
        x = tonumber(state.x),
        yTop = tonumber(state.yTop),
        w = ClampNumber(state.w, MIN_WINDOW_W, maxW, DEFAULT_WINDOW_W),
        h = ClampNumber(state.h, MIN_WINDOW_H, maxH, DEFAULT_WINDOW_H),
    }
    if not layout.x or not layout.yTop then
        layout.x = nil
        layout.yTop = nil
    end
    return layout
end

local function ApplyWindowLayout(frame, layout, skipSave)
    if not (frame and layout and _G.UIParent) then return false end
    local maxW, maxH = WindowMaxBounds()
    local w = ClampNumber(layout.w, MIN_WINDOW_W, maxW, DEFAULT_WINDOW_W)
    local h = ClampNumber(layout.h, MIN_WINDOW_H, maxH, DEFAULT_WINDOW_H)
    SetWindowMetrics(w, h)
    frame:ClearAllPoints()
    frame:SetSize(WINDOW_W, WINDOW_H)
    if layout.x and layout.yTop then
        frame:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT", layout.x, layout.yTop)
    else
        frame:SetPoint("CENTER", _G.UIParent, "CENTER", -60, 10)
    end
    ApplyWindowResizeBounds(frame)
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    if not skipSave then SaveWindowLayout(frame) end
    return true
end

local function IsConfigSnapEnabled()
    local state = EnsureGlobalOptionsState()
    if type(state) ~= "table" then return true end
    return state.snapEnabled ~= false
end

local function GetAddonVersionText()
    local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")

    if not version or version == "" then
        return nil
    end

    return "v" .. tostring(version)
end

local function ApplyFooterTextStyle(fontString)
    if not fontString then return end

    local db = CDM.db or {}
    local defaults = CDM.defaults or {}
    local fontName = db.textFont or defaults.textFont or "Friz Quadrata TT"
    local fontOutline = nil
    local fontPath = (LSM and LSM:Fetch("font", fontName)) or CDM_C.FONT_PATH
    local fontSize = (CDM.Pixel and CDM.Pixel.FontSize(14)) or 14

    fontString:SetFontObject("GameFontHighlightSmall")
    local setOk = fontString:SetFont(fontPath, fontSize, fontOutline)
    if not setOk then
        fontString:SetFont(STANDARD_TEXT_FONT, fontSize, fontOutline)
    end
end

local function ApplyAllFooterTextStyles()
    local currentFont = CDM.db and CDM.db.textFont
    if currentFont == lastFooterFont then return end
    lastFooterFont = currentFont
    ApplyFooterTextStyle(versionText)
    ApplyFooterTextStyle(discordText)
    ApplyFooterTextStyle(twitchText)
end

local function PrintConfigCombatBlocked(actionLabel)
    print("|cffff0000" .. string.format(L["Cannot %s while in combat"], actionLabel or L["open CDM config"]) .. "|r")
end

local function HideConfigPopups()
    if not StaticPopup_Hide then
        return
    end

    StaticPopup_Hide("MidnightCooldownManager_COPY_URL")
    StaticPopup_Hide("MidnightCooldownManager_CONFIRM_RESET_PROFILE")
    StaticPopup_Hide("MidnightCooldownManager_CONFIRM_COPY_PROFILE")
    StaticPopup_Hide("MidnightCooldownManager_CONFIRM_DELETE_PROFILE")
    StaticPopup_Hide("MidnightCooldownManager_CONFIRM_DELETE_GROUP")
    StaticPopup_Hide("MidnightCooldownManager_CONFIRM_DELETE_CD_GROUP")
    StaticPopup_Hide("MidnightCooldownManager_CONFIRM_DELETE_BAR_GROUP")
end

local function AddSpecialFrameOnce(frameName)
    if type(frameName) ~= "string" or frameName == "" or type(UISpecialFrames) ~= "table" then return end
    for _, name in ipairs(UISpecialFrames) do
        if name == frameName then return end
    end
    tinsert(UISpecialFrames, frameName)
end

local function HideConfigWindowAndMinibar(frame)
    frame = frame or ConfigFrame or ns.ConfigFrame
    if minimizedBar and minimizedBar.Hide then minimizedBar:Hide() end
    if frame and frame.Hide then frame:Hide() end
end

local function RestoreConfigWindow(frame)
    frame = frame or ConfigFrame or ns.ConfigFrame
    if not frame then return false end
    local layout = frame._mcdmRestoreLayout
    frame._mcdmWindowState = "normal"
    frame._mcdmRestoreLayout = nil
    if layout then
        ApplyWindowLayout(frame, layout)
    else
        ApplyWindowLayout(frame, CaptureWindowLayout(frame) or ReadSavedWindowLayout())
    end
    if UI.RefreshWindowControls then UI.RefreshWindowControls(frame) end
    return true
end

local function MaximizeConfigWindow(frame)
    frame = frame or ConfigFrame or ns.ConfigFrame
    if not frame then return false end
    if frame._mcdmWindowState == "maximized" then
        return RestoreConfigWindow(frame)
    end

    frame._mcdmRestoreLayout = CaptureWindowLayout(frame)
    frame._mcdmWindowState = "maximized"

    local parent = _G.UIParent
    if not (parent and parent.GetWidth and parent.GetHeight) then return false end
    local screenW, screenH = parent:GetWidth() or 0, parent:GetHeight() or 0
    if screenW <= 0 or screenH <= 0 then return false end

    local scale = WindowVisualScale(frame)
    if scale <= 0 then scale = 1 end
    local maxW, maxH = WindowMaxBounds()
    local usableW = max(1, screenW - (SNAP_SCREEN_MARGIN * 2))
    local usableH = max(1, screenH - (SNAP_SCREEN_MARGIN * 2))
    local localW = ClampNumber(usableW / scale, MIN_WINDOW_W, maxW, DEFAULT_WINDOW_W)
    local localH = ClampNumber(usableH / scale, MIN_WINDOW_H, maxH, DEFAULT_WINDOW_H)
    local visualW = localW * scale
    local x = max(SNAP_SCREEN_MARGIN, floor((screenW - visualW) * 0.5 + 0.5))
    local yTop = screenH - SNAP_SCREEN_MARGIN
    ApplyWindowLayout(frame, { x = x, yTop = yTop, w = localW, h = localH })
    if UI.RefreshWindowControls then UI.RefreshWindowControls(frame) end
    return true
end

local function RestoreMinimizedConfigWindow(frame)
    frame = frame or ConfigFrame or ns.ConfigFrame
    if not frame then return false end
    if minimizedBar and minimizedBar.Hide then minimizedBar:Hide() end
    frame._mcdmMinimized = nil
    frame:Show()
    frame:Raise()
    if UI.RefreshWindowControls then UI.RefreshWindowControls(frame) end
    return true
end

local function MinimizeConfigWindow(frame)
    frame = frame or ConfigFrame or ns.ConfigFrame
    if not (frame and minimizedBar) then return false end
    frame._mcdmMinimized = true
    if minimizedBar.title then
        local title = frame.title and frame.title.GetText and frame.title:GetText()
        minimizedBar.title:SetText((title and title ~= "" and title) or "MCDM Menu")
    end
    minimizedBar:Show()
    frame:Hide()
    return true
end

local function GetConfigSnapLayout(frame)
    if not (frame and IsConfigSnapEnabled()) then return false end
    local parent = _G.UIParent
    if not (parent and parent.GetWidth and parent.GetHeight) then return false end
    local cursorX, cursorY = CursorPositionInUIParent()
    if not cursorX then return false end
    local screenW, screenH = parent:GetWidth() or 0, parent:GetHeight() or 0
    if screenW <= 0 or screenH <= 0 then return false end

    local frameLeft = (frame.GetLeft and frame:GetLeft()) or cursorX
    local frameRight = (frame.GetRight and frame:GetRight()) or cursorX
    local frameTop = (frame.GetTop and frame:GetTop()) or cursorY
    local frameBottom = (frame.GetBottom and frame:GetBottom()) or cursorY
    local left = cursorX <= SNAP_EDGE_PX or frameLeft <= SNAP_FRAME_EDGE_PX
    local right = cursorX >= (screenW - SNAP_EDGE_PX) or frameRight >= (screenW - SNAP_FRAME_EDGE_PX)
    if left and right then
        right = cursorX >= (screenW * 0.5)
        left = not right
    end
    local top = cursorY >= (screenH - SNAP_EDGE_PX) or frameTop >= (screenH - SNAP_FRAME_EDGE_PX)
    local bottom = cursorY <= SNAP_EDGE_PX or frameBottom <= SNAP_FRAME_EDGE_PX
    if not (left or right or top or bottom) then return false end
    if bottom and not (left or right) then return false end

    local scale = WindowVisualScale(frame)
    if scale <= 0 then scale = 1 end
    local maxW, maxH = WindowMaxBounds()
    local usableW = max(1, screenW - (SNAP_SCREEN_MARGIN * 2))
    local usableH = max(1, screenH - (SNAP_SCREEN_MARGIN * 2))
    local halfW = usableW * 0.5
    local halfH = usableH * 0.5
    local targetW = top and not (left or right) and usableW or halfW
    local targetH = ((left or right) and (top or bottom)) and halfH or usableH
    local localW = ClampNumber(targetW / scale, MIN_WINDOW_W, maxW, DEFAULT_WINDOW_W)
    local localH = ClampNumber(targetH / scale, MIN_WINDOW_H, maxH, DEFAULT_WINDOW_H)
    local visualW = localW * scale
    local visualH = localH * scale
    local x = right and (screenW - SNAP_SCREEN_MARGIN - visualW) or SNAP_SCREEN_MARGIN
    if x < SNAP_SCREEN_MARGIN then x = SNAP_SCREEN_MARGIN end
    local yTop = bottom and (SNAP_SCREEN_MARGIN + visualH) or (screenH - SNAP_SCREEN_MARGIN)
    if yTop > screenH - SNAP_SCREEN_MARGIN then yTop = screenH - SNAP_SCREEN_MARGIN end
    return {
        x = x,
        yTop = yTop,
        w = localW,
        h = localH,
        visualW = visualW,
        visualH = visualH,
        scale = scale,
    }
end

local function ApplyConfigSnap(frame)
    local layout = frame and frame._mcdmLastSnapLayout or nil
    if not layout then layout = GetConfigSnapLayout(frame) end
    if not layout then
        SaveWindowLayout(frame)
        return false
    end
    if frame._mcdmWindowState == "maximized" then
        frame._mcdmWindowState = "normal"
        frame._mcdmRestoreLayout = nil
    end
    ApplyWindowLayout(frame, layout)
    if UI.RefreshWindowControls then UI.RefreshWindowControls(frame) end
    return true
end

local function HideConfigUiForCombat()
    local frame = ConfigFrame or ns.ConfigFrame
    if (frame and frame.IsShown and frame:IsShown()) or (minimizedBar and minimizedBar.IsShown and minimizedBar:IsShown()) then
        if UI and UI.CloseAllDropdownMenus then
            UI.CloseAllDropdownMenus()
        end
        HideConfigWindowAndMinibar(frame)
    end
    HideConfigPopups()
end

local function RegisterCombatConfigAutoClose()
    if combatCloseRegistered then return end
    combatCloseRegistered = true

    CDM:RegisterCombatStateHandler(function(isInCombat)
        if isInCombat then
            HideConfigUiForCombat()
        end
    end)
end

RegisterCombatConfigAutoClose()

local function SetCategoryButtonState(button, isActive)
    if button and button.SetActive then
        button:SetActive(isActive)
    end
end

local function ScheduleActivePageSkin(page)
    -- First-open stability: pages create their own styled controls. A recursive
    -- post-pass over large editor pages can stall the WoW client on some builds.
end

local BuildCategoryPage
local BLIZZARD_PANEL_TAB = "buffgroups"

local function SelectCategory(id)
    if UI and UI.CloseAllDropdownMenus then
        UI.CloseAllDropdownMenus()
    end
    currentTab = id
    BuildCategoryPage(id)
    for categoryId, frame in pairs(categories) do frame:SetShown(categoryId == id) end
    for buttonId, btn in pairs(buttons) do
        SetCategoryButtonState(btn, buttonId == id)
    end

    ScheduleActivePageSkin(categories[id])

    local page = categories[id]
    if page and page.Refresh then
        page:Refresh()
    end
    if ConfigFrame and ConfigFrame.title and ns.ConfigTabs and ns.ConfigTabs[id] then
        ConfigFrame.title:SetText(ns.ConfigTabs[id].label or "Midnight Simple Cooldown")
    end

    local scrollFrameName = SCROLL_FRAME_NAMES[id]
    if scrollFrameName then
        local scrollFrame = _G[scrollFrameName]
        if scrollFrame then
            scrollFrame:SetVerticalScroll(0)
        end
    end

    if CDM.SetBuffGroupsTabActive then
        CDM:SetBuffGroupsTabActive(currentTab == BLIZZARD_PANEL_TAB)
    end
end

ns.ConfigSelectCategory = SelectCategory

local function CreateCategoryPage(id, name, Content)
    local page = CreateFrame("Frame", nil, Content)
    page:SetAllPoints()
    if UI.EnableClipping then UI.EnableClipping(page) end
    page:Hide()
    page.controls = {}
    page._mcdmTabId = id
    categories[id] = page
    return page
end

ns.ConfigCreatePage = CreateCategoryPage

BuildCategoryPage = function(id)
    local page = categories[id]
    if not page or page._mcdmBuilt then return page end
    local tabDef = ns.ConfigTabs and ns.ConfigTabs[id]
    if not (tabDef and tabDef.createFunc) then
        page._mcdmBuilt = true
        return page
    end

    page._mcdmBuilt = true
    local ok, err = pcall(tabDef.createFunc, page, tabDef.id)
    if not ok then
        page._mcdmBuildFailed = true
        CDM.PrintError("Options page failed to build (" .. tostring(id) .. "): " .. tostring(err))
    end
    return page
end

local function Txt(key, fallback)
    return L[key] or fallback or key
end

local categoryHeaders = {
    {
        id = "dashboard",
        label = "MSC",
        tabs = {
            { id = "dashboard", label = "Dashboard", terms = "dashboard overview status setup checklist quick actions smoke diagnostic" },
        },
    },
    {
        id = "cooldowns",
        label = "COOLDOWNS",
        tabs = {
            { id = "layout", label = Txt("Cooldown Groups", "Cooldown Groups"), terms = "cooldowns cooldown groups icons externals general layout" },
            { id = "sizes", label = L["Icon Sizes"], terms = "sizes icon width height" },
            { id = "positions", label = L["Positions"], terms = "position anchors offsets" },
        },
    },
    {
        id = "buffs",
        label = "BUFFS",
        tabs = {
            { id = "buffgroups", label = L["Buff Groups"], terms = "buff groups custom buffs aura spells" },
            { id = "bars", label = L["Bars"], terms = "bars buff bars groups timers" },
        },
    },
    {
        id = "style",
        label = "STYLE",
        tabs = {
            { id = "border", label = L["Borders & Look"], terms = "border look edge appearance" },
            { id = "text", label = L["Text"], terms = "font text cooldown charge count" },
            { id = "glow", label = L["Glow"], terms = "glow highlight border" },
            { id = "fading", label = L["Fading"], terms = "fade alpha transparency inactive" },
            { id = "assist", label = L["Assist"], terms = "assist rotation recommendation" },
        },
    },
    {
        id = "features",
        label = "FEATURES",
        tabs = {
            { id = "resources", label = "Class Resources", terms = "class resource power hp player bars combo points runes holy power chi essence icicles frost mage" },
            { id = "racials", label = L["Racials"], terms = "racial spell item" },
            { id = "defensives", label = L["Defensives"], terms = "defensive spell mitigation" },
            { id = "trinkets", label = L["Trinkets"], terms = "trinket item blacklist" },
        },
    },
    {
        id = "utility",
        label = "UTILITY",
        tabs = {
            { id = "profiles", label = L["Profiles"], terms = "profile copy reset delete spec" },
            { id = "importexport", label = L["Import/Export"], terms = "import export share wago string ayije acdm legacy" },
        },
    },
}

local function NormalizeSearch(text)
    text = tostring(text or ""):lower()
    return text:gsub("%s+", "")
end

local function RowMatches(row, filter)
    if filter == "" then return true end
    local haystack = row.searchText or ""
    return haystack:find(filter, 1, true) ~= nil
end

local function RefreshNavHeaderVisual(group)
    if not group then return end
    local open = group.open ~= false
    if group.arrow and group.arrow.SetRotation then
        group.arrow:SetRotation(open and 1.570796 or 0)
    end
    if group.arrow and group.arrow.SetVertexColor then
        local c = open and (COLORS.navArrowOpen or COLORS.accent2 or CDM_C.GOLD) or (COLORS.navArrowClosed or COLORS.accent or CDM_C.GOLD)
        group.arrow:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    end
end

local function ReflowNavigation()
    if not navSearchBox then return end
    local filter = NormalizeSearch(navSearchBox:GetText())
    local navParent = navScrollChild
    if not navParent then return end
    local y = -2

    for _, group in ipairs(navGroups) do
        local visibleRows = 0
        for _, row in ipairs(group.rows) do
            if RowMatches(row, filter) then
                visibleRows = visibleRows + 1
            end
        end

        local showGroup = visibleRows > 0
        group.frame:SetShown(showGroup)
        if showGroup then
            group.frame:ClearAllPoints()
            group.frame:SetPoint("TOPLEFT", navParent, "TOPLEFT", 10, y)
            y = y - 22
            RefreshNavHeaderVisual(group)
        end

        local showChildren = showGroup and (filter ~= "" or group.open ~= false)
        for _, row in ipairs(group.rows) do
            local showRow = showChildren and RowMatches(row, filter)
            row.button:SetShown(showRow)
            if showRow then
                row.button:ClearAllPoints()
                row.button:SetPoint("TOPLEFT", navParent, "TOPLEFT", 22, y)
                y = y - 24
            end
        end

        if showGroup then
            y = y - 4
        end
    end

    navParent:SetHeight(max(abs(y) + 8, 1))
    navParent:SetWidth(NAV_W)
    if filter ~= "" and navScrollFrame and navScrollFrame.SetVerticalScroll then
        navScrollFrame:SetVerticalScroll(0)
    end
end

local function RefreshHeaderStatus()
    if not statusText then return end
    local profile = (API.GetActiveProfileName and API:GetActiveProfileName()) or "Default"
    local editMode = CDM.isEditModeActive and "On" or "Off"
    local combatLocked = InCombatLockdown and InCombatLockdown()
    local editText = editMode == "On" and "|cff4ade80Edit: On|r" or "|cff5a6a88Edit: Off|r"
    local combatText = combatLocked and "|cffef4444In Combat|r" or "|cff22c55eOut of Combat|r"
    statusText:SetText("|cff4a90d9Profile:|r |cffccd8e8" .. tostring(profile) .. "|r  |cff3a4a66/|r  " .. editText .. "  |cff3a4a66/|r  " .. combatText)

    if editModeBtn then
        editModeBtn:SetText("Edit Mode: " .. editMode)
        if editModeBtn.SetActive then
            editModeBtn:SetActive(CDM.isEditModeActive)
        end
    end
    if versionText then
        versionText:SetText(GetAddonVersionText() or "")
    end
    if ns.RefreshDashboard then
        ns.RefreshDashboard()
    end
end

local function CreateCloseButton(parent)
    local btn = UI.CreateCloseButton and UI.CreateCloseButton(parent) or CreateFrame("Button", nil, parent)
    btn:SetSize(24, 24)
    btn:SetScript("OnClick", function()
        HideConfigWindowAndMinibar(ConfigFrame)
    end)
    return btn
end

local function OpenNativeCooldownSettings()
    if API.ToggleCooldownViewerSettingsPanel then
        API:ToggleCooldownViewerSettingsPanel()
    end
end

local function OpenEditModeSettingsOverlay()
    if not ns.CreateEditModeOverlay then return end

    local overlay = ns._HeaderEditModeOverlay or ns._DashboardEditModeOverlay
    if not overlay then
        overlay = ns.CreateEditModeOverlay()
        ns._HeaderEditModeOverlay = overlay
        ns._DashboardEditModeOverlay = overlay
    end
    overlay:Show()
end

local function SetHeaderButtonTooltip(btn, title, text)
    if not btn then return end
    btn:SetScript("OnEnter", function(self)
        self._mcdmHover = true
        if self.RefreshVisual then self:RefreshVisual() end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(title)
        if text then
            GameTooltip:AddLine(text, 0.75, 0.82, 0.92, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self._mcdmHover = nil
        if self.RefreshVisual then self:RefreshVisual() end
        GameTooltip:Hide()
    end)
end

local function AttachWindowControlTooltip(btn, title, text)
    if not btn or not btn.HookScript then return end
    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(title)
        if text then
            GameTooltip:AddLine(text, 0.75, 0.82, 0.92, true)
        end
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function CreateHeaderActionButtons(parent)
    local settingsBtn = UI.CreateActionButton(parent, L["Settings"], 92, 22, "danger")
    settingsBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -5)
    settingsBtn:SetScript("OnClick", OpenNativeCooldownSettings)
    SetHeaderButtonTooltip(settingsBtn, L["Settings"], L["Open Blizzard cooldown manager settings."])

    local editSettingsBtn = UI.CreateActionButton(parent, L["Edit Mode Settings"], 154, 22, "danger")
    editSettingsBtn:SetPoint("LEFT", settingsBtn, "RIGHT", 8, 0)
    editSettingsBtn:SetScript("OnClick", OpenEditModeSettingsOverlay)
    SetHeaderButtonTooltip(editSettingsBtn, L["Edit Mode Settings"], L["Check and apply recommended Blizzard Edit Mode settings."])

    return settingsBtn, editSettingsBtn
end

local function CreateResizeProxy(frame)
    if frame._mcdmResizeProxy then return frame._mcdmResizeProxy end
    local proxy = CreateFrame("Frame", nil, UIParent)
    proxy:SetFrameStrata("TOOLTIP")
    proxy:Hide()

    local fill = proxy:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(COLORS.bg.r, COLORS.bg.g, COLORS.bg.b, 0.18)
    proxy.fill = fill

    local accent = COLORS.accent or { r = 0.22, g = 0.78, b = 0.94, a = 1 }
    local function Edge(pointA, pointB, width, height)
        local tex = proxy:CreateTexture(nil, "BORDER")
        tex:SetColorTexture(accent.r, accent.g, accent.b, 0.72)
        tex:SetPoint(unpack(pointA))
        tex:SetPoint(unpack(pointB))
        if width then tex:SetWidth(width) end
        if height then tex:SetHeight(height) end
        return tex
    end
    Edge({ "TOPLEFT", proxy, "TOPLEFT", 0, 0 }, { "TOPRIGHT", proxy, "TOPRIGHT", 0, 0 }, nil, 2)
    Edge({ "BOTTOMLEFT", proxy, "BOTTOMLEFT", 0, 0 }, { "BOTTOMRIGHT", proxy, "BOTTOMRIGHT", 0, 0 }, nil, 2)
    Edge({ "TOPLEFT", proxy, "TOPLEFT", 0, 0 }, { "BOTTOMLEFT", proxy, "BOTTOMLEFT", 0, 0 }, 2, nil)
    Edge({ "TOPRIGHT", proxy, "TOPRIGHT", 0, 0 }, { "BOTTOMRIGHT", proxy, "BOTTOMRIGHT", 0, 0 }, 2, nil)

    local label = proxy:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    label:SetPoint("BOTTOMRIGHT", proxy, "TOPRIGHT", 0, 4)
    label:SetJustifyH("RIGHT")
    label:SetTextColor(accent.r, accent.g, accent.b, accent.a or 1)
    proxy.sizeLabel = label

    frame._mcdmResizeProxy = proxy
    return proxy
end

local function ShowWindowLayoutProxy(frame, layout)
    if not (frame and layout) then return nil end
    local scale = layout.scale or WindowVisualScale(frame)
    if scale <= 0 then scale = 1 end
    local proxy = CreateResizeProxy(frame)
    proxy:ClearAllPoints()
    proxy:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", layout.x or SNAP_SCREEN_MARGIN, layout.yTop or DEFAULT_WINDOW_H)
    proxy:SetSize(layout.visualW or ((layout.w or WINDOW_W) * scale), layout.visualH or ((layout.h or WINDOW_H) * scale))
    if proxy.sizeLabel then proxy.sizeLabel:SetText(string.format("%d x %d", layout.w or WINDOW_W, layout.h or WINDOW_H)) end
    proxy:Show()
    return proxy
end

local function HideWindowLayoutProxy(frame)
    local proxy = frame and frame._mcdmResizeProxy
    if proxy then proxy:Hide() end
    if frame then frame._mcdmSnapPreviewKey = nil end
end

local function CreateMinimizedBar(frame)
    if minimizedBar then return minimizedBar end
    local bar = UI.CreatePanel(UIParent, "MidnightCooldownManager_MinimizedWindow", COLORS.glassShell or COLORS.shell, COLORS.border)
    if UI.ApplySurface then UI.ApplySurface(bar, "shell") end
    bar:SetSize(MINIMIZED_WINDOW_W, MINIMIZED_WINDOW_H)
    bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 18, 18)
    bar:SetFrameStrata("HIGH")
    bar:EnableMouse(true)
    bar:SetMovable(true)
    if bar.SetClampedToScreen then bar:SetClampedToScreen(true) end
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self) self:StartMoving() end)
    bar:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    bar:Hide()

    local title = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("LEFT", bar, "LEFT", 12, 0)
    title:SetPoint("RIGHT", bar, "RIGHT", -62, 0)
    title:SetJustifyH("LEFT")
    title:SetText("MCDM Menu")
    UI.SetTextColor(title, COLORS.accent)
    bar.title = title

    local restore = UI.CreateWindowControlButton and UI.CreateWindowControlButton(bar, "maximize") or UI.CreateModernButton(bar, "", 24, 24)
    restore:SetPoint("RIGHT", bar, "RIGHT", -31, 0)
    restore:SetScript("OnClick", function() RestoreMinimizedConfigWindow(frame) end)
    AttachWindowControlTooltip(restore, "Restore", "Restore the minimized MCDM menu.")
    bar.restoreButton = restore

    local close = UI.CreateCloseButton and UI.CreateCloseButton(bar) or CreateCloseButton(bar)
    close:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    close:SetScript("OnClick", function()
        bar:Hide()
        if frame then frame._mcdmMinimized = nil end
    end)
    bar.closeButton = close

    minimizedBar = bar
    return bar
end

local function AttachWindowInteractions(frame)
    if not frame or frame._mcdmWindowInteractionsAttached then return end
    frame._mcdmWindowInteractionsAttached = true
    frame:SetMovable(true)
    if frame.SetResizable then frame:SetResizable(true) end
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    ApplyWindowResizeBounds(frame)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if self._mcdmWindowState == "maximized" then
            self._mcdmWindowState = "normal"
            self._mcdmRestoreLayout = nil
            if UI.RefreshWindowControls then UI.RefreshWindowControls(self) end
        end
        self._mcdmDraggingWindow = true
        self._mcdmLastSnapLayout = nil
        self._mcdmSnapPreviewKey = nil
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self._mcdmDraggingWindow = nil
        HideWindowLayoutProxy(self)
        if self.StopMovingOrSizing then self:StopMovingOrSizing() end
        ApplyConfigSnap(self)
        self._mcdmLastSnapLayout = nil
    end)
    frame:SetScript("OnSizeChanged", function(self)
        if self._mcdmLiveResizing then
            self._mcdmResizeMetricsDirty = true
            return
        end
        local width = self.GetWidth and self:GetWidth()
        local height = self.GetHeight and self:GetHeight()
        SetWindowMetrics(width, height)
        SaveWindowLayout(self)
    end)

    local function UpdateSnapPreview(self)
        if not self._mcdmDraggingWindow then return end
        local layout = GetConfigSnapLayout(self)
        if not layout then
            self._mcdmLastSnapLayout = nil
            HideWindowLayoutProxy(self)
            return
        end
        self._mcdmLastSnapLayout = layout
        local key = floor((layout.x or 0) + 0.5) .. ":"
            .. floor((layout.yTop or 0) + 0.5) .. ":"
            .. floor((layout.w or 0) + 0.5) .. ":"
            .. floor((layout.h or 0) + 0.5)
        if key == self._mcdmSnapPreviewKey then return end
        self._mcdmSnapPreviewKey = key
        ShowWindowLayoutProxy(self, layout)
    end
    frame._mcdmUpdateSnapPreview = UpdateSnapPreview

    local FinishResizeProxy
    local function UpdateResizeProxy()
        local state = frame._mcdmResizeState
        if not state then return end
        if not frame._mcdmFinishingResize and _G.IsMouseButtonDown and not _G.IsMouseButtonDown("LeftButton") then
            if FinishResizeProxy then FinishResizeProxy(true) end
            return
        end
        local cursorX, cursorY = CursorPositionInUIParent()
        if not cursorX then return end
        local scale = state.scale or 1
        if scale <= 0 then scale = 1 end
        local maxW, maxH = WindowMaxBounds()
        local w = ClampNumber(state.startW + ((cursorX - state.cursorX) / scale), MIN_WINDOW_W, maxW, DEFAULT_WINDOW_W)
        local h = ClampNumber(state.startH + ((state.cursorY - cursorY) / scale), MIN_WINDOW_H, maxH, DEFAULT_WINDOW_H)
        if state.w == w and state.h == h then return end
        state.w, state.h = w, h
        ShowWindowLayoutProxy(frame, { x = state.layout.x, yTop = state.layout.yTop, w = w, h = h, scale = scale })
    end

    local function BeginResizeProxy(button)
        if button ~= "LeftButton" then return false end
        local cursorX, cursorY = CursorPositionInUIParent()
        local layout = CaptureWindowLayout(frame)
        if not (cursorX and layout) then return false end
        frame._mcdmLiveResizing = true
        frame._mcdmResizeMetricsDirty = nil
        frame._mcdmWindowState = "normal"
        frame._mcdmRestoreLayout = nil
        if UI.RefreshWindowControls then UI.RefreshWindowControls(frame) end
        frame._mcdmResizeState = {
            cursorX = cursorX,
            cursorY = cursorY,
            startW = layout.w or WINDOW_W,
            startH = layout.h or WINDOW_H,
            layout = layout,
            scale = WindowVisualScale(frame),
        }
        local proxy = CreateResizeProxy(frame)
        proxy:SetScript("OnUpdate", UpdateResizeProxy)
        proxy:Show()
        UpdateResizeProxy()
        return true
    end

    FinishResizeProxy = function(apply)
        local state = frame._mcdmResizeState
        frame._mcdmFinishingResize = true
        if state then UpdateResizeProxy() end
        local proxy = frame._mcdmResizeProxy
        if proxy then
            proxy:SetScript("OnUpdate", nil)
            HideWindowLayoutProxy(frame)
        end
        if not state then
            frame._mcdmLiveResizing = nil
            frame._mcdmResizeMetricsDirty = nil
            frame._mcdmFinishingResize = nil
            return
        end
        local w = state.w or state.startW
        local h = state.h or state.startH
        local changed = math.abs((w or state.startW) - state.startW) >= 1
            or math.abs((h or state.startH) - state.startH) >= 1
        frame._mcdmResizeState = nil
        frame._mcdmResizeMetricsDirty = nil
        if apply and changed then
            ApplyWindowLayout(frame, { x = state.layout.x, yTop = state.layout.yTop, w = w, h = h })
        end
        frame._mcdmLiveResizing = nil
        frame._mcdmFinishingResize = nil
    end
    frame._mcdmFinishResizeProxy = FinishResizeProxy

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function(_, button)
        BeginResizeProxy(button)
    end)
    grip:SetScript("OnMouseUp", function()
        FinishResizeProxy(true)
    end)
    grip:SetScript("OnHide", function()
        FinishResizeProxy(false)
    end)
    frame.resizeGrip = grip
end

local function CreateGroupHeader(parent, group)
    local header = CreateFrame("Button", nil, parent)
    header:SetSize(160, 18)
    header.parent = parent
    header.arrow = header:CreateTexture(nil, "ARTWORK")
    header.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    header.arrow:SetSize(10, 10)
    header.arrow:SetPoint("LEFT", header, "LEFT", 0, 0)

    header.label = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header.label:SetPoint("LEFT", header.arrow, "RIGHT", 7, 0)
    header.label:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    header.label:SetJustifyH("LEFT")
    header.label:SetText(group.label)
    UI.SetTextColor(header.label, COLORS.navHeaderText or { r = 0.680, g = 0.780, b = 1.000, a = 0.96 })

    header:SetScript("OnClick", function()
        group.open = not (group.open ~= false)
        ReflowNavigation()
    end)
    header:SetScript("OnEnter", function()
        UI.SetTextColor(header.label, COLORS.navHeaderHover or { r = 0.780, g = 0.860, b = 1.000, a = 1 })
    end)
    header:SetScript("OnLeave", function()
        UI.SetTextColor(header.label, COLORS.navHeaderText or { r = 0.680, g = 0.780, b = 1.000, a = 0.96 })
    end)

    group.frame = header
    group.open = true
    RefreshNavHeaderVisual(group)
    return header
end

local function CreateNavigation(Sidebar)
    wipe(navRows)
    wipe(navGroups)
    buttons = {}
    navScrollFrame = nil
    navScrollChild = nil

    navSearchBox = UI.CreateModernEditBox(Sidebar, 180, 20)
    navSearchBox:SetPoint("TOPLEFT", Sidebar, "TOPLEFT", 10, -10)
    navSearchBox:SetPoint("TOPRIGHT", Sidebar, "TOPRIGHT", -10, -10)
    navSearchBox:SetHeight(20)
    navSearchBox:SetMaxLetters(48)
    UI.AttachPlaceholder(navSearchBox, "Search MSC...")
    navSearchBox:SetScript("OnTextChanged", ReflowNavigation)
    navSearchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    navScrollFrame = CreateFrame("ScrollFrame", "MidnightCDM_NavigationScrollFrame", Sidebar, "ScrollFrameTemplate")
    navScrollFrame:SetPoint("TOPLEFT", Sidebar, "TOPLEFT", 0, -36)
    navScrollFrame:SetPoint("BOTTOMRIGHT", Sidebar, "BOTTOMRIGHT", -1, 6)
    if UI.AttachCloseMenusOnScroll then UI.AttachCloseMenusOnScroll(navScrollFrame) end
    if UI.StyleScrollFrame then UI.StyleScrollFrame(navScrollFrame) end

    navScrollChild = CreateFrame("Frame", nil, navScrollFrame)
    navScrollChild:SetSize(NAV_W, 1)
    navScrollFrame:SetScrollChild(navScrollChild)

    for _, groupDef in ipairs(categoryHeaders) do
        local group = {
            id = groupDef.id,
            label = groupDef.label,
            parent = navScrollChild,
            rows = {},
            open = true,
        }
        CreateGroupHeader(navScrollChild, group)
        navGroups[#navGroups + 1] = group

        for _, tabRef in ipairs(groupDef.tabs) do
            local tabDef = ns.ConfigTabs and ns.ConfigTabs[tabRef.id]
            if tabDef then
                local label = tabRef.label or tabDef.label
                local btn = UI.CreateNavButton(navScrollChild, label, 142, 20)
                btn:SetScript("OnClick", function() SelectCategory(tabDef.id) end)
                btn.Text = btn._mcdmLabel
                buttons[tabDef.id] = btn

                local row = {
                    button = btn,
                    id = tabDef.id,
                    searchText = NormalizeSearch((label or "") .. " " .. (tabDef.label or "") .. " " .. (tabRef.terms or "")),
                }
                navRows[#navRows + 1] = row
                group.rows[#group.rows + 1] = row
            end
        end
    end

    ReflowNavigation()
end

local function CreateConfigFrame()
    if ConfigFrame then return end

    ConfigFrame = CreateFrame("Frame", "MidnightCooldownManagerConfigFrame", UIParent, "BackdropTemplate")
    local savedLayout = ReadSavedWindowLayout()
    SetWindowMetrics(savedLayout.w, savedLayout.h)
    ConfigFrame:SetFrameStrata("HIGH")
    ConfigFrame:EnableMouse(true)
    if UI.ApplySurface then
        UI.ApplySurface(ConfigFrame, "shell")
    else
        UI.ApplyBackdrop(ConfigFrame, COLORS.shell, COLORS.border)
    end
    ApplyWindowLayout(ConfigFrame, savedLayout, true)
    ConfigFrame:Hide()
    AddSpecialFrameOnce("MidnightCooldownManagerConfigFrame")
    ConfigFrame:HookScript("OnHide", function(self)
        if self._mcdmFinishResizeProxy then self._mcdmFinishResizeProxy(false) end
        self._mcdmDraggingWindow = nil
        HideWindowLayoutProxy(self)
        if UI and UI.CloseAllDropdownMenus then
            UI.CloseAllDropdownMenus()
        end
        HideConfigPopups()
        if CDM.SetBuffGroupsTabActive then
            CDM:SetBuffGroupsTabActive(false)
        end
    end)
    ConfigFrame:SetMovable(true)
    ConfigFrame:RegisterForDrag("LeftButton")
    ConfigFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    ConfigFrame:SetScript("OnDragStop", function(self)
        if self.StopMovingOrSizing then self:StopMovingOrSizing() end
        SaveWindowLayout(self)
    end)

    local settingsButton, editSettingsButton = CreateHeaderActionButtons(ConfigFrame)
    ConfigFrame.settingsButton = settingsButton
    ConfigFrame.editSettingsButton = editSettingsButton

    local title = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    title:SetPoint("TOPLEFT", ConfigFrame, "TOPLEFT", 286, -6)
    title:SetPoint("TOPRIGHT", ConfigFrame, "TOPRIGHT", -112, -6)
    title:SetJustifyH("CENTER")
    title:SetAlpha(0.50)
    title:SetText("Midnight Simple Cooldown")
    UI.SetTextColor(title, COLORS.accent)
    ConfigFrame.title = title

    local subtitle = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subtitle:SetPoint("TOPRIGHT", ConfigFrame, "TOPRIGHT", -112, -14)
    subtitle:SetJustifyH("RIGHT")
    subtitle:SetText(L["Cooldown Manager"])
    UI.SetTextColor(subtitle, COLORS.muted)
    ConfigFrame.subtitle = subtitle

    local closeButton = CreateCloseButton(ConfigFrame)
    closeButton:SetPoint("TOPRIGHT", ConfigFrame, "TOPRIGHT", -4, -4)
    ConfigFrame.closeButton = closeButton

    local maximizeButton = UI.CreateWindowControlButton and UI.CreateWindowControlButton(ConfigFrame, "maximize") or UI.CreateActionButton(ConfigFrame, "", 24, 24)
    maximizeButton:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", -2, 0)
    maximizeButton:SetScript("OnClick", function()
        MaximizeConfigWindow(ConfigFrame)
    end)
    AttachWindowControlTooltip(maximizeButton, "Maximize", "Maximize or restore the MCDM menu window.")
    ConfigFrame.maximizeButton = maximizeButton

    local minimizeButton = UI.CreateWindowControlButton and UI.CreateWindowControlButton(ConfigFrame, "minimize") or UI.CreateActionButton(ConfigFrame, "", 24, 24)
    minimizeButton:SetPoint("TOPRIGHT", maximizeButton, "TOPLEFT", -2, 0)
    minimizeButton:SetScript("OnClick", function()
        if not minimizedBar then CreateMinimizedBar(ConfigFrame) end
        MinimizeConfigWindow(ConfigFrame)
    end)
    AttachWindowControlTooltip(minimizeButton, "Minimize", "Collapse the MCDM menu to a small taskbar-style bar.")
    ConfigFrame.minimizeButton = minimizeButton

    local ShellContent = CreateFrame("Frame", nil, ConfigFrame)
    ShellContent:SetPoint("TOPLEFT", ConfigFrame, "TOPLEFT", 8, -30)
    ShellContent:SetPoint("BOTTOMRIGHT", ConfigFrame, "BOTTOMRIGHT", -8, 8)
    if UI.EnableClipping then UI.EnableClipping(ShellContent) end
    ConfigFrame.content = ShellContent

    local Sidebar = UI.CreatePanel(ShellContent, nil, COLORS.glassRail or COLORS.rail, COLORS.borderSoft)
    if UI.ApplySurface then UI.ApplySurface(Sidebar, "rail") end
    if UI.EnableClipping then UI.EnableClipping(Sidebar) end
    Sidebar:SetPoint("TOPLEFT", ShellContent, "TOPLEFT", 0, 0)
    Sidebar:SetPoint("BOTTOMLEFT", ShellContent, "BOTTOMLEFT", 0, 0)
    Sidebar:SetWidth(NAV_W)

    local Host = UI.CreatePanel(ShellContent, nil, COLORS.glassHost or COLORS.host, COLORS.borderSoft)
    if UI.ApplySurface then UI.ApplySurface(Host, "host") end
    if UI.EnableClipping then UI.EnableClipping(Host) end
    Host:SetPoint("TOPLEFT", Sidebar, "TOPRIGHT", 8, 0)
    Host:SetPoint("BOTTOMRIGHT", ShellContent, "BOTTOMRIGHT", 0, 0)
    ConfigFrame.host = Host

    local statusBar = UI.CreatePanel(Host, nil, COLORS.glassStatus or { r = 0.032, g = 0.040, b = 0.070, a = 0.56 }, COLORS.borderSoft)
    if UI.ApplySurface then UI.ApplySurface(statusBar, "status") end
    statusBar:SetPoint("TOPLEFT", Host, "TOPLEFT", 0, 0)
    statusBar:SetPoint("TOPRIGHT", Host, "TOPRIGHT", 0, 0)
    statusBar:SetHeight(22)

    local statusTopLine = statusBar:CreateTexture(nil, "ARTWORK", nil, 6)
    statusTopLine:SetTexture(CDM_C.TEX_WHITE8X8 or "Interface\\Buttons\\WHITE8X8")
    statusTopLine:SetHeight(1)
    statusTopLine:SetPoint("TOPLEFT", statusBar, "TOPLEFT", 0, 0)
    statusTopLine:SetPoint("TOPRIGHT", statusBar, "TOPRIGHT", 0, 0)
    statusTopLine:SetColorTexture(COLORS.accent.r, COLORS.accent.g, COLORS.accent.b, 0.25)

    statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("LEFT", statusBar, "LEFT", 10, 0)
    statusText:SetPoint("RIGHT", statusBar, "RIGHT", -92, 0)
    statusText:SetJustifyH("LEFT")
    UI.SetTextColor(statusText, COLORS.muted)

    versionText = statusBar:CreateFontString(nil, "OVERLAY")
    versionText:SetPoint("RIGHT", statusBar, "RIGHT", -10, 0)
    ApplyFooterTextStyle(versionText)
    versionText:SetText(GetAddonVersionText() or "")
    UI.SetTextFaint(versionText)
    versionText:SetAlpha(0.55)

    local ContentHost = CreateFrame("Frame", nil, Host)
    ContentHost:SetPoint("TOPLEFT", statusBar, "BOTTOMLEFT", 0, 0)
    ContentHost:SetPoint("BOTTOMRIGHT", Host, "BOTTOMRIGHT", 0, 0)
    if UI.EnableClipping then UI.EnableClipping(ContentHost) end

    local Content = CreateFrame("Frame", nil, ContentHost)
    Content:SetPoint("TOPLEFT", ContentHost, "TOPLEFT", 0, 0)
    Content:SetPoint("BOTTOMRIGHT", ContentHost, "BOTTOMRIGHT", 0, 0)
    if UI.EnableClipping then UI.EnableClipping(Content) end

    ns.ConfigContent = Content
    ns.ConfigFrame = ConfigFrame
    ns.ConfigSidebar = Sidebar

    local sortedTabs = {}
    for id, tabDef in pairs(ns.ConfigTabs or {}) do
        table.insert(sortedTabs, tabDef)
    end
    table.sort(sortedTabs, function(a, b)
        if a.navOrder == b.navOrder then
            return tostring(a.id) < tostring(b.id)
        end
        return a.navOrder < b.navOrder
    end)

    for _, tabDef in ipairs(sortedTabs) do
        CreateCategoryPage(tabDef.id, tabDef.label, Content)
    end

    CreateNavigation(Sidebar)
    CreateMinimizedBar(ConfigFrame)
    AttachWindowInteractions(ConfigFrame)

    local initialTab = (ns.ConfigTabs and ns.ConfigTabs.layout) and "layout" or (sortedTabs[1] and sortedTabs[1].id)
    if initialTab then
        SelectCategory(initialTab)
    end

    ConfigFrame:HookScript("OnShow", function()
        if minimizedBar and minimizedBar.Hide then minimizedBar:Hide() end
        if ConfigFrame then ConfigFrame._mcdmMinimized = nil end
        RefreshHeaderStatus()
        ScheduleActivePageSkin()
    end)

    if not footerRefreshRegistered then
        API:RegisterRefreshCallback("configFooterTextStyle", function()
            ApplyAllFooterTextStyles()
            RefreshHeaderStatus()
        end, 95, { "STYLE", "PROFILE" })
        footerRefreshRegistered = true
    end

    if not treeSkinRefreshRegistered then
        API:RegisterRefreshCallback("configTreeSkin", function()
            if not (ConfigFrame and ConfigFrame:IsShown()) then return end
            ScheduleActivePageSkin()
        end, 100)
        treeSkinRefreshRegistered = true
    end
end

local function ClearPartialConfigFrame()
    if minimizedBar then
        minimizedBar:Hide()
        minimizedBar:SetParent(nil)
        minimizedBar = nil
    end
    if ConfigFrame then
        ConfigFrame:Hide()
        ConfigFrame:SetParent(nil)
        ConfigFrame = nil
    end
    categories = {}
    buttons = {}
    currentTab = nil
    versionText = nil
    statusText = nil
    editModeBtn = nil
    navRows = {}
    navGroups = {}
    navSearchBox = nil
    navScrollFrame = nil
    navScrollChild = nil
    treeSkinPending = false
    ns.ConfigFrame = nil
    ns.ConfigContent = nil
    ns.ConfigSidebar = nil
end

function API:ShowConfig()
    if InCombatLockdown() then
        PrintConfigCombatBlocked(L["open CDM config"])
        return
    end

    if not ConfigFrame then
        local ok, err = pcall(CreateConfigFrame)
        if not ok then
            ClearPartialConfigFrame()
            CDM.PrintError("Options UI failed to build: " .. tostring(err))
            return
        end
    end
    if minimizedBar and minimizedBar.Hide then minimizedBar:Hide() end
    ConfigFrame._mcdmMinimized = nil
    ConfigFrame:Show()
    ConfigFrame:Raise()
end

function API:RebuildConfigFrame(targetTab)
    if InCombatLockdown() then
        PrintConfigCombatBlocked(L["rebuild CDM config"])
        return
    end

    if ConfigFrame then
        API:UnregisterRefreshCallback("configFooterTextStyle")
        API:UnregisterRefreshCallback("configTreeSkin")
        footerRefreshRegistered = false
        treeSkinRefreshRegistered = false
        if ns.CancelImportStatusTimer then
            ns.CancelImportStatusTimer()
        end

        HideConfigWindowAndMinibar(ConfigFrame)
        if minimizedBar then
            minimizedBar:SetParent(nil)
            minimizedBar = nil
        end
        ConfigFrame:SetParent(nil)
        ConfigFrame = nil
        categories = {}
        buttons = {}
        currentTab = nil
        versionText = nil
        statusText = nil
        editModeBtn = nil
        discordText = nil
        twitchText = nil
        navRows = {}
        navGroups = {}
        navSearchBox = nil
        navScrollFrame = nil
        navScrollChild = nil
        treeSkinPending = false
        ns.ConfigFrame = nil
        ns.ConfigContent = nil
        ns.ConfigSidebar = nil
    end
    local ok, err = pcall(CreateConfigFrame)
    if not ok then
        ClearPartialConfigFrame()
        CDM.PrintError("Options UI failed to rebuild: " .. tostring(err))
        return
    end
    ConfigFrame:Show()

    local tabToSelect = targetTab or currentTab or "dashboard"
    if not (ns.ConfigTabs and ns.ConfigTabs[tabToSelect]) then
        tabToSelect = "layout"
    end
    if not (ns.ConfigTabs and ns.ConfigTabs[tabToSelect]) then
        tabToSelect = "profiles"
    end
    if ns.ConfigTabs and ns.ConfigTabs[tabToSelect] then
        SelectCategory(tabToSelect)
    end
end
