local GHOSTTY = "com.mitchellh.ghostty"

local backtapWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    print("BACKTICK: keyCode=" .. event:getKeyCode())
    if event:getKeyCode() ~= 50 then return false end  -- grave key

    local f = event:getFlags()
    if f.cmd or f.ctrl or f.alt or f.shift then
        print("BACKTICK: modifier key detected, passing through")
        return false
    end

    local front = hs.application.frontmostApplication()
    print("BACKTICK: front app = " .. (front and front:name() or "nil"))

    if front and front:bundleID() == GHOSTTY then
        print("BACKTICK: Ghostty is focused, passing through for toggle")
        return false
    end

    -- Don't intercept for games
    local gameApps = { "com.yoyogames.GameMaker-Mac", "YoYo Runner" }
    if front then
        for _, gameApp in ipairs(gameApps) do
            if front:name():find(gameApp) or front:bundleID() == gameApp then
                print("BACKTICK: game running, passing through")
                return false
            end
        end
    end

    -- If Ghostty isn't running, launch it
    local ghostty = hs.application.get(GHOSTTY)
    if not ghostty then
        print("BACKTICK: Ghostty not running, launching...")
        hs.application.launchOrFocusByBundleID(GHOSTTY)
        return true
    end

    -- Ghostty is running but not focused, activate it
    print("BACKTICK: activating Ghostty")
    ghostty:activate()
    return true
end)

backtapWatcher:start()
print("Ghostty quick terminal watcher started (grave key)")
