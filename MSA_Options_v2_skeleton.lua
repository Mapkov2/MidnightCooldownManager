-- ########################################################
-- MSA_Options.lua  v2.0  (MSUF/PeelDamage Midnight Theme)
-- NavRail + PageHost architecture with superellipse widgets
--
-- Architecture:
--   [Left Sidebar]  [NavRail]  [PageHost]  
--    Aura list       8 tabs     Page content
--    Search bar      
--    New/Import
--
-- Pages: Trigger | Look | Text | Glow | Sound | Alpha | Load | Pos
-- ########################################################

local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local tinsert, tsort = table.insert, table.sort
local pcall, select = pcall, select
local wipe = wipe or table.wipe
local W = MSWA_W  -- Widget library
local T = W.Theme

-----------------------------------------------------------
-- NAV DEFINITION (8 vertical tabs)
-----------------------------------------------------------
local NAV_PAGES = {
    { key = "trigger", label = "Trigger",  tip = "Aura mode, Spell ID, Anchor" },
    { key = "look",    label = "Look",     tip = "Display type, Icon/Bar settings" },
    { key = "text",    label = "Text",     tip = "Timer font, Stack counter" },
    { key = "glow",    label = "Glow",     tip = "LibCustomGlow effects" },
    { key = "sound",   label = "Sound",    tip = "Sound on start/ready" },
    { key = "alpha",   label = "Alpha",    tip = "Visibility per state" },
    { key = "load",    label = "Load",     tip = "Load conditions" },
    { key = "pos",     label = "Position", tip = "X, Y, Width, Height" },
}

-----------------------------------------------------------
-- Page state
-----------------------------------------------------------
local pages = {}          -- { key = { build=fn, frame=nil } }
local navButtons = {}     -- { key = btn }
local currentPageKey = nil
local pageHost = nil

-----------------------------------------------------------
-- Shared helpers (used by all pages)
-----------------------------------------------------------
local function GetSel()
    local key = MSWA.selectedSpellID; if not key then return nil end
    local db = MSWA_GetDB()
    return select(1, MSWA_GetSpellSettings(db, key)) or nil
end

local function EnsureSel()
    local key = MSWA.selectedSpellID; if not key then return nil end
    return select(1, MSWA_GetOrCreateSpellSettings(MSWA_GetDB(), key))
end

local function GetSelKey() return MSWA.selectedSpellID end

-----------------------------------------------------------
-- Context menu (right-click) — UNCHANGED from v1.8
-----------------------------------------------------------
-- [PRESERVED VERBATIM — ~140 lines]
-- Copy lines 15-137 from original MSA_Options.lua here
-- MSWA_ShowListContextMenu(row) ...

-----------------------------------------------------------
-- Options panel state — UNCHANGED
-----------------------------------------------------------
MSWA.optionsFrame = nil

function MSWA_RefreshOptionsList()
    local f = MSWA.optionsFrame; if not f then return end
    if f.UpdateAuraList then f:UpdateAuraList() end
    MSWA_UpdateDetailPanel()
end

-----------------------------------------------------------
-- Sorted tracked IDs — UNCHANGED
-- Copy lines 160-216 from original
-----------------------------------------------------------
-- local tempIDList = {}
-- local function MSWA_BuildSortedTrackedIDs() ... end

-----------------------------------------------------------
-- Build list entries — UNCHANGED
-- Copy lines 222-321 from original
-----------------------------------------------------------
-- local function MSWA_BuildListEntries() ... end

-----------------------------------------------------------
-- PAGE SWITCHING (PeelDamage MenuCore pattern)
-----------------------------------------------------------
local function SwitchPage(key)
    if not pages[key] then return end
    W.CloseAllDropdowns()

    if currentPageKey and pages[currentPageKey] and pages[currentPageKey].frame then
        pages[currentPageKey].frame:Hide()
    end

    for _, btn in pairs(navButtons) do
        if btn.SetActive then btn:SetActive(false) end
    end

    -- Lazy build
    if not pages[key].frame then
        if pages[key].build then
            pages[key].frame = pages[key].build(pageHost)
            if pages[key].frame then pages[key].frame:SetAllPoints(pageHost) end
        end
    end

    if pages[key].frame then
        pages[key].frame:Show()
        if pages[key].frame.Refresh then pcall(pages[key].frame.Refresh, pages[key].frame) end
    end

    if navButtons[key] then navButtons[key]:SetActive(true) end
    currentPageKey = key
