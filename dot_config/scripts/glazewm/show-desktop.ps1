#requires -Version 7
# show-desktop.ps1: Win+D for every screen, with a second press that brings everything back.
# Windows' own Win+D toggle breaks under GlazeWM: minimizing makes GlazeWM move focus, and Windows then
# forgets it was in show-desktop mode. So this remembers exactly which windows it minimized.
$ErrorActionPreference = 'SilentlyContinue'
Add-Type @'
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public static class SD {
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint c);
  [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
  [DllImport("user32.dll")] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int a, out int v, int s);
  static readonly string[] SkipClass = { "Shell_TrayWnd", "Shell_SecondaryTrayWnd", "Progman", "WorkerW" };
  // windows actually on screen right now: visible, not cloaked (other workspace), not minimized, titled, unowned
  public static List<long> OnScreen(uint[] skipPids) {
    var r = new List<long>();
    EnumWindows((h, l) => {
      if (!IsWindowVisible(h) || IsIconic(h) || GetWindow(h, 4) != IntPtr.Zero || GetWindowTextLength(h) == 0) return true;
      int cloaked; DwmGetWindowAttribute(h, 14, out cloaked, 4); if (cloaked != 0) return true;
      var c = new StringBuilder(256); GetClassName(h, c, 256); if (Array.IndexOf(SkipClass, c.ToString()) >= 0) return true;
      uint pid; GetWindowThreadProcessId(h, out pid); if (Array.IndexOf(skipPids, pid) >= 0) return true;
      r.Add(h.ToInt64()); return true;
    }, IntPtr.Zero);
    return r;
  }
}
'@
$state = Join-Path $env:LOCALAPPDATA 'show-desktop.json'
$saved = @(); if (Test-Path $state) { $saved = @(Get-Content $state -Raw | ConvertFrom-Json) }
$stillDown = @($saved | Where-Object { [SD]::IsWindow([IntPtr][long]$_) -and [SD]::IsIconic([IntPtr][long]$_) })

if ($stillDown.Count -gt 0) {
  # second press: bring back what we minimized, in reverse so the top window ends on top
  [array]::Reverse($stillDown)
  foreach ($h in $stillDown) { [SD]::ShowWindow([IntPtr][long]$h, 9) | Out-Null }   # SW_RESTORE
  Remove-Item $state -Force
} else {
  # first press: minimize everything on screen except the bar
  $skip = [uint32[]]@(Get-Process yasb, glazewm -ErrorAction SilentlyContinue | ForEach-Object { [uint32]$_.Id })
  $list = [SD]::OnScreen($skip)
  ($list | ConvertTo-Json -Compress -AsArray) | Set-Content $state -Force
  foreach ($h in $list) { [SD]::ShowWindow([IntPtr]$h, 6) | Out-Null }              # SW_MINIMIZE
}
