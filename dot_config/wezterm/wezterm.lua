-- wezterm.lua: mirror of the ghostty config. Windows-only bits are guarded so it also runs on macOS.
local wezterm = require("wezterm")
local config = wezterm.config_builder()
local is_windows = wezterm.target_triple:find("windows") ~= nil

config.font = wezterm.font_with_fallback({
  "Hack Nerd Font",
  "JetBrainsMonoNL NF",
})
config.font_size = 13.0

config.color_scheme = "Catppuccin Mocha"

config.window_decorations = "RESIZE"
config.window_background_opacity = 0.92
if is_windows then
  config.win32_system_backdrop = "Acrylic"
end
config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false

config.background = {
  {
    source = { Color = "#000000" },
    width = "100%",
    height = "100%",
    opacity = 1.0,
  },
  { -- explicit size at the source aspect (0.895) so it cannot stretch; scale width and height together
    source = { File = wezterm.home_dir .. "/.config/wezterm/bg/horror-fit.png" },
    hsb = { brightness = 0.5 },
    opacity = 0.9,
    width = 1075,
    height = 1200,
    horizontal_align = "Center",
    vertical_align = "Bottom",
    repeat_x = "NoRepeat",
    repeat_y = "NoRepeat",
  },
}
-- with a bg image, drop the system acrylic so the image isn't washed out
config.window_background_opacity = 1.0

config.hide_mouse_cursor_when_typing = true
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = wezterm.action.CompleteSelection("Clipboard"),
  },
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = wezterm.action.PasteFrom("Clipboard"),
  },
}

-- tmux (dot_tmux.conf) is the source of truth for panes; these mirror it outside tmux.
config.leader = { key = "b", mods = "CTRL", timeout_milliseconds = 1000 }
local act = wezterm.action
config.keys = {
  -- No Ctrl+C binding: it always reaches the shell as SIGINT. Copy is Alt+C / Ctrl+Shift+C / drag-select.
  { key = "v", mods = "CTRL", action = act.PasteFrom("Clipboard") },
  -- Alt sits where the Mac's Cmd is.
  { key = "c", mods = "ALT", action = wezterm.action_callback(function(win, pane)
      local s = win:get_selection_text_for_pane(pane)
      if s and s ~= "" then win:perform_action(act.CopyTo("Clipboard"), pane) end  -- an empty copy would flush the clipboard
    end) },
  { key = "v", mods = "ALT", action = act.PasteFrom("Clipboard") },
  { key = "t", mods = "ALT", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "c", mods = "CTRL|SHIFT", action = wezterm.action_callback(function(win, pane)
      local s = win:get_selection_text_for_pane(pane)
      if s and s ~= "" then win:perform_action(act.CopyTo("Clipboard"), pane) end
    end) },
  { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },

  -- splits (ghostty: ctrl+b \ and ctrl+b % = right ; ctrl+b - and ctrl+b " = down)
  { key = "\\", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "%",  mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "-",  mods = "LEADER",       action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "\"", mods = "LEADER|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  -- pane nav (vim hjkl)
  { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
  { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
  { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
  { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
  -- tabs (ghostty: ctrl+b c/n/p)
  { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
  { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
}

-- Nightlies point SSH_AUTH_SOCK at an agent socket nobody serves, which broke `devpod up` (2026-09-01).
config.mux_enable_ssh_agent = false

if is_windows then
  config.default_prog = { "pwsh.exe", "-NoLogo" }
  -- WSL tab on the leader: AMD Radeon Software grabs Ctrl+Shift+U globally.
  table.insert(config.keys, {
    key = "u", mods = "LEADER",
    action = act.SpawnCommandInNewTab({ args = { "wsl.exe", "~", "-d", "Ubuntu" } }),
  })
end

return config