end

-----------------------------------------------------------
-- DETAIL PANEL UPDATE (replaces old 400-line function)
-----------------------------------------------------------
MSWA_UpdateDetailPanel = function()
    local f = MSWA.optionsFrame; if not f then return end
    local key = MSWA.selectedSpellID
    local gid = MSWA.selectedGroupID

    -- Group selected: show group panel
    if gid and not key then
        -- Show group panel, hide page host
        if f.groupPanel then f.groupPanel:Show(); if f.groupPanel.Sync then f.groupPanel:Sync() end end
        if pageHost then pageHost:Hide() end
        if f.navRail then f.navRail:Hide() end
        return
    end

    -- Nothing selected: show empty state
    if not key then
        if f.groupPanel then f.groupPanel:Hide() end
        if pageHost then pageHost:Hide() end
        if f.navRail then f.navRail:Hide() end
        if f.emptyPanel then f.emptyPanel:Show() end
        return
    end

    -- Aura selected: show nav + current page
    if f.groupPanel then f.groupPanel:Hide() end
    if f.emptyPanel then f.emptyPanel:Hide() end
    if f.navRail then f.navRail:Show() end
    if pageHost then pageHost:Show() end

    -- Update title
    local name = MSWA_GetDisplayNameForKey(key)
    if f.rightTitle then f.rightTitle:SetText(name or "Selected Aura") end

    -- Refresh current page
    if currentPageKey and pages[currentPageKey] and pages[currentPageKey].frame then
        if pages[currentPageKey].frame.Refresh then
            pcall(pages[currentPageKey].frame.Refresh, pages[currentPageKey].frame)
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- PAGE BUILDERS
-- Each returns a frame with a :Refresh() method
-- ═══════════════════════════════════════════════════════════

