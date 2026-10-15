# Raycast Script Command (Windows / PowerShell)
# After a display upset Windows renumbers monitors; reruns the yasb CRT bar and RetroArch monitor-index fixes.
# Idempotent, touches no display setting.

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
