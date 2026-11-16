-- What the player wears (Equipped.lua) and the points not spent yet:
-- shared with the guild while the active build's gear is.
local H = ...

local HELM = "|cffa335ee|Hitem:16939:0:0:0:0:0:0:1234567:60:0:0|h[Helm]|h|r"
local BOW = "|cff1eff00|Hitem:2504:0:0:0:0:0:0:7654321:60:0:0|h[Worn Shortbow]|h|r"
local world = H.NewWorld({ seed = 23 })
local hunter = world:NewClient("Hunter Name", {
    talents = { active = 1, groups = { [1] = { [101] = 5, [102] = 3 }, [2] = { [301] = 5 } }, unspent = 4 },
    gear = { [1] = { link = HELM, il = 76 }, [18] = { link = BOW, il = 9 } },
    itemLevel = 60.5,
})
local mage = world:NewClient("Mage Name", { classID = 8, talents = { active = 1, groups = { [1] = { [201] = 5 } } } })
world:Login(hunter)
world:RunFor(20)
world:Login(mage)
world:RunFor(60)

local ns = hunter.ns
local function Own()
    return ns.Data.GetOwnRecord(false)
end
local function Copy()
    return mage.ns.Data.CurrentGuild(false).members[hunter.guid]
end
local function WaitForCopy()
    world:RunUntil(function()
        local copy = Copy()
        return copy ~= nil and copy.t == Own().t
    end, 180)
    return Copy()
end
local function Switch(group)
    hunter.talents.active = group
    world:FireEvent(hunter, "ACTIVE_TALENT_GROUP_CHANGED")
    world:RunFor(3)
end

H.section("Worn: shared with the active build's gear")
H.eq(#world.errors, 0, "no errors")
local worn = Own().w
H.check(worn ~= nil and #worn == 2, "the items worn, while the gear is shared (by default)")
H.check(worn and worn[1].s == 1 and worn[2].s == 18, "by slot")
H.eq(worn and worn[1].i, "item:16939:0:0:0:0:0:0::::0", "as item strings, without the fields that change on their own")
H.check(worn and worn[1].il == 76 and worn[2].il == 9, "with their item levels")
H.eq(Own().il, 6050, "and the average item level, in hundredths")
H.eq(Own().un, 4, "the points not spent yet")
local copy = WaitForCopy()
H.check(copy ~= nil and ns.Same(copy.w, Own().w) and copy.il == 6050 and copy.un == 4, "all of it reaches the guild")

H.section("Worn: changes")
hunter.gear[18] = nil
world:FireEvent(hunter, "PLAYER_EQUIPMENT_CHANGED", 18)
world:RunFor(3)
H.eq(#Own().w, 1, "an item taken off goes")
copy = WaitForCopy()
H.eq(#copy.w, 1, "from the guild's copies too")
hunter.gear[18] = { link = BOW, il = 9 }
world:FireEvent(hunter, "PLAYER_EQUIPMENT_CHANGED", 18)
world:RunFor(3)
H.eq(#Own().w, 2, "and comes back when worn again")

H.section("Worn: in the gear panel")
copy = WaitForCopy()
local mns = mage.ns
local gear = mns.Data.GearOf(copy, 1)
H.check(#gear == 1 and gear[1].worn and #gear[1].it == 2, "a build without sets still has gear: what its owner wears")
H.eq(#mns.Data.GearOf(copy, 2), 0, "only with the talents in use")
H.check(mns.GearPanel.Show(hunter.guid, 1, mage.env.UIParent), "the gear panel shows it")
local panel = mns.GearPanel.panel
H.check(panel.SetName._shown and panel.SetName:GetText() == "Equipped (item level 60.5)", "as Equipped, with the item level")
H.eq(mns.GearPanel.buttons[1].item, "item:16939:0:0:0:0:0:0::::0", "and the items worn")
mns.GearPanel.Hide()

H.section("Worn: not shared")
ns.Sets.SetShared(2, false)
world:RunFor(3)
H.eq(#Own().w, 2, "the other spec group's box does not matter")
ns.Sets.SetShared(1, false)
world:RunFor(3)
H.check(Own().w == nil and Own().il == nil, "the active one's does")
copy = WaitForCopy()
H.check(copy.w == nil and copy.il == nil, "and the guild's copies lose it")
H.eq(copy.un, 4, "the unspent points stay, with the talents")
Switch(2)
H.eq(Own().w, nil, "nor with the other talents, their gear not shared either")
ns.Sets.SetShared(2, true)
world:RunFor(3)
H.check(Own().w ~= nil and #Own().w == 2, "shared again with the talents in use")
Switch(1)
H.eq(Own().w, nil, "and gone again with the Primary ones")
ns.Sets.SetShared(1, true)
world:RunFor(3)
H.check(Own().w ~= nil, "back")
H.eq(#world.errors, 0, "no errors")

H.section("Worn: packed")
local Pack = ns.Pack
local writer = Pack.Writer()
Pack.WriteRecord(writer, hunter.guid, Own())
local guid, read = Pack.ReadRecord(Pack.Reader(writer:Result()))
H.eq(guid, hunter.guid, "the GUID")
H.check(ns.Same(read.w, Own().w) and read.il == 6050 and read.un == 4, "the items worn, the item level and the unspent points")
local clean = ns.Data.CleanRecord(read, ns.Now())
H.check(clean ~= nil and ns.Same(clean.w, Own().w), "and they pass the checks")
local bare = { n = "Someone", t = ns.Now() - 10, av = 200, lv = 10, tr = 1, ag = 1, tb = { { g = 1 } }, s = { { gr = 1, p = { 0 } } } }
writer = Pack.Writer()
Pack.WriteRecord(writer, hunter.guid, bare)
_, read = Pack.ReadRecord(Pack.Reader(writer:Result()))
H.check(read.w == nil and read.il == nil and read.un == nil, "nothing worn, no item level and no unspent points when unknown")
local bad = { n = "Someone", t = ns.Now() - 10, av = 200, w = { { s = 0, i = "item:1", il = 1 } } }
H.eq(ns.Data.CleanRecord(bad, ns.Now()), nil, "no ammo slot")
bad.w = { { s = 1, i = "item:1" }, { s = 1, i = "item:2" } }
H.eq(ns.Data.CleanRecord(bad, ns.Now()), nil, "nor two items in one slot")
bad.w = { { s = 1, i = "|Hitem:1|h" } }
H.eq(ns.Data.CleanRecord(bad, ns.Now()), nil, "nor links")
bad.w = { { s = 1, i = "item:1", il = 10000 } }
H.eq(ns.Data.CleanRecord(bad, ns.Now()), nil, "nor impossible item levels")
bad.w = {}
H.check(ns.Data.CleanRecord(bad, ns.Now()) ~= nil, "nothing worn at all is fine")
