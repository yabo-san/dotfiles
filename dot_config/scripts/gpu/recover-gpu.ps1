<#
.SYNOPSIS
  Bring the RX 7900 GRE back after a GPU hang left it disabled.

.DESCRIPTION
  After a hard freeze this PC has come back with the discrete GPU in Device
  Manager as CM_PROB_DISABLED. The LG and the Acer hang off that card, so both
  stay dark and only the CRT (motherboard graphics) lights up. Re-enabling it is
  not enough on its own: the driver then sits at CM_PROB_FAILED_ADD until the
  device is restarted. This does both, only when needed (INC0044922).

  Runs as SYSTEM from a startup scheduled task, before anyone logs on, so the
  logon scripts that bind the CRT (fix-crt-bar.ps1, retroarch/bind-crt.ps1) see
  all three monitors and pick the right numbers. A no-op on a healthy boot.

  Log: C:\ProgramData\recover-gpu\recover-gpu.log
#>
[CmdletBinding()]
param(
    [string]$Match = 'DEV_744C',   # RX 7900 GRE; change if the card is ever replaced
    [switch]$WhatIfOnly
)

$ErrorActionPreference = 'Stop'
$logDir = Join-Path $env:ProgramData 'recover-gpu'
New-Item -ItemType Directory -Force $logDir | Out-Null
$log = Join-Path $logDir 'recover-gpu.log'
function Log([string]$m) { $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m; Add-Content $log $line; Write-Host $line }

$gpu = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | Where-Object InstanceId -match $Match | Select-Object -First 1
if (-not $gpu) { Log "no display device matching $Match - nothing to do"; exit 0 }

$state = "$($gpu.Status) / $($gpu.Problem)"
if ($gpu.Status -eq 'OK') { Log "GPU healthy ($state)"; exit 0 }

Log "GPU not healthy: $state"
if ($WhatIfOnly) { Log 'would enable and restart it'; exit 0 }

if ($gpu.Problem -eq 'CM_PROB_DISABLED') {
    Enable-PnpDevice -InstanceId $gpu.InstanceId -Confirm:$false
    Start-Sleep 3
    Log "enabled; now $((Get-PnpDevice -InstanceId $gpu.InstanceId).Problem)"
}

& pnputil.exe /restart-device "$($gpu.InstanceId)" | Out-Null
Start-Sleep 8
$after = Get-PnpDevice -InstanceId $gpu.InstanceId
Log "after restart: $($after.Status) / $($after.Problem)"
if ($after.Status -ne 'OK') { exit 1 }
