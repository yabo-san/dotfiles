# Classic context menu + why Windhawk was removed

## TL;DR
- We use the **classic (Windows 10) right-click context menu** on Windows 11.
- It's done with a **registry key** — NOT Windhawk.
- **Windhawk was uninstalled** because it crashed **File Pilot** (our file explorer)
  via DLL injection (`0xc0000005` access violation).

## The story
1. Installed **Windhawk** intending to use its "classic context menu" mod.
2. Installed **File Pilot** (fast file manager). It crashed on launch every time —
   `Fatal Exception: Access Violation (0xc0000005)`, dropping `.dmp` files on the
   Desktop.
3. Diagnosed: **Windhawk injects a DLL into every process**, and that injection
   crashed File Pilot. Confirmed by stopping Windhawk → File Pilot launched fine.
4. Decision: we don't need Windhawk at all. The classic context menu has a native
   **registry** equivalent (no injection, nothing to crash File Pilot).

## How the classic context menu is set (reproducible)
This key is in `windows-tweaks.reg` (applied at bootstrap). Manual command:

```
reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve
```

Then restart Explorer (`Stop-Process -Name explorer -Force`, it respawns).

To REVERT to the Windows 11 menu:
```
reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f
```

## File manager choice
- **File Pilot** — fast GUI file manager (beta; download from filepilot.tech).
  Tiled by GlazeWM (process `FPilot` is in the glaze allowlist).
- **yazi** — terminal file manager (`y`), cross-platform via dotfiles.
- **Win+E** — still opens stock Explorer.

## Rule going forward
Don't reinstall Windhawk unless a specific mod is worth it AND File Pilot is
excluded from its injection (Windhawk Settings → Advanced → process exclusion).
