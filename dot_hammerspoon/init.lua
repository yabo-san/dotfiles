local GHOSTTY = "com.mitchellh.ghostty"
local previousApp = nil

-- Resolve aerospace once at load time (blocking is fine here, not inside the tap).
-- hs.task needs an absolute path; it does not search the shell PATH.
local AEROSPACE = hs.execute("command -v aerospace", true):gsub("%s+", "")
if AEROSPACE == "" then AEROSPACE = "/opt/homebrew/bin/aerospace" end

-- Everything that touches AeroSpace runs async. The old code called
-- hs.execute("aerospace list-workspaces --focused") INSIDE the eventtap callback,
-- which blocks the keystroke. macOS disables an event tap that takes too long to
-- answer (kCGEventTapDisabledByTimeout) and Hammerspoon does not re-enable it,
-- so a slow aerospace reply silently killed the backtick until a reload.
local function toggleFromOtherApp(front, ghostty)
    hs.task.new(AEROSPACE, function(_, stdout, _)
        local currentWS = (stdout or ""):gsub("%s+", "")
        print("backtick: activating Ghostty from ws=" .. currentWS .. " front=" .. (front and front:name() or "none"))

        previousApp = front
        ghostty:activate()
        hs.timer.doAfter(0.05, function()
            local nowFront = hs.application.frontmostApplication()
            print("backtick: 50ms later, front=" .. (nowFront and nowFront:name() or "none"))
            hs.eventtap.event.newKeyEvent(50, true):post()
            hs.eventtap.event.newKeyEvent(50, false):post()
            if currentWS ~= "" then
                hs.timer.doAfter(0.1, function()
                    print("backtick: restoring ws=" .. currentWS)
                    hs.task.new(AEROSPACE, nil, { "workspace", currentWS }):start()
                end)
            end
        end)
    end, { "list-workspaces", "--focused" }):start()
end

-- GLOBAL on purpose, not `local`. A local at the top of init.lua has no live
-- reference once this file finishes running, so Lua's garbage collector can free
-- the eventtap at any moment and the backtick just stops working. That was the
-- "misfires once in a while, reload fixes it" bug. Test from the Hammerspoon
-- console: `backtapWatcher` should never print nil.
backtapWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    if event:getKeyCode() ~= 50 then return false end
    local f = event:getFlags()
    if f.cmd or f.ctrl or f.alt or f.shift then return false end

    local front = hs.application.frontmostApplication()
    if front and front:bundleID() == GHOSTTY then
        print("backtick: Ghostty front, toggle quake")
        hs.timer.doAfter(0.15, function()
            local ghostty = hs.application.get(GHOSTTY)
            if ghostty and #ghostty:allWindows() == 0 and previousApp then
                print("backtick: quake hidden, restoring " .. previousApp:name())
                previousApp:activate()
            end
        end)
        return false
    end

    -- Don't intercept if a game/fullscreen app is running
    local gameApps = { "com.yoyogames.GameMaker-Mac", "YoYo Runner" }
    if front then
        for _, gameApp in ipairs(gameApps) do
            if front:name():find(gameApp) or front:bundleID() == gameApp then
                print("backtick: game running (" .. front:name() .. "), passing through")
                return false
            end
        end
    end

    local ghostty = hs.application.get(GHOSTTY)
    if not ghostty then
        print("backtick: Ghostty not running, launching...")
        hs.application.launchOrFocusByBundleID(GHOSTTY)
        hs.timer.doAfter(0.5, function()
            hs.eventtap.event.newKeyEvent(50, true):post()
            hs.eventtap.event.newKeyEvent(50, false):post()
        end)
        return true
    end

    -- Swallow the keystroke now and do the slow part a tick later.
    toggleFromOtherApp(front, ghostty)
    return true
end)

backtapWatcher:start()
print("Ghostty quick terminal watcher started")

-- Safety net, not the cure: macOS can still disable a tap (secure input, a
-- timeout we did not foresee). Check every 5s and re-arm it. Also GLOBAL, for the
-- same garbage-collection reason as the tap itself.
backtapHealth = hs.timer.doEvery(5, function()
    if not backtapWatcher:isEnabled() then
        print("backtick: eventtap was disabled, restarting")
        backtapWatcher:start()
    end
end)
