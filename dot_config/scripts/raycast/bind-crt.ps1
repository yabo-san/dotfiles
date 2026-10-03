# Raycast Script Command (Windows / PowerShell)
# "Bind CRT": after a display upset (adapter replug, GPU reset, primary flip) Windows renumbers
# the monitors and two things point at the old number: the yasb bar on the CRT and RetroArch's
# video_monitor_index. Each has its own script; both run at logon. This runs both now.
# Idempotent, prints what changed, touches no display setting.

# @raycast.schemaVersion 1
# @raycast.title Bind CRT
# @raycast.mode fullOutput
# @raycast.packageName Displays

# Optional:
# @raycast.icon 📺
# @raycast.description Point the yasb CRT bar and RetroArch at whichever monitor is the CRT now

$yasb = Join-Path $env:USERPROFILE '.config\scripts\yasb\fix-crt-bar.ps1'
$retro = Join-Path $env:USERPROFILE '.config\scripts\retroarch\bind-crt.ps1'
$rc = 0
foreach ($s in @($yasb, $retro)) {
    if (-not (Test-Path $s)) { Write-Host "bind-crt: $s not found (chezmoi apply?)"; $rc = 1; continue }
    & pwsh -NoProfile -File $s
    if ($LASTEXITCODE -ne 0) { $rc = $LASTEXITCODE }
}
exit $rc
