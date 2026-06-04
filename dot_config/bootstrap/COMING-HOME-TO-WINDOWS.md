# Coming Home to Windows

> A platform engineer rebuilding a Windows gaming PC the way you'd build
> infrastructure: declarative, reproducible, version-controlled. Not "settling
> for Windows" — making Windows *mine*. This is the master narrative; detail
> docs are linked at the bottom.

---

## The thesis

I live in GitOps, Linux, mac. Windows was the thing I booted to play games. This
is the rebuild that made it a first-class, reproducible environment — same
discipline as a k8s cluster, applied to a desktop that has to launch DOOM.

The principles that kept transferring:
- **Float by default, opt into management.** (Window manager *and* package manager.)
- **The repo is the source of truth.** If it's not declarative, it's not real.
- **Diagnose the host before you blame the app.** (Cost me hours on a "slow RomM"
  that was actually a dying k3s cluster — see below.)
- **Path-agnostic everything.** Never hardcode `C:\Users\<name>` — so the username
  mess (and a coming factory reset) don't matter.

---

## The stack we built

| Layer | Tool | Mac equivalent | Notes |
|-------|------|----------------|-------|
| Package manager | **scoop** (per-user, no UAC) | brew | the bootstrap foundation |
| Window manager | **GlazeWM** | FlashSpace | opt-in tiling, vim keys |
| Status bar | **YASB** (per-monitor) | SketchyBar | minimal bar on the CRT |
| Terminal | **WezTerm** | ghostty | one cross-platform lua config |
| Multiplexer | tmux (via WSL) | tmux | the real cross-machine panes |
| Editor | **LazyVim** | (shared) | base fetched, 5 override files tracked |
| Shell | PowerShell (vi-mode, starship) + WSL | zsh + pure | full dot_zshrc parity |
| Quake term | WezTerm + AutoHotkey | ghostty native | follows cursor, remembers height |
| Launcher | Raycast | Raycast | + the Win+L bridge hack |
| Dotfiles | chezmoi | chezmoi | one repo, OS-gated, mac+win+WSL |

---

## Key decisions (and why)

**Opt-in tiling, not denylist.** 455 installed programs, ~380 games. A "tile by
default, exclude games" denylist could never keep up. Flipped GlazeWM to
`initial_state: floating` + a ~30-app allowlist. Games/launchers/unknowns float
automatically forever. THE architectural win.

**scoop over winget.** winget triggers UAC on every install (system-wide). scoop
is per-user, no elevation, exports to a manifest — the real brew-equivalent.
~80% of apps are scoopable; the rest documented as winget/manual.

**WezTerm over staying on Windows Terminal quake.** WT quake can't be resized and
has no config parity with mac. WezTerm: resizable, GPU, one lua config for
mac+win, tmux-style ctrl+b leader. The quake "follow active monitor" is scripted
(cursor-follow, mirrors ghostty `screen=cursor`) — slightly slower toggle than
WT native, worth it for resize + parity.

**Username "yabo" lives in the prompt, not the OS.** Renaming a Microsoft-account
profile folder (`C:\Users\senio`) is unsupported and breaky. Instead: factory
reset will create the `yabo` account clean, and meanwhile the starship prompt
shows "yabo" regardless of the OS account. Path-agnostic dotfiles make the folder
name irrelevant.

**Workspaces unbound (roaming), not monitor-pinned.** `bind_to_monitor` is a
fragile position-index that scrambles when you unplug a monitor (esp. the
EDID-less CRT). Roaming workspaces survive unplugging. Tradeoff: no fixed app
homes, but bulletproof.

---

## Dead-ends & lessons (the honest part)

- **"RomM is slow" → was a dying k3s cluster.** The home-cluster (Flux/Longhorn/
  Prometheus on 8GB) was crash-looping, pinning the host at load 24 / 68% IO-wait.
  Killed k3s → everything (RomM, Stash, arr) recovered. Lesson: diagnose the host.
- **Epic/DOOM "GPU crashes" → DWM instability from TranslucentTB**, not GlazeWM.
  Chased the wrong layer twice before checking `dwm.exe` uptime.
- **Start menu "opens then closes" → GlazeWM stealing focus** + the bind eating
  the Win key. Fixed with shell-surface ignore rules + freeing the alt modifier.
- **Playnite 7-min startup → a hung GameVault plugin** (dead network dep), not the
  1,800-game library. Wiped Playnite clean; rebuild via yabo export.
- **`disabled.lua` had `#` instead of `--`** — a shell comment in a Lua file,
  silently erroring nvim for who-knows-how-long. Read configs as a whole.

---

## Detail docs

- [HOTKEYS.md](../../.glzr/glazewm/HOTKEYS.md) — GlazeWM keymap, plain English
- [WIN-L-BRIDGE.md](../../.glzr/glazewm/WIN-L-BRIDGE.md) — the Win+L registry+Raycast hack
- [WINDOWS-REGISTRY.md](WINDOWS-REGISTRY.md) — registry tweaks + replica .reg
- [PLAYNITE-TODO.md](../../.glzr/glazewm/PLAYNITE-TODO.md) — Playnite/GlazeWM pause notes

## Bootstrap a fresh machine
1. Create the account as **yabo** (clean `C:\Users\yabo`)
2. Install scoop → add buckets (extras, nerd-fonts) → `scoop import scoopfile.json`
3. `winget import winget-packages.json` (the non-scoop GUI apps)
4. Run `windows-tweaks.reg` + enable taskbar auto-hide
5. `chezmoi init --apply yabo-san` (Windows files) ; again inside WSL (zsh/nvim/tmux)
6. Manual: Raycast hotkey bindings, app logins, the ~5 un-packaged apps
