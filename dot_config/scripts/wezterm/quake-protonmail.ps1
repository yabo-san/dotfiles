# quake-protonmail.ps1 — sideways Guake for Proton Mail: slides out the LEFT edge.
# Win+W toggles it (via AHK). Found by PROCESS (Electron's class isn't unique).
# Mirrors quake-wezterm.ps1 but anchored left, ~35% wide, full height under the YASB bar.
$ErrorActionPreference = 'SilentlyContinue'
$procName  = 'Proton Mail'
$launch    = "$env:LOCALAPPDATA\proton_mail\Proton Mail.exe"   # portable: survives the yabo reset
$widthFrac = 0.35
$yasbHeight = 34

Add-Type @'
using System; using System.Runtime.InteropServices;
public class PQ {
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h,int x,int y,int w,int ht,bool r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern IntPtr MonitorFromPoint(POINT p,uint f);
  [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr h,ref MONITORINFO mi);
  [DllImport("user32.dll",SetLastError=true)] public static extern int GetWindowLong(IntPtr h,int i);
  [DllImport("user32.dll",SetLastError=true)] public static extern int SetWindowLong(IntPtr h,int i,int v);
  public static void HideFromAltTab(IntPtr h){int GWL=-20,TOOL=0x80,APP=0x40000;int ex=GetWindowLong(h,GWL);SetWindowLong(h,GWL,(ex|TOOL)&~APP);}
  public struct POINT{public int x,y;}
  public struct RECT{public int left,top,right,bottom;}
  public struct MONITORINFO{public int cbSize;public RECT rcMonitor;public RECT rcWork;public uint dwFlags;}
  public static int[] CursorMonitor(){POINT p;GetCursorPos(out p);IntPtr m=MonitorFromPoint(p,2);MONITORINFO mi=new MONITORINFO();mi.cbSize=Marshal.SizeOf(mi);GetMonitorInfo(m,ref mi);return new int[]{mi.rcMonitor.left,mi.rcMonitor.top,mi.rcMonitor.right-mi.rcMonitor.left,mi.rcMonitor.bottom-mi.rcMonitor.top};}
}
'@

function Get-PMHandle { (Get-Process -Name $procName -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1).MainWindowHandle }

$m=[PQ]::CursorMonitor(); $mx=$m[0]; $my=$m[1]; $mw=$m[2]; $mh=$m[3]
$qx=$mx; $qy=$my+$yasbHeight; $qw=[int]($mw*$widthFrac); $qh=$mh-$yasbHeight

$h = Get-PMHandle
if ($h) {
  $fg=[PQ]::GetForegroundWindow()
  if ([PQ]::IsWindowVisible($h) -and $fg -eq $h) {
    [PQ]::ShowWindow($h,0) | Out-Null                                   # hide
  } else {
    [PQ]::HideFromAltTab($h)
    [PQ]::MoveWindow($h,$qx,$qy,$qw,$qh,$true) | Out-Null               # left edge
    [PQ]::ShowWindow($h,5) | Out-Null
    [PQ]::SetForegroundWindow($h) | Out-Null
  }
} else {
  if (Test-Path $launch) { Start-Process $launch }
  for ($i=0;$i -lt 25;$i++){ Start-Sleep -Milliseconds 200; $h=Get-PMHandle; if ($h){break} }
  if ($h) { [PQ]::HideFromAltTab($h); [PQ]::MoveWindow($h,$qx,$qy,$qw,$qh,$true)|Out-Null; [PQ]::SetForegroundWindow($h)|Out-Null }
}
