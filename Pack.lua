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
    itemLevel = 9999,
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
--       i = item string, il = item level, 0 if unknown (from 0.3.0) },
--       ig = the slots it leaves as they are, in order (from 0.3.0) } },
--   un = points not spent yet, in the active build (from 0.2.0);
--   and, from 0.2.0, while its owner shares the active build's gear:
--   w = the items it wears: { s = equipment slot, i = item string,
--       il = item level, 0 if unknown }, by slot,
--   il = the average item level of what it wears, in hundredths, or nil.
-- A packed record is prefixed by its length, so fields added later are
-- skipped by older readers. The gear sets come after the builds, what 0.2.0
-- added after everything 0.1 reads, and what 0.3.0 added after everything
-- 0.2 reads, for the same reason.
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

-- What 0.2.0 added: unspent points and the items worn. 0 stands for an
-- unknown number, so known ones are stored plus one.
local function WriteWorn(writer, record)
    writer:UInt(record.un and record.un + 1 or 0)
    if not record.w then
        writer:Byte(ABSENT)
        return
    end
    writer:Byte(PRESENT)
    writer:UInt(record.il and record.il + 1 or 0)
    writer:UInt(#record.w)
    for _, item in ipairs(record.w) do
        writer:Byte(item.s)
        writer:Str(item.i)
        writer:UInt(item.il or 0)
    end
end

local function ReadWorn(reader, record)
    local unspent = reader:UInt()
    record.un = unspent > 0 and unspent - 1 or nil
    if reader:Byte() ~= PRESENT then
        return
    end
    local level = reader:UInt()
    record.il = level > 0 and level - 1 or nil
    local count = reader:UInt()
    if count > LIMITS.slot then
        error("too many items worn", 0)
    end
    record.w = {}
    for i = 1, count do
        record.w[i] = { s = reader:Byte(), i = reader:Str(LIMITS.item), il = reader:UInt() }
    end
end

-- What 0.3.0 added: for each gear set, the level of each of its items (in
-- the order of its items) and the slots it leaves as they are.
local function WriteSetDetails(writer, record)
    local builds = {}
    for _, spec in ipairs(record.s or {}) do
        if spec.q then
            builds[#builds + 1] = spec
        end
    end
    writer:UInt(#builds)
    for _, spec in ipairs(builds) do
        writer:Byte(spec.gr)
        writer:UInt(#spec.q)
        for _, set in ipairs(spec.q) do
            writer:UInt(#set.it)
            for _, item in ipairs(set.it) do
                writer:UInt(item.il or 0)
            end
            local leaves = set.ig or {}
            writer:UInt(#leaves)
            for _, slot in ipairs(leaves) do
                writer:Byte(slot)
            end
        end
    end
end

local function ReadSetDetails(reader, record)
    local count = reader:UInt()
    if count > LIMITS.specs then
        error("too many builds with gear", 0)
    end
    for _ = 1, count do
        local group, sets = reader:Byte(), reader:UInt()
        local build
        for _, spec in ipairs(record.s or {}) do
            if spec.gr == group then
                build = spec
            end
        end
        if not (build and build.q and #build.q == sets) then
            error("details of unknown gear sets", 0)
        end
        for _, set in ipairs(build.q) do
            if reader:UInt() ~= #set.it then
                error("details of unknown items", 0)
            end
            for _, item in ipairs(set.it) do
                item.il = reader:UInt()
            end
            local leaves = reader:UInt()
            if leaves > LIMITS.slot then
                error("too many slots left", 0)
            end
            set.ig = {}
            for i = 1, leaves do
                set.ig[i] = reader:Byte()
            end
        end
    end
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
    WriteWorn(body, record)
    WriteSetDetails(body, record)
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
    -- A record from 0.1 ends here.
    if not reader:AtEnd() then
        ReadWorn(reader, record)
    end
    -- A record from 0.2 ends here.
    if not reader:AtEnd() then
        ReadSetDetails(reader, record)
    end
    -- Anything after this was added by a later version.
    return guid, record
end
