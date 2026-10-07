#requires -Version 7
# safe-reload.ps1: reload GlazeWM's config without losing the layout. Bound to Win+Shift+R.
# GlazeWM 3.10.1's wm-reload-config drops every window onto the focused workspace, so: record each
# window's workspace by its window handle, reload, then move any window that moved back to where it was.
$ErrorActionPreference = 'SilentlyContinue'
$G = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'

function Get-Placement {
  $map = @{}
  function Walk($node, $ws) {
    foreach ($c in $node.children) {
      if ($c.type -eq 'window') { $map["$($c.handle)"] = @{ ws = $ws; id = $c.id } } else { Walk $c $ws }
    }
  }
  foreach ($w in (& $G query workspaces | ConvertFrom-Json).data.workspaces) { Walk $w $w.name }
  $map
}

$before = Get-Placement
$r = & $G command wm-reload-config | ConvertFrom-Json
if (-not $r.success) { exit 1 }
Start-Sleep -Milliseconds 800
$after = Get-Placement
foreach ($h in $before.Keys) {
  if ($after.ContainsKey($h) -and $after[$h].ws -ne $before[$h].ws) {
    & $G command --id $after[$h].id move --workspace $before[$h].ws | Out-Null
  }
}
