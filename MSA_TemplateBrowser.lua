-- ########################################################
-- MSA_TemplateBrowser.lua  (v2 – professional UI)
--
-- 3-panel layout:
--   Left   = category list (with category icon)
--   Middle = template list (for selected category)
--   Right  = detail panel: description + spell list with
--            checkboxes for individual selection
--
-- Features:
--   • Fixed 20×20 icons (never stretched)
--   • Per-spell checkbox selection before install
--   • "Your Spellbook" / "Your Bags" dynamic categories
--   • Select All / Deselect All buttons
--   • Install / Reinstall / Uninstall
--   • 100 % secret-safe, zero pcall
-- ########################################################

local ADDON_NAME, ns = ...

local pairs, ipairs, tinsert, wipe, format = pairs, ipairs, table.insert, wipe or table.wipe, string.format
local CreateFrame = CreateFrame

-----------------------------------------------------------
-- State
-----------------------------------------------------------

local browser        -- main frame
local catButtons  = {}
local tplButtons  = {}
local spellRows   = {}
local selectedCat
local selectedTpl
local spellChecks = {}   -- [index] = true/false
local currentSpells = {} -- current spell list shown

-----------------------------------------------------------
-- Constants
-----------------------------------------------------------

local FRAME_W, FRAME_H = 720, 480
local CAT_W       = 170
local TPL_W       = 180
local DETAIL_W    = FRAME_W - CAT_W - TPL_W - 30
local ROW_H       = 22
local ICON_SIZE   = 20  -- fixed square, never stretched
local MAX_CAT_ROWS  = 18
local MAX_TPL_ROWS  = 18
local MAX_SPELL_ROWS = 20

-----------------------------------------------------------
-- Helpers
-----------------------------------------------------------

local function StripColor(text)
    if not text then return "" end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function SetIcon(tex, iconID, size)
    size = size or ICON_SIZE
    tex:SetSize(size, size)
    if iconID then
        tex:SetTexture(iconID)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- trim bleed
        tex:Show()
    else
        tex:Hide()
    end
end

local function Highlight(btn, on)
    if on then
        btn:SetBackdropColor(0.2, 0.4, 0.8, 0.6)
    else
        btn:SetBackdropColor(0, 0, 0, 0)
    end
end

local backdrop = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local panelBD = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-----------------------------------------------------------
-- Create main frame
-----------------------------------------------------------

