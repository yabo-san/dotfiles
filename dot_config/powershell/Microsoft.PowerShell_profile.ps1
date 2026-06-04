# PowerShell profile — full parity port of dot_zshrc for Windows.
# Chezmoi-tracked; deployed to $PROFILE.CurrentUserAllHosts.
# Mirrors: vi-mode, EDITOR=nvim, lsd/bat aliases, completions, Pure-style
# prompt (starship), and the dot_zshrc alias set. Mac-only paths adapted to D:\.

# --- ensure scoop shims on PATH (nvim, lsd, bat, fzf, lazygit, kubectl...) ---
$scoopShims = "$env:USERPROFILE\scoop\shims"
if ((Test-Path $scoopShims) -and ($env:Path -notlike "*$scoopShims*")) {
    $env:Path = "$scoopShims;$env:Path"
}

# ~~~~~~~~~~~~~~~ Vi mode (dot_zshrc: bindkey -v, KEYTIMEOUT=1) ~~~~~~~~~~~~~~~
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -ViModeIndicator Cursor      # block/beam cursor shows mode
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
# history hints — only in a real interactive terminal (skips redirected shells)
try { Set-PSReadLineOption -PredictionSource History -ErrorAction Stop } catch {}

# ~~~~~~~~~~~~~~~ Environment (dot_zshrc: EDITOR/VISUAL=nvim, LANG) ~~~~~~~~~~~~
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    $env:EDITOR = "nvim"; $env:VISUAL = "nvim"
}
$env:LANG = "en_US.UTF-8"

# XDG: make Windows respect ~/.config like Linux/mac. Many tools (lazygit,
# fastfetch, etc.) then read from ~/.config instead of %LOCALAPPDATA% — so the
# SAME config files work across all 3 OSes. Big linuxify win.
$env:XDG_CONFIG_HOME = "$env:USERPROFILE\.config"
$env:XDG_DATA_HOME   = "$env:USERPROFILE\.local\share"
$env:XDG_CACHE_HOME  = "$env:USERPROFILE\.cache"
# bat looks at the scoop app dir by default — point it at our tracked config
# (so `cat`=bat never pages and uses our style). Without this it hangs on long files.
$env:BAT_CONFIG_PATH = "$env:USERPROFILE\.config\bat\config"

# ~~~~~~~~~~~~~~~ Shell trio: zoxide + atuin + fzf ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Both init scripts are slow to GENERATE (zoxide ~225ms, atuin ~500ms) but the
# output is static — so CACHE the init script and source the cache (refresh
# weekly). Same trick as kubectl. Keeps startup snappy.
function Initialize-CachedInit($cmd, $args, $cacheName) {
    $cache = Join-Path $env:LOCALAPPDATA $cacheName
    if ((-not (Test-Path $cache)) -or ((Get-Item $cache).LastWriteTime -lt (Get-Date).AddDays(-7))) {
        & $cmd $args 2>$null | Out-String | Set-Content $cache -Encoding utf8
    }
    if ((Get-Item $cache -EA SilentlyContinue).Length -gt 0) { . $cache }
}
# zoxide: smart cd. --cmd cd makes `cd` ITSELF frecency-aware: `cd repos` jumps
# to D:\repos from anywhere, `cd ~/x` still works literally, `cdi` = interactive.
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Initialize-CachedInit 'zoxide' @('init','powershell','--cmd','cd') 'zoxide-init.ps1'
}
# atuin: magic shell history — Ctrl+R full-screen fuzzy search, synced across
# machines. (~200ms init cost; you opted to keep it in PowerShell too.)
# Needs PSReadLine loaded first (done above). Cached init like the others.
if (Get-Command atuin -ErrorAction SilentlyContinue) {
    Initialize-CachedInit 'atuin' @('init','powershell') 'atuin-init.ps1'
}
# fzf via PSFzf: Ctrl+T = fuzzy file insert, Alt+C = fuzzy cd.
# (Ctrl+R is left to atuin above — its history search wins.)
if (Get-Module PSFzf -ListAvailable -ErrorAction SilentlyContinue) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
    # only bind the file + cd choords; do NOT take Ctrl+R (atuin owns it)
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key 'Alt+c' -ScriptBlock { Invoke-FuzzySetLocation } -ErrorAction SilentlyContinue
}

