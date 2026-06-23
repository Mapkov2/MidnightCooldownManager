[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,
    [string]$Version,
    [string]$ReleaseName,
    [string]$TocPath = "MidnightCooldownManager/MidnightCooldownManager.toc",
    [string]$ChangelogPath = "CHANGELOG.md",
    [string]$ProjectId = $env:CF_PROJECT_ID,
    [string]$GameVersionIds = $env:CF_GAME_VERSION_IDS,
    [string]$ApiToken = $env:CF_API_KEY,
    [string]$ReleaseType = $env:CF_RELEASE_TYPE,
    [string]$ApiBaseUrl = $env:CF_API_BASE_URL,
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

function Convert-GameVersionIds {
    param([Parameter(Mandatory = $true)][string]$RawIds)
    $ids = $RawIds -split '[,;\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        $value = 0
        if (-not [int]::TryParse($_.Trim(), [ref]$value)) {
            throw "Invalid CurseForge game version id '$($_)'."
        }
        $value
    }
    if (-not $ids) { throw "No CurseForge game version ids provided." }
    return @($ids)
}

function Get-CurseForgeReleaseType {
    param([Parameter(Mandatory = $true)][string]$ReleaseVersion, [Parameter(Mandatory = $true)][bool]$IsPrerelease)
    if ($ReleaseVersion -match '(?i)alpha') { return "alpha" }
    if ($IsPrerelease -or $ReleaseVersion -match '(?i)(beta|rc|pre)') { return "beta" }
    return "release"
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
    $ProjectId = Get-TocField -Content $tocContent -Name "X-Curse-Project-ID"
}
if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    throw "CF_PROJECT_ID is missing. Add it as a repository variable or TOC field."
}
if ($ProjectId -notmatch '^\d+$') {
    throw "CurseForge project id must be numeric. Got: $ProjectId"
}
if ([string]::IsNullOrWhiteSpace($GameVersionIds)) {
    throw "CF_GAME_VERSION_IDS is missing."
}
if ([string]::IsNullOrWhiteSpace($ReleaseType)) {
    $ReleaseType = Get-CurseForgeReleaseType -ReleaseVersion $Version -IsPrerelease $Prerelease.IsPresent
}
if ($ReleaseType -notin @("release", "beta", "alpha")) {
    throw "Invalid CurseForge release type '$ReleaseType'."
}
if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = "https://wow.curseforge.com"
}

$metadata = [ordered]@{
    changelog = Get-Content -LiteralPath $changelogFullPath -Raw
    changelogType = "markdown"
    displayName = $ReleaseName
    gameVersions = Convert-GameVersionIds -RawIds $GameVersionIds
    releaseType = $ReleaseType
} | ConvertTo-Json -Depth 5 -Compress

if ($DryRun) {
    Write-Host "Prepared CurseForge upload for project $ProjectId as $ReleaseName ($ReleaseType)."
    return
}
if ([string]::IsNullOrWhiteSpace($ApiToken)) {
    throw "CF_API_KEY is missing."
}

$headers = @{ "X-Api-Token" = $ApiToken; Accept = "application/json" }
$form = @{ metadata = $metadata; file = Get-Item -LiteralPath $zipFullPath }
Invoke-RestMethod -Method Post -Uri "$($ApiBaseUrl.TrimEnd('/'))/api/projects/$ProjectId/upload-file" -Headers $headers -Form $form | Out-Null
Write-Host "Uploaded $zipFullPath to CurseForge project $ProjectId."

