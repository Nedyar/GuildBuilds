-- Data.lua: what Guild Builds adds to LibGuildSync's database (Store.lua):
-- checking its records (see Pack.lua for their fields) and reading them.
local _, ns = ...

local Lib = LibGuildSync
local Data = ns.Data
local LIMITS = ns.Pack.LIMITS

-- Copies of the same time: the one with more builds is kept.
Data.STATS = 1

function Data.Stats(record)
    return record.s and #record.s or 0
end

-- The game's import strings are Base64.
local function IsBuild(text)
    return type(text) == "string" and #text <= LIMITS.build and text:find("^[%w%+/=]+$") ~= nil
end

local function CleanTabs(tabs)
    if type(tabs) ~= "table" or #tabs > LIMITS.tabs then
        return nil
    end
    local clean = {}
    for i, tab in ipairs(tabs) do
        if type(tab) ~= "table" or not Lib.IsID(tab.g) or not Lib.IsCount(tab.i or 0, 2147483647) then
            return nil
        end
        clean[i] = { g = tab.g, i = tab.i or 0 }
    end
    return clean
end

-- A gear set's name, as the game lets players type it: no escape
-- sequences, links or control characters.
local function IsName(text)
    return type(text) == "string" and #text <= LIMITS.text and text:find("^[^|%c]+$") ~= nil
end

-- An item string as the addon shares it (see Sets.ItemString).
function Data.IsItem(text)
    return type(text) == "string" and #text <= LIMITS.item and text:find("^item:%d+[%w:%-]*$") ~= nil
end

-- A build's gear sets, or nil when unusable.
local function CleanGear(sets)
    if type(sets) ~= "table" or #sets < 1 or #sets > LIMITS.sets then
        return nil
    end
    local clean = {}
    for i, set in ipairs(sets) do
        if type(set) ~= "table" or not IsName(set.n) or not Lib.IsCount(set.i or 0, 2147483647)
            or type(set.it) ~= "table" or #set.it > LIMITS.slot then
            return nil
        end
        local items, slots = {}, {}
        for j, item in ipairs(set.it) do
            if type(item) ~= "table" or not Lib.IsCount(item.s, LIMITS.slot) or item.s < 1 or slots[item.s]
                or not Data.IsItem(item.i) then
                return nil
            end
            slots[item.s] = true
            items[j] = { s = item.s, i = item.i }
        end
        clean[i] = { n = set.n, i = set.i or 0, it = items }
    end
    return clean
end

local function CleanSpecs(specs)
    if type(specs) ~= "table" or #specs < 1 or #specs > LIMITS.specs then
        return nil
    end
    local clean, groups = {}, {}
    for i, spec in ipairs(specs) do
        -- A build not shared has no import string, and no gear sets when
        -- they are not shared.
        if type(spec) ~= "table" or (spec.gr ~= 1 and spec.gr ~= 2) or groups[spec.gr]
            or (spec.x ~= nil and not IsBuild(spec.x)) or type(spec.p) ~= "table" or #spec.p > LIMITS.tabs then
            return nil
        end
        groups[spec.gr] = true
        local points = {}
        for j, value in ipairs(spec.p) do
            if not Lib.IsCount(value, LIMITS.points) then
                return nil
            end
            points[j] = value
        end
        local gear
        if spec.q ~= nil then
            gear = CleanGear(spec.q)
            if not gear then
                return nil
            end
        end
        clean[i] = { gr = spec.gr, x = spec.x, p = points, q = gear }
    end
    return clean
end

-- A checked copy of a record, or nil when it cannot be trusted. Talents
-- come all together or not at all.
function Data.CleanRecord(record, now)
    local clean = Data.CleanBase(record, now)
    if not clean then
        return nil
    end
    if record.s == nil then
        return clean
    end
    local tabs, specs = CleanTabs(record.tb), CleanSpecs(record.s)
    if not tabs or not specs or not Lib.IsCount(record.lv, LIMITS.level) or record.lv < 1
        or not Lib.IsID(record.tr) or (record.ag ~= 1 and record.ag ~= 2) then
        return nil
    end
    clean.lv, clean.tr, clean.ag, clean.tb, clean.s = record.lv, record.tr, record.ag, tabs, specs
    return clean
end

local TALENT_FIELDS = { "lv", "tr", "ag", "tb", "s" }

-- A copy kept without talents takes them from the other copy.
function Data.CarryMissing(kept, other)
    if kept.s == nil and other.s ~= nil then
        for _, field in ipairs(TALENT_FIELDS) do
            kept[field] = other[field]
        end
        return true
    end
    return false
end

function Data.AdoptOwn(own, record)
    return Data.CarryMissing(own, record)
end

-- Reading -----------------------------------------------------------------------

-- The tab with the most points of a build (the first of a tie), or nil
-- when it has none.
function Data.MainTab(spec)
    local best, most = nil, 0
    for i, points in ipairs(spec.p) do
        if points > most then
            best, most = i, points
        end
    end
    return best
end

-- A member's builds to show, in spec group order (Primary, then Secondary),
-- whichever is active.
function Data.BuildsToShow(record)
    local list = {}
    if not record or not record.s then
        return list
    end
    for _, spec in ipairs(record.s) do
        list[#list + 1] = spec
    end
    table.sort(list, function(a, b)
        return a.gr < b.gr
    end)
    return list
end

-- The build of a spec group, or nil.
function Data.BuildOf(record, group)
    for _, spec in ipairs(record and record.s or {}) do
        if spec.gr == group then
            return spec
        end
    end
end
