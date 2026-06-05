-- wezterm.lua — mirror of the ghostty config (dot_config/ghostty/config)
-- Cross-platform: the win-only Acrylic bits are guarded so this same file
-- works on macOS too if you ever migrate off ghostty.
local wezterm = require("wezterm")
local config = wezterm.config_builder()
local is_windows = wezterm.target_triple:find("windows") ~= nil

-- ── Font (ghostty: Hack Nerd Font, size 13) ──────────────────────────────
config.font = wezterm.font_with_fallback({
  "Hack Nerd Font",
  "JetBrainsMonoNL NF", -- fallback (already installed via YASB)
})
config.font_size = 13.0

-- ── Theme (ghostty: Catppuccin Mocha) ────────────────────────────────────
config.color_scheme = "Catppuccin Mocha"

-- ── Window (ghostty: no decoration, opacity 0.92, blur 20) ───────────────
config.window_decorations = "RESIZE" -- borderless but still resizable (the thing WT quake couldn't do)
config.window_background_opacity = 0.92
if is_windows then
  config.win32_system_backdrop = "Acrylic" -- ≈ ghostty background-blur-radius 20
end
config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false

-- ── Background image (Klonoa) ────────────────────────────────────────────
-- Two layers: a dark solid base for contrast, then the image dimmed on top so
-- terminal text stays readable. Image sits bottom-right (where the art is).
config.background = {
  { -- base: pure black so the image's dark edges blend seamlessly
    source = { Color = "#000000" },
    width = "100%",
    height = "100%",
    opacity = 1.0,
  },
  { -- dark-red horror silhouette. EXPLICIT display size (358x400) matching the
    -- source aspect 0.895 so it can't stretch. File is cropped (bottom dead-black
    -- removed) so the figure sits at the image bottom; bottom-center anchors it
    -- low. Shrink width/height together to zoom out, keep the 0.895 ratio.
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

-- ── Mouse / clipboard (ghostty: copy-on-select, hide mouse while typing) ──
config.hide_mouse_cursor_when_typing = true
config.mouse_bindings = {
  { -- copy on select (left-drag release → clipboard)
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = wezterm.action.CompleteSelection("Clipboard"),
  },
  { -- right-click pastes from clipboard (Windows-terminal habit)
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = wezterm.action.PasteFrom("Clipboard"),
  },
}

-- ── tmux-style keys (ghostty: ctrl+b leader, vim splits/nav/tabs) ─────────
-- NOTE: real tmux (your dot_tmux.conf, via WSL) is the cross-machine source of
-- truth for panes. These WezTerm binds mirror it for when you're NOT in tmux.
config.leader = { key = "b", mods = "CTRL", timeout_milliseconds = 1000 }
local act = wezterm.action
config.keys = {
  -- ── COPY / PASTE ──────────────────────────────────────────────────────
  -- Ctrl+C = ALWAYS interrupt (SIGINT) — never copies. (No Ctrl+C binding here means
  -- WezTerm passes it straight to the shell.) Copy is on Alt+C / Ctrl+Shift+C / drag-select.
  { key = "v", mods = "CTRL", action = act.PasteFrom("Clipboard") },
  -- mac muscle memory: on a Windows keyboard, ALT sits where mac's Cmd is, so
  -- Alt+C / Alt+V = your literal Cmd+C / Cmd+V copy/paste. WezTerm-only (games
  -- never see it). Alt+C copies the selection like mac Cmd+C.
  { key = "c", mods = "ALT", action = wezterm.action_callback(function(win, pane)
      local s = win:get_selection_text_for_pane(pane)
      if s and s ~= "" then win:perform_action(act.CopyTo("Clipboard"), pane) end  -- copy only if selected; NEVER flush the clipboard on an empty copy
    end) },
  { key = "v", mods = "ALT", action = act.PasteFrom("Clipboard") },
  { key = "t", mods = "ALT", action = act.SpawnTab("CurrentPaneDomain") },  -- Alt+T = new tab (mac Cmd+T parity)
  -- Linux-terminal convention too, always available:
  { key = "c", mods = "CTRL|SHIFT", action = wezterm.action_callback(function(win, pane)
      local s = win:get_selection_text_for_pane(pane)
      if s and s ~= "" then win:perform_action(act.CopyTo("Clipboard"), pane) end  -- copy only if selected; never flush
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

-- ── Default shell: PowerShell 7 ; WSL one keybind away ───────────────────
if is_windows then
  config.default_prog = { "pwsh.exe", "-NoLogo" }
  -- WSL tab: was Ctrl+Shift+U, but AMD Radeon Software grabs that globally.
  -- Moved under the Ctrl+B leader (internal to WezTerm -> AMD can't intercept).
  table.insert(config.keys, {
    key = "u", mods = "LEADER",
    action = act.SpawnCommandInNewTab({ args = { "wsl.exe", "~", "-d", "Ubuntu" } }),
  })
end

return config
