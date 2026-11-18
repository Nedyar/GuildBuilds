local H = ...

-- Members on the last release and members on this version share one guild:
-- both must keep talking. The release is taken from its git tag
-- (H.Release).
local RELEASE = "v0.4.0"

H.section("Versions: against " .. RELEASE)
local old = H.Release(RELEASE)
if not old then
    print("   NOTE: " .. RELEASE .. " could not be extracted with git: skipped")
    return
end
local OLD = { H.ADDONS[1], old }

local function Errors(world, label)
    H.eq(#world.errors, 0, "no errors: " .. label)
    for _, err in ipairs(world.errors) do
        print("   " .. err)
    end
    world.errors = {}
end

local function RecordOf(client, other)
    local guild = client.ns.Data.GetGuild("Test Guild")
    return guild and guild.members[other.guid]
end

local function Character(world, name, addons)
    return world:NewClient(name, {
        addons = addons,
        talents = { active = 1, groups = { [1] = { [101] = 5, [102] = 3 } }, unspent = 2 },
        gear = { [1] = { link = "|cffa335ee|Hitem:16939:0:0:0:0:0:0:1:60|h[Helm]|h|r", il = 76 } },
        itemLevel = 60.5,
    })
end

-- The builds, as any version keeps them.
local function HasBuilds(record)
    return record ~= nil and record.s ~= nil and #record.s == 1 and record.s[1].p ~= nil
end

for _, case in ipairs({
    { "this version first, then " .. RELEASE, nil, OLD },
    { RELEASE .. " first, then this version", OLD, nil },
}) do
    local label, firstAddons, secondAddons = case[1], case[2], case[3]
    local world = H.NewWorld({ seed = #label, senderFormat = "short", strictWhispers = true })
    local first = Character(world, "First Member", firstAddons)
    local second = Character(world, "Second Member", secondAddons)
    -- A gear set with its helm worn, leaving the shoulders as they are.
    for _, client in ipairs({ first, second }) do
        client.sets = {
            [0] = { name = "Main", icon = 132222, items = { [1] = 16939, [3] = 1 }, locations = { [1] = H.WORN + 1 }, ignored = { [3] = true } },
        }
    end
    world:Login(first)
    first.ns.Sets.Assign(1, 0, true)
    world:RunFor(10)
    world:Login(second)
    second.ns.Sets.Assign(1, 0, true)
    world:RunFor(300)
    H.check(HasBuilds(RecordOf(second, first)), label .. ": the one who logged in later has the other's builds")
    H.check(HasBuilds(RecordOf(first, second)), label .. ": and the other way round")
    -- Both share the sets with their item levels and the slots they leave
    -- as they are (0.3), and the items worn (0.2).
    local current = firstAddons and second or first
    local release = firstAddons and first or second
    local atRelease = RecordOf(release, current)
    local atCurrent = RecordOf(current, release)
    for _, case in ipairs({ { atRelease, "the release gets" }, { atCurrent, "this version gets" } }) do
        local set = case[1].s[1].q and case[1].s[1].q[1]
        H.check(set ~= nil and set.it[1].il == 76 and H.SameList(set.ig, { 3 }),
            label .. ": " .. case[2] .. " the set, with its item levels and slots left")
    end
    H.check(atRelease.w ~= nil and atCurrent.w ~= nil, label .. ": both share the items worn")
    -- A change while both are online.
    current.talents.groups[1][103] = 1
    world:FireEvent(current, "TRAIT_CONFIG_UPDATED", 501)
    world:RunFor(150)
    local record = RecordOf(release, current)
    H.check(record ~= nil and record.t == current.ns.Data.GetOwnRecord(false).t,
        label .. ": a talent learned reaches the release")
    Errors(world, label)
end
