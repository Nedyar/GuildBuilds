-- RosterColumn.lua: the specialization icons in the Class column of the
-- guild's Roster tab, one per spec group of each member (Primary, then
-- Secondary), the one not active dimmed. A click opens that build: its
-- talents in the game's talent window and its gear sets beside it, as far
-- as its owner shares them.
--
-- Blizzard's roster (CommunitiesFrame.MemberList) keeps its column layout in
-- local tables and places each row's columns at fixed distances, so room
-- is made from the outside: the Class header gets wider, and in each row
-- the name (and the zone and rank after it) moves right by the same amount.
-- The Note column, the one that stretches, gives up that room. Everything
-- here only hooks (hooksecurefunc) and reads Blizzard's frames, so the
-- roster's own actions (invite, promote, remove...) are left untouched.
local _, ns = ...
local L = ns.L

local RosterColumn = {}
ns.RosterColumn = RosterColumn

local ICON_SIZE = 16
local ICON_GAP = 2
local SLOTS = 2
local CLASS_COLUMN = 2         -- the Class header's ID (Blizzard's GUILD_COLUMN_INFO)
local NOTE_WIDTH = 93          -- Blizzard's Note width while an extra column shows

-- Blizzard's Class column (measured in game): a 45 px header, with the class
-- icon 15 px in from its left edge, placed 8 px after the Level column, and
-- the name 4 px after the header's right edge.
local BLIZZARD_WIDTH = 45
local BLIZZARD_INSET = 15
local BLIZZARD_CLASS_X = 8
local NAME_AFTER_HEADER = 4
-- Ours holds the class icon and our two with the margins the Professions
-- column of Guild Professions & Recipes leaves: 6 px on each side.
local MARGIN = 6
local CLASS_X = BLIZZARD_CLASS_X - (BLIZZARD_INSET - MARGIN)  -- the class icon moves left
local CONTENT = ICON_SIZE + SLOTS * (ICON_GAP + ICON_SIZE)
RosterColumn.WIDTH = MARGIN + CONTENT + MARGIN
RosterColumn.SHIFT = RosterColumn.WIDTH - BLIZZARD_WIDTH       -- how much wider the Class column gets
-- From the class icon's right edge to the name.
RosterColumn.NAME_X = CONTENT - ICON_SIZE + MARGIN + NAME_AFTER_HEADER
local SHIFT, NAME_X = RosterColumn.SHIFT, RosterColumn.NAME_X
local INACTIVE_ALPHA = 0.55

local memberList
local slots = setmetatable({}, { __mode = "k" })   -- row -> our buttons
local hooked = setmetatable({}, { __mode = "k" })
local classMoved = setmetatable({}, { __mode = "k" })  -- row -> true while its class icon is in our place
local tabNames = {}  -- [tree ID] = { [group ID] = name }, in the client's language

local function IsGuildClub(list)
    local clubInfo = list and list.GetSelectedClubInfo and list:GetSelectedClubInfo()
    return ns.CanRead(clubInfo) and ns.Plain(clubInfo.clubType) == Enum.ClubType.Guild
end

-- A row of a member in the guild roster, showing its class icon.
local function IsMemberRow(row)
    local memberInfo = row.GetMemberInfo and row:GetMemberInfo()
    return row.expanded and not row.isInvitation and ns.CanRead(memberInfo) and row.Class and row.Class:IsShown()
        and not (row.ProfessionHeader and row.ProfessionHeader:IsShown()) and IsGuildClub(memberList), memberInfo
end

