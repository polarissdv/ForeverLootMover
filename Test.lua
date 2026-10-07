local ADDON_NAME, ns = ...
local L = ns.L

-- =========================================================
-- TEST ROLL: the real bar, with a real item, on demand
-- =========================================================
-- This build keeps GroupLootFrame1..4 around all the time but hands out no
-- template to copy (/flm scan says so), so the test borrows one of the real
-- bars instead of building a lookalike. Everything you see is the game's own
-- frame, with its own art, in its own place.
--
-- Borrowing means: remember its scripts, take them all off, fill it in, show
-- it. Nothing is ever asked of the loot API about a roll that is not happening,
-- and the frame is handed back untouched when the test ends, when you end it,
-- or the moment a real roll starts.
local Test = {}
ns.Test = Test

local BAR_COUNT = 2
local DURATION = 30
local SCRIPTS = { "OnShow", "OnHide", "OnUpdate", "OnEvent", "OnEnter", "OnLeave", "OnClick" }
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Name, icon and quality are only a fallback: whatever the client knows about
-- the item wins, so the bar shows the real thing once it is cached.
-- The name is deliberately not ITEMS: that one is already a Blizzard global.
local TEST_ITEMS = {
    { id = 19019, name = "Thunderfury, Blessed Blade of the Windseeker",
      icon = "Interface\\Icons\\INV_Sword_39", quality = 5 },
    { id = 18832, name = "Brutality Blade",
      icon = "Interface\\Icons\\INV_Sword_30", quality = 4 },
}

local borrowed = {}

-- ---------------------------------------------------------
-- Finding the pieces to fill in
-- ---------------------------------------------------------
local function TypeOf(object)
    if type(object) ~= "table" or type(object.GetObjectType) ~= "function" then return nil end
    local ok, kind = pcall(object.GetObjectType, object)
    return ok and kind or nil
end

-- Only the pieces we can name. A real frame is being borrowed here, so guessing
-- from the regions could repaint its background with an item icon.
local function PieceOfType(candidates, kind)
    for _, candidate in ipairs(candidates) do
        if TypeOf(candidate) == kind then return candidate end
    end
    return nil
end

local function NormalTextureOf(object)
    if type(object) ~= "table" or type(object.GetNormalTexture) ~= "function" then return nil end
    local ok, texture = pcall(object.GetNormalTexture, object)
    return ok and texture or nil
end

local function IsShownSafe(frame)
    local ok, shown = pcall(frame.IsShown, frame)
    return ok and shown or false
end

local function TextureInfo(texture)
    local file, atlas
    if type(texture.GetTexture) == "function" then
        local ok, value = pcall(texture.GetTexture, texture)
        if ok then file = value end
    end
    if type(texture.GetAtlas) == "function" then
        local ok, value = pcall(texture.GetAtlas, texture)
        if ok then atlas = value end
    end
    return file, atlas
end

-- The texture of an item button that actually carries the item picture: the one
-- already showing an icon file, or failing that its normal texture.
local function IconTextureOf(button)
    if type(button) ~= "table" then return nil end
    if type(button.GetRegions) == "function" then
        local ok, regions = pcall(function() return { button:GetRegions() } end)
        if ok then
            for _, region in ipairs(regions) do
                if TypeOf(region) == "Texture" then
                    local file = TextureInfo(region)
                    file = tostring(file or ""):lower()
                    if file:find("icons") or file:find("inv_") then return region end
                end
            end
        end
    end
    return NormalTextureOf(button)
end

local function FindPieces(frame)
    local name = frame.GetName and frame:GetName()
    local iconFrame = name and _G[name .. "IconFrame"]
    local buttons = ns.Rolls.Buttons(frame)
    local iconButton = buttons and buttons.icon

    frame.lrmIcon = PieceOfType({
        frame.IconFrame and frame.IconFrame.Icon,
        frame.Icon,
        name and _G[name .. "IconFrameIcon"],
        NormalTextureOf(iconFrame),
        iconButton and iconButton.Icon,
        IconTextureOf(iconButton),
    }, "Texture")
    frame.lrmIconButton = iconButton or frame.IconFrame

    frame.lrmName = PieceOfType({
        frame.Name,
        frame.ItemName,
        name and _G[name .. "Name"],
    }, "FontString")

    frame.lrmTimer = PieceOfType({
        frame.Timer,
        name and _G[name .. "Timer"],
    }, "StatusBar")
end

local function QualityColor(quality)
    local colors = _G.ITEM_QUALITY_COLORS
    local color = type(colors) == "table" and colors[quality or 4]
    if type(color) == "table" and color.r then return color.r, color.g, color.b end
    return 0.64, 0.21, 0.93
end

local function Fill(frame, item)
    if type(item) ~= "table" then return end
    local name, quality, icon = item.name, item.quality, item.icon

    local okInfo, infoName, _, infoQuality, _, _, _, _, _, _, infoIcon = pcall(GetItemInfo, item.id)
    if okInfo and infoName then
        name = infoName
        quality = infoQuality or quality
        icon = infoIcon or icon
    end

    if frame.lrmIcon then
        pcall(frame.lrmIcon.SetTexture, frame.lrmIcon, icon)
        if not frame.lrmIcon:GetTexture() then
            pcall(frame.lrmIcon.SetTexture, frame.lrmIcon, QUESTION_MARK)
        end
    end
    -- The way the default UI fills an item button, for a build that keeps its
    -- icon somewhere we did not think of
    if frame.lrmIconButton and type(_G.SetItemButtonTexture) == "function" then
        pcall(_G.SetItemButtonTexture, frame.lrmIconButton, icon)
    end
    if frame.lrmName then
        pcall(frame.lrmName.SetText, frame.lrmName, name)
        pcall(frame.lrmName.SetTextColor, frame.lrmName, QualityColor(quality))
    end
    if frame.lrmTimer then
        pcall(frame.lrmTimer.SetMinMaxValues, frame.lrmTimer, 0, DURATION)
        pcall(frame.lrmTimer.SetValue, frame.lrmTimer, DURATION)
    end
