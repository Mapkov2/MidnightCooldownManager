local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local function SetSizeField(key, field, value)
    local current = CDM.db[key]
    local updated = { w = current.w, h = current.h }
    updated[field] = value
    CDM.db[key] = updated
end

local function CreateSizesTab(page, tabId)
    local content, scrollFrame = UI.CreateScrollableTab(page, "MidnightCDM_SizesScrollFrame", 640, 560)
    local scrollChild = scrollFrame:GetScrollChild()
    local sections = {}
    local function Relayout()
        UI.LayoutAccordionSections(sections, 0, 8, scrollChild, content)
    end
    local function AddSection(title, key, height)
        local section, body = UI.CreateAccordionSection(content, title, 540, height, "sizes:" .. key, true, Relayout)
        sections[#sections + 1] = section
        return section, body
    end

    local _, essentialBody = AddSection(L["Essential"], "essential", 270)
    local yOff = 0

    page.controls.s1 = UI.CreateModernSlider(essentialBody, L["Row 1 Width"], 20, 100, CDM.db.sizeEssRow1.w, function(v) SetSizeField("sizeEssRow1", "w", v); API:Refresh("LAYOUT") end)
    page.controls.s1:SetPoint("TOPLEFT", 0, yOff)
    page.controls.s2 = UI.CreateModernSlider(essentialBody, L["Row 1 Height"], 20, 100, CDM.db.sizeEssRow1.h, function(v) SetSizeField("sizeEssRow1", "h", v); API:Refresh("LAYOUT") end)
    page.controls.s2:SetPoint("TOPLEFT", page.controls.s1, "BOTTOMLEFT", 0, -10)

    page.controls.s3 = UI.CreateModernSlider(essentialBody, L["Row 2 Width"], 20, 100, CDM.db.sizeEssRow2.w, function(v) SetSizeField("sizeEssRow2", "w", v); API:Refresh("LAYOUT") end)
    page.controls.s3:SetPoint("TOPLEFT", page.controls.s2, "BOTTOMLEFT", 0, -10)
    page.controls.s4 = UI.CreateModernSlider(essentialBody, L["Row 2 Height"], 20, 100, CDM.db.sizeEssRow2.h, function(v) SetSizeField("sizeEssRow2", "h", v); API:Refresh("LAYOUT") end)
    page.controls.s4:SetPoint("TOPLEFT", page.controls.s3, "BOTTOMLEFT", 0, -10)

    local _, utilityBody = AddSection(L["Utility"], "utility", 130)

    page.controls.s5 = UI.CreateModernSlider(utilityBody, L["Width"], 20, 100, CDM.db.sizeUtility.w, function(v) SetSizeField("sizeUtility", "w", v); API:Refresh("LAYOUT") end)
    page.controls.s5:SetPoint("TOPLEFT", 0, 0)
    page.controls.s6 = UI.CreateModernSlider(utilityBody, L["Height"], 20, 100, CDM.db.sizeUtility.h, function(v) SetSizeField("sizeUtility", "h", v); API:Refresh("LAYOUT") end)
    page.controls.s6:SetPoint("TOPLEFT", page.controls.s5, "BOTTOMLEFT", 0, -10)

    local _, buffBody = AddSection(L["Buff"], "buff", 130)

    page.controls.s7 = UI.CreateModernSlider(buffBody, L["Width"], 20, 100, CDM.db.sizeBuff.w, function(v) SetSizeField("sizeBuff", "w", v); API:Refresh("LAYOUT") end)
    page.controls.s7:SetPoint("TOPLEFT", 0, 0)
    page.controls.s8 = UI.CreateModernSlider(buffBody, L["Height"], 20, 100, CDM.db.sizeBuff.h, function(v) SetSizeField("sizeBuff", "h", v); API:Refresh("LAYOUT") end)
    page.controls.s8:SetPoint("TOPLEFT", page.controls.s7, "BOTTOMLEFT", 0, -10)

    Relayout()
end

API:RegisterConfigTab("sizes", L["Icon Sizes"], CreateSizesTab, 1)
