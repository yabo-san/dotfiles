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
