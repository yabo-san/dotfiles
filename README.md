# dotfiles

One repo for Windows, macOS and Linux dev containers, managed by [chezmoi](https://www.chezmoi.io/).
Each OS only gets its own files (gated in `.chezmoiignore`), and tools with no package are pulled
as pinned releases (`.chezmoiexternals/`).

Heavily based on [rio/dotfiles](https://github.com/rio/dotfiles).

## Windows

One command, in a **normal (not elevated)** PowerShell window. Scoop refuses to install as admin.

```powershell
irm https://raw.githubusercontent.com/yabo-san/dotfiles/main/bootstrap.ps1 | iex
```

It installs scoop, then git and chezmoi, then runs `chezmoi init --apply yabo-san/dotfiles`,
imports the scoop and winget package lists, and applies the registry tweaks. The manual
leftovers are in `dot_config/bootstrap/windows-notes.txt`.

> **Never tested on a clean Windows install.** Built incrementally on a live machine and
> captured into the repo. Expect gaps the first time it runs end to end.

| Layer | Tool |
|-------|------|
| Window manager | GlazeWM |
| Status bar | YASB |
| Terminal | WezTerm, with an AutoHotkey quake drop-down on `` ` `` |
| Shell | PowerShell 7, a port of `dot_zshrc` |
| Launcher | Raycast, Open-Shell classic menu on Shift+Win |
| Files | File Pilot, yazi |
| Screenshots | Snipping Tool (Win+Shift+S) |

Packages: scoop first, then winget. Manifests live in `dot_config/bootstrap/`.

### Keyboard: who owns what

Three things sit on the keyboard. They claim different keys and never see each other's.

- **GlazeWM** owns the Win key (`Win+H/J/K/L` move, workspaces on a grid, `Win+1-4` / `Win+Q W` / `Win+D F` / `Win+C`, `Win+Shift+…` send/move) and
  `Alt+Q` (graceful close, Cmd+Q parity). Alt+Tab is deliberately unbound so the native switcher works.
  `Win+L` is the exception: Windows reserves it for lock below any keyboard hook, so the lock action is
  disabled in `windows-tweaks.reg` and Raycast runs `scripts/raycast/glaze-move-right.ps1` on it instead.
  No Raycast, no move-right.
- **AutoHotkey** (`scripts/wezterm/quake-hotkey.ahk`) owns only what nothing else can rebind, listed below.
  Playnite kills it before a game and restarts it after (anti-cheat, raw input); the Raycast commands
  `AHK Off` / `AHK On` are the manual version. GlazeWM keeps working with AHK dead.
- **Everything else** lives in each app's own config (WezTerm, Zen, Obsidian hotkeys), never in AHK,
  so nothing is double-bound.

| Scope | Key | Does |
|---|---|---|
| everywhere | `` ` `` | toggle the WezTerm quake dropdown |
| everywhere | ``Ctrl+` `` | type a literal backtick |
| not WezTerm / RustDesk | `Alt+C` `Alt+X` `Alt+V` `Alt+A` | copy / cut / paste / select all (Alt sits where mac's Cmd is) |
| not WezTerm / RustDesk | `Alt+Z`, `Alt+Shift+Z` | undo / redo |
| not WezTerm / RustDesk | `Alt+Shift+C/X/V/A` | passed through untouched (Zen copy-URL, addons, …) |
| Obsidian only | `Alt+Y` `Alt+M` `Alt+I` `Alt+N` `Alt+T` | browse vault / move file / Templater Zettel / new tab / daily note |
| Zen only | `Win+click` | Alt+click (split tab, Cmd+click parity) |

WezTerm is excluded because it binds `Alt+C/V` itself; remapped to `Ctrl+C` it would be SIGINT, not copy.
RustDesk is excluded so the remote machine gets the real keystrokes.

## macOS

```sh
# 1. homebrew: https://brew.sh
# 2. mise, from its own installer, NOT homebrew: https://mise.jdx.dev/getting-started.html
brew bundle
chezmoi init --apply yabo-san
```

Terminal is Ghostty; the backtick quake toggle is Hammerspoon (`dot_hammerspoon/init.lua`).
If mise did not install everything:
`~/.local/bin/mise trust ~/.config/mise/config.toml && ~/.local/bin/mise install`

## Linux (dev containers)

`bootstrap.sh` installs chezmoi and applies the repo in one step, for Devsy's dotfiles option or
any fresh box. Linux gets a trimmed dev shell and never gets `.ssh/`.

## TODO

- run the Windows bootstrap on a clean install
- back up the Raycast config
- a PowerShell helper for Devsy port forwarding
