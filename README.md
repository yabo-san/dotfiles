# The idea:
- chezmoi pulls and syncs dot files
- mise installs whatever global packages you need

## notes on mac setup:
install [homebrew](https://brew.sh/)  
install [mise](https://mise.jdx.dev/getting-started.html) do not install using homebrew !!!  
install [chezmoi](https://www.chezmoi.io/install/#one-line-package-install)

### install all packages
```
brew bundle
chezmoi init --apply <your-github-username>
```

All packages are declared in `Brewfile` at the repo root.

Ghostty quick terminal (tilde drop-down) is configured in `~/.config/ghostty/config` — no extra setup needed.

if mise isn't installing everything you might have to manually run:  
$HOME/.local/bin/mise trust $HOME/.config/mise/config.toml && $HOME/.local/bin/mise install

also a note on .chezmoiexternals/mise.toml.tmpl:  
this is a very linux/devcontainer oriented dotfiles setup so the idea is that chezmoi will skip installing mise on mac. it does this by checking for a hostname on line 1 except hostnames are weird on mac
- typing 'hostname' in your terminal will append '.local' you dont want this
- chezmoi execute-template '{{ .chezmoi.hostname }}' -> appends '%' prompt character

heavily based on this [setup](https://www.skool.com/kubecraft/mise-devcontainers-dotfiles-a-developers-setup?p=8785e2d5)  
also found [here](https://github.com/rio/dotfiles)
also see: https://www.skool.com/kubecraft/classroom/1c6ab39e?md=a018c921401b4e0394d0971752ec43f8

## notes on windows setup:
A full "coming home to Windows" rice — same repo, OS-gated via `.chezmoiignore`.
Detailed bootstrap + gotchas live in `dot_config/bootstrap/windows-notes.txt`; this is the overview.

### the stack
| Layer | Tool | Version |
|-------|------|---------|
| Window manager | GlazeWM (opt-in tiling) | 3.10.1 |
| Status bar | YASB | 2.0.2 |
| Terminal | WezTerm + AHK quake (`` ` ``) | 20240203 |
| Shell | PowerShell (full zsh-parity port of `dot_zshrc`) | 7.5.5 |
| Launcher | Raycast (Win) · Open-Shell classic menu (Shift+Win) | — |
| Files | File Pilot (GUI) · yazi (TUI) · Win+E (Explorer) | 0.7.0 |
| Screenshots | ShareX — PrtSc / Ctrl+PrtSc; Win+Shift+S via AHK | 20.2 |
| Task manager | System Informer (replaces taskmgr via IFEO) | 3.2 |
| Archives | NanaZip (frontend) + 7-Zip (scoop/yazi dependency) | 6.0 |
| Remote desktop | RustDesk | 1.4.7 |
| System info | fastfetch (custom braille logo) | 2.64 |
| Prompt | native Pure-style (in-process, ~5ms) | — |

### package management
Everything is package-managed: **scoop** (default, no UAC) → **winget** → **choco** (kept empty,
AUR-tier fallback), unified behind a `brew` wrapper in the PS profile. Manifests in
`dot_config/bootstrap/`: `scoopfile.json` (~44), `winget-packages.json` (~128), `msstore-apps.md`.
Registry state in `windows-tweaks.reg`; Open-Shell in `openshell-settings.{reg,xml}`.

### bootstrap a fresh machine (see windows-notes.txt for the full list)
1. account name = `yabo`; install scoop + buckets (extras, games, nerd-fonts, nonportable)
2. `scoop import scoopfile.json` + `winget import winget-packages.json`
3. `chezmoi init --apply yabo-san/dotfiles`
4. apply `windows-tweaks.reg`; load `openshell-settings.xml` into Open-Shell
5. manual (Win11 won't script these): taskbar auto-hide, Raycast Win+L binding, PS modules to
   `$env:LOCALAPPDATA\PowerShell\Modules`, default-app "Open with → Always" choices

> ⚠️ **This Windows setup has NEVER been bootstrapped on a fresh Windows machine.**
> It was built incrementally on the existing install and reverse-captured into the repo.
> The bootstrap steps above are documented but **UNVERIFIED** — expect gaps and manual
> fixups until it's actually run end-to-end on a clean Windows install.

TODO:  
- **verify the Windows bootstrap on a clean install** (never done — see warning above)  
- backup raycast configuration even if it is encrypted  
- go through twitter bookmarks and youtube watch later for processing in obsidian  
- setup retroNAS and gamevault  
- cleanup steam and playnite installation on desktop pc  
- organize obsidian vault  
