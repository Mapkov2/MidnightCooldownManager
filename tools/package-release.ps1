[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$Version,
    [string]$OutputDir = "dist"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
$RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
if ([string]::IsNullOrWhiteSpace($Version)) {
    $versionPath = Join-Path $RepoRoot "VERSION"
    if (Test-Path -LiteralPath $versionPath -PathType Leaf) {
        $Version = (Get-Content -LiteralPath $versionPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1).Trim()
    }
}
if ([string]::IsNullOrWhiteSpace($Version)) {
    throw "Version is required. Pass -Version or create a VERSION file."
}

$addonDirs = @(
    "MidnightCooldownManager",
    "MidnightCooldownManager_Options"
)

foreach ($dir in $addonDirs) {
    $source = Join-Path $RepoRoot $dir
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        throw "Missing addon directory: $source"
    }
}

$outputFull = $OutputDir
if (-not [System.IO.Path]::IsPathRooted($outputFull)) {
    $outputFull = Join-Path $RepoRoot $outputFull
}
$outputFull = [System.IO.Path]::GetFullPath($outputFull)
New-Item -ItemType Directory -Force -Path $outputFull | Out-Null

$safeVersion = ($Version.Trim() -replace '[\\/:*?"<>|]', '-')
$safeVersion = ($safeVersion -replace '[^A-Za-z0-9._-]+', '-').Trim('-')
if ([string]::IsNullOrWhiteSpace($safeVersion)) {
    throw "Version produced an empty file-safe version."
}

$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mcdm-package-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null

try {
    foreach ($dir in $addonDirs) {
        Copy-Item -LiteralPath (Join-Path $RepoRoot $dir) -Destination $stageRoot -Recurse -Force
        $tocPath = Join-Path $stageRoot "$dir\$dir.toc"
        if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
            throw "Missing staged TOC: $tocPath"
        }

        $toc = Get-Content -LiteralPath $tocPath -Raw
        if ($toc -notmatch '(?m)^## Version:') {
            throw "No TOC version line found in $tocPath."
        }
        $toc = [regex]::Replace($toc, '(?m)^## Version:.*$', "## Version: $Version", 1)
        [System.IO.File]::WriteAllText($tocPath, $toc, [System.Text.UTF8Encoding]::new($false))
    }

    $zipPath = Join-Path $outputFull "MidnightCooldownManager-$safeVersion.zip"
    if (Test-Path -LiteralPath $zipPath -PathType Leaf) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Get-ChildItem -LiteralPath $stageRoot | Compress-Archive -DestinationPath $zipPath -Force

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $roots = $zip.Entries |
            Where-Object { $_.FullName -match '^[^\\/]+[\\/]' } |
            ForEach-Object { ($_.FullName -split '[\\/]')[0] } |
            Select-Object -Unique
        foreach ($expected in $addonDirs) {
            if ($expected -notin $roots) {
                throw "Package is missing root folder: $expected"
            }
        }
    } finally {
        $zip.Dispose()
    }

    Write-Host "Created $zipPath"
    return $zipPath
} finally {
    if (Test-Path -LiteralPath $stageRoot -PathType Container) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
    }
}