-----------------------------------------------------------
-- PAGE: Trigger (Aura Mode + Spell ID + Anchor)
-----------------------------------------------------------
local function BuildTriggerPage(host)
    local f = W.ScrollPage(host)
    local c = f._content

    local title = W.Title(c, "Trigger", 12, -10)
    local sub = W.MutedLabel(c, "Aura mode, spell/item binding, anchor frame.", "TOPLEFT", c, "TOPLEFT", 12, -34)

    -- ── Aura Mode Cards (2x3 grid) ──
    local modeHeader = W.SectionHeader(c, "Aura Mode", sub, -16)

    local MODES = {
        { key = nil,              label = "Cooldown",    desc = "Standard CD tracker" },
        { key = "AUTOBUFF",       label = "Auto Buff",   desc = "Show while buff active" },
        { key = "BUFF_THEN_CD",   label = "Buff > CD",   desc = "Buff timer, then CD" },
        { key = "REMINDER_BUFF",  label = "Reminder",    desc = "Alert when missing" },
        { key = "CHARGES",        label = "Charges",     desc = "User-defined charges" },
        { key = "BUFF_AURA",      label = "Buff Aura",   desc = "Pure buff watcher" },
    }
    local modeCards = {}
    local cardW = 155
    for i, m in ipairs(MODES) do
        local card = W.ModeCard(c, m.label, m.desc, cardW, 40, function()
            local key = GetSelKey(); if not key then return end
            local s = EnsureSel(); if not s then return end
            s.auraMode = m.key
            -- Reset buff state
            if MSWA._autoBuff then MSWA._autoBuff[key] = nil end
            if m.key == "BUFF_AURA" and MSWA_RegisterBuffWatch then
                MSWA_RegisterBuffWatch(tostring(key))
            elseif MSWA_UnregisterBuffWatch then
                MSWA_UnregisterBuffWatch(tostring(key))
            end
            MSWA_UpdateDetailPanel(); MSWA_RequestUpdateSpells()
        end)
        local col = ((i - 1) % 2)
        local row = math.floor((i - 1) / 2)
        card:SetPoint("TOPLEFT", modeHeader, "BOTTOMLEFT", col * (cardW + 6), -10 - row * 46)
        modeCards[i] = card
    end

    -- ── Spell/Item ID (rekey) ──
    local idHeader = W.SectionHeader(c, "Spell / Item ID", modeCards[5], -16)

    local rekeyLabel = W.Label(c, "ID:", "TOPLEFT", idHeader, "BOTTOMLEFT", 0, -10)
    local rekeyEdit = W.EditBox(c, 80, 22, true)
    rekeyEdit:SetPoint("LEFT", rekeyLabel, "RIGHT", 8, 0)

    local rekeyBtn = W.Button(c, "Change", 70, 22, function()
        local key = GetSelKey(); if not key then return end
        local newID = tonumber(rekeyEdit:GetText()); if not newID or newID <= 0 then return end
        if MSWA_RekeyAura then MSWA_RekeyAura(key, newID) end
        MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList()
    end)
    rekeyBtn:SetPoint("LEFT", rekeyEdit, "RIGHT", 6, 0)

    local rekeyHint = W.MutedLabel(c, "Change spell/item ID. All settings preserved.", "TOPLEFT", rekeyLabel, "BOTTOMLEFT", 0, -4)

    -- ── Drop Zone ──
    -- [Port drop zone from original lines 2707-2731]

    -- ── Anchor ──
    local anchorHeader = W.SectionHeader(c, "Anchor", rekeyHint, -16)

    local anchorLabel = W.Label(c, "Frame:", "TOPLEFT", anchorHeader, "BOTTOMLEFT", 0, -10)
    local anchorEdit = W.EditBox(c, 200, 22)
    anchorEdit:SetPoint("LEFT", anchorLabel, "RIGHT", 8, 0)
    anchorEdit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local key = GetSelKey(); if not key then return end
        local s = EnsureSel(); if not s then return end
        local v = self:GetText():gsub("^%s+",""):gsub("%s+$","")
        s.anchorFrame = (v ~= "" and v) or nil
        MSWA_RequestUpdateSpells()
    end)

    local presetCD = W.Button(c, "CD Manager", 100, 22, function()
        anchorEdit:SetText("MidnightCDManager")
        anchorEdit:GetScript("OnEnterPressed")(anchorEdit)
    end)
    presetCD:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -8)

    local presetMSUF = W.Button(c, "MSUF Player", 100, 22, function()
        anchorEdit:SetText("MidnightPlayerFrame")
        anchorEdit:GetScript("OnEnterPressed")(anchorEdit)
    end)
    presetMSUF:SetPoint("LEFT", presetCD, "RIGHT", 6, 0)

    local presetDefault = W.Button(c, "Default", 80, 22, function()
        anchorEdit:SetText("")
        local key = GetSelKey(); if not key then return end
        local s = EnsureSel(); if s then s.anchorFrame = nil; s.x = 0; s.y = 0 end
        MSWA_RequestUpdateSpells()
    end)
    presetDefault:SetPoint("LEFT", presetMSUF, "RIGHT", 6, 0)

    -- ── Mode-specific sub-settings ──
    -- (Buff duration, delay, haste scaling, reminder text, charges, etc.)
    -- These show/hide based on current aura mode in Refresh()
    -- [Port from original lines 2743-3070]

    -- Set content height
    c:SetHeight(700)

    -- ── Refresh ──
    function f:Refresh()
        local key = GetSelKey(); if not key then return end
        local db = MSWA_GetDB()
        local s = GetSel() or {}

        -- Sync mode cards
        local curMode = s.auraMode
        for i, m in ipairs(MODES) do
            modeCards[i]:SetSelected((curMode or nil) == m.key)
        end

        -- Sync rekey
        local currentID
        if MSWA_IsItemKey(key) then currentID = MSWA_KeyToItemID(key)
        elseif MSWA_IsSpellInstanceKey(key) then currentID = MSWA_KeyToSpellID(key)
        elseif type(key) == "number" then currentID = key end
        rekeyEdit:SetText(currentID and tostring(currentID) or "")

        -- Sync anchor
        local gid2 = MSWA_GetAuraGroup and MSWA_GetAuraGroup(key) or nil
        local a
        if gid2 then
            local g2 = (db.groups or {})[gid2]
            a = (g2 and g2.anchorFrame) or ""
        else a = s.anchorFrame or "" end
        anchorEdit:SetText(a)

        -- Sync mode-specific controls visibility
        -- [Show/hide buff duration, reminder text, charges etc. based on curMode]
    end

    return f
