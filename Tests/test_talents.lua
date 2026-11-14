-- Reading our own builds (Talents.lua) and sharing them with the guild.
local H = ...

local DUAL = {
    active = 2,
    groups = {
        [1] = { [101] = 5, [102] = 3, [201] = 2 },
        [2] = { [301] = 5, [302] = 4, [303] = 3, [201] = 1 },
    },
}

local world = H.NewWorld({ seed = 7 })
local hunter = world:NewClient("Hunter Name", { level = 42, talents = H.DeepCopy(DUAL) })
local mage = world:NewClient("Mage Name", { classID = 8, level = 16, talents = { active = 1, groups = { [1] = { [104] = 3 } } } })
world:Login(hunter)
world:RunFor(30)

H.section("Talents: our builds")
H.eq(#world.errors, 0, "no errors")
local ns = hunter.ns
local own = ns.Data.GetOwnRecord(false)
H.check(ns.Talents.ready, "read at login")
H.check(own ~= nil and ns.Data.IsShareable(own), "our record is stamped")
H.eq(own.lv, 42, "with our level")
H.eq(own.tr, H.TREE.id, "and our class's tree")
H.eq(own.ag, 2, "the active spec group")
H.eq(#own.tb, 3, "three tabs")
H.check(own.tb[1].g == 11 and own.tb[2].g == 12 and own.tb[3].g == 13, "in the game's order, by node group")
H.check(own.tb[1].i == 1 and own.tb[3].i == 3, "with their icons")
H.eq(#own.s, 2, "a build per spec group")
H.check(H.SameList(own.s[1].p, { 8, 2, 0 }), "points per tab of the primary build")
H.check(H.SameList(own.s[2].p, { 0, 1, 12 }), "points per tab of the secondary build")
H.eq(ns.Data.MainTab(own.s[2]), 3, "the secondary build is mostly the third tab")

H.section("Talents: sharing")
H.check(own.s[1].x == nil and own.s[2].x == nil, "no build is shared until the player says so")
H.check(not ns.Talents.IsShared(1) and not ns.Talents.IsShared(2), "both spec groups off")
local function Hints(client)
    local count = 0
    for _, line in ipairs(client.printed) do
        if line:find("tick the box", 1, true) then
            count = count + 1
        end
    end
    return count
end
H.eq(Hints(hunter), 1, "the player is told once where to share from")
local before = own.t
world:RunFor(5)
H.Share(hunter, 2)
H.check(own.t > before, "sharing a build stamps the record")
H.eq(own.s[2].x, H.BuildString(DUAL.groups[2]), "the shared build is the game's import string")
H.eq(own.s[1].x, nil, "the other spec group stays private")
H.Share(hunter, 1)
H.eq(own.s[1].x, H.BuildString(DUAL.groups[1]), "each spec group on its own")
H.check(ns.Data.OwnState().share[1] and ns.Data.OwnState().share[2], "kept for this character on this account")
world:FireEvent(hunter, "TRAIT_CONFIG_UPDATED")
world:RunFor(5)
H.eq(Hints(hunter), 1, "and the hint is not repeated")

H.section("Talents: changes")
before = own.t
world:RunFor(5)
world:FireEvent(hunter, "TRAIT_CONFIG_UPDATED")
world:RunFor(5)
H.eq(own.t, before, "nothing changed, nothing stamped")
hunter.talents.groups[1][103] = 2
hunter.talents.staged = true
world:FireEvent(hunter, "TRAIT_CONFIG_UPDATED")
world:RunFor(5)
H.eq(own.t, before, "picked but not applied: not read yet")
hunter.talents.staged = nil
world:FireEvent(hunter, "TRAIT_CONFIG_UPDATED")
world:RunFor(5)
H.check(own.t > before, "applied: stamped again")
H.eq(own.s[1].x, H.BuildString(hunter.talents.groups[1]), "with the new build")
H.check(H.SameList(own.s[1].p, { 10, 2, 0 }), "and its points")
before = own.t
hunter.talents.active = 1
world:FireEvent(hunter, "ACTIVE_TALENT_GROUP_CHANGED")
world:RunFor(5)
H.eq(own.ag, 1, "switching spec groups changes the active one")
H.check(own.t > before, "and is announced")

H.section("Talents: the guild gets them")
world:Login(mage)
world:RunFor(60)
H.eq(#world.errors, 0, "no errors")
local mageNs = mage.ns
local seen = mageNs.Data.CurrentGuild(false).members[hunter.guid]
H.check(seen ~= nil and seen.s ~= nil, "the hunter's builds reach the mage")
H.check(seen and ns.Same(seen.s, own.s) and seen.ag == 1 and seen.lv == 42, "the same builds, active group and level")
local mageOwn = mageNs.Data.GetOwnRecord(false)
local back = ns.Data.CurrentGuild(false).members[mage.guid]
H.check(back ~= nil and ns.Same(back.s, mageOwn.s), "and the mage's build reaches the hunter")
H.eq(#mageOwn.s, 1, "one build without dual spec")
H.eq(mageOwn.ag, 1, "which is the active one")

hunter.talents.groups[2][305] = nil
hunter.talents.groups[2][302] = 5
world:FireEvent(hunter, "TRAIT_CONFIG_UPDATED")
world:RunUntil(function()
    local copy = mageNs.Data.CurrentGuild(false).members[hunter.guid]
    return copy and ns.Same(copy.s, own.s)
end, 120)
H.check(ns.Same(mageNs.Data.CurrentGuild(false).members[hunter.guid].s, own.s), "a later change reaches the mage too")
H.eq(mageOwn.s[1].x, nil, "the mage shares nothing")
H.eq(back.s[1].x, nil, "so the hunter gets the mage's points but not the build")
H.check(H.SameList(back.s[1].p, { 3, 0, 0 }), "(its points)")

ns.Talents.SetShared(1, false)
H.eq(own.s[1].x, nil, "taking a build back stops sharing it")
world:RunUntil(function()
    local copy = mageNs.Data.CurrentGuild(false).members[hunter.guid]
    return copy and copy.s[1].x == nil
end, 120)
H.eq(mageNs.Data.CurrentGuild(false).members[hunter.guid].s[1].x, nil, "and the mage's copy loses it too")
H.check(mageNs.Data.CurrentGuild(false).members[hunter.guid].s[2].x ~= nil, "but keeps the build still shared")

H.section("Talents: no talents yet")
local fresh = world:NewClient("Fresh Name", { level = 5 })
world:Login(fresh)
world:RunFor(30)
H.check(not fresh.ns.Talents.ready, "a character without a talent config is not read")
H.check(fresh.ns.Talents.lastError ~= nil, "and says why")
H.eq(#world.errors, 0, "no errors")
