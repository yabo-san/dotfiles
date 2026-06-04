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

# head — first N lines. `head file`, `head -n 5 file`, `head -5 file`, `... | head`
function head {
    $n = 10; $files = @()
    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -eq '-n') { $n = [int]$args[++$i] }
        elseif ($args[$i] -match '^-(\d+)$') { $n = [int]$Matches[1] }
        else { $files += $args[$i] }
    }
    if ($files) { $files | ForEach-Object { Get-Content $_ -TotalCount $n } }
    else { $input | Select-Object -First $n }
}

# tail — last N lines. `tail file`, `tail -n 5 file`, `tail -f file` (follow)
function tail {
    $n = 10; $follow = $false; $files = @()
    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -eq '-n') { $n = [int]$args[++$i] }
        elseif ($args[$i] -match '^-(\d+)$') { $n = [int]$Matches[1] }
        elseif ($args[$i] -eq '-f') { $follow = $true }
        else { $files += $args[$i] }
    }
    if ($files) {
        if ($follow) { Get-Content $files[0] -Tail $n -Wait }
        else { $files | ForEach-Object { Get-Content $_ -Tail $n } }
    } else { $input | Select-Object -Last $n }
}

# wc — count. `wc -l file` (lines), `-w` (words), `-c` (chars), `... | wc -l`
function wc {
    $mode = $null; $files = @()
    foreach ($a in $args) {
        switch ($a) { '-l' { $mode = 'l' } '-w' { $mode = 'w' } '-c' { $mode = 'c' } default { $files += $a } }
    }
    $content = if ($files) { Get-Content $files } else { $input }
    $arr = @($content)
    $text = $arr -join "`n"
    $lines = $arr.Count
    $words = ($text -split '\s+' | Where-Object { $_ }).Count
    $chars = $text.Length
    switch ($mode) { 'l' { $lines } 'w' { $words } 'c' { $chars } default { "$lines $words $chars" } }
}

# grep → ripgrep. rg's flags mostly superset grep; recursive + gitignore-aware
# by default. (find stays as Windows find.exe; use `fd` for unix-style find.)
if (Get-Command rg -ErrorAction SilentlyContinue) { function grep { rg @args } }

# wget → curl-based download (real wget isn't installed). `wget <url>` saves the
# file to cwd, like wget's default. For full wget, `scoop install wget`.
function wget { curl -L -O @args }

# ─────────────────────────────────────────────────────────────────────────────
# NOTE: for FULL real GNU coreutils (proper `rm -rf`, `cp -a`, `ls --color`, the
# exact unix flag set), install uutils-coreutils:  scoop install uutils-coreutils
# It's a Rust reimplementation of GNU coreutils. We did NOT install it because it
# can shadow PowerShell's built-in cp/mv/rm aliases and surprise scripts that
# expect PowerShell semantics. These hand-written functions cover the common gaps
# (head/tail/wc/touch/which/open) without that risk. If you want the real thing,
# install it and these functions can be removed.
# ─────────────────────────────────────────────────────────────────────────────
