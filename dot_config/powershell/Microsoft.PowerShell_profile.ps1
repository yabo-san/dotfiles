# PowerShell profile: Windows port of dot_zshrc, deployed to $PROFILE.CurrentUserAllHosts.

$scoopShims = "$env:USERPROFILE\scoop\shims"
if ((Test-Path $scoopShims) -and ($env:Path -notlike "*$scoopShims*")) {
    $env:Path = "$scoopShims;$env:Path"
}

# Modules load from LOCALAPPDATA, not OneDrive-redirected Documents, where sync locks them (PSFzf 0x80070020).
$localModules = "$env:LOCALAPPDATA\PowerShell\Modules"
if ($env:PSModulePath -notlike "*$localModules*") {
    $env:PSModulePath = "$localModules;$env:PSModulePath"
}

Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -ViModeIndicator Cursor
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
# try: fails in redirected (non-interactive) shells.
try { Set-PSReadLineOption -PredictionSource History -ErrorAction Stop } catch {}

if (Get-Command nvim -ErrorAction SilentlyContinue) {
    $env:EDITOR = "nvim"; $env:VISUAL = "nvim"
}
$env:LANG = "en_US.UTF-8"

# XDG: tools read the same ~/.config files as on Linux/mac.
$env:XDG_CONFIG_HOME = "$env:USERPROFILE\.config"
$env:XDG_DATA_HOME   = "$env:USERPROFILE\.local\share"
$env:XDG_CACHE_HOME  = "$env:USERPROFILE\.cache"
# Point bat at the tracked config; without it `cat`=bat pages and hangs on long files.
$env:BAT_CONFIG_PATH = "$env:USERPROFILE\.config\bat\config"

# zoxide/atuin init is slow to generate but static: cache it, refresh weekly.
function Initialize-CachedInit($cmd, $cmdArgs, $cacheName) {
    $cache = Join-Path $env:LOCALAPPDATA $cacheName
    if ((-not (Test-Path $cache)) -or ((Get-Item $cache).LastWriteTime -lt (Get-Date).AddDays(-7))) {
        # $cmdArgs, NOT $args: $args is an automatic variable, a param by that name arrives empty.
        $out = & $cmd @cmdArgs 2>$null | Out-String
        if ($out.Trim()) { Set-Content $cache $out -Encoding utf8 }
    }
    if ((Get-Item $cache -EA SilentlyContinue).Length -gt 0) { . $cache }
}
# zoxide: --cmd cd makes `cd` itself frecency-aware; `cdi` = interactive.
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Initialize-CachedInit 'zoxide' @('init','powershell','--cmd','cd') 'zoxide-init.ps1'
}
# atuin: Ctrl+R history. Needs PSReadLine loaded first.
if (Get-Command atuin -ErrorAction SilentlyContinue) {
    Initialize-CachedInit 'atuin' @('init','powershell') 'atuin-init.ps1'
}
# PSFzf: Ctrl+T file insert, Alt+C cd. Ctrl+R is left to atuin.
if (Get-Module PSFzf -ListAvailable -ErrorAction SilentlyContinue) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key 'Alt+c' -ScriptBlock { Invoke-FuzzySetLocation } -ErrorAction SilentlyContinue
}

# brew: one command on every OS; here it tries scoop -> winget -> MS Store -> choco, first hit wins.
# scoop first because it never prompts UAC.
function brew {
    $op = $args[0]; $pkg = $args[1]
    switch -Regex ($op) {
        '^(search|se)$' {
            Write-Host "── scoop ──"          -ForegroundColor Cyan;    scoop search $pkg
            Write-Host "── winget ──"         -ForegroundColor Blue;    winget search $pkg --source winget
            Write-Host "── MS Store ──"       -ForegroundColor Green;   winget search $pkg --source msstore
            Write-Host "── choco ──"          -ForegroundColor Magenta; choco search $pkg
            return
        }
        '^(upgrade|up)$' {
            Write-Host "scoop update *..."  -ForegroundColor Cyan;  scoop update *
            Write-Host "winget upgrade --all..." -ForegroundColor Blue; sudo winget upgrade --all --silent
            Write-Host "choco upgrade all..." -ForegroundColor Magenta; sudo choco upgrade all -y
            return
        }
        '^(uninstall|rm|remove)$' {
            scoop uninstall $pkg 2>$null; winget uninstall $pkg 2>$null; sudo choco uninstall $pkg -y 2>$null
            return
        }
        default {  # install <pkg...>, or bare `brew <pkg...>` (multi-word ok)
            # join all args so `brew install proton mail` works
            $rest = if ($op -eq 'install') { $args[1..($args.Count-1)] } else { $args }
            $target = ($rest -join ' ').Trim()
            if (-not $target) { Write-Host "usage: brew install <pkg> | search <pkg> | upgrade | uninstall <pkg>"; return }
            Write-Host "trying scoop..." -ForegroundColor Cyan
            scoop install $target; if ($?) { return }
            # No --id -e: a plain query fuzzy-matches, so names like "proton mail" resolve.
            Write-Host "scoop miss -> winget (community)..." -ForegroundColor Blue
            winget install $target --source winget --accept-package-agreements --accept-source-agreements
            if ($?) { return }
            Write-Host "miss -> winget (MS Store)..." -ForegroundColor Green
            winget install $target --source msstore --accept-package-agreements --accept-source-agreements
            if ($?) { return }
            Write-Host "miss -> choco..." -ForegroundColor Magenta
            sudo choco install $target -y
        }
    }
}


