# 🅿️ Rice parking lot
Open items + durable decisions. Detailed keybind design in Claude memory `ricing-todos-next`.

## ✅ Model (decided + live)
**Per-app Alt parity:** AHK = OS copy family ONLY (`Alt+C/X/V/A`→Ctrl, scoped out of WezTerm). Each app's OWN config carries the rest. `chezmoi apply` → AHK + each app's Alt-ified config = parity.
- ✅ **Zen** fully Alt-ified (Cmd→Alt), private=`Alt+Shift+N`, tracked (`setup-zen.ps1`)
- ✅ **WezTerm** Ctrl+C=interrupt · Alt+C/V copy/paste (flush-guarded) · WSL=`Ctrl+B,U`

## ⌨️ Open
- [ ] **GMEdit Alt-ify needs MANUAL setup first.** `customizedKeybinds` (user-preferences.json) is EMPTY — Ace defaults are hardcoded. Rebind to Alt **by hand** in GMEdit → Preferences → Keyboard → that populates the key → THEN track it. Selective only (Ace uses Alt for word-nav): save/find/replace/comment.
- [ ] **G502 (remind me).** Hybrid: G HUB maps buttons → F13–F20 (OS-neutral, syncs via Logi cloud) → tracked AHK(Win)+Karabiner(Mac) → actions. Layout (gist tcg/e7a9…): side=copy/paste, sniper=cut, DPI=undo/redo, tilt=desktop, profile=overview.
- [ ] **Mac standalone (Karabiner):** Caps dual-role (tap=Esc, hold=command) + copy gesture. *(Sitting AT the Mac — separate from KVM below.)*
- [ ] **KVM crossing (Mac drives THIS pc):** Deskflow/RustDesk modifier-map (Mac Cmd → right Win modifier) — the "moves keys around" finickiness. Chain: Karabiner(Mac) → Deskflow → AHK(Win).
- [ ] **Logitech Flow vs Deskflow** — all-Logitech; Flow may beat Deskflow's shuffle + no anti-cheat flag. Verify G502 supports Flow.

## 🎮 Playnite → folding INTO chezmoi (gamedev agent's handoff)
- Spec: `D:\REPOS\yabo-playnite-dotfiles\CHEZMOI-HANDOFF.md`. Fold the Playnite config backup in (windows-guarded managed files under `%APPDATA%\Playnite` + a `run_onchange` restore hook). Their `capture/restore-playnite.ps1` have the scrub/de-noise/vendor logic. Retires the standalone `yabo-san/yabo` repo. **AHK kill-on-game = config.json Pre/Post scripts → auto-tracked** (no separate wiring). My old `setup-playnite.ps1` is superseded → remove on fold.

## 🍎 Mac
- [x] Ghostty — KEEPING (decided).
- [ ] `borders` (FelixKratz) — keep or drop.

## 🅿️ Parked / decided
- **Obsidian** — do NOT Alt-ify (hotkeys.json is iCloud-synced w/ Mac → would break it). Keep `Mod`. Mod+T dup deferred. Guardian (iCloud fix) is in `windows-notes`; vault CONTENT cleanup = personal, NOT tracked.
- **Arch:** NO ("Arch at home"). · **rustdesk:** both scoop+PF (your call).
