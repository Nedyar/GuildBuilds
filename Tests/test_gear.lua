-- Gear sets (Sets.lua): giving them to spec groups, sharing them with the
-- builds, equipping them when switching talents, and where the player and
-- the guild see them: the talent window (ShareBox.lua), the Equipment
-- Manager (GearManager.lua), and the panel beside a member's talents
-- (GearPanel.lua).
local H = ...

local BOW = "|cff1eff00|Hitem:2504:0:0:0:0:0:0:1234567:42:0:0|h[Worn Shortbow]|h|r"
local HAMMER = "|cffffffff|Hitem:2361::::::::42:::::|h[Battleworn Hammer]|h|r"
local world = H.NewWorld({ seed = 17, communities = H.TalentsCommunities })
local hunter = world:NewClient("Hunter Name", {
    level = 42,
    talents = { active = 1, groups = { [1] = { [101] = 5, [102] = 3 }, [2] = { [301] = 5, [302] = 4 } } },
    gear = { [18] = { link = BOW } },
    containers = { [0] = { size = 16, [3] = { 2361, 1, HAMMER } } },
})
-- Adventurer: a bow worn, a hammer in the bags, a chest piece not found,
-- the head left as it is (1), the neck empty (0) and arrows in the ammo slot.
hunter.sets = {
    [0] = { name = "Adventurer", icon = 132164, items = { [0] = 2512, [18] = 2504, [16] = 2361, [5] = 6000, [1] = 1, [2] = 0 },
        locations = { [18] = H.WORN + 18, [16] = H.InBag(0, 3), [5] = -1 } },
    [1] = { name = "Fishing", icon = 136245, items = { [16] = 6256 }, locations = { [16] = H.InBag(0, 9) } },
    [2] = { name = "PvP", icon = 132222, items = { [1] = 7000, [3] = 7001 }, locations = {}, ignored = { [3] = true } },
}
-- The levels of the set's items: the bow (worn), the hammer (in the bags)
-- and the chest piece the client knows though it is not found.
hunter.itemLevels = { [2504] = 14, [2361] = 21, [6000] = 30 }
local hunterWindow = H.TalentWindow(hunter)
hunter.globals = hunterWindow.globals
local mage = world:NewClient("Mage Name", { classID = 8, level = 16, talents = { active = 1, groups = { [1] = { [201] = 5 } } } })
local mageWindow = H.TalentWindow(mage)
mage.globals = mageWindow.globals
world:Login(hunter)
world:RunFor(20)
world:Login(mage)
world:RunFor(60)

local ns = hunter.ns
local Sets = ns.Sets
local function Own()
    return ns.Data.GetOwnRecord(false)
end
local function Printed(client, words)
    for _, line in ipairs(client.printed) do
        if tostring(line):find(words, 1, true) then
            return true
        end
    end
    return false
end

