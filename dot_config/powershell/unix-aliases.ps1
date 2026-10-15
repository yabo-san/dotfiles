# unix-aliases.ps1: Unix/mac commands PowerShell lacks, sourced by the profile. zsh-port aliases live there.

function open {
    if ($args.Count -eq 0) { Invoke-Item . } else { Invoke-Item @args }
}

function touch {
    foreach ($f in $args) {
        if (Test-Path $f) { (Get-Item $f).LastWriteTime = Get-Date }
        else { New-Item -ItemType File -Path $f | Out-Null }
    }
}

function which { (Get-Command $args[0] -ErrorAction SilentlyContinue).Source }

function pbcopy  { $input | Set-Clipboard }
function pbpaste { Get-Clipboard }

function export {
    foreach ($a in $args) {
        if ($a -match '^([^=]+)=(.*)$') { Set-Item "env:$($Matches[1])" $Matches[2] }
    }
}

if (Get-Command gsudo -ErrorAction SilentlyContinue) {
    function sudo { gsudo @args }
}

function mkcd { param($d) New-Item -ItemType Directory -Force -Path $d | Out-Null; Set-Location $d }

# reload: sources the tracked file directly; bare $PROFILE is CurrentUserCurrentHost, not the slot the bridge wires up.
function reload { . "$env:USERPROFILE\.config\powershell\Microsoft.PowerShell_profile.ps1" }

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

if (Get-Command rg -ErrorAction SilentlyContinue) { function grep { rg @args } }

# find -> fd: Windows find.exe reads file contents, which hydrates OneDrive cloud-only files; fd matches names only.
if (Get-Command fd -ErrorAction SilentlyContinue) { function find { fd @args } }

# wget -> curl (real wget isn't installed).
function wget { curl -L -O @args }

# uutils-coreutils is deliberately not installed: it shadows PowerShell's cp/mv/rm and surprises scripts.
