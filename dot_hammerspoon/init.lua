local GHOSTTY = "com.mitchellh.ghostty"
local backtapWatcher = nil

local function createBacktapWatcher()
    backtapWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
        if event:getKeyCode() ~= 50 then return false end
        local f = event:getFlags()
        if f.cmd or f.ctrl or f.alt or f.shift then return false end

        local front = hs.application.frontmostApplication()
        if front and front:bundleID() == GHOSTTY then
            print("backtick: Ghostty already front, passing through")
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

        local currentWS = hs.execute("aerospace list-workspaces --focused"):gsub("%s+", "")
        print("backtick: activating Ghostty from ws=" .. currentWS .. " front=" .. (front and front:name() or "none"))

        ghostty:activate()
        hs.timer.doAfter(0.05, function()
            local nowFront = hs.application.frontmostApplication()
            print("backtick: 50ms later, front=" .. (nowFront and nowFront:name() or "none"))
            hs.eventtap.event.newKeyEvent(50, true):post()
            hs.eventtap.event.newKeyEvent(50, false):post()
            if currentWS ~= "" then
                hs.timer.doAfter(0.1, function()
                    print("backtick: restoring ws=" .. currentWS)
                    hs.execute("aerospace workspace " .. currentWS)
                end)
            end
        end)

        return true
    end)
    backtapWatcher:start()
end

-- Watchdog: re-register eventtap every 30min to prevent degradation
createBacktapWatcher()
hs.timer.new(hs.timer.minutes(30), function()
    print("backtick: watchdog refreshing eventtap")
    if backtapWatcher then
        backtapWatcher:stop()
    end
    createBacktapWatcher()
end):start()

print("Ghostty quick terminal watcher started (with auto-refresh watchdog)")
