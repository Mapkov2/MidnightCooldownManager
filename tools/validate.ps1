[CmdletBinding()]
param(
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
$RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
$addonDirs = @(
    "MidnightCooldownManager",
    "MidnightCooldownManager_Options"
)

function Fail {
    param([Parameter(Mandatory = $true)][string]$Message)
    throw "[validate] $Message"
}

foreach ($dir in $addonDirs) {
    $fullDir = Join-Path $RepoRoot $dir
    if (-not (Test-Path -LiteralPath $fullDir -PathType Container)) {
        Fail "Missing addon directory: $dir"
    }

    $tocPath = Join-Path $fullDir "$dir.toc"
    if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
        Fail "Missing TOC: $tocPath"
    }

    $toc = Get-Content -LiteralPath $tocPath -Raw
    if ($toc -notmatch '(?m)^## Interface:\s*120000\s*$') {
        Fail "$dir must use ## Interface: 120000"
    }
    if ($toc -notmatch '(?m)^## Version:\s*\S') {
        Fail "$dir has no TOC version"
    }

    $lines = Get-Content -LiteralPath $tocPath
    foreach ($line in $lines) {
        $value = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }
        if ($value.StartsWith("#")) {
            continue
        }

        $relative = $value -replace '/', [System.IO.Path]::DirectorySeparatorChar
        $target = Join-Path $fullDir $relative
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            Fail "$dir TOC references missing file: $value"
        }
    }
}

$addonRoots = $addonDirs | ForEach-Object { Join-Path $RepoRoot $_ }
$badHardLink = $addonRoots |
    ForEach-Object { Get-ChildItem -LiteralPath $_ -Recurse -File -Include *.lua,*.toc } |
    Select-String -SimpleMatch "Interface\AddOns\MidnightSimpleUnitFrames" |
    Select-Object -First 1
if ($badHardLink) {
    Fail "Found hard dependency on MidnightSimpleUnitFrames in $($badHardLink.Path):$($badHardLink.LineNumber)"
}

$luac = Get-Command luac -ErrorAction SilentlyContinue
if (-not $luac) {
    $luac = Get-Command luac5.1 -ErrorAction SilentlyContinue
}

if ($luac) {
    $luaFiles = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Filter *.lua |
        Where-Object { $_.FullName -notmatch '\\(dist|_backups|_release-stage)\\' }
    foreach ($file in $luaFiles) {
        & $luac.Source -p $file.FullName
        if ($LASTEXITCODE -ne 0) {
            Fail "luac failed: $($file.FullName)"
        }
    }
    Write-Host "[validate] luac ok ($($luaFiles.Count) files)"
} else {
    Write-Warning "[validate] luac/luac5.1 not found; skipped Lua syntax check."
}

Write-Host "[validate] repository structure ok"
