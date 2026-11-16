-- Guild Builds: shows the builds of the guild's members (talent
-- specializations and the gear sets that go with them) in the guild roster,
-- opens their talents in the game's talent window and their gear beside it,
-- and gives the player's own gear sets to their spec groups.
--
-- The addon messages, the guild roster, the saved database and the sync
-- are LibGuildSync's (a separate addon this one depends on), attached
-- below. Core.lua holds the startup and the slash commands.
local ADDON_NAME, ns = ...
local L = ns.L
local Lib = LibGuildSync

ns.ADDON_NAME = ADDON_NAME

Lib.Attach(ns, {
    title = "Guild Builds",
    tag = "GB",
    prefix = "GuildBuilds",
    protocol = "1",
    savedVariable = "GuildBuildsDB",
})

-- While a version that keeps the protocol is tried in game before its
-- release, it tells the guild it runs the last release (ANNOUNCE_AS): it
-- keeps sharing with the members on it, who are not told to update to a
-- version they cannot get yet. Set it to nil for the release.
local ANNOUNCE_AS = nil
if ANNOUNCE_AS then
    ns.VERSION_NUM = Lib.VersionNumber(ANNOUNCE_AS)
end

-- Our own builds have been read, so what we announce is current.
function ns.Sync.OwnReady()
    return ns.Talents.ready
end

-- A spec group's name, in the game's words when it has them.
function ns.GroupLabel(group)
    if group == 2 then
        return DUAL_SPEC_SECONDARY or L["Secondary"]
    end
    return DUAL_SPEC_PRIMARY or L["Primary"]
end

-- Startup ------------------------------------------------------------------

local events = CreateFrame("Frame")
ns.RegisterEvents(events, "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT")
events:SetScript("OnEvent", function(self, event, name)
    if event == "PLAYER_LOGOUT" then
        ns.Data.PackForSave(ns.db)
    elseif event == "ADDON_LOADED" and name == ADDON_NAME then
        self:UnregisterEvent("ADDON_LOADED")
        ns.Data.Load()
        if ns.db.settings.locale then
            ns.SetLocale(ns.db.settings.locale)
        end
    elseif event == "PLAYER_LOGIN" then
        -- The library first: our name, the roster, the messages and the sync.
        Lib.Start(ns)
        -- Each part starts on its own, so a failure in one (reported as a normal
        -- Lua error) does not stop the others.
        local parts = {
            ns.Talents.Init, ns.Sets.Init, ns.Equipped.Init, ns.Viewer.Init, ns.GearPanel.Init,
            ns.ShareBox.Init, ns.GearManager.Init, ns.RosterColumn.Init,
        }
        for _, init in ipairs(parts) do
            xpcall(init, geterrorhandler())
        end
    end
end)

-- Slash commands -------------------------------------------------------------

local function PrintHelp()
    ns.Print(L["/gbuilds status - what the addon knows and is doing"])
    ns.Print(L["/gbuilds sync - ask the guild for missing data now"])
    ns.Print(L["/gbuilds language [code|auto] - language of the addon's texts"])
    ns.Print(L["/gbuilds debug - show the sync log in the chat"])
    ns.Print(L["/gbuilds reset - forget the data of your current guild"])
end

local function PrintStatus()
    ns.Print(L["version %s. Saved data loaded by the client: %s."], ns.VERSION, ns.loadInfo.native and YES or NO)

    local guildKey = ns.Roster.guildKey
    if not guildKey then
        ns.Print(L["you are not in a guild (or the guild has not loaded yet)."])
    else
        local count = 0
        local guild = ns.Data.GetGuild(guildKey)
        if guild then
            ns.Data.ForEachShared(guild, function(_, record)
                if record.s then
                    count = count + 1
                end
            end)
        end
        ns.Print(L["guild %s: talents of %d |4character:characters; with the addon, %d |4member:members; in the roster."], guildKey, count, ns.Roster.total)
    end
    if not ns.Talents.ready then
        ns.Print(L["your talents have not been read yet (%s)."], tostring(ns.Talents.lastError))
    elseif ns.playerGUID then
        local talents, gear = {}, {}
        for group = 1, 2 do
            if ns.Talents.ConfigFor(group) then
                local label = ns.GroupLabel(group)
                talents[#talents + 1] = ("%s: %s"):format(label, ns.Talents.IsShared(group) and YES or NO)
                local sets = {}
                local ids, known = ns.Sets.Of(group)
                for _, id in ipairs(ids) do
                    sets[#sets + 1] = known[id].name
                end
                gear[#gear + 1] = ("%s: %s (%s)"):format(label, #sets > 0 and table.concat(sets, ", ") or L["none"],
                    ns.Sets.IsShared(group) and L["shared"] or L["not shared"])
            end
        end
        ns.Print(L["talents shared with the guild: %s."], table.concat(talents, ", "))
        ns.Print(L["gear sets: %s."], table.concat(gear, "; "))
        ns.Print(L["switching talents equips their default gear set: %s."], ns.Sets.AutoEquip() and YES or NO)
    end
    ns.Print(L["sync: %s"], ns.Sync.Describe())
end

SLASH_GUILDBUILDS1 = "/gbuilds"
SLASH_GUILDBUILDS2 = "/guildbuilds"
SlashCmdList.GUILDBUILDS = function(message)
    message = strtrim(message or "")
    local command, rest = message:match("^(%S*)%s*(.-)$")
    local lower = command:lower()
    if lower == "" or lower == "status" then
        PrintStatus()
    elseif lower == "sync" then
        ns.Sync.SendHello(true)
    elseif lower == "debug" then
        ns.debugEnabled = not ns.debugEnabled
        ns.Print(ns.debugEnabled and L["sync log on."] or L["sync log off."])
    elseif lower == "language" or lower == "lang" then
        -- A language code in any case ("dede" is deDE), or auto.
        local code
        for _, known in ipairs(ns.LOCALES) do
            if known:lower() == rest:lower() then
                code = known
            end
        end
        if not code and rest:lower() ~= "auto" then
            ns.Print(L["languages: %s, or auto for the client's."], table.concat(ns.LOCALES, ", "))
            return
        end
        ns.db.settings.locale = code
        ns.SetLocale(code)
        ns.Print(L["language set to %s."], ns.LOCALE)
    elseif lower == "reset" then
        if rest:lower() ~= "confirm" then
            ns.Print(L["this forgets what you know about your current guild. Type /gbuilds reset confirm to do it."])
        else
            ns.Data.ResetGuild(ns.Roster.guildKey)
            ns.Print(L["data of your current guild forgotten."])
        end
    else
        PrintHelp()
    end
end
