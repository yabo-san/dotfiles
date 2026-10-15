#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Classic Start Menu
# @raycast.mode silent
# @raycast.packageName Windows
# @raycast.icon 🪟
# @raycast.description Open the Open-Shell classic start menu, focused

# Posts Open-Shell's registered IPC message to the taskbar (see StartMenuDLL.cpp), then forces the menu to the
# foreground so keys work and Esc/click-away close it. AttachThreadInput gets past Windows' foreground lock.
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
