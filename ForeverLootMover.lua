local ADDON_NAME, ns = ...
local L, Persist = ns.L, ns.Persist

-- =========================================================
-- FOREVERLOOTMOVER
-- =========================================================
-- The group loot roll bars show up in the middle of the screen, right on top of
-- everything you are looking at while the raid rolls. This moves them, resizes
-- them and stacks them the way you want, and keeps that position no matter how
-- often the game puts them back (see Rolls.lua).
--
-- Written for the Forever beta: no global Blizzard function name is hooked, so
-- a build that renames the loot code does not break the addon, and the position
-- is kept through Persist.lua because SavedVariables do not survive a restart
-- on this client.
ns.VERSION = GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version") or "1.0"
if C_AddOns and C_AddOns.GetAddOnMetadata then
    ns.VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or ns.VERSION
end

ns.defaults = {
    enabled = true,
    scale = 1,
    spacing = 3,          -- Pixels between two stacked bars
    growUp = true,        -- New bars pile up above the first one
    clamp = true,         -- Cannot be dragged off screen
    smooth = true,        -- Fade in, and slide back into place when a roll ends
    moveAlerts = true,    -- The "You received" toast lands on the anchor too
    minimapButton = true,
    minimapAngle = 200,
    locale = "auto",

    -- Learned from a real roll bar the first time one shows up, so the
    -- placement frame has the size this build actually uses
    barWidth = 277,
    barHeight = 67,

    point = { "CENTER", "CENTER", 0, 140 },
}

local GOLD = "|cffffd100"

function ns.Print(text)
    DEFAULT_CHAT_FRAME:AddMessage(GOLD .. "LootMover|r  " .. tostring(text))
end

function ns.ClampScale(value)
    value = tonumber(value) or 1
    if value < 0.5 then return 0.5 end
    if value > 3 then return 3 end
    return math.floor(value * 100 + 0.5) / 100
end

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

-- ---------------------------------------------------------
-- Settings changed, from the options panel or a slash command
-- ---------------------------------------------------------
function ns.SettingsChanged()
    if not ns.db then return end
    ns.db.scale = ns.ClampScale(ns.db.scale)

    if not ns.db.enabled then
        if ns.Anchor.IsPlacing() then ns.Anchor.Hide() end
        if ns.Test.IsShown() then ns.Test.Hide() end
    end
    if not ns.db.smooth or not ns.db.enabled then ns.Rolls.ResetAlpha() end
    ns.Anchor.Refresh()
    ns.Test.Layout()
    ns.Rolls.Soon()
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.SetEnabled(enabled)
    ns.db.enabled = enabled and true or false
    ns.SettingsChanged()
    ns.Print(ns.db.enabled and L.TURNED_ON or L.TURNED_OFF)
end

function ns.ResetAll()
    for key in pairs(ns.db) do ns.db[key] = nil end
    CopyDefaults(ns.defaults, ns.db)
    ns.Anchor.Restore()
    ns.SettingsChanged()
    ns.LanguageChanged()
    ns.Print(L.RESET_DONE)
end

-- ---------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------
SLASH_FOREVERLOOTMOVER1 = "/flm"
SLASH_FOREVERLOOTMOVER2 = "/lootmover"
SlashCmdList.FOREVERLOOTMOVER = function(msg)
    local command, rest = strsplit(" ", strtrim(msg or ""), 2)
    command = (command or ""):lower()
    rest = strtrim(rest or "")

    if command == "" or command == "move" or command == "place" or command == "anchor" then
        ns.Anchor.Toggle()
    elseif command == "options" or command == "config" then
        ns.ToggleOptions()
    elseif command == "on" then
        ns.SetEnabled(true)
    elseif command == "off" then
        ns.SetEnabled(false)
    elseif command == "toggle" then
        ns.SetEnabled(not ns.db.enabled)
    elseif command == "up" then
        ns.db.growUp = true
        ns.SettingsChanged()
    elseif command == "down" then
        ns.db.growUp = false
        ns.SettingsChanged()
    elseif command == "scale" or command == "size" then
        local value = tonumber(rest)
        if value and value > 5 then value = value / 100 end -- 120 reads as 120%
        if value and value >= 0.5 and value <= 3 then
            ns.db.scale = ns.ClampScale(value)
            ns.SettingsChanged()
            ns.Print(string.format(L.SCALE_SET, math.floor(ns.db.scale * 100 + 0.5)))
        else
            ns.Print(L.SCALE_INVALID)
        end
    elseif command == "spacing" or command == "gap" then
        local value = tonumber(rest)
        if value and value >= 0 and value <= 30 then
            ns.db.spacing = math.floor(value + 0.5)
            ns.SettingsChanged()
        else
            ns.Print(L.HELP)
        end
    elseif command == "test" then
        ns.Test.Toggle()
    elseif command == "minimap" or command == "button" then
        ns.db.minimapButton = not ns.db.minimapButton
        ns.SettingsChanged()
        ns.Print(ns.db.minimapButton and L.MINIMAP_ON or L.MINIMAP_OFF)
    elseif command == "reset" then
        ns.Anchor.ResetPosition()
        ns.Print(L.POSITION_RESET)
    elseif command == "resetall" then
        ns.ResetAll()
    elseif command == "scan" then
        ns.Rolls.Scan(ns.Print)
        if ns.Rolls.Count() == 0 then ns.Print(L.NOT_FOUND) end
    elseif command == "debug" then
        ns.Rolls.Scan(ns.Print)
        if Persist and Persist.Debug then Persist.Debug(ns.Print) end
    else
        ns.Print(L.HELP)
    end