local function CreateBrowser()
    if browser then return browser end

    browser = CreateFrame("Frame", "MSA_TemplateBrowserFrame", UIParent, "BackdropTemplate")
    browser:SetSize(FRAME_W, FRAME_H)
    browser:SetPoint("CENTER")
    browser:SetBackdrop(backdrop)
    browser:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
    browser:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)
    browser:SetFrameStrata("DIALOG")
    browser:SetMovable(true)
    browser:EnableMouse(true)
    browser:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "MSA_TemplateBrowserFrame")

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, browser)
    titleBar:SetHeight(24)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() browser:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() browser:StopMovingOrSizing() end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", 12, 0)
    titleText:SetText("MSA Template Browser")
    titleText:SetTextColor(1, 0.82, 0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, browser, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() browser:Hide() end)

    -- ESC to close
    browser:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide(); self:SetPropagateKeyboardInput(false)
        else self:SetPropagateKeyboardInput(true) end
    end)

    -----------------------------------------------------------
    -- Left panel: Categories
    -----------------------------------------------------------
    local catPanel = CreateFrame("Frame", nil, browser, "BackdropTemplate")
    catPanel:SetPoint("TOPLEFT", 8, -30)
    catPanel:SetPoint("BOTTOMLEFT", 8, 8)
    catPanel:SetWidth(CAT_W)
    catPanel:SetBackdrop(panelBD)
    catPanel:SetBackdropColor(0.08, 0.08, 0.12, 0.9)
    catPanel:SetBackdropBorderColor(0.3, 0.3, 0.4, 0.8)

    local catTitle = catPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    catTitle:SetPoint("TOPLEFT", 8, -6)
    catTitle:SetText("Categories")
    catTitle:SetTextColor(0.7, 0.7, 0.7)

    browser.catPanel = catPanel
    browser.catScroll = CreateFrame("ScrollFrame", "MSA_TB_CatScroll", catPanel, "UIPanelScrollFrameTemplate")
    browser.catScroll:SetPoint("TOPLEFT", 4, -20)
    browser.catScroll:SetPoint("BOTTOMRIGHT", -22, 4)

    local catContent = CreateFrame("Frame", nil, browser.catScroll)
    catContent:SetSize(CAT_W - 26, MAX_CAT_ROWS * ROW_H)
    browser.catScroll:SetScrollChild(catContent)
    browser.catContent = catContent

    -----------------------------------------------------------
    -- Middle panel: Templates
    -----------------------------------------------------------
    local tplPanel = CreateFrame("Frame", nil, browser, "BackdropTemplate")
    tplPanel:SetPoint("TOPLEFT", catPanel, "TOPRIGHT", 4, 0)
    tplPanel:SetPoint("BOTTOMLEFT", catPanel, "BOTTOMRIGHT", 4, 0)
    tplPanel:SetWidth(TPL_W)
    tplPanel:SetBackdrop(panelBD)
    tplPanel:SetBackdropColor(0.08, 0.08, 0.12, 0.9)
    tplPanel:SetBackdropBorderColor(0.3, 0.3, 0.4, 0.8)

    local tplTitle = tplPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tplTitle:SetPoint("TOPLEFT", 8, -6)
    tplTitle:SetText("Templates")
    tplTitle:SetTextColor(0.7, 0.7, 0.7)

    browser.tplPanel = tplPanel
    browser.tplScroll = CreateFrame("ScrollFrame", "MSA_TB_TplScroll", tplPanel, "UIPanelScrollFrameTemplate")
    browser.tplScroll:SetPoint("TOPLEFT", 4, -20)
    browser.tplScroll:SetPoint("BOTTOMRIGHT", -22, 4)

    local tplContent = CreateFrame("Frame", nil, browser.tplScroll)
    tplContent:SetSize(TPL_W - 26, MAX_TPL_ROWS * ROW_H)
    browser.tplScroll:SetScrollChild(tplContent)
    browser.tplContent = tplContent

    -----------------------------------------------------------
    -- Right panel: Detail / spell list with checkboxes
    -----------------------------------------------------------
    local detPanel = CreateFrame("Frame", nil, browser, "BackdropTemplate")
    detPanel:SetPoint("TOPLEFT", tplPanel, "TOPRIGHT", 4, 0)
    detPanel:SetPoint("BOTTOMRIGHT", -8, 50)
    detPanel:SetBackdrop(panelBD)
    detPanel:SetBackdropColor(0.08, 0.08, 0.12, 0.9)
    detPanel:SetBackdropBorderColor(0.3, 0.3, 0.4, 0.8)

    browser.detPanel = detPanel

    -- Template name
    browser.detName = detPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    browser.detName:SetPoint("TOPLEFT", 10, -10)
    browser.detName:SetWidth(DETAIL_W - 20)
    browser.detName:SetJustifyH("LEFT")
    browser.detName:SetTextColor(1, 0.82, 0)

    -- Description
    browser.detDesc = detPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    browser.detDesc:SetPoint("TOPLEFT", browser.detName, "BOTTOMLEFT", 0, -4)
    browser.detDesc:SetWidth(DETAIL_W - 20)
    browser.detDesc:SetJustifyH("LEFT")
    browser.detDesc:SetTextColor(0.7, 0.7, 0.7)

    -- Select All / Deselect All
    browser.selAllBtn = CreateFrame("Button", nil, detPanel, "UIPanelButtonTemplate")
    browser.selAllBtn:SetSize(80, 18)
    browser.selAllBtn:SetPoint("TOPLEFT", browser.detDesc, "BOTTOMLEFT", 0, -6)
    browser.selAllBtn:SetText("Select All")
    browser.selAllBtn:GetFontString():SetTextColor(1, 1, 1)
    browser.selAllBtn:SetScript("OnClick", function()
        for i = 1, #currentSpells do spellChecks[i] = true end
        MSWA_TB_RefreshSpellList()
    end)

    browser.deselBtn = CreateFrame("Button", nil, detPanel, "UIPanelButtonTemplate")
    browser.deselBtn:SetSize(90, 18)
    browser.deselBtn:SetPoint("LEFT", browser.selAllBtn, "RIGHT", 4, 0)
    browser.deselBtn:SetText("Deselect All")
    browser.deselBtn:GetFontString():SetTextColor(1, 1, 1)
    browser.deselBtn:SetScript("OnClick", function()
        wipe(spellChecks)
        MSWA_TB_RefreshSpellList()
    end)

    -- Spell list scroll
    browser.spellScroll = CreateFrame("ScrollFrame", "MSA_TB_SpellScroll", detPanel, "UIPanelScrollFrameTemplate")
    browser.spellScroll:SetPoint("TOPLEFT", browser.selAllBtn, "BOTTOMLEFT", 0, -4)
    browser.spellScroll:SetPoint("BOTTOMRIGHT", detPanel, "BOTTOMRIGHT", -22, 4)

    local spellContent = CreateFrame("Frame", nil, browser.spellScroll)
    spellContent:SetSize(DETAIL_W - 30, MAX_SPELL_ROWS * (ROW_H + 2))
    browser.spellScroll:SetScrollChild(spellContent)
    browser.spellContent = spellContent

    -----------------------------------------------------------
    -- Bottom bar: Install button
    -----------------------------------------------------------
    local bottomBar = CreateFrame("Frame", nil, browser)
    bottomBar:SetPoint("BOTTOMLEFT", 8, 8)
    bottomBar:SetPoint("BOTTOMRIGHT", -8, 8)
    bottomBar:SetHeight(38)

    browser.installBtn = CreateFrame("Button", nil, bottomBar, "UIPanelButtonTemplate")
    browser.installBtn:SetSize(160, 28)
    browser.installBtn:SetPoint("CENTER", 0, 0)
    browser.installBtn:SetText("Install Selected")
    browser.installBtn:GetFontString():SetTextColor(1, 1, 1)
    browser.installBtn:SetScript("OnClick", function() MSWA_TB_DoInstall() end)

    -- Status text
    browser.statusText = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    browser.statusText:SetPoint("LEFT", 10, 0)
    browser.statusText:SetTextColor(0.5, 1, 0.5)

    browser:Hide()
    return browser
