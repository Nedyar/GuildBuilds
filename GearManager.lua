-- GearManager.lua: the spec groups in the game's Equipment Manager (the
-- gear sets in the character window).
--
-- Each set's settings button (the gear that shows over it) opens a menu
-- with the game's "Change Name/Icon"; below it go the spec groups: give the
-- set to the Primary or Secondary talents, and make it their default. A set
-- given to talents shows their main tree's icon in the ring where retail
-- shows a specialization's. The same settings are in the talent window
-- (ShareBox.lua): both read and change Sets.lua's lists.
local _, ns = ...
local L = ns.L

local GearManager = {}
ns.GearManager = GearManager

local MENU_TAG = "MENU_PAPERDOLL_FRAME"  -- the tag of the settings menu (PaperDollFrame.lua)
local QUESTION_MARK = 134400

-- The set whose settings button opened the menu: it opens on the press,
-- under the mouse, and the set's button is the settings button's parent.
local function SetUnderMouse()
    local frame
    if GetMouseFoci then
        local foci = ns.Try(GetMouseFoci)
        frame = type(foci) == "table" and foci[1]
    elseif GetMouseFocus then
        frame = ns.Try(GetMouseFocus)
    end
    for _ = 1, 3 do
        if type(frame) ~= "table" then
            return nil
        end
        local id = ns.Number(frame.setID)
        if id then
            return id
        end
        frame = frame.GetParent and ns.Try(frame.GetParent, frame)
    end
end

-- The entries added to the settings menu of a set.
function GearManager.AddEntries(_, root)
    local id = SetUnderMouse()
    if id == nil or not ns.Talents.ConfigFor(1) then
        return
    end
    root:CreateDivider()
    root:CreateTitle(ns.TITLE)
    for group = 1, 2 do
        if ns.Talents.ConfigFor(group) then
            local label = ns.GroupLabel(group)
            root:CreateCheckbox(L["Use with the %s talents"]:format(label), function()
                return ns.Sets.IsAssigned(group, id)
            end, function()
                ns.Sets.Assign(group, id, not ns.Sets.IsAssigned(group, id))
            end)
            if ns.Sets.IsAssigned(group, id) and #ns.Sets.Of(group) > 1 then
                root:CreateCheckbox(L["Default gear set of the %s talents"]:format(label), function()
                    return ns.Sets.Default(group) == id
                end, function()
                    ns.Sets.SetDefault(group, id)
                end)
            end
        end
    end
end

-- The main tree's icon of one of our builds, or nil.
local function MainIcon(group)
    local record = ns.Data.GetOwnRecord(false)
    local spec = ns.Data.BuildOf(record, group)
    local main = spec and ns.Data.MainTab(spec)
    local tab = main and record.tb[main]
    return tab and tab.i > 0 and tab.i or nil
end

-- The spec group a set shows: the active one if it has the set.
local function GroupOf(id)
    local active = ns.Talents.ActiveGroup()
    if ns.Sets.IsAssigned(active, id) then
        return active
    end
    for group = 1, 2 do
        if ns.Sets.IsAssigned(group, id) then
            return group
        end
    end
end

-- Runs after the game draws a set's specialization ring.
function GearManager.UpdateButton(button)
    if not (button and button.SpecIcon and button.SpecRing) then
        return
    end
    local group = button.setID ~= nil and GroupOf(button.setID)
    if group then
        button.SpecIcon:SetTexture(MainIcon(group) or QUESTION_MARK)
        button.SpecIcon:Show()
        button.SpecRing:Show()
    elseif not button.specID then
        -- The game's own ring stays, if the game ever shows one.
        button.SpecIcon:Hide()
        button.SpecRing:Hide()
    end
end

function GearManager.Refresh()
    local pane = PaperDollFrame and PaperDollFrame.EquipmentManagerPane
    if pane and pane.ScrollBox and pane:IsVisible() then
        pane.ScrollBox:ForEachFrame(GearManager.UpdateButton)
    end
end

function GearManager.Init()
    if Menu and Menu.ModifyMenu then
        Menu.ModifyMenu(MENU_TAG, GearManager.AddEntries)
    end
    if type(GearSetButton_UpdateSpecInfo) == "function" then
        hooksecurefunc("GearSetButton_UpdateSpecInfo", GearManager.UpdateButton)
    end
    ns.On("SetsChanged", GearManager.Refresh)
    ns.On("OwnChanged", GearManager.Refresh)
end
