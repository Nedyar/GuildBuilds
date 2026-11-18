-- Viewer.lua: shows a member's build: its talents in the game's talent
-- window, and its gear sets beside it (GearPanel.lua).
--
-- The window (PlayerSpellsFrame, Blizzard_PlayerSpells) shows a build from
-- its import string the way it shows a talent build link from the chat:
-- PlayerSpellsUtil.InspectLoadout gives it the string and the level, and it
-- draws that class's tree with the build's points. It needs neither the
-- member online nor nearby. The window's title then names the member. A
-- build whose talents are not shared but whose gear is shows only the gear,
-- beside the guild window.
--
-- While the window shows a member's build, a button left of its close
-- button opens or closes the build's gear (greyed when its owner does not
-- share it); the gear panel has the same button for the talents. Each only
-- opens and closes its own target. For a member with dual spec, tabs like
-- the window's own Primary and Secondary ones change between their builds.
--
-- Our own builds open the window as usual, where they can be changed.
local _, ns = ...
local L = ns.L

local Viewer = {}
ns.Viewer = Viewer

-- What the window shows for us: { guid, gr, x, title }, while it shows it.
Viewer.current = nil

local titleHooked = false
local GEAR_ICON = "Interface\\Icons\\INV_Chest_Chain_05"  -- when the build's set has no icon

local function Frame()
    return PlayerSpellsFrame
end

-- "Talents: Name (Primary)", with the game's own words when it has them.
local function TitleFor(name, record, group)
    local who = name
    if record.s and #record.s > 1 then
        who = ("%s (%s)"):format(name, ns.GroupLabel(group))
    end
    if type(TALENTS_INSPECT_FORMAT) == "string" then
        local ok, text = pcall(string.format, TALENTS_INSPECT_FORMAT, who)
        if ok then
            return text
        end
    end
    return L["Talents of %s"]:format(who)
end

-- True while the window shows the build we gave it.
function Viewer.IsShowing(guid, group)
    local frame, current = Frame(), Viewer.current
    if not (frame and current and frame:IsShown()) then
        return false
    end
    if guid and (current.guid ~= guid or current.gr ~= group) then
        return false
    end
    local inspecting = ns.Try(frame.IsInspecting, frame)
    local unit = ns.Try(frame.GetInspectUnit, frame)
    local text = ns.Try(frame.GetInspectString, frame)
    return inspecting == true and unit == nil and text == current.x
end

function Viewer.UpdateTitle()
    local frame = Frame()
    if frame and Viewer.IsShowing() and frame.SetTitle then
        frame:SetTitle(Viewer.current.title)
    end
    Viewer.UpdateGearButton()
    Viewer.UpdateGroupTabs()
    ns.GearPanel.Check()
end

-- The build the window shows for us, and its record, or nil.
local function BuildShown()
    local current = Viewer.IsShowing() and Viewer.current
    if not current then
        return nil
    end
    local guild = ns.Data.CurrentGuild(false)
    local record = guild and guild.members[current.guid]
    return ns.Data.BuildOf(record, current.gr), record
end

-- The gear of the build the window shows (Data.GearOf): empty without one.
local function GearShown()
    local build, record = BuildShown()
    return build and ns.Data.GearOf(record, build.gr) or {}
end

-- The gear button, on the window while it shows a member's build: it opens
-- or closes the build's gear beside it, when its owner shares it.
local gearButton

