#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Classic Start Menu
# @raycast.mode silent
# @raycast.packageName Windows
# @raycast.icon 🪟
# @raycast.description Toggle the Open-Shell classic start menu

# Opens Open-Shell's classic menu WITHOUT a keypress — posts its registered IPC
# message to the taskbar (the mechanism Open-Shell uses internally; see
# StartMenuDLL.cpp). Bypasses the keyboard hook entirely, so it works from Raycast
# even though Open-Shell ignores injected keystrokes.
#   MSG_TOGGLE = 0 (open/close)  ·  MSG_OPEN = 2 (open only)
$sig = @"
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern uint RegisterWindowMessage(string lpString);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern System.IntPtr FindWindow(string c, string n);
[DllImport("user32.dll")] public static extern bool PostMessage(System.IntPtr hWnd, uint Msg, System.IntPtr wParam, System.IntPtr lParam);
"@
$t    = Add-Type -MemberDefinition $sig -Name OpenShellIPC -Namespace OS -PassThru
$msg  = $t::RegisterWindowMessage("OpenShellMenu.StartMenuMsg")
$tray = $t::FindWindow("Shell_TrayWnd", $null)
[void]$t::PostMessage($tray, $msg, [IntPtr]0, [IntPtr]0)  # MSG_TOGGLE