end

-----------------------------------------------------------
-- PAGE: Look (Display Type + Visual Options)
-----------------------------------------------------------
local function BuildLookPage(host)
    local f = W.ScrollPage(host)
    local c = f._content

    W.Title(c, "Appearance", 12, -10)
    W.MutedLabel(c, "Display type, icon/bar settings, visual options.", "TOPLEFT", c, "TOPLEFT", 12, -34)

    -- Display Type (Icon / Bar) mode cards
    local dtHeader = W.SectionHeader(c, "Display Type", nil, -54)

    -- [Icon settings: Custom Icon, Grayscale on CD, Gray at 0, Swipe, Decimal]
    -- [Bar settings: Name, Width, Height, Color, Direction, Show Name/Timer/Spark/Icon]
    -- Port from original lines 3096-3653

    c:SetHeight(800)

    function f:Refresh()
        local s = GetSel() or {}
        -- Sync display type, icon/bar settings
    end
    return f
end

-----------------------------------------------------------
-- PAGE: Text (Timer Font + Stack Counter)
-----------------------------------------------------------
local function BuildTextPage(host)
    local f = W.ScrollPage(host)
    local c = f._content

    W.Title(c, "Text & Stacks", 12, -10)
    W.MutedLabel(c, "Timer text formatting and stack counter settings.", "TOPLEFT", c, "TOPLEFT", 12, -34)

    -- [Timer: Font dropdown, Size +/-, Position dropdown, Color swatch]
    -- [2nd color conditional]
    -- [Stacks: Mode button, Font, Size, Position, Color, Offset X/Y, Hide on CD]
    -- Port from original display panel lines 3451-3661

    c:SetHeight(600)

    function f:Refresh()
        local s = GetSel() or {}
        -- Sync all text/stack controls
    end
    return f
end

-----------------------------------------------------------
-- PAGE: Glow (LibCustomGlow)
-----------------------------------------------------------
local function BuildGlowPage(host)
    local f = W.ScrollPage(host)
    local c = f._content

    local glowAvail = MSWA_IsGlowAvailable and MSWA_IsGlowAvailable() or false
    W.Title(c, glowAvail and "Glow Settings" or "Glow (LibCustomGlow not found)", 12, -10)

    -- [Enable checkbox, Type dropdown, Color swatch, Condition dropdown]
    -- [Fine-tuning: Lines, Speed, Thickness, Duration]
    -- Port from original lines 2310-2657

    c:SetHeight(400)

    function f:Refresh()
        local s = GetSel() or {}
        -- Sync glow controls
    end
    return f
end

