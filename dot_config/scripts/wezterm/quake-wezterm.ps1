# quake-wezterm.ps1 — Guake-style dropdown for WezTerm.
# Follows the monitor UNDER THE CURSOR (mirrors mac ghostty quick-terminal-screen=cursor).
# Drops BELOW the YASB bar so it never covers it.
#
# Launched with `--class quake-term` (sets WINDOW CLASS, found by class via Win32).
#   bare `  -> toggle (AutoHotkey)      ctrl+`  -> literal backtick (AutoHotkey)
#
# FIXES (2026-06): (1) PER-MONITOR-DPI-AWARE thread so GetMonitorInfo/MoveWindow use real
# physical pixels on every monitor regardless of scaling (no mis-size on mixed-DPI/aspect).
# (2) Remembered height is keyed PER MONITOR — switching monitors no longer reuses another
# monitor's height (that was the "learn once / gets overwritten" race).

$ErrorActionPreference = 'SilentlyContinue'
$wezterm    = "$env:USERPROFILE\scoop\shims\wezterm-gui.exe"
$class      = "quake-term"
$heightFrac = 0.45    # drop covers ~45% of the monitor height
$yasbHeight = 34      # YASB bar is 32px tall at top; clear it + 2px

Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Q {
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool repaint);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern IntPtr MonitorFromPoint(POINT p, uint flags);
  [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr h, ref MONITORINFO mi);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr l);
  public delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int m);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll", SetLastError=true)] public static extern int GetWindowLong(IntPtr h, int idx);
  [DllImport("user32.dll", SetLastError=true)] public static extern int SetWindowLong(IntPtr h, int idx, int val);
  // make THIS thread per-monitor-DPI-aware v2 (runtime, overrides pwsh's system-aware manifest)
  [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
  public static void DpiAware() { SetThreadDpiAwarenessContext((IntPtr)(-4)); } // PER_MONITOR_AWARE_V2
  // hide a window from Alt-Tab: add WS_EX_TOOLWINDOW, remove WS_EX_APPWINDOW
  public static void HideFromAltTab(IntPtr h) {
    int GWL_EXSTYLE = -20, WS_EX_TOOLWINDOW = 0x80, WS_EX_APPWINDOW = 0x40000;
    int ex = GetWindowLong(h, GWL_EXSTYLE);
    ex = (ex | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW;
    SetWindowLong(h, GWL_EXSTYLE, ex);
  }
  public struct POINT { public int x, y; }
  public struct RECT { public int left, top, right, bottom; }
  public struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }

  // monitor bounds under the cursor
  public static int[] CursorMonitor() {
    POINT p; GetCursorPos(out p);
    IntPtr hMon = MonitorFromPoint(p, 2); // MONITOR_DEFAULTTONEAREST
    MONITORINFO mi = new MONITORINFO(); mi.cbSize = Marshal.SizeOf(mi);
    GetMonitorInfo(hMon, ref mi);
    return new int[] { mi.rcMonitor.left, mi.rcMonitor.top,
                       mi.rcMonitor.right - mi.rcMonitor.left,
                       mi.rcMonitor.bottom - mi.rcMonitor.top };
  }
  public static IntPtr FindByClass(string target) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h,l)=>{ var c=new StringBuilder(256); GetClassName(h,c,256);
      if (c.ToString()==target){ found=h; return false; } return true; }, IntPtr.Zero);
    return found;
  }
}
'@

# per-monitor-DPI-aware BEFORE any monitor/window math, so dimensions are real physical pixels
[Q]::DpiAware()

# remembered height PER MONITOR (keyed by geometry) — survives toggles + restarts
$stateFile = Join-Path $env:LOCALAPPDATA "quake-wezterm-heights.json"
function Read-Heights {
  if (Test-Path $stateFile) { try { return (Get-Content $stateFile -Raw -EA Stop | ConvertFrom-Json -AsHashtable) } catch {} }
  return @{}
}
function Save-Height($key, $h) {
  $d = Read-Heights; $d[$key] = $h
  ($d | ConvertTo-Json -Compress) | Set-Content -Path $stateFile -Force
}

# monitor under the cursor
$m  = [Q]::CursorMonitor()
$mx = $m[0]; $my = $m[1]; $mw = $m[2]; $mh = $m[3]
$monKey  = "$($mw)x$($mh)@$($mx),$($my)"             # this exact monitor
$qy = $my + $yasbHeight                              # below the YASB bar
$default = [int]($mh * $heightFrac) - $yasbHeight    # autosize height for THIS monitor

$h = [Q]::FindByClass($class)
if ($h -ne [IntPtr]::Zero) {
  $fg = [Q]::GetForegroundWindow()
  if ([Q]::IsWindowVisible($h) -and $fg -eq $h) {
    # HIDING — remember THIS monitor's current height (so a manual resize sticks, per-monitor)
    $r = New-Object Q+RECT
    if ([Q]::GetWindowRect($h, [ref]$r)) {
      $curH = $r.bottom - $r.top
      if ($curH -gt 100) { Save-Height $monKey $curH }
    }
    [Q]::ShowWindow($h, 0) | Out-Null                # SW_HIDE
  } else {
    # SHOWING — this monitor's saved height, else the autosize default
    $qh = (Read-Heights)[$monKey]; if (-not $qh) { $qh = $default }
    [Q]::HideFromAltTab($h)                            # keep it out of Alt-Tab
    [Q]::MoveWindow($h, $mx, $qy, $mw, $qh, $true) | Out-Null
    [Q]::ShowWindow($h, 5) | Out-Null
    [Q]::SetForegroundWindow($h) | Out-Null
  }
} else {
  Start-Process $wezterm -ArgumentList @("start","--class",$class)
  for ($i=0; $i -lt 20; $i++) { Start-Sleep -Milliseconds 150; $h = [Q]::FindByClass($class); if ($h -ne [IntPtr]::Zero) { break } }
  if ($h -ne [IntPtr]::Zero) {
    $qh = (Read-Heights)[$monKey]; if (-not $qh) { $qh = $default }
    [Q]::HideFromAltTab($h)                            # keep it out of Alt-Tab
    [Q]::MoveWindow($h, $mx, $qy, $mw, $qh, $true) | Out-Null
    [Q]::SetForegroundWindow($h) | Out-Null
  }
}
