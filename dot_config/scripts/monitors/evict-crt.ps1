# evict-crt.ps1
# Clear every GlazeWM workspace off the CRT, leaving the display active in
# Windows but empty — for when a game is going to take that screen, or you just
# want it out of the rotation.
#
# REWRITTEN 2026-07-31. The old version could never have worked against GlazeWM
# 3.x: it hardcoded \\.\DISPLAY3 / \\.\DISPLAY1 (the GDI names have since drifted
# to DISPLAY7/8/9 anyway) and called `move-workspace --workspace N --monitor X`.
# MoveWorkspace only accepts --direction — there is no --monitor and no
# --workspace flag — so every call was silently rejected.
#
# The real work lives in place_game_window.py so the game path and the manual
# path share one implementation. Target is given as a RESOLUTION because the CRT
# has no EDID and reports the useless hardwareId 'Default_Monitor'.

$py = @(
    "$env:USERPROFILE\scoop\apps\python\current\python.exe",
    "$env:USERPROFILE\scoop\shims\python3.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $py) {
    Write-Host "python not found (scoop install python)" -ForegroundColor Red
    exit 1
}

$worker = Join-Path $env:USERPROFILE '.config\scripts\playnite\place_game_window.py'
& $py $worker --mode evacuate --target '1024x768'

glazewm.exe command "focus --workspace 1"
