; hotkeys.ahk: every AutoHotkey binding on this machine, AutoHotkey v2.
; One process on purpose: AHK Off / AHK On (Raycast) and Playnite's pre/post-game scripts stop and start
; exactly this file. Keys here must never also be bound in GlazeWM: AHK sees keys first and would win.
;
;   `            WezTerm drop-down (top of the screen under the mouse)
;   Ctrl+`       type a literal backtick
;   Win+S        Cider drop-down (centred)
;   Win+D        show desktop on every screen; again to bring back exactly what it hid
;   Alt+C/X/V/A/Z  Mac-style copy/cut/paste/select-all/undo (not in WezTerm or RustDesk)
;   Obsidian Alt keys, Zen Win+click
; Win+Shift+S is deliberately NOT bound: it is the snip, and AHK would swallow it before Windows.

#Requires AutoHotkey v2.0
#SingleInstance Force

; Physical pixels on every monitor, so mixed scaling (ultrawide, Acer, CRT) never mis-sizes a drop-down.
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

global BAR_HEIGHT := 34                                         ; yasb bar; drop-downs open below it
global SIZES_FILE := EnvGet("LOCALAPPDATA") "\dropdown\sizes.ini"
DirCreate(EnvGet("LOCALAPPDATA") "\dropdown")

; ── Drop-downs ──────────────────────────────────────────────────────────────────────────────────
; Done in-process: the old PowerShell versions took 850 to 1,100 ms a press (PowerShell start-up
; plus compiling their helper code every time). These take a few milliseconds.
; The app must be ignored by GlazeWM, or GlazeWM pulls it back into a tile.

vkC0::Dropdown("terminal", "wezterm-gui.exe", "quake-term"
    , '"' EnvGet("USERPROFILE") '\scoop\shims\wezterm-gui.exe" start --class quake-term', "top")