end

-- ---------------------------------------------------------
-- Borrowing and handing back
-- ---------------------------------------------------------
local function Borrow(frame)
    local saved = { frame = frame, scripts = {}, mouse = {} }

    for _, script in ipairs(SCRIPTS) do
        local ok, handler = pcall(frame.GetScript, frame, script)
        if ok and handler then saved.scripts[script] = handler end
        pcall(frame.SetScript, frame, script, nil)
    end
    pcall(frame.UnregisterAllEvents, frame)

    saved.rollID = frame.rollID
    frame.rollID = nil

    -- The buttons and the icon ask the loot API about the roll on hover and on
    -- click, so they go deaf for the length of the test
    local okChildren, children = pcall(function() return { frame:GetChildren() } end)
    if okChildren then
        for _, child in ipairs(children) do
            local okMouse, enabled = pcall(child.IsMouseEnabled, child)
            saved.mouse[child] = okMouse and enabled or false
            pcall(child.EnableMouse, child, false)
        end
    end

    -- A real bar keeps whatever its last roll left on the buttons, and this
    -- build leaves a transmog icon sitting there. The test shows the three we
    -- roll with, each in its own art, and nothing else.
    -- A bar keeps whatever its last roll left on its buttons: one of them hidden
    -- because that roll did not offer it, the transmog square shown on top of
    -- the greed one. The test shows every roll button this build has and takes
    -- the transmog one off, in their own art - nothing is repainted.
    saved.art = {}
    saved.shown = {}
    local buttons = ns.Rolls.Buttons(frame)
    if buttons then
        for _, button in ipairs(buttons.rolls) do
            saved.shown[button] = IsShownSafe(button)
            pcall(button.Show, button)
        end
        for _, button in ipairs(buttons.extras) do
            saved.shown[button] = IsShownSafe(button)
            pcall(button.Hide, button)
        end
    end

    FindPieces(frame)
    return saved
end

local function GiveBack(saved)
    local frame = saved.frame
    pcall(frame.SetScript, frame, "OnUpdate", nil)
    pcall(frame.Hide, frame)

    for texture, art in pairs(saved.art) do
        if art.atlas and art.atlas ~= "" then
            pcall(texture.SetAtlas, texture, art.atlas)
        else
            pcall(texture.SetTexture, texture, art.file)
        end
    end
    for button, shown in pairs(saved.shown) do
        if shown then pcall(button.Show, button) else pcall(button.Hide, button) end
    end
    for child, enabled in pairs(saved.mouse) do
        pcall(child.EnableMouse, child, enabled)
    end
    for script, handler in pairs(saved.scripts) do
        pcall(frame.SetScript, frame, script, handler)
    end
    frame.rollID = saved.rollID
end

-- ---------------------------------------------------------
-- Showing and hiding
-- ---------------------------------------------------------
function Test.IsShown()
    return #borrowed > 0
end

function Test.Hide()
    if #borrowed == 0 then return end
    for _, saved in ipairs(borrowed) do
        GiveBack(saved)
    end
    wipe(borrowed)
    if ns.Rolls then ns.Rolls.Soon() end
    if ns.RefreshOptions then ns.RefreshOptions() end
end

-- The real bars live inside the loot container, which some builds keep hidden
-- while nothing is being rolled on
local function ShowContainer()
    local container = ns.Rolls and ns.Rolls.Container()
    if container and not container:IsShown() then
        pcall(container.Show, container)
    end
end

function Test.Show()
    if not ns.db or not ns.db.enabled then
        ns.Print(L.DISABLED)
        return
    end
    Test.Hide()

    local frames = ns.Rolls.Bars()
    if #frames == 0 then
        ns.Print(L.TEST_UNAVAILABLE)
        return
    end

    ShowContainer()

    local count = math.min(BAR_COUNT, #frames)
    for index = 1, count do
        local frame = frames[index]
        local saved = Borrow(frame)
        borrowed[#borrowed + 1] = saved

        Fill(frame, TEST_ITEMS[((index - 1) % #TEST_ITEMS) + 1])
        frame.lrmLeft = DURATION
        pcall(frame.Show, frame)

        -- Our own countdown, so the bar behaves like a real roll and goes away
        frame:SetScript("OnUpdate", function(self, elapsed)
            self.lrmLeft = (self.lrmLeft or 0) - elapsed
            if self.lrmLeft <= 0 then
                Test.Hide()
                return
            end
            if self.lrmTimer then
                pcall(self.lrmTimer.SetValue, self.lrmTimer, self.lrmLeft)
            end
        end)
    end

    -- Rolls.lua puts every shown bar on the anchor, these included
    ns.Rolls.Soon()
    ns.Print(L.TEST_SHOWN)
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function Test.Toggle()
    if Test.IsShown() then
        Test.Hide()
    else
        Test.Show()
    end
end

-- Kept for the settings: the bars are laid out by Rolls.lua like any other
function Test.Layout()
    if Test.IsShown() and ns.Rolls then ns.Rolls.Soon() end
end
