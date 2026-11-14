-- Talents.lua: reads the player's own builds (their gear sets come from
-- Sets.lua).
--
-- WoW Forever's talents are a trait tree (C_Traits), one per class, shown
-- by Blizzard's Camelot talent window (Blizzard_PlayerSpells): the three
-- classic tabs are node groups of that tree (GetGroupDisplayInfoByTreeID),
-- and with dual spec each spec group has its own config
-- (GetCombatConfigIDForSpecGroup). The game turns a config into an import
-- string (C_Traits.GenerateImportString), the same text its talent window
-- shows another build from, so that string is what the guild gets, for the
-- builds the player shares.
local _, ns = ...
local L = ns.L

local Talents = {}
ns.Talents = Talents

Talents.ready = false  -- read at least once this session
Talents.lastError = nil

local Number = ns.Number
local LIMITS = ns.Pack.LIMITS
local RETRY_INTERVAL = 10
local MAX_RETRIES = 30

local function ActiveSpecGroup()
    local Spec = C_SpecializationInfo
    return Number(Spec and ns.Try(Spec.GetActiveSpecGroup)) or 1
end

-- The spec group in use (1 or 2).
Talents.ActiveGroup = ActiveSpecGroup

local function SpecGroupCount()
    local count = Number(ns.Try(GetNumSpecGroups))
    return count and count >= 1 and count or 1
end

local function ConfigForSpecGroup(group, active)
    local Spec = C_SpecializationInfo
    local configID = Spec and Number(ns.Try(Spec.GetCombatConfigIDForSpecGroup, group))
    if not configID and active and C_ClassTalents then
        configID = Number(ns.Try(C_ClassTalents.GetActiveConfigID))
    end
    return configID
end

local function TreeOf(configID)
    local info = ns.Try(C_Traits.GetConfigInfo, configID)
    if not ns.CanRead(info) or type(info.treeIDs) ~= "table" then
        return nil
    end
    return Number(info.treeIDs[1])
end

