# Raycast Script Command (Windows / PowerShell)
# Throw the FOCUSED window into its own empty workspace and fullscreen it over
# the bar. Point at a game, hit this, done — then Borderless Gaming (or the
# borderless strip) removes the chrome and it just works.
#
# This is the MANUAL driver. The Playnite tag pipeline does the same thing
# automatically for tagged games, but it only fires on a Playnite launch and
# depends on Playnite reporting a usable process id — which it does not for
# Steam titles (it hands back the vcredist prerequisite). This works on anything
# already on screen, however it got there.
#
# Why 'set-fullscreen --maximized=false' rather than toggle-fullscreen:
#   * maximized=true (the DEFAULT) calls Win32 maximize, which silently does
#     nothing on windows lacking WS_MAXIMIZEBOX — i.e. most games.
#   * maximized=false does a SetWindowPos to the monitor's FULL bounds, which
#     includes the strip under the bar. That is what makes the window draw OVER
#     yasb instead of stopping below it.

# @raycast.schemaVersion 1
# @raycast.title Window Solo
# @raycast.mode fullOutput
# @raycast.packageName GlazeWM

# Optional:
# @raycast.icon 🖥️
# @raycast.description Focused window -> own workspace, fullscreen over the bar

$ErrorActionPreference = 'Stop'

# Workspaces to hand out, in order. These are the overflow ones in the GlazeWM
# config that nothing else homes to.
$Candidates = @('8', '9', '10')

function Glaze($argline) { & glazewm @argline | ConvertFrom-Json }

$windows = (Glaze @('query','windows')).data.windows
$focused = $windows | Where-Object { $_.hasFocus } | Select-Object -First 1

if (-not $focused) {
    Write-Host "Nothing is focused — click the window you want, then re-run." -ForegroundColor Yellow
    exit 1
}

Write-Host "Focused: $($focused.processName)  '$($focused.title)'" -ForegroundColor Cyan

# Which workspaces already hold windows? Take the first candidate that is free,
# so repeated use doesn't pile two games onto one workspace.
$occupied = @{}
foreach ($m in (Glaze @('query','monitors')).data.monitors) {
    foreach ($ws in $m.children) {
        if ($ws.children.Count -gt 0) { $occupied[$ws.name] = $true }
    }
}
$target = $Candidates | Where-Object { -not $occupied.ContainsKey($_) } | Select-Object -First 1
if (-not $target) { $target = $Candidates[0] }   # all busy: reuse the first

Write-Host "  -> workspace $target, fullscreen over the bar"

& glazewm command --id $focused.id move --workspace $target | Out-Null
Start-Sleep -Milliseconds 250
& glazewm command --id $focused.id set-fullscreen --maximized=false | Out-Null
Start-Sleep -Milliseconds 250
& glazewm command focus --workspace $target | Out-Null

Write-Host ""
Write-Host "Done. Move it between monitors with lwin+shift+h/j/k/l." -ForegroundColor DarkGray
Write-Host "If the window won't move, GlazeWM isn't managing it — alt-tab away" -ForegroundColor DarkGray
Write-Host "and back to make it re-register, then re-run." -ForegroundColor DarkGray
