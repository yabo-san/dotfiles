#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Classic Start Menu
# @raycast.mode silent
# @raycast.packageName Windows
# @raycast.icon 🪟
# @raycast.description Open the Open-Shell classic start menu, focused

# Opens Open-Shell's classic menu WITHOUT a keypress — posts its registered IPC
# message to the taskbar (the mechanism Open-Shell uses internally; see
# StartMenuDLL.cpp). Then FORCES the menu window to the foreground so:
#   - arrow keys + Enter work (menu has keyboard focus), and
#   - Esc / click-away close it (Open-Shell closes on WM_ACTIVATE/WA_INACTIVE,
#     which only fires if the menu was the active window).
# SetForegroundWindow alone is blocked by Windows' foreground lock, so we use the
# AttachThreadInput trick (attach to the current foreground thread first).
#   MSG_OPEN = 2 (open)  ·  MSG_TOGGLE = 0 (open/close)
$sig = @"
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern uint RegisterWindowMessage(string s);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern System.IntPtr FindWindow(string c, string n);
[DllImport("user32.dll")] public static extern bool PostMessage(System.IntPtr h, uint m, System.IntPtr w, System.IntPtr l);
[DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(System.IntPtr h, System.IntPtr pid);
[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(System.IntPtr h);
[DllImport("user32.dll")] public static extern bool SetActiveWindow(System.IntPtr h);
"@
$t    = Add-Type -MemberDefinition $sig -Name OpenShellIPC -Namespace OS -PassThru
$msg  = $t::RegisterWindowMessage("OpenShellMenu.StartMenuMsg")
$tray = $t::FindWindow("Shell_TrayWnd", $null)
[void]$t::PostMessage($tray, $msg, [IntPtr]2, [IntPtr]0)  # MSG_OPEN

# wait for the menu window, then force-focus it
$menu = [IntPtr]::Zero
for ($i = 0; $i -lt 25 -and $menu -eq [IntPtr]::Zero; $i++) {
    Start-Sleep -Milliseconds 20
    $menu = $t::FindWindow("OpenShell.CMenuContainer", $null)
}
if ($menu -ne [IntPtr]::Zero) {
    $fg  = $t::GetForegroundWindow()
    $fgT = $t::GetWindowThreadProcessId($fg, [IntPtr]::Zero)
    $me  = $t::GetCurrentThreadId()
    [void]$t::AttachThreadInput($me, $fgT, $true)
    [void]$t::SetForegroundWindow($menu)
    [void]$t::SetActiveWindow($menu)
    [void]$t::AttachThreadInput($me, $fgT, $false)
}
