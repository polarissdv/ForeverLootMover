local ADDON_NAME, ns = ...

-- =========================================================
-- ROLLS: finding and moving the game's loot roll bars
-- =========================================================
-- Nothing in here depends on a global function name. The older movers hook
-- GroupLootContainer_Update, GroupLootFrame_OnShow and friends, so the day the
-- client renames or rewrites that code they silently stop working - which is
-- exactly what happens on the Forever beta.
--
-- Instead the bars are looked up (by name, then by walking the container, then
-- by anything holding a rollID), their own SetPoint is hooked on the object
-- itself, and a slow ticker re-checks the layout while a roll is on screen.
-- Every write goes through SetPointIfNeeded, so a layout that is already right
-- costs nothing at all.
--
-- The bars are not chained to one another: each is pinned straight to the
-- anchor at its own offset. That is what lets a bar leaving the stack slide the
-- others into place instead of snapping them.
local Rolls = {}
ns.Rolls = Rolls

local CHECK_EVERY = 0.2
local MAX_BARS = 8          -- This build has no NUM_GROUP_LOOT_FRAMES, so here is the ceiling
local MIN_BAR_SIZE = 40     -- Anything smaller is not a roll bar: do not learn it
local SLIDE_SPEED = 14      -- Higher slides into place faster
local FADE_TIME = 0.18      -- Seconds for a bar to appear

local bars = {}             -- The roll bars, in stacking order
local hooked = {}
local states = {}           -- bar -> where it is, where it is going, how visible
local applying = false      -- Our own SetPoint calls must not trigger the hooks
local pending = false
local managedCleared = false

-- ---------------------------------------------------------
-- Safety
-- ---------------------------------------------------------
-- A forbidden frame belongs to the client and must not be touched. On the 12.0
-- engine a call on one can raise, so every call goes through pcall.
local function Usable(obj)
    if type(obj) ~= "table" then return false end
    if type(obj.IsForbidden) == "function" then
        local ok, forbidden = pcall(obj.IsForbidden, obj)
        if not ok or forbidden then return false end
    end
    return type(obj.SetPoint) == "function"
        and type(obj.ClearAllPoints) == "function"
        and type(obj.IsShown) == "function"
end

local function FrameName(frame)
    if type(frame) ~= "table" or type(frame.GetName) ~= "function" then return nil end
    local ok, name = pcall(frame.GetName, frame)
    if ok then return name end
    return nil
end

local function IsShownSafe(frame)
    local ok, shown = pcall(frame.IsShown, frame)
    return ok and shown
end

local function HeightOf(bar)
    local ok, height = pcall(bar.GetHeight, bar)
    if ok and height and height > MIN_BAR_SIZE then return height end
    return (ns.db and tonumber(ns.db.barHeight)) or 67
end

-- ---------------------------------------------------------
-- Finding the frames
-- ---------------------------------------------------------
function Rolls.Container()
    local container = _G.GroupLootContainer
    if Usable(container) then return container end
    return nil
end

-- Does this frame look like a loot roll bar?
local function LooksLikeBar(frame)
    if not Usable(frame) then return false end
    if frame.rollID ~= nil then return true end
    local name = FrameName(frame)
    return name ~= nil and name:find("GroupLoot") ~= nil
end

-- Collect runs five times a second, so it keeps its scratch tables around
-- instead of handing the collector a new one every tick.
local seen = {}
local count = 0

local function Add(frame)
    if count >= MAX_BARS then return end
    if Usable(frame) and not seen[frame] and frame ~= (ns.Anchor and ns.Anchor.frame) then
        seen[frame] = true
        count = count + 1
        bars[count] = frame
    end
end

local function Collect()
    local previousCount = #bars
    wipe(seen)
    count = 0

    -- 1. The named bars, in order: this is the stacking order the game uses
    for i = 1, (_G.NUM_GROUP_LOOT_FRAMES or MAX_BARS) do
        Add(_G["GroupLootFrame" .. i])
    end

    -- 2. Only if the names gave nothing: walk the container, for a build that
    -- pools its bars or names them something else entirely
    if count == 0 then
        local container = Rolls.Container()
        if container then
            if type(container.rollFrames) == "table" then
                for _, frame in pairs(container.rollFrames) do
                    if LooksLikeBar(frame) then Add(frame) end
                end
            end
            if count == 0 and type(container.GetChildren) == "function" then
                local ok, children = pcall(function() return { container:GetChildren() } end)
                if ok then
                    for _, frame in ipairs(children) do
                        if LooksLikeBar(frame) then Add(frame) end
                    end
                end
            end
        end
    end

    for i = count + 1, previousCount do bars[i] = nil end
    return count