H.section("Gear: the player's sets")
H.eq(#world.errors, 0, "no errors")
local all = Sets.All()
H.eq(#all, 3, "the game's three sets")
H.check(all[1].id == 0 and all[1].name == "Adventurer" and all[1].icon == 132164, "with their IDs (from 0), names and icons")
H.eq(#Sets.Of(1), 0, "no set goes with any talents until the player says so")
H.eq(Sets.Default(1), nil, "so no default")
H.eq(Own().s[1].q, nil, "and the build shares none")
H.check(Sets.IsShared(1) and Sets.IsShared(2), "sharing the gear is on by default")
local state = ns.Data.OwnState()
H.eq(state.gearReset, 1, "ticked once at login (0.5)")
state.gearHidden, state.gearReset = { [2] = true }, nil
Sets.ResetGearSharing()
H.check(Sets.IsShared(1) and Sets.IsShared(2) and state.gearReset == 1, "a character from before 0.5 shares its gear again")
Sets.SetShared(2, false)
H.check(Sets.IsShared(1) and not Sets.IsShared(2), "each spec group on its own")
Sets.ResetGearSharing()
H.check(not Sets.IsShared(2), "only once: unticked afterwards, it stays unticked")
Sets.SetShared(2, true)
H.check(Sets.AutoEquip(), "and so is equipping it when switching talents")

H.section("Gear: giving sets to talents")
Sets.Assign(1, 0, true)
H.eq(Sets.Default(1), 0, "the first set given is the default")
Sets.Assign(1, 2, true)
H.check(H.SameList(Sets.Of(1), { 0, 2 }), "another one goes after it")
H.eq(Sets.Default(1), 0, "and the first stays the default")
Sets.SetDefault(1, 2)
H.check(H.SameList(Sets.Of(1), { 2, 0 }), "a new default goes first")
Sets.Assign(1, 2, false)
H.check(H.SameList(Sets.Of(1), { 0 }), "taking the default away leaves the next one")
H.eq(Sets.Default(1), 0, "as the default")
Sets.Assign(2, 1, true)
Sets.Assign(2, 0, true)
H.check(H.SameList(Sets.Of(2), { 1, 0 }), "a set can go with both spec groups")
H.check(H.SameList(ns.Data.OwnState().sets[1], { 0 }), "kept for the character")
Sets.Assign(3, 0, true)
H.eq(ns.Data.OwnState().sets[3], nil, "only the two spec groups")

H.section("Gear: shared with the builds")
local pvpItems, pvpLeft = Sets.ItemsOf(2)
H.check(#pvpItems == 1 and pvpItems[1].s == 1 and H.SameList(pvpLeft, { 3 }),
    "a slot ignored in the game's set is left as it is, though the set names an item for it")
local _, adventurerLeft = Sets.ItemsOf(0)
H.check(H.SameList(adventurerLeft, { 1 }), "as is one the set marks so (item 1); an empty one is not")
local q1 = Own().s[1].q
H.check(q1 ~= nil and #q1 == 1, "the Primary build carries its set")
H.check(q1[1].n == "Adventurer" and q1[1].i == 132164, "with its name and icon")
local items = {}
for _, item in ipairs(q1[1].it) do
    items[item.s] = item.i
end
H.eq(items[18], Sets.ItemString(BOW), "the item worn, from its link")
H.check(not items[18]:find("1234567", 1, true) and not items[18]:find(":42:", 1, true), "without its unique ID and level")
H.eq(items[16], Sets.ItemString(HAMMER), "the item in the bags, from its link")
H.eq(items[5], "item:6000", "an item not found, by its ID")
H.check(items[1] == nil and items[2] == nil, "no slot left as it is, nor an empty one")
H.eq(items[0], nil, "nor the ammo")
H.check(q1[1].it[1].s == 5 and q1[1].it[3].s == 18, "by slot")
local q2 = Own().s[2].q
H.check(q2 ~= nil and q2[1].n == "Fishing" and q2[2].n == "Adventurer", "the Secondary build's sets, its default first")
H.eq(Own().s[1].x, nil, "talents not shared do not stop the gear")
hunter.containers[0][3] = nil
ns.Talents.Update()
H.eq(Own().s[1].q[1].it[2].i, Sets.ItemString(HAMMER), "an item out of reach keeps the string read before")
hunter.sets[0].items[16] = 2362
ns.Talents.Update()
H.eq(Own().s[1].q[1].it[2].i, "item:2362", "unless the set now has another item")
hunter.sets[0].items[16] = 2361
hunter.containers[0][3] = { 2361, 1, HAMMER }
ns.Talents.Update()

-- The mage's copy of the hunter's record, once it has the hunter's latest.
local function MageCopy()
    return mage.ns.Data.CurrentGuild(false).members[hunter.guid]
end
local function WaitForCopy()
    world:RunUntil(function()
        local copy = MageCopy()
        return copy ~= nil and copy.t == Own().t
    end, 180)
    return MageCopy()
end

H.section("Gear: the guild gets them")
local copy = WaitForCopy()
H.check(copy ~= nil and ns.Same(copy.s[1].q, Own().s[1].q), "the mage has the Primary build's sets")
H.check(ns.Same(copy.s[2].q, Own().s[2].q), "and the Secondary one's")

H.section("Gear: not shared")
Sets.SetShared(2, false)
H.eq(Own().s[2].q, nil, "a spec group's gear can be kept private")
H.check(Own().s[1].q ~= nil, "the other one's stays")
copy = WaitForCopy()
H.eq(copy.s[2].q, nil, "the guild's copies lose it too")
Sets.SetShared(2, true)
H.check(Own().s[2].q ~= nil, "shared again")

H.section("Gear: sets deleted in the game")
hunter.sets[1] = nil
world:FireEvent(hunter, "EQUIPMENT_SETS_CHANGED")
world:RunFor(3)
H.check(H.SameList(ns.Data.OwnState().sets[2], { 0 }), "leave the lists")
H.eq(Sets.Default(2), 0, "the next one is the default")
H.eq(#Own().s[2].q, 1, "and the build shares what is left")
hunter.sets[1] = { name = "Fishing", icon = 136245, items = { [16] = 6256 }, locations = {} }
world:FireEvent(hunter, "EQUIPMENT_SETS_CHANGED")
world:RunFor(3)
H.eq(#Sets.Of(2), 1, "a new set with the same ID does not come back on its own")

H.section("Gear: switching talents")
local function Switch(group)
    hunter.talents.active = group
    world:FireEvent(hunter, "ACTIVE_TALENT_GROUP_CHANGED")
    world:RunFor(3)
end
Sets.Assign(2, 1, true)
Sets.SetDefault(2, 1)
hunter.wornSet = 0
Switch(2)
H.check(H.SameList(hunter.equippedSets, { 1 }), "equips the new spec group's default set")
H.check(Printed(hunter, "equipping Fishing"), "and says so")
Switch(1)
H.check(H.SameList(hunter.equippedSets, { 1, 0 }), "and back")
Switch(1)
H.eq(#hunter.equippedSets, 2, "nothing when the spec group did not change")
hunter.wornSet = 1
Switch(2)
H.eq(#hunter.equippedSets, 2, "nor when the set is worn already")
Sets.SetAutoEquip(false)
Switch(1)
H.eq(#hunter.equippedSets, 2, "nor when the player turned it off")
Sets.SetAutoEquip(true)
hunter.inCombat = true
hunter.wornSet = nil
Switch(2)
H.eq(#hunter.equippedSets, 2, "in combat it waits")
H.check(Printed(hunter, "when the combat ends"), "saying so")
hunter.inCombat = false
world:FireEvent(hunter, "PLAYER_REGEN_ENABLED")
H.check(H.SameList(hunter.equippedSets, { 1, 0, 1 }), "and equips it after the combat")
hunter.wornSet = nil
world:FireEvent(hunter, "PLAYER_ENTERING_WORLD")
Switch(1)
H.eq(#hunter.equippedSets, 3, "nothing right after a loading screen")
world:RunFor(6)
Switch(2)
H.eq(#hunter.equippedSets, 4, "but a switch afterwards")
Switch(1)

H.section("Gear: the talent window")
hunterWindow.globals.PlayerSpellsUtil.OpenToClassTalentsTab()
local box = ns.ShareBox
local talents = hunterWindow.talents
H.check(box.gearBox ~= nil and box.gearBox._parent == talents, "a gear box in the talents page")
H.eq(box.gearBox.Label:GetText(), "Share gear", "saying what it does")
H.check(box.gearBox._shown and box.gearBox:GetChecked(), "shown and ticked by default")
H.check(box.gearBox._point[2] == box.box.Label, "after the talents box")
H.check(box.dropdown._shown and box.dropdown._point[2] == box.gearBox.Label, "then the gear sets menu")
H.eq(box.dropdown._text, "|T132164:0|t Adventurer", "showing the default set")
local menu = H.MenuOf(box.dropdown)
H.eq(menu[1].kind, "title", "a menu with a title")
local fishing = H.MenuEntry(menu, "checkbox", "Fishing")
local adventurer = H.MenuEntry(menu, "checkbox", "Adventurer")
H.check(adventurer and adventurer.isSelected() and fishing and not fishing.isSelected(), "the sets, ticked when they go with these talents")
H.eq(H.MenuEntry(menu, "radio"), nil, "no default to pick with one set")
fishing.setSelected()
H.check(H.SameList(Sets.Of(1), { 0, 1 }), "ticking one gives it to the talents shown")
H.eq(box.dropdown._text, "|T132164:0|t Adventurer (+1)", "the menu says how many more there are")
menu = H.MenuOf(box.dropdown)
local radio = H.MenuEntry(menu, "radio", "Fishing")
H.check(radio and not radio.isSelected(), "with two, the default can be picked")
radio.setSelected()
H.eq(Sets.Default(1), 1, "and is")
local auto = H.MenuEntry(menu, "checkbox", "when switching talents")
H.check(auto and auto.isSelected(), "the menu also has equipping when switching talents")
auto.setSelected()
H.check(not Sets.AutoEquip(), "which turns it off")
auto.setSelected()
H.check(Sets.AutoEquip(), "and on")
hunterWindow.ClickTab(2)
H.eq(box.dropdown.group, 2, "the Secondary tab's own sets")
H.eq(box.dropdown._text, "|T136245:0|t Fishing (+1)", "shown for it")
box.gearBox:SetChecked(false)
box.gearBox._scripts.OnClick(box.gearBox)
H.check(not Sets.IsShared(2) and Sets.IsShared(1), "unticking the gear box stops sharing the tab's gear")
H.eq(Own().s[2].q, nil, "so the build carries none")
hunterWindow.ClickTab(1)
H.check(box.gearBox:GetChecked(), "the other tab's box stays ticked")
hunterWindow.ClickTab(2)
box.gearBox:SetChecked(true)
box.gearBox._scripts.OnClick(box.gearBox)
hunterWindow.ClickTab(1)
local mageMenu
mageWindow.globals.PlayerSpellsUtil.OpenToClassTalentsTab()
mageMenu = H.MenuOf(mage.ns.ShareBox.dropdown)
H.check(H.MenuEntry(mageMenu, "title", "no gear sets") ~= nil, "without sets, it says where to make them")
H.eq(mage.ns.ShareBox.dropdown._text, "No gear set", "and shows none")
mageWindow.globals.HideUIPanel(mageWindow.frame)

H.section("Gear: the Equipment Manager")
local entries = H.OpenSetMenu(hunter, 2)
H.eq(entries[1].text, "Change Name/Icon", "the game's own entry first")
local primary = H.MenuEntry(entries, "checkbox", "Primary")
local secondary = H.MenuEntry(entries, "checkbox", "Secondary")
H.check(primary and secondary, "then one for each spec group")
H.eq(primary.text, "Use with the Primary talents", "saying what it does")
H.check(not primary.isSelected(), "not ticked for a set the talents lack")
primary.setSelected()
H.check(Sets.IsAssigned(1, 2), "ticking it gives the set to the talents")
entries = H.OpenSetMenu(hunter, 2)
local default = H.MenuEntry(entries, "checkbox", "Default gear set of the Primary")
H.check(default and not default.isSelected(), "a set given to talents with more sets can be made their default")
default.setSelected()
H.eq(Sets.Default(1), 2, "and is")
H.MenuEntry(entries, "checkbox", "Use with the Primary").setSelected()
H.check(not Sets.IsAssigned(1, 2), "unticking takes it away")
hunter.mouseFocus = nil
local root = H.NewMenuDescription()
ns.GearManager.AddEntries(nil, root)
H.eq(#root.entries, 0, "nothing in a menu not opened over a set")
local button = H.SetButton(hunter, 0)
H.check(button.SpecIcon._shown and button.SpecRing._shown, "a set given to talents shows their ring")
H.eq(button.SpecIcon._texture, 1, "with the active build's main tree")
hunter.sets[3] = { name = "Spare", icon = 1, items = {}, locations = {} }
button = H.SetButton(hunter, 3)
H.check(not button.SpecIcon._shown and not button.SpecRing._shown, "a set without talents shows none")
hunter.sets[3] = nil

H.section("Gear: a member's gear beside their talents")
-- The Primary talents are shared with Fishing and Adventurer; the
-- Secondary ones are not, and have Adventurer alone.
Sets.Assign(2, 1, false)
H.Share(hunter, 1)
WaitForCopy()
local mns = mage.ns
local list = mage.env.CommunitiesFrame.MemberList
local function HunterButtons()
    for _, row in ipairs(list.rows) do
        if row.memberInfo.guid == hunter.guid then
            row:RefreshExpandedColumns()
            return mns.RosterColumn.ButtonsOf(row)
        end
    end
end
local primaryIcon, secondaryIcon = unpack(HunterButtons())
primaryIcon._scripts.OnEnter(primaryIcon)
local lines = table.concat(mage.env.GameTooltip._lines, "\n")
H.check(lines:find("Gear sets: Fishing, Adventurer", 1, true) ~= nil, "the roster's tooltip names the build's sets")
H.check(lines:find("Click to see the talents and the gear.", 1, true) ~= nil, "and what a click shows")
primaryIcon._scripts.OnClick(primaryIcon)
local panel = mns.GearPanel.panel
H.check(mageWindow.frame._shown and panel and panel._shown, "a click opens the talents and the gear")
H.eq(mns.GearPanel.current.target, mageWindow.frame, "beside the talent window")
local window = mageWindow.frame
H.check(panel._point[1] == "TOPLEFT" and panel._point[2] == window and panel._point[3] == "TOPRIGHT", "on its right")
H.check(window._point[1] == "TOP" and window._point[2] == "UIParent" and window._point[4] == -116,
    "the window moves left by half the panel, so the two are centred")
H.eq(panel._title, "Gear of Hunter Name (Primary)", "titled with the member and the spec group")
local slots = mns.GearPanel.buttons
H.eq(slots[16].item, "item:6256", "the default set's items, by slot")
H.eq(slots[16].Icon._texture, 1000 + 6256, "with their icons")
H.eq(slots[18].item, nil, "an empty slot shows none")
H.check(slots[0] == nil and slots[18] ~= nil, "the ranged slot, but no ammo slot (sets leave ammo out)")
slots[16]._scripts.OnEnter(slots[16])
H.eq(mage.env.GameTooltip._hyperlink, "item:6256", "an item's tooltip")
H.check(panel.SetMenu._shown and not panel.SetName._shown, "a menu to pick between the build's sets")
local setMenu = H.MenuOf(panel.SetMenu)
H.eq(setMenu[1].text, "Fishing", "the default first, by its name")
setMenu[2].setSelected()
H.eq(slots[18].item, Sets.ItemString(BOW), "picking another shows its items")
H.eq(#setMenu, 3, "and, last, what the member wears with these talents")
H.eq(setMenu[3].text, "Equipped", "as Equipped")
setMenu[3].setSelected()
H.check(slots[18].item == Sets.ItemString(BOW) and slots[16].item == nil, "its items")
H.eq(panel.SetIcon._texture, "Interface\\Icons\\INV_Chest_Chain_05", "with an icon of its own")
setMenu[2].setSelected()
mageWindow.globals.HideUIPanel(mageWindow.frame)
H.check(not panel._shown and mns.GearPanel.current == nil, "closing the talents closes the gear")
mageWindow.globals.PlayerSpellsUtil.OpenToClassTalentsTab()
H.eq(window._point[4], 0, "our own talents open where the game puts them")
primaryIcon._scripts.OnClick(primaryIcon)
H.eq(window._point[4], -116, "the member's build moves it again")
mageWindow.globals.PlayerSpellsUtil.OpenToClassTalentsTab()
H.check(not panel._shown and window._point[4] == 0, "showing our own talents in it puts it back, without the gear")
mageWindow.globals.HideUIPanel(window)
mage.leftPanel = mage.env.CommunitiesFrame
primaryIcon._scripts.OnClick(primaryIcon)
H.check(panel._shown and window._point[4] == 0, "beside a window on the left, it stays where the game puts it")
mageWindow.globals.HideUIPanel(window)
mage.leftPanel = nil
window._scale = 2
primaryIcon._scripts.OnClick(primaryIcon)
H.eq(window._point[4], 0, "nor when the screen has no room for both")
mageWindow.globals.HideUIPanel(window)
window._scale = nil

H.section("Gear: only the gear shared")
secondaryIcon._scripts.OnEnter(secondaryIcon)
lines = table.concat(mage.env.GameTooltip._lines, "\n")
H.check(lines:find("Its talents are not shared.", 1, true) and lines:find("Click to see the gear.", 1, true), "the tooltip says only the gear shows")
local opened = #mageWindow.opened
secondaryIcon._scripts.OnClick(secondaryIcon)
H.check(panel._shown and #mageWindow.opened == opened, "a click shows the gear without the talents")
H.eq(mns.GearPanel.current.target, mage.env.CommunitiesFrame, "beside the guild window")
local onlyGearMenu = H.MenuOf(panel.SetMenu)
H.check(panel.SetMenu._shown and onlyGearMenu[1].text == "Adventurer" and onlyGearMenu[2].text == "Equipped",
    "its set first, then what the member wears, though these talents are not in use")
H.check(not panel.ItemLevel._shown, "no item level for a set that leaves slots as they are")
H.check(slots[1].Ignored._shown and slots[1].Icon._shown == false, "a slot the set leaves as it is shows so, as in the game")
H.eq(slots[1].Ignored._texture, "Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent", "with the game's mark")
H.check(not slots[2].Ignored._shown and not slots[5].Ignored._shown, "an empty slot and one with an item do not")
slots[1]._scripts.OnEnter(slots[1])
H.eq(mage.env.GameTooltip._lines[1], "This set leaves this slot as it is.", "its tooltip says so")
secondaryIcon._scripts.OnClick(secondaryIcon)
H.check(not panel._shown, "clicking again closes it")

H.section("Gear: buttons between the talents and the gear")
primaryIcon._scripts.OnClick(primaryIcon)
local gearButton = mns.Viewer.gearButton
H.check(gearButton ~= nil and gearButton._shown and gearButton._parent == window, "the talent window has a gear button")
H.check(gearButton:IsEnabled(), "on, for a build that shares its gear")
H.eq(gearButton.Icon._texture, 136245, "with the default set's icon")
gearButton._scripts.OnEnter(gearButton)
H.eq(mage.env.GameTooltip._lines[1], "Gear", "its tooltip says what it opens")
gearButton._scripts.OnClick(gearButton)
H.check(not panel._shown and window._shown, "it closes the gear, not the talents")
H.eq(window._point[4], 0, "and the window goes back to its place")
gearButton._scripts.OnClick(gearButton)
H.check(panel._shown and mns.GearPanel.current.target == window and window._point[4] == -116, "and opens the gear again beside it")
local talentsButton = panel.TalentsButton
H.check(talentsButton ~= nil and talentsButton._parent == panel and talentsButton:IsEnabled(), "the gear panel has a talents button, on")
H.eq(talentsButton.Icon._texture, 1, "with the build's main tree")
local title = panel.TitleContainer
mns.GearPanel.Hide()
gearButton._scripts.OnClick(gearButton)
H.check(talentsButton:GetFrameLevel() > title:GetFrameLevel(), "drawn over the title bar")
H.check(title._point[1] == "TOPRIGHT" and title._point[4] == -58, "and the title ends before it, centred, as far from the left edge")
H.MenuOf(panel.SetMenu)[2].setSelected()
talentsButton._scripts.OnClick(talentsButton)
H.check(not window._shown and panel._shown, "it closes the talents, not the gear")
H.eq(mns.GearPanel.current.target, mage.env.UIParent, "which stays where it was, on its own")
talentsButton._scripts.OnClick(talentsButton)
H.check(window._shown and panel._shown and mns.GearPanel.current.target == window, "and opens them again, the gear beside them")
H.eq(mns.GearPanel.current.index, 2, "still showing the set picked")
mageWindow.globals.PlayerSpellsUtil.OpenToClassTalentsTab()
H.check(not gearButton._shown, "our own talents have no gear button")
mageWindow.globals.HideUIPanel(window)

H.section("Gear: the buttons and what members share")
secondaryIcon._scripts.OnClick(secondaryIcon)
H.check(panel._shown and not talentsButton:IsEnabled(), "talents not shared: the panel's button is off")
talentsButton._scripts.OnEnter(talentsButton)
H.eq(mage.env.GameTooltip._lines[2], "Its talents are not shared.", "and says why")
opened = #mageWindow.opened
talentsButton._scripts.OnClick(talentsButton)
H.check(not window._shown and #mageWindow.opened == opened, "nothing opens")
secondaryIcon._scripts.OnClick(secondaryIcon)
Sets.SetShared(1, false)
WaitForCopy()
primaryIcon._scripts.OnClick(primaryIcon)
H.check(window._shown and not panel._shown, "gear not shared: the talents open alone")
H.check(gearButton._shown and not gearButton:IsEnabled(), "with the gear button off")
gearButton._scripts.OnEnter(gearButton)
H.eq(mage.env.GameTooltip._lines[2], "Its gear is not shared.", "saying why")
gearButton._scripts.OnClick(gearButton)
H.check(not panel._shown, "and no gear opens")
mageWindow.globals.HideUIPanel(window)
secondaryIcon._scripts.OnClick(secondaryIcon)
H.check(panel.SetName._shown and panel.SetName:GetText() == "Adventurer",
    "the Secondary talents keep their gear: their one set, alone and by its name, without what is worn")
secondaryIcon._scripts.OnClick(secondaryIcon)
Sets.SetShared(1, true)

H.section("Gear: what the member wears, without sets")
local assigned = {}
for i, id in ipairs(Sets.Of(1)) do
    assigned[i] = id
end
for _, id in ipairs(assigned) do
    Sets.Assign(1, id, false)
end
WaitForCopy()
primaryIcon._scripts.OnEnter(primaryIcon)
lines = table.concat(mage.env.GameTooltip._lines, "\n")
H.check(not lines:find("Gear sets", 1, true) and lines:find("Click to see the talents and the gear.", 1, true),
    "no sets, but the roster offers the gear worn")
primaryIcon._scripts.OnClick(primaryIcon)
H.check(window._shown and panel._shown, "a click opens the talents and, beside them, the gear worn")
H.check(panel.SetName._shown and panel.SetName:GetText() == "Equipped", "Equipped alone, without a menu")
H.check(gearButton:IsEnabled() and gearButton.Icon._texture == "Interface\\Icons\\INV_Chest_Chain_05",
    "the talent window's gear button is on")
mageWindow.globals.HideUIPanel(window)
for _, id in ipairs(assigned) do
    Sets.Assign(1, id, true)
end

H.section("Gear: changing between a member's spec groups")
H.Share(hunter, 2)
WaitForCopy()
primaryIcon._scripts.OnClick(primaryIcon)
local tabs = mns.Viewer.groupTabs
H.check(panel._shown and panel._title == "Gear of Hunter Name (Primary)", "the Primary talents with their gear")
tabs:SetTab(2, true)
H.check(mns.Viewer.IsShowing(hunter.guid, 2), "the Secondary tab shows the Secondary talents")
H.check(panel._shown and panel._title == "Gear of Hunter Name (Secondary)", "and their gear beside them")
mns.GearPanel.Hide()
tabs:SetTab(1, true)
H.check(mns.Viewer.IsShowing(hunter.guid, 1) and not panel._shown, "with the gear closed, it stays closed")
Sets.Assign(2, 0, false)
WaitForCopy()
tabs:SetTab(2, true)
local secondaryGear = mns.Viewer.gearButton
H.check(secondaryGear:IsEnabled(), "talents not in use, without sets, still have the gear the member wears")
secondaryGear._scripts.OnClick(secondaryGear)
H.check(panel._shown and panel.SetName:GetText() == "Equipped", "Equipped, beside them")
Sets.Assign(2, 0, true)
mageWindow.globals.HideUIPanel(window)
H.eq(#world.errors, 0, "no errors")
