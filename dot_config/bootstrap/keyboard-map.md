# ⌨️ Keyboard map — the one keybind reference

**Principle:** on Windows, **Alt sits where mac's Cmd is**. AHK puts the OS clipboard family on Alt;
each app's own config (or an AHK `#HotIf` block) carries the rest — so Windows ≈ the Mac.
Sources: `scripts/wezterm/quake-hotkey.ahk` (AHK) · `~/.glzr/glazewm/config.yaml` (WM) ·
`~/.config/wezterm/` · Zen/Obsidian configs · `windows-tweaks.reg` (the Win+ disables).

---

## AHK — global (everywhere except WezTerm + RustDesk)
| Key | Action |
|---|---|
| `Alt+C / X / V / A` | copy / cut / paste / select-all (mac Cmd parity) |
| `Alt+Z` / `Alt+Shift+Z` | undo / redo |
| `Alt+Shift+C/X/V/A` | pass through to the app (e.g. Zen copy-URL) |
| `` ` `` (backtick) | WezTerm quake dropdown toggle |
| `` Ctrl+` `` | type a literal backtick |
| `Win+Shift+S` | ShareX region capture |

**Obsidian only (when focused)** — Alt-ified via AHK, NOT its config (it's iCloud-synced → Mac-safe):
`Alt+Y` browse-vault · `Alt+M` move-file · `Alt+I` Templater Zettel · `Alt+N` new-tab · `Alt+T` daily-note

---

## Windows keys
**Disabled** (`DisabledHotkeys=IXNQSBOR`, relog to activate): `Win+ I X N Q S B O R`
(Settings/power-menu/notifications/search×2/taskbar-focus/orientation/Run — all covered by Raycast / Open-Shell / YASB)
**Removed:** `Win+C` (Copilot off) · `Win+W` (Widgets app uninstalled)
**Already inert** (GlazeWM eats `lwin+k`/`lwin+h`): `Win+K` (cast) · `Win+H` (dictation)
**Kept:** `Win+E` files · `Win+P` display · `Win+V` clipboard · `Win+G` Game Bar · `Win+A` quick-settings · `Win+.` emoji
**Rebound:** `Win+L` → GlazeWM move-window-right (Raycast bridge) · `Win+Shift+S` → ShareX

---

## GlazeWM (`lwin` = Win)
| Key | Action |
|---|---|
| `lwin+h / j / k` | move window left / down / up |
| `Win+L` | move window **right** (Raycast → glaze bridge; Windows reserves plain lwin+l) |
| `lwin+1`–`9` | focus workspace 1–9 |
| `lwin+0` | focus workspace 10 |
| `lwin+d` | **show desktop** — flip to empty workspace `0` (wallpaper + icons); tap again = flip back |
| `lwin+shift+1`–`9`, `lwin+shift+0` | send window to workspace 1–9 / 10 |
| `lwin+shift+h / j / k / l` | move whole workspace to monitor left / down / up / right |
| `lwin+t` | toggle float ↔ tile |
| `lwin+m` | toggle fullscreen |
| `lwin+shift+p` | pause all WM binds (safety) |
| `lwin+shift+r` | reload glaze config |

_Note: a `resize` binding-mode is defined (h/j/k/l/arrows = ±2%, Esc/Enter exits) but has **no trigger key** — add an `wm-enable-binding-mode --name resize` bind if you want it._

---

## WezTerm
| Key | Action |
|---|---|
| `` ` `` | quake dropdown (via AHK) |
| `Ctrl+B` | leader |
| `Ctrl+C` | interrupt (SIGINT — never copy) |
| `Alt+C` / `Ctrl+Shift+C` | copy (guarded — empty copy won't flush clipboard) |
| `Alt+V` / `Ctrl+V` / `Ctrl+Shift+V` | paste |
| `Alt+T` | new tab |
| `Ctrl+B` then `U` | new WSL (Ubuntu) tab |

---

## Apps
- **Zen** — all command shortcuts Alt-ified (Cmd-parity); private window = `Alt+Shift+N`; reload = `Alt+R` (works now AMD hotkeys are off).
- **Obsidian** — see the AHK Obsidian block above; vim mode is ON (Obsidian hotkeys override vim's Ctrl-keys).
- **ShareX** — `Win+Shift+S` region (via AHK) · `PrtSc` all screens · `Ctrl+PrtSc` region.
- **Playnite** — global Pre/PostScript kills AHK on game launch (raw input, anti-cheat safe) and relaunches it after. Manual toggle = Raycast **"AHK Off" / "AHK On"**.

---

## ⚠️ Required on AMD
Turn OFF **all AMD Radeon Software hotkeys** (Settings → Hotkeys) — Radeon grabs `Alt+Z`, `Alt+R`,
`Ctrl+Shift+U` globally before AHK, silently breaking the remaps. (See `windows-notes.txt`.)

## Mac parity
`aerospace.toml` mirrors this glaze keymap; Karabiner (Caps dual-role: tap=Esc, hold=command) is still TODO.