^vkC0::SendText("``")                                           ; Ctrl+` types a real backtick

#s::Dropdown("cider", "Cider.exe", "HwndWrapper[Cider"
    , "shell:AppsFolder\27554FireDevElijahKlauman.CiderEA_270bejk4xgzqp!App", "center")

Dropdown(name, exe, classPrefix, launch, layout) {
    static prevFocus := Map()
    DetectHiddenWindows true
    hwnd := DropdownFind(exe, classPrefix)

    ; geometry for the monitor under the mouse
    CoordMode "Mouse", "Screen"
    MouseGetPos &mx, &my
    l := 0, t := 0, r := A_ScreenWidth, b := A_ScreenHeight
    Loop MonitorGetCount() {
        MonitorGet A_Index, &ml, &mt, &mr, &mb
        if (mx >= ml && mx < mr && my >= mt && my < mb) {
            l := ml, t := mt, r := mr, b := mb
            break
        }
    }
    mw := r - l, mh := b - t, monKey := mw "x" mh "@" l "," t
    saved := IniRead(SIZES_FILE, name, monKey, "")
    if (layout = "top") {
        w := mw, x := l, y := t + BAR_HEIGHT
        h := saved != "" ? Integer(saved) : Round(mh * 0.45) - BAR_HEIGHT
    } else {
        sw := 0, sh := 0
        if (saved != "") {
            parts := StrSplit(saved, ",")
            sw := Integer(parts[1]), sh := Integer(parts[2])
        }
        w := sw ? sw : Min(1600, Round(mw * 0.5))
        h := sh ? sh : Round((mh - BAR_HEIGHT) * 0.7)
        x := l + (mw - w) // 2, y := t + BAR_HEIGHT + 8
    }

    fg := WinExist("A")
    if !hwnd {
        Run launch
        Loop 40 {                                               ; up to 10 s for a cold start
            Sleep 250
            if hwnd := DropdownFind(exe, classPrefix)
                break
        }
        if !hwnd
            return
        Sleep 400                                               ; let it finish its own first layout
        shown := false
    } else {
        shown := DllCall("IsWindowVisible", "ptr", hwnd) && WinGetMinMax(hwnd) != -1 && fg = hwnd
    }

    if shown {
        ; HIDE: remember a size you chose (never one near full screen), then hand focus back
        WinGetPos , , &cw, &ch, hwnd
        if (layout = "top" && ch > 100 && ch < mh * 0.9)
            IniWrite ch, SIZES_FILE, name, monKey
        else if (layout != "top" && cw > 300 && ch > 200 && cw < mw * 0.9 && ch < mh * 0.9)
            IniWrite cw "," ch, SIZES_FILE, name, monKey
        WinHide hwnd
        if prevFocus.Has(name) && WinExist(prevFocus[name])
            WinActivate prevFocus[name]
    } else {
        ; SHOW: remember who had focus, keep it out of Alt+Tab and the taskbar, drop it down
        if (fg && fg != hwnd)
            prevFocus[name] := fg
        WinSetExStyle "+0x80", hwnd                             ; WS_EX_TOOLWINDOW
        WinSetExStyle "-0x40000", hwnd                          ; not WS_EX_APPWINDOW
        if WinGetMinMax(hwnd) = -1
            WinRestore hwnd
        WinMove x, y, w, h, hwnd
        WinShow hwnd
        WinActivate hwnd
        ; crossing to a monitor with different scaling makes the app resize itself after our move
        Loop 5 {
            Sleep 25
            if WinExist(hwnd)
                WinMove x, y, w, h, hwnd
        }
    }
}

; Largest unowned top-level window of exe whose class starts with classPrefix. Hidden windows count:
; a hidden window has no main handle, which is what broke June's Proton Mail attempt.
DropdownFind(exe, classPrefix) {
    DetectHiddenWindows true
    best := 0, bestArea := 0
    for hwnd in WinGetList("ahk_exe " exe) {
        if SubStr(WinGetClass(hwnd), 1, StrLen(classPrefix)) != classPrefix
            continue
        if DllCall("GetWindow", "ptr", hwnd, "uint", 4, "ptr")  ; GW_OWNER: skip owned popups
            continue
        WinGetPos , , &w, &h, hwnd
        if (w * h > bestArea)
            best := hwnd, bestArea := w * h
    }
    return bestArea >= 200 * 200 ? best : 0
}

; ── Win+D: show desktop on every screen ─────────────────────────────────────────────────────────
; Windows' own Win+D cannot toggle back under GlazeWM (minimizing makes GlazeWM move focus, and
; Windows forgets it was in show-desktop mode). This minimizes what is on screen and remembers it.
; While a game runs AHK is off and Win+D is Windows' again.
#d::ShowDesktop()

ShowDesktop() {
    static minimized := []
    stillDown := []
    for h in minimized
        if WinExist(h) && WinGetMinMax(h) = -1
            stillDown.Push(h)
    if stillDown.Length {
        Loop stillDown.Length                                   ; reverse, so the top window ends on top
            WinRestore stillDown[stillDown.Length - A_Index + 1]
        minimized := []
        return
    }
    minimized := []
    for h in WinGetList() {                                     ; hidden windows excluded by default
        if WinGetMinMax(h) = -1 || WinGetTitle(h) = ""
            continue
        if WinGetClass(h) ~= "^(Shell_TrayWnd|Shell_SecondaryTrayWnd|Progman|WorkerW)$"
            continue
        if DllCall("GetWindow", "ptr", h, "uint", 4, "ptr")
            continue
        cloaked := 0                                            ; cloaked = on another GlazeWM workspace
        DllCall("dwmapi\DwmGetWindowAttribute", "ptr", h, "uint", 14, "int*", &cloaked, "uint", 4)
        if cloaked
            continue
        try exe := WinGetProcessName(h)
        catch
            continue
        if (exe = "yasb.exe" || exe = "glazewm.exe")
            continue
        minimized.Push(h)
    }
    for h in minimized
        WinMinimize h
}

; ── Mac-style copy/cut/paste on Alt ─────────────────────────────────────────────────────────────
; ALT sits where the Mac's Cmd is. Scoped out of WezTerm (it binds Alt+C/V itself; Alt+C -> Ctrl+C
; would be SIGINT) and RustDesk (the remote machine needs the real keys). Alt+Tab and Alt+F4 untouched.
#HotIf !WinActive("ahk_exe wezterm-gui.exe") and !WinActive("ahk_exe RustDesk.exe")
!c::^c
!x::^x
!v::^v
!a::^a
!z::^z   ; Alt+Shift+Z -> Ctrl+Shift+Z = redo, via the implicit *
; The remaps above fire with extra modifiers too, which would hijack Alt+Shift+C/X/V/A (Zen's
; copy-URL, addons). Pass the Shift variants straight through (~ = don't suppress):
~!+c::return
~!+x::return
~!+v::return
~!+a::return
; Only the OS copy family lives here; everything else is in each app's own config, so nothing is
; bound twice (Zen's zen-keyboard-shortcuts.json is Alt-ified).
#HotIf

; ── Obsidian: Mac parity (Alt = Cmd) ────────────────────────────────────────────────────────────
; Here and not in Obsidian's hotkeys.json, which iCloud-syncs to the Mac and would break Cmd there.
#HotIf WinActive("ahk_exe Obsidian.exe")
!y::^y   ; quick-explorer: browse vault
!m::^m   ; file: move
!i::^i   ; templater: Zettel
!n::^n   ; new tab
!t::^t   ; daily note
#HotIf

; ── Zen: Win+click -> Alt+click (split tab, Mac Cmd+click parity) ───────────────────────────────
#HotIf WinActive("ahk_exe zen.exe")
#LButton::
{
    Send("{LWin up}{Alt down}")
    Click
    Send("{Alt up}")
}
#HotIf
