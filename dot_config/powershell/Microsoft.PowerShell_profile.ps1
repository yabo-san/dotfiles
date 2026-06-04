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
# zoxide: smart cd. `z wez` jumps to ~/.config/wezterm by frecency; `zi` = pick.
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Initialize-CachedInit 'zoxide' @('init','powershell') 'zoxide-init.ps1'
}
# atuin: DELIBERATELY NOT loaded in PowerShell — its init hooks PSReadLine and
# costs ~213ms per launch, too heavy. atuin lives in WSL instead (real shell,
# where it shines + the sync matters). PowerShell keeps PSReadLine's own Ctrl+R
# history search, which is plenty. Same fast-PS / full-WSL split as starship.
# fzf: Ctrl+T fuzzy file, Alt+C fuzzy cd (via PSFzf if installed; see below).

# ~~~~~~~~~~~~~~~ yay — unified package manager (the Arch analogy) ~~~~~~~~~~~~~
# pacman = scoop+winget (official tiers) ; AUR = chocolatey (community) ;
# yay = this wrapper that hits all three so you forget which has what.
# Priority: scoop (per-user, freshest, no admin) -> winget (official GUI apps)
# -> choco (AUR-tier community fallback).
#   yay <pkg>            install (first manager that has it wins)
#   yay -S <pkg>         same (explicit install, pacman-style)
#   yay -Ss <pkg>        search ALL managers
#   yay -R <pkg>         remove (tries each)
#   yay -Syu             upgrade everything across all managers
function yay {
    $op = $args[0]; $pkg = $args[1]
    switch -Regex ($op) {
        '^-Ss$' {  # search all
            Write-Host "── scoop ──"  -ForegroundColor Cyan;    scoop search $pkg
            Write-Host "── winget ──" -ForegroundColor Blue;    winget search $pkg
            Write-Host "── choco (AUR) ──" -ForegroundColor Magenta; choco search $pkg
            return
        }
        '^-Syu$' {  # upgrade everything
            Write-Host "scoop update *..."  -ForegroundColor Cyan;  scoop update *
            Write-Host "winget upgrade --all..." -ForegroundColor Blue; winget upgrade --all --silent
            Write-Host "choco upgrade all..." -ForegroundColor Magenta; gsudo choco upgrade all -y
            return
        }
        '^-R$' {  # remove — try each
            scoop uninstall $pkg 2>$null; winget uninstall $pkg 2>$null; gsudo choco uninstall $pkg -y 2>$null
            return
        }
        default {  # install: -S <pkg>, or bare `yay <pkg>`
            $target = if ($op -eq '-S') { $pkg } else { $op }
            if (-not $target) { Write-Host "usage: yay <pkg> | -Ss <pkg> | -R <pkg> | -Syu"; return }
            Write-Host "trying scoop..." -ForegroundColor Cyan
            scoop install $target; if ($?) { return }
            Write-Host "scoop miss -> winget..." -ForegroundColor Blue
            winget install --id $target -e --accept-package-agreements --accept-source-agreements
            if ($?) { return }
            Write-Host "winget miss -> choco (AUR-tier)..." -ForegroundColor Magenta
            gsudo choco install $target -y
        }
    }
}

function pacman { yay @args }   # same wrapper, Arch muscle memory either name

# ~~~~~~~~~~~~~~~ Aliases (ported from dot_zshrc) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function v   { nvim @args }
function gp  { git pull @args }
function gs  { git status @args }
function lg  { lazygit @args }
# k / kgp: kubectl shortcuts. NOTE: `k` is defined later (lazy-loads completion).
function kgp { kubectl get pods @args }

# cat -> bat
if (Get-Command bat -ErrorAction SilentlyContinue) { function cat { bat @args } }

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