function top    { btop @args }
function du     { dust @args }
function df     { duf @args }
# `ps` is a built-in alias that shadows functions; remove it first.
Remove-Alias ps -Force -ErrorAction SilentlyContinue
Remove-Item Alias:ps -Force -ErrorAction SilentlyContinue
function ps     { procs @args }

# yazi: on quit the shell cd's to where you browsed.
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -EA SilentlyContinue
    if ($cwd -and $cwd -ne $PWD.Path) { Set-Location -LiteralPath $cwd }
    Remove-Item -Path $tmp -EA SilentlyContinue
}

function ff  { fastfetch @args }
function neofetch { fastfetch @args }
# No greeting in the quake dropdown, so it opens instantly.
if ($Host.Name -eq 'ConsoleHost' -and -not $env:QUAKE_TERM -and (Get-Command fastfetch -EA SilentlyContinue)) {
    fastfetch
}

# Unix muscle-memory gap-fillers (open, touch, which, pbcopy, sudo, ...).
$unixAliases = "$env:USERPROFILE\.config\powershell\unix-aliases.ps1"
if (Test-Path $unixAliases) { . $unixAliases }

function v   { nvim @args }
function gp  { git pull @args }
function gs  { git status @args }
function lg  { lazygit @args }
# `k` is defined further down (lazy-loads completion).
function kgp { kubectl get pods @args }

# The built-in `cat` alias shadows functions; remove it first.
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Remove-Alias cat -Force -ErrorAction SilentlyContinue
    Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
    function cat { bat @args }
}

# The built-in `ls` alias shadows functions; remove it first.
if (Get-Command lsd -ErrorAction SilentlyContinue) {
    Remove-Alias ls -Force -ErrorAction SilentlyContinue
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls  { lsd --icon always @args }
    function ll  { lsd --icon always -lgh @args }
    function la  { lsd --icon always -lathr @args }
    function lla { lsd --icon always -lgha @args }
    function lt  { lsd --icon always --tree @args }
}

function lastmod {
    Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.' } |
        Sort-Object LastWriteTime | Format-Table LastWriteTime, FullName -AutoSize
}

# dormin: opencode, default model ollama (the Mac uses the tailscale-bound server on yabohome).
function dormin {
    if ($args.Count -eq 0) { opencode }
    else { opencode run --auto @args }
}

# cc: Claude Code resumed from HOME, where the long-running rice session lives (sessions are per-directory).
# cca: elevated. Never elevate the quake terminal instead: UIPI blocks AHK hotkeys over admin windows.
function cc  { Push-Location $HOME; try { claude -c --dangerously-skip-permissions @args } finally { Pop-Location } }
function cca { Push-Location $HOME; try { gsudo claude -c --dangerously-skip-permissions @args } finally { Pop-Location } }

function icloud { Set-Location "D:\iCloudDrive" }
# sb = the replica you edit; the daemon bridges it to iCloud. sbi = the iCloud side, look only.
function sb     { Set-Location "D:\obsidian\sb" }
function sbi    { Set-Location "D:\iCloudDrive\iCloud~md~obsidian\sb" }
function od     { Set-Location "D:\OneDrive" }
# desktop: asks Windows for the real (OneDrive-redirected) Desktop instead of hardcoding the path.
function desktop { Set-Location -LiteralPath ([Environment]::GetFolderPath('Desktop')) }
function ubu    { wsl ~ -d Ubuntu @args }
# devpod: DevPod muscle memory over Devsy. Names default to this folder, which is how Devsy names workspaces.
# -q hides Devsy's harmless keepalive/port-forward log lines that print on top of nvim.
function devpod {
    $verb = $args[0]
    $rest = @($args | Select-Object -Skip 1)
    $here = (Split-Path -Leaf (Get-Location)).ToLower()
    if (-not $verb) { devsy workspace list; return }
    switch ($verb) {
        'up'     { if ($rest.Count -eq 0) { $rest = @('.') }; devsy workspace up @rest --ide none }
        'ssh'    { if ($rest.Count -eq 0) { $rest = @($here) }; devsy workspace ssh @rest -q }
        'stop'   { if ($rest.Count -eq 0) { $rest = @($here) }; devsy workspace stop @rest }
        'delete' { if ($rest.Count -eq 0) { $rest = @($here) }; devsy workspace delete @rest }
        default  { devsy workspace @args }
    }
}

# kubectl completion costs ~250ms, so it loads on the first `k` call.
function global:Initialize-KubectlCompletion {
    $kcache = "$env:LOCALAPPDATA\kubectl-completion.ps1"
    if (-not (Test-Path $kcache) -or (Get-Item $kcache).LastWriteTime -lt (Get-Date).AddDays(-7)) {
        kubectl completion powershell | Out-File $kcache -Encoding utf8
    }
    . $kcache
    Remove-Item function:k -ErrorAction SilentlyContinue   # drop the bootstrap wrapper
}
function k {
    Initialize-KubectlCompletion
    kubectl @args
}

# Native Pure-style prompt: ~5ms in-process vs ~220ms for starship. Catppuccin Mocha.
$script:c = @{
    cyan='38;2;148;226;213'; blue='38;2;137;180;250'
    mauve='38;2;203;166;247'; red='38;2;243;139;168'; grey='38;2;108;112;134'
}
function prompt {
    $e = [char]27
    $loc = $PWD.Path.Replace($HOME, '~')
    $branch = ''
    $g = git symbolic-ref --short HEAD 2>$null
    if ($g) { $branch = "$e[$($c.mauve)m $g$e[0m " }
    "$e[$($c.cyan)myabo$e[0m " +
    "$e[$($c.blue)m$loc$e[0m " +
    $branch +
    "$e[$($c.mauve)m❯$e[0m "
}
