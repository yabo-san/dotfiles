#requires -Version 5.1
# =============================================================================
# apply-emulation.ps1: put ~/.config/playnite/emulation.json back into Playnite
# =============================================================================
# The other half of export-emulation.ps1. Idempotent: profiles are matched by
# name, mappings by RomM platform id, so a second run changes nothing.
#
# It does not create emulators. On a fresh machine, first let Playnite find
# them (Library > Configure Emulators > Auto-scan, pointing at the scoop and
# Steam RetroArch folders), then close Playnite and run this. An emulator the
# JSON names but Playnite lacks is reported and skipped.
#
# RomM sign-in (host, user, token) is not touched: sign in from the plugin.
# Backs up emulators.db and the RomM config next to themselves first.
# =============================================================================
$ErrorActionPreference = 'Stop'
if (Get-Process Playnite.DesktopApp, Playnite.FullscreenApp -ErrorAction SilentlyContinue) { throw 'Playnite is running, close it first.' }

$pn    = Join-Path $env:APPDATA 'Playnite'
$src   = Join-Path $env:USERPROFILE '.config\playnite\emulation.json'
$romm  = Join-Path $pn 'ExtensionsData\9700aa21-447d-41b4-a989-acd38f407d9f\config.json'
$steam = ((Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath -replace '/', '\')
if (-not $steam) { $steam = 'C:\Program Files (x86)\Steam' }
$want  = Get-Content $src -Raw | ConvertFrom-Json
Add-Type -Path (Join-Path $env:LOCALAPPDATA 'Playnite\LiteDB.dll')

function Expand([string]$s) { if (-not $s) { return $s }; $s.Replace('%STEAM%', $steam).Replace('%USERPROFILE%', $env:USERPROFILE) }
function Val($v) { [LiteDB.BsonValue]::new($v) }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item "$pn\library\emulators.db" "$pn\library\emulators.db.pre-apply-$stamp"
if (Test-Path $romm) { Copy-Item $romm "$romm.pre-apply-$stamp" }

# specification id -> this install's platform GUID
$db = New-Object LiteDB.LiteDatabase("Filename=$pn\library\platforms.db;Mode=ReadOnly")
$plat = @{}
foreach ($p in $db.GetCollection('Platform').FindAll()) { if ($p.ContainsKey('SpecificationId') -and -not $p['SpecificationId'].IsNull) { $plat[$p['SpecificationId'].AsString] = $p['_id'].AsGuid } }
$db.Dispose()

$db  = New-Object LiteDB.LiteDatabase("Filename=$pn\library\emulators.db")
$col = $db.GetCollection('Emulator')
$installed = @{}
foreach ($e in $col.FindAll()) { if ($e.ContainsKey('BuiltInConfigId') -and -not $e['BuiltInConfigId'].IsNull) { $installed[$e['BuiltInConfigId'].AsString] = $e } }

$ids = @{}   # "<configId>|<kind>|<name>" -> profile id, for the mappings
foreach ($we in $want.emulators) {
    $e = $installed[$we.builtInConfigId]
    if (-not $e) { Write-Warning "$($we.name) is not in Playnite yet: add it (auto-scan), then run this again."; continue }
    $emuId = $e['_id'].AsString

    $builtin = if ($e.ContainsKey('BuiltinProfiles') -and -not $e['BuiltinProfiles'].IsNull) { ,$e['BuiltinProfiles'].AsArray } else { New-Object LiteDB.BsonArray }
    $have = @{}; foreach ($b in $builtin) { $have[$b['BuiltInProfileName'].AsString] = $b['_id'].AsString }
    foreach ($name in $we.builtinProfiles) {
        if (-not $have.ContainsKey($name)) {
            $d = New-Object LiteDB.BsonDocument
            $d['_id'] = Val ('#builtin_' + [guid]::NewGuid()); $d['Name'] = Val $name; $d['BuiltInProfileName'] = Val $name; $d['OverrideDefaultArgs'] = Val $false
            [void]$builtin.Add((Val $d)); $have[$name] = $d['_id'].AsString
            "  + $($we.name): built-in profile $name"
        }
        $ids["$($we.builtInConfigId)|builtin|$name"] = @($emuId, $have[$name])
    }
    $e['BuiltinProfiles'] = $builtin

    $custom = if ($e.ContainsKey('CustomProfiles') -and -not $e['CustomProfiles'].IsNull) { ,$e['CustomProfiles'].AsArray } else { New-Object LiteDB.BsonArray }
    foreach ($wc in $we.customProfiles) {
        $d = ($custom | Where-Object { $_.AsDocument['Name'].AsString -eq $wc.name } | Select-Object -First 1)
        if ($d) { $d = $d.AsDocument } else {
            $d = New-Object LiteDB.BsonDocument; $d['_id'] = Val ('#custom_' + [guid]::NewGuid())
            [void]$custom.Add((Val $d)); "  + $($we.name): custom profile $($wc.name)"
        }
        $d['Name'] = Val $wc.name
        $d['Executable'] = Val (Expand $wc.executable)
        $d['Arguments'] = Val (Expand $wc.arguments)
        $d['WorkingDirectory'] = Val (Expand $wc.workingDirectory)
        $d['TrackingMode'] = Val $wc.trackingMode
        $d['TrackingPath'] = Val (Expand $wc.trackingPath)
        $pa = New-Object LiteDB.BsonArray
        foreach ($s in $wc.platforms) { if ($plat[$s]) { [void]$pa.Add((Val $plat[$s])) } else { Write-Warning "unknown platform '$s' on $($wc.name)" } }
        $d['Platforms'] = $pa
        $xa = New-Object LiteDB.BsonArray; foreach ($x in $wc.imageExtensions) { [void]$xa.Add((Val ([string]$x))) }
        $d['ImageExtensions'] = $xa
        $ids["$($we.builtInConfigId)|custom|$($wc.name)"] = @($emuId, $d['_id'].AsString)
    }
    $e['CustomProfiles'] = $custom
    [void]$col.Update($e)
}
$db.Dispose()

if (-not (Test-Path $romm)) { Write-Warning 'RomM plugin not installed or never opened: install it, open its settings once, then run this again.'; return }
$r = Get-Content $romm -Raw | ConvertFrom-Json
foreach ($p in $want.romm.settings.PSObject.Properties) {
    if ($r.PSObject.Properties.Name -contains $p.Name) { $r.($p.Name) = $p.Value } else { $r | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value }
}
$maps = [System.Collections.ArrayList]@(@($r.Mappings) | Where-Object { $_ })
foreach ($wm in $want.romm.mappings) {
    $hit = $ids["$($wm.emulator)|$($wm.profileKind)|$($wm.profile)"]
    if (-not $hit) { Write-Warning "RomM platform $($wm.rommPlatformId): profile '$($wm.profile)' on '$($wm.emulator)' missing, skipped."; continue }
    $dest = Expand $wm.destinationPath
    New-Item -ItemType Directory -Force $dest | Out-Null
    $m = $maps | Where-Object { [int]$_.RomMPlatformId -eq [int]$wm.rommPlatformId } | Select-Object -First 1
    if (-not $m) { $m = [pscustomobject]@{ MappingId = [guid]::NewGuid().ToString() }; [void]$maps.Add($m) }
    $vals = [ordered]@{ Enabled = $wm.enabled; AutoExtract = $wm.autoExtract; UseM3U = $wm.useM3U; EmulatorId = $hit[0]; EmulatorProfileId = $hit[1]; RomMPlatformId = $wm.rommPlatformId; DestinationPath = $dest; InstallFlat = $wm.installFlat }
    foreach ($k in $vals.Keys) { if ($m.PSObject.Properties.Name -contains $k) { $m.$k = $vals[$k] } else { $m | Add-Member -NotePropertyName $k -NotePropertyValue $vals[$k] } }
}
$r.Mappings = @($maps)
$r | ConvertTo-Json -Depth 20 | Set-Content -Path $romm -Encoding UTF8
"RomM mappings: $($maps.Count). Backups: *.pre-apply-$stamp"