-----------------------------------------------------------
-- PAGE: Sound
-----------------------------------------------------------
local function BuildSoundPage(host)
    local f = W.ScrollPage(host)
    local c = f._content

    W.Title(c, "Sound Effects", 12, -10)
    W.MutedLabel(c, "Play sounds when cooldowns start or become ready.", "TOPLEFT", c, "TOPLEFT", 12, -34)

    local h1 = W.SectionHeader(c, "Events", nil, -54)

    local function SoundChoices()
        local choices = {{ text = "-- None --", value = "NONE" }}
        if MSWA_GetSoundChoices then
            for _, entry in ipairs(MSWA_GetSoundChoices()) do
                tinsert(choices, { text = entry.label, value = entry.key })
            end
        end
        return choices
    end

    local ddStart = W.Dropdown(c, "On Cooldown Start", 220, SoundChoices,
        function() local s = GetSel(); return s and s.soundOnStart or "NONE" end,
        function(v) local s = EnsureSel(); if s then s.soundOnStart = v end end)
    ddStart:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -10)

    -- Preview button
    local prevStart = W.Button(c, ">", 28, 22, function()
        local s = GetSel(); if s and s.soundOnStart and s.soundOnStart ~= "NONE" and MSWA_PlaySoundByKey then
            MSWA_PlaySoundByKey(s.soundOnStart, s.soundChannel or "Master")
        end
    end)
    prevStart:SetPoint("LEFT", ddStart._btn, "RIGHT", 6, 0)

    local ddReady = W.Dropdown(c, "On Ready", 220, SoundChoices,
        function() local s = GetSel(); return s and s.soundOnReady or "NONE" end,
        function(v) local s = EnsureSel(); if s then s.soundOnReady = v end end)
    ddReady:SetPoint("TOPLEFT", ddStart, "BOTTOMLEFT", 0, -8)

    local prevReady = W.Button(c, ">", 28, 22, function()
        local s = GetSel(); if s and s.soundOnReady and s.soundOnReady ~= "NONE" and MSWA_PlaySoundByKey then
            MSWA_PlaySoundByKey(s.soundOnReady, s.soundChannel or "Master")
        end
    end)
    prevReady:SetPoint("LEFT", ddReady._btn, "RIGHT", 6, 0)

    local ddChannel = W.Dropdown(c, "Audio Channel", 160,
        function()
            local ch = {{ text = "Master", value = "Master" }, { text = "SFX", value = "SFX" },
                { text = "Music", value = "Music" }, { text = "Ambience", value = "Ambience" },
                { text = "Dialog", value = "Dialog" }}
            return ch
        end,
        function() local s = GetSel(); return s and s.soundChannel or "Master" end,
        function(v) local s = EnsureSel(); if s then s.soundChannel = v end end)
    ddChannel:SetPoint("TOPLEFT", ddReady, "BOTTOMLEFT", 0, -8)

    c:SetHeight(300)

    function f:Refresh()
        ddStart:Refresh(); ddReady:Refresh(); ddChannel:Refresh()
    end
    return f
end

-----------------------------------------------------------
-- PAGE: Alpha (4 visibility sliders)
-----------------------------------------------------------
local function BuildAlphaPage(host)
    local f = W.ScrollPage(host)
    local c = f._content

    W.Title(c, "Alpha / Visibility", 12, -10)
    W.MutedLabel(c, "Control icon opacity per state.", "TOPLEFT", c, "TOPLEFT", 12, -34)

    local h1 = W.SectionHeader(c, "State Alpha", nil, -54)

    local slCD = W.Slider(c, "On Cooldown", 0, 100, 1,
        function() local s = GetSel(); return math.floor(((s and tonumber(s.cdAlpha)) or 1.0) * 100 + 0.5) end,
        function(v) local s = EnsureSel(); if s then s.cdAlpha = v / 100; MSWA_RequestUpdateSpells() end end)
    slCD:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -12)

    local slOOC = W.Slider(c, "Out of Combat", 0, 100, 1,
        function() local s = GetSel(); return math.floor(((s and tonumber(s.oocAlpha)) or 1.0) * 100 + 0.5) end,
        function(v) local s = EnsureSel(); if s then s.oocAlpha = v / 100; MSWA_RequestUpdateSpells() end end)
    slOOC:SetPoint("TOPLEFT", slCD, "BOTTOMLEFT", 0, -6)

    local slCombat = W.Slider(c, "In Combat", 0, 100, 1,
        function() local s = GetSel(); return math.floor(((s and tonumber(s.combatAlpha)) or 1.0) * 100 + 0.5) end,
        function(v) local s = EnsureSel(); if s then s.combatAlpha = v / 100; MSWA_RequestUpdateSpells() end end)
    slCombat:SetPoint("TOPLEFT", slOOC, "BOTTOMLEFT", 0, -6)

    local slReady = W.Slider(c, "Ready", 0, 100, 1,
        function() local s = GetSel(); return math.floor(((s and tonumber(s.readyAlpha)) or 1.0) * 100 + 0.5) end,
        function(v) local s = EnsureSel(); if s then s.readyAlpha = v / 100; MSWA_RequestUpdateSpells() end end)
    slReady:SetPoint("TOPLEFT", slCombat, "BOTTOMLEFT", 0, -6)

    c:SetHeight(340)

    function f:Refresh()
        slCD:Refresh(); slOOC:Refresh(); slCombat:Refresh(); slReady:Refresh()
    end
    return f
