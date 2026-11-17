-- OwnItemLevel.lua: the item level of the player's own gear in the game's
-- windows: what is worn, at the foot of the character window's stats, and
-- each gear set's, in its tooltip (the Equipment Manager's).
--
-- Both go beside the game's code, never into it. The stats are a list the
-- game fills from its own tables each time the character window opens,
-- also in combat, when the game no longer lets addons open windows: an
-- entry added to those tables would make that opening the addon's, and the
-- game could block it. So the item level gets a row of its own, under the
-- list (in the room the game leaves there), that looks like the game's.
--
-- Both levels are worked out as every item level the addon shows
-- (Data.SetItemLevel): the row's from the items worn now, not the game's
-- average, which leaves out the ranged slot.
local _, ns = ...
local L = ns.L

local OwnItemLevel = {}
ns.OwnItemLevel = OwnItemLevel

-- A row of the game's stats list, as its rows look.
local ROW_TEMPLATE = "CharacterStatFrameScrollBoxLabelElementTemplate"
local ROW_GAP = 3        -- from the bottom of the list, below the line the game draws there
local MIN_LEVEL = 10     -- the game shows no item level below it (MIN_PLAYER_LEVEL_FOR_ITEM_LEVEL_DISPLAY)

local row

-- The worn gear's row ---------------------------------------------------------------

-- Fills the row with the item level of what is worn now, in the game's
-- words: "Item Level: 30.3", and a tooltip with the same and the game's
-- line about it. It is hidden below the level the game starts showing an
-- item level at.
function OwnItemLevel.UpdateRow()
    if not row then
        return
    end
    local level = ns.Number(ns.Try(UnitLevel, "player"))
    local itemLevel = ns.Data.SetItemLevel({ it = ns.Equipped.Read() })
    if not (level and itemLevel) or level < (ns.Number(MIN_PLAYER_LEVEL_FOR_ITEM_LEVEL_DISPLAY) or MIN_LEVEL) then
        row:Hide()
        return
    end
    local text = ns.ItemLevelNumber(itemLevel)
    local label = STAT_AVERAGE_ITEM_LEVEL or L["Item level"]
    row.Label:SetText((STAT_FORMAT or "%s:"):format(label))
    row.Value:SetText(text)
    row.numericValue = tonumber(text)
    row.tooltip = (HIGHLIGHT_FONT_COLOR_CODE or "") .. (PAPERDOLLFRAME_TOOLTIP_FORMAT or "%s"):format(label)
        .. " " .. text .. (FONT_COLOR_CODE_CLOSE or "")
    row.tooltip2 = STAT_AVERAGE_ITEM_LEVEL_TOOLTIP
    row:Show()
end

-- The row, under the character window's stats list, once.
function OwnItemLevel.CreateRow()
    local pane = CharacterStatsPaneScrollBox
    local list = pane and pane.ScrollBox
    if row or not list then
        return row
    end
    row = CreateFrame("Frame", nil, pane, ROW_TEMPLATE)
    row:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -ROW_GAP)
    row:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 0, -ROW_GAP)
    OwnItemLevel.row = row
    OwnItemLevel.UpdateRow()
    return row
end

-- The sets' tooltips ------------------------------------------------------------------

-- A set's item level (Data.SetItemLevel): nil for a set that leaves slots
-- as they are, or when a level it needs is not known.
function OwnItemLevel.OfSet(id)
    local items, leaves = ns.Sets.ItemsOf(id)
    return ns.Data.SetItemLevel({ it = items, ig = leaves })
end

-- Runs after the game fills a gear set's tooltip; only for the tooltips it
-- fills from a set's ID (GameTooltip:SetEquipmentSet), the Equipment
-- Manager's.
function OwnItemLevel.AddToTooltip(tooltip)
    local info = tooltip and tooltip.GetProcessingTooltipInfo and ns.Try(tooltip.GetProcessingTooltipInfo, tooltip)
    if type(info) ~= "table" or info.getterName ~= "GetEquipmentSet" or type(info.getterArgs) ~= "table" then
        return
    end
    local id = ns.Number(info.getterArgs[1])
    local level = id and OwnItemLevel.OfSet(id)
    if level then
        local r, g, b = NORMAL_FONT_COLOR:GetRGB()
        tooltip:AddLine(ns.ItemLevelText(level), r, g, b)
    end
end

function OwnItemLevel.Init()
    OwnItemLevel.CreateRow()
    if row and type(PaperDollFrame_UpdateStats) == "function" then
        -- The game refreshes its stats when the window opens and whenever
        -- they may change while it is open (equipment, level, talents).
        hooksecurefunc("PaperDollFrame_UpdateStats", OwnItemLevel.UpdateRow)
    end
    local types = Enum and Enum.TooltipDataType
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and types and types.EquipmentSet then
        TooltipDataProcessor.AddTooltipPostCall(types.EquipmentSet, OwnItemLevel.AddToTooltip)
    end
end