end

Rolls.Collect = Collect

function Rolls.Count()
    return #bars
end

-- The live list of roll bars, for Test.lua to borrow one
function Rolls.Bars()
    Collect()
    return bars
end

-- Is a roll on screen right now?
function Rolls.Visible()
    for _, bar in ipairs(bars) do
        if IsShownSafe(bar) then return true end
    end
    return false
end

-- ---------------------------------------------------------
-- The roll buttons
-- ---------------------------------------------------------
-- Need, greed and pass are the three this client rolls with. The fourth square
-- - transmog on some builds, disenchant on others - does nothing here and can
-- be taken off the bar from the options.
local function ButtonArt(button)
    if type(button) ~= "table" or type(button.GetNormalTexture) ~= "function" then return "" end
    local ok, texture = pcall(button.GetNormalTexture, button)
    if not ok or type(texture) ~= "table" then return "" end
    local art = ""
    if type(texture.GetTexture) == "function" then
        local okFile, file = pcall(texture.GetTexture, texture)
        if okFile and file then art = art .. tostring(file) end
    end
    if type(texture.GetAtlas) == "function" then
        local okAtlas, atlas = pcall(texture.GetAtlas, texture)
        if okAtlas and atlas then art = art .. " " .. tostring(atlas) end
    end
    return art:lower()
end

-- Sorts the buttons of a bar into need, greed, pass, the item icon, and the
-- extras - anything else the build put there. Going at it the other way round,
-- hiding only what we recognise as transmog, let a differently named button
-- through; here the three we roll with and the icon are the keepers and
-- everything else goes.
--
-- The icon is the only button at the far left of the bar, which is what the
-- leftmost test catches when its name gives nothing away.
-- This build does not hang its roll buttons straight off the bar: the bar has
-- one child, the item icon, and the buttons sit deeper in. So the whole little
-- tree is walked rather than just the first level.
local MAX_DEPTH = 4
local MAX_BUTTONS = 24

