# dotfiles

My personal dotfiles, managed with [chezmoi](https://www.chezmoi.io/), for one setup across three places. Based on
[rio/dotfiles](https://github.com/rio/dotfiles). It works out of the box with:

- **Windows**: a de-Windowsed desktop (tiling, a status bar, Mac-style keys), installed by scoop and winget
- **macOS**: Homebrew plus mise
- **Linux dev containers**: [Devsy](https://github.com/devsy-org/devsy), VS Code Dev Containers, Zed, GitHub Codespaces

Each OS only gets its own files (gated in `.chezmoiignore`). Tools with no package are pulled as pinned releases.

---

## Repository Structure

```
├── .chezmoidata/          # data the templates read (glazewm.yaml: which app lives on which workspace)
├── .chezmoiexternals/     # pinned downloads: devsy, mise, neovim, launchers, RetroArch cores
├── .chezmoiignore         # what each OS does NOT get
├── .chezmoiscripts/       # hooks per OS: windows/, darwin/, unix/ (packages, shortcuts, NAS, Playnite)
├── AppData/               # Windows app configs that live in %APPDATA% (FilePilot, Zed, ...)
├── dot_config/            # XDG configs: nvim, wezterm, ghostty, mise, starship, yasb, powershell, scripts
│   └── bootstrap/         # Windows: package lists, registry tweaks, how-it-works, keyboard map, automation
├── dot_glzr/              # GlazeWM (config.yaml.tmpl, generated from .chezmoidata/glazewm.yaml)
├── dot_hammerspoon/       # macOS quake toggle
├── dot_*                  # bashrc, zshrc, gitconfig, tmux, wslconfig
├── private_dot_ssh/       # SSH config (never applied on Linux)
├── Brewfile               # macOS packages
├── bootstrap.ps1          # Windows one-liner
├── bootstrap.sh           # Linux / dev container one-liner
└── setup                  # zsh + pure prompt, inherited from rio
```

---

## Usage

### 1. Windows

In a **normal (not elevated)** PowerShell window; scoop refuses to install as admin:

```powershell
irm https://raw.githubusercontent.com/yabo-san/dotfiles/main/bootstrap.ps1 | iex
```

This will:
- install scoop, then git and chezmoi
- run `chezmoi init --apply yabo-san/dotfiles`
- import the scoop and winget package lists and apply the registry tweaks

The leftovers that need a human are in `dot_config/bootstrap/windows-notes.txt`.

> **Never tested on a clean Windows install.** Built on a live machine and captured into the repo.

### 2. macOS

```sh
# homebrew: https://brew.sh, then mise from its own installer (not homebrew): https://mise.jdx.dev
brew bundle
chezmoi init --apply yabo-san
```

### 3. Linux and dev containers

`bootstrap.sh` installs chezmoi and applies the repo in one step. Point Devsy's or Codespaces' dotfiles option at this
repo and every container gets the same shell. Linux gets a trimmed dev shell and never gets `.ssh/`.

### 4. Day to day

- `chezmoi apply`: apply the repo to the machine
- `chezmoi update`: pull and apply
- `chezmoi re-add <file>`: an app changed its own config, bring it back into the repo

---

## Highlights

| | Windows | macOS |
| --- | --- | --- |
| Window manager | GlazeWM, opt-in: only listed apps tile | AeroSpace |
| Bar | YASB | |
| Terminal | WezTerm, quake drop-down on `` ` `` (AutoHotkey) | Ghostty, quake on `` ` `` (Hammerspoon) |
| Shell | PowerShell 7, a port of the zshrc | zsh |
| Launcher | Raycast | Raycast |
| Files | File Pilot, yazi | |
| Keys | Alt sits where Cmd is: Alt+C/V/X/Z, Alt+Q quits | native |

Everywhere: Neovim (LazyVim), starship, mise for tools, lazygit, bat.

How the Windows side fits together: `dot_config/bootstrap/how-it-works.md`. Every key: `dot_config/bootstrap/keyboard-map.md`.
What runs by itself and what starts it: `dot_config/bootstrap/automation.md`.

---

## Customization

- **Put an app on a workspace**: Raycast "Add App to Workspace" (pick the window, the workspace, tile or float), or
  add a line to `.chezmoidata/glazewm.yaml` and `chezmoi apply`
- **Add a package**: `dot_config/bootstrap/scoopfile.json` or `winget-packages.json` (Windows), `Brewfile` (macOS),
  `dot_config/mise/config.toml` (CLI tools everywhere)
- **Add a pinned download**: `.chezmoiexternals/`
- **Add a hook**: `.chezmoiscripts/<os>/`

---

## TODO

- run the Windows bootstrap on a clean install
- back up the Raycast config
- a PowerShell helper for Devsy port forwarding

## License

Provided as-is for personal use and inspiration. Use at your own risk.
