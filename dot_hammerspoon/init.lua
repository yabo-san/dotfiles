local GHOSTTY = "com.mitchellh.ghostty"

local function toggleGhostty()
    local front = hs.application.frontmostApplication()

    -- Don't intercept for games
    local gameApps = { "com.yoyogames.GameMaker-Mac", "YoYo Runner" }
    if front then
        for _, gameApp in ipairs(gameApps) do
            if front:name():find(gameApp) or front:bundleID() == gameApp then
                print("BACKTICK: game running, ignoring toggle")
                return
            end
        end
    end

    local ghostty = hs.application.get(GHOSTTY)
    if not ghostty then
        print("BACKTICK: launching Ghostty")
        hs.application.launchOrFocusByBundleID(GHOSTTY)
        return
    end

    if ghostty:isFrontmost() then
        print("BACKTICK: hiding Ghostty")
        ghostty:hide()
    else
        print("BACKTICK: showing Ghostty")
        ghostty:activate()
    end
end

hs.hotkey.bind({}, "grave", toggleGhostty)
print("Ghostty quick terminal bound to grave key")
