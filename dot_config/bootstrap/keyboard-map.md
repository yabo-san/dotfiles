# Keyboard map — every bind and WHERE it is defined

**Principle:** Alt sits where the Mac's Cmd is. AHK owns only the OS clipboard family on Alt; everything
else lives in the owning app's config. Win is GlazeWM's modifier. Nothing is bound in two places on purpose.

**Hook order when two owners claim a combo:** Windows (lock, Win+E object) → AutoHotkey → GlazeWM → the app.
Earlier wins. That is why Win+L never reaches GlazeWM and why Alt+Q in Zen closes the window.

## Owners and their files

| Owner | Where | Tracked? |
|---|---|---|
| Windows registry | `dot_config/bootstrap/windows-tweaks.reg.tmpl` | yes |
| AutoHotkey | `dot_config/scripts/wezterm/quake-hotkey.ahk` (autostart via `quake-hotkey.lnk`) | yes |
| GlazeWM | `dot_glzr/glazewm/config.yaml`, `keybindings:` section | yes |
| Raycast | Raycast's own SQLite index. Scripts in `dot_config/scripts/raycast/`, hotkeys set by hand | scripts yes, keys no |
| WezTerm | `dot_config/wezterm/wezterm.lua`, `config.keys` | yes |
| Zen | `dot_config/bootstrap/zen-keyboard-shortcuts.json`, pushed by `setup-zen.ps1` | yes, manual apply |
| Obsidian | AHK `#HotIf WinActive("ahk_exe Obsidian.exe")` block. `hotkeys.json` is iCloud-synced and untouched | yes (via AHK) |
| Open-Shell | `openshell-settings.reg.tmpl`: `WinKey=Nothing`, `ShiftWin=Nothing`. No key. Opened by the Raycast "Classic Start Menu" script | yes |
| YASB | no keyboard binds, mouse callbacks only (`dot_config/yasb/config.yaml`) | yes |
| Playnite | `scripts/playnite/` kills AHK on game launch, restarts after. Not keys | yes |

## Master index, by key

| Key | Does | Owner |
|---|---|---|
| `` ` `` | toggle WezTerm quake dropdown | AHK |
| `` Ctrl+` `` | type a literal backtick | AHK |
| `Alt+C / X / V / A` | copy / cut / paste / select all (not in WezTerm or RustDesk) | AHK |
| `Alt+Z` / `Alt+Shift+Z` | undo / redo (not in WezTerm or RustDesk) | AHK |
| `Alt+Shift+C / X / V / A` | passed through to the app (Zen copy-URL, addons) | AHK |
| `Alt+Q` | close focused window (graceful, Cmd+Q parity) | GlazeWM |
| `Alt+Tab` | native Windows switcher, deliberately unbound | Windows |
| `Alt+F4` | native, untouched | Windows |
| `Win+H / J / K` | move window left / down / up | GlazeWM |
| `Win+L` | move window right, via Raycast → `glaze-move-right.ps1`. Needs `DisableLockWorkstation` | Raycast + registry |
| `Win+T` | toggle float / tile | GlazeWM |
| `Win+M` | toggle fullscreen | GlazeWM |
| `Win+D` | show desktop: flip to empty workspace 0, again to flip back | GlazeWM |
| `Win+1` `2` `3` `4` | focus main, comms, music, dev | GlazeWM |
| `Win+Q` `W` | focus play (Playnite), utils and launchers | GlazeWM |
| `Win+F` | focus media | GlazeWM |
| `Win+C` | focus the CRT workspace | GlazeWM |
| `Win+5` to `Win+9`, `Win+0` | aliases for the same workspaces; 9 and 10 are number-only spares. Also keeps Windows from opening taskbar app N | GlazeWM |
| `Win+Shift+` the same keys | send window there and follow. Not `Win+Shift+S`, which stays the snip | GlazeWM |
| `Win+Tab` / `Win+Shift+Tab` | next / previous active workspace | GlazeWM |
| `Win+Shift+H / J / K / L` | move whole workspace to monitor left / down / up / right | GlazeWM |
| `Win+Shift+P` | pause all GlazeWM binds | GlazeWM |
| `Win+Shift+R` | reload GlazeWM config. On 3.10.1 reload drops every window onto the focused workspace; restore placement after | GlazeWM |
| `Win+E` | File Pilot, via the File Explorer CLSID override | registry |
| `Win+click` in Zen | Alt+click, split tab (Cmd+click parity) | AHK |
| `Win+Shift+S`, `PrtSc` | Snipping Tool | Windows |
| `Win+P / V / G / A / .` | display / clipboard / Game Bar / quick settings / emoji, native | Windows |
| `Win+I X N Q B O R` | disabled (`DisabledHotkeys=IXNQBOR`) | registry |
| `Win+C` | dead, Copilot off | registry |
| `Win+K`, `Win+H` | native cast / dictation never fire, GlazeWM eats them | GlazeWM |
| `Alt+Y / M / I / N / T` in Obsidian | browse vault / move file / Templater Zettel / new tab / daily note | AHK |

