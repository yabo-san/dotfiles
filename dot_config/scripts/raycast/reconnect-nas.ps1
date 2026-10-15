# Raycast Script Command (Windows / PowerShell)
# Drops the stale SMB session and remaps N:; Windows doesn't retry the drive when Tailscale comes back.
# Credentials: one-time cmdkey /add:thinkserver.tail811b23.ts.net /user:yabo /pass.

# @raycast.schemaVersion 1
# @raycast.title Reconnect NAS
# @raycast.mode compact
# @raycast.packageName NAS

# Optional:
# @raycast.icon 🗄️
# @raycast.description Remap N: to \\thinkserver.tail811b23.ts.net\NAS

$share = '\\thinkserver.tail811b23.ts.net\NAS'

net use N: /delete /y 2>$null | Out-Null
Remove-SmbMapping -RemotePath $share -Force -ErrorAction SilentlyContinue

net use N: $share /persistent:yes | Out-Null
if ($LASTEXITCODE -eq 0) { "N: connected" } else { "N: failed (net use exit $LASTEXITCODE)" }
