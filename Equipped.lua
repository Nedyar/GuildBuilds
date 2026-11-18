-- Equipped.lua: what the player wears, shared with the guild together with
-- the gear of the build in use: only while the active spec group's "Share
-- gear" box is ticked (Sets.IsShared). The gear panel shows it as
-- "Equipped", or marks the set it is (Data.GearOf); other addons read it
-- from the records (w and il, see Pack.lua).
local _, ns = ...

local Equipped = {}
ns.Equipped = Equipped

local Number = ns.Number
local LIMITS = ns.Pack.LIMITS

-- The first slot is 1: the ammo slot (0) is not equipment.
local FIRST_SLOT = 1
local LAST_SLOT = LIMITS.slot

local function ItemLevel(slot, link)
    local level
    if ItemLocation and C_Item.GetCurrentItemLevel then
        local location = ns.Try(ItemLocation.CreateFromEquipmentSlot, ItemLocation, slot)
        if location then
            level = Number(ns.Try(C_Item.GetCurrentItemLevel, location))
        end
    end
    if not level and C_Item.GetDetailedItemLevelInfo then
        level = Number(ns.Try(C_Item.GetDetailedItemLevelInfo, link))
    end
    if level then
        return math.min(math.max(math.floor(level + 0.5), 0), LIMITS.itemLevel)
    end
    return 0
end

-- The items worn, by slot: { s = slot, i = item string, il = item level }.
function Equipped.Read()
    local items = {}
    for slot = FIRST_SLOT, LAST_SLOT do
        local link = ns.Plain(ns.Try(GetInventoryItemLink, "player", slot))
        local itemString = ns.Sets.ItemString(link)
        if itemString then
            items[#items + 1] = { s = slot, i = itemString, il = ItemLevel(slot, link) }
        end
    end
    return items
end

-- The item level of what is worn (items: as Equipped.Read gives them), in
-- hundredths, worked out as every item level the addon shows
-- (Data.SetItemLevel), or nil.
function Equipped.ReadItemLevel(items)
    local level = ns.Data.SetItemLevel({ it = items or Equipped.Read() })
    if not level then
        return nil
    end
    return math.min(math.floor(level * 100 + 0.5), LIMITS.itemLevel * 100)
end

-- Whether what we wear goes to the guild now.
function Equipped.IsShared()
    return ns.Sets.IsShared(ns.Talents.ActiveGroup())
end

-- Brings our record's items worn up to date: read while shared, gone when
-- not.
function Equipped.Update()
    local record = ns.Data.GetOwnRecord(true)
    if not record then
        return
    end
    local worn, level
    if Equipped.IsShared() then
        worn = Equipped.Read()
        level = Equipped.ReadItemLevel(worn)
    end
    if ns.Same(record.w, worn) and record.il == level then
        return
    end
    record.w, record.il = worn, level
    ns.Data.TouchOwn(record)
    ns.Debug("own items worn updated")
end

local function Later()
    ns.Debounce("EquippedUpdate", 2, Equipped.Update)
end

function Equipped.Init()
    local events = CreateFrame("Frame")
    ns.RegisterEvents(events,
        "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE",
        "ACTIVE_TALENT_GROUP_CHANGED", "ACTIVE_COMBAT_CONFIG_CHANGED")
    events:SetScript("OnEvent", Later)
    ns.On("GuildChanged", Later)
    -- The "Share gear" boxes.
    ns.On("SetsChanged", Later)
    Equipped.Update()
end
