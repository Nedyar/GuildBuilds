-- Pack.lua: the packed form of Guild Builds's records (LibGuildSync's
-- Pack.lua has the numbers, texts, Base64 and hashing they are made of).
-- Plain Lua with no game API, so it can be tested outside the game.
local _, ns = ...

local Pack = ns.Pack

-- The most a record may hold. Anything bigger is refused when read.
Pack.LIMITS = {
    text = 64,
    build = 400,    -- length of a build's import string
    tabs = 4,       -- talent tabs of a class tree
    specs = 2,      -- spec groups (dual spec)
    points = 255,   -- points spent in one tab
    level = 255,
    sets = 10,      -- gear sets of one build
    slot = 19,      -- the last equipment slot (the first is 1: no ammo)
    item = 255,     -- length of an item string
}

-- Records --------------------------------------------------------------------

-- A record is what one character shares about itself, under its GUID:
--   n = name, rl = realm, t = time of its last change, av = addon version,
--   and, once its talents have been read (all of them or none):
--   lv = the character's level when they were read, tr = its class's talent
--   tree, ag = the active spec group (1 or 2),
--   tb = the tree's tabs, in the game's order: { g = node group ID,
--       i = icon file ID, 0 if unknown },
--   s = its builds, one per spec group: { gr = spec group, x = the game's
--       import string of the build (C_Traits.GenerateImportString), only
--       when its owner shares it with the guild, p = points spent in each
--       tab, in the order of tb, q = the gear sets that go with it, the
--       default one first, only when its owner shares them: { n = name,
--       i = icon file ID, 0 if unknown, it = items { s = equipment slot,
--       i = item string } } }.
-- A packed record is prefixed by its length, so fields added later are
-- skipped by older readers. The gear sets come after the builds, for the
-- same reason.
local ABSENT, PRESENT = 0, 1

local LIMITS = Pack.LIMITS

local function WriteGear(writer, record)
    local count = 0
    for _, spec in ipairs(record.s) do
        if spec.q then
            count = count + 1
        end
    end
    writer:UInt(count)
    for _, spec in ipairs(record.s) do
        if spec.q then
            writer:Byte(spec.gr)
            writer:UInt(#spec.q)
            for _, set in ipairs(spec.q) do
                writer:Str(set.n)
                writer:UInt(set.i or 0)
                writer:UInt(#set.it)
                for _, item in ipairs(set.it) do
                    writer:Byte(item.s)
                    writer:Str(item.i)
                end
            end
        end
    end
end

local function ReadGear(reader, record)
    local count = reader:UInt()
    if count > LIMITS.specs then
        error("too many builds with gear", 0)
    end
    for _ = 1, count do
        local group = reader:Byte()
        local spec
        for _, other in ipairs(record.s) do
            if other.gr == group then
                spec = other
            end
        end
        if not spec or spec.q then
            error("gear of an unknown build", 0)
        end
        local setCount = reader:UInt()
        if setCount > LIMITS.sets then
            error("too many gear sets", 0)
        end
        spec.q = {}
        for i = 1, setCount do
            local set = { n = reader:Str(LIMITS.text), i = reader:UInt(), it = {} }
            local itemCount = reader:UInt()
            if itemCount > LIMITS.slot then
                error("too many items", 0)
            end
            for j = 1, itemCount do
                set.it[j] = { s = reader:Byte(), i = reader:Str(LIMITS.item) }
            end
            spec.q[i] = set
        end
    end
end

local function WriteTalents(writer, record)
    writer:UInt(record.lv)
    writer:UInt(record.tr)
    writer:Byte(record.ag)
    writer:UInt(#record.tb)
    for _, tab in ipairs(record.tb) do
        writer:UInt(tab.g)
        writer:UInt(tab.i or 0)
    end
    writer:UInt(#record.s)
    for _, spec in ipairs(record.s) do
        writer:Byte(spec.gr)
        writer:Str(spec.x or "")
        writer:UInt(#spec.p)
        for _, points in ipairs(spec.p) do
            writer:UInt(points)
        end
    end
    WriteGear(writer, record)
end

local function ReadTalents(reader, record)
    record.lv = reader:UInt()
    record.tr = reader:UInt()
    record.ag = reader:Byte()
    local tabCount = reader:UInt()
    if tabCount > LIMITS.tabs then
        error("too many tabs", 0)
    end
    record.tb = {}
    for i = 1, tabCount do
        record.tb[i] = { g = reader:UInt(), i = reader:UInt() }
    end
    local specCount = reader:UInt()
    if specCount > LIMITS.specs then
        error("too many specs", 0)
    end
    record.s = {}
    for i = 1, specCount do
        local spec = { gr = reader:Byte(), x = reader:Str(LIMITS.build), p = {} }
        if spec.x == "" then
            spec.x = nil
        end
        local count = reader:UInt()
        if count > LIMITS.tabs then
            error("too many tabs", 0)
        end
        for j = 1, count do
            spec.p[j] = reader:UInt()
        end
        record.s[i] = spec
    end
    ReadGear(reader, record)
end

function Pack.WriteRecord(writer, guid, record)
    local body = Pack.Writer()
    body:Str(guid)
    body:Str(record.n or "")
    body:UInt(record.t)
    body:UInt(record.av or 0)
    body:Str(record.rl or "")
    if record.s then
        body:Byte(PRESENT)
        WriteTalents(body, record)
    else
        body:Byte(ABSENT)
    end
    writer:Str(body:Result())
end

function Pack.ReadRecord(reader)
    reader = reader:Sub(reader:UInt())
    local guid = reader:Str()
    local record = { n = reader:Str(), t = reader:UInt(), av = reader:UInt(), rl = reader:Str() }
    if record.n == "" then
        record.n = nil
    end
    if record.rl == "" then
        record.rl = nil
    end
    if reader:Byte() == PRESENT then
        ReadTalents(reader, record)
    end
    return guid, record
end
