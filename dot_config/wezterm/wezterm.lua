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
  { -- dark-red horror silhouette. NATIVE size (no width/height) = pixels render
    -- 1:1, CANNOT stretch. File pre-resized to 441x560. Bottom-center so the
    -- figure shows; black edges blend into the black base. (Contain stretches
    -- in this wezterm version, so we avoid it entirely.)
    source = { File = wezterm.home_dir .. "/.config/wezterm/bg/horror-fit.png" },
    hsb = { brightness = 0.5 },
    opacity = 0.9,
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
  -- Ctrl+C is SMART: copy if text is selected, else pass through as SIGINT
  -- (so ctrl-C still kills running commands). Ctrl+V pastes.
  { key = "c", mods = "CTRL", action = wezterm.action_callback(function(win, pane)
      local sel = win:get_selection_text_for_pane(pane)
      if sel and sel ~= "" then
        win:perform_action(act.CopyTo("Clipboard"), pane)
        win:perform_action(act.ClearSelection, pane)
      else
        win:perform_action(act.SendKey({ key = "c", mods = "CTRL" }), pane) -- real SIGINT
      end
    end) },
  { key = "v", mods = "CTRL", action = act.PasteFrom("Clipboard") },
  -- Linux-terminal convention too, always available:
  { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
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
  table.insert(config.keys, {
    key = "u", mods = "CTRL|SHIFT",
    action = act.SpawnCommandInNewTab({ args = { "wsl.exe", "~", "-d", "Ubuntu" } }),
  })
end

return config
