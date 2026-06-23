local Runtime = _G["MidnightCooldownManager"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local C = CDM.CONST
local L = Runtime.L

local Pixel = CDM.Pixel


local function RefreshAutoWidthLinkedElements()
end

local function EnsurePosition(viewerName, defaults)
    if not CDM.db.editModePositions then
        CDM.db.editModePositions = {}
    end
    if not CDM.db.editModePositions[viewerName] then
        CDM.db.editModePositions[viewerName] = {}
    end
    if not CDM.db.editModePositions[viewerName]["Default"] then
        CDM.db.editModePositions[viewerName]["Default"] = defaults
    end
    return CDM.db.editModePositions[viewerName]["Default"]
end

local function CreatePositionControls(parent, anchor, page, cfg)
    local pos = EnsurePosition(cfg.viewerName, cfg.defaults)

    local display = parent:CreateFontString(nil, "ARTWORK", "MidnightCDM_Font14")
    if anchor then
        display:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -15)
    else
        display:SetPoint("TOPLEFT", 0, 0)
    end
    display:SetText(string.format(L["Current: %s (%d, %d)"],pos.point, pos.x, pos.y))
    UI.SetTextSuccess(display)

    local function UpdateDisplay()
        local p = EnsurePosition(cfg.viewerName, cfg.defaults)
        display:SetText(string.format(L["Current: %s (%d, %d)"],p.point, p.x, p.y))
    end

    local function OnSliderChanged(axis, v)
        local p = EnsurePosition(cfg.viewerName, cfg.defaults)
        p[axis] = v

        local container = CDM.anchorContainers and CDM.anchorContainers[cfg.viewerName]
        if container then
            if cfg.reanchor then
                cfg.reanchor()
            else
                container:ClearAllPoints()
                local anchorPt = cfg.getAnchorPoint and cfg.getAnchorPoint() or cfg.anchorPoint
                Pixel.SetPoint(container, anchorPt, UIParent, p.point, p.x, p.y)
            end
            if cfg.postMove then cfg.postMove() end
        end
        UpdateDisplay()
    end

    page.controls[cfg.xKey] = UI.CreateModernSlider(
        parent, L["X Position"], -2000, 2000, pos.x,
        function(v) OnSliderChanged("x", v) end
    )
    page.controls[cfg.xKey]:SetPoint("TOPLEFT", display, "BOTTOMLEFT", 0, -10)

    page.controls[cfg.yKey] = UI.CreateModernSlider(
        parent, L["Y Position"], -2000, 2000, pos.y,
        function(v) OnSliderChanged("y", v) end
    )
    page.controls[cfg.yKey]:SetPoint("TOPLEFT", page.controls[cfg.xKey], "BOTTOMLEFT", 0, -10)

    return page.controls[cfg.yKey]
end

local function CreatePositionsTab(page, tabId)
    local content, scrollFrame = UI.CreateScrollableTab(page, "MidnightCDM_PositionsScrollFrame", 740, 560)
    local scrollChild = scrollFrame:GetScrollChild()

    local sections = {}
    local function Relayout()
        UI.LayoutAccordionSections(sections, 0, 8, scrollChild, content)
    end
    local function AddSection(title, key, height)
        local section, body = UI.CreateAccordionSection(content, title, 540, height, "positions:" .. key, true, Relayout)
        sections[#sections + 1] = section
        return section, body
    end

    local _, essBody = AddSection(L["Essential Container Position"], "essential", 220)

    local essYSlider = CreatePositionControls(essBody, nil, page, {
        viewerName = C.VIEWERS.ESSENTIAL,
        defaults = { point = "CENTER", x = 0, y = -201 },
        anchorPoint = "TOP",
        reanchor = function() CDM:ReanchorContainer(C.VIEWERS.ESSENTIAL) end,
        xKey = "xPos",
        yKey = "yPos",
        postMove = function()
            if CDM.UpdateUtilityContainerPosition then
                API:UpdateUtilityContainerPosition()
            end
            RefreshAutoWidthLinkedElements()
        end,
    })

    local utilYOffsetSlider = UI.CreateModernSlider(essBody, L["Utility Y Offset"], -600, 600, CDM.db.utilityYOffset, function(v)
        CDM.db.utilityYOffset = v; API:Refresh("LAYOUT")
    end)
    utilYOffsetSlider:SetPoint("TOPLEFT", essYSlider, "BOTTOMLEFT", 0, -10)

    local _, buffBody = AddSection(L["Main Buff Container Position"], "buff", 160)

    CreatePositionControls(buffBody, nil, page, {
        viewerName = C.VIEWERS.BUFF,
        defaults = { point = "CENTER", x = 0, y = -149 },
        anchorPoint = "BOTTOM",
        xKey = "buffXPos",
        yKey = "buffYPos",
        reanchor = function() CDM:UpdateBuffContainerPosition() end,
    })

    local _, buffBarBody = AddSection(L["Buff Bar Container Position"], "buffbar", 160)

    CreatePositionControls(buffBarBody, nil, page, {
        viewerName = C.VIEWERS.BUFF_BAR,
        defaults = { point = "CENTER", x = 0, y = -324 },
        xKey = "buffBarXPos",
        yKey = "buffBarYPos",
        reanchor = function() CDM:UpdateBuffBarContainerPosition() end,
        getAnchorPoint = function()
            local growDirection = CDM.db.buffBarGrowDirection or "DOWN"
            return growDirection == "DOWN" and "TOP" or "BOTTOM"
        end,
    })

    Relayout()
end

API:RegisterConfigTab("positions", L["Positions"], CreatePositionsTab, 3)
