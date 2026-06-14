local GHOSTTY = "com.mitchellh.ghostty"

-- Ghostty quick terminal global toggle
-- Ghostty's built-in global: keybind stops working when AeroSpace moves all
-- Ghostty windows off-screen. This eventtap intercepts backtick at the OS level,
-- activates Ghostty briefly, sends the key, then restores the AeroSpace workspace.
-- The quick terminal is unmanaged by AeroSpace so it stays visible after the restore.
local backtapWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    if event:getKeyCode() ~= 50 then return false end
    local f = event:getFlags()
    if f.cmd or f.ctrl or f.alt or f.shift then return false end

    local front = hs.application.frontmostApplication()
    if front and front:bundleID() == GHOSTTY then return false end

    local ghostty = hs.application.get(GHOSTTY)
    if not ghostty then return true end

    local currentWS = hs.execute("aerospace list-workspaces --focused"):gsub("%s+", "")

    ghostty:activate()
    hs.timer.doAfter(0.03, function()
        hs.eventtap.keyStroke({}, "grave")
        if currentWS ~= "" then
            hs.timer.doAfter(0.08, function()
                hs.execute("aerospace workspace " .. currentWS)
            end)
        end
    end)

    return true
end)

backtapWatcher:start()