end

-----------------------------------------------------------
-- Populate categories
-----------------------------------------------------------

local function RefreshCategories()
    local cats = MSWA_GetTemplateCategories()
    local parent = browser.catContent

    -- Hide all existing
    for _, btn in ipairs(catButtons) do btn:Hide() end

    for i, cat in ipairs(cats) do
        local btn = catButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(CAT_W - 30, ROW_H)
            btn:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
            btn:SetBackdropColor(0, 0, 0, 0)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetPoint("LEFT", 4, 0)
            btn.icon:SetSize(ICON_SIZE, ICON_SIZE)
            btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 6, 0)
            btn.text:SetJustifyH("LEFT")

            btn:SetScript("OnEnter", function(self)
                if self._catKey ~= selectedCat then
                    self:SetBackdropColor(0.15, 0.3, 0.6, 0.3)
                end
            end)
            btn:SetScript("OnLeave", function(self)
                if self._catKey ~= selectedCat then
                    self:SetBackdropColor(0, 0, 0, 0)
                end
            end)

            catButtons[i] = btn
        end

        btn:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW_H + 1))
        btn._catKey = cat.key
        btn.text:SetText(cat.name)

        -- Category icon: use first spell of first template in this category
        local icon = nil
        if cat.dynamic then
            if cat.key == "SPELLBOOK" then
                icon = 133743 -- Spellbook icon
            elseif cat.key == "COOLDOWNS" then
                icon = 136243 -- Spell_Nature_TimeStop (cooldown clock icon)
            else
                icon = 133633 -- Backpack icon
            end
        else
            local tpls = MSWA_GetTemplatesForCategory(cat.key)
            if tpls and tpls[1] and tpls[1].spells and tpls[1].spells[1] then
                icon = MSWA_GetSpellIconSafe(tpls[1].spells[1].sid)
            end
        end
        SetIcon(btn.icon, icon)

        btn:SetScript("OnClick", function(self)
            selectedCat = self._catKey
            selectedTpl = nil
            RefreshCategories()   -- update highlight
            MSWA_TB_RefreshTemplates()
            MSWA_TB_ClearDetail()
        end)

        Highlight(btn, cat.key == selectedCat)
        btn:Show()
    end

    -- Resize scroll child
    parent:SetHeight(#cats * (ROW_H + 1))
end

-----------------------------------------------------------
-- Populate templates for selected category
-----------------------------------------------------------

function MSWA_TB_RefreshTemplates()
    local parent = browser.tplContent
    for _, btn in ipairs(tplButtons) do btn:Hide() end

    if not selectedCat then return end

    local catInfo = MSWA_CATEGORY_LOOKUP[selectedCat]
    local isDynamic = catInfo and catInfo.dynamic

    local items = {}
    if isDynamic then
        -- Dynamic: show individual spells/items as "templates"
        local dynSpells = MSWA_GetDynamicSpells(selectedCat)
        for i, sp in ipairs(dynSpells) do
            tinsert(items, {
                id     = format("dyn_%s_%d", selectedCat, i),
                name   = sp.name or "Unknown",
                desc   = sp.isItem and format("Item: %d", sp.itemID or 0) or format("Spell: %d", sp.sid or 0),
                spells = { sp },
                _isDynamic = true,
            })
        end
        -- Show "Scan" message if in combat
        if #items == 0 and InCombatLockdown() then
            browser.statusText:SetText("Leave combat to scan " .. (selectedCat == "SPELLBOOK" and "spellbook" or selectedCat == "COOLDOWNS" and "cooldowns" or "bags"))
        else
            browser.statusText:SetText("")
        end
    else
        items = MSWA_GetTemplatesForCategory(selectedCat)
        browser.statusText:SetText("")
    end

    for i, tpl in ipairs(items) do
        local btn = tplButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(TPL_W - 30, ROW_H)
            btn:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
            btn:SetBackdropColor(0, 0, 0, 0)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetPoint("LEFT", 4, 0)
            btn.icon:SetSize(ICON_SIZE, ICON_SIZE)
            btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 6, 0)
            btn.text:SetPoint("RIGHT", -4, 0)
            btn.text:SetJustifyH("LEFT")
            btn.text:SetWordWrap(false)

            btn:SetScript("OnEnter", function(self)
                if self._tplID ~= selectedTpl then self:SetBackdropColor(0.15, 0.3, 0.6, 0.3) end
            end)
            btn:SetScript("OnLeave", function(self)
                if self._tplID ~= selectedTpl then self:SetBackdropColor(0, 0, 0, 0) end
            end)

            tplButtons[i] = btn
        end

        btn:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW_H + 1))
        btn._tplID = tpl.id
        btn._tplData = tpl
        btn.text:SetText(tpl.name)

        -- Icon
        local icon
        if tpl.spells and tpl.spells[1] then
            local sp = tpl.spells[1]
            if sp.isItem and sp.itemID then
                icon = sp.icon or MSWA_GetItemIconSafe(sp.itemID)
            elseif sp.sid then
                icon = sp.icon or MSWA_GetSpellIconSafe(sp.sid)
            end
        end
        SetIcon(btn.icon, icon)

        btn:SetScript("OnClick", function(self)
            selectedTpl = self._tplID
            MSWA_TB_RefreshTemplates()
            MSWA_TB_ShowDetail(self._tplData)
        end)

        Highlight(btn, tpl.id == selectedTpl)
        btn:Show()
    end

    parent:SetHeight(#items * (ROW_H + 1))
end

-----------------------------------------------------------
-- Detail panel: show spells with checkboxes
-----------------------------------------------------------

function MSWA_TB_ClearDetail()
    browser.detName:SetText("")
    browser.detDesc:SetText("")
    browser.selAllBtn:Hide()
    browser.deselBtn:Hide()
    browser.installBtn:Hide()
    wipe(spellChecks)
    wipe(currentSpells)
    for _, row in ipairs(spellRows) do row:Hide() end
end

function MSWA_TB_ShowDetail(tpl)
    if not tpl then MSWA_TB_ClearDetail(); return end

    browser.detName:SetText(tpl.name or "")
    browser.detDesc:SetText(tpl.desc or "")
    browser.selAllBtn:Show()
    browser.deselBtn:Show()
    browser.installBtn:Show()

    -- Build spell list
    wipe(currentSpells)
    wipe(spellChecks)
    if tpl.spells then
        for i, sp in ipairs(tpl.spells) do
            currentSpells[i] = sp
            spellChecks[i] = true  -- all checked by default
        end
    end

    MSWA_TB_RefreshSpellList()
end

function MSWA_TB_RefreshSpellList()
    local parent = browser.spellContent

    for _, row in ipairs(spellRows) do row:Hide() end

    for i, sp in ipairs(currentSpells) do
        local row = spellRows[i]
        if not row then
            row = CreateFrame("Frame", nil, parent)
            row:SetSize(DETAIL_W - 36, ROW_H + 2)

            -- Checkbox
            row.check = CreateFrame("CheckButton", "MSA_TB_Check" .. i, row, "UICheckButtonTemplate")
            row.check:SetSize(20, 20)
            row.check:SetPoint("LEFT", 0, 0)
            row.check._idx = i
            row.check:SetScript("OnClick", function(self)
                spellChecks[self._idx] = self:GetChecked() and true or false
            end)

            -- Icon (fixed size, never stretched)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
            row.icon:SetSize(ICON_SIZE, ICON_SIZE)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            -- Name text
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.nameText:SetJustifyH("LEFT")

            -- ID text (small, gray)
            row.idText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.idText:SetPoint("RIGHT", -4, 0)
            row.idText:SetJustifyH("RIGHT")

            spellRows[i] = row
        end

        row:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW_H + 2))
        row.check._idx = i
        row.check:SetChecked(spellChecks[i] or false)

        -- Icon
        local icon
        if sp.isItem and sp.itemID then
            icon = sp.icon or MSWA_GetItemIconSafe(sp.itemID)
        elseif sp.sid then
            icon = sp.icon or MSWA_GetSpellIconSafe(sp.sid)
        end
        if icon then
            row.icon:SetTexture(icon)
            row.icon:Show()
        else
            row.icon:Hide()
        end

        row.nameText:SetText(sp.name or "Unknown")

        if sp.isItem and sp.itemID then
            row.idText:SetText(format("Item:%d", sp.itemID))
        elseif sp.sid then
            row.idText:SetText(format("(%d)", sp.sid))
        else
            row.idText:SetText("")
        end

        row:Show()
    end

    parent:SetHeight(#currentSpells * (ROW_H + 2))
end

-----------------------------------------------------------
-- Install: only checked spells
-----------------------------------------------------------

function MSWA_TB_DoInstall()
    local db = MSWA_GetDB and MSWA_GetDB()
    if not db then return end

    db.trackedSpells  = db.trackedSpells  or {}
    db.trackedItems   = db.trackedItems   or {}
    db.spellSettings  = db.spellSettings  or {}

    -- Check if current category is a buff category
    local catInfo = selectedCat and MSWA_CATEGORY_LOOKUP[selectedCat]
    local isBuff = catInfo and catInfo.isBuff

    local installed = 0
    for i, sp in ipairs(currentSpells) do
        if spellChecks[i] then
            if sp.isItem and sp.itemID then
                local iid = sp.itemID
                if not db.trackedItems[iid] then
                    db.trackedItems[iid] = true
                end
                if isBuff then
                    local key = format("item:%d", iid)
                    local s = db.spellSettings[key] or {}
                    s.auraMode = "BUFF_AURA"
                    s.auraSpellID = iid
                    s.auraUnit = "player"
                    if s.showWhenAbsent == nil then s.showWhenAbsent = true end
                    if s.desaturateOnAbsent == nil then s.desaturateOnAbsent = true end
                    if s.alphaOnAbsent == nil then s.alphaOnAbsent = 0.45 end
                    if s.showStacks == nil then s.showStacks = true end
                    db.spellSettings[key] = s
                end
                installed = installed + 1
            elseif sp.sid then
                local sid = sp.sid
                if not db.trackedSpells[sid] then
                    db.trackedSpells[sid] = true
                end
                if isBuff then
                    local s = db.spellSettings[sid] or {}
                    s.auraMode = "BUFF_AURA"
                    s.auraSpellID = sid
                    s.auraUnit = "player"
                    if s.showWhenAbsent == nil then s.showWhenAbsent = true end
                    if s.desaturateOnAbsent == nil then s.desaturateOnAbsent = true end
                    if s.alphaOnAbsent == nil then s.alphaOnAbsent = 0.45 end
                    if s.showStacks == nil then s.showStacks = true end
                    db.spellSettings[sid] = s
                end
                installed = installed + 1
            end
        end
    end

    if installed > 0 then
        browser.statusText:SetText(format("|cff55ff55Installed %d aura(s)!|r", installed))
        if MSWA_RequestUpdateSpells then MSWA_RequestUpdateSpells() end
        if MSWA_RefreshOptionsList then MSWA_RefreshOptionsList() end
    else
        browser.statusText:SetText("|cffff5555No spells selected.|r")
    end
end

-----------------------------------------------------------
-- Toggle
-----------------------------------------------------------

function MSWA_ToggleTemplateBrowser()
    local f = CreateBrowser()
    if f:IsShown() then
        f:Hide()
    else
        -- Invalidate dynamic caches so they rescan on next view
        if not InCombatLockdown() then
            MSWA_InvalidateSpellbookCache()
            MSWA_InvalidateBagCache()
        end
        selectedCat = nil
        selectedTpl = nil
        MSWA_TB_ClearDetail()
        RefreshCategories()
        MSWA_TB_RefreshTemplates()
        f:Show()
    end
end
