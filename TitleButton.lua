-- TitleButton.lua: a small button for a window's title bar, left of its
-- close button, that opens or closes another window (the same look as
-- Bot'tar Sync's KinFolk buttons).
--
-- It looks like the game's own title bar buttons: the red frame of its
-- close button, with its pressed and highlight looks, as big as the
-- window's close button. The close button's cross is covered by its own
-- plain red (a thin column left of the cross, stretched), and an icon goes
-- on it, square. Turned off (what it opens is not shared), it stays visible,
-- greyed, and its tooltip says why.
local _, ns = ...

local TitleButton = {}
ns.TitleButton = TitleButton

local FRAME = "RedButton-Exit"
local FRAME_PRESSED = "RedButton-Exit-Pressed"
local FRAME_HIGHLIGHT = "RedButton-Highlight"
local SIZE = 24          -- when the window's close button has no size
local RIM = 0.125        -- the frame's rim, part of the size: the red starts there
local PLAIN = { 0.17, 0.22 }  -- a column of the frame with only red in it
local ICON_MARGIN = 0.19 -- the margin around the icon, part of the size
local GAP = 2            -- from the close button
local CROP = { 0.08, 0.92, 0.08, 0.92 }  -- the game's icons, without their border

local function HasAtlas(name)
    return C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo(name) ~= nil
end

-- tooltip(button) fills the tooltip; onClick(button) runs when on.
function TitleButton.New(parent, close, onClick, tooltip)
    local width = close and ns.Try(close.GetWidth, close)
    local size = (type(width) == "number" and width > 0) and width or SIZE
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    if close and close.GetFrameLevel then
        button:SetFrameLevel(close:GetFrameLevel())
    end
    if close then
        button:SetPoint("RIGHT", close, "LEFT", -GAP, 0)
    else
        button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, -4)
    end
    local native = HasAtlas(FRAME)
    local rim = math.floor(size * RIM + 0.5)
    local margin = native and math.floor(size * ICON_MARGIN + 0.5) or 1
    button.Frame = button:CreateTexture(nil, "BACKGROUND")
    button.Frame:SetAllPoints()
    if native then
        button.Frame:SetAtlas(FRAME)
        button.Fill = button:CreateTexture(nil, "BORDER")
        button.Fill:SetPoint("TOPLEFT", rim, -rim)
        button.Fill:SetPoint("BOTTOMRIGHT", -rim, rim)
    else
        -- A thin dark border, should the game lack its red button.
        button.Frame:SetColorTexture(0, 0, 0, 1)
    end
    -- The plain red column of an atlas, from the rim down to the rim.
    local function Fill(atlas)
        local info = button.Fill and C_Texture.GetAtlasInfo(atlas)
        local file = info and (info.file or info.filename)
        if not file then
            return
        end
        local du, dv = info.rightTexCoord - info.leftTexCoord, info.bottomTexCoord - info.topTexCoord
        button.Fill:SetTexture(file)
        button.Fill:SetTexCoord(info.leftTexCoord + du * PLAIN[1], info.leftTexCoord + du * PLAIN[2],
            info.topTexCoord + dv * RIM, info.bottomTexCoord - dv * RIM)
    end
    Fill(FRAME)
    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetTexCoord(unpack(CROP))
    local function PlaceIcon(offset)
        button.Icon:ClearAllPoints()
        button.Icon:SetPoint("TOPLEFT", margin + offset, -margin - offset)
        button.Icon:SetPoint("BOTTOMRIGHT", -margin + offset, margin - offset)
    end
    PlaceIcon(0)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    if native and HasAtlas(FRAME_HIGHLIGHT) then
        highlight:SetAtlas(FRAME_HIGHLIGHT)
    else
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    end
    highlight:SetBlendMode("ADD")
    -- Pressed: the frame's pressed look, and the icon a pixel down and right.
    local pressed = native and HasAtlas(FRAME_PRESSED)
    button:SetScript("OnMouseDown", function(self)
        if not self:IsEnabled() then
            return
        end
        if pressed then
            self.Frame:SetAtlas(FRAME_PRESSED)
            Fill(FRAME_PRESSED)
        end
        PlaceIcon(1)
    end)
    button:SetScript("OnMouseUp", function(self)
        if pressed then
            self.Frame:SetAtlas(FRAME)
            Fill(FRAME)
        end
        PlaceIcon(0)
    end)
    button:SetScript("OnClick", onClick)
    -- The tooltip says why it is off, too.
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        tooltip(self)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

-- Sets the icon, and whether the button is on (greyed when off).
function TitleButton.Set(button, icon, on)
    button.Icon:SetTexture(icon)
    button.Icon:SetDesaturated(not on)
    button.Icon:SetAlpha(on and 1 or 0.5)
    button:SetEnabled(on)
end
