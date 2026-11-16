-- Records (Pack.lua, Data.lua), the texts in every language and the release
-- files.
local H = ...

local world = H.NewWorld({ seed = 1 })
local solo = world:NewClient("Solo Name", {
    talents = { active = 1, groups = { [1] = { [101] = 5, [201] = 2 } } },
})
world:Login(solo)
world:RunFor(30)
local ns = solo.ns
local Pack, Data = ns.Pack, ns.Data
local now = ns.Now()

H.section("Loading")
H.eq(#world.errors, 0, "no errors while loading and starting")
for _, err in ipairs(world.errors) do
    print("   " .. err)
end

H.section("Pack: records")
local GUID = "Player-1-0000000A"
local record = {
    n = "Solo Name", rl = "TestRealm", t = now, av = 100,
    lv = 30, tr = 1091, ag = 2,
    tb = { { g = 11372, i = 132164 }, { g = 11371, i = 132222 }, { g = 11370, i = 0 } },
    s = {
        { gr = 1, x = "C0cBZcHs6hiHBl7Csp3hvR+3/w==", p = { 21, 0, 0 } },
        { gr = 2, x = "C0cBZcHs6hiAAAAAAAAAA", p = { 0, 5, 16 } },
    },
}
local key, back = Pack.ReadRecord(Pack.Reader(Pack.RecordString(GUID, record)))
H.eq(key, GUID, "record key (the GUID)")
H.check(ns.Same(back, record), "record round trip, every field")
local private = H.DeepCopy(record)
private.s[2].x = nil
_, back = Pack.ReadRecord(Pack.Reader(Pack.RecordString(GUID, private)))
H.check(back.s[2].x == nil and H.SameList(back.s[2].p, { 0, 5, 16 }), "a build not shared travels without its string, with its points")
H.check(Data.CleanRecord(private, now) ~= nil and Data.CleanRecord(private, now).s[2].x == nil, "and passes the checks")
local bare = { n = "Solo Name", t = now, av = 100 }
_, back = Pack.ReadRecord(Pack.Reader(Pack.RecordString(GUID, bare)))
H.check(back.s == nil and back.tb == nil and back.lv == nil and back.rl == nil, "a record without talents reads without them")

-- A later version's extra fields are skipped, and the next record still reads.
local body = Pack.RecordString(GUID, record)
local reader = Pack.Reader(body)
local length = reader:UInt()
local longer = Pack.Writer()
longer:Str(body:sub(reader.pos, reader.pos + length - 1) .. "\1\2\3")
longer:Raw(Pack.RecordString("Player-1-0000000B", bare))
reader = Pack.Reader(longer:Result())
key = Pack.ReadRecord(reader)
H.eq(key, GUID, "a record with fields from a later version reads")
H.eq((Pack.ReadRecord(reader)), "Player-1-0000000B", "the record after it reads too")
H.check(reader:AtEnd(), "batch fully read")
local tooMany = H.DeepCopy(record)
tooMany.s[3] = { gr = 1, x = "AAAA", p = {} }
H.check(not pcall(Pack.ReadRecord, Pack.Reader(Pack.RecordString(GUID, tooMany))), "more than two builds refused")
local longBuild = H.DeepCopy(record)
longBuild.s[1].x = ("A"):rep(Pack.LIMITS.build + 1)
H.check(not pcall(Pack.ReadRecord, Pack.Reader(Pack.RecordString(GUID, longBuild))), "an overlong build refused")

-- Builds with gear sets.
local geared = H.DeepCopy(record)
geared.s[2].x = nil
geared.s[2].q = {
    { n = "Raid", i = 132222, ig = { 3, 19 },
      it = { { s = 1, i = "item:16846::::::::::::", il = 66 }, { s = 18, i = "item:18713:1:::::-23::::::", il = 0 } } },
    { n = "Pesca y más", i = 0, it = {}, ig = {} },
}
_, back = Pack.ReadRecord(Pack.Reader(Pack.RecordString(GUID, geared)))
H.check(ns.Same(back, geared), "gear sets round trip, on the build they go with, with item levels and slots left as they are")
H.eq(back.s[1].q, nil, "a build without them reads without them")
local tooManySets = H.DeepCopy(geared)
for i = 3, Pack.LIMITS.sets + 1 do
    tooManySets.s[2].q[i] = { n = "Set" .. i, i = 0, it = {} }
end
H.check(not pcall(Pack.ReadRecord, Pack.Reader(Pack.RecordString(GUID, tooManySets))), "too many gear sets refused")
local tooManyItems = H.DeepCopy(geared)
for slot = 1, Pack.LIMITS.slot + 1 do
    tooManyItems.s[2].q[2].it[slot] = { s = slot, i = "item:1" }
end
H.check(not pcall(Pack.ReadRecord, Pack.Reader(Pack.RecordString(GUID, tooManyItems))), "too many items in a set refused")

H.section("Data: checking records")
H.check(Data.CleanRecord(record, now) ~= nil, "a good record passes")
H.check(ns.Same(Data.CleanRecord(record, now).s, record.s), "its builds are kept as they are")
H.check(Data.CleanRecord(bare, now) ~= nil and Data.CleanRecord(bare, now).s == nil, "a record without talents passes")
local function Broken(change)
    local copy = H.DeepCopy(record)
    change(copy)
    return Data.CleanRecord(copy, now) == nil
end
H.check(Broken(function(r) r.t = now + 3600 end), "record from the future refused")
H.check(Broken(function(r) r.s[1].x = "C0c|cffff0000" end), "a build with other characters refused")
H.check(Broken(function(r) r.s[1].x = "" end), "an empty build refused")
H.check(Broken(function(r) r.s[2].gr = 1 end), "two builds of one spec group refused")
H.check(Broken(function(r) r.s[1].gr = 3 end), "a third spec group refused")
H.check(Broken(function(r) r.s = {} end), "talents without builds refused")
H.check(Broken(function(r) r.s[1].p[1] = -1 end), "negative points refused")
H.check(Broken(function(r) r.s[1].p[1] = 1.5 end), "fractional points refused")
H.check(Broken(function(r) r.ag = 3 end), "a bad active spec group refused")
H.check(Broken(function(r) r.lv = 0 end), "level 0 refused")
H.check(Broken(function(r) r.tr = nil end), "talents without their tree refused")
H.check(Broken(function(r) r.tb = { {}, {}, {}, {}, {} } end), "too many tabs refused")
H.check(Broken(function(r) r.tb[1].g = "x" end), "a bad tab refused")
H.check(Data.CleanRecord(geared, now) ~= nil and ns.Same(Data.CleanRecord(geared, now).s, geared.s), "gear sets pass, as they are")
local function BrokenGear(change)
    local copy = H.DeepCopy(geared)
    change(copy.s[2].q)
    return Data.CleanRecord(copy, now) == nil
end
H.check(BrokenGear(function(q) q[1].n = "Raid|cffff0000" end), "a set name with an escape sequence refused")
H.check(BrokenGear(function(q) q[1].n = "" end), "an empty set name refused")
H.check(BrokenGear(function(q) q[1].n = ("x"):rep(Pack.LIMITS.text + 1) end), "an overlong set name refused")
H.check(BrokenGear(function(q) q[1].it[1].i = "|Hitem:1|h" end), "an item that is not an item string refused")
H.check(BrokenGear(function(q) q[1].it[1].i = "item:1:|r" end), "an item string with other characters refused")
H.check(BrokenGear(function(q) q[1].it[2].s = 1 end), "two items in one slot refused")
H.check(BrokenGear(function(q) q[1].it[1].s = Pack.LIMITS.slot + 1 end), "a slot past the last refused")
H.check(BrokenGear(function(q) q[1].it[1].s = 0 end), "the ammo slot refused")
H.check(BrokenGear(function(q) q[1].i = -1 end), "a bad icon refused")
H.check(BrokenGear(function(q) q[1].it[1].il = Pack.LIMITS.itemLevel + 1 end), "an impossible item level refused")
H.check(BrokenGear(function(q) q[1].ig = { 1 } end), "a slot left as it is that holds an item refused")
H.check(BrokenGear(function(q) q[1].ig = { 3, 3 } end), "a slot left twice refused")
H.check(BrokenGear(function(q) q[1].ig = { 0 } end), "leaving the ammo slot refused")
H.check(BrokenGear(function(q) q[1].ig = "3" end), "slots left that are not a list refused")
local older = H.DeepCopy(geared)
older.s[2].q[1].ig, older.s[2].q[1].it[1].il = nil, nil
H.check(ns.Same(Data.CleanRecord(older, now).s[2].q, older.s[2].q), "sets from 0.2, without them, pass")
H.eq(Data.SetItemLevel({ it = { { s = 1, il = 60 }, { s = 4, il = 1 }, { s = 18, il = 0 }, { s = 5, il = 70 }, { s = 19, il = 5 } } }), 65,
    "a set's item level: the average of the levels known, without shirt and tabard")
H.eq(Data.SetItemLevel({ it = { { s = 1 } } }), nil, "none when no level is known")
H.check(BrokenGear(function(q)
    for i = #q + 1, Pack.LIMITS.sets + 1 do
        q[i] = { n = "Set" .. i, i = 0, it = {} }
    end
end), "too many gear sets refused")
local emptyGear = H.DeepCopy(geared)
emptyGear.s[2].q = {}
H.eq(Data.CleanRecord(emptyGear, now), nil, "an empty list of sets refused (none is no list)")
local copy = H.DeepCopy(record)
copy.n = "Evil|cffff0000Name"
H.eq(Data.CleanRecord(copy, now).n, "Evilcffff0000Name", "escape sequences stripped from names")

H.section("Data: merging")
local guild = { members = {} }
Data.MergeRecord(guild, GUID, Data.CleanRecord(record, now), false)
H.check(not Data.MergeRecord(guild, GUID, { t = now - 100 }, false), "an older copy loses")
Data.MergeRecord(guild, GUID, { t = now + 1, n = "Solo Name" }, true)
H.eq(guild.members[GUID].t, now + 1, "a newer copy wins")
H.check(ns.Same(guild.members[GUID].s, record.s), "it keeps the builds the older copy knew")
local sameTime = Data.CleanRecord(record, now)
sameTime.s[2] = nil
local other = { members = { [GUID] = sameTime } }
H.check(Data.MergeRecord(other, GUID, Data.CleanRecord(record, now), false), "at the same time, the copy with more builds wins")
H.eq(#other.members[GUID].s, 2, "both builds kept")

H.section("Data: reading")
H.eq(Data.MainTab({ p = { 21, 0, 0 } }), 1, "the main tab is the one with most points")
H.eq(Data.MainTab({ p = { 0, 5, 16 } }), 3, "wherever it is")
H.eq(Data.MainTab({ p = { 7, 7, 0 } }), 1, "the first of a tie")
H.eq(Data.MainTab({ p = { 0, 0, 0 } }), nil, "none without points")
local shown = Data.BuildsToShow(record)
H.check(#shown == 2 and shown[1].gr == 1 and shown[2].gr == 2, "Primary first, Secondary second")
shown = Data.BuildsToShow({ ag = 2, s = { record.s[2], record.s[1] } })
H.check(#shown == 2 and shown[1].gr == 1 and shown[2].gr == 2, "in spec group order however they came, whichever is active")
H.eq(Data.BuildOf(record, 1), record.s[1], "a spec group's build")
H.eq(Data.BuildOf(record, 3), nil, "no build of a missing spec group")
H.eq(#Data.BuildsToShow(bare), 0, "nothing to show without talents")

H.section("Data: saved form")
local savedGuild = Data.GetGuild("Test Guild", true)
savedGuild.members[GUID] = Data.CleanRecord(record)
local packed = H.DeepCopy(ns.db)
Data.PackForSave(packed)
H.eq(type(packed.guilds["Test Guild"].members[GUID].b), "string", "records are saved packed")
local loaded = Data.Sanitize(packed)
H.check(ns.Same(loaded.guilds["Test Guild"].members[GUID].s, record.s), "builds survive saving")
H.check(ns.Same(loaded.guilds["Test Guild"].members[GUID].tb, record.tb), "tabs survive saving")

H.section("Locales")
local function ReadKeys(paths)
    local keys = {}
    for _, file in ipairs(paths) do
        local handle = io.open(H.ADDON .. "/" .. file, "rb")
        local text = handle:read("*a")
        handle:close()
        for k in text:gmatch('L%["(.-)"%]') do
            keys[k] = true
        end
    end
    return keys
end
local codeFiles = {}
for _, file in ipairs(H.FILES) do
    if not file:find("^Locales/") then
        codeFiles[#codeFiles + 1] = file
    end
end
local codeKeys = ReadKeys(codeFiles)
H.check(next(codeKeys) ~= nil, "the code's texts are found")
local function Specifiers(text)
    local list = {}
    for spec in text:gmatch("%%[%d%.]*[sdf]") do
        list[#list + 1] = spec
    end
    return table.concat(list, " ")
end
for _, locale in ipairs({ "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }) do
    local texts = {}
    local env = setmetatable({}, { __index = _G })
    local chunk = assert(loadfile(H.ADDON .. "/Locales/" .. locale .. ".lua"))
    setfenv(chunk, env)
    chunk("GuildBuilds", { RegisterLocale = function(_, fill) fill(texts) end })
    local missing, extra, badSpecs = {}, {}, {}
    for k in pairs(codeKeys) do
        if texts[k] == nil and locale ~= "esMX" then
            missing[#missing + 1] = k
        end
    end
    for k, v in pairs(texts) do
        if not codeKeys[k] then
            extra[#extra + 1] = k
        elseif Specifiers(k) ~= Specifiers(v) then
            badSpecs[#badSpecs + 1] = k
        end
    end
    H.check(#missing == 0, locale .. " has every text" .. (#missing > 0 and (": missing " .. table.concat(missing, " | ")) or ""))
    H.check(#extra == 0, locale .. " has no unused text" .. (#extra > 0 and (": " .. table.concat(extra, " | ")) or ""))
    H.check(#badSpecs == 0, locale .. " keeps the format specifiers" .. (#badSpecs > 0 and (": " .. table.concat(badSpecs, " | ")) or ""))
end

H.section("Release files")
local function Read(path)
    local handle = io.open(H.ADDON .. "/" .. path, "rb")
    if not handle then
        return nil
    end
    local text = handle:read("*a")
    handle:close()
    return text
end
local toc = Read("GuildBuilds.toc")
local changelog = Read("CHANGELOG.md")
local tocVersion = toc:match("## Version: ([%d%.]+)")
H.check(changelog ~= nil and changelog:match("## ([%d%.]+)") == tocVersion, "the TOC version is the changelog's newest")
local announced = Read("Core.lua"):match('\nlocal ANNOUNCE_AS = "([%d%.]+)"')
if announced then
    print(("  NOTE: Core.lua tells the guild this is %s: set ANNOUNCE_AS to nil before tagging a release"):format(announced))
end
H.check(toc:find("## Dependencies: LibGuildSync", 1, true) ~= nil, "LibGuildSync is a dependency")
H.check(toc:find("## SavedVariables: GuildBuildsDB", 1, true) ~= nil, "the saved variable is declared")
local pkgmeta = Read(".pkgmeta")
H.check(pkgmeta ~= nil and pkgmeta:find("package%-as: GuildBuilds") ~= nil, ".pkgmeta packages the folder as GuildBuilds")
H.check(pkgmeta ~= nil and pkgmeta:find("\n    %- Tests\n") ~= nil, ".pkgmeta leaves the tests out of the package")
H.check(pkgmeta ~= nil and pkgmeta:find("required%-dependencies:\n    %- lib%-guild%-sync\n") ~= nil,
    ".pkgmeta makes LibGuildSync a required relation on CurseForge")
for _, locale in ipairs({ "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }) do
    H.check(toc:find("## Notes-" .. locale .. ": ", 1, true) ~= nil, "the TOC has notes in " .. locale)
end