end

-----------------------------------------------------------
-- PAGE: Load (Load Conditions)
-----------------------------------------------------------
local function BuildLoadPage(host)
    local f = W.ScrollPage(host)
    local c = f._content

    W.Title(c, "Load Conditions", 12, -10)
    W.MutedLabel(c, "Control when this aura is active.", "TOPLEFT", c, "TOPLEFT", 12, -34)

    -- [Never checkbox, Combat button, Encounter button, Character edit, Class dropdown, Spec dropdown]
    -- Port from original lines 1886-2147

    c:SetHeight(400)
    function f:Refresh() end
    return f
end

-----------------------------------------------------------
-- PAGE: Position (X/Y/W/H)
-----------------------------------------------------------
local function BuildPositionPage(host)
    local f = W.ScrollPage(host)
    local c = f._content

    W.Title(c, "Position & Size", 12, -10)
    W.MutedLabel(c, "Fine-tune aura placement and dimensions.", "TOPLEFT", c, "TOPLEFT", 12, -34)

    local h1 = W.SectionHeader(c, "Coordinates", nil, -54)

    local function MakePosEdit(lbl, anchor, yOff, getter, setter)
        local l = W.Label(c, lbl, "TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
        local eb = W.EditBox(c, 70, 22)
        eb:SetPoint("LEFT", l, "RIGHT", 8, 0)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus()
            local v = tonumber(self:GetText()); if v and setter then setter(v) end; MSWA_RequestUpdateSpells()
        end)
        eb:SetScript("OnEditFocusLost", function(self)
            local v = tonumber(self:GetText()); if v and setter then setter(v) end; MSWA_RequestUpdateSpells()
        end)
        return l, eb
    end

    local lX, ebX = MakePosEdit("X:", h1, -10,
        function() local s = GetSel(); return s and s.x or 0 end,
        function(v) local s = EnsureSel(); if s then s.x = v end end)
    local lY, ebY = MakePosEdit("Y:", lX, -8,
        function() local s = GetSel(); return s and s.y or 0 end,
        function(v) local s = EnsureSel(); if s then s.y = v end end)
    local lW, ebW = MakePosEdit("Width:", lY, -8,
        function() local s = GetSel(); return s and s.width or MSWA.ICON_SIZE end,
        function(v) local s = EnsureSel(); if s then s.width = v end end)
    local lH, ebH = MakePosEdit("Height:", lW, -8,
        function() local s = GetSel(); return s and s.height or MSWA.ICON_SIZE end,
        function(v) local s = EnsureSel(); if s then s.height = v end end)

    local btnReset = W.Button(c, "Reset Position", 120, 24, function()
        local s = EnsureSel(); if s then s.x = 0; s.y = 0; MSWA_RequestUpdateSpells(); f:Refresh() end
    end)
    btnReset:SetPoint("TOPLEFT", lH, "BOTTOMLEFT", 0, -14)

    local btnDefault = W.Button(c, "Default Size", 120, 24, function()
        local s = EnsureSel(); if s then s.width = nil; s.height = nil; MSWA_RequestUpdateSpells(); f:Refresh() end
    end)
    btnDefault:SetPoint("LEFT", btnReset, "RIGHT", 8, 0)

    c:SetHeight(320)

    function f:Refresh()
        local s = GetSel() or {}
        ebX:SetText(tostring(s.x or 0))
        ebY:SetText(tostring(s.y or 0))
        ebW:SetText(tostring(s.width or MSWA.ICON_SIZE))
        ebH:SetText(tostring(s.height or MSWA.ICON_SIZE))
    end
    return f
end

-- ═══════════════════════════════════════════════════════════
-- REGISTER ALL PAGES
-- ═══════════════════════════════════════════════════════════

pages = {
    trigger = { build = BuildTriggerPage, frame = nil },
    look    = { build = BuildLookPage,    frame = nil },
    text    = { build = BuildTextPage,    frame = nil },
    glow    = { build = BuildGlowPage,    frame = nil },
    sound   = { build = BuildSoundPage,   frame = nil },
    alpha   = { build = BuildAlphaPage,   frame = nil },
    load    = { build = BuildLoadPage,    frame = nil },
    pos     = { build = BuildPositionPage,frame = nil },
}