-- The tree's tabs, left to right: { g = group ID, i = icon }.
local function ReadTabs(treeID)
    local tabs = {}
    local infos = ns.Try(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
    if not ns.CanRead(infos) then
        return tabs
    end
    for _, info in ipairs(infos) do
        if ns.CanRead(info) and Number(info.groupID) and #tabs < LIMITS.tabs then
            local icon = Number(info.icon)
            tabs[#tabs + 1] = { g = info.groupID, i = icon and icon > 0 and math.floor(icon) or 0 }
        end
    end
    return tabs
end

-- Points spent in each tab, in the order of tabs.
local function SpentPerTab(configID, tabs)
    local ids, index, spent = {}, {}, {}
    for i, tab in ipairs(tabs) do
        ids[i] = tab.g
        index[tab.g] = i
        spent[i] = 0
    end
    local infos = #ids > 0 and ns.Try(C_Traits.GetGroupCurrencyInfo, configID, ids)
    if ns.CanRead(infos) then
        for _, info in ipairs(infos) do
            local i = ns.CanRead(info) and index[info.traitNodeGroupID]
            local currency = i and ns.CanRead(info.currencyInfos) and info.currencyInfos[1]
            local points = currency and ns.CanRead(currency) and Number(currency.spent)
            if points then
                spent[i] = math.min(math.max(math.floor(points), 0), LIMITS.points)
            end
        end
    end
    return spent
end

local function ImportString(configID)
    local text = ns.Plain(ns.Try(C_Traits.GenerateImportString, configID))
    if type(text) == "string" and text ~= "" and #text <= LIMITS.build and text:find("^[%w%+/=]+$") then
        return text
    end
end

-- Our builds, as the record holds them (see Pack.lua), or nil (with
-- Talents.lastError) when the client cannot give them yet.
function Talents.Read()
    if not (C_Traits and C_Traits.GetConfigInfo and C_Traits.GenerateImportString) then
        Talents.lastError = "no C_Traits"
        return nil
    end
    local active = ActiveSpecGroup()
    local activeConfig = ConfigForSpecGroup(active, true)
    if not activeConfig then
        Talents.lastError = "no talent config yet"
        return nil
    end
    if ns.Try(C_Traits.ConfigHasStagedChanges, activeConfig) == true then
        -- Talents picked in the window but not applied yet.
        Talents.lastError = "changes not applied yet"
        return nil
    end
    local treeID = TreeOf(activeConfig)
    if not treeID then
        Talents.lastError = "no talent tree"
        return nil
    end
    local level = Number(UnitLevel("player"))
    if not level or level < 1 then
        Talents.lastError = "no level yet"
        return nil
    end
    local tabs = ReadTabs(treeID)
    local talents = { lv = math.min(level, LIMITS.level), tr = treeID, ag = active, tb = tabs, s = {} }
    for group = 1, math.min(SpecGroupCount(), LIMITS.specs) do
        local configID = group == active and activeConfig or ConfigForSpecGroup(group, false)
        local text = configID and ImportString(configID)
        if text then
            talents.s[#talents.s + 1] = { gr = group, x = text, p = SpentPerTab(configID, tabs) }
        elseif group == active then
            Talents.lastError = "the active build could not be read"
            return nil
        end
    end
    Talents.lastError = nil
    return talents
end

-- The config of one of our spec groups, or nil (dual spec not learned).
function Talents.ConfigFor(group)
    return ConfigForSpecGroup(group, group == ActiveSpecGroup())
end

-- Sharing ------------------------------------------------------------------

-- Which of our builds the guild may open: a setting of each character and
-- spec group, kept on this account only (Data.OwnState), off until the
-- player turns it on. A build not shared still shows its main tab and its
-- points; its import string never leaves this client.
function Talents.IsShared(group)
    local state = ns.Data.OwnState()
    return type(state.share) == "table" and state.share[group] == true
end

function Talents.SetShared(group, shared)
    if group ~= 1 and group ~= 2 then
        return
    end
    local state = ns.Data.OwnState()
    if type(state.share) ~= "table" then
        state.share = {}
    end
    state.share[group] = shared and true or nil
    state.hinted = true
    Talents.Update()
end

-- Once per character, while it shares nothing: where to share from.
local function HintOnce(talents)
    local state = ns.Data.OwnState()
    if state.hinted then
        return
    end
    local hasPoints = false
    for _, spec in ipairs(talents.s) do
        if spec.x then
            state.hinted = true
            return
        end
        hasPoints = hasPoints or ns.Data.MainTab(spec) ~= nil
    end
    if hasPoints then
        state.hinted = true
        ns.Print(L["your talents are not shared with the guild. To share them, tick the box at the bottom of your talent window."])
    end
end

local FIELDS = { "lv", "tr", "ag", "tb", "s" }

function Talents.Update()
    local record = ns.Data.GetOwnRecord(true)
    if not record then
        return false
    end
    local talents = Talents.Read()
    if not talents then
        ns.Debug("talents not read: %s", tostring(Talents.lastError))
        return false
    end
    for _, spec in ipairs(talents.s) do
        if not Talents.IsShared(spec.gr) then
            spec.x = nil
        end
        -- The gear sets that go with the build, unless they are not shared.
        if ns.Sets.IsShared(spec.gr) then
            local before = ns.Data.BuildOf(record, spec.gr)
            spec.q = ns.Sets.Read(spec.gr, before and before.q)
        end
    end
    HintOnce(talents)
    Talents.ready = true
    local changed = not ns.Data.IsShareable(record) or record.av ~= ns.VERSION_NUM
    for _, field in ipairs(FIELDS) do
        if not ns.Same(record[field], talents[field]) then
            record[field] = talents[field]
            changed = true
        end
    end
    if changed then
        ns.Data.TouchOwn(record)
        ns.Debug("own builds updated")
    end
    return true
end

function Talents.Init()
    local events = CreateFrame("Frame")
    ns.RegisterEvents(events,
        "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_TALENT_UPDATE",
        "TRAIT_CONFIG_LIST_UPDATED", "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
        "ACTIVE_COMBAT_CONFIG_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED")
    events:SetScript("OnEvent", function()
        ns.Debounce("TalentsUpdate", 2, Talents.Update)
    end)
    ns.On("GuildChanged", function()
        ns.Debounce("TalentsUpdate", 2, Talents.Update)
    end)
    -- The talent config can arrive a while after login.
    local tries = 0
    local ticker
    ticker = C_Timer.NewTicker(RETRY_INTERVAL, function()
        tries = tries + 1
        if Talents.ready or tries > MAX_RETRIES then
            ticker:Cancel()
            return
        end
        Talents.Update()
    end)
    Talents.Update()
end
