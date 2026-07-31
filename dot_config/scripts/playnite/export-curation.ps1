#requires -Version 5.1
<#
  export-curation.ps1 — snapshot per-game Playnite curation into the dotfiles.

  THE PROBLEM THIS SOLVES
  clone-my-playnite.ps1 deliberately scrubs library\*.db as [secret] — reasonable
  for accounts and API keys, wrong for TAGS and FEATURES. Those aren't
  credentials, they're curation, and they are exactly what you'd most want back
  on a fresh machine. Without them a rebuilt box has the Playnite -> GlazeWM
  integration and no data to feed it: every 'yabo:display=' target and every
  '[RC] Display:' assignment is gone, and every game lands on the default
  workspace.

  So: export the game -> tags/features mapping to tracked JSON. Small, diffable,
  secret-free, and it survives the library being rebuilt from scratch.

  Games are keyed by NAME + PLUGIN, never by database GUID — the GUIDs are minted
  fresh when the library re-imports, so they cannot match across machines.

  READ-ONLY. Works on a temp copy; the live database is never opened.
  Run with Playnite closed for a consistent snapshot.

  Writes into the chezmoi SOURCE tree (same pattern as snapshot-my-playnite.ps1
  writing into bundle/), so the result is committed rather than deployed:
      ~/.local/share/chezmoi/dot_config/playnite/curation.json
  Then: chezmoi apply; git commit.
#>
param(
    [string] $PlayniteRoot = (Join-Path $env:APPDATA 'Playnite'),
    [string] $OutFile      = (Join-Path $env:USERPROFILE '.local\share\chezmoi\dot_config\playnite\curation.json')
)

$ErrorActionPreference = 'Stop'

$liteDb = "$env:LOCALAPPDATA\Playnite\LiteDB.dll"
if (-not (Test-Path $liteDb)) { throw "LiteDB.dll not found — is Playnite installed? ($liteDb)" }

$libDir = Join-Path $PlayniteRoot 'library'
foreach ($f in 'games.db', 'tags.db', 'features.db') {
    if (-not (Test-Path (Join-Path $libDir $f))) { throw "missing $f in $libDir" }
}

if (Get-Process 'Playnite*' -ErrorAction SilentlyContinue) {
    Write-Host "warning: Playnite is running — snapshot may be mid-write." -ForegroundColor Yellow
}

# Work on a copy so a live Playnite can never be disturbed.
$tmp = Join-Path $env:TEMP "yabo-curation-$PID"
New-Item -ItemType Directory -Force $tmp | Out-Null
try {
    foreach ($f in 'games.db', 'tags.db', 'features.db') {
        Copy-Item (Join-Path $libDir $f) (Join-Path $tmp $f) -Force
    }
    Add-Type -Path $liteDb

    function Read-Lookup([string]$File, [string]$Collection) {
        $map = @{}
        $db = New-Object LiteDB.LiteDatabase("Filename=$(Join-Path $tmp $File);ReadOnly=true")
        try {
            foreach ($doc in $db.GetCollection($Collection).FindAll()) {
                $map[$doc['_id'].AsGuid.ToString()] = $doc['Name'].AsString
            }
        } finally { $db.Dispose() }
        return $map
    }

    $tagNames     = Read-Lookup 'tags.db'     'Tag'
    $featureNames = Read-Lookup 'features.db' 'GameFeature'

    $entries = @()
    $db = New-Object LiteDB.LiteDatabase("Filename=$(Join-Path $tmp 'games.db');ReadOnly=true")
    try {
        foreach ($g in $db.GetCollection('Game').FindAll()) {
            # LiteDB omits empty arrays entirely, so these keys may be absent.
            $tags = @()
            if ($g.ContainsKey('TagIds')) {
                foreach ($id in $g['TagIds'].AsArray) {
                    $n = $tagNames[$id.AsGuid.ToString()]
                    if ($n) { $tags += $n }
                }
            }
            $feats = @()
            if ($g.ContainsKey('FeatureIds')) {
                foreach ($id in $g['FeatureIds'].AsArray) {
                    $n = $featureNames[$id.AsGuid.ToString()]
                    if ($n) { $feats += $n }
                }
            }
            if (-not $tags -and -not $feats) { continue }   # nothing to carry

            $entries += [ordered]@{
                name     = $g['Name'].AsString
                # PluginId identifies the library (Steam/Epic/Yabo/...) and is a
                # stable constant per plugin, unlike the game's own GUID.
                plugin   = if ($g.ContainsKey('PluginId')) { $g['PluginId'].AsGuid.ToString() } else { '' }
                gameId   = if ($g.ContainsKey('GameId'))   { $g['GameId'].AsString }            else { '' }
                tags     = @($tags | Sort-Object)
                features = @($feats | Sort-Object)
            }
        }
    } finally { $db.Dispose() }

    $entries = $entries | Sort-Object { $_.name }

    $payload = [ordered]@{
        '##'        = @(
            'Per-game Playnite curation (tags + features), exported by export-curation.ps1.',
            'Tags and features are CURATION, not secrets - clone-my-playnite.ps1 scrubs the',
            'whole library DB, which would otherwise lose every yabo:display= target and',
            'every [RC] Display: assignment on a fresh machine.',
            'Games are keyed by name+plugin because database GUIDs are re-minted on import.'
        )
        exportedAt  = (Get-Date).ToString('o')
        gameCount   = $entries.Count
        games       = $entries
    }

    New-Item -ItemType Directory -Force (Split-Path $OutFile) | Out-Null
    $payload | ConvertTo-Json -Depth 10 | Set-Content $OutFile -Encoding UTF8

    Write-Host "[curation] $($entries.Count) games with tags/features -> $OutFile" -ForegroundColor Green
    Write-Host "           commit it, then 'chezmoi apply' to deploy." -ForegroundColor DarkGray
}
finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
