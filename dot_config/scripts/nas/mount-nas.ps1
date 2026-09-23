<#
.SYNOPSIS
  At logon, wait for Tailscale, then make sure N: (the thinkserver NAS) is mounted.

.DESCRIPTION
  Windows reconnects mapped drives at logon BEFORE Tailscale is up, so the first
  attempt fails and N: sits at "Unavailable" until something touches it. This runs
  from a Startup shortcut (Windows PowerShell 5.1, so keep this file plain ASCII),
  waits until the NAS answers on the SMB port, then remaps N: if it is not readable.
  The password comes from Windows Credential Manager, stored once with:
      cmdkey /add:100.99.35.21 /user:yabo /pass
  Idempotent: exits quietly when N: already works. Log: %LOCALAPPDATA%\mount-nas.log
#>
[CmdletBinding()]
param(
    [string]$Server = '100.99.35.21',
    [string]$Share  = 'NAS',
    [string]$Drive  = 'N:',
    [int]$TimeoutSeconds = 180
)

$log = Join-Path $env:LOCALAPPDATA 'mount-nas.log'
function Log($m) { "{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $m | Add-Content -Path $log }

function Test-Smb {
    $c = New-Object System.Net.Sockets.TcpClient
    try { return $c.ConnectAsync($Server, 445).Wait(2000) -and $c.Connected } catch { return $false } finally { $c.Close() }
}

if (Test-Path "$Drive\") { Log "$Drive already readable, nothing to do."; exit 0 }

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while (-not (Test-Smb)) {
    if ((Get-Date) -gt $deadline) { Log "gave up: $Server did not answer on 445 within $TimeoutSeconds s (Tailscale down?)"; exit 1 }
    Start-Sleep -Seconds 5
}

& net use $Drive /delete /y 2>$null | Out-Null
$unc = '\\' + $Server + '\' + $Share
$out = & net use $Drive $unc /persistent:yes 2>&1
if (Test-Path "$Drive\") { Log "mounted $Drive -> $unc" ; exit 0 }
Log "net use failed: $out"
exit 1
