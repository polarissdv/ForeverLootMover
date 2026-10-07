local ADDON_NAME, ns = ...
local L = ns.L

-- =========================================================
-- OPTIONS MENU (same native style as the other Forever addons)
-- =========================================================
local PANEL_WIDTH = 420
local PAD = 26
local CONTENT_W = PANEL_WIDTH - PAD * 2
local HALF_W = CONTENT_W / 2 - 10
local AUTHOR = "Made by Polarz141"
local ICON = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\icon"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local GOLD = { 1, 0.82, 0.35 }

local refreshers = {}

local function PlaySoundKey(key)
    if SOUNDKIT and SOUNDKIT[key] then PlaySound(SOUNDKIT[key]) end
end

local function SetGradient(tex, orientation, r, g, b, a1, a2)
    tex:SetTexture(WHITE)
    local ok = CreateColor and pcall(tex.SetGradient, tex, orientation, CreateColor(r, g, b, a1), CreateColor(r, g, b, a2))
    if not ok then tex:SetVertexColor(r, g, b, (a1 + a2) / 2) end
end

local function MakeRound(tex)
    local parent = tex:GetParent()
    if not parent.CreateMaskTexture or not tex.AddMaskTexture then return end
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
end

local function Diamond(parent, size, layer)
    local d = parent:CreateTexture(nil, layer or "ARTWORK")
    d:SetTexture(WHITE)
    d:SetSize(size, size)
    d:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    d:SetRotation(math.rad(45))
    return d
end

local function Ornament(parent, width)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 10)
    local center = Diamond(holder, 8)
    center:SetPoint("CENTER")
    local left = holder:CreateTexture(nil, "ARTWORK")
    left:SetHeight(1)
    left:SetPoint("LEFT")
    left:SetPoint("RIGHT", center, "LEFT", -7, 0)
    SetGradient(left, "HORIZONTAL", GOLD[1], GOLD[2], GOLD[3], 0, 0.9)
    local right = holder:CreateTexture(nil, "ARTWORK")
    right:SetHeight(1)
    right:SetPoint("RIGHT")
    right:SetPoint("LEFT", center, "RIGHT", 7, 0)
    SetGradient(right, "HORIZONTAL", GOLD[1], GOLD[2], GOLD[3], 0.9, 0)
    return holder
end

local function MakeFont(name, size, outline, path)
    local font = CreateFont(name)
    font:SetFont(path or "Fonts\\MORPHEUS.TTF", size, outline)
    font:SetShadowOffset(1, -1)
    font:SetShadowColor(0, 0, 0, 1)
    return font
end
local FontTitle = MakeFont("ForeverLootMoverOptTitle", 26, "OUTLINE")
local FontSection = MakeFont("ForeverLootMoverOptSection", 17, "OUTLINE")
local FontSmall = MakeFont("ForeverLootMoverOptSmall", 13, "")

-- =========================================================
-- MAIN PANEL
-- =========================================================
local panel = CreateFrame("Frame", "ForeverLootMoverOptionsFrame", UIParent, "BackdropTemplate")
panel:SetSize(PANEL_WIDTH, 520)
panel:SetPoint("CENTER")
panel:SetFrameStrata("HIGH")
panel:SetToplevel(true)
panel:SetMovable(true)
panel:SetClampedToScreen(true)
panel:EnableMouse(true)
panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
panel:Hide()
tinsert(UISpecialFrames, "ForeverLootMoverOptionsFrame") -- Escape closes the menu

local topGlow = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
topGlow:SetPoint("TOPLEFT", 12, -12)
topGlow:SetPoint("TOPRIGHT", -12, -12)
topGlow:SetHeight(120)
SetGradient(topGlow, "VERTICAL", 0.55, 0.45, 0.2, 0, 0.3)

local header = CreateFrame("Frame", nil, panel)
header:SetPoint("TOPLEFT")
header:SetPoint("TOPRIGHT")
header:SetHeight(76)
header:EnableMouse(true)
header:SetScript("OnMouseDown", function() panel:StartMoving() end)
header:SetScript("OnMouseUp", function() panel:StopMovingOrSizing() end)

local crest = CreateFrame("Frame", nil, panel)
crest:SetSize(48, 48)
crest:SetPoint("CENTER", panel, "TOP", 0, -2)
crest:SetFrameLevel(panel:GetFrameLevel() + 10)
local crestIcon = crest:CreateTexture(nil, "ARTWORK")
crestIcon:SetAllPoints()
crestIcon:SetTexture(ICON)

local title = panel:CreateFontString(nil, "OVERLAY")
title:SetFontObject(FontTitle)
title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
title:SetPoint("TOP", 0, -32)
title:SetText("ForeverLootMover")

