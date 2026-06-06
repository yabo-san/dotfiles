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
- [ ] **KVM crossing — UNTESTED both directions (the real gap).** Standalone maps are physically consistent; the Deskflow/RustDesk crossing is NOT verified.
  - *Mac → this PC* (common, you live on Mac): likely OK — Cmd → Alt or Ctrl → copy works either way.
  - *this PC → Mac* (risky): AHK turns `Alt+C`→`Ctrl+C` on Win FIRST → crosses as Ctrl+C → Mac won't copy (needs Cmd). Comes down to hook order (AHK vs Deskflow capture) — untestable without trying.
  - **Fix lever:** Deskflow/RustDesk per-screen modifier-map = Mac-Cmd ↔ Win-Alt (the command/thumb key). For the Win→Mac AHK double-remap: map Win-Ctrl→Mac-Cmd, or accept it's the rarer direction.
  - **Action:** test each direction (copy/paste), report, then fix. Needs both machines + live KVM.
- [ ] **Logitech Flow vs Deskflow** — all-Logitech; Flow may beat Deskflow's shuffle + no anti-cheat flag. Verify G502 supports Flow.

## 🎮 Playnite → folding INTO chezmoi (gamedev agent's handoff)
- Spec: `D:\REPOS\yabo-playnite-dotfiles\CHEZMOI-HANDOFF.md`. Fold the Playnite config backup in (windows-guarded managed files under `%APPDATA%\Playnite` + a `run_onchange` restore hook). Their `capture/restore-playnite.ps1` have the scrub/de-noise/vendor logic. Retires the standalone `yabo-san/yabo` repo. **AHK kill-on-game = config.json Pre/Post scripts → auto-tracked** (no separate wiring). My old `setup-playnite.ps1` is superseded → remove on fold.

## 🎮 AHK game-pause — focus-aware (PARKED 2026-06; current toggle is FINE for now)
**Current (KEEP — verified e2e):** whole-session kill via `game-mode.ps1 -On` (OnGameStarting → kill AHK = raw input, anti-cheat safe) / `-Off` (OnGameStopped → relaunch). Gap: alt-tabbing OUT of a game mid-session leaves AHK dead until you fully quit. **The "global pause" goal = AHK `Suspend` so a game's `Alt+C` stays raw (not remapped to Ctrl+C).**
**TODO — make it focus-aware so alt-tab-OUT restores copy/paste** (design validated vs Playnite source):
- Playnite **`GameStartedScript`** ("during" slot, currently `null`) exposes **`$StartedProcessId`** + **`$Game.InstallDirectory`** ([docs](https://api.playnite.link/docs/manual/gameScripts.html)).
- Wire: that slot writes PID+install-dir + spawns a watcher → watcher sets an `in-game` flag when the foreground window is a **descendant of `$StartedProcessId`** (catches launcher→child, e.g. Quake Injector `javaw` → Quake engine) **OR** its exe is under the install dir (catches launcher-exit orphan) → AHK reads the flag + `Suspend`s; PostScript clears it.
- **Caveat:** `$StartedProcessId` absent for some launcher games → fall back to the whole-session kill above.
- **Test FIRST (don't theorize):** Quake Injector → launch a map (Playnite→javaw→engine), alt-tab out, probe the tree to confirm descendant-walk + install-dir tag the engine.
- Set `GameStartedScript` via Playnite UI **or** edit `config.json` while Playnite CLOSED (it owns config.json live). Note `quake-hotkey.ahk` = the WHOLE AHK config (copy family + quake + ShareX + Obsidian), not just the terminal.

## 🍎 Mac
- [x] Ghostty — KEEPING (decided).
- [ ] `borders` (FelixKratz) — keep or drop.

## 🅿️ Parked / decided
- **Obsidian** — do NOT Alt-ify (hotkeys.json is iCloud-synced w/ Mac → would break it). Keep `Mod`. Mod+T dup deferred. Guardian (iCloud fix) is in `windows-notes`; vault CONTENT cleanup = personal, NOT tracked.
- **Arch:** NO ("Arch at home"). · **rustdesk:** both scoop+PF (your call).
