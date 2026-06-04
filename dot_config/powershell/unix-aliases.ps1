# unix-aliases.ps1 — Unix/mac muscle-memory commands that PowerShell lacks.
# Sourced by Microsoft.PowerShell_profile.ps1. Add reflexes here as you hit them.
# (zsh-port aliases like v/gp/gs/ls/cat live in the main profile; THIS file is
#  specifically the "the unix command doesn't exist on Windows" gap-fillers.)

# open — mac `open`: file→default app, dir→file manager, url→browser, none→cwd
function open {
    if ($args.Count -eq 0) { Invoke-Item . } else { Invoke-Item @args }
}

# touch — create empty file (or update timestamp if it exists)
function touch {
    foreach ($f in $args) {
        if (Test-Path $f) { (Get-Item $f).LastWriteTime = Get-Date }
        else { New-Item -ItemType File -Path $f | Out-Null }
    }
}

# which — show the path/source of a command (like unix `which`)
function which { (Get-Command $args[0] -ErrorAction SilentlyContinue).Source }

# pbcopy / pbpaste — mac clipboard. `echo hi | pbcopy`, `pbpaste`
function pbcopy  { $input | Set-Clipboard }
function pbpaste { Get-Clipboard }

# export NAME=value — unix env var setting (sets for this session)
function export {
    foreach ($a in $args) {
        if ($a -match '^([^=]+)=(.*)$') { Set-Item "env:$($Matches[1])" $Matches[2] }
    }
}

# sudo — map to gsudo (sudo-for-Windows). `sudo <cmd>`
if (Get-Command gsudo -ErrorAction SilentlyContinue) {
    function sudo { gsudo @args }
}

# mkcd — mkdir + cd into it (common unix one-liner)
function mkcd { param($d) New-Item -ItemType Directory -Force -Path $d | Out-Null; Set-Location $d }

# reload — re-source the profile (like `source ~/.zshrc`)
function reload { . $PROFILE }