function Viewer.UpdateGearButton()
    if not gearButton then
        return
    end
    local build = BuildShown()
    gearButton:SetShown(build ~= nil)
    if build then
        local gear = GearShown()
        local set = gear[1]
        ns.TitleButton.Set(gearButton, set and not set.worn and set.i > 0 and set.i or GEAR_ICON, #gear > 0)
    end
end

-- Opens or closes the gear of the build the window shows, beside it.
function Viewer.ToggleGear()
    if #GearShown() == 0 then
        return
    end
    local current = Viewer.current
    if ns.GearPanel.IsShowing(current.guid, current.gr) then
        ns.GearPanel.Hide()
    else
        ns.GearPanel.Show(current.guid, current.gr, Frame())
    end
end

-- The spec group tabs: while the window shows the build of a member with
-- two spec groups, tabs like its own Primary and Secondary ones (which the
-- game hides while it shows someone else's talents) change between the
-- member's two builds. The tab of a build whose talents are not shared is
-- locked and says so; the member's active one is ticked, as ours is.
local groupTabs
local TAB_TEMPLATE = "ClassTalentsFrameTabTemplate"  -- the window's own tabs
local TAB_LEVEL = 4010                               -- over the talents page's effects (HIGH, 4000)

function Viewer.UpdateGroupTabs()
    if not groupTabs then
        return
    end
    local build, record = BuildShown()
    local shown = build ~= nil and type(record.s) == "table" and #record.s > 1
    groupTabs:SetShown(shown)
    if not shown then
        return
    end
    -- The texts first, with no tab selected: the game's tabs read the
    -- selected one as locked.
    groupTabs:SetTabVisuallySelected(nil)
    for group = 1, 2 do
        local other = ns.Data.BuildOf(record, group)
        local shared = other ~= nil and other.x ~= nil
        groupTabs:SetTabEnabled(group, shared, not shared and L["Its talents are not shared."] or nil)
        local tab = groupTabs:GetTabButton(group)
        if tab and tab.SetIsActive then
            tab:SetIsActive(record.ag == group)
        end
    end
    groupTabs:SetTabVisuallySelected(build.gr)
end

-- A click on a spec group tab: the member's build of that spec group, and
-- its gear beside it if the gear of the build shown was there. Selecting
-- the tab is left to UpdateGroupTabs, once the window shows the build.
local function OnGroupTab(group)
    local current = Viewer.IsShowing() and Viewer.current
    ns.Debug("spec group tab %s clicked; showing %s", tostring(group), current and tostring(current.gr) or "no build of ours")
    if not current or group == current.gr then
        return true
    end
    local guid = current.guid
    local gearShown = ns.GearPanel.IsShowing(guid, current.gr)
    if not Viewer.ShowTalents(guid, group) then
        return true
    end
    if gearShown then
        local guild = ns.Data.CurrentGuild(false)
        if #ns.Data.GearOf(guild and guild.members[guid], group) > 0 then
            ns.GearPanel.Show(guid, group, Frame())
        else
            ns.GearPanel.Hide()
        end
    end
    return true
end

-- The tabs, where the window has its own (ClassTalentsFrameTemplate's
-- TabSystem), as its own are made.
local function CreateGroupTabs(frame)
    local talents = frame.TalentsFrame
    if groupTabs or not talents then
        return
    end
    groupTabs = CreateFrame("Frame", nil, talents, "TabSystemTemplate")
    groupTabs.tabTemplate = TAB_TEMPLATE
    groupTabs.minTabWidth, groupTabs.maxTabWidth = 150, 200
    groupTabs.tabPool = CreateFramePool("BUTTON", groupTabs, TAB_TEMPLATE)
    -- Above the talents page's own frames over that spot, which take the
    -- mouse while it shows someone else's build (seen in game): the frame
    -- of the talent buttons (raised over 1010) and its effects (HIGH, 4000).
    -- Set before the tabs are made, so they are made there too.
    groupTabs:SetFrameStrata("HIGH")
    groupTabs:SetFrameLevel(TAB_LEVEL)
    groupTabs:SetPoint("BOTTOMLEFT", talents.BackgroundBorder or talents, "TOPLEFT", 70, -4)
    groupTabs:SetTabSelectedCallback(OnGroupTab)
    groupTabs:AddTab(ns.GroupLabel(1))
    groupTabs:AddTab(ns.GroupLabel(2))
    groupTabs:Hide()
    Viewer.groupTabs = groupTabs
end

local function UpdateButtons()
    Viewer.UpdateGearButton()
    Viewer.UpdateGroupTabs()
end

local function GearTooltip()
    GameTooltip:SetText(L["Gear"], 1, 1, 1)
    if #GearShown() > 0 then
        GameTooltip:AddLine(L["Show or hide the gear of these talents beside them."], nil, nil, nil, true)
    else
        GameTooltip:AddLine(L["Its gear is not shared."], 0.7, 0.7, 0.7)
    end
end

-- The window updates its title on its own (opening, changing tabs); ours
-- goes on top while it shows our build. The gear button goes on it too.
local function HookTitle()
    local frame = Frame()
    if titleHooked or not frame or type(frame.UpdateFrameTitle) ~= "function" then
        return
    end
    titleHooked = true
    hooksecurefunc(frame, "UpdateFrameTitle", Viewer.UpdateTitle)
    gearButton = ns.TitleButton.New(frame, frame.CloseButton, Viewer.ToggleGear, GearTooltip)
    gearButton:Hide()
    Viewer.gearButton = gearButton
    CreateGroupTabs(frame)
    frame:HookScript("OnShow", UpdateButtons)
end

local function Close()
    local frame = Frame()
    if frame and frame:IsShown() then
        HideUIPanel(frame)
    end
end

-- Our own talents, in the window as the game opens them.
local function ToggleOwn()
    local frame = Frame()
    if frame and frame:IsShown() and ns.Try(frame.IsInspecting, frame) ~= true then
        Close()
        return
    end
    Viewer.current = nil
    if PlayerSpellsUtil and PlayerSpellsUtil.OpenToClassTalentsTab then
        PlayerSpellsUtil.OpenToClassTalentsTab()
    end
end

-- Shows a member's talents of a spec group in the window, when shared.
function Viewer.ShowTalents(guid, group)
    if InCombatLockdown() then
        ns.Print(L["the talent window cannot be opened in combat."])
        return false
    end
    local guild = ns.Data.CurrentGuild(false)
    local record = guild and guild.members[guid]
    local build = ns.Data.BuildOf(record, group)
    if not (build and build.x) then
        -- Unknown, or not shared by its owner.
        ns.Debug("talents %s of %s unknown or not shared", tostring(group), tostring(guid))
        return false
    end
    if not (PlayerSpellsUtil and PlayerSpellsUtil.InspectLoadout) then
        ns.Print(L["this version of the game cannot show other builds."])
        return false
    end
    Viewer.current = {
        guid = guid, gr = group, x = build.x,
        title = TitleFor(ns.Data.NameOf(guid, record), record, group),
    }
    HookTitle()
    -- The level sets which talents the build could have; the first field
    -- (a spec) is not read: the string has its own.
    local ok, err = pcall(PlayerSpellsUtil.InspectLoadout, ("0:%d:%s"):format(record.lv or 1, build.x))
    if not ok then
        Viewer.current = nil
        ns.Debug("InspectLoadout failed: %s", tostring(err))
        return false
    end
    Viewer.UpdateTitle()
    return true
end

-- Closes the window.
function Viewer.CloseTalents()
    Close()
end

-- From the roster: opens a member's build of a spec group (its talents, its
-- gear beside them), or closes it if it shows already.
function Viewer.Toggle(guid, group)
    if InCombatLockdown() then
        ns.Print(L["the talent window cannot be opened in combat."])
        return false
    end
    if guid == ns.playerGUID then
        ToggleOwn()
        return true
    end
    if Viewer.IsShowing(guid, group) then
        -- The gear beside it closes with it.
        Close()
        return true
    end
    if ns.GearPanel.IsShowing(guid, group) then
        ns.GearPanel.Hide()
        return true
    end
    local guild = ns.Data.CurrentGuild(false)
    local record = guild and guild.members[guid]
    local build = ns.Data.BuildOf(record, group)
    local hasGear = #ns.Data.GearOf(record, group) > 0
    if build and not build.x and hasGear then
        -- Only its gear is shared: beside the guild window, without someone
        -- else's talents left open.
        if Viewer.IsShowing() then
            Close()
        end
        return ns.GearPanel.Show(guid, group, CommunitiesFrame)
    end
    if not Viewer.ShowTalents(guid, group) then
        return false
    end
    if hasGear then
        ns.GearPanel.Show(guid, group, Frame())
    else
        ns.GearPanel.Hide()
    end
    return true
end

function Viewer.Init()
    -- Hooked as soon as the window exists, in case the game opens it first.
    EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", HookTitle)
    -- A member may share or stop sharing while the window shows them.
    ns.On("DataChanged", UpdateButtons)
end
