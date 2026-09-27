#requires -Version 5.1
# =============================================================================
# export-emulation.ps1: snapshot Playnite's emulator setup into the dotfiles
# =============================================================================
# Writes ~/.config/playnite/emulation.json: every emulator's profiles (built-in
# names and the full custom ones, e.g. the "<core> via Steam" RetroArch set) and
# the RomM plugin's platform mappings, minus anything secret. apply-emulation.ps1
# puts it back on a fresh Playnite.
#
# Nothing machine-specific is kept raw: platform GUIDs become specification ids
# (the same on every install), emulators are keyed by their built-in config id,
# profiles by name, and paths use %USERPROFILE% / %STEAM% tokens.
#
# Playnite must be closed: it holds the LiteDB files open and rewrites the
# plugin config on exit.
#
# Usage: pwsh ~/.config/scripts/playnite/export-emulation.ps1
#        then `chezmoi re-add ~/.config/playnite/emulation.json`
# =============================================================================
$ErrorActionPreference = 'Stop'
if (Get-Process Playnite.DesktopApp, Playnite.FullscreenApp -ErrorAction SilentlyContinue) { throw 'Playnite is running, close it first.' }

$pn    = Join-Path $env:APPDATA 'Playnite'
$out   = Join-Path $env:USERPROFILE '.config\playnite\emulation.json'
$romm  = Join-Path $pn 'ExtensionsData\9700aa21-447d-41b4-a989-acd38f407d9f\config.json'
$steam = ((Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath -replace '/', '\')
Add-Type -Path (Join-Path $env:LOCALAPPDATA 'Playnite\LiteDB.dll')

function Tokenize([string]$s) {
    if (-not $s) { return $s }
    if ($steam) { $s = $s.Replace($steam, '%STEAM%').Replace('C:\Program Files (x86)\Steam', '%STEAM%') }
    return $s.Replace($env:USERPROFILE, '%USERPROFILE%')
}
function Str($doc, $key) { if ($doc.ContainsKey($key) -and -not $doc[$key].IsNull) { $doc[$key].AsString } }

# platform GUID -> specification id
$db = New-Object LiteDB.LiteDatabase("Filename=$pn\library\platforms.db;Mode=ReadOnly")
$spec = @{}
foreach ($p in $db.GetCollection('Platform').FindAll()) { if ($p.ContainsKey('SpecificationId') -and -not $p['SpecificationId'].IsNull) { $spec[$p['_id'].AsGuid] = $p['SpecificationId'].AsString } }
$db.Dispose()

$db = New-Object LiteDB.LiteDatabase("Filename=$pn\library\emulators.db;Mode=ReadOnly")
$emulators = @(); $profileById = @{}; $emuById = @{}
foreach ($e in $db.GetCollection('Emulator').FindAll()) {
    $cfgId = Str $e 'BuiltInConfigId'
    if (-not $cfgId) { continue }   # hand-made emulators with no definition ("New Emulator") are not portable
    $emuById[$e['_id'].AsString] = $cfgId
    $builtin = @(); $custom = @()
    if ($e.ContainsKey('BuiltinProfiles') -and -not $e['BuiltinProfiles'].IsNull) {
        foreach ($b in $e['BuiltinProfiles'].AsArray) {
            $name = $b['BuiltInProfileName'].AsString
            $builtin += $name
            $profileById[$b['_id'].AsString] = [ordered]@{ kind = 'builtin'; name = $name }
        }
    }
    if ($e.ContainsKey('CustomProfiles') -and -not $e['CustomProfiles'].IsNull) {
        foreach ($c in $e['CustomProfiles'].AsArray) {
            $cd = $c.AsDocument
            $custom += [ordered]@{
                name             = $cd['Name'].AsString
                executable       = Tokenize (Str $cd 'Executable')
                arguments        = Tokenize (Str $cd 'Arguments')
                workingDirectory = Tokenize (Str $cd 'WorkingDirectory')
                trackingMode     = Str $cd 'TrackingMode'
                trackingPath     = Tokenize (Str $cd 'TrackingPath')
                platforms        = @(if ($cd.ContainsKey('Platforms') -and -not $cd['Platforms'].IsNull) { $cd['Platforms'].AsArray | ForEach-Object { $spec[$_.AsGuid] } | Where-Object { $_ } })
                imageExtensions  = @(if ($cd.ContainsKey('ImageExtensions') -and -not $cd['ImageExtensions'].IsNull) { $cd['ImageExtensions'].AsArray | ForEach-Object { $_.AsString } })
            }
            $profileById[$cd['_id'].AsString] = [ordered]@{ kind = 'custom'; name = $cd['Name'].AsString }
        }
    }
    $emulators += [ordered]@{ builtInConfigId = $cfgId; name = $e['Name'].AsString; installDir = Tokenize (Str $e 'InstallDir'); builtinProfiles = $builtin; customProfiles = $custom }
}
$db.Dispose()

$r = Get-Content $romm -Raw | ConvertFrom-Json
$mappings = foreach ($m in $r.Mappings) {
    $prof = $profileById[$m.EmulatorProfileId]
    if (-not $prof -or -not $emuById[$m.EmulatorId]) { Write-Warning "skipping RomM platform $($m.RomMPlatformId): its emulator/profile no longer exists"; continue }
    [ordered]@{
        rommPlatformId  = $m.RomMPlatformId
        emulator        = $emuById[$m.EmulatorId]
        profileKind     = $prof.kind
        profile         = $prof.name
        destinationPath = Tokenize $m.DestinationPath
        enabled         = $m.Enabled
        autoExtract     = $m.AutoExtract
        useM3U          = $m.UseM3U
        installFlat     = $m.InstallFlat
    }
}
# the plugin's behaviour switches; host/user/password/token/device ids stay out
$settings = [ordered]@{}
foreach ($k in 'RomMHost', 'KeepRomMSynced', 'MergeRevisions', 'KeepDeletedGames', 'SkipMissingFiles', 'ExcludeGenres', 'NotifyOnInstallComplete', 'Use7z') { $settings[$k] = $r.$k }

New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
[ordered]@{ emulators = $emulators; romm = [ordered]@{ settings = $settings; mappings = @($mappings | Sort-Object { $_.rommPlatformId }) } } |
    ConvertTo-Json -Depth 10 | Set-Content -Path $out -Encoding UTF8
"wrote $out : $($emulators.Count) emulators, $(@($mappings).Count) RomM mappings"
