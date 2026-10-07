#requires -Version 7
# dropdown.ps1: toggle an app as a drop-down over the screen under the mouse.
# First press shows it centred below the yasb bar and focuses it; next press hides it and hands focus back.
# Launches the app if it is not running. Size is remembered per monitor when you resize it.
#
# The app must be IGNORED by GlazeWM (not in any window rule), or GlazeWM pulls it back into a tile.
# A hidden window has no MainWindowHandle, so the window is found by walking every top-level window of
# the process (lesson from the June Proton Mail attempt, which could hide but never re-show).
#
#   pwsh dropdown.ps1 -Name cider -Process Cider -ClassPrefix 'HwndWrapper[Cider' `
#        -Launch 'shell:AppsFolder\27554FireDevElijahKlauman.CiderEA_270bejk4xgzqp!App'
param(
  [Parameter(Mandatory)] [string] $Name,
  [Parameter(Mandatory)] [string] $Process,
  [string] $ClassPrefix = '',
  [Parameter(Mandatory)] [string] $Launch,
  [double] $WidthFrac  = 0.5,
  [double] $HeightFrac = 0.7,
  [int]    $MaxWidth   = 1600,
  [int]    $BarHeight  = 34
)
$ErrorActionPreference = 'SilentlyContinue'

Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices;
public class DD {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool repaint);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern IntPtr MonitorFromPoint(POINT p, uint flags);
  [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr h, ref MONITORINFO mi);
  [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
  public struct POINT { public int x, y; }
  public struct RECT { public int left, top, right, bottom; }
  public struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }
  public static void HideFromAltTab(IntPtr h) { int ex = GetWindowLong(h, -20); SetWindowLong(h, -20, (ex | 0x80) & ~0x40000); }
  public static int[] CursorMonitor() {
    POINT p; GetCursorPos(out p); IntPtr m = MonitorFromPoint(p, 2);
    MONITORINFO mi = new MONITORINFO(); mi.cbSize = Marshal.SizeOf(mi); GetMonitorInfo(m, ref mi);
    return new int[] { mi.rcMonitor.left, mi.rcMonitor.top, mi.rcMonitor.right - mi.rcMonitor.left, mi.rcMonitor.bottom - mi.rcMonitor.top };
  }
  // largest unowned top-level window of these PIDs whose class starts with prefix (hidden ones included)
  public static IntPtr Find(uint[] pids, string prefix) {
    IntPtr best = IntPtr.Zero; long bestArea = 0;
    EnumWindows((h, l) => {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (Array.IndexOf(pids, pid) < 0 || GetWindow(h, 4) != IntPtr.Zero) return true;
      var c = new StringBuilder(256); GetClassName(h, c, 256);
      if (prefix.Length > 0 && !c.ToString().StartsWith(prefix)) return true;
      RECT r; GetWindowRect(h, out r); long a = (long)(r.right - r.left) * (r.bottom - r.top);
      if (a > bestArea) { bestArea = a; best = h; }
      return true;
    }, IntPtr.Zero);
    return bestArea >= 200 * 200 ? best : IntPtr.Zero;
  }
}
'@
[DD]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null   # per-monitor DPI aware v2

$stateDir  = Join-Path $env:LOCALAPPDATA 'dropdown'
$null = New-Item -ItemType Directory -Force $stateDir
$sizeFile  = Join-Path $stateDir "$Name-sizes.json"
$prevFile  = Join-Path $stateDir "$Name-prev.txt"

function Find-Window {
  $pids = [uint32[]]@(Get-Process -Name $Process -ErrorAction SilentlyContinue | ForEach-Object { [uint32]$_.Id })
  if (-not $pids) { return [IntPtr]::Zero }
  [DD]::Find($pids, $ClassPrefix)
}
function Read-Sizes { if (Test-Path $sizeFile) { try { return (Get-Content $sizeFile -Raw | ConvertFrom-Json -AsHashtable) } catch {} }; @{} }

$m = [DD]::CursorMonitor(); $mx, $my, $mw, $mh = $m
$monKey = "$($mw)x$($mh)@$($mx),$($my)"
$sizes = Read-Sizes
$w = if ($sizes[$monKey]) { $sizes[$monKey][0] } else { [Math]::Min($MaxWidth, [int]($mw * $WidthFrac)) }
$h = if ($sizes[$monKey]) { $sizes[$monKey][1] } else { [int](($mh - $BarHeight) * $HeightFrac) }
$x = $mx + [int](($mw - $w) / 2)
$y = $my + $BarHeight + 8

$win = Find-Window
if ($win -eq [IntPtr]::Zero) {
  Start-Process $Launch
  for ($i = 0; $i -lt 40 -and $win -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 250; $win = Find-Window }
  if ($win -eq [IntPtr]::Zero) { exit 1 }
  Start-Sleep -Milliseconds 400   # let it finish laying itself out before we move it
  $fg = [DD]::GetForegroundWindow(); $isShown = $false
} else {
  $fg = [DD]::GetForegroundWindow()
  $isShown = [DD]::IsWindowVisible($win) -and -not [DD]::IsIconic($win) -and $fg -eq $win
}

if ($isShown) {
  # HIDE: remember this monitor's size if it was resized, then give focus back
  $r = New-Object DD+RECT
  if ([DD]::GetWindowRect($win, [ref]$r)) {
    $cw = $r.right - $r.left; $ch = $r.bottom - $r.top
    # only remember a size you chose: an app that reopened at its own full-screen size is not a choice
    if ($cw -gt 300 -and $ch -gt 200 -and $cw -lt 0.9 * $mw -and $ch -lt 0.9 * $mh) {
      $sizes[$monKey] = @($cw, $ch); ($sizes | ConvertTo-Json -Compress) | Set-Content $sizeFile -Force
    }
  }
  [DD]::ShowWindow($win, 0) | Out-Null                       # SW_HIDE
  try {
    $prev = [IntPtr][int64](Get-Content $prevFile -Raw).Trim()
    if ($prev -ne [IntPtr]::Zero -and $prev -ne $win -and [DD]::IsWindow($prev)) { [DD]::SetForegroundWindow($prev) | Out-Null }
  } catch {}
} else {
  # SHOW: remember who had focus, then drop it down on the screen under the mouse
  if ($fg -ne [IntPtr]::Zero -and $fg -ne $win) { "$([int64]$fg)" | Set-Content $prevFile -Force }
  [DD]::HideFromAltTab($win)
  if ([DD]::IsIconic($win)) { [DD]::ShowWindow($win, 9) | Out-Null }   # SW_RESTORE
  [DD]::MoveWindow($win, $x, $y, $w, $h, $true) | Out-Null
  [DD]::ShowWindow($win, 5) | Out-Null                       # SW_SHOW
  [DD]::SetForegroundWindow($win) | Out-Null
  # crossing to a different-DPI monitor makes the app resize itself after our move; re-apply briefly
  for ($k = 0; $k -lt 5; $k++) { Start-Sleep -Milliseconds 30; [DD]::MoveWindow($win, $x, $y, $w, $h, $true) | Out-Null }
}
