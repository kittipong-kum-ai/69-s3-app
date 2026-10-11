#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Build the Strapi app into a Docker image and push it to a container registry (default: GitHub Container Registry).

.EXAMPLE
  ./scripts/docker-publish.ps1
  $env:CR_PAT = "ghp_xxx"; ./scripts/docker-publish.ps1 -Tag 1.0.0
  ./scripts/docker-publish.ps1 -NoPush          # build only
#>
[CmdletBinding()]
param(
    [string]$Registry = "ghcr.io",
    [string]$Owner = "kittipong-kum-ai",
    [string]$Name = "",
    [string]$Tag = "",
    [string]$User = "",
    [string]$Token = $env:CR_PAT,
    [switch]$NoLatest,
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "docker was not found in PATH"
}

$root = Split-Path -Parent $PSScriptRoot
$pkgPath = Join-Path $root "package.json"
$pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($Name)) { $Name = Split-Path -Leaf $root }
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = $pkg.version }
if ([string]::IsNullOrWhiteSpace($User)) { $User = $Owner }

# GHCR requires the repository path to be lowercase
$imageBase = ("{0}/{1}/{2}" -f $Registry, $Owner, $Name).ToLower()
$tags = @("${imageBase}:${Tag}")
if (-not $NoLatest -and $Tag -ne "latest") { $tags += "${imageBase}:latest" }

$dockerfile = Join-Path $root "Dockerfile"
if (-not (Test-Path $dockerfile)) { throw "Dockerfile not found at $dockerfile" }

$buildArgs = @("build", "-f", $dockerfile)
foreach ($t in $tags) { $buildArgs += @("-t", $t) }
$buildArgs += $root

Write-Step "Building: $($tags -join ', ')"
& docker @buildArgs
if ($LASTEXITCODE -ne 0) { throw "docker build failed" }

if ($NoPush) {
    Write-Step "Skipping push (-NoPush)"
    return
}

if (-not [string]::IsNullOrWhiteSpace($Token)) {
    Write-Step "Logging in to $Registry as $User"
    $Token | docker login $Registry -u $User --password-stdin
    if ($LASTEXITCODE -ne 0) { throw "docker login failed" }
}
else {
    Write-Step "No token supplied; assuming an existing session for $Registry"
}

foreach ($t in $tags) {
    Write-Step "Pushing $t"
    docker push $t
    if ($LASTEXITCODE -ne 0) { throw "docker push failed for $t" }
}

Write-Step "Done:"
$tags | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
