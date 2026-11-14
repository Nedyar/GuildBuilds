-- GearPanel.lua: a member's gear set, in a panel beside the game's talent
-- window when it shows that member's talents, or beside the guild window
-- when only the gear is shared. The items sit by slot as in the character
-- window, with their tooltips (shift-click links one, control-click tries
-- it on). A build with more than one set has a menu to pick one, its
-- default first.
--
-- Beside the talent window, the two are centred together: the window moves
-- left by half the panel's width while it shows the member's build, and
-- goes back when it shows anything else (our own talents, a player
-- inspected, a build linked in the chat) or closes. The game's panel
-- manager places the window anew whenever it opens it; nothing of its own
-- is changed (no panel attributes), only where the window is anchored.
local _, ns = ...
local L = ns.L

local GearPanel = {}
ns.GearPanel = GearPanel

local SLOT_SIZE, GAP, MARGIN = 37, 4, 14
local MIDDLE = 128
local HEADER = 62   -- the title bar, then the set's name or menu
local WIDTH = MARGIN * 2 + SLOT_SIZE * 2 + MIDDLE
local ROWS = 8
local HEIGHT = HEADER + ROWS * (SLOT_SIZE + GAP) + GAP + SLOT_SIZE + MARGIN
-- The character window's slots: the left and right columns, then the
-- weapons and the ranged weapon (gear sets leave the ammo out).
local COLUMNS = {
    { 1, 2, 3, 15, 5, 4, 19, 9 },
    { 10, 6, 7, 8, 11, 12, 13, 14 },
}
local BOTTOM = { 16, 17, 18 }
local SLOT_NAMES = {
    "HEADSLOT", "NECKSLOT", "SHOULDERSLOT", "SHIRTSLOT", "CHESTSLOT", "WAISTSLOT",
    "LEGSSLOT", "FEETSLOT", "WRISTSLOT", "HANDSSLOT", "FINGER0SLOT", "FINGER1SLOT", "TRINKET0SLOT",
    "TRINKET1SLOT", "BACKSLOT", "MAINHANDSLOT", "SECONDARYHANDSLOT", "RANGEDSLOT", "TABARDSLOT",
}
local MIN_QUALITY = 2   -- uncommon and better show their quality's border
local TITLE_INSET = 58  -- from each side to the title, when it cannot be measured
local TITLE_GAP = 2     -- between the title and the talents button
local QUESTION_MARK = 134400

local panel
local buttons = {}      -- [slot] = button
local hookedTargets = {}
local shifted           -- { frame, points = its anchors before we moved it }

-- What the panel shows: { guid, gr, index = the set shown, target = the
-- window it sits beside }, while it shows it.
GearPanel.current = nil

local function BuildShown()
    local current = GearPanel.current
    if not current then
        return nil
    end
    local guild = ns.Data.CurrentGuild(false)
    local record = guild and guild.members[current.guid]
    return ns.Data.BuildOf(record, current.gr), record
end

-- Slots -------------------------------------------------------------------------------

local function SlotOnEnter(button)
    if not button.item then
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(button.item)
    GameTooltip:Show()
end

local function SlotOnClick(button)
    if not button.item then
        return
    end
    local _, link = ns.Try(C_Item.GetItemInfo, button.item)
    if type(link) == "string" and HandleModifiedItemClick then
        HandleModifiedItemClick(link)
    end
end

local function CreateSlot(slot, emptyTexture)
    local button = CreateFrame("Button", nil, panel)
    button:SetSize(SLOT_SIZE, SLOT_SIZE)
    button.slot = slot
    button.Empty = button:CreateTexture(nil, "BACKGROUND")
    button.Empty:SetAllPoints()
    button.Empty:SetTexture(emptyTexture or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetAllPoints()
    button.Border = button:CreateTexture(nil, "OVERLAY")
    button.Border:SetAllPoints()
    button.Border:SetTexture("Interface\\Common\\WhiteIconFrame")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnEnter", SlotOnEnter)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnClick", SlotOnClick)
    buttons[slot] = button
    return button
end

