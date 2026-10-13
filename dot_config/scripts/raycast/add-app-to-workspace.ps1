# Raycast Script Command (Windows / PowerShell)
# Pick a running app and tile it on a GlazeWM workspace from now on: appends it to
# .chezmoidata/glazewm.yaml, applies, reloads. Apps already tiled are left out of the list.

# @raycast.schemaVersion 1
# @raycast.title Add App to Workspace
# @raycast.mode compact
# @raycast.packageName GlazeWM
# @raycast.argument1 { "type": "dropdown", "placeholder": "Workspace", "data": [{"title": "1 main", "value": "1"}, {"title": "2 comms", "value": "2"}, {"title": "3 media", "value": "3"}, {"title": "4 dev", "value": "4"}, {"title": "5 play", "value": "5"}, {"title": "6 spare (F)", "value": "6"}, {"title": "7 utils", "value": "7"}, {"title": "8 crt", "value": "8"}, {"title": "9 spare (V)", "value": "9"}, {"title": "10 spare (A)", "value": "10"}] }
# @raycast.argument2 { "type": "dropdown", "placeholder": "Tile or float", "data": [{"title": "Tile", "value": "tile"}, {"title": "Float", "value": "float"}] }

# Optional:
# @raycast.icon 🪟
# @raycast.description Pick a running app and tile it on a workspace

$ws   = $args[0]
$mode = if ($args.Count -gt 1 -and $args[1] -eq 'float') { 'float' } else { 'tile' }
$data = Join-Path $env:USERPROFILE '.local\share\chezmoi\.chezmoidata\glazewm.yaml'
$raw  = Get-Content $data -Raw
$listed = [regex]::Matches($raw, 'p: "([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
$covered = { param($p) foreach ($l in $listed) { if ($p -cmatch "^($l)$") { return $true } }; $false }

# every visible, titled, top-level window that isn't a popup or a tool window
Add-Type @'
using System; using System.Collections.Generic; using System.Text; using System.Runtime.InteropServices;
public static class Wins {
  delegate bool Cb(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(Cb cb, IntPtr l);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint cmd);
  [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
  public static List<string> All() {
    var r = new List<string>();
    EnumWindows((h, l) => {
      if (!IsWindowVisible(h) || GetWindow(h, 4) != IntPtr.Zero || (GetWindowLong(h, -20) & 0x80) != 0) return true;
      var s = new StringBuilder(256); if (GetWindowText(h, s, 256) == 0) return true;
      uint pid; GetWindowThreadProcessId(h, out pid); r.Add(pid + "\t" + s); return true;
    }, IntPtr.Zero);
    return r;
  }
}
'@
$skip = [regex]::Match($raw, 'pickerSkip: "([^"]+)"').Groups[1].Value   # .chezmoidata/glazewm.yaml
$rows = [Wins]::All() | ForEach-Object {
    $pid_, $title = $_ -split "`t", 2
    $name = (Get-Process -Id $pid_ -ErrorAction SilentlyContinue).ProcessName
    if ($name -and $name -notmatch "^($skip)$" -and -not (& $covered $name)) {
        [pscustomobject]@{ App = $name; Window = $title }
    }
} | Sort-Object App, Window -Unique

if (-not $rows) { "Every open app is already tiled"; exit 0 }

# Out-GridView ships with Windows PowerShell 5.1 (pwsh 7 needs a module), so the picker runs there
$tmp = New-TemporaryFile
$rows | Export-Clixml $tmp
$pick = powershell.exe -NoProfile -Command "Import-Clixml '$tmp' | Out-GridView -Title 'Tile on workspace $ws' -OutputMode Single | ForEach-Object App"
Remove-Item $tmp
$proc = "$pick".Trim()
if (-not $proc) { "Nothing picked"; exit 0 }

# regex metacharacters in a process name become [x], which needs no escaping inside a YAML string
$pattern = -join ($proc.ToCharArray() | ForEach-Object { if ('.+*?()[]{}|^$\'.Contains($_)) { "[$_]" } else { $_ } })

$lines = [System.Collections.Generic.List[string]]($raw -split "`r?`n")
while ($lines.Count -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
$start = $lines.FindIndex({ param($l) $l -match "^\s+- ws: `"$ws`"\s*$" })
if ($start -lt 0) {
    # first app on this workspace: start its rule just before the never-offer list
    $at = $lines.FindIndex({ param($l) $l -match '^  (# never offered|pickerSkip:)' })
    if ($at -lt 0) { $at = $lines.Count }
    $lines.InsertRange($at, [string[]]@("    - ws: `"$ws`"", "      note: workspace $ws", "      apps:"))
    $start = $at
}
$end = $lines.FindIndex($start + 1, { param($l) $l -match '^\s+- ws: |^  (# never offered|pickerSkip:)' })
if ($end -lt 0) { $end = $lines.Count }
while ($end -gt $start -and $lines[$end - 1].Trim() -eq '') { $end-- }
$lines.Insert($end, "        - p: `"$pattern`"")
if ($mode -eq 'float') { $lines.Insert($end + 1, "          float: true") }
[IO.File]::WriteAllText($data, ($lines -join "`n") + "`n")   # keep LF, no BOM

chezmoi apply --no-tty "$env:USERPROFILE\.glzr\glazewm\config.yaml"
if ($LASTEXITCODE -ne 0) { "chezmoi apply failed; $proc was added to glazewm.yaml"; exit 1 }
& "$env:USERPROFILE\.config\scripts\glazewm\safe-reload.ps1" | Out-Null
"$proc goes to workspace $ws, $(if ($mode -eq 'float') { 'floating' } else { 'tiled' }) (reopen it once)"
