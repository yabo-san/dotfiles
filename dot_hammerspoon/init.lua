local GHOSTTY = "com.mitchellh.ghostty"

hs.hotkey.bind({}, "grave", function()
    local ghostty = hs.application.get(GHOSTTY)

    -- If Ghostty is running but not focused, activate it
    if ghostty and ghostty ~= hs.application.frontmostApplication() then
        ghostty:activate()
        return
    end

    -- If Ghostty isn't running, launch it
    if not ghostty then
        hs.application.launchOrFocusByBundleID(GHOSTTY)
        return
    end

    -- If Ghostty is focused, forward the keystroke using keycode (grave = 50)
    if ghostty == hs.application.frontmostApplication() then
        hs.eventtap.keyStroke({}, 50)
    end
end)
