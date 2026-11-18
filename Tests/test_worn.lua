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
H.eq(Own().il, 500, "and their item level, in hundredths, as the addon shows it: helm and bow over 17")
H.eq(Own().un, 4, "the points not spent yet")
local copy = WaitForCopy()
H.check(copy ~= nil and ns.Same(copy.w, Own().w) and copy.il == 500 and copy.un == 4, "all of it reaches the guild")

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
H.eq(#mns.Data.GearOf(copy, 2), 1, "with the talents not in use too")
H.check(mns.GearPanel.Show(hunter.guid, 1, mage.env.UIParent), "the gear panel shows it")
local panel = mns.GearPanel.panel
H.check(panel.SetName._shown and panel.SetName:GetText() == "Equipped", "as Equipped")
H.check(panel.ItemLevel._shown and panel.ItemLevel:GetText() == "Item level 5.0", "with its item level under its icon")
H.eq(mns.GearPanel.buttons[1].item, "item:16939:0:0:0:0:0:0::::0", "and the items worn")
mns.GearPanel.Hide()

H.section("Worn: one of the sets")
-- Raid is what the hunter wears (the helm and the bow); Helm only is not.
hunter.sets[0] = { name = "Raid", icon = 132222, items = { [1] = 16939, [18] = 2504 },
    locations = { [1] = H.WORN + 1, [18] = H.WORN + 18 } }
hunter.sets[1] = { name = "Helm only", icon = 133070, items = { [1] = 16939 }, locations = { [1] = H.WORN + 1 } }
ns.Sets.Assign(1, 0, true)
ns.Sets.Assign(1, 1, true)
copy = WaitForCopy()
gear = mns.Data.GearOf(copy, 1)
H.check(#gear == 2 and gear[1].equipped and not gear[2].equipped, "the set worn is marked, and Equipped is not added")
H.check(copy.s[1].q[1].equipped == nil, "on a copy: the record is left as it is")
mns.GearPanel.Show(hunter.guid, 1, mage.env.UIParent)
local menu = H.MenuOf(panel.SetMenu)
H.check(#menu == 2 and menu[1].text == "Raid (equipped)" and menu[2].text == "Helm only",
    "in the menu, the set worn says so")
ns.Sets.SetDefault(1, 1)
copy = WaitForCopy()
mns.GearPanel.Show(hunter.guid, 1, mage.env.UIParent)
menu = H.MenuOf(panel.SetMenu)
H.check(menu[1].text == "Helm only" and menu[2].text == "Raid (equipped)", "also when it is not the default")
ns.Sets.Assign(1, 1, false)
copy = WaitForCopy()
mns.GearPanel.Show(hunter.guid, 1, mage.env.UIParent)
H.check(not panel.SetMenu._shown and panel.SetName:GetText() == "Raid (equipped)", "alone, by its name")
ns.Sets.Assign(1, 0, false)
ns.Sets.Assign(1, 1, true)
copy = WaitForCopy()
mns.GearPanel.Show(hunter.guid, 1, mage.env.UIParent)
menu = H.MenuOf(panel.SetMenu)
H.check(#menu == 2 and menu[1].text == "Helm only" and menu[2].text == "Equipped",
    "a set not worn leaves Equipped in the menu")
mns.GearPanel.Hide()
ns.Sets.Assign(1, 1, false)

H.section("Worn: slots a set leaves as they are")
-- Leave: a chest piece not found, and the head, the shoulders and the ranged
-- slot left as they are; the hunter wears the helm and the bow there.
hunter.sets[2] = { name = "Leave", icon = 132222, items = { [5] = 6000, [1] = 1, [3] = 1, [18] = 1 },
    locations = { [5] = -1 }, ignored = { [1] = true, [3] = true, [18] = true } }
ns.Sets.Assign(1, 2, true)
copy = WaitForCopy()
mns.GearPanel.Show(hunter.guid, 1, mage.env.UIParent)
local slots = mns.GearPanel.buttons
local MARK = "Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent"
H.eq(slots[1].item, "item:16939:0:0:0:0:0:0::::0", "a slot left as it is shows what the member wears there")
H.check(slots[1].Icon._shown and slots[1].Ignored._shown and slots[1].Ignored._texture == MARK, "with the game's mark over it")
H.check(slots[1].Ignored._alpha == 0.5 and slots[1].Ignored._point[1] == "CENTER", "see-through, over the whole slot")
H.check(slots[18].item ~= nil and slots[18].Ignored._shown and slots[18].Ignored._alpha == 0.5
    and slots[18].Ignored._point[1] == "CENTER", "on a weapon too")
H.check(slots[3].item == nil and slots[3].Ignored._shown and slots[3].Ignored._alpha == 1
    and slots[3].Ignored._point[1] == "CENTER", "nothing worn there: the mark alone, as the game shows it")
H.check(slots[5].item == "item:6000" and not slots[5].Ignored._shown, "the set's own items as ever")
slots[1]._scripts.OnEnter(slots[1])
local tipLines = mage.env.GameTooltip._lines
H.check(tipLines[1] == slots[1].item and tipLines[#tipLines] == "This set leaves this slot as it is.",
    "its tooltip: the item worn, and that the set leaves it on")
slots[3]._scripts.OnEnter(slots[3])
H.eq(mage.env.GameTooltip._lines[1], "This set leaves this slot as it is.", "an empty one says only that")
mns.GearPanel.Hide()
ns.Sets.Assign(1, 2, false)
hunter.sets[2] = nil

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

H.section("Worn: the settings of 0.4")
local older = world:NewClient("Older Name", {
    talents = { active = 1, groups = { [1] = { [101] = 5 } } },
    gear = { [1] = { link = HELM, il = 76 } },
})
-- Its saved data: the gear of both spec groups unticked, one box each.
older.saved = { GuildBuildsDB = { own = { [older.guid] = { gearHidden = { [1] = true, [2] = true } } } } }
world:Login(older)
world:RunFor(5)
H.check(older.ns.Sets.IsShared(1) and older.ns.Sets.IsShared(2) and older.ns.Data.OwnState().gearReset == 1,
    "ticked again at login, both")
H.check(older.ns.Data.GetOwnRecord(false).w ~= nil, "what is worn too")
H.eq(#world.errors, 0, "no errors")

H.section("Worn: packed")
local Pack = ns.Pack
local writer = Pack.Writer()
Pack.WriteRecord(writer, hunter.guid, Own())
local guid, read = Pack.ReadRecord(Pack.Reader(writer:Result()))
H.eq(guid, hunter.guid, "the GUID")
H.check(ns.Same(read.w, Own().w) and read.il == 500 and read.un == 4, "the items worn, the item level and the unspent points")
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
