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
    Run('"C:\Users\senio\scoop\apps\sharex\current\ShareX.exe" -RectangleRegion')
}