# ~~~~~~~~~~~~~~~ brew — unified package manager (child of 3 OSes) ~~~~~~~~~~~~~
# One command everywhere: real Homebrew on macOS, brew-on-Linux in WSL, and on
# Windows THIS wrapper masquerades as brew over scoop+winget+choco.
# Priority: scoop (per-user, NO UAC — the default that "just works") -> winget
# community -> winget MS STORE (Cider/iCloud/EarTrumpet) -> choco (empty AUR-tier
# fallback, kept). NOTE: scoop never prompts UAC; winget/choco prompt for apps
# that install system-wide (unavoidable for those). scoop is preferred for exactly
# this reason. choco uses the `sudo` (gsudo) shim only when actually hit.
#   brew install <pkg>   (or bare `brew <pkg>`)   first manager that has it wins
#   brew search <pkg>    search ALL three
#   brew upgrade         upgrade everything across all three
#   brew uninstall <pkg> remove (tries each)
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
            Write-Host "winget upgrade --all..." -ForegroundColor Blue; winget upgrade --all --silent
            Write-Host "choco upgrade all..." -ForegroundColor Magenta; sudo choco upgrade all -y
            return
        }
        '^(uninstall|rm|remove)$' {
            scoop uninstall $pkg 2>$null; winget uninstall $pkg 2>$null; sudo choco uninstall $pkg -y 2>$null
            return
        }
        default {  # install <pkg>, or bare `brew <pkg>`
            $target = if ($op -eq 'install') { $pkg } else { $op }
            if (-not $target) { Write-Host "usage: brew install <pkg> | search <pkg> | upgrade | uninstall <pkg>"; return }
            Write-Host "trying scoop..." -ForegroundColor Cyan
            scoop install $target; if ($?) { return }
            Write-Host "scoop miss -> winget (community)..." -ForegroundColor Blue
            winget install --id $target -e --source winget --accept-package-agreements --accept-source-agreements
            if ($?) { return }
            Write-Host "miss -> winget (MS Store)..." -ForegroundColor Green
            winget install --id $target -e --source msstore --accept-package-agreements --accept-source-agreements
            if ($?) { return }
            Write-Host "miss -> choco..." -ForegroundColor Magenta
            sudo choco install $target -y
        }
    }
}


# ~~~~~~~~~~~~~~~ Modern CLI replacements (the Linux daily-driver pack) ~~~~~~~~
# btop=htop, dust=du, duf=df, procs=ps, gdu=disk usage, tldr=man examples,
# delta=git diffs. Installed via scoop; aliased to their classic names where safe.
function top    { btop @args }       # gorgeous system monitor
function du     { dust @args }       # visual disk tree
function df     { duf @args }        # pretty disk free
# `ps` is a built-in ALIAS (-> Get-Process) that shadows a function — remove it
# first so our procs mapping actually wins (same fix as cat/ls).
Remove-Alias ps -Force -ErrorAction SilentlyContinue
Remove-Item Alias:ps -Force -ErrorAction SilentlyContinue
function ps     { procs @args }      # modern process list
# tldr + delta + gdu used by their own names. delta is wired as git pager below.

# yazi — terminal file manager (the "terminal Finder"). `y` opens it, and on
# quit your shell cd's to wherever you browsed (the killer feature).
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -EA SilentlyContinue
    if ($cwd -and $cwd -ne $PWD.Path) { Set-Location -LiteralPath $cwd }
    Remove-Item -Path $tmp -EA SilentlyContinue
}

# ~~~~~~~~~~~~~~~ fetch / greeting ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function ff  { fastfetch @args }
function neofetch { fastfetch @args }
# Greet on a top-level interactive shell, but NOT in the quake dropdown or
# nested shells (keeps quake instant). $env:WT_SESSION-style guard via depth.
if ($Host.Name -eq 'ConsoleHost' -and -not $env:QUAKE_TERM -and (Get-Command fastfetch -EA SilentlyContinue)) {
    fastfetch
}

# ~~~~~~~~~~~~~~~ Unix/mac muscle-memory commands (separate file) ~~~~~~~~~~~~~~
# open, touch, which, pbcopy/pbpaste, export, sudo, mkcd, reload — the "this unix
# command doesn't exist on Windows" gap-fillers. Add new reflexes there.
$unixAliases = "$env:USERPROFILE\.config\powershell\unix-aliases.ps1"
if (Test-Path $unixAliases) { . $unixAliases }

# ~~~~~~~~~~~~~~~ Aliases (ported from dot_zshrc) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function v   { nvim @args }
function gp  { git pull @args }
function gs  { git status @args }
function lg  { lazygit @args }
# k / kgp: kubectl shortcuts. NOTE: `k` is defined later (lazy-loads completion).
function kgp { kubectl get pods @args }

