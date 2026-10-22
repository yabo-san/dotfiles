#requires -Version 5.1
# Restarts iCloud for Windows when it is idle, because it silently stops pulling changes from other devices.
# 2026-10-21: notes written on the Mac 10-19 and 10-20 never arrived here; the client looked healthy (processes up,
# Responding) and logged nothing. Killing and relaunching it brought the whole backlog down within a minute.
# Windows cannot see what the server holds, so a stall cannot be detected from here; restart on a timer instead.
# Never mid-transfer: skip the restart if anything in the vault's iCloud folder changed in the last few minutes.
#
# Registered by register-icloud-watchdog.ps1 (scheduled task "iCloud watchdog", every hour and at logon).
$ErrorActionPreference = 'Stop'

$icloudVault = 'D:\iCloudDrive\iCloud~md~obsidian\sb'
$appId       = 'AppleInc.iCloud_nzyj5cx40ttqa!iCloud'   # Store app: the exe cannot be started by path (access denied)
$quietMins   = 3
$log         = 'D:\obsidian\logs\icloud-watchdog.log'

function Note($msg) {
    try { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" | Add-Content -LiteralPath $log -Encoding utf8 } catch { }
}

$busy = Get-ChildItem -LiteralPath $icloudVault -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-$quietMins) } | Select-Object -First 1
if ($busy) { Note "skip: $($busy.Name) changed in the last $quietMins min"; exit 0 }

Get-Process iCloudDrive, iCloudHome, iCloudCKKS -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Start-Process "shell:AppsFolder\$appId"
Start-Sleep -Seconds 20

if (Get-Process iCloudDrive -ErrorAction SilentlyContinue) { Note 'restarted iCloud' }
else { Note 'FAILED: iCloudDrive did not come back after relaunch' }
