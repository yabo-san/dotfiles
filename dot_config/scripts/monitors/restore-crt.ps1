# restore-crt.ps1
# Put a workspace back on the CRT — for when you actually want to use it.
# Defaults to workspace 3 (music), which is the usual CRT tenant.
#
# REWRITTEN 2026-07-31 alongside evict-crt.ps1; see the note there for why the
# previous `move-workspace --workspace N --monitor \\.\DISPLAY3` form never
# worked. Target is the FRIENDLY NAME 'crt' from ~/.config/monitors.json.

param(
    [string] $Workspace = '3'
)

$py = @(
    "$env:USERPROFILE\scoop\apps\python\current\python.exe",
    "$env:USERPROFILE\scoop\shims\python3.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $py) {
    Write-Host "python not found (scoop install python)" -ForegroundColor Red
    exit 1
}

$worker = Join-Path $env:USERPROFILE '.config\scripts\playnite\place_game_window.py'
& $py $worker --mode home --workspace $Workspace --target 'crt'

glazewm.exe command "focus --workspace $Workspace"