local titleOrnament = Ornament(panel, 280)
titleOrnament:SetPoint("TOP", title, "BOTTOM", 0, -4)

local subtitle = panel:CreateFontString(nil, "OVERLAY")
subtitle:SetFontObject(FontSmall)
subtitle:SetTextColor(0.75, 0.68, 0.52)
subtitle:SetPoint("TOP", titleOrnament, "BOTTOM", 0, -4)
subtitle:SetWidth(CONTENT_W)
tinsert(refreshers, function() subtitle:SetText("v" .. (ns.VERSION or "1.0") .. "  |cff806030.|r  " .. L.SUBTITLE) end)

local closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -6, -6)

local cursorY = -104

-- =========================================================
-- WIDGETS
-- =========================================================
local function Section(key)
    cursorY = cursorY - 6
    local label = panel:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(FontSection)
    label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    label:SetPoint("TOPLEFT", PAD, cursorY)
    tinsert(refreshers, function() label:SetText(L[key]) end)

    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", label, "TOPRIGHT", 10, -9)
    line:SetPoint("TOPRIGHT", panel, "TOPLEFT", PANEL_WIDTH - PAD, cursorY - 9)
    SetGradient(line, "HORIZONTAL", GOLD[1], GOLD[2], GOLD[3], 0.7, 0)

    cursorY = cursorY - 26
end

local function CreateSlider(key, x, width, minV, maxV, step, dbKey, formatValue)
    local holder = CreateFrame("Frame", nil, panel)
    holder:SetSize(width, 42)
    holder:SetPoint("TOPLEFT", PAD + x, cursorY)

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT")
    tinsert(refreshers, function() label:SetText(L[key]) end)

    local valueText = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("TOPRIGHT")

    local slider = CreateFrame("Slider", nil, holder)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(width, 18)
    slider:SetPoint("TOPLEFT", 0, -20)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    if slider.SetObeyStepDuringDrag then slider:SetObeyStepDuringDrag(true) end
    slider:SetHitRectInsets(0, 0, -4, -4)

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0, 0, 0, 0.6)
    track:SetHeight(6)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(WHITE)
    thumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    thumb:SetSize(12, 12)
    MakeRound(thumb)
    slider:SetThumbTexture(thumb)

    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(6)
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")
    SetGradient(fill, "HORIZONTAL", GOLD[1], GOLD[2], GOLD[3], 0.45, 0.95)

    local updating = false
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        valueText:SetText(formatValue(value))
        if not updating then
            ns.db[dbKey] = value
            ns.SettingsChanged()
        end
    end)

    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + delta * step)
    end)
    slider:SetScript("OnEnter", function() thumb:SetSize(14, 14) end)
    slider:SetScript("OnLeave", function() thumb:SetSize(12, 12) end)

    tinsert(refreshers, function()
        updating = true
        slider:SetValue(ns.db[dbKey] or minV)
        valueText:SetText(formatValue(ns.db[dbKey] or minV))
        updating = false
    end)
end

local function CreateCheck(key, descKey, getValue, setValue)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", PAD, cursorY)
    cursorY = cursorY - 26

    local templateText = check.Text or check.text
    if templateText then templateText:SetText("") end

    local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 4, 1)
    label:SetWidth(CONTENT_W - 30)
    label:SetJustifyH("LEFT")
    tinsert(refreshers, function() label:SetText(L[key]) end)

    check:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
        PlaySoundKey(self:GetChecked() and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
    end)
    check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[key])
        GameTooltip:AddLine(L[descKey], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function() GameTooltip:Hide() end)

    tinsert(refreshers, function() check:SetChecked(getValue()) end)
end

local function OptionCheck(key, descKey, dbKey)
    CreateCheck(key, descKey,
        function() return ns.db[dbKey] end,
        function(v)
            ns.db[dbKey] = v
            ns.SettingsChanged()
        end)
end

local function CreateButton(width, x, label, onClick)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(width, 26)
    button:SetPoint("TOPLEFT", PAD + x, cursorY)
    button:SetText(label)
    button:SetScript("OnClick", function(self)
        PlaySoundKey("IG_MAINMENU_OPTION_CHECKBOX_ON")
        onClick(self)
    end)
    return button
end

-- =========================================================
-- CONTENT
-- =========================================================
Section("SECTION_GENERAL")
OptionCheck("ENABLED", "ENABLED_DESC", "enabled")
OptionCheck("MINIMAP_BUTTON", "MINIMAP_BUTTON_DESC", "minimapButton")
OptionCheck("CLAMP", "CLAMP_DESC", "clamp")
OptionCheck("ALERTS", "ALERTS_DESC", "moveAlerts")
OptionCheck("SMOOTH", "SMOOTH_DESC", "smooth")
cursorY = cursorY - 8