local function GatherButtons(frame, out, depth)
    if depth > MAX_DEPTH or #out >= MAX_BUTTONS then return end
    if type(frame.GetChildren) ~= "function" then return end
    local ok, children = pcall(function() return { frame:GetChildren() } end)
    if not ok then return end
    for _, child in ipairs(children) do
        local okType, kind = pcall(child.GetObjectType, child)
        if okType and kind == "Button" then
            out[#out + 1] = child
        end
        GatherButtons(child, out, depth + 1)
    end
end

function Rolls.Buttons(bar)
    local found = bar.lrmButtons
    if found then return found end

    local buttons = {}
    GatherButtons(bar, buttons, 1)
    if #buttons == 0 then return nil end

    -- The item icon is the one thing sitting at the far left of the bar; every
    -- roll button is crowded on the right. So the left third is the icon's,
    -- whatever it is called, and the rest is sorted by what it is wearing.
    local okLeft, barLeft = pcall(bar.GetLeft, bar)
    local okWidth, barWidth = pcall(bar.GetWidth, bar)
    local function InIconArea(button)
        if not (okLeft and okWidth and barLeft and barWidth and barWidth > 0) then return false end
        local okButton, left = pcall(button.GetLeft, button)
        return okButton and left ~= nil and (left - barLeft) < barWidth / 3
    end

    -- What a button wears says what it is. This build names its art by role -
    -- lootroll-toast-icon-need-up, -greed-up, -transmog-up - where other builds
    -- use the old UI-GroupLoot-Dice / Coin / Pass files, so both are read.
    --
    -- Only what is positively recognised as transmog or disenchant is taken
    -- off. A roll button whose art says nothing (the pass button here is a bare
    -- file number) is kept: an unknown button is worth leaving on the bar, and
    -- is never worth a missing need or greed.
    found = { extras = {}, rolls = {} }
    for _, button in ipairs(buttons) do
        local name = (FrameName(button) or ""):lower()
        local art = ButtonArt(button)
        local text = name .. " " .. art
        local kind
        if text:find("transmog") or text:find("disenchant") then kind = "extra"
        elseif text:find("need") or text:find("dice") then kind = "need"
        elseif text:find("greed") or text:find("coin") then kind = "greed"
        elseif text:find("pass") then kind = "pass"
        elseif name:find("icon") or InIconArea(button) then kind = "icon"
        else kind = "roll" end

        if kind == "extra" then
            found.extras[#found.extras + 1] = button
        elseif kind == "icon" then
            if not found.icon then found.icon = button end
        else
            found.rolls[#found.rolls + 1] = button
            if kind ~= "roll" and not found[kind] then found[kind] = button end
        end
    end

    found.art = {}
    for _, button in ipairs(buttons) do
        found.art[button] = ButtonArt(button)
    end

    bar.lrmButtons = found
    return found
end

-- The game shows its buttons again on every roll, so this runs on every pass.
local function ApplyButtons(bar)
    local found = Rolls.Buttons(bar)
    if not found then return end
    for _, button in ipairs(found.extras) do
        if IsShownSafe(button) then pcall(button.Hide, button) end
    end
end

-- ---------------------------------------------------------
-- Hooks: the bars tell us when the game moved them
-- ---------------------------------------------------------
local function Touch()
    if applying then return end
    Rolls.Soon()
end

-- A bar being shown is placed in the same frame, before anything is drawn:
-- waiting for the next one is what makes a bar flash at its default spot first.
local function TouchNow()
    if applying then return end
    Rolls.Apply()
end

local function Hook(frame)
    if not Usable(frame) or hooked[frame] then return end
    hooked[frame] = true
    pcall(hooksecurefunc, frame, "SetPoint", Touch)
    pcall(hooksecurefunc, frame, "ClearAllPoints", Touch)
    if type(frame.HookScript) == "function" then
        pcall(frame.HookScript, frame, "OnShow", TouchNow)
        pcall(frame.HookScript, frame, "OnHide", Touch)
    end
end

-- Apply on the next frame instead of right away: the game is usually in the
-- middle of its own layout pass when a hook fires, so this avoids fighting it.
function Rolls.Soon()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        Rolls.Apply()
    end)
end

-- ---------------------------------------------------------
-- Moving them
-- ---------------------------------------------------------
local function SetPointIfNeeded(frame, point, relative, relativePoint, x, y)
    local ok, currentPoint, currentRelative, currentRelativePoint, currentX, currentY =
        pcall(frame.GetPoint, frame, 1)
    local okCount, points = pcall(frame.GetNumPoints, frame)
    if ok and okCount and points == 1
        and currentPoint == point and currentRelative == relative
        and currentRelativePoint == relativePoint
        and math.abs((currentX or 0) - x) < 0.3
        and math.abs((currentY or 0) - y) < 0.3 then
        return false
    end
    pcall(frame.ClearAllPoints, frame)
    pcall(frame.SetPoint, frame, point, relative, relativePoint, x, y)
    return true
end

local function SetScaleIfNeeded(frame, scale)
    if type(frame.GetScale) ~= "function" then return end
    local ok, current = pcall(frame.GetScale, frame)
    if ok and math.abs((current or 1) - scale) < 0.001 then return end
    pcall(frame.SetScale, frame, scale)
end

-- The game lays the loot container out together with the rest of the default
-- UI. Taking it out of that list is what makes our position stick.
local function FreeContainer(container)
    container.ignoreFramePositionManager = true
    if managedCleared then return end
    managedCleared = true
    local managed = _G.UIPARENT_MANAGED_FRAME_POSITIONS
    if type(managed) == "table" then
        managed["GroupLootContainer"] = nil
    end
    pcall(container.EnableMouse, container, false) -- It swallows clicks otherwise
end

-- Remember how big a real bar is, so the placement frame has the size this
-- build actually uses, even before the first roll of a session.
local function Learn(bar)
    local db = ns.db
    if not db then return end
    local okWidth, width = pcall(bar.GetWidth, bar)
    local okHeight, height = pcall(bar.GetHeight, bar)
    if not okWidth or not okHeight then return end
    if (width or 0) < MIN_BAR_SIZE or (height or 0) < MIN_BAR_SIZE then return end
    width, height = math.floor(width + 0.5), math.floor(height + 0.5)
    if db.barWidth ~= width or db.barHeight ~= height then
        db.barWidth, db.barHeight = width, height
        if ns.Anchor then ns.Anchor.Refresh() end
    end
end

-- ---------------------------------------------------------
-- The "You received" toast
-- ---------------------------------------------------------
-- The toast that announces what you won is not a roll bar: it belongs to the
-- game's alert system, which lays its own frames out from AlertFrame. Two ways
-- in, both guarded, because this build may only have one of them:
--   1. the alert subsystems can be told to measure from our anchor instead;
--   2. failing that, AlertFrame itself is pinned to the anchor.
local alertManagedCleared = false

local function AlertHost()
    local frame = _G.AlertFrame
    if Usable(frame) then return frame end
    return nil
end

-- Is a toast on screen? The host frame is shown even when empty on some
-- builds, so one of its children has to be shown too.
function Rolls.AlertShown()
    local host = AlertHost()
    if not host or not IsShownSafe(host) then return false end
    if type(host.GetChildren) ~= "function" then return false end
    local ok, children = pcall(function() return { host:GetChildren() } end)
    if not ok then return false end
    for _, child in ipairs(children) do
        if IsShownSafe(child) then return true end
    end
    return false
end

-- Hand each subsystem our anchor as the frame to measure from. Their own points
-- are cleared first, otherwise a second pass stacks offset on offset.
local function AnchorSubSystems(host, anchor)
    local subsystems = host.alertFrameSubSystems
    if type(subsystems) ~= "table" then return false end

    local relative = anchor
    local moved = false
    for _, subSystem in ipairs(subsystems) do
        if type(subSystem) == "table" and type(subSystem.AdjustAnchors) == "function" then
            local pool = subSystem.alertFramePool
            if pool and type(pool.EnumerateActive) == "function" then
                local ok, iterator = pcall(pool.EnumerateActive, pool)
                if ok and type(iterator) == "function" then
                    for alert in iterator do
                        pcall(alert.ClearAllPoints, alert)
                    end
                end
            elseif subSystem.alertFrame and type(subSystem.alertFrame.ClearAllPoints) == "function" then
                pcall(subSystem.alertFrame.ClearAllPoints, subSystem.alertFrame)
            end

            local ok, result = pcall(subSystem.AdjustAnchors, subSystem, relative)
            if ok then
                moved = true
                if type(result) == "table" then relative = result end
            end
        end
    end
    return moved
end

local function ApplyAlerts(anchor, growUp, scale)
    local db = ns.db
    if not db or not db.moveAlerts then return end
    local host = AlertHost()
    if not host then return end

    -- Out of the default UI layout, or it is put back where it came from
    host.ignoreFramePositionManager = true
    if not alertManagedCleared then
        alertManagedCleared = true
        local managed = _G.UIPARENT_MANAGED_FRAME_POSITIONS
        if type(managed) == "table" then
            managed["AlertFrame"] = nil
        end
    end

    Hook(host)
    SetScaleIfNeeded(host, scale)

    -- The toast is centred on its anchor, so the middle of the bar is the spot
    local point = growUp and "BOTTOM" or "TOP"
    SetPointIfNeeded(host, point, anchor, point, 0, 0)

    AnchorSubSystems(host, anchor)
end

-- ---------------------------------------------------------
-- The slide
-- ---------------------------------------------------------
-- Only runs while something is moving or appearing, and stops itself as soon as
-- every bar sits where it belongs.
local slider = CreateFrame("Frame")
slider:Hide()

local function WriteState(bar, state)
    SetPointIfNeeded(bar, state.corner, state.anchor, state.corner, 0, state.y)
    if state.alpha < 1 then
        pcall(bar.SetAlpha, bar, state.alpha)
    end
end

slider:SetScript("OnUpdate", function(self, elapsed)
    applying = true
    local busy = false

    for bar, state in pairs(states) do
        if state.visible and state.corner then
            local distance = state.targetY - state.y
            if math.abs(distance) > 0.3 then
                state.y = state.y + distance * math.min(1, elapsed * SLIDE_SPEED)
                busy = true
            else
                state.y = state.targetY
            end

            if state.alpha < 1 then
                state.alpha = math.min(1, state.alpha + elapsed / FADE_TIME)
                if state.alpha >= 1 then
                    pcall(bar.SetAlpha, bar, 1)
                else
                    busy = true
                end
            end

            WriteState(bar, state)
        end
    end

    applying = false
    if not busy then self:Hide() end
end)

local function Smooth()
    local db = ns.db
    return db ~= nil and db.smooth ~= false
end

function Rolls.Apply()
    local db = ns.db
    if not db or not db.enabled then return end
    local anchor = ns.Anchor and ns.Anchor.frame
    if not anchor then return end
    if applying then return end
    applying = true

    local scale = ns.ClampScale(db.scale)
    local spacing = tonumber(db.spacing) or 3
    local growUp = db.growUp ~= false
    local corner = growUp and "BOTTOMLEFT" or "TOPLEFT"
    local sign = growUp and 1 or -1
    local smooth = Smooth()

    -- The container holds the bars and is what the default UI moves around
    local container = Rolls.Container()
    if container then
        FreeContainer(container)
        Hook(container)
        SetScaleIfNeeded(container, scale)
        SetPointIfNeeded(container, corner, anchor, corner, 0, 0)
    end

    Collect()

    local offset = 0
    for _, bar in ipairs(bars) do
        Hook(bar)
        local state = states[bar]
        if not state then
            state = { y = 0, targetY = 0, alpha = 1, visible = false }
            states[bar] = state
        end

        if IsShownSafe(bar) then
            -- A bar inside the container already carries the container scale
            local okParent, parent = pcall(bar.GetParent, bar)
            local parentIsContainer = container ~= nil and okParent and parent == container
            SetScaleIfNeeded(bar, parentIsContainer and 1 or scale)

            state.corner = corner
            state.anchor = anchor
            state.targetY = sign * offset

            if not state.visible then
                -- Appearing: straight to its place, fading in when asked for
                state.visible = true
                state.y = state.targetY
                state.alpha = smooth and 0 or 1
                if not smooth then pcall(bar.SetAlpha, bar, 1) end
            elseif not smooth then
                state.y = state.targetY
            end

            WriteState(bar, state)
            ApplyButtons(bar)
            Learn(bar)
            offset = offset + HeightOf(bar) + spacing
        else
            if state.visible then
                state.visible = false
                state.alpha = 1
                pcall(bar.SetAlpha, bar, 1) -- Never hand a bar back half faded
            end
            bar.lrmButtons = nil -- The game rebuilds its buttons between rolls
        end
    end

    ApplyAlerts(anchor, growUp, scale)

    applying = false

    -- Anything left to slide or fade in? Wake the driver up.
    if smooth then
        for _, state in pairs(states) do
            if state.visible and (math.abs(state.targetY - state.y) > 0.3 or state.alpha < 1) then
                slider:Show()
                break
            end
        end
    else
        slider:Hide()
    end
end

-- Every bar back to full opacity, used when the addon is switched off so none
-- is left half faded.
function Rolls.ResetAlpha()
    for bar, state in pairs(states) do
        state.alpha = 1
        pcall(bar.SetAlpha, bar, 1)
    end
    slider:Hide()
end

-- ---------------------------------------------------------
-- Watchdog
-- ---------------------------------------------------------
-- The hooks catch almost everything, but a build that places its bars from C
-- code would fire none of them. Five cheap checks a second cover for that:
-- Apply only ever writes a point that is actually wrong.
function Rolls.Start()
    if Rolls.ticker then return end
    Rolls.ticker = C_Timer.NewTicker(CHECK_EVERY, function()
        local db = ns.db
        if not db or not db.enabled then return end
        Collect()
        -- A toast can show up without a roll ever happening, so both count
        if not Rolls.Visible() and not Rolls.AlertShown() then return end
        Rolls.Apply()
    end)
end

-- ---------------------------------------------------------
-- /flm scan: what this build actually has
-- ---------------------------------------------------------
function Rolls.Scan(print)
    local container = Rolls.Container()
    print(string.format("GroupLootContainer: %s  |cff806030.|r  NUM_GROUP_LOOT_FRAMES: %s",
        container and "yes" or "NO", tostring(_G.NUM_GROUP_LOOT_FRAMES)))

    local found = Collect()
    print(string.format("Loot roll bars found: %d", found))
    for index, bar in ipairs(bars) do
        local okWidth, width = pcall(bar.GetWidth, bar)
        local okHeight, height = pcall(bar.GetHeight, bar)
        print(string.format("  %d. %s  %dx%d  %s", index,
            FrameName(bar) or "(unnamed)",
            math.floor((okWidth and width or 0) + 0.5),
            math.floor((okHeight and height or 0) + 0.5),
            IsShownSafe(bar) and "shown" or "hidden"))
    end

    -- The buttons of the first bar, so the fourth square can be named exactly
    local first = bars[1]
    if first then
        first.lrmButtons = nil -- Sort them again, in case the game swapped one
        local found = Rolls.Buttons(first)
        if found then
            local function Line(button, label)
                print(string.format("  button: %s  [%s]  %s  art=%s",
                    FrameName(button) or "(unnamed)", label,
                    IsShownSafe(button) and "shown" or "hidden",
                    (found.art and found.art[button]) ~= "" and found.art[button] or "none"))
            end
            if found.icon then Line(found.icon, "icon") end
            for _, button in ipairs(found.rolls) do
                local label = "roll, kept"
                for _, key in ipairs({ "need", "greed", "pass" }) do
                    if found[key] == button then label = key end
                end
                Line(button, label)
            end
            for _, button in ipairs(found.extras) do
                Line(button, "extra, hidden by the addon")
            end

            -- What is painted on the greed button, to catch an icon sitting on
            -- top of the coin rather than next to it
            local greed = found.greed
            if greed and type(greed.GetRegions) == "function" then
                local okRegions, regions = pcall(function() return { greed:GetRegions() } end)
                if okRegions then
                    for _, region in ipairs(regions) do
                        if region.GetObjectType and region:GetObjectType() == "Texture" then
                            local file, atlas = nil, nil
                            local okFile, value = pcall(region.GetTexture, region)
                            if okFile then file = value end
                            if type(region.GetAtlas) == "function" then
                                local okAtlas, name = pcall(region.GetAtlas, region)
                                if okAtlas then atlas = name end
                            end
                            print(string.format("    greed layer: %s %s  %s",
                                tostring(file), tostring(atlas),
                                IsShownSafe(region) and "shown" or "hidden"))
                        end
                    end
                end
            end
        end
    end

    -- The alert system, which carries the "You received" toast
    local host = AlertHost()
    local subsystems = host and host.alertFrameSubSystems
    print(string.format("AlertFrame: %s  |cff806030.|r  subsystems: %s  |cff806030.|r  toast on screen: %s",
        host and "yes" or "NO",
        type(subsystems) == "table" and tostring(#subsystems) or "none",
        Rolls.AlertShown() and "yes" or "no"))
    if host and type(host.GetChildren) == "function" then
        local okAlerts, children = pcall(function() return { host:GetChildren() } end)
        if okAlerts then
            for _, child in ipairs(children) do
                if IsShownSafe(child) then
                    print("  toast: " .. (FrameName(child) or "(unnamed)"))
                end
            end
        end
    end

    -- Anything else on screen that smells like a roll bar, in case a build
    -- moved them somewhere else entirely.
    local extras = 0
    local ok, children = pcall(function() return { UIParent:GetChildren() } end)
    if ok then
        for _, frame in ipairs(children) do
            local name = FrameName(frame)
            if name and IsShownSafe(frame)
                and (name:find("Loot") or name:find("Roll"))
                and name ~= "GroupLootContainer"
                and not name:find(ADDON_NAME) then
                extras = extras + 1
                if extras <= 10 then print("  other: " .. name) end
            end
        end
    end
    if extras == 0 then print("  no other loot frame shown right now") end
end
