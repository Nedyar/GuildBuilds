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
-- opens and closes its own target.
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
    frame:HookScript("OnShow", Viewer.UpdateGearButton)
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
    ns.On("DataChanged", Viewer.UpdateGearButton)
end
