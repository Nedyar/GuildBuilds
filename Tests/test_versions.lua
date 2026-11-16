local H = ...

-- Members on the last release and members on this version share one guild:
-- both must keep talking. The release is taken from its git tag
-- (H.Release).
local RELEASE = "v0.1.0"

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
    world:Login(first)
    world:RunFor(10)
    world:Login(second)
    world:RunFor(300)
    H.check(HasBuilds(RecordOf(second, first)), label .. ": the one who logged in later has the other's builds")
    H.check(HasBuilds(RecordOf(first, second)), label .. ": and the other way round")
    -- This version's record also carries what it wears, which the release
    -- skips.
    local current = firstAddons and second or first
    local release = firstAddons and first or second
    H.check(current.ns.Data.GetOwnRecord(false).w ~= nil, label .. ": this version shares its items worn")
    H.eq(RecordOf(release, current).w, nil, label .. ": the release skips them")
    H.eq(RecordOf(current, release).w, nil, label .. ": and shares none")
    -- A change while both are online.
    current.talents.groups[1][103] = 1
    world:FireEvent(current, "TRAIT_CONFIG_UPDATED", 501)
    world:RunFor(150)
    local record = RecordOf(release, current)
    H.check(record ~= nil and record.t == current.ns.Data.GetOwnRecord(false).t,
        label .. ": a talent learned reaches the release")
    Errors(world, label)
end