Section("SECTION_POSITION")
OptionCheck("GROW_UP", "GROW_UP_DESC", "growUp")
cursorY = cursorY - 10

CreateSlider("SCALE", 0, HALF_W, 0.5, 3, 0.05, "scale", function(v)
    return string.format("%d%%", math.floor(v * 100 + 0.5))
end)
CreateSlider("SPACING", CONTENT_W - HALF_W, HALF_W, 0, 30, 1, "spacing", function(v)
    return string.format("%d px", v)
end)
cursorY = cursorY - 52

local placeButton = CreateButton(HALF_W, 0, "", function()
    ns.Anchor.Toggle()
end)
tinsert(refreshers, function()
    placeButton:SetText(ns.Anchor.IsPlacing() and L.HIDE_PLACE or L.PLACE)
end)

local testButton = CreateButton(HALF_W, CONTENT_W - HALF_W, "", function()
    ns.Test.Toggle()
end)
tinsert(refreshers, function()
    testButton:SetText(ns.Test.IsShown() and L.TEST_HIDE or L.TEST)
end)
cursorY = cursorY - 32

local resetPositionButton = CreateButton(CONTENT_W, 0, "", function()
    ns.Anchor.ResetPosition()
    ns.Print(L.POSITION_RESET)
end)
tinsert(refreshers, function() resetPositionButton:SetText(L.RESET_POSITION) end)
cursorY = cursorY - 40

-- Footer
local footerOrnament = Ornament(panel, CONTENT_W)
footerOrnament:SetPoint("TOP", panel, "TOP", 0, cursorY)
cursorY = cursorY - 18

-- Language: three buttons instead of a drop-down, there are only two of them
local langLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
langLabel:SetPoint("TOPLEFT", PAD, cursorY + 6)
tinsert(refreshers, function() langLabel:SetText(L.LANGUAGE) end)

local langButtons = {}
local LANG_KEYS = { "auto", "en", "fr" }
local LANG_NAMES = { auto = "Auto", en = "English", fr = "Francais" }
for i, code in ipairs(LANG_KEYS) do
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(78, 22)
    button:SetPoint("TOPRIGHT", -PAD - (3 - i) * 82, cursorY + 4)
    button:SetText(LANG_NAMES[code])
    button:SetScript("OnClick", function()
        if ns.db.locale == code then return end
        PlaySoundKey("IG_MAINMENU_OPTION_CHECKBOX_ON")
        ns.db.locale = code
        ns.LanguageChanged()
    end)
    button.code = code
    langButtons[i] = button
end
tinsert(refreshers, function()
    for _, button in ipairs(langButtons) do
        local selected = (ns.db.locale or "auto") == button.code
        button:SetEnabled(not selected)
        button:GetFontString():SetTextColor(selected and GOLD[1] or 1, selected and GOLD[2] or 0.82, selected and GOLD[3] or 0.35)
    end
end)
cursorY = cursorY - 34

-- Two clicks: a reset cannot be undone
local resetArmed = false
local resetButton = CreateButton(CONTENT_W, 0, "", function(self)
    if not resetArmed then
        resetArmed = true
        self:SetText(L.CONFIRM)
        C_Timer.After(4, function()
            resetArmed = false
            self:SetText(L.RESET_ALL)
        end)
        return
    end
    resetArmed = false
    ns.ResetAll()
    ns.RefreshOptions()
end)
tinsert(refreshers, function()
    if not resetArmed then resetButton:SetText(L.RESET_ALL) end
end)
cursorY = cursorY - 40

local signature = panel:CreateFontString(nil, "OVERLAY")
signature:SetFontObject(FontSmall)
signature:SetTextColor(0.75, 0.62, 0.35)
signature:SetPoint("TOP", panel, "TOP", 0, cursorY)
signature:SetText(AUTHOR)
local sigLeft = Diamond(panel, 5, "OVERLAY")
sigLeft:SetPoint("RIGHT", signature, "LEFT", -8, 0)
local sigRight = Diamond(panel, 5, "OVERLAY")
sigRight:SetPoint("LEFT", signature, "RIGHT", 8, 0)
cursorY = cursorY - 26

panel:SetHeight(-cursorY)

-- =========================================================
-- OPEN / CLOSE
-- =========================================================
function ns.RefreshOptions()
    if not panel:IsShown() then return end
    if not ns.db then return end
    for _, fn in ipairs(refreshers) do fn() end
end

panel:SetScript("OnShow", function()
    PlaySoundKey("IG_CHARACTER_INFO_OPEN")
    ns.RefreshOptions()
end)
panel:SetScript("OnHide", function()
    PlaySoundKey("IG_CHARACTER_INFO_CLOSE")
end)

function ns.ToggleOptions()
    panel:SetShown(not panel:IsShown())
end
