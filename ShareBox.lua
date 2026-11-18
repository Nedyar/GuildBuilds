-- ShareBox.lua: a build's settings at the bottom left of the game's talent
-- window (PlayerSpellsFrame.TalentsFrame), where WoW Forever leaves out the
-- loadouts: whether the guild may open its talents (off by default) and see
-- its gear sets (on by default), and a menu of the gear sets that go with
-- it, their default, and whether switching talents equips it. They are for
-- the spec group the window shows (its Primary and Secondary tabs), and
-- hide while the window shows someone else's build.
local _, ns = ...
local L = ns.L

local ShareBox = {}
ns.ShareBox = ShareBox

local box, gearBox, dropdown

local function TalentsFrame()
    return PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
end

-- The spec group the window shows: its tab IDs are the spec groups.
local function ShownGroup(frame)
    local tab = ns.Try(frame.GetTab, frame)
    if tab == 1 or tab == 2 then
        return tab
    end
    return ns.Talents.ActiveGroup()
end

-- "|T icon|t Name", for the menus.
local function SetText(set)
    if set.icon and set.icon > 0 then
        return ("|T%d:0|t %s"):format(set.icon, set.name)
    end
    return set.name
end

-- What the menu button says: the default set, and how many more there are.
local function DropdownText(group)
    local ids, known = ns.Sets.Of(group)
    if #ids == 0 then
        return L["No gear set"]
    end
    local text = SetText(known[ids[1]])
    if #ids > 1 then
        text = ("%s (+%d)"):format(text, #ids - 1)
    end
    return text
end

local function UpdateDropdownText(group)
    local text = DropdownText(group)
    ShareBox.dropdownText = text
    if dropdown.OverrideText then
        dropdown:OverrideText(text)
    elseif dropdown.SetText then
        dropdown:SetText(text)
    end
end

function ShareBox.Update()
    local frame = TalentsFrame()
    if not (box and frame) then
        return
    end
    local group = ShownGroup(frame)
    local inspecting = ns.Try(frame.IsInspecting, frame) == true
    local shown = not inspecting and ns.Talents.ConfigFor(group) ~= nil
    for _, widget in ipairs({ box, gearBox, dropdown }) do
        widget.group = group
        widget:SetShown(shown)
    end
    box:SetChecked(ns.Talents.IsShared(group))
    gearBox:SetChecked(ns.Sets.IsShared(group))
    UpdateDropdownText(group)
end

-- The menu of the gear sets of the spec group the window shows.
local function Generate(owner, root)
    local group = owner.group or ns.Talents.ActiveGroup()
    root:CreateTitle(L["Gear sets of these talents"])
    local all = ns.Sets.All()
    if #all == 0 then
        root:CreateTitle(L["You have no gear sets: save them in the Equipment Manager of your character window."])
    end
    for _, set in ipairs(all) do
        root:CreateCheckbox(SetText(set), function()
            return ns.Sets.IsAssigned(group, set.id)
        end, function()
            ns.Sets.Assign(group, set.id, not ns.Sets.IsAssigned(group, set.id))
        end)
    end
    local ids, known = ns.Sets.Of(group)
    if #ids > 1 then
        root:CreateDivider()
        root:CreateTitle(L["Default gear set"])
        for _, id in ipairs(ids) do
            root:CreateRadio(SetText(known[id]), function()
                return ns.Sets.Default(group) == id
            end, function()
                ns.Sets.SetDefault(group, id)
            end)
        end
    end
    root:CreateDivider()
    root:CreateCheckbox(L["Equip the default gear set when switching talents"], ns.Sets.AutoEquip, function()
        ns.Sets.SetAutoEquip(not ns.Sets.AutoEquip())
    end)
end

local function BoxTooltip(title, ...)
    local lines = { ... }
    return function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(title, 1, 1, 1)
        for _, line in ipairs(lines) do
            GameTooltip:AddLine(line, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end
end

local function NewBox(frame, label, onClick, onEnter)
    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    -- Over the window's art, like its own buttons.
    check:SetFrameLevel(1010)
    check.Label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    check.Label:SetPoint("LEFT", check, "RIGHT", 2, 1)
    check.Label:SetText(label)
    check:SetScript("OnClick", function(self)
        onClick(self.group, self:GetChecked())
        ShareBox.Update()
    end)
    check:SetScript("OnEnter", onEnter)
    check:SetScript("OnLeave", GameTooltip_Hide)
    return check
end

local function Create(frame)
    box = NewBox(frame, L["Share talents"], ns.Talents.SetShared, BoxTooltip(L["Share these talents with the guild"],
        L["Guild members with Guild Builds can open them from the guild roster."],
        L["Not shared, they only see the main tree and the points in each tree."]))
    box:SetPoint("BOTTOMLEFT", frame.Background or frame, "BOTTOMLEFT", 44, 6)

    gearBox = NewBox(frame, L["Share gear"], ns.Sets.SetShared, BoxTooltip(L["Share these gear sets with the guild"],
        L["Guild members with Guild Builds can see the gear sets of these talents from the guild roster."],
        L["While these talents are in use, the gear you are wearing is shared too."]))
    gearBox:SetPoint("LEFT", box.Label, "RIGHT", 14, -1)

    dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(190)
    dropdown:SetFrameLevel(1010)
    dropdown:SetPoint("LEFT", gearBox.Label, "RIGHT", 14, -1)
    dropdown:SetupMenu(Generate)

    ShareBox.box, ShareBox.gearBox, ShareBox.dropdown = box, gearBox, dropdown
end

local function Setup()
    local frame = TalentsFrame()
    if box or not frame then
        return
    end
    Create(frame)
    -- Opening the window, changing tabs, and showing someone else's build or
    -- ours again.
    frame:HookScript("OnShow", ShareBox.Update)
    for _, method in ipairs({ "SetTab", "UpdateInspecting" }) do
        if type(frame[method]) == "function" then
            hooksecurefunc(frame, method, ShareBox.Update)
        end
    end
    -- A click on a tab reaches the window's SetTab as the game kept it when
    -- the window loaded, missing the hook above; every change of tab marks
    -- the tab selected on the window's tab system, though. Without this the
    -- boxes kept the tab shown before, and changed its settings.
    local tabs = frame.TabSystem
    if tabs and type(tabs.SetTabVisuallySelected) == "function" then
        hooksecurefunc(tabs, "SetTabVisuallySelected", ShareBox.Update)
    end
    ShareBox.Update()
end

function ShareBox.Init()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", Setup)
    -- Learning dual spec gives the second tab a build; sets come and go.
    ns.On("OwnChanged", ShareBox.Update)
    ns.On("SetsChanged", ShareBox.Update)
end
