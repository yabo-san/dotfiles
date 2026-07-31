#requires -Version 5.1
<#
  restore-curation.ps1 — re-apply exported tags/features to a rebuilt library.

  The other half of export-curation.ps1. On a fresh machine the library is
  re-imported from scratch and every tag is gone, so the Playnite -> GlazeWM
  integration would have no data to read. This puts it back.

  RUNS INSIDE PLAYNITE, via the global "Application started" script, so it can
  use $PlayniteApi.Database rather than writing LiteDB behind a running app —
  which is how you corrupt a library. (Borderless Gaming is the cautionary tale:
  one malformed config and it silently deletes every favourite.)

  GATED ON A MARKER FILE. It does nothing on a normal Playnite launch. Drop
  ~/.config/playnite/.restore-pending (the Raycast command "Restore Playnite
  Curation" does it for you), then start Playnite. The marker is consumed on
  success so it can't loop.

  NON-DESTRUCTIVE: only ever ADDS tags and features. It never removes anything,
  so running it against a library that's already correct is a no-op, and it can
  never eat curation you did after the last export.

  Games are matched on NAME + PLUGIN. Database GUIDs are minted fresh on import,
  so they can't match across machines.
#>
param(
    [object] $PlayniteApi,
    [string] $CurationFile = (Join-Path $env:USERPROFILE '.config\playnite\curation.json'),
    [string] $Marker       = (Join-Path $env:USERPROFILE '.config\playnite\.restore-pending'),
    [switch] $Force,
    [switch] $WhatIf
)

$ErrorActionPreference = 'Continue'
$log = Join-Path $env:USERPROFILE '.config\playnite\restore-curation.log'

function Note($m) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m"
    try { Add-Content -Path $log -Value $line -Encoding UTF8 } catch { }
}

try {
    if (-not $Force -and -not (Test-Path $Marker)) { return }   # normal launch: do nothing
    if (-not $PlayniteApi) { Note 'no $PlayniteApi - must run inside Playnite'; return }
    if (-not (Test-Path $CurationFile)) { Note "curation file missing: $CurationFile"; return }

    $data = Get-Content $CurationFile -Raw | ConvertFrom-Json
    Note "--- restore starting: $($data.gameCount) exported entries (exported $($data.exportedAt))"

    # name|plugin -> game, so lookup is O(1) instead of scanning the library per entry.
    $index = @{}
    foreach ($g in $PlayniteApi.Database.Games) {
        $key = "$($g.Name)|$($g.PluginId)".ToLower()
        if (-not $index.ContainsKey($key)) { $index[$key] = $g }
    }

    # Resolve-or-create a Tag/GameFeature by name, caching so we hit the DB once each.
    $tagCache  = @{}
    $featCache = @{}

    function Resolve-Named($collection, $cache, [string]$name) {
        if ($cache.ContainsKey($name)) { return $cache[$name] }
        $existing = $collection | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        if (-not $existing) {
            if ($WhatIf) { $cache[$name] = $null; return $null }
            $existing = $collection.Add($name)
            Note "  created: $name"
        }
        $cache[$name] = $existing
        return $existing
    }

    $matched = 0; $missing = 0; $touched = 0; $addedTags = 0; $addedFeats = 0

    foreach ($entry in $data.games) {
        $key = "$($entry.name)|$($entry.plugin)".ToLower()
        $game = $index[$key]
        if (-not $game) {
            # Fall back to name-only: the same game can arrive under a different
            # plugin (e.g. imported manually instead of via Steam).
            $game = $PlayniteApi.Database.Games | Where-Object { $_.Name -eq $entry.name } | Select-Object -First 1
        }
        if (-not $game) { $missing++; continue }
        $matched++
        $dirty = $false

        foreach ($tagName in @($entry.tags)) {
            if (-not $tagName) { continue }
            $tag = Resolve-Named $PlayniteApi.Database.Tags $tagCache $tagName
            if (-not $tag) { continue }
            if (-not $game.TagIds) { $game.TagIds = New-Object 'System.Collections.Generic.List[Guid]' }
            if (-not $game.TagIds.Contains($tag.Id)) {
                if (-not $WhatIf) { $game.TagIds.Add($tag.Id) }
                $addedTags++; $dirty = $true
            }
        }

        foreach ($featName in @($entry.features)) {
            if (-not $featName) { continue }
            $feat = Resolve-Named $PlayniteApi.Database.Features $featCache $featName
            if (-not $feat) { continue }
            if (-not $game.FeatureIds) { $game.FeatureIds = New-Object 'System.Collections.Generic.List[Guid]' }
            if (-not $game.FeatureIds.Contains($feat.Id)) {
                if (-not $WhatIf) { $game.FeatureIds.Add($feat.Id) }
                $addedFeats++; $dirty = $true
            }
        }

        if ($dirty) {
            if (-not $WhatIf) { $PlayniteApi.Database.Games.Update($game) }
            $touched++
        }
    }

    Note ("--- done: matched {0}, not in library {1}, updated {2}, +{3} tags, +{4} features{5}" -f `
          $matched, $missing, $touched, $addedTags, $addedFeats, $(if ($WhatIf) { ' (WHATIF)' } else { '' }))

    if (-not $WhatIf -and (Test-Path $Marker)) {
        Remove-Item $Marker -Force -ErrorAction SilentlyContinue   # consume, so it can't loop
    }
}
catch {
    Note "ERROR: $($_.Exception.Message)"
}
