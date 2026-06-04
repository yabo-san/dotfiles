# Windows registry tweaks — the invisible config

> Registry changes don't live in any config file, so a fresh machine silently
> loses them. This documents every tweak we made + ships a `windows-tweaks.reg`
> replica that reproduces them. Verified live 2026-06-04.
>
> These are the "registry fuckery" that make the keyboard/taskbar behave the way
> the rest of the setup assumes. Without them, GlazeWM/Raycast/WezTerm look
> wired but don't actually work right.

---

## The tweaks (current live values)

| Setting | Path | Value | Why |
|---------|------|-------|-----|
| **DisableLockWorkstation** | `HKCU\...\Policies\System` | `1` | Frees `Win+L` from the lock action so Raycast can bind it → move-window-right bridge. See WIN-L-BRIDGE.md. |
| **MMTaskbarEnabled** | `HKCU\...\Explorer\Advanced` | `1` | Taskbar shows on all monitors (default-ish; noted so it's intentional). |
| **Taskbar auto-hide** | `HKCU\...\Explorer\StuckRects3` | byte[8]=`3` | Taskbar auto-hides so GlazeWM/YASB own the screen edge. (Binary blob — can't be a simple .reg line; toggle in Settings → Personalization → Taskbar → "Automatically hide".) |

**Deliberately NOT set:**
- `EnableAutoTray` — show-all-tray-icons. We decided against it (YASB systray handles tray; you don't use the Windows taskbar tray). Documented here so future-me knows it was a *choice*, not an omission.

---

## What it SHOULD look like vs. what a fresh machine gives you

| Behavior | Fresh Windows | After these tweaks (what we want) |
|----------|---------------|-----------------------------------|
| `Win+L` | locks the PC | freed → Raycast bridges it to move-window-right |
| Taskbar | always visible, bottom | auto-hidden → screen edge belongs to YASB |
| Taskbar across monitors | primary only | all monitors (`MMTaskbarEnabled=1`) |

So on a fresh box, until you run the replica below + flip auto-hide:
- `Win+L` will LOCK instead of moving a window (the Raycast bridge will appear dead)
- the Windows taskbar will be visible, fighting YASB for the top/bottom edge

---

## Replica — reproduce on a fresh machine

Run `windows-tweaks.reg` (in this folder), then:
1. **Auto-hide taskbar** (can't be cleanly scripted via .reg — it's a binary blob):
   Settings → Personalization → Taskbar → Taskbar behaviors → ✅ "Automatically hide the taskbar"
2. **Restart Explorer** so changes take: `Stop-Process -Name explorer -Force` (it auto-respawns)
3. Re-bind `Win+L` in Raycast (the binding itself is in Raycast's encrypted DB, not here — see WIN-L-BRIDGE.md).

---

## Hard-to-capture (document only — can't be automated)

These have no config file and must be redone by hand on a fresh machine:

- **Raycast hotkey bindings** — stored in Raycast's encrypted SQLite. Re-add: Settings → Extensions → Script Commands → add `~/.config/scripts/raycast` → bind `Win+L` to "Glaze Move Right".
- **App logins / auth** — Discord, Steam, browsers, etc. Inherently manual.
- **Windows account / username** — the OS account stays whatever it is; "yabo" identity lives in the shell prompt, not the OS (see prompt config).
- **Apps with no scoop/winget/choco package — install manually (download + license/auth):**
  | App | Where | Notes |
  |-----|-------|-------|
  | Ableton Live (Suite, current) | ableton.com | winget only has v10; license auth manual anyway |
  | reWASD | rewasd.com | commercial controller remapper, no pkg manager |
  | EmuDeck | emudeck.com | |
  | Slippi Launcher | slippi.gg | |
  | Aseprite | Steam (or compile) | you own it on Steam |
  | GameMaker (modern) | gamemaker.io | GMS 1.4 = local installer |
  | Elgato 4K Capture / Camera Hub | elgato.com | |
  Everything else: `scoop import scoopfile.json` + `winget import winget-packages.json`.
