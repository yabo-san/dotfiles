# Raycast Script Command (Windows / PowerShell)
# Drop the stale SMB session to the NAS and map N: again. Windows does not retry the
# drive when Tailscale comes back, so this is the manual "get it back" step. No
# detection on purpose: run it when N: is dead. Credentials come from the cmdkey
# entry for thinkserver.tail811b23.ts.net (one-time: cmdkey /add:<host> /user:yabo /pass).

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