# cat -> bat. PowerShell's built-in `cat` ALIAS (-> Get-Content) shadows a
# function of the same name, so remove it first (same fix as `ls` below).
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Remove-Alias cat -Force -ErrorAction SilentlyContinue
    Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
    function cat { bat @args }
}

# ls -> lsd suite (dot_zshrc: ls/ll/la/lla/lt)
# PowerShell ships a built-in `ls` ALIAS for Get-ChildItem that shadows our
# function — remove it first so our lsd function actually runs.
if (Get-Command lsd -ErrorAction SilentlyContinue) {
    Remove-Alias ls -Force -ErrorAction SilentlyContinue
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls  { lsd --icon always @args }
    function ll  { lsd --icon always -lgh @args }
    function la  { lsd --icon always -lathr @args }
    function lla { lsd --icon always -lgha @args }
    function lt  { lsd --icon always --tree @args }
}

# lastmod (dot_zshrc find → PS)
function lastmod {
    Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.' } |
        Sort-Object LastWriteTime | Format-Table LastWriteTime, FullName -AutoSize
}

# dormin (dot_zshrc: claude --resume / passthrough)
function dormin {
    if ($args.Count -eq 0) { claude --dangerously-skip-permissions --resume }
    else { claude --dangerously-skip-permissions @args }
}

# --- machine-specific dir jumps (mac iCloud paths → Windows D:\) ---
function icloud { Set-Location "D:\iCloudDrive" }
function sb     { Set-Location "D:\iCloudDrive\iCloud~md~obsidian\sb" }
function od     { Set-Location "D:\OneDrive" }
function ubu    { wsl ~ -d Ubuntu @args }   # drop into Ubuntu w/ your zsh dotfiles

# ~~~~~~~~~~~~~~~ Completions (dot_zshrc: fzf, kubectl) ~~~~~~~~~~~~~~~~~~~~~~~~
# kubectl completion is the biggest startup cost (~246ms — a huge completion
# scriptblock). LAZY-LOAD it: don't register at launch; load on first use of
# k/kubectl. Saves ~250ms per shell; you only pay it once, only if you use k8s.
function global:Initialize-KubectlCompletion {
    $kcache = "$env:LOCALAPPDATA\kubectl-completion.ps1"
    if (-not (Test-Path $kcache) -or (Get-Item $kcache).LastWriteTime -lt (Get-Date).AddDays(-7)) {
        kubectl completion powershell | Out-File $kcache -Encoding utf8
    }
    . $kcache
    Remove-Item function:k -ErrorAction SilentlyContinue   # drop the bootstrap wrapper
}
# first `k` or `kubectl` call wires up completion, then runs the command
function k {
    Initialize-KubectlCompletion
    kubectl @args
}
# fzf key-bindings via PSFzf — only if the module is actually installed.
# (Import-Module with -ErrorAction skips the slow -ListAvailable scan when absent.)
if ((Get-Module PSFzf -ListAvailable -EA SilentlyContinue)) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# ~~~~~~~~~~~~~~~ Prompt — native Pure-style (dot_zshrc used `prompt pure`) ~~~
# In-process, ~5ms (vs ~220ms for starship). Catppuccin Mocha colors.
# Format:  yabo  <dir>  <git-branch>  ❯
# git branch only shows inside a repo (one cheap `git branch` call there).
$script:c = @{          # Catppuccin Mocha
    cyan='38;2;148;226;213'; blue='38;2;137;180;250'
    mauve='38;2;203;166;247'; red='38;2;243;139;168'; grey='38;2;108;112;134'
}
function prompt {
    $e = [char]27
    $loc = $PWD.Path.Replace($HOME, '~')
    # git branch (only if inside a repo — fast, no status porcelain)
    $branch = ''
    $g = git symbolic-ref --short HEAD 2>$null
    if ($g) { $branch = "$e[$($c.mauve)m $g$e[0m " }
    # vi-mode aware prompt char: ❯ insert (mauve), ❮ normal (green)... PSReadLine
    # ViModeIndicator=Cursor handles the cursor; we keep a clean mauve ❯.
    "$e[$($c.cyan)myabo$e[0m " +
    "$e[$($c.blue)m$loc$e[0m " +
    $branch +
    "$e[$($c.mauve)m❯$e[0m "
}