-- Shows an item string in a slot, or the empty slot. Returns false when the
-- client has yet to load the item's quality.
local function ShowItem(button, itemString)
    button.item = itemString
    if not itemString then
        button.Icon:Hide()
        button.Border:Hide()
        return true
    end
    local itemID = tonumber(itemString:match("^item:(%d+)"))
    button.Icon:SetTexture(ns.Try(C_Item.GetItemIconByID, itemID) or QUESTION_MARK)
    button.Icon:Show()
    local quality = ns.Number(ns.Try(C_Item.GetItemQualityByID, itemID))
    if quality and quality >= MIN_QUALITY and C_Item.GetItemQualityColor then
        local r, g, b = ns.Try(C_Item.GetItemQualityColor, quality)
        button.Border:SetVertexColor(r or 1, g or 1, b or 1)
        button.Border:Show()
    else
        button.Border:Hide()
    end
    if quality == nil then
        ns.Try(C_Item.RequestLoadItemDataByID, itemID)
        return false
    end
    return true
end

-- The panel ----------------------------------------------------------------------------

local function SetMenu(owner, root)
    local build = BuildShown()
    for index, set in ipairs(build and build.q or {}) do
        local text = index == 1 and L["%s (default)"]:format(set.n) or set.n
        root:CreateRadio(text, function()
            return GearPanel.current and GearPanel.current.index == index
        end, function()
            if GearPanel.current then
                GearPanel.current.index = index
                GearPanel.Refresh()
            end
        end)
    end
end

local function TalentsTooltip()
    local build = BuildShown()
    GameTooltip:SetText(TALENTS or L["Talents"], 1, 1, 1)
    if build and build.x then
        GameTooltip:AddLine(L["Show or hide these talents."], nil, nil, nil, true)
    else
        GameTooltip:AddLine(L["Its talents are not shared."], 0.7, 0.7, 0.7)
    end
end

local function Create()
    if panel then
        return
    end
    panel = CreateFrame("Frame", "GuildBuildsGearPanel", UIParent, "ButtonFrameTemplate")
    panel:SetSize(WIDTH, HEIGHT)
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:Hide()
    if ButtonFrameTemplate_HidePortrait then
        ButtonFrameTemplate_HidePortrait(panel)
    end
    if ButtonFrameTemplate_HideButtonBar then
        ButtonFrameTemplate_HideButtonBar(panel)
    end
    -- However it closes (its close button, Escape...), the talent window
    -- goes back where it was.
    panel:SetScript("OnHide", function()
        GearPanel.current = nil
        GearPanel.RestoreTalentWindow()
    end)
    -- Left of its close button, the build's talents, over the title.
    panel.TalentsButton = ns.TitleButton.New(panel, panel.CloseButton, GearPanel.ToggleTalents, TalentsTooltip)
    local container = panel.TitleContainer
    if container then
        panel.TalentsButton:SetFrameLevel(container:GetFrameLevel() + 1)
        local count = ns.Number(ns.Try(container.GetNumPoints, container)) or 0
        panel.titleY = count > 0 and ns.Number(select(5, container:GetPoint(1))) or 0
    end
    -- Escape closes it, like the game's windows.
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "GuildBuildsGearPanel")
    end

    -- The set's name, or a menu of the build's sets.
    panel.SetName = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    panel.SetName:SetPoint("TOP", 0, -34)
    panel.SetName:SetWidth(WIDTH - 2 * MARGIN)
    panel.SetMenu = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    panel.SetMenu:SetWidth(WIDTH - 2 * MARGIN)
    panel.SetMenu:SetPoint("TOP", 0, -28)
    panel.SetMenu:SetupMenu(SetMenu)

    -- In the middle, the set's icon.
    panel.SetIcon = panel:CreateTexture(nil, "ARTWORK")
    panel.SetIcon:SetSize(48, 48)
    panel.SetIcon:SetPoint("TOP", 0, -HEADER - 10)

    for column, slots in ipairs(COLUMNS) do
        local x = column == 1 and MARGIN or WIDTH - MARGIN - SLOT_SIZE
        for row, slot in ipairs(slots) do
            local _, texture = ns.Try(GetInventorySlotInfo, SLOT_NAMES[slot])
            CreateSlot(slot, texture):SetPoint("TOPLEFT", x, -(HEADER + (row - 1) * (SLOT_SIZE + GAP)))
        end
    end
    -- The bottom row, centred.
    local rowWidth = #BOTTOM * SLOT_SIZE + (#BOTTOM - 1) * GAP
    for i, slot in ipairs(BOTTOM) do
        local _, texture = ns.Try(GetInventorySlotInfo, SLOT_NAMES[slot])
        local x = (WIDTH - rowWidth) / 2 + (i - 1) * (SLOT_SIZE + GAP)
        CreateSlot(slot, texture):SetPoint("TOPLEFT", x, -(HEADER + ROWS * (SLOT_SIZE + GAP) + GAP))
    end
    GearPanel.panel, GearPanel.buttons = panel, buttons
