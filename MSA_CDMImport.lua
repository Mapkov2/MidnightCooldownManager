-- ########################################################
-- MSA_CDMImport.lua  v1 - CDM Spell Picker
--
-- Lightweight popup to import spells from Blizzard's
-- Cooldown Manager (CDM) into MSA.
--
-- Two sections: "Tracked Buffs" and "Tracked Cooldowns"
-- Smart defaults: buffs -> BUFF_AURA, CDs -> Cooldown mode
-- 100 % secret-safe, zero pcall on hot paths
-- ########################################################

local ADDON_NAME, ns = ...

local pairs, ipairs, tinsert, wipe, format = pairs, ipairs, table.insert, wipe or table.wipe, string.format
local type, tonumber = type, tonumber
local CreateFrame = CreateFrame

-----------------------------------------------------------
-- Constants
-----------------------------------------------------------

local FRAME_W, FRAME_H = 420, 520
local ROW_H       = 24
local ICON_SIZE   = 20
local MAX_ROWS    = 40  -- pre-alloc pool
local SECTION_H   = 28

-----------------------------------------------------------
-- State
-----------------------------------------------------------

local picker           -- main frame
local scrollContent    -- scroll child
local rows       = {}  -- row pool
local flatList   = {}  -- { type="SPELL"|"HEADER", ... }
local checks     = {}  -- [flatIndex] = true/false
local tracked    = {}  -- [flatIndex] = true if already in MSA

-----------------------------------------------------------
-- CDM scan: split into Buffs and Cooldowns
-----------------------------------------------------------

local _issecretvalue = _G.issecretvalue

local function ResolveCDMSpell(cooldownID)
    if not cooldownID then return nil, nil, nil end
    if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then return nil, nil, nil end

    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
    if not info then return nil, nil, nil end

    local candidates = {
        info.overrideTooltipSpellID,
        info.linkedSpellIDs and info.linkedSpellIDs[1] or nil,
        info.overrideSpellID,
        info.spellID,
    }

    local spellID
    for i = 1, #candidates do
        local v = candidates[i]
        if type(v) == "number" and not (_issecretvalue and _issecretvalue(v)) and v > 0 then
            spellID = v; break
        end
    end
    if not spellID then return nil, nil, nil end

    local name, icon
    local CSpell_GetSpellInfo = C_Spell and C_Spell.GetSpellInfo
    if CSpell_GetSpellInfo then
        local sInfo = CSpell_GetSpellInfo(spellID)
        if sInfo then name = sInfo.name; icon = sInfo.iconID end
    end
    if not icon and C_Spell and C_Spell.GetSpellTexture then
        icon = C_Spell.GetSpellTexture(spellID)
    end

    return spellID, name, icon
end

local function ScanCDMCategory(category)
    if not category then return {} end
    if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet) then return {} end

    local ok, cooldownIDs = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, category, true)
    if not ok or type(cooldownIDs) ~= "table" then return {} end

    local results = {}
    local seen = {}
    for _, cooldownID in ipairs(cooldownIDs) do
        local spellID, name, icon = ResolveCDMSpell(cooldownID)
        if spellID and not seen[spellID] then
            seen[spellID] = true
            tinsert(results, {
                sid  = spellID,
                name = name or ("Spell:" .. spellID),
                icon = icon,
                cdmCooldownID = cooldownID,
            })
        end
    end

    table.sort(results, function(a, b) return (a.name or "") < (b.name or "") end)
    return results
end

-----------------------------------------------------------
-- Build flat list (headers + spells)
-----------------------------------------------------------