## WezTerm (only while WezTerm is focused)

| Key | Does |
|---|---|
| `Ctrl+C` | interrupt, never copy. No binding, passes to the shell |
| `Alt+C`, `Ctrl+Shift+C` | copy selection, never flushes clipboard on empty |
| `Alt+V`, `Ctrl+V`, `Ctrl+Shift+V` | paste |
| `Alt+T` | new tab |
| `Ctrl+B` | leader, 1 s timeout |
| leader `\` or `%` | split right |
| leader `-` or `"` | split down |
| leader `H / J / K / L` | pane focus |
| leader `C` / `N` / `P` | new tab / next / previous |
| leader `U` | new WSL Ubuntu tab |

AHK's Alt remaps are scoped OUT of WezTerm, so these are WezTerm's own.

## Zen (only while Zen is focused), the ones that matter

Everything is Alt-ified for Cmd parity. Full list is the JSON, 88 Alt binds. Notable:

| Key | Does |
|---|---|
| `Alt+T` / `Alt+W` / `Alt+N` | new tab / close tab / new window |
| `Alt+1` to `Alt+9` | select tab |
| `Alt+L` | focus URL bar |
| `Alt+R` / `Alt+Shift+R` | reload / reload skip cache (works since AMD hotkeys are off) |
| `Alt+F` / `Alt+G` | find / find again |
| `Alt+Shift+N` | private window |
| `Alt+Shift+C` | copy URL (passes through AHK) |
| `Alt+E` / `Alt+Q` | Zen workspace forward / backward. **Alt+Q never fires, GlazeWM eats it (close)** |
| `Alt+H` / `Alt+V` / `Alt+G` | split view horizontal / vertical / grid. **Alt+V never fires, AHK eats it (paste)** |
| `Alt+C / X / V / A / Z` | mapped in Zen too, but AHK rewrites them to Ctrl first. Copy, cut, paste, select all, undo |

## Raycast script commands (no default keys, assign in Raycast)

`AHK On`, `AHK Off`, `Classic Start Menu`, `Glaze Move Right` (this one is bound to Win+L), `Window Solo`,
`Bind CRT`, `Label Monitor`, `Reconnect NAS`, `Restore Playnite Curation`, `Crysis Sandbox 2 Editor` ×2.
Raycast's own launcher hotkey is set in Raycast, not tracked.

## Known collisions (all intentional or accepted)

- `Alt+Q`: GlazeWM close beats Zen workspace-backward. Use `Alt+E` in Zen, or rebind Zen.
- `Alt+V`: AHK paste beats Zen split-vertical. Zen's `Alt+Shift+*` new-split still works.
- `Alt+C`: AHK copy beats Zen compact-mode toggle.
- `Win+L`: Windows lock beats everything unless `DisableLockWorkstation=1` is applied and relogged.
- `Win+W`: now the utils workspace. Free because the Widgets app is uninstalled; the old AHK "jump to Zen" bind is gone.

## Dead ends

- GlazeWM has a `resize` binding mode defined but no key enables it. Add `wm-enable-binding-mode --name resize` if wanted.
- No GlazeWM focus-direction keys. Focus is by mouse.
- README says Open-Shell is on Shift+Win. It is not; both Open-Shell key settings are "Nothing".

## Required on AMD

Turn OFF all Radeon Software hotkeys (Settings → Hotkeys). Radeon grabs `Alt+Z`, `Alt+R`, `Ctrl+Shift+U`
globally before AHK and silently breaks the remaps.

## Mac parity

`aerospace.toml` mirrors the GlazeWM map. Karabiner Caps dual-role (tap Esc, hold Cmd) is still TODO.
