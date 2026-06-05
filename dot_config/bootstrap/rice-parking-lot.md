# 🅿️ Rice parking lot
Everything open/parked from the rice marathon (2026-06-04/05). Detailed keybind design
is in Claude memory `ricing-todos-next`; this is the browsable checklist.

## ✅ Done this run (context)
- AHK = OS-level copy family ONLY: Alt+C/X/V/A → copy/cut/paste/select-all (scoped OUT of WezTerm; Alt+Tab/F4/ShareX untouched; live). App shortcuts live in each app's OWN config now.
- **Zen** = ALL command shortcuts Alt-ified (Cmd/Ctrl→Alt = mac parity) in zen-keyboard-shortcuts.json; private window = Alt+Shift+N; tracked via `setup-zen.ps1` (restore/snapshot, resolves random profile-id). Ctrl+Alt combos + F-keys kept; Alt+R reload is AMD-blocked → use F5. **Model: chezmoi apply → AHK (copy family) + each app's Alt-ified config = full parity.**
- WezTerm: Ctrl+C = always interrupt · Alt+C/Ctrl+Shift+C guarded so empty copy can't FLUSH the clipboard · WSL tab → Ctrl+B then U (off AMD's Ctrl+Shift+U)
- RustDesk un-tiled in glaze (transient session window was flashing the layout)
- `game-mode.ps1` — kills AHK during Playnite games (anti-cheat safe), relaunches after
- Obsidian config guardian (full config incl Templater) · package/Raycast dedup → single source · `lwin+d` show-desktop toggle · sketchybar dropped (default macOS bar) · `grifting` → private repo · scrubbed ALL Claude attribution from every repo

## ⌨️ Keybinds / cross-machine parity
- [ ] **Wire Playnite global scripts** → OnGameStarting `game-mode.ps1 -On`, OnGameStopped `-Off`. Verify it lands in `config.json`.
- [ ] **Mac side (Karabiner):** Caps dual-role (tap=Esc, hold=command) + mirror the copy binds so the gesture matches Windows (Windows Alt-remaps already live).
- [ ] **Finalize modifier model:** Alt-as-command is LIVE on Windows (Alt+C/X/V/A). Reconcile w/ Caps dual-role (Esc tap / Hyper hold). Likely both: Alt = copy-family, Caps = Esc + hyper layer.
- [ ] **Extend Alt-remaps?** Z/S/F etc. — ⚠️ Alt+F/S/V shadow menu mnemonics (Alt+F=File, Alt+V=View).
- [ ] **Logitech Flow vs Deskflow** — all-Logitech (MX Mechanical + G502); Flow may beat Deskflow's modifier-shuffle + no anti-cheat. Verify G502 model supports Flow.
- [ ] **G502 mapping (DEFERRED — remind me):** hybrid = G HUB maps buttons → F13–F20 (OS-neutral, syncs via Logi cloud) → tracked AHK(Win)+Karabiner(Mac) map those → per-OS actions. Desired layout (gist https://gist.github.com/tcg/e7a9f9e9980bba68cda59557fb31d54e + its comment): side btns=copy/paste, sniper=cut, DPI up/down=undo/redo, tilt L/R=desktop switch, profile=overview. I'll scaffold the AHK F13–F20 block when you say go.
- [ ] **Window-switcher parity** — Raycast switcher on both / GlazeWM focus (lwin+hjkl). Native Alt+Tab is already window-level.

## 🎮 Playnite — ⏸️ HANDED OFF to another agent (2026-06-05); don't touch from here
(Prior decision kept for ref. The `game-mode.ps1` Playnite-wiring item above is also that agent's domain now.)
### (ref) DEV-ONLY EXTENSION reference — DECIDED; supersedes the backup idea
- [x] `dot_config/bootstrap/setup-playnite.ps1` — installs Playnite (winget) → clones the PRIVATE yabo-launcher repo → builds YaboLibrary → runs the launcher's existing `dev/deploy-playnite-extension.ps1`. Public dotfiles stay generic + secret-free; the private extension owns the library/feed/curation = the real "backup".
- [ ] **Retire `yabo-san/yabo`** (old standalone backup repo) — the extension + this script ARE the backup now.
- [ ] Playnite `config.json` (theme/global) doesn't carry — set on first run or document.
- [ ] (run setup-playnite.ps1 with Playnite CLOSED; needs gh token + .NET SDK on the dev machine.)

## 🍎 Mac
- [x] Ghostty — KEEPING it (decided, not switching). Accept no inline-image rendering.
- [ ] `borders` (FelixKratz) — keep (active-window highlight for aerospace) or drop.

## 🅿️ Parked / decided
- **Arch:** NO — "Arch at home" (homelab). Optional: weave the "don't need Arch" closer into the coming-home LinkedIn post.
- **rustdesk:** kept in scoop + Program Files (both, your call).

## 🧠 Obsidian
- Only the **iCloud-clobber FIX (the guardian)** is documented — in `windows-notes`. That's it.
- Vault **content** cleanup is a PERSONAL task → deliberately **NOT** tracked in the dotfiles.
- [ ] **Alt-ify hotkeys (same as Zen) = PAUSED** — later, do Cmd/Ctrl→Alt in `hotkeys.json` + track it. Obsidian's been the troublemaker, so not now.