local function BuildFlatList()
    wipe(flatList)
    wipe(checks)
    wipe(tracked)

    local db = MSWA_GetDB and MSWA_GetDB()
    local ts = db and db.trackedSpells or {}
    local ti = db and db.trackedItems or {}

    local TrackedBuff = Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBuff
    local TrackedBar  = Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBar

    local buffs = ScanCDMCategory(TrackedBuff)
    local cds   = ScanCDMCategory(TrackedBar)

    -- Dedup: remove CDs that are already in buffs
    local buffSeen = {}
    for _, sp in ipairs(buffs) do buffSeen[sp.sid] = true end
    local cdsFiltered = {}
    for _, sp in ipairs(cds) do
        if not buffSeen[sp.sid] then tinsert(cdsFiltered, sp) end
    end
    cds = cdsFiltered

    -- Section: Buffs
    if #buffs > 0 then
        tinsert(flatList, { type = "HEADER", label = format("Tracked Buffs  (%d)", #buffs), isBuff = true })
        for _, sp in ipairs(buffs) do
            local idx = #flatList + 1
            tinsert(flatList, { type = "SPELL", sp = sp, isBuff = true })
            checks[idx] = false
            tracked[idx] = (ts[sp.sid] == true)
        end
    end

    -- Section: Cooldowns
    if #cds > 0 then
        tinsert(flatList, { type = "HEADER", label = format("Tracked Cooldowns  (%d)", #cds), isBuff = false })
        for _, sp in ipairs(cds) do
            local idx = #flatList + 1
            tinsert(flatList, { type = "SPELL", sp = sp, isBuff = false })
            checks[idx] = false
            tracked[idx] = (ts[sp.sid] == true)
        end
    end

    -- Empty state
    if #flatList == 0 then
        tinsert(flatList, { type = "HEADER", label = "No CDM spells found." })
    end
end

-----------------------------------------------------------
-- UI: Row pool
-----------------------------------------------------------

local W  -- resolved on first use (MSA_Widgets loaded before us)
local T

local function EnsureRow(parent, idx)
    if rows[idx] then return rows[idx] end

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("LEFT", 0, 0)
    row:SetPoint("RIGHT", 0, 0)

    -- Highlight on hover
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 0)

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if self._isHeader then return end
        self.bg:SetColorTexture(1, 1, 1, 0.04)
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(1, 1, 1, 0)
    end)

    -- Checkbox
    row.check = CreateFrame("CheckButton", "MSA_CDM_Check" .. idx, row, "UICheckButtonTemplate")
    row.check:SetSize(20, 20)
    row.check:SetPoint("LEFT", 4, 0)
    row.check._idx = idx
    row.check:SetScript("OnClick", function(self)
        checks[self._idx] = self:GetChecked() and true or false
        if picker and picker.UpdateStatus then picker:UpdateStatus() end
    end)

    -- Icon
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Name
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.nameText:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    -- Status (right side: tracked badge / spell ID)
    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.statusText:SetPoint("RIGHT", -6, 0)
    row.statusText:SetJustifyH("RIGHT")

    -- Section header label (reused for HEADER type)
    row.headerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.headerText:SetPoint("LEFT", 8, 0)
    row.headerText:SetTextColor(1, 0.82, 0)

    -- Click row to toggle check
    row:SetScript("OnMouseDown", function(self)
        if self._isHeader then return end
        local i = self._flatIdx
        if not i or tracked[i] then return end
        checks[i] = not checks[i]
        self.check:SetChecked(checks[i])
        if picker and picker.UpdateStatus then picker:UpdateStatus() end
    end)

    rows[idx] = row
    return row
end

-----------------------------------------------------------
-- Refresh visible rows
-----------------------------------------------------------

local function RefreshRows()
    for _, row in ipairs(rows) do row:Hide() end

    local yOff = 0
    for i, entry in ipairs(flatList) do
        local row = EnsureRow(scrollContent, i)
        row._flatIdx = i
        row._isHeader = (entry.type == "HEADER")

        if entry.type == "HEADER" then
            row:SetHeight(SECTION_H)
            row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOff)
            row.check:Hide()
            row.icon:Hide()
            row.nameText:Hide()
            row.statusText:Hide()
            row.headerText:SetText(entry.label)
            row.headerText:Show()
            yOff = yOff - SECTION_H
        else
            local sp = entry.sp
            local isTracked = tracked[i]
            row:SetHeight(ROW_H)
            row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOff)
            row.headerText:Hide()

            -- Checkbox
            row.check._idx = i
            row.check:SetChecked(checks[i] or false)
            row.check:SetEnabled(not isTracked)
            row.check:Show()

            -- Icon
            if sp.icon then
                row.icon:SetTexture(sp.icon)
                row.icon:SetDesaturated(isTracked)
                row.icon:SetAlpha(isTracked and 0.45 or 1)
                row.icon:Show()
            else
                row.icon:Hide()
            end

            -- Name
            if isTracked then
                row.nameText:SetText("|cff666666" .. (sp.name or "?") .. "|r")
            else
                row.nameText:SetText(sp.name or "?")
            end
            row.nameText:Show()

            -- Status
            if isTracked then
                row.statusText:SetText("|cff44aa44tracked|r")
            else
                row.statusText:SetText(format("(%d)", sp.sid or 0))
            end
            row.statusText:Show()

            yOff = yOff - ROW_H
        end

        row:Show()
    end

    scrollContent:SetHeight(math.abs(yOff) + 10)
end

-----------------------------------------------------------
-- Select helpers
-----------------------------------------------------------

local function SelectAllOfType(isBuff)
    for i, entry in ipairs(flatList) do
        if entry.type == "SPELL" and entry.isBuff == isBuff and not tracked[i] then
            checks[i] = true
        end
    end
    RefreshRows()
    if picker and picker.UpdateStatus then picker:UpdateStatus() end
end

local function DeselectAll()
    for i in pairs(checks) do checks[i] = false end
    RefreshRows()
    if picker and picker.UpdateStatus then picker:UpdateStatus() end
end

local function CountSelected()
    local n = 0
    for i, entry in ipairs(flatList) do
        if entry.type == "SPELL" and checks[i] and not tracked[i] then n = n + 1 end
    end
    return n
end

-----------------------------------------------------------
-- Import logic
-----------------------------------------------------------

local function DoImport()
    local db = MSWA_GetDB and MSWA_GetDB()
    if not db then return 0 end

    db.trackedSpells  = db.trackedSpells  or {}
    db.spellSettings  = db.spellSettings  or {}

    local installed = 0

    for i, entry in ipairs(flatList) do
        if entry.type == "SPELL" and checks[i] and not tracked[i] then
            local sp = entry.sp
            local sid = sp.sid
            if sid then
                if not db.trackedSpells[sid] then
                    db.trackedSpells[sid] = true
                end

                local s = db.spellSettings[sid] or {}

                if entry.isBuff then
                    -- Buff -> BUFF_AURA with smart defaults
                    s.auraMode      = "BUFF_AURA"
                    s.auraSpellID   = sid
                    s.auraUnit      = "player"
                    if s.showWhenAbsent     == nil then s.showWhenAbsent     = true end
                    if s.desaturateOnAbsent == nil then s.desaturateOnAbsent = true end
                    if s.alphaOnAbsent      == nil then s.alphaOnAbsent      = 0.45 end
                    if s.showStacks         == nil then s.showStacks         = true end
                else
                    -- Cooldown -> standard CD mode (nil = Cooldown)
                    -- Keep existing auraMode if already set, otherwise nil (default CD)
                    if not s.auraMode then s.auraMode = nil end
                end

                if sp.cdmCooldownID then
                    s.cdmCooldownID = sp.cdmCooldownID
                end

                db.spellSettings[sid] = s
                installed = installed + 1
                tracked[i] = true
                checks[i] = false
            end
        end
    end

    return installed
end

-----------------------------------------------------------
-- Create picker frame
-----------------------------------------------------------

local function CreatePicker()
    if picker then return picker end

    W = MSWA_W
    T = W and W.Theme or {}

    picker = CreateFrame("Frame", "MSA_CDMImportFrame", UIParent, "BackdropTemplate")
    picker:SetSize(FRAME_W, FRAME_H)
    picker:SetPoint("CENTER")
    picker:SetFrameStrata("DIALOG")
    picker:SetMovable(true)
    picker:EnableMouse(true)
    picker:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "MSA_CDMImportFrame")

    -- Backdrop
    if W and W.ApplyBackdrop then
        W.ApplyBackdrop(picker, 0.95)
    else
        picker:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        picker:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
        picker:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)
    end

    -- Title bar (draggable)
    local titleBar = CreateFrame("Frame", nil, picker)
    titleBar:SetHeight(28)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() picker:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() picker:StopMovingOrSizing() end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", 12, 0)
    titleText:SetText("Import from Cooldown Manager")
    if W and W.SkinTitle then W.SkinTitle(titleText) else titleText:SetTextColor(1, 0.82, 0) end

    -- Close button
    local closeBtn = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() picker:Hide() end)

    -- ESC to close
    picker:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide(); self:SetPropagateKeyboardInput(false)
        else self:SetPropagateKeyboardInput(true) end
    end)

    -- Hint text (below title)
    local hint = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 12, -30)
    hint:SetPoint("TOPRIGHT", -12, -30)
    hint:SetText("Select spells from Blizzard's Cooldown Manager to track in MSA.\nBuffs are imported as Buff Aura, cooldowns as standard CD tracker.")
    hint:SetJustifyH("LEFT")
    if W and W.SkinMuted then W.SkinMuted(hint) end

    -- Scroll area
    local scrollFrame = CreateFrame("ScrollFrame", "MSA_CDM_Scroll", picker, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -68)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 68)

    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(FRAME_W - 36, 800)
    scrollFrame:SetScrollChild(scrollContent)

    -- Bottom area: buttons + status
    local bottomArea = CreateFrame("Frame", nil, picker)
    bottomArea:SetPoint("BOTTOMLEFT", 8, 8)
    bottomArea:SetPoint("BOTTOMRIGHT", -8, 8)
    bottomArea:SetHeight(56)

    -- Status text
    picker.statusText = bottomArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    picker.statusText:SetPoint("TOPLEFT", 4, -2)
    picker.statusText:SetPoint("TOPRIGHT", -4, -2)
    picker.statusText:SetJustifyH("LEFT")

    -- Button row
    local btnY = -20
    local function MakeBtn(text, w, onClick)
        local btn
        if W and W.Button then
            btn = W.Button(bottomArea, text, w, 26, onClick)
        else
            btn = CreateFrame("Button", nil, bottomArea, "UIPanelButtonTemplate")
            btn:SetSize(w, 26); btn:SetText(text)
            btn:SetScript("OnClick", onClick)
        end
        return btn
    end

    local btnSelBuffs = MakeBtn("Select All Buffs", 120, function() SelectAllOfType(true) end)
    btnSelBuffs:SetPoint("BOTTOMLEFT", bottomArea, "BOTTOMLEFT", 0, 0)

    local btnSelCDs = MakeBtn("Select All CDs", 110, function() SelectAllOfType(false) end)
    btnSelCDs:SetPoint("LEFT", btnSelBuffs, "RIGHT", 4, 0)

    local btnDesel = MakeBtn("Deselect", 72, function() DeselectAll() end)
    btnDesel:SetPoint("LEFT", btnSelCDs, "RIGHT", 4, 0)

    picker.importBtn = MakeBtn("|cff55ff55Import|r", 90, function()
        local n = DoImport()
        if n > 0 then
            picker.statusText:SetText(format("|cff55ff55Imported %d aura(s)!|r", n))
            if MSWA_RequestUpdateSpells then MSWA_RequestUpdateSpells() end
            if MSWA_RefreshOptionsList then MSWA_RefreshOptionsList() end
            RefreshRows()
        else
            picker.statusText:SetText("|cffff9900No new spells selected.|r")
        end
        if picker.UpdateStatus then picker:UpdateStatus() end
    end)
    picker.importBtn:SetPoint("BOTTOMRIGHT", bottomArea, "BOTTOMRIGHT", 0, 0)

    -- Status updater
    function picker:UpdateStatus()
        local sel = CountSelected()
        local total = 0
        local trackedN = 0
        for i, entry in ipairs(flatList) do
            if entry.type == "SPELL" then
                total = total + 1
                if tracked[i] then trackedN = trackedN + 1 end
            end
        end
        local newN = total - trackedN
        if sel > 0 then
            self.statusText:SetText(format("|cff88cc88%d selected|r  |cff888888(%d new, %d tracked)|r", sel, newN, trackedN))
        elseif trackedN == total and total > 0 then
            self.statusText:SetText(format("|cff888888All %d spells already tracked.|r", total))
        elseif total > 0 then
            self.statusText:SetText(format("|cff888888%d new, %d tracked|r", newN, trackedN))
        else
            self.statusText:SetText("")
        end
    end

    picker:Hide()
    return picker
end

-----------------------------------------------------------
-- Public API
-----------------------------------------------------------

function MSWA_ToggleCDMImport()
    local f = CreatePicker()
    if f:IsShown() then
        f:Hide()
    else
        BuildFlatList()
        RefreshRows()
        f:UpdateStatus()
        f:Show()
    end
end

function MSWA_OpenCDMImport()
    local f = CreatePicker()
    BuildFlatList()
    RefreshRows()
    f:UpdateStatus()
    f:Show()
end
