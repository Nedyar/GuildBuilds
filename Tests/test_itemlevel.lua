-- The item level of the player's own gear in the game's windows
-- (OwnItemLevel.lua): what is worn, under the character window's stats,
-- and each gear set's, in its tooltip.
local H = ...

local BOW = "|cff1eff00|Hitem:2504:0:0:0:0:0:0:1234567:42:0:0|h[Worn Shortbow]|h|r"
local SHIRT = "|cffffffff|Hitem:45::::::::42:::::|h[Shirt]|h|r"
local HAMMER = "|cffffffff|Hitem:2361::::::::42:::::|h[Battleworn Hammer]|h|r"
local HELM = "|cffffffff|Hitem:3300::::::::42:::::|h[Helm]|h|r"
local CHEST = "|cffffffff|Hitem:6000::::::::42:::::|h[Chest]|h|r"
local world = H.NewWorld({ seed = 29 })
-- The hammer is a two-handed weapon.
world.itemSlots[2361] = "INVTYPE_2HWEAPON"
local hunter = world:NewClient("Hunter Name", {
    level = 42,
    talents = { active = 1, groups = { [1] = { [101] = 5, [102] = 3 } } },
    gear = { [18] = { link = BOW, il = 14 }, [4] = { link = SHIRT, il = 1 }, [1] = { link = HELM, il = 24 } },
    containers = { [0] = { size = 16, [3] = { 2361, 1, HAMMER } } },
    itemLevel = 33.72,
})
hunter.sets = {
    -- The bow and the shirt worn, the hammer in the bags, a chest piece not
    -- found that the client knows, and the head left as it is (a helm is
    -- worn there).
    [0] = { name = "Adventurer", icon = 132164, items = { [18] = 2504, [4] = 45, [16] = 2361, [5] = 6000, [1] = 1 },
        locations = { [18] = H.WORN + 18, [4] = H.WORN + 4, [16] = H.InBag(0, 3), [5] = -1 } },
    -- The hammer alone.
    [1] = { name = "Smashing", icon = 132329, items = { [16] = 2361 }, locations = { [16] = H.InBag(0, 3) } },
    -- An item whose level the client does not know.
    [2] = { name = "Fishing", icon = 136245, items = { [16] = 6256 }, locations = { [16] = H.InBag(0, 9) } },
    -- The bow, the shirt and the helm worn, and the chest piece not found.
    [3] = { name = "Everyday", icon = 132164, items = { [18] = 2504, [4] = 45, [1] = 3300, [5] = 6000 },
        locations = { [18] = H.WORN + 18, [4] = H.WORN + 4, [1] = H.WORN + 1, [5] = -1 } },
}
hunter.itemLevels = { [2361] = 21, [6000] = 30 }
-- Action button 1 holds the Adventurer set.
hunter.actionSets = { [1] = 0 }
world:Login(hunter)
world:RunFor(20)
local env, ns = hunter.env, hunter.ns

H.section("Own item level: the character window's stats")
H.eq(#world.errors, 0, "no errors")
local pane = env.CharacterStatsPaneScrollBox
local row = ns.OwnItemLevel.row
H.check(row ~= nil and row._parent == pane, "a row on the character window's stats")
H.eq(row and row._template, "CharacterStatFrameScrollBoxLabelElementTemplate", "as the game's stat rows look")
H.check(row and H.SameList(row._point, { "TOPRIGHT", pane.ScrollBox, "BOTTOMRIGHT", 0, -3 }),
    "under the game's list, not in it")
H.check(row and row._shown, "shown")
H.eq(row and row.Label:GetText(), "Item level:", "in the game's words")
H.eq(row and row.Value:GetText(), "2.2",
    "the item level of what is worn now: the bow and the helm over 17, not the shirt nor the game's average")
H.eq(row and row.tooltip, "|cffffffffItem level 2.2|r", "the same in its tooltip")
H.eq(row and row.tooltip2, "The average item level of your equipment.", "with the game's line about it")

hunter.gear[5] = { link = CHEST, il = 30 }
env.PaperDollFrame_UpdateStats()
H.eq(row.Value:GetText(), "4.0", "up to date whenever the game updates its stats")
hunter.level = 9
env.PaperDollFrame_UpdateStats()
H.check(not row._shown, "hidden below level 10, as the game hides it")
hunter.level = 10
env.PaperDollFrame_UpdateStats()
H.check(row._shown, "and back from level 10")

H.section("Own item level: gear sets' tooltips")
local tooltip = env.GameTooltip
tooltip:SetEquipmentSet(3)
H.eq(tooltip._lines[1], "Everyday", "the game's tooltip of a set")
H.eq(tooltip._lines[2], "Item level 4.0", "then its item level, worked out as the row's: the same items, the same level")
H.eq(#tooltip._lines, 2, "once")
tooltip:SetEquipmentSet(1)
H.eq(tooltip._lines[2], "Item level 2.5", "each set its own (a two-handed weapon alone counts twice)")
tooltip:SetEquipmentSet(0)
H.eq(#tooltip._lines, 1, "none for a set that leaves slots as they are")
tooltip:SetEquipmentSet(2)
H.eq(#tooltip._lines, 1, "nor for a set whose items' levels are not known")
hunter.actionSets = { [1] = 3 }
tooltip:SetAction(1)
H.eq(#tooltip._lines, 1, "none either where the game does not fill the tooltip from the set's ID")
H.eq(#world.errors, 0, "no errors")
