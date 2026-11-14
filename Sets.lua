-- Sets.lua: the player's own gear sets (the game's Equipment Manager,
-- C_EquipmentSet) and the builds they go with.
--
-- WoW Forever's character window keeps the Equipment Manager, but not the
-- option to give a set to a specialization (a class has one there). Here
-- each spec group (Primary, Secondary) gets a list of sets, its default
-- first: the first set given to a spec group is its default until the
-- player picks another. Switching spec groups equips the default set of the
-- new one, unless the player turns that off. The lists are kept for each
-- character on this account (Data.OwnState), and the sets of each spec
-- group go to the guild with its build, unless the player stops sharing
-- them (shared by default, unlike the talents).
local _, ns = ...
local L = ns.L

local Sets = {}
ns.Sets = Sets

local Number = ns.Number
local LIMITS = ns.Pack.LIMITS
local SETTLE = 5  -- seconds after entering the world before a spec switch equips a set

local lastActive   -- the active spec group, as last seen
local settled = false
local pendingGroup -- a spec group whose default set waits for the end of combat

-- Settings -----------------------------------------------------------------------

-- { [group] = { set IDs, the default first } }, kept for this character.
local function Lists()
    local state = ns.Data.OwnState()
    if type(state.sets) ~= "table" then
        state.sets = {}
    end
    return state.sets
end

local function ListOf(group, create)
    local lists = Lists()
    if type(lists[group]) ~= "table" then
        if not create then
            return {}
        end
        lists[group] = {}
    end
    return lists[group]
end

-- Something changed that the record or the windows show.
local function Changed()
    ns.Fire("SetsChanged")
    if ns.Talents.ready then
        ns.Talents.Update()
    end
end

-- The game's sets ------------------------------------------------------------------

