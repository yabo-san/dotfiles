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

# ~~~~~~~~~~~~~~~ Prompt (dot_zshrc: Pure) → starship Pure preset ~~~~~~~~~~~~~
# Identity "yabo" regardless of OS account name. Pure-style minimal prompt.
$env:STARSHIP_CONFIG = "$env:USERPROFILE\.config\starship.toml"
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
