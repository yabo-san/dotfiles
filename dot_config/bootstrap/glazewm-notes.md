# GlazeWM notes

Why `~/.glzr/glazewm/config.yaml` is shaped the way it is. The config itself stays terse; the reasons live here.
Keys are in `keyboard-map.md`.

## The model: deny by default

`initial_state` is floating and a catch-all `ignore` rule matches every process not named in a workspace rule.
An ignored window gets no border, no workspace and no tiling. It stays on the monitor it opened on and sits over
every workspace there, which is what games and launchers want.

This replaced an allowlist-tiling setup with a per-game ignore list (2026-08-12). The floating-size snapshot
(`manage_window.rs`) kept pinning game windows at their init size: Dishonored at 160x120, Dishonored 2's splash,
BorderlessGaming at 146x32. Each broken title needed its own entry. Ignoring by default ends that.

**To manage a new app: add its process to its workspace rule AND to the catch-all `not_regex`.** Miss the second
and it is silently ignored. That is how Obsidian ended up hanging over every workspace until it was added.

## Main window only

GlazeWM only skips owned windows with no title bar (`check_is_manageable`). Real dialogs have one, so they get
managed and the rules run on them. A rule that matches by process alone tiles and teleports the app's dialogs too.
Off the current workspace that reads as "the window vanished", and a modal dialog makes the app look frozen.

There is no is-dialog match key, only process, class and title, so main-window rules add a second field:

| App | Field | Why that field |
| --- | --- | --- |
| Zen | class `MozillaWindowClass` | dialogs are `MozillaDialogClass` or `#32770` |
| Explorer | class `CabinetWClass` | the desktop and taskbar are also `explorer` |
| File Pilot | class `File Pilot` | delete and overwrite confirms are `#32770` (2026-10-05) |
| Office | `XLMAIN`, `OpusApp`, `PPTFrameClass` | each app's main frame class |
| Playnite | title `Playnite` | WPF, class carries a per-launch GUID; the title is exact in both MainWindow.xaml files |
| Steam | title `Steam` on `steamwebhelper` | every Steam surface is class `SDL_app` |

Obsidian is matched by process alone on purpose: it is Electron, every window is `Chrome_WidgetWin_1`, and popped
out notes are real editor windows that should tile.

GlazeWM's `process_name` keeps the exe name up to the first dot, so `Playnite.DesktopApp.exe` and
`Playnite.FullscreenApp.exe` both report `Playnite`.

## Monitors

`bind_to_monitor` is 0-based, left to right by x position, not by Windows' display number. Today:
0 = Acer XG270HU, 1 = CRT (1024x768 at x=-1024), 2 = LG ultrawide. Confirm after any rearrangement with
`glazewm query monitors`.

A bound workspace re-homes itself whenever it activates. An unbound one lands wherever it is activated and never
corrects itself; that is how workspace 1 drifted onto the CRT twice on 2026-07-31.

Workspaces 1, 4, 5 and 7 all bind to the ultrawide and only one can show at a time. A rule that moves a window to
5 while 1 is showing puts it out of sight. That was half of the Playnite popup bug.

Workspace 8 is the CRT. It is not `keep_alive`, so it disappears when empty and Playnite shows through instead of
an empty screen. RetroArch no longer has a rule: it picks the CRT itself via `video_monitor_index`, set at logon.

## Keys

- Win+L cannot be bound: Windows reserves it below every keyboard hook. Lock is disabled in `windows-tweaks.reg`
  and Raycast runs `glaze-move-right.ps1` on Win+L. Without Raycast there is no move-window-right.
- Alt+Tab is unbound on purpose. GlazeWM's hook wins the race for any combo it binds, so binding it anywhere
  killed the native switcher. Workspace cycling is on Win+Tab.
- Win+D focuses workspace 0, which nothing homes to, so it shows the wallpaper. `toggle_workspace_on_refocus`
  makes a second Win+D flip back. Workspace 9 was tried first and failed because it can hold windows.
- Alt+Q is a graceful close (the app's own close path, may prompt to save). Alt+F4 stays native.
- The backtick quake terminal is AutoHotkey, not GlazeWM.

## Layout

`outer_gap.top` is 40px because the yasb bar reserves no screen space.