-- The player's gear sets, in the game's order: { id, name, icon, equipped }.
function Sets.All()
    local list = {}
    local api = C_EquipmentSet
    local ids = api and ns.Try(api.GetEquipmentSetIDs)
    if not ns.CanRead(ids) then
        return list
    end
    for _, id in ipairs(ids) do
        id = Number(id)
        if id then
            local name, icon, _, equipped = ns.Try(api.GetEquipmentSetInfo, id)
            name = ns.Plain(name)
            if type(name) == "string" and name ~= "" then
                list[#list + 1] = { id = id, name = name, icon = Number(icon) or 0, equipped = ns.Plain(equipped) == true }
            end
        end
    end
    return list
end

-- The sets of a spec group that still exist, the default first, and the
-- player's sets by ID.
function Sets.Of(group)
    local known = {}
    for _, set in ipairs(Sets.All()) do
        known[set.id] = set
    end
    local ids = {}
    for _, id in ipairs(ListOf(group)) do
        if known[id] then
            ids[#ids + 1] = id
        end
    end
    return ids, known
end

-- The default set of a spec group, or nil.
function Sets.Default(group)
    return (Sets.Of(group))[1]
end

function Sets.IsAssigned(group, id)
    for _, other in ipairs(ListOf(group)) do
        if other == id then
            return true
        end
    end
    return false
end

local function Remove(list, id)
    for i = #list, 1, -1 do
        if list[i] == id then
            table.remove(list, i)
        end
    end
end

-- Gives a set to a spec group (at the end of its list: the first one is the
-- default), or takes it away.
function Sets.Assign(group, id, assigned)
    if (group ~= 1 and group ~= 2) or type(id) ~= "number" then
        return
    end
    local list = ListOf(group, true)
    Remove(list, id)
    if assigned and #Sets.Of(group) < LIMITS.sets then
        list[#list + 1] = id
    end
    Changed()
end

-- Makes a set the default of a spec group (giving it the set if needed).
function Sets.SetDefault(group, id)
    if (group ~= 1 and group ~= 2) or type(id) ~= "number" then
        return
    end
    local list = ListOf(group, true)
    Remove(list, id)
    table.insert(list, 1, id)
    Changed()
end

-- Sets deleted in the game leave the lists (a new set may get the same ID).
local function Prune()
    local ids = C_EquipmentSet and ns.Try(C_EquipmentSet.GetEquipmentSetIDs)
    if not ns.CanRead(ids) then
        return
    end
    local exists = {}
    for _, id in ipairs(ids) do
        if Number(id) then
            exists[Number(id)] = true
        end
    end
    for _, list in pairs(Lists()) do
        if type(list) == "table" then
            for i = #list, 1, -1 do
                if not exists[list[i]] then
                    table.remove(list, i)
                end
            end
        end
    end
end

-- Whether the guild sees a spec group's sets: on until the player turns it
-- off.
function Sets.IsShared(group)
    local hidden = ns.Data.OwnState().gearHidden
    return not (type(hidden) == "table" and hidden[group] == true)
end

function Sets.SetShared(group, shared)
    if group ~= 1 and group ~= 2 then
        return
    end
    local state = ns.Data.OwnState()
    if type(state.gearHidden) ~= "table" then
        state.gearHidden = {}
    end
    state.gearHidden[group] = not shared or nil
    Changed()
end

-- Whether switching spec groups equips the new one's default set: on until
-- the player turns it off.
function Sets.AutoEquip()
    return ns.Data.OwnState().noAutoEquip ~= true
end

function Sets.SetAutoEquip(on)
    ns.Data.OwnState().noAutoEquip = not on or nil
    ns.Fire("SetsChanged")
end

-- Items ------------------------------------------------------------------------------

-- "item:19019:1900:0:0:0:0:0:1234567:60:0:..." -> the same without the
-- fields that change on their own (unique ID, the player's level and spec),
-- which would make an unchanged item look new. Fields are numbers, except
-- the crafter's GUID that crafted items carry ("Player-4613-010B766A");
-- a field with anything else is left blank. nil for anything that is not
-- an item.
function Sets.ItemString(link)
    if type(link) ~= "string" then
        return nil
    end
    local text = link:match("|H(item:[^|]+)|h") or link:match("^(item:[^|]+)$")
    if not text then
        return nil
    end
    local fields = {}
    for field in (text .. ":"):gmatch("([^:]*):") do
        fields[#fields + 1] = field
    end
    if not (fields[2] and fields[2]:find("^%d+$")) then
        return nil
    end
    for i = 3, #fields do
        -- 9, 10 and 11 are the unique ID, link level and spec.
        if (i >= 9 and i <= 11) or not fields[i]:find("^[%w%-]*$") then
            fields[i] = ""
        end
    end
    local itemString = table.concat(fields, ":")
    if #itemString > LIMITS.item then
        return "item:" .. fields[2]
    end
    return itemString
end

local function ItemIDOf(itemString)
    return tonumber(itemString:match("^item:(%d+)"))
end

-- The link of the item at one of the Equipment Manager's locations: worn,
-- in the bags, or in the bank while it can be read.
local function LinkAt(location)
    if not location or location <= 1 or type(EquipmentManager_GetLocationData) ~= "function" then
        return nil
    end
    local data = ns.Try(EquipmentManager_GetLocationData, location)
    if not ns.CanRead(data) or not Number(data.slot) then
        return nil
    end
    if data.isBags then
        return C_Container and ns.Plain(ns.Try(C_Container.GetContainerItemLink, data.bag, data.slot))
    elseif data.isPlayer or data.isBank then
        return ns.Plain(ns.Try(GetInventoryItemLink, "player", data.slot))
    end
end

-- A set's items: { s = slot, i = item string }, by slot. previous: the same
-- set's items as shared before, kept for items that cannot be read now (in
-- the bank); an item never read is shared by its ID alone.
function Sets.ItemsOf(id, previous)
    local api = C_EquipmentSet
    local itemIDs = api and ns.Try(api.GetItemIDs, id)
    if not ns.CanRead(itemIDs) then
        return {}
    end
    local locations = ns.Try(api.GetItemLocations, id)
    locations = ns.CanRead(locations) and locations or {}
    local ignored = ns.Try(api.GetIgnoredSlots, id)
    ignored = ns.CanRead(ignored) and ignored or {}
    local known = {}
    for _, item in ipairs(previous or {}) do
        known[item.s] = item.i
    end
    local items = {}
    -- The ammo slot (0) is left out: sets cannot hold ammo.
    for slot = 1, LIMITS.slot do
        local itemID = Number(itemIDs[slot])
        -- 0 is an empty slot, 1 one the set leaves as it is.
        if itemID and itemID > 1 and ns.Plain(ignored[slot]) ~= true then
            itemID = math.floor(itemID)
            local text = Sets.ItemString(LinkAt(Number(locations[slot])))
            if not text or ItemIDOf(text) ~= itemID then
                local old = known[slot]
                text = old and ItemIDOf(old) == itemID and old or ("item:" .. itemID)
            end
            items[#items + 1] = { s = slot, i = text }
        end
    end
    return items
end

-- A name the record can hold (see Data.lua's checks).
local function CleanName(name)
    name = name:gsub("[|%c]", "?")
    if #name > LIMITS.text then
        -- Cut whole characters only.
        name = name:sub(1, LIMITS.text):gsub("[\192-\255][\128-\191]*$", "")
    end
    return name
end

-- A spec group's sets as the record holds them (see Pack.lua), the default
-- first, or nil when it has none. previous: the build's sets as shared
-- before.
function Sets.Read(group, previous)
    local ids, known = Sets.Of(group)
    if #ids == 0 then
        return nil
    end
    local before = {}
    for _, set in ipairs(previous or {}) do
        before[set.n] = set.it
    end
    local list = {}
    for _, id in ipairs(ids) do
        local set = known[id]
        local name = CleanName(set.name)
        list[#list + 1] = { n = name, i = set.icon, it = Sets.ItemsOf(id, before[name]) }
    end
    return list
end

-- Switching spec groups --------------------------------------------------------------

local function EquipDefault(group)
    local id = Sets.Default(group)
    if id == nil then
        return
    end
    local _, known = Sets.Of(group)
    local set = known[id]
    if set.equipped then
        return
    end
    if InCombatLockdown() then
        pendingGroup = group
        ns.Print(L["%s will be equipped when the combat ends."], set.name)
        return
    end
    pendingGroup = nil
    ns.Try(C_EquipmentSet.UseEquipmentSet, id)
    ns.Print(L["equipping %s, the gear set of your %s talents."], set.name, ns.GroupLabel(group))
end

local function OnSpecMaybeChanged()
    local active = ns.Talents.ActiveGroup()
    if settled and lastActive and active ~= lastActive and Sets.AutoEquip() then
        EquipDefault(active)
    end
    lastActive = active
end

function Sets.Init()
    if not C_EquipmentSet then
        return
    end
    lastActive = ns.Talents.ActiveGroup()
    local events = CreateFrame("Frame")
    ns.RegisterEvents(events, "EQUIPMENT_SETS_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
        "ACTIVE_TALENT_GROUP_CHANGED", "ACTIVE_COMBAT_CONFIG_CHANGED")
    events:SetScript("OnEvent", function(_, event)
        if event == "EQUIPMENT_SETS_CHANGED" then
            Prune()
            ns.Fire("SetsChanged")
            ns.Debounce("TalentsUpdate", 2, ns.Talents.Update)
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Loading screens may report the spec group anew: only a switch
            -- made afterwards equips a set.
            settled = false
            lastActive = ns.Talents.ActiveGroup()
            C_Timer.After(SETTLE, function()
                lastActive = ns.Talents.ActiveGroup()
                settled = true
            end)
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingGroup and pendingGroup == ns.Talents.ActiveGroup() and Sets.AutoEquip() then
                EquipDefault(pendingGroup)
            end
            pendingGroup = nil
        else
            OnSpecMaybeChanged()
        end
    end)
    C_Timer.After(SETTLE, function()
        settled = true
    end)
end