-- The name of a tab of a class tree, from the client (in its language).
local function TabName(treeID, groupID)
    local names = tabNames[treeID]
    if not names then
        names = {}
        local infos = ns.Try(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
        for _, info in ipairs(ns.CanRead(infos) and infos or {}) do
            if ns.CanRead(info) and info.groupID then
                names[info.groupID] = ns.Plain(info.displayName)
            end
        end
        if next(names) then
            tabNames[treeID] = names
        end
    end
    return names[groupID]
end

-- Tooltip and click -----------------------------------------------------------

local function IconOnEnter(button)
    local record, spec = button.record, button.spec
    local main = ns.Data.MainTab(spec)
    local tab = main and record.tb[main]
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(tab and TabName(record.tr, tab.g) or TALENTS or L["Talents"], 1, 1, 1)
    local points = {}
    for i, value in ipairs(spec.p) do
        points[i] = tostring(value)
    end
    GameTooltip:AddLine(table.concat(points, " / "), NORMAL_FONT_COLOR:GetRGB())
    if #record.s > 1 then
        local label = ns.GroupLabel(spec.gr)
        if spec.gr == record.ag then
            label = L["%s, active"]:format(label)
        end
        GameTooltip:AddLine(label, 0.8, 0.8, 0.8)
    end
    if spec.q then
        local names = {}
        for _, set in ipairs(spec.q) do
            names[#names + 1] = set.n
        end
        GameTooltip:AddLine(L["Gear sets: %s"]:format(table.concat(names, ", ")), 1, 1, 1, true)
    end
    local hasGear = #ns.Data.GearOf(record, spec.gr) > 0
    local green = { GREEN_FONT_COLOR:GetRGB() }
    if button.guid == ns.playerGUID then
        -- Ours open our own talents, shared or not.
        GameTooltip:AddLine(L["Click to see the talents."], unpack(green))
        if not spec.x then
            GameTooltip:AddLine(L["Talents not shared with the guild: tick the box at the bottom of your talent window to share them."], 0.7, 0.7, 0.7, true)
        end
    elseif spec.x then
        GameTooltip:AddLine(hasGear and L["Click to see the talents and the gear."] or L["Click to see the talents."], unpack(green))
    else
        GameTooltip:AddLine(L["Its talents are not shared."], 0.7, 0.7, 0.7)
        if hasGear then
            GameTooltip:AddLine(L["Click to see the gear."], unpack(green))
        end
    end
    GameTooltip:AddLine(L["Updated %s ago"]:format(ns.Ago(record.t)), 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function IconOnClick(button)
    if button.guid and button.spec then
        ns.Viewer.Toggle(button.guid, button.spec.gr)
    end
end

local function CreateSlots(row)
    local list = {}
    for i = 1, SLOTS do
        local button = CreateFrame("Button", nil, row)
        button:SetSize(ICON_SIZE, ICON_SIZE)
        button.Icon = button:CreateTexture(nil, "ARTWORK")
        button.Icon:SetAllPoints()
        button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnEnter", IconOnEnter)
        button:SetScript("OnLeave", GameTooltip_Hide)
        button:SetScript("OnClick", IconOnClick)
        button:Hide()
        list[i] = button
    end
    slots[row] = list
    return list
end

-- Rows -------------------------------------------------------------------------

-- The record the roster shows for a member's GUID, or nil.
function RosterColumn.RecordOf(guid)
    local guild = ns.Data.CurrentGuild(false)
    return guid and guild and guild.members[guid] or nil
end

-- Runs after Blizzard places the row's name (UpdateNameFrame), which it
-- puts right after the class icon: ours goes after the room for our icons.
local function MoveName(row)
    if not IsMemberRow(row) or not row.NameFrame then
        return
    end
    row.NameFrame:ClearAllPoints()
    row.NameFrame:SetPoint("LEFT", row.Class, "RIGHT", NAME_X, 0)
end

-- The class icon, at the left of our wider column, or back where Blizzard
-- puts it (the same rows show other communities too).
local function PlaceClass(row, ours)
    if not (row.Class and row.Level) or classMoved[row] == ours then
        return
    end
    classMoved[row] = ours
    row.Class:ClearAllPoints()
    row.Class:SetPoint("LEFT", row.Level, "RIGHT", ours and CLASS_X or BLIZZARD_CLASS_X, 0)
end

-- Runs after Blizzard refreshes a row's columns.
local function UpdateRow(row)
    local list = slots[row]
    local isMember, memberInfo = IsMemberRow(row)
    if not isMember then
        for _, button in ipairs(list or {}) do
            button:Hide()
        end
        if classMoved[row] then
            PlaceClass(row, false)
        end
        return
    end
    list = list or CreateSlots(row)
    PlaceClass(row, true)
    -- Beside an extra column (achievement points...), the Note column has a
    -- width of its own: it gives up the room the names moved into.
    if row.guildColumnIndex ~= nil and row.Note then
        row.Note:SetWidth(NOTE_WIDTH - SHIFT)
    end

    local guid = ns.Plain(memberInfo.guid)
    local record = RosterColumn.RecordOf(guid)
    local specs = ns.Data.IsShareable(record) and ns.Data.BuildsToShow(record) or {}
    local shown = 0
    for _, spec in ipairs(specs) do
        local main = ns.Data.MainTab(spec)
        local tab = main and record.tb[main]
        if tab and shown < SLOTS then
            shown = shown + 1
            local button = list[shown]
            button.guid, button.record, button.spec = guid, record, spec
            button.Icon:SetTexture(tab.i > 0 and tab.i or 134400)  -- the question mark
            button.Icon:SetAlpha(spec.gr == record.ag and 1 or INACTIVE_ALPHA)
            button:ClearAllPoints()
            button:SetPoint("LEFT", row.Class, "RIGHT", ICON_GAP + (shown - 1) * (ICON_SIZE + ICON_GAP), 0)
            button:Show()
        end
    end
    for i = shown + 1, SLOTS do
        list[i].guid, list[i].record, list[i].spec = nil, nil, nil
        list[i]:Hide()
    end
    MoveName(row)
end

-- Our buttons on a row (none until it shows a member).
function RosterColumn.ButtonsOf(row)
    return slots[row] or {}
end

local function HookRow(row)
    if hooked[row] or not row.RefreshExpandedColumns then
        return
    end
    hooked[row] = true
    -- Every path that redraws a row (new member, expanded, extra column,
    -- roster update) ends in RefreshExpandedColumns; UpdateNameFrame places
    -- the name again, after it or on its own.
    hooksecurefunc(row, "RefreshExpandedColumns", UpdateRow)
    if row.UpdateNameFrame then
        hooksecurefunc(row, "UpdateNameFrame", MoveName)
    end
end

-- Header -------------------------------------------------------------------------

-- Runs after Blizzard lays out the headers (each one starts where the one
-- before it ends), so the wider Class header moves the others along.
local function UpdateHeader(list)
    local columns = list.ColumnDisplay
    if not (columns and columns.columnHeaders and list.expandedDisplay and IsGuildClub(list)) then
        return
    end
    local info = type(list.columnInfo) == "table" and list.columnInfo[CLASS_COLUMN]
    local width = type(info) == "table" and type(info.width) == "number" and info.width
    if not width or info.attribute ~= "classID" then
        return
    end
    for header in columns.columnHeaders:EnumerateActive() do
        if header:GetID() == CLASS_COLUMN then
            header:SetWidth(width + SHIFT)
        end
    end
end

-- Setup --------------------------------------------------------------------------

local function RefreshVisible()
    if memberList and CommunitiesFrame:IsVisible() then
        memberList.ScrollBox:ForEachFrame(UpdateRow)
    end
end

local function Setup()
    if memberList or not (CommunitiesFrame and CommunitiesFrame.MemberList and CommunitiesFrame.MemberList.ScrollBox) then
        return
    end
    memberList = CommunitiesFrame.MemberList
    hooksecurefunc(memberList, "RefreshLayout", UpdateHeader)
    ScrollUtil.AddAcquiredFrameCallback(memberList.ScrollBox, function(_, row)
        HookRow(row)
    end, RosterColumn, false)
    memberList.ScrollBox:ForEachFrame(function(row)
        HookRow(row)
        UpdateRow(row)
    end)
    UpdateHeader(memberList)

    local function Refresh()
        ns.Debounce("RosterColumnRefresh", 0.3, RefreshVisible)
    end
    ns.On("DataChanged", Refresh)
    ns.On("RosterUpdated", Refresh)
end

function RosterColumn.Init()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Communities", Setup)
end
