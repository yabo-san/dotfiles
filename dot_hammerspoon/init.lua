local GHOSTTY = "com.mitchellh.ghostty"

hs.hotkey.bind({}, "grave", function()
    local front = hs.application.frontmostApplication()

    -- Don't intercept if Ghostty is already front
    if front and front:bundleID() == GHOSTTY then
        return
    end

    -- Don't intercept if a game/fullscreen app is running
    local gameApps = { "com.yoyogames.GameMaker-Mac", "YoYo Runner" }
    if front then
        for _, gameApp in ipairs(gameApps) do
            if front:name():find(gameApp) or front:bundleID() == gameApp then
                return
            end
        end
    end

    local ghostty = hs.application.get(GHOSTTY)
    if not ghostty then
        hs.application.launchOrFocusByBundleID(GHOSTTY)
        return
    end

    ghostty:activate()
end)

print("Ghostty quick terminal hotkey bound (grave/backtick)")
