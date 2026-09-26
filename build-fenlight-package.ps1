[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

$scriptRoot = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    Split-Path -Path $MyInvocation.MyCommand.Path -Parent
} else {
    $PSScriptRoot
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $scriptRoot 'fenlight-source\plugin.video.fenlight'
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $scriptRoot 'packages'
}

# Resolve caller-supplied paths before changing directory for 7-Zip. Relative
# output paths otherwise point inside the source tree while Push-Location is active.
$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

$sevenZip = Join-Path $scriptRoot 'bin\7z.exe'
$manifestPath = Join-Path $SourceRoot 'addon.xml'

if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "Fen Light source directory was not found: $SourceRoot"
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Fen Light addon.xml was not found: $manifestPath"
}

if (-not (Test-Path -LiteralPath $sevenZip -PathType Leaf)) {
    throw "7-Zip was not found: $sevenZip"
}

[xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
$addonId = [string]$manifest.addon.id
$addonVersion = [string]$manifest.addon.version

if ([string]::IsNullOrWhiteSpace($addonId) -or [string]::IsNullOrWhiteSpace($addonVersion)) {
    throw "Fen Light addon.xml does not contain an addon id and version."
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$packagePath = Join-Path $OutputDirectory "$addonId-private.zip"

if (Test-Path -LiteralPath $packagePath) {
    Remove-Item -LiteralPath $packagePath -Force
}

$sourceParent = Split-Path -Path $SourceRoot -Parent
$sourceFolder = Split-Path -Path $SourceRoot -Leaf

Push-Location $sourceParent
try {
    & $sevenZip a '-tzip' '-mx=9' $packagePath "$sourceFolder\*" '-xr!__pycache__' '-xr!*.pyc' '-xr!*.pyo'
    $sevenZipExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($sevenZipExitCode -gt 1) {
    throw "7-Zip failed while creating the Fen Light package (exit code $sevenZipExitCode)."
}

if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
    throw "7-Zip did not create the Fen Light package: $packagePath"
}

Write-Output "Created $packagePath (Fen Light $addonVersion)."
