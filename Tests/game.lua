-- What the game gives Guild Builds that LibGuildSync's shared harness does
-- not simulate: builds as import strings, the roster rows' class icon and
-- name, the game's talent window, the Equipment Manager's gear sets and
-- their menu, and combat. Sizes, widths, textures and titles set on the
-- fake frames are kept for the tests to check.
return function(H)
    H.FrameMethods.SetWidth = function(self, width)
        self._width = width
    end
    H.FrameMethods.SetTexture = function(self, texture)
        self._texture = texture
    end
    H.FrameMethods.SetTitle = function(self, title)
        self._title = title
    end
    -- A dropdown's own text (WowStyle1DropdownTemplate).
    H.FrameMethods.OverrideText = function(self, text)
        self._text = text
    end
    -- Where a frame is: its last anchor (_point), and its edges and scale
    -- as a test sets them (_left, _right, _scale).
    H.FrameMethods.GetNumPoints = function(self)
        return self._point and 1 or 0
    end
    H.FrameMethods.GetPoint = function(self)
        return unpack(self._point, 1, 5)
    end
    H.FrameMethods.GetLeft = function(self)
        return self._left
    end
    H.FrameMethods.GetRight = function(self)
        return self._right
    end
    H.FrameMethods.GetEffectiveScale = function(self)
        return self._scale or 1
    end
    -- Drawing levels, as set (the game starts a frame at 1).
    H.FrameMethods.SetFrameLevel = function(self, level)
        self._level = level
    end
    H.FrameMethods.GetFrameLevel = function(self)
        return self._level or 1
    end
    -- A window's title bar (ButtonFrameTemplate), a frame above the window.
    H.TemplateRegions.ButtonFrameTemplate = { TitleContainer = "Frame" }

    -- Menus also have titles and dividers.
    local NewMenuDescription = H.NewMenuDescription
    function H.NewMenuDescription()
        local description = NewMenuDescription()
        function description:CreateTitle(text)
            self.entries[#self.entries + 1] = { kind = "title", text = text }
        end
        function description:CreateDivider()
            self.entries[#self.entries + 1] = { kind = "divider" }
        end
        return description
    end

    -- The menu entries (H.NewMenuDescription) of the first entry of a kind
    -- whose text has the given words, or nil.
    function H.MenuEntry(entries, kind, words)
        for _, entry in ipairs(entries) do
            if entry.kind == kind and (not words or tostring(entry.text):find(words, 1, true)) then
                return entry
            end
        end
    end

    -- Where the Equipment Manager finds a set's items, as numbers (decoded
    -- by the fake EquipmentManager_GetLocationData): worn in a slot, or in a
    -- bag's slot.
    H.WORN = 0x100000
    H.IN_BAGS = 0x200000
    function H.InBag(bag, slot)
        return H.IN_BAGS + bag * 100 + slot
    end
    local SLOT_IDS = {
        AMMOSLOT = 0, HEADSLOT = 1, NECKSLOT = 2, SHOULDERSLOT = 3, SHIRTSLOT = 4, CHESTSLOT = 5, WAISTSLOT = 6,
        LEGSSLOT = 7, FEETSLOT = 8, WRISTSLOT = 9, HANDSSLOT = 10, FINGER0SLOT = 11, FINGER1SLOT = 12,
        TRINKET0SLOT = 13, TRINKET1SLOT = 14, BACKSLOT = 15, MAINHANDSLOT = 16, SECONDARYHANDSLOT = 17,
        RANGEDSLOT = 18, TABARDSLOT = 19,
    }

    -- The game's gear sets (C_EquipmentSet) for a client: client.sets =
    -- { [setID] = { name, icon, items = { [slot] = itemID }, locations =
    -- { [slot] = location }, ignored = { [slot] = true } } }. The set worn
    -- is client.wornSet; the sets the client put on, client.equippedSets.
    local function EquipmentSets(client, env)
        client.sets = client.sets or {}
        client.equippedSets = {}
        local function IDs()
            local ids = {}
            for id in pairs(client.sets) do
                ids[#ids + 1] = id
            end
            table.sort(ids)
            return ids
        end
        env.C_EquipmentSet = {
            GetEquipmentSetIDs = IDs,
            GetEquipmentSetInfo = function(id)
                local set = client.sets[id]
                if not set then
                    return nil
                end
                return set.name, set.icon, id, client.wornSet == id, 0, 0, 0, 0, 0
            end,
            GetItemIDs = function(id)
                local set = client.sets[id]
                return set and set.items or {}
            end,
            GetItemLocations = function(id)
                local set = client.sets[id]
                return set and set.locations or {}
            end,
            GetIgnoredSlots = function(id)
                local set = client.sets[id]
                return set and set.ignored or {}
            end,
            UseEquipmentSet = function(id)
                client.equippedSets[#client.equippedSets + 1] = id
                client.wornSet = id
                return true
            end,
        }
        env.EquipmentManager_GetLocationData = function(location)
            if location >= H.IN_BAGS then
                local rest = location - H.IN_BAGS
                return { isPlayer = true, isBags = true, bag = math.floor(rest / 100), slot = rest % 100 }
            elseif location >= H.WORN then
                return { isPlayer = true, slot = location - H.WORN }
            end
            return {}
        end
        env.C_Container.GetContainerItemLink = function(bag, slot)
            local info = env.C_Container.GetContainerItemInfo(bag, slot)
            return info and info.hyperlink
        end
        -- The settings menu of a set (Menu.ModifyMenu by tag), opened with
        -- H.OpenSetMenu; the game draws a set button's ring with
        -- GearSetButton_UpdateSpecInfo.
        client.menuMods = {}
        env.Menu = {
            ModifyMenu = function(tag, fn)
                client.menuMods[tag] = client.menuMods[tag] or {}
                table.insert(client.menuMods[tag], fn)
            end,
        }
        env.GetMouseFoci = function()
            return { client.mouseFocus }
        end
        env.GearSetButton_UpdateSpecInfo = function(button)
            button.SpecIcon:Hide()
            button.SpecRing:Hide()
        end
        env.GetInventorySlotInfo = function(name)
            local id = SLOT_IDS[name]
            if not id then
                error("unknown slot " .. tostring(name))
            end
            return id, "EmptySlot-" .. name
        end
        env.C_Item.GetItemIconByID = function(itemID)
            return 1000 + itemID
        end
        env.HandleModifiedItemClick = function(link)
            client.modifiedClick = link
        end
        env.UISpecialFrames = {}
        env.GameTooltip.SetHyperlink = function(self, link)
            self._hyperlink = link
            table.insert(self._lines, link)
        end
        -- In combat while client.inCombat.
        env.InCombatLockdown = function()
            return client.inCombat == true
        end
        -- A 1920 wide screen; the game's window on the left, if any, is
        -- client.leftPanel.
        env.UIParent._left, env.UIParent._right = 0, 1920
        env.GetUIPanel = function(key)
            return key == "left" and client.leftPanel or nil
        end
    end

    -- Opens the settings menu of a set as the game does: the mouse is on its
    -- settings button, whose parent is the set's button. Returns its entries.
    function H.OpenSetMenu(client, setID)
        local setButton = H.NewObject(client, "Button")
        setButton.setID = setID
        local settings = H.NewObject(client, "Button")
        settings._parent = setButton
        rawset(settings, "GetParent", function(self)
            return self._parent
        end)
        client.mouseFocus = settings
        local root = H.NewMenuDescription()
        root:CreateButton("Change Name/Icon", function() end)
        for _, fn in ipairs(client.menuMods["MENU_PAPERDOLL_FRAME"] or {}) do
            fn(client.env.PaperDollFrame, root)
        end
        return root.entries
    end

    -- A set button of the Equipment Manager, as the game draws it.
    function H.SetButton(client, setID)
        local button = H.NewObject(client, "Button")
        button.setID = setID
        button.SpecIcon = H.NewObject(client, "Texture")
        button.SpecRing = H.NewObject(client, "Texture")
        client.env.GearSetButton_UpdateSpecInfo(button)
        return button
    end

    -- A build as the game's import string: Base64 characters that change
    -- with every rank of the spec group's config (see H.TREE).
    function H.BuildString(ranks)
        local ids = {}
        for nodeID in pairs(ranks or {}) do
            ids[#ids + 1] = nodeID
        end
        table.sort(ids)
        local parts = { "C0c" }
        for _, nodeID in ipairs(ids) do
            parts[#parts + 1] = ("%dr%d"):format(nodeID, ranks[nodeID])
        end
        return table.concat(parts, "x")
    end

    -- Every world made by the tests gets it.
    local NewWorld = H.NewWorld
    function H.NewWorld(options)
        local world = NewWorld(options)
        local MakeEnv = world.MakeEnv
        world.MakeEnv = function(self, client)
            local env = MakeEnv(self, client)
            env.C_Traits.GenerateImportString = function(configID)
                local groups = client.talents and client.talents.groups
                return H.BuildString(groups and groups[configID - 500])
            end
            env.TALENTS = "Talents"
            EquipmentSets(client, env)
            return env
        end
        return world
    end

    -- The guild window's roster rows as the game draws them: the level, the
    -- class icon, and the name placed right after it (UpdateNameFrame), with
    -- the Class column 45 wide (Blizzard's GUILD_COLUMN_INFO).
    function H.TalentsCommunities(client)
        local frame = H.FakeCommunities(client)
        local list = frame.MemberList
        list.columnInfo[2] = { attribute = "classID", width = 45 }
        for _, row in ipairs(list.rows) do
            row.Level = H.NewObject(client, "FontString")
            row.Level:SetPoint("LEFT", 4, 0)
            row.Class = H.NewObject(client, "Texture")
            row.Class:SetPoint("LEFT", row.Level, "RIGHT", 8, 0)
            row.NameFrame = H.NewObject(client, "Frame")
            rawset(row, "UpdateNameFrame", function(self)
                self.NameFrame:ClearAllPoints()
                self.NameFrame:SetPoint("LEFT", self.Class, "RIGHT", 18, 0)
            end)
            row:UpdateNameFrame()
        end
        return frame
    end

    -- The game's talent window (PlayerSpellsFrame) and PlayerSpellsUtil,
    -- as globals for a client: it shows a build given as a talent build
    -- link's data ("spec:level:string"), or the player's own talents.
    function H.TalentWindow(client)
        local frame = H.NewObject(client, "Frame")
        frame:Hide()
        rawset(frame, "IsInspecting", function(self)
            return self.inspectString ~= nil
        end)
        rawset(frame, "GetInspectUnit", function()
            return nil
        end)
        rawset(frame, "GetInspectString", function(self)
            return self.inspectString
        end)
        rawset(frame, "SetTitle", function(self, title)
            self.title = title
        end)
        rawset(frame, "UpdateFrameTitle", function(self)
            self.title = self.inspectString and "Linked Talents (Hunter Hunter)" or "Talents"
        end)
        -- Its talents page: tabs 1 and 2 are the spec groups (Primary and
        -- Secondary), and while it shows someone else's build it says so.
        local talents = H.NewObject(client, "Frame")
        talents.Background = H.NewObject(client, "Texture")
        talents.tab = 1
        rawset(talents, "GetTab", function(self)
            return self.tab
        end)
        rawset(talents, "SetTab", function(self, tab)
            self.tab = tab
        end)
        rawset(talents, "IsInspecting", function()
            return frame.inspectString ~= nil
        end)
        rawset(talents, "UpdateInspecting", function() end)
        frame.TalentsFrame = talents
        local function Open()
            frame:Show()
            frame:UpdateFrameTitle()
            talents:UpdateInspecting()
            if talents._scripts.OnShow then
                talents._scripts.OnShow(talents)
            end
        end
        -- The game places it at the top centre of the screen whenever it
        -- opens it (its panel manager), 1218 wide on a 1920 screen.
        local function Place()
            frame:SetPoint("TOP", "UIParent", "TOP", 0, -41)
            frame._left, frame._right = 351, 1569
        end
        Place()
        local OpenShown = Open
        Open = function()
            if not frame._shown then
                Place()
            end
            OpenShown()
        end
        local window = { frame = frame, talents = talents, opened = {} }
        window.globals = {
            PlayerSpellsFrame = frame,
            PlayerSpellsUtil = {
                InspectLoadout = function(linkData)
                    window.opened[#window.opened + 1] = linkData
                    local _, level, text = linkData:match("^([^:]*):([^:]*):(.*)$")
                    frame.inspectString, frame.inspectLevel = text, tonumber(level)
                    Open()
                end,
                OpenToClassTalentsTab = function()
                    window.own = (window.own or 0) + 1
                    frame.inspectString = nil
                    Open()
                end,
            },
            -- Closing it forgets the build it showed, as the game's does.
            HideUIPanel = function(target)
                target:Hide()
                target.inspectString = nil
                if target._scripts.OnHide then
                    target._scripts.OnHide(target)
                end
            end,
        }
        return window
    end

    -- Shares a client's builds of the given spec groups, as its player
    -- would with the box in the talent window.
    function H.Share(client, ...)
        for _, group in ipairs({ ... }) do
            client.ns.Talents.SetShared(group, true)
        end
    end
end
