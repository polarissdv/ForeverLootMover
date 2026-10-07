local ADDON_NAME, ns = ...
local L = ns.L

-- =========================================================
-- MINIMAP BUTTON
-- =========================================================
-- Left-click: place the bars  ·  Right-click: options  ·  Drag: move it around
--
-- The addon artwork, with the need die off the loot roll bar as a fallback:
-- that one is a texture every build is sure to have.
local ICON = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\icon"
local ICON_FALLBACK = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
local GOLD = { 1, 0.82, 0.35 }

local mm = CreateFrame("Button", "ForeverLootMoverMinimapButton", Minimap)
mm:SetSize(31, 31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mm:RegisterForDrag("LeftButton")
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mm:Hide()

local background = mm:CreateTexture(nil, "BACKGROUND")
background:SetSize(24, 24)
background:SetPoint("CENTER")
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

local icon = mm:CreateTexture(nil, "ARTWORK")
icon:SetSize(21, 21)
icon:SetPoint("CENTER")
icon:SetTexture(ICON)
if not icon:GetTexture() then icon:SetTexture(ICON_FALLBACK) end

local border = mm:CreateTexture(nil, "OVERLAY")
border:SetSize(50, 50)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function UpdatePosition()
    local angle = math.rad((ns.db and ns.db.minimapAngle) or 200)
    local radius = (Minimap:GetWidth() / 2) + 5
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function ns.UpdateMinimapButton()
    if not ns.db then return end
    mm:SetShown(ns.db.minimapButton and ns.db.enabled)
    icon:SetDesaturated(not ns.db.enabled)
    UpdatePosition()
end

mm:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        ns.db.minimapAngle = math.floor(math.deg(math.atan2(py / scale - my, px / scale - mx)) + 0.5)
        UpdatePosition()
    end)
    GameTooltip:Hide()
end)
mm:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

mm:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        ns.ToggleOptions()
    else
        ns.Anchor.Toggle()
    end
    if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
end)

mm:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("ForeverLootMover", GOLD[1], GOLD[2], GOLD[3])
    GameTooltip:AddLine(L.SUBTITLE, 1, 1, 1, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.TT_PLACE, 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L.TT_OPTIONS, 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