end

-- Screen pixels from a frame's coordinates.
local function OnScreen(frame, value)
    return (value or 0) * (ns.Try(frame.GetEffectiveScale, frame) or 1)
end

-- Moves the talent window left by half the panel, so the two are centred
-- together, when the screen has room for both and the game shows no window
-- on the left (the window then sits beside it).
local function ShiftTalentWindow(frame)
    if shifted or InCombatLockdown() or ns.Try(GetUIPanel, "left") then
        return
    end
    local count = ns.Number(ns.Try(frame.GetNumPoints, frame)) or 0
    if count == 0 then
        return
    end
    local panelWidth = OnScreen(panel, WIDTH + 2)
    local half = panelWidth / 2
    local left = OnScreen(frame, ns.Try(frame.GetLeft, frame))
    local right = OnScreen(frame, ns.Try(frame.GetRight, frame))
    local screen = OnScreen(UIParent, ns.Try(UIParent.GetRight, UIParent))
    if left - half < 0 or right - half + panelWidth > screen then
        return
    end
    local points = {}
    for i = 1, count do
        points[i] = { frame:GetPoint(i) }
    end
    local offset = half / (ns.Try(frame.GetEffectiveScale, frame) or 1)
    frame:ClearAllPoints()
    for _, point in ipairs(points) do
        frame:SetPoint(point[1], point[2], point[3], (point[4] or 0) - offset, point[5] or 0)
    end
    shifted = { frame = frame, points = points, x = (points[1][4] or 0) - offset }
end

-- Puts the talent window back where it was. In combat, once hidden, or
-- when the game has placed it anew since (another window opened), the
-- game's own placing does it.
local function RestoreTalentWindow()
    if not shifted then
        return
    end
    local frame, points, x = shifted.frame, shifted.points, shifted.x
    shifted = nil
    if InCombatLockdown() or not frame:IsShown() then
        return
    end
    local now = ns.Number(select(4, frame:GetPoint(1)))
    if not now or math.abs(now - x) > 0.5 then
        return
    end
    frame:ClearAllPoints()
    for _, point in ipairs(points) do
        frame:SetPoint(unpack(point, 1, 5))
    end
end
GearPanel.RestoreTalentWindow = RestoreTalentWindow

-- The title between the talents button and as much room on the left, so it
-- stays centred and clear of the button (cut short if too long).
local function FitTitle()
    local container = panel.TitleContainer
    if not container then
        return
    end
    local right = ns.Number(ns.Try(panel.GetRight, panel))
    local left = ns.Number(ns.Try(panel.TalentsButton.GetLeft, panel.TalentsButton))
    local inset = (right and left and right > left) and (right - left + TITLE_GAP) or TITLE_INSET
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, panel.titleY)
    container:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -inset, panel.titleY)
end

-- Beside the window, on whichever side the screen has room for it.
local function Place(target)
    panel:ClearAllPoints()
    local width = WIDTH * (ns.Try(panel.GetEffectiveScale, panel) or 1)
    local scale = ns.Try(target.GetEffectiveScale, target) or 1
    local right = (ns.Try(target.GetRight, target) or 0) * scale
    local left = (ns.Try(target.GetLeft, target) or 0) * scale
    local screen = (ns.Try(UIParent.GetRight, UIParent) or 0) * (ns.Try(UIParent.GetEffectiveScale, UIParent) or 1)
    if right + width <= screen then
        panel:SetPoint("TOPLEFT", target, "TOPRIGHT", 2, 0)
    elseif left - width >= 0 then
        panel:SetPoint("TOPRIGHT", target, "TOPLEFT", -2, 0)
    else
        panel:SetPoint("TOPRIGHT", target, "TOPRIGHT", -4, -24)
    end
    local strata = ns.Try(target.GetFrameStrata, target)
    if strata then
        panel:SetFrameStrata(strata)
    end
end

