[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,
    [string]$Version,
    [string]$ReleaseName,
    [string]$TocPath = "MidnightCooldownManager/MidnightCooldownManager.toc",
    [string]$ChangelogPath = "CHANGELOG.md",
    [string]$ProjectId = $env:WAGO_PROJECT_ID,
    [string]$ApiToken = $env:WAGO_API_TOKEN,
    [string]$Stability = $env:WAGO_STABILITY,
    [string]$RetailPatch = $env:WAGO_RETAIL_PATCH,
    [switch]$Prerelease,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

function Resolve-InRepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $candidate = $Path
    if (-not [System.IO.Path]::IsPathRooted($candidate)) {
        $candidate = Join-Path $RepoRoot $candidate
    }
    $full = [System.IO.Path]::GetFullPath($candidate)
    $root = $RepoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    if (-not ($full.Equals($root, [System.StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($root + [System.IO.Path]::AltDirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Refusing path outside repository: $full"
    }
    return $full
}

function Get-TocField {
    param([Parameter(Mandatory = $true)][string]$Content, [Parameter(Mandatory = $true)][string]$Name)
    $match = [regex]::Match($Content, "(?m)^##\s+$([regex]::Escape($Name)):\s*(.+?)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return $null
}

function Convert-RetailInterfaceToPatch {
    param([Parameter(Mandatory = $true)][int]$Interface)
    $major = [math]::Floor($Interface / 10000)
    $minor = [math]::Floor(($Interface % 10000) / 100)
    $patch = $Interface % 100
    return "$major.$minor.$patch"
}

function Get-Stability {
    param([Parameter(Mandatory = $true)][string]$ReleaseVersion, [Parameter(Mandatory = $true)][bool]$IsPrerelease)
    if ($ReleaseVersion -match '(?i)alpha') { return "alpha" }
    if ($IsPrerelease -or $ReleaseVersion -match '(?i)(beta|rc|pre)') { return "beta" }
    return "stable"
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $versionPath = Join-Path $RepoRoot "VERSION"
    $Version = (Get-Content -LiteralPath $versionPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1).Trim()
}
$Version = ($Version -replace '^refs/tags/', '') -replace '^v(?=\d)', ''
if ([string]::IsNullOrWhiteSpace($ReleaseName)) {
    $ReleaseName = "Midnight Simple Cooldown $Version"
}

$zipFullPath = Resolve-InRepoPath -Path $ZipPath
$tocFullPath = Resolve-InRepoPath -Path $TocPath
$changelogFullPath = Resolve-InRepoPath -Path $ChangelogPath
if (-not (Test-Path -LiteralPath $zipFullPath -PathType Leaf)) { throw "Release zip not found: $zipFullPath" }
if (-not (Test-Path -LiteralPath $tocFullPath -PathType Leaf)) { throw "TOC not found: $tocFullPath" }
if (-not (Test-Path -LiteralPath $changelogFullPath -PathType Leaf)) { throw "Changelog not found: $changelogFullPath" }

$tocContent = Get-Content -LiteralPath $tocFullPath -Raw
if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    $ProjectId = Get-TocField -Content $tocContent -Name "X-Wago-ID"
}
if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    throw "No Wago project id found. Set WAGO_PROJECT_ID or add ## X-Wago-ID to the TOC."
}

if ([string]::IsNullOrWhiteSpace($RetailPatch)) {
    $interfaceField = Get-TocField -Content $tocContent -Name "Interface"
    $interfaces = $interfaceField -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    if (-not $interfaces) { throw "No numeric Interface found. Set WAGO_RETAIL_PATCH explicitly." }
    $RetailPatch = Convert-RetailInterfaceToPatch -Interface (($interfaces | Measure-Object -Maximum).Maximum)
}
if ([string]::IsNullOrWhiteSpace($Stability)) {
    $Stability = Get-Stability -ReleaseVersion $Version -IsPrerelease $Prerelease.IsPresent
}
if ($Stability -notin @("stable", "beta", "alpha")) {
    throw "Invalid Wago stability '$Stability'."
}

$metadata = [ordered]@{
    label = $ReleaseName
    stability = $Stability
    changelog = Get-Content -LiteralPath $changelogFullPath -Raw
    supported_retail_patch = $RetailPatch
} | ConvertTo-Json -Depth 5 -Compress

if ($DryRun) {
    Write-Host "Prepared Wago upload for project $ProjectId as $ReleaseName ($Stability, retail $RetailPatch)."
    return
}
if ([string]::IsNullOrWhiteSpace($ApiToken)) {
    throw "WAGO_API_TOKEN is missing."
}

$headers = @{ Authorization = "Bearer $ApiToken"; Accept = "application/json" }
$form = @{ metadata = $metadata; file = Get-Item -LiteralPath $zipFullPath }
Invoke-RestMethod -Method Post -Uri "https://addons.wago.io/api/projects/$ProjectId/version" -Headers $headers -Form $form | Out-Null
Write-Host "Uploaded $zipFullPath to Wago project $ProjectId."

