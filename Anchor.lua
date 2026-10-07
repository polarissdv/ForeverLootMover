local ADDON_NAME, ns = ...
local L = ns.L

-- =========================================================
-- ANCHOR: the spot the roll bars are pinned to
-- =========================================================
-- The game draws its own loot roll bars and this addon never touches how they
-- look: it only decides where they land. The anchor is an invisible frame the
-- size of one bar which the real ones point at, so they follow it around even
-- while it is being dragged.
--
-- The handle is what you see while placing: a stone frame in the usual World of
-- Warcraft look, exactly the size and place the real bar will take, with an
-- arrow showing which way a second roll will stack.
local Anchor = {}
ns.Anchor = Anchor

local WHITE = "Interface\\Buttons\\WHITE8x8"
local GOLD = { 1, 0.82, 0.35 }
local ARROW_UP = "Interface\\Buttons\\Arrow-Up-Up"
local ARROW_DOWN = "Interface\\Buttons\\Arrow-Down-Up"

local function BarSize()
    local db = ns.db
    local width = (db and tonumber(db.barWidth)) or 277
    local height = (db and tonumber(db.barHeight)) or 67
    return width, height
end

local FontTitle = CreateFont("ForeverLootMoverAnchorTitle")
FontTitle:SetFont("Fonts\\MORPHEUS.TTF", 17, "OUTLINE")
FontTitle:SetShadowOffset(1, -1)
FontTitle:SetShadowColor(0, 0, 0, 1)

-- ---------------------------------------------------------
-- The anchor
-- ---------------------------------------------------------
local anchor = CreateFrame("Frame", "ForeverLootMoverAnchor", UIParent)
anchor:SetSize(277, 67)
anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
anchor:SetMovable(true)
anchor:SetFrameStrata("DIALOG")
Anchor.frame = anchor

-- ---------------------------------------------------------
-- The handle you drag
-- ---------------------------------------------------------
local handle = CreateFrame("Frame", "ForeverLootMoverHandle", anchor, "BackdropTemplate")
handle:SetAllPoints(anchor)
handle:SetFrameStrata("DIALOG")
handle:SetFrameLevel(anchor:GetFrameLevel() + 20)
handle:EnableMouse(true)
handle:EnableMouseWheel(true)
handle:RegisterForDrag("LeftButton")
handle:Hide()
handle:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 20,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
})
handle:SetBackdropColor(1, 1, 1, 0.85)
handle:SetBackdropBorderColor(1, 1, 1, 1)

-- Which way the next roll will stack
local arrow = handle:CreateTexture(nil, "OVERLAY")
arrow:SetSize(26, 26)
arrow:SetPoint("CENTER")
arrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.9)

-- A small gold diamond, the same ornament as the options menu
local function Diamond(parent, size)
    local diamond = parent:CreateTexture(nil, "OVERLAY")
    diamond:SetTexture(WHITE)
    diamond:SetSize(size, size)
    diamond:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    diamond:SetRotation(math.rad(45))
    return diamond
end

-- The labels sit outside the frame, so the box always shows the bare footprint
-- of the real bar whatever its size
local title = handle:CreateFontString(nil, "OVERLAY")
title:SetFontObject(FontTitle)
title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
title:SetPoint("BOTTOM", handle, "TOP", 0, 8)

local titleLeft = Diamond(handle, 5)
titleLeft:SetPoint("RIGHT", title, "LEFT", -8, 0)
local titleRight = Diamond(handle, 5)
titleRight:SetPoint("LEFT", title, "RIGHT", 8, 0)

local hint = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("TOP", handle, "BOTTOM", 0, -8)

local hint2 = handle:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint2:SetPoint("TOP", hint, "BOTTOM", 0, -3)

handle:SetScript("OnDragStart", function()
    anchor:StartMoving()
end)

handle:SetScript("OnDragStop", function()
    anchor:StopMovingOrSizing()
    Anchor.Save()
    if ns.Rolls then ns.Rolls.Soon() end
end)

handle:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then
        Anchor.Hide()
        ns.Print(L.MOVED)
    end
end)

-- Wheel over the handle resizes the bars: the box follows, so the size can be
-- judged against the rest of the screen
handle:SetScript("OnMouseWheel", function(_, delta)
    if not ns.db then return end
    ns.db.scale = ns.ClampScale((ns.db.scale or 1) + delta * 0.05)
    ns.SettingsChanged()
end)

-- ---------------------------------------------------------
-- Position
-- ---------------------------------------------------------
function Anchor.Save()
    local point, _, relativePoint, x, y = anchor:GetPoint(1)
    if not point or not ns.db then return end
    ns.db.point = { point, relativePoint, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) }
end

function Anchor.Restore()
    local point = (ns.db and ns.db.point) or ns.defaults.point
    anchor:ClearAllPoints()
    anchor:SetPoint(point[1] or "CENTER", UIParent, point[2] or "CENTER",
        tonumber(point[3]) or 0, tonumber(point[4]) or 0)
    if ns.Rolls then ns.Rolls.Soon() end
end

function Anchor.ResetPosition()
    if ns.db then
        local default = ns.defaults.point
        ns.db.point = { default[1], default[2], default[3], default[4] }
    end
    Anchor.Restore()
    Anchor.Refresh()
end

-- ---------------------------------------------------------
-- Show, hide, refresh
-- ---------------------------------------------------------
function Anchor.IsPlacing()
    return handle:IsShown()
end

function Anchor.Show()
    if not ns.db or not ns.db.enabled then
        ns.Print(L.DISABLED)
        return
    end
    handle:Show()
    Anchor.Refresh()
    ns.Print(L.PLACING)
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function Anchor.Hide()
    handle:Hide()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function Anchor.Toggle()
    if Anchor.IsPlacing() then
        Anchor.Hide()
    else
        Anchor.Show()
    end
end

-- Everything the settings can change about the anchor, in one place
function Anchor.Refresh()
    local db = ns.db
    if not db then return end

    local width, height = BarSize()
    local scale = ns.ClampScale(db.scale)
    anchor:SetSize(width * scale, height * scale)
    anchor:SetClampedToScreen(db.clamp ~= false)

    local growUp = db.growUp ~= false
    arrow:SetTexture(growUp and ARROW_UP or ARROW_DOWN)

    title:SetText(L.ANCHOR_TITLE)
    hint:SetText(L.ANCHOR_HINT)
    hint2:SetText(L.ANCHOR_HINT2)
end