-- Draws the set shown again (the record may have changed).
function GearPanel.Refresh()
    local build, record = BuildShown()
    if not (build and build.q) then
        GearPanel.Hide()
        return
    end
    local current = GearPanel.current
    current.index = math.min(math.max(current.index or 1, 1), #build.q)
    local set = build.q[current.index]
    local name = ns.Data.NameOf(current.guid, record)
    if #record.s > 1 then
        name = ("%s (%s)"):format(name, ns.GroupLabel(current.gr))
    end
    panel:SetTitle(L["Gear of %s"]:format(name))
    local several = #build.q > 1
    panel.SetMenu:SetShown(several)
    panel.SetName:SetShown(not several)
    if several then
        panel.SetMenu:GenerateMenu()
    else
        panel.SetName:SetText(set.n)
    end
    panel.SetIcon:SetTexture(set.i > 0 and set.i or QUESTION_MARK)
    -- The talents button shows the build's main tree, greyed when its
    -- talents are not shared.
    local main = ns.Data.MainTab(build)
    local tab = main and record.tb and record.tb[main]
    ns.TitleButton.Set(panel.TalentsButton, tab and tab.i > 0 and tab.i or QUESTION_MARK, build.x ~= nil)

    local items = {}
    for _, item in ipairs(set.it) do
        items[item.s] = item.i
    end
    local loading = false
    for slot, button in pairs(buttons) do
        if not ShowItem(button, items[slot]) then
            loading = true
        end
    end
    -- Item qualities the client did not have yet: drawn again once loaded.
    if loading then
        ns.Debounce("GearPanelRefresh", 0.5, function()
            if panel:IsShown() then
                GearPanel.Refresh()
            end
        end)
    end
end

-- Shows a member's gear of a spec group beside a window (index: the set
-- shown, the default one if not given). False when the build has no shared
-- gear.
function GearPanel.Show(guid, group, target, index)
    local guild = ns.Data.CurrentGuild(false)
    local build = ns.Data.BuildOf(guild and guild.members[guid], group)
    if not (build and build.q) then
        GearPanel.Hide()
        return false
    end
    Create()
    target = target or UIParent
    if target ~= UIParent and not hookedTargets[target] then
        hookedTargets[target] = true
        target:HookScript("OnHide", function()
            if GearPanel.current and GearPanel.current.target == target then
                GearPanel.Hide()
            end
        end)
    end
    GearPanel.current = { guid = guid, gr = group, index = index or 1, target = target }
    if target == PlayerSpellsFrame then
        ShiftTalentWindow(target)
    end
    Place(target)
    GearPanel.Refresh()
    panel:Show()
    if panel.Raise then
        panel:Raise()
    end
    FitTitle()
    return true
end

function GearPanel.Hide()
    GearPanel.current = nil
    if panel then
        panel:Hide()
    end
    RestoreTalentWindow()
end

function GearPanel.IsShowing(guid, group)
    local current = GearPanel.current
    return panel ~= nil and panel:IsShown() and current ~= nil and current.guid == guid and current.gr == group
end

-- Keeps the panel where it is on the screen, on its own: the window it sat
-- beside may close without it.
local function Detach()
    local left, top = ns.Try(panel.GetLeft, panel), ns.Try(panel.GetTop, panel)
    if ns.Number(left) and ns.Number(top) then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
    GearPanel.current.target = UIParent
end

-- The talents button: opens the build's talents in the game's window (the
-- gear moves beside it), or closes them (the gear stays where it is).
function GearPanel.ToggleTalents()
    local current = GearPanel.current
    if not current then
        return
    end
    if ns.Viewer.IsShowing(current.guid, current.gr) then
        Detach()
        RestoreTalentWindow()
        ns.Viewer.CloseTalents()
    elseif ns.Viewer.ShowTalents(current.guid, current.gr) then
        GearPanel.Show(current.guid, current.gr, PlayerSpellsFrame, current.index)
    end
end

-- After the talent window changes what it shows: the gear beside it goes
-- when the window no longer shows that member's build.
function GearPanel.Check()
    local current = GearPanel.current
    if current and current.target == PlayerSpellsFrame and not ns.Viewer.IsShowing(current.guid, current.gr) then
        GearPanel.Hide()
    end
end

function GearPanel.Init()
    ns.On("DataChanged", function()
        if panel and panel:IsShown() then
            GearPanel.Refresh()
        end
    end)
end
