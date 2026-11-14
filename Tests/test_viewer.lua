-- Opening builds in the game's talent window (Viewer.lua), from the roster's
-- icons.
local H = ...

local world = H.NewWorld({ seed = 13, communities = H.TalentsCommunities })
local hunter = world:NewClient("Hunter Name", {
    level = 42,
    talents = { active = 2, groups = { [1] = { [101] = 5, [102] = 3 }, [2] = { [301] = 5, [302] = 4 } } },
})
local mage = world:NewClient("Mage Name", { classID = 8, level = 16, talents = { active = 1, groups = { [1] = { [201] = 5 } } } })
local window = H.TalentWindow(mage)
mage.globals = window.globals
world:Login(hunter)
world:RunFor(20)
H.Share(hunter, 1, 2)
world:RunFor(5)
world:Login(mage)
world:RunFor(60)

local env = mage.env
local ns = mage.ns
local frame = window.frame
local list = env.CommunitiesFrame.MemberList
local function RowOf(guid)
    for _, row in ipairs(list.rows) do
        if row.memberInfo.guid == guid then
            row:RefreshExpandedColumns()
            return row
        end
    end
end
local function Click(button)
    button._scripts.OnClick(button, "LeftButton")
end
local record = ns.Data.CurrentGuild(false).members[hunter.guid]
-- In spec group order: Primary, then the Secondary one, which is active.
local other, active = unpack(ns.RosterColumn.ButtonsOf(RowOf(hunter.guid)))

H.section("Viewer: a member's build")
H.eq(#world.errors, 0, "no errors")
H.check(record ~= nil and record.s ~= nil and active ~= nil, "the mage has the hunter's builds in the roster")
Click(active)
H.eq(window.opened[1], ("0:42:%s"):format(ns.Data.BuildOf(record, 2).x), "the game's window gets the build and the member's level")
H.check(frame._shown, "and shows it")
H.eq(frame.title, "Talents of Hunter Name (Secondary)", "titled with the member's name and spec group")
frame:UpdateFrameTitle()
H.eq(frame.title, "Talents of Hunter Name (Secondary)", "the window's own title updates keep it")
H.check(ns.Viewer.IsShowing(hunter.guid, 2), "known to show it")

Click(other)
H.eq(window.opened[2], ("0:42:%s"):format(ns.Data.BuildOf(record, 1).x), "the other icon shows the other build")
H.check(frame._shown, "in the same window")
H.eq(frame.title, "Talents of Hunter Name (Primary)", "titled with its spec group")
Click(other)
H.check(not frame._shown, "clicking the icon of the build shown closes the window")
H.eq(#window.opened, 2, "without opening anything else")
frame:UpdateFrameTitle()
H.eq(frame.title, "Talents", "closed, the window's own title is left alone")

H.section("Viewer: the game's title words")
env.TALENTS_INSPECT_FORMAT = "Talents - %s"
Click(active)
H.eq(frame.title, "Talents - Hunter Name (Secondary)", "the game's own words when it has them")
env.TALENTS_INSPECT_FORMAT = "%s %s %d"
Click(active)
Click(active)
H.eq(frame.title, "Talents of Hunter Name (Secondary)", "ours when the game's do not fit")
env.TALENTS_INSPECT_FORMAT = nil
Click(active)

H.section("Viewer: our own builds")
local mine = ns.RosterColumn.ButtonsOf(RowOf(mage.guid))[1]
H.check(mine ~= nil and mine._shown, "our own row has an icon")
H.check(not frame._shown, "(the window is closed)")
local opened = #window.opened
Click(mine)
H.eq(window.own, 1, "it opens our own talents, as the game does")
H.eq(#window.opened, opened, "not as someone else's build")
H.check(frame._shown and not frame:IsInspecting(), "showing our talents")
Click(mine)
H.check(not frame._shown, "and closes them")

H.section("Viewer: in combat")
env.InCombatLockdown = function()
    return true
end
Click(active)
H.check(not frame._shown, "nothing opens in combat")
H.check(mage.printed[#mage.printed]:find("combat", 1, true) ~= nil, "and it says why")
env.InCombatLockdown = function()
    return false
end

H.section("Viewer: builds not shared")
hunter.ns.Talents.SetShared(1, false)
world:RunUntil(function()
    return ns.Data.CurrentGuild(false).members[hunter.guid].s[1].x == nil
end, 120)
local hunterRow = RowOf(hunter.guid)
local notShared, stillActive = unpack(ns.RosterColumn.ButtonsOf(hunterRow))
H.check(notShared._shown and notShared.spec.gr == 1, "the build taken back keeps its icon")
opened = #window.opened
Click(notShared)
H.check(not frame._shown and #window.opened == opened, "but clicking it opens nothing")
Click(stillActive)
H.check(frame._shown and #window.opened == opened + 1, "the build still shared opens")
Click(stillActive)

H.section("Viewer: the share box")
local talents = window.talents
local box = ns.ShareBox.box
H.check(box ~= nil and box._parent == talents, "a check box in the talent window's talents page")
Click(mine)
H.check(box._shown and not box:GetChecked(), "shown with our talents, unchecked: nothing shared yet")
H.eq(box.Label:GetText(), "Share talents", "saying what it does")
H.eq(box._point[2], talents.Background, "at the bottom left of the talents page")
box:SetChecked(true)
box._scripts.OnClick(box)
H.check(ns.Talents.IsShared(1), "ticking it shares the build shown")
H.check(ns.Data.GetOwnRecord(false).s[1].x ~= nil, "and our record carries it")
talents:SetTab(2)
H.check(not box._shown, "hidden on the Secondary tab without dual spec")
talents:SetTab(1)
H.check(box._shown and box:GetChecked(), "back on Primary, checked")
box:SetChecked(false)
box._scripts.OnClick(box)
H.check(not ns.Talents.IsShared(1) and ns.Data.GetOwnRecord(false).s[1].x == nil, "unticking it stops sharing")
Click(mine)
Click(active)
H.check(frame._shown and frame:IsInspecting() and not box._shown, "hidden while the window shows someone else's build")
Click(active)

H.section("Viewer: without the game's window")
env.PlayerSpellsUtil = nil
H.check(not ns.Viewer.Toggle(hunter.guid, 2), "a game without it opens nothing")
H.check(mage.printed[#mage.printed]:find("cannot show", 1, true) ~= nil, "and says so")
H.check(not ns.Viewer.Toggle("Player-1-000000FF", 1), "an unknown member opens nothing")
H.eq(#world.errors, 0, "no errors")
