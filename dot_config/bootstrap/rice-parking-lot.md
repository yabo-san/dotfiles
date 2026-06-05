# 🅿️ Rice parking lot
Everything open/parked from the rice marathon (2026-06-04/05). Detailed keybind design
is in Claude memory `ricing-todos-next`; this is the browsable checklist.

## ✅ Done this run (context)
- Alt+C/X/V/A → copy/cut/paste/select-all (AHK, scoped OUT of WezTerm; Alt+Tab/F4/ShareX-Win+Shift+S untouched; live)
- `game-mode.ps1` — kills AHK during Playnite games (anti-cheat safe), relaunches after
- Obsidian config guardian (full config incl Templater) · package/Raycast dedup → single source · `lwin+d` show-desktop toggle · sketchybar dropped (default macOS bar) · `grifting` → private repo · scrubbed ALL Claude attribution from every repo

## ⌨️ Keybinds / cross-machine parity
- [ ] **Wire Playnite global scripts** → OnGameStarting `game-mode.ps1 -On`, OnGameStopped `-Off`. Verify it lands in `config.json`.
- [ ] **Mac side (Karabiner):** Caps dual-role (tap=Esc, hold=command) + mirror the copy binds so the gesture matches Windows (Windows Alt-remaps already live).
- [ ] **Finalize modifier model:** Alt-as-command is LIVE on Windows (Alt+C/X/V/A). Reconcile w/ Caps dual-role (Esc tap / Hyper hold). Likely both: Alt = copy-family, Caps = Esc + hyper layer.
- [ ] **Extend Alt-remaps?** Z/S/F etc. — ⚠️ Alt+F/S/V shadow menu mnemonics (Alt+F=File, Alt+V=View).
- [ ] **Logitech Flow vs Deskflow** — all-Logitech (MX Mechanical + G502); Flow may beat Deskflow's modifier-shuffle + no anti-cheat. Verify G502 model supports Flow.
- [ ] **G502 productivity mapping** (Logi Options+, per-app) → gist. (Options+ not chezmoi-trackable → document.)
- [ ] **Window-switcher parity** — Raycast switcher on both / GlazeWM focus (lwin+hjkl). Native Alt+Tab is already window-level.

## 🎮 Playnite dotfilesify — via DEV-ONLY EXTENSION reference (DECIDED; supersedes the backup idea)
- [x] `dot_config/bootstrap/setup-playnite.ps1` — installs Playnite (winget) → clones the PRIVATE yabo-launcher repo → builds YaboLibrary → runs the launcher's existing `dev/deploy-playnite-extension.ps1`. Public dotfiles stay generic + secret-free; the private extension owns the library/feed/curation = the real "backup".
- [ ] **Retire `yabo-san/yabo`** (old standalone backup repo) — the extension + this script ARE the backup now.
- [ ] Playnite `config.json` (theme/global) doesn't carry — set on first run or document.
- [ ] (run setup-playnite.ps1 with Playnite CLOSED; needs gh token + .NET SDK on the dev machine.)

## 🍎 Mac
- [ ] Ghostty "can't draw art" — switch Mac terminal (kitty/iTerm for inline images) or accept Ghostty.
- [ ] `borders` (FelixKratz) — keep (active-window highlight for aerospace) or drop.

## 🅿️ Parked / decided
- **Arch:** NO — "Arch at home" (homelab). Optional: weave the "don't need Arch" closer into the coming-home LinkedIn post.
- **rustdesk:** kept in scoop + Program Files (both, your call).

## 🧠 Separate (not rice)
- Obsidian VAULT cleanup — plan delivered (inbox triage, Kubernetes MOC, delete stubs); your task.
