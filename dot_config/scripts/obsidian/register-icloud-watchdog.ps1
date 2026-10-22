#requires -Version 5.1
# Registers the "iCloud watchdog" scheduled task: icloud-watchdog.ps1 every hour and 5 minutes after logon.
# Per-user, no admin. Safe to rerun (replaces the task).
$script  = Join-Path $env:USERPROFILE '.config\scripts\obsidian\icloud-watchdog.ps1'
$pwsh    = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell).Source }

$action  = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
$every   = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddHours(1) -RepetitionInterval (New-TimeSpan -Hours 1)
$logon   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$logon.Delay = 'PT5M'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName 'iCloud watchdog' -Action $action -Trigger $every, $logon -Settings $settings `
    -Description 'Restarts iCloud for Windows when idle; it silently stops pulling changes (2026-10-21).' -Force | Out-Null
Get-ScheduledTask -TaskName 'iCloud watchdog' | Select-Object TaskName, State