end

function ForeverLootMover_OnAddonCompartmentClick()
    ns.ToggleOptions()
end

-- ---------------------------------------------------------
-- Settings copy for the Forever beta saving bug (see Persist.lua)
-- ---------------------------------------------------------
-- A macro body holds 255 characters, so the anchor points are stored as short
-- codes. _savedAt comes first, which lets new fields be appended later without
-- breaking a macro written by an older version.
local POINT_CODES = {
    CENTER = "C", TOP = "T", BOTTOM = "B", LEFT = "L", RIGHT = "R",
    TOPLEFT = "TL", TOPRIGHT = "TR", BOTTOMLEFT = "BL", BOTTOMRIGHT = "BR",
}
local CODE_POINTS = {}
for name, code in pairs(POINT_CODES) do CODE_POINTS[code] = name end

local MACRO_FIELDS = {
    "_savedAt", "enabled", "scale", "spacing", "growUp", "clamp", "smooth",
    "moveAlerts",
    "minimapButton", "minimapAngle", "locale", "barWidth", "barHeight",
}

local function EncodeMacro(db)
    local parts = {}
    for i, key in ipairs(MACRO_FIELDS) do
        local v = db[key]
        if type(v) == "boolean" then v = v and "t" or "f" end
        if type(v) == "number" then v = tostring(math.floor(v * 100 + 0.5) / 100) end
        parts[i] = tostring(v or "")
    end
    local point = db.point or ns.defaults.point
    parts[#parts + 1] = POINT_CODES[point[1] or "CENTER"] or "C"
    parts[#parts + 1] = POINT_CODES[point[2] or "CENTER"] or "C"
    parts[#parts + 1] = tostring(math.floor((tonumber(point[3]) or 0) + 0.5))
    parts[#parts + 1] = tostring(math.floor((tonumber(point[4]) or 0) + 0.5))
    return table.concat(parts, ",")
end

local function DecodeMacro(data)
    local values = { strsplit(",", data) }
    if not tonumber(values[1]) then return nil end
    local db = {}
    for i, key in ipairs(MACRO_FIELDS) do
        local v = values[i]
        if v == "t" then db[key] = true
        elseif v == "f" then db[key] = false
        elseif tonumber(v) then db[key] = tonumber(v)
        elseif v and v ~= "" then db[key] = v end
    end
    local base = #MACRO_FIELDS
    local point = CODE_POINTS[values[base + 1] or ""]
    local relativePoint = CODE_POINTS[values[base + 2] or ""]
    if point and relativePoint then
        db.point = { point, relativePoint,
            tonumber(values[base + 3]) or 0, tonumber(values[base + 4]) or 0 }
    end
    return db
end

-- ---------------------------------------------------------
-- Events
-- ---------------------------------------------------------
local events = CreateFrame("Frame")

-- An event name this build does not know would raise, so each one is tried
local function Listen(event)
    pcall(events.RegisterEvent, events, event)
end

Listen("ADDON_LOADED")
Listen("PLAYER_LOGIN")
Listen("PLAYER_ENTERING_WORLD")
Listen("START_LOOT_ROLL")
Listen("CANCEL_LOOT_ROLL")
Listen("CONFIRM_LOOT_ROLL")
Listen("LOOT_ROLLS_COMPLETE")
Listen("LOOT_HISTORY_ROLL_CHANGED")
-- The "You received" toast, so it is put in place the moment it shows up
Listen("SHOW_LOOT_TOAST")
Listen("SHOW_LOOT_TOAST_UPGRADE")
Listen("LOOT_ITEM_ROLL_WON")
Listen("SHOW_PVP_FACTION_LOOT_TOAST")

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        ForeverLootMoverDB = CopyDefaults(ns.defaults, ForeverLootMoverDB or {})
        ns.db = ForeverLootMoverDB

        Persist.Register("ForeverLootMoverDB", function() return ForeverLootMoverDB end, function(saved)
            Persist.Replace(ForeverLootMoverDB, saved, ns.defaults)
            ns.Anchor.Restore()
            ns.SettingsChanged()
            ns.LanguageChanged()
        end, { name = "ForeverLootMover", encode = EncodeMacro, decode = DecodeMacro })

        ns.Anchor.Restore()
        ns.Anchor.Refresh()
        ns.Rolls.Start()
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
        return
    end

    if event == "PLAYER_LOGIN" then
        ns.Anchor.Restore()
        ns.Anchor.Refresh()
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
        ns.Print("v" .. ns.VERSION .. " " .. L.WELCOME)
    end

    -- A real roll wants its frames back: the test is borrowing them
    if event == "START_LOOT_ROLL" and ns.Test.IsShown() then
        ns.Test.Hide()
    end

    -- Any loot event is a good moment to check the bars again. The hooks and the
    -- ticker in Rolls.lua do the real work; this just reacts a frame earlier.
    ns.Rolls.Soon()
end)
