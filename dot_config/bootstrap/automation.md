# What runs by itself, and what starts it

Keys are in `keyboard-map.md`. This is everything else.

## At boot, before login

| what | started by | does |
| --- | --- | --- |
| `scripts/gpu/recover-gpu.ps1` | scheduled task, at startup, as SYSTEM (`Task Scheduler > recover-gpu`, registered by `run_onchange_after_register-recover-gpu`) | re-enables the GPU after a hang, so all three monitors exist before the CRT scripts look |

## At login

Startup folder shortcuts (`shell:startup`). The four PowerShell ones are made by `run_onchange_after_startup-shortcuts` and run through `conhost.exe --headless`, so no console window flashes.

| shortcut | runs | does |
| --- | --- | --- |
| `GlazeWM.lnk` | `glazewm.exe` | tiling and workspaces |
| `YASB.lnk` | `yasb.exe` | the top bars |
| `hotkeys.lnk` | `scripts/hotkeys.ahk` | every AHK remap |
| `mount-nas.lnk` | `scripts/nas/mount-nas.ps1` | waits for Tailscale, then mounts N: |
| `yasb-crt-bar.lnk` | `scripts/yasb/fix-crt-bar.ps1` | points the CRT bar at whatever display number the CRT has today |
| `retroarch-crt.lnk` | `scripts/retroarch/bind-crt.ps1` | points RetroArch at the CRT the same way |
| `obsidian-sync.lnk` | `scripts/obsidian/start-sync-daemon.ps1` | syncs D:\obsidian\sb with iCloud for the Mac |

## Around a game

Playnite's global scripts (planted by `run_onchange_after_playnite-scripts`).

| when | runs | does |
| --- | --- | --- |
| game starts | `scripts/playnite/pre-game.ps1` | stops AutoHotkey and kills GlazeWM |
| game exits | `scripts/playnite/post-game.ps1` | starts both again |

## When you ask

| how | runs | does |
| --- | --- | --- |
| Win+R | `scripts/glazewm/safe-reload.ps1` | reloads GlazeWM and puts windows back |
| Win+Tab / Win+Shift+Tab | `scripts/glazewm/cycle-window.ps1` | next / previous window on any workspace; the mouse follows |
| Raycast "Bind CRT" | `scripts/raycast/bind-crt.ps1` | runs both CRT scripts after a display change |
| Raycast "Reconnect NAS" | `scripts/raycast/reconnect-nas.ps1` | remounts N: |
| Raycast "AHK On" / "AHK Off" | `scripts/raycast/ahk-on.ps1`, `ahk-off.ps1` | hotkeys on or off |
| Win+L (Raycast "Glaze Move Right") | `scripts/raycast/glaze-move-right.ps1` | moves the window right |
| Raycast "Classic Start Menu" | `scripts/raycast/classic-start-menu.ps1` | opens Open-Shell |
| Raycast "Add App to Workspace" | `scripts/raycast/add-app-to-workspace.ps1` | pick a workspace, then a running app from a list (apps already tiled are hidden); adds it to `.chezmoidata/glazewm.yaml`, applies, reloads |
| Raycast "Crysis Sandbox 2 Editor" | `scripts/raycast/launch-crysis-editor.ps1` | Crysis 1 editor through c1-launcher |
| by hand | `scripts/playnite/export-emulation.ps1` / `apply-emulation.ps1` | emulator profiles and RomM mappings in and out of `playnite/emulation.json` |

## On `chezmoi apply`

`.chezmoiscripts/windows/`. `run_onchange_` runs only when the script's text changes; `run_after_` runs every apply.

| script | does |
| --- | --- |
| `startup-shortcuts` | writes the login shortcuts above |
| `map-nas` | maps N: |
| `powershell-profile-bridge` | points `$PROFILE` at the dotfiles profile |
| `playnite-scripts` | plants Playnite's game-start and game-exit hooks |
| `register-recover-gpu` | registers the boot task |
| `install-rohankar` | installs y4bo |
| `install-obsidian-sync` | clones and sets up the vault sync tool |
| `retroarch-config` (every apply) | the CRT settings in Steam RetroArch |
| `retroarch-cores` (every apply) | Brimir, SwanStation and LRPS2 into Steam RetroArch |