-- ═══════════════════════════════════════════════════════════
-- CREATE MAIN OPTIONS FRAME
-- ═══════════════════════════════════════════════════════════

local NAV_WIDTH = 100
local NAV_BTN_H = 24
local NAV_BTN_GAP = 3

local function MSWA_CreateOptionsFrame()
    if MSWA.optionsFrame then return MSWA.optionsFrame end

    -- ── Main frame (MSUF dark theme) ──
    local f = CreateFrame("Frame", "MidnightSimpleAurasOptions", UIParent, "BackdropTemplate")
    f:SetSize(920, 560); f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
    f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    W.ApplyBackdrop(f, 0.97)

    -- Resizable
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(760, 440, 1200, 800)
    elseif f.SetMinResize then f:SetMinResize(760, 440); f:SetMaxResize(1200, 800) end

    -- Resize grip
    local grip = CreateFrame("Frame", nil, f)
    grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -4, 4); grip:EnableMouse(true)
    grip:SetFrameLevel(f:GetFrameLevel() + 10)
    local gt = grip:CreateTexture(nil, "OVERLAY"); gt:SetAllPoints()
    gt:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT"); gt:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); gt:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up") end)
    grip:SetScript("OnEnter", function() gt:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight") end)
    grip:SetScript("OnLeave", function() gt:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up") end)

    -- ESC close
    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "MidnightSimpleAurasOptions") end

    -- Title + Version
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10); title:SetText("Midnight Simple Auras"); W.SkinTitle(title)
    local tocVer = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("MidnightSimpleAuras", "Version") or "?"
    local ver = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ver:SetPoint("LEFT", title, "RIGHT", 8, -1); ver:SetText("v" .. tocVer); W.SkinMuted(ver)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ── Content area ──
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 8, -34); content:SetPoint("BOTTOMRIGHT", -8, 40)

    -- ── LEFT: Aura list sidebar ──
    local sidebar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(280)
    W.ApplyBackdrop(sidebar, 0.22)
    f.listPanel = sidebar

    -- Top buttons (New / Import / Templates)
    local btnNew = W.Button(sidebar, "New", 70, 22); btnNew:SetPoint("TOPLEFT", 6, -6)
    local btnImport = W.Button(sidebar, "Import", 70, 22); btnImport:SetPoint("LEFT", btnNew, "RIGHT", 4, 0)
    local btnTemplates = W.Button(sidebar, "Templates", 80, 22); btnTemplates:SetPoint("LEFT", btnImport, "RIGHT", 4, 0)
    f.btnNew = btnNew; f.btnImport = btnImport

    -- Search box
    local searchBox = W.EditBox(sidebar, 268, 20)
    searchBox:SetPoint("TOPLEFT", 6, -32)
    searchBox:SetMaxLetters(40)
    -- TODO: hook OnTextChanged for filter

    -- Aura list scroll area
    -- [Port FauxScrollFrame + row creation from original lines 1174-1740]
    -- This is the most complex part — drag-drop, multi-select, inline rename
    -- For now, use existing pattern with MSUF theming

    -- ── RIGHT: NavRail + PageHost ──
    local navRail = CreateFrame("Frame", nil, content, "BackdropTemplate")
    navRail:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 6, 0)
    navRail:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 6, 0)
    navRail:SetWidth(NAV_WIDTH)
    W.ApplyBackdrop(navRail, 0.22)
    f.navRail = navRail

    -- Nav buttons
    local yPos = -6
    for _, nav in ipairs(NAV_PAGES) do
        local btn = W.NavButton(navRail, nav.label, NAV_WIDTH - 10, NAV_BTN_H, false, function()
            SwitchPage(nav.key)
        end)
        btn:SetPoint("TOPLEFT", navRail, "TOPLEFT", 5, yPos)
        navButtons[nav.key] = btn
        yPos = yPos - NAV_BTN_H - NAV_BTN_GAP
        if nav.tip then W.AddTooltip(btn, nav.label, nav.tip) end
    end

    -- Page host
    pageHost = CreateFrame("Frame", nil, content)
    pageHost:SetPoint("TOPLEFT", navRail, "TOPRIGHT", 6, 0)
    pageHost:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

    -- Empty state
    f.emptyPanel = CreateFrame("Frame", nil, content)
    f.emptyPanel:SetPoint("TOPLEFT", navRail, "TOPRIGHT", 6, 0)
    f.emptyPanel:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    W.ApplyBackdrop(f.emptyPanel, 0.25)
    local emptyText = f.emptyPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyText:SetPoint("CENTER", 0, 0); emptyText:SetText("Select an aura from the list to edit."); W.SkinMuted(emptyText)

    -- Group panel (shown when group selected)
    -- [Port from original lines 2149-2307]
    f.groupPanel = CreateFrame("Frame", nil, content)
    f.groupPanel:SetPoint("TOPLEFT", navRail, "TOPRIGHT", 6, 0)
    f.groupPanel:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    f.groupPanel:Hide()

    -- ── Bottom bar ──
    local bottomBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    bottomBar:SetPoint("BOTTOMLEFT", 8, 8); bottomBar:SetPoint("BOTTOMRIGHT", -8, 8)
    bottomBar:SetHeight(28)
    W.ApplyBackdrop(bottomBar, 0.30)

    local btnPreview = W.Button(bottomBar, "Preview", 70, 22, function()
        MSWA.previewMode = not MSWA.previewMode
        MSWA_RequestUpdateSpells()
    end)
    btnPreview:SetPoint("LEFT", 6, 0)

    local btnExport = W.Button(bottomBar, "Export", 70, 22, function()
        if MSWA.selectedGroupID then MSWA_ExportGroup(MSWA.selectedGroupID); return end
        local key = MSWA.selectedSpellID; if not key then return end
        MSWA_ExportAura(key)
    end)
    btnExport:SetPoint("LEFT", btnPreview, "RIGHT", 4, 0)

    local btnIDInfo = W.Button(bottomBar, "ID Info", 65, 22)
    btnIDInfo:SetPoint("LEFT", btnExport, "RIGHT", 4, 0)

    local btnGroup = W.Button(bottomBar, "Group", 65, 22, function()
        local gid = MSWA_CreateGroup(nil)
        MSWA.selectedSpellID = nil; MSWA.selectedGroupID = gid
        MSWA_RequestUpdateSpells(); MSWA_RefreshOptionsList()
    end)
    btnGroup:SetPoint("LEFT", btnIDInfo, "RIGHT", 4, 0)

    f.rightTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.rightTitle:SetPoint("TOPLEFT", pageHost, "TOPLEFT", 12, -10)
    f.rightTitle:SetText("Select an Aura"); W.SkinTitle(f.rightTitle)

    -- ── OnShow / OnHide ──
    f:SetScript("OnShow", function()
        MSWA.selectedSpellID = nil; MSWA.selectedGroupID = nil; MSWA.previewMode = false
        currentPageKey = "trigger"; SwitchPage("trigger")
        if f.UpdateAuraList then f:UpdateAuraList() end
    end)
    f:SetScript("OnHide", function()
        MSWA.selectedSpellID = nil; MSWA.selectedGroupID = nil
        if MSWA.previewMode then MSWA.previewMode = false; MSWA_RequestUpdateSpells() end
    end)

    f:Hide()
    MSWA.optionsFrame = f
    return f
end

-----------------------------------------------------------
-- Toggle / Slash commands — UNCHANGED
-----------------------------------------------------------
function MSWA_ToggleOptions()
    local f = MSWA.optionsFrame or MSWA_CreateOptionsFrame()
    if f:IsShown() then f:Hide() else MSWA_RefreshOptionsList(); f:Show() end
end

-- [Copy slash commands from original lines 4832-4910 verbatim]

-----------------------------------------------------------
-- Open helpers
-----------------------------------------------------------
function MSWA_OpenOptions() MSWA_ToggleOptions() end
function MidnightSimpleAuras_OpenOptions() MSWA_ToggleOptions() end
