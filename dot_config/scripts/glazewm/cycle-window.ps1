# Win+Tab / Win+Shift+Tab: focus the next / previous GlazeWM window, workspace by workspace. Focus goes
# through GlazeWM, so it switches workspace when needed and the mouse follows.
param([int]$Step = 1)

$windows = @((glazewm query windows | ConvertFrom-Json).data.windows)
if ($windows.Count -lt 2) { return }
$cur = [array]::FindIndex($windows, [Predicate[object]] { param($w) $w.hasFocus })
$next = ($cur + $Step + $windows.Count) % $windows.Count   # nothing focused (-1) starts at the first
glazewm command focus --container-id $windows[$next].id | Out-Null
