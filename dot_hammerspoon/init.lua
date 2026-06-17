local GHOSTTY = "com.mitchellh.ghostty"

local backtapWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    if event:getKeyCode() ~= 50 then return false end  -- grave key
    local f = event:getFlags()
    if f.cmd or f.ctrl or f.alt or f.shift then return false end

    local front = hs.application.frontmostApplication()
    if front and front:bundleID() == GHOSTTY then
        -- Ghostty is focused, let toggle_quick_terminal handle the keystroke
        return false
    end

    -- Don't intercept for games
    local gameApps = { "com.yoyogames.GameMaker-Mac", "YoYo Runner" }
    if front then
        for _, gameApp in ipairs(gameApps) do
            if front:name():find(gameApp) or front:bundleID() == gameApp then
                return false
            end
        end
    end

    -- If Ghostty isn't running, launch it
    local ghostty = hs.application.get(GHOSTTY)
    if not ghostty then
        hs.application.launchOrFocusByBundleID(GHOSTTY)
        return true  -- consume the key
    end

    -- Ghostty is running but not focused, activate it
    ghostty:activate()
    return true  -- consume the key
end)

backtapWatcher:start()
print("Ghostty quick terminal watcher started (grave key)")
