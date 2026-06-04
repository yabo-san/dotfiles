# THE RICE — yabo's Windows setup (a "coming home to Windows" build)

A reproducible, version-controlled Windows environment that mirrors a Mac/Linux
workflow. Everything here is chezmoi-tracked and OS-gated (one repo → mac /
Windows / WSL). Goal: factory reset → one command → fully wired.

---

## Window manager — GlazeWM (opt-in tiling)
- Config: `~/.glzr/glazewm/config.yaml`
- **Float by default, allowlist tiles** (inverted model — ~12 apps tile, ~380
  games float). Adding an app = add its `window_process` to the `set-tiling`
  allowlist.
- Workspaces 1–10, unbound/roaming, named with purpose ICONS in `display_name`
  (the icon travels with the workspace across monitors).
- Keybinds (lwin): `h/j/k` move window · `1–0` focus ws · `shift+1–0` send to ws ·
  `shift+h/j/k/l` move ws→monitor · `t` float toggle · `m` fullscreen ·
  `shift+r` reload. Win+L (right-move) bridged via Raycast (Windows reserves it).
- CRT monitor kept hands-off (retro/games).

## Bar — YASB 2.0 (Catppuccin)
- Config: `~/.config/yasb/{config.yaml,styles.css}` · font: Hack Nerd Font
- Widgets: glazewm workspaces + tiling-direction, pomodoro, active-window, clock,
  systray (alt+click to pin), cava, media. Taskbar auto-hidden.
- (A Vista glass theme was tried + reverted; kept at `styles.css.vista-ref`.)

## Terminal — WezTerm
- Config: `~/.config/wezterm/wezterm.lua` — mirrors ghostty (Catppuccin Mocha,
  Hack NF, copy-on-select, ctrl+b leader splits/tabs).
- **Quake dropdown**: backtick (`` ` ``) toggles globally (AutoHotkey), follows the
  cursor monitor, remembers height, hidden from Alt-Tab. ctrl+backtick = literal `.
  Scripts: `~/.config/scripts/wezterm/`.
- **Background image**: dark-red horror art, explicit aspect-matched dims
  (0.895 ratio so it never stretches), cropped so the figure sits bottom-center.
  Tune by scaling width/height together in the `config.background` block.

## Shell — PowerShell (zsh parity)
- Profile: `~/.config/powershell/Microsoft.PowerShell_profile.ps1`
- vi-mode, native Pure-style prompt (~5ms; starship kept for WSL), EDITOR=nvim,
  XDG_CONFIG_HOME=~/.config (so tools read ~/.config like Linux).
- **The trio**: `zoxide` (cd by frecency — `cd <partial>` jumps), `atuin`
  (Ctrl+R history), `fzf`/PSFzf (Ctrl+T files, Alt+C cd).
- **CLI pack**: btop(top) · dust(du) · duf(df) · procs(ps) · gdu · tldr · delta ·
  bat(cat) · lsd(ls) · ripgrep · fd · fastfetch(ff).
- Aliases: v=nvim, gp/gs, lg=lazygit, k=kubectl (lazy completion).
- **Unix commands**: `unix-aliases.ps1` hand-rolls the gaps (open/touch/which/
  head/tail/wc/pbcopy/pbpaste/export/sudo/mkcd). **SIDESTEP:** all of this can be
  replaced by `scoop install uutils-coreutils` — a Rust GNU-coreutils port that
  gives real `cp`/`mv`/`rm -rf`/`head`/`ls --color`/etc. with proper unix flags.
  We hand-rolled instead (it can shadow PowerShell built-ins), but coreutils is
  the one-command way to get true unix commands if preferred.

## Package management — scoop-first, `brew` wrapper
- **scoop** is primary (per-user, no UAC). Manifest: `bootstrap/scoopfile.json`.
- **`brew`** = unified wrapper (also `brew` on mac/WSL). Falls through:
  scoop → winget(community) → winget(**msstore**) → choco. Verbs: install / search
  / upgrade / uninstall. Arch mental model: scoop+winget = official, choco = AUR.
- `gsudo` = sudo-for-Windows (elevation w/ UAC).
- Manual/Store apps documented: `bootstrap/msstore-apps.md`, `WINDOWS-REGISTRY.md`.

## Files
- **yazi** (`y`) — terminal file manager, cd-on-quit, previews (poppler/ffmpeg/
  imagemagick). Open source, cross-platform. The daily driver.
- **File Pilot** (`Voidstar.FilePilot`, winget) — fast GUI file manager (tiled by
  glaze, process `FPilot`). Proprietary but fairly-licensed (pay-for-a-year-of-
  updates, keep forever) AND winget-managed, so it's reproducible.
- **Win+E** — stock Explorer. Classic right-click menu via registry
  (see `classic-context-menu-and-windhawk.md` — Windhawk removed, it crashed FilePilot).
- (Tried `FilesCommunity.Files` — open-source GUI FM — but it's sluggish/UWP-feel,
  uninstalled. yazi covers the open-source need; File Pilot covers fast-GUI.)

## Git — lazygit + delta
- `lg` = lazygit (Catppuccin, `~/.config/lazygit/config.yml`).
- delta = git pager (pretty diffs on CLI + inside lazygit). `~/.gitconfig` tracked.

## Cross-platform (the point)
- **chezmoi** source: `~/.local/share/chezmoi` (repo: yabo-san/dotfiles).
- OS-gated via `.chezmoiignore`. Same trio/CLI/lazygit/yazi/brew on mac via
  `Brewfile` + `dot_zshrc`. Mac tiling = `dot_config/aerospace/aerospace.toml`
  (mirrors the glaze keymap).
- Identity "yabo" lives in the prompt + fastfetch (OS account renamed at reset).

## Bootstrap a fresh machine
1. Install scoop, add buckets (extras, nerd-fonts, games, nonportable).
2. `scoop import bootstrap/scoopfile.json` + `winget import bootstrap/winget-packages.json`.
3. MS Store apps: see `bootstrap/msstore-apps.md`. Manual apps: `WINDOWS-REGISTRY.md`.
4. `chezmoi init --apply yabo-san/dotfiles`.
5. Apply `bootstrap/windows-tweaks.reg` (DisableLockWorkstation, classic context menu, etc.).
6. Manual: Raycast Win+L binding, app logins, the few non-packaged apps.
