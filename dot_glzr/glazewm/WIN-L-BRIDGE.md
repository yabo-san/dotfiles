# Win+L → "move window right" — the registry + Raycast bridge

> Why this exists: `Win+L` is the one key GlazeWM can **never** capture on its
> own. Getting it to do something useful (move the focused window right) takes a
> registry change + Raycast as a relay. This documents the whole hack so future-me
> doesn't have to re-derive it. Verified 2026-06-04.

---

## TL;DR

| Key | What runs it | What it does |
|-----|--------------|--------------|
| `lwin+shift+l` | GlazeWM native | move window right (always works) |
| `Win+L` | Raycast → script → GlazeWM CLI | move window right (the bridge) |

Two keys, same action. `lwin+shift+l` is the bulletproof fallback; `Win+L` is the
reclaimed convenience key. If Raycast isn't running, `Win+L` does nothing — use
the fallback.

---

## Why GlazeWM can't have Win+L

Windows shortcuts are handled at two different layers:

- **Shell layer (`explorer.exe`)** — `Win+1-9`, `Win+D`, `Win+Tab`, `Win+S`, etc.
  GlazeWM's low-level keyboard hook (`WH_KEYBOARD_LL`) sits ABOVE this, so it
  swallows these cleanly and wins.
- **winlogon / OS-secure layer** — `Win+L` (lock) and `Ctrl+Alt+Del`. These are
  intercepted BELOW any low-level hook. GlazeWM's hook never even sees the
  keystroke. **No user-space app can bind Win+L through a normal hook.**

So GlazeWM literally cannot receive `Win+L`. That's why move-right's native bind
is `lwin+shift+l`, not `lwin+l`.

---

## The two-part hack

### Part 1 — registry: free the key from "lock"

`Win+L`'s default job is "lock workstation." Disable that action so the key isn't
consumed by the lock handler:

    HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System
        DisableLockWorkstation = 1   (DWORD)

Current value on this machine: **1 (lock disabled).**

To set it again if it ever resets (PowerShell):

    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
      -Name DisableLockWorkstation -Value 1 -PropertyType DWORD -Force

> NOTE: this disables the *lock action*. It does NOT hand the key to GlazeWM's
> hook (that layer still can't see it). It only stops Windows from eating the key,
> so something ELSE (Raycast) can grab it.

### Part 2 — Raycast: catch the key, call the GlazeWM CLI

Raycast captures hotkeys through a different mechanism than GlazeWM's hook, and it
CAN grab `Win+L`. So Raycast is the relay:

> **Win+L → Raycast hotkey → runs script command → script calls `glazewm command`**

**The script** (`D:\repos\scripts\raycast\glaze-move-right.ps1`):

    # @raycast.schemaVersion 1
    # @raycast.title Glaze Move Right
    # @raycast.mode silent
    # @raycast.packageName GlazeWM
    & "C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe" command move --direction right

**Wiring it in Raycast (one-time, manual — Raycast stores this in its own DB):**
1. Raycast → Settings → Extensions → Script Commands → add directory
   `D:\repos\scripts\raycast`
2. Find "Glaze Move Right" → assign hotkey → press `Win+L`.

---

## Rebuild checklist (fresh machine / after a wipe)

1. `DisableLockWorkstation = 1` in the registry (Part 1).
2. Script file present at `D:\repos\scripts\raycast\glaze-move-right.ps1` (Part 2).
3. Raycast: add the script-commands directory + bind `Win+L`.
4. Test: focus a tiled window, press `Win+L` → it moves right.
   - Moves right ✅ done.
   - Nothing happens → Raycast not running, or hotkey not bound. Fall back to
     `lwin+shift+l`.
   - PC locks → the registry value didn't take; re-apply Part 1.

---

## Adding more bridged keys later

Same pattern for any other key GlazeWM can't capture: copy the script, change the
`@raycast.title` and the final `glazewm command ...` line, bind a new hotkey in
Raycast. Keep it to keys GlazeWM genuinely can't have — each Raycast script spawns
a PowerShell process (~100-300ms lag), so don't bridge keys GlazeWM can bind natively.
