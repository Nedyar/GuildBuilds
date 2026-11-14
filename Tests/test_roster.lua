-- The specialization icons in the guild roster (RosterColumn.lua).
local H = ...

local world = H.NewWorld({ seed = 11, communities = H.TalentsCommunities })
local hunter = world:NewClient("Hunter Name", {
    level = 42,
    talents = { active = 2, groups = { [1] = { [101] = 5, [102] = 3 }, [2] = { [301] = 5, [302] = 4 } } },
})
local mage = world:NewClient("Mage Name", { classID = 8, talents = { active = 1, groups = { [1] = { [201] = 5 } } } })
local _, outsiderGUID = world:AddMember("Outsider Name", nil, { class = "ROGUE" })
world:Login(mage)
world:RunFor(20)
world:Login(hunter)
world:RunFor(20)
-- The hunter shares the active build (Secondary) and keeps the other one.
H.Share(hunter, 2)
world:RunFor(60)

local env = mage.env
local ns = mage.ns
local list = env.CommunitiesFrame.MemberList
local SHIFT = ns.RosterColumn.SHIFT

local function RowOf(guid)
    for _, row in ipairs(list.rows) do
        if row.memberInfo.guid == guid then
            return row
        end
    end
end

H.section("Roster: icons")
H.eq(#world.errors, 0, "no errors")
local hunterRow, mageRow, outsiderRow = RowOf(hunter.guid), RowOf(mage.guid), RowOf(outsiderGUID)
H.check(hunterRow and mageRow and outsiderRow, "every member has a row")
local record = ns.Data.CurrentGuild(false).members[hunter.guid]
H.check(record ~= nil and record.s ~= nil, "the mage knows the hunter's builds")
for _, row in ipairs(list.rows) do
    row:RefreshExpandedColumns()
end

local hunterButtons = ns.RosterColumn.ButtonsOf(hunterRow)
H.eq(#hunterButtons, 2, "two spec icons for a member with dual spec")
local first, second = hunterButtons[1], hunterButtons[2]
H.check(first._shown and second._shown, "both shown")
H.eq(first.spec.gr, 1, "the Primary spec group first")
H.eq(second.spec.gr, 2, "then the Secondary one, although it is the active one")
H.eq(first.Icon._texture, 1, "the first's icon is its main tree's (the first)")
H.eq(second.Icon._texture, 3, "the second's is the third tree's")
H.eq(second.Icon:GetAlpha(), 1, "the active one is bright")
H.check(first.Icon:GetAlpha() < 1, "the other one is dimmed")
H.check(first._point[1] == "LEFT" and first._point[2] == hunterRow.Class and first._point[3] == "RIGHT", "right after the class icon")
H.check(second._point[2] == hunterRow.Class and second._point[4] > first._point[4], "the second one after the first")
local classPoint = hunterRow.Class._point
H.check(classPoint[1] == "LEFT" and classPoint[2] == hunterRow.Level and classPoint[3] == "RIGHT" and classPoint[4] == -1,
    "the class icon moves 9 px left of Blizzard's place (8 after the Level column)")
-- Blizzard's class icon is 15 px in from the Class header's left edge;
-- moved 9 px left, it leaves 6 px, as the Professions column does.
H.eq(15 - 9 + 16 + second._point[4] + 16 + 6, ns.RosterColumn.WIDTH, "the icons fill the Class column with 6 px margins")
H.eq(ns.RosterColumn.WIDTH, 64, "a column of 64 px")

local mageButtons = ns.RosterColumn.ButtonsOf(mageRow)
H.check(mageButtons[1]._shown and not mageButtons[2]._shown, "one icon without dual spec")
H.eq(mageButtons[1].spec.gr, 1, "of its only build")
local outsiderButtons = ns.RosterColumn.ButtonsOf(outsiderRow)
H.check(#outsiderButtons == 0 or (not outsiderButtons[1]._shown and not outsiderButtons[2]._shown), "no icons for a member without the addon")

H.section("Roster: room for the icons")
local point = hunterRow.NameFrame._point
-- Blizzard's name is 18 px after the class icon; the icon moved 9 px left.
H.check(point[1] == "LEFT" and point[2] == hunterRow.Class and point[4] == 18 + 9 + SHIFT, "the name moves right by what the column gains")
-- The class icon starts 6 px into the column, so the column ends WIDTH - 6
-- - 16 px after the icon's right edge.
H.eq(point[4], ns.RosterColumn.WIDTH - 6 - 16 + 4, "4 px after the column's right edge, as Blizzard's")
outsiderRow:UpdateNameFrame()
H.eq(outsiderRow.NameFrame._point[4], 18 + 9 + SHIFT, "also for members without the addon, so the column lines up")
H.eq(outsiderRow.Class._point[4], -1, "their class icon moves too")
list:RefreshLayout()
H.eq(list.headers[2]._width, 45 + SHIFT, "the Class header is wider by the same room")
list:RefreshLayout()
H.eq(list.headers[2]._width, 45 + SHIFT, "laid out again, it does not grow twice")
H.eq(list.headers[6]._width, nil, "the Note header is left to Blizzard (it stretches)")
hunterRow.guildColumnIndex = 1
hunterRow:RefreshExpandedColumns()
H.eq(hunterRow.Note._width, 93 - SHIFT, "beside an extra column, the Note column gives up the room")

H.section("Roster: tooltip")
second._scripts.OnEnter(second)
local lines = env.GameTooltip._lines
H.eq(lines[1], "Survival", "the main tree's name")
H.eq(lines[2], "0 / 0 / 9", "the points in each tree")
H.check(lines[3] and lines[3]:find("active", 1, true) ~= nil, "which spec group, and that it is the active one")
H.eq(lines[4], "Click to see the talents.", "what a click does")
H.check(lines[5] and lines[5]:find("^Updated") ~= nil, "when it was updated")
first._scripts.OnEnter(first)
lines = env.GameTooltip._lines
H.eq(lines[1], "Beast Mastery", "a build not shared still shows its main tree")
H.eq(lines[2], "8 / 0 / 0", "and its points")
H.eq(lines[3], "Primary", "and its spec group")
H.eq(lines[4], "Its talents are not shared.", "but says its talents are not shared")
H.eq(first.Icon._texture, 1, "its icon shows too")
mageButtons[1]._scripts.OnEnter(mageButtons[1])
lines = env.GameTooltip._lines
H.eq(lines[3], "Click to see the talents.", "our own icon opens our talents, no spec group line without dual spec")
H.check(lines[4] and lines[4]:find("tick the box", 1, true) ~= nil, "and tells us where to share it from")
H.check(lines[5] and lines[5]:find("^Updated") ~= nil, "then when it was updated")

H.section("Roster: other rows")
local invitation = outsiderRow
invitation.isInvitation = true
invitation:RefreshExpandedColumns()
H.check(#ns.RosterColumn.ButtonsOf(invitation) == 0 or not ns.RosterColumn.ButtonsOf(invitation)[1]._shown, "no icons on an invitation")
H.eq(invitation.Class._point[4], 8, "its class icon back in Blizzard's place (rows are reused for other communities)")
invitation.isInvitation = false
invitation:RefreshExpandedColumns()
H.eq(invitation.Class._point[4], -1, "and in ours again for a member")
hunterRow.Class:Hide()
hunterRow:RefreshExpandedColumns()
H.check(not first._shown and not second._shown, "no icons where Blizzard shows no class")
hunterRow.Class:Show()
hunterRow:RefreshExpandedColumns()
H.check(first._shown and second._shown, "back with the class")
H.eq(#world.errors, 0, "no errors")
