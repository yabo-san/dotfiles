; quake-hotkey.ahk — AutoHotkey v2
; Backtick key behavior (mirrors mac ghostty quick-terminal):
;   `        (bare backtick)  -> toggle the WezTerm quake dropdown (global)
;   Ctrl+`   (ctrl backtick)  -> type a literal backtick everywhere
;
; Uses vkC0 = the grave/backtick (~`) key, to avoid AHK's backtick-as-escape mess.
; Bare backtick is consumed globally; use Ctrl+` whenever you need to TYPE one.

#Requires AutoHotkey v2.0
#SingleInstance Force

; bare backtick -> fire the quake toggle script (hidden pwsh)
vkC0::
{
    ; A_ScriptDir = this file's folder, so the path is portable wherever chezmoi puts it
    Run('pwsh -NoProfile -WindowStyle Hidden -File "' . A_ScriptDir . '\quake-wezterm.ps1"', , "Hide")
}

; ctrl+backtick -> send a real backtick (escape hatch so you can still type one)
^vkC0::
{
    SendText("``")
}

; Win+Shift+S -> ShareX region capture (AHK swallows it BEFORE Windows snip, so
; Snipping Tool never fires; no reboot needed). Replaces the native snip key.
; KeyWait releases Win+Shift FIRST — else ShareX's region selector sees the held
; modifiers as mode-changers and the crosshair won't track the mouse (finicky).
#+s::
{
    KeyWait("LWin")
    KeyWait("Shift")
    Run('"' . EnvGet("USERPROFILE") . '\scoop\apps\sharex\current\ShareX.exe" -RectangleRegion')
}

; Win+W -> focus the Zen window WHEREVER it is — even cloaked on another glaze
; workspace, or minimized. DetectHiddenWindows lets us see it when glaze cloaks
; it; we pick the window with a real TITLE (the browser, not a hidden helper).
; We use GlazeWM's CLI to handle the workspace switch, then native activation
; to ensure it's in front. Only launches if Zen truly isn't running.
#w::
{
    DetectHiddenWindows true
    target := 0
    for idx, hwnd in WinGetList("ahk_exe zen.exe") {
        if (WinGetTitle("ahk_id " hwnd) != "") {
            target := hwnd
            break
        }
    }
    if (target) {
        ; Use GlazeWM CLI to focus the window, which handles workspace switching
        Run("glazewm.exe command 'focus --window-id " . target . "'", , "Hide")
        ; Native activation as fallback/ensure
        WinShow("ahk_id " target)
        if (WinGetMinMax("ahk_id " target) = -1)
            WinRestore("ahk_id " target)
        WinActivate("ahk_id " target)
    } else {
        Run('"C:\Program Files\Zen Browser\zen.exe"')
    }
}

; ── Mac-style copy/cut/paste on Alt ──────────────────────────────────────────
; On a Windows keyboard ALT sits where mac's Cmd is, so Alt+C/X/V == Cmd+C/X/V.
; Scoped OUT of WezTerm: the terminal binds Alt+C/V itself (wezterm.lua), else
; Alt+C -> Ctrl+C would be SIGINT, not copy. Alt+Tab / Alt+F4 stay native (not touched).
; Games: the Playnite global script (game-mode.ps1) KILLS this whole AHK process,
; so in-game everything is raw native input (anti-cheat safe).
#HotIf !WinActive("ahk_exe wezterm-gui.exe") and !WinActive("ahk_exe RustDesk.exe")
!c::^c
!x::^x
!v::^v
!a::^a
!z::^z   ; Cmd+Z = undo (AMD overlay hotkeys now off, so Alt+Z is free). Alt+Shift+Z -> Ctrl+Shift+Z = redo (free via the implicit *).
; The remaps above use an implicit * (they fire even with EXTRA modifiers held), which
; hijacks Alt+SHIFT+C/X/V/A — e.g. Zen's Alt+Shift+C = copy URL, Alt+Shift+A = addons.
; Pass the Shift variants straight through to the app (~ = don't suppress; more-specific
; than !c so it wins):
~!+c::return
~!+x::return
~!+v::return
~!+a::return
; ONLY the OS-level copy family lives in AHK — nothing can rebind Ctrl+C/X/V/A, so
; AHK is the only way to put them on Alt. Everything else (new tab, find, close,
; address bar, tabs, …) lives in each app's OWN dotfile-able config — e.g. Zen's
; zen-keyboard-shortcuts.json is Alt-ified. Doing them here too would DOUBLE-bind.
#HotIf

; ── Obsidian: PARITY WITH THE MAC keybinds (Alt sits where mac's Cmd is, so Alt+T here == Cmd+T
; on the Mac). Done HERE in AHK, NOT in hotkeys.json — that file iCloud-syncs to the Mac, so
; Alt-ifying it would break the Mac's native Cmd shortcuts. AHK is Windows-only -> Mac untouched.
; (Contrast: Zen was Alt-ified in its OWN config because Zen's config is NOT cloud-synced.)
; Program-specific via WinActive — live only while Obsidian is focused, auto-off when you leave.
; (Copy family Alt+C/X/V/A + Alt+Z undo are already handled by the global block above.)
#HotIf WinActive("ahk_exe Obsidian.exe")
!y::^y   ; quick-explorer: browse vault
!m::^m   ; file: move
!i::^i   ; templater: Zettel
!n::^n   ; new tab
!t::^t   ; daily note (your Mod+T)
#HotIf

; Zen: Win+click → Alt+click (split tab — parity with mac Cmd+click)
#HotIf WinActive("ahk_exe zen.exe")
#LButton::
{
    Send("{LWin up}{Alt down}")
    Click
    Send("{Alt up}")
}
#HotIf
