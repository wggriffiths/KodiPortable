[CmdletBinding()]
param(
    [string]$RepositoryOutputDirectory
)

$ErrorActionPreference = 'Stop'

$scriptRoot = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    Split-Path -Path $MyInvocation.MyCommand.Path -Parent
} else {
    $PSScriptRoot
}

if ([string]::IsNullOrWhiteSpace($RepositoryOutputDirectory)) {
    $RepositoryOutputDirectory = Join-Path $scriptRoot 'kodi-repo'
}

$RepositoryOutputDirectory = [System.IO.Path]::GetFullPath($RepositoryOutputDirectory)
$packageDirectory = [System.IO.Path]::GetFullPath((Join-Path $scriptRoot 'packages'))
$sevenZip = Join-Path $scriptRoot 'bin\7z.exe'
$repositorySource = Join-Path $scriptRoot 'repository.tinkerer'
$repositoryManifestPath = Join-Path $repositorySource 'addon.xml'

if (-not (Test-Path -LiteralPath $sevenZip -PathType Leaf)) {
    throw "7-Zip was not found: $sevenZip"
}

if (-not (Test-Path -LiteralPath $repositoryManifestPath -PathType Leaf)) {
    throw "Repository add-on manifest was not found: $repositoryManifestPath"
}

# Always rebuild the source packages so the repository cannot publish stale ZIPs.
& (Join-Path $scriptRoot 'build-fenlight-package.ps1') -OutputDirectory $packageDirectory
if ($LASTEXITCODE -gt 1) {
    throw "Fen Light package build failed."
}

& (Join-Path $scriptRoot 'build-cocoscrapers-package.ps1') -OutputDirectory $packageDirectory
if ($LASTEXITCODE -gt 1) {
    throw "CocoScrapers package build failed."
}

function Read-AddonManifest {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Add-on manifest was not found: $Path"
    }

    [xml]$manifest = Get-Content -LiteralPath $Path -Raw
    $id = [string]$manifest.addon.id
    $version = [string]$manifest.addon.version

    if ([string]::IsNullOrWhiteSpace($id) -or [string]::IsNullOrWhiteSpace($version)) {
        throw "Manifest does not contain an add-on id and version: $Path"
    }

    return $manifest
}

function Add-VersionedPackage {
    param(
        [Parameter(Mandatory = $true)][string]$AddonId,
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$SourcePackage,
        [Parameter(Mandatory = $true)][string]$OutputRoot
    )

    if (-not (Test-Path -LiteralPath $SourcePackage -PathType Leaf)) {
        throw "Source package was not found: $SourcePackage"
    }

    $targetDirectory = Join-Path $OutputRoot (Join-Path 'zips' $AddonId)
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    $targetPackage = Join-Path $targetDirectory "$AddonId-$Version.zip"
    Copy-Item -LiteralPath $SourcePackage -Destination $targetPackage -Force
    Write-Output "Published $targetPackage"
}

$fenManifestPath = Join-Path $scriptRoot 'fenlight-source\plugin.video.fenlight\addon.xml'
$cocoManifestPath = Join-Path $scriptRoot 'cocoscrapers-source\script.module.cocoscrapers\addon.xml'
$fenManifest = Read-AddonManifest -Path $fenManifestPath
$cocoManifest = Read-AddonManifest -Path $cocoManifestPath
$repositoryManifest = Read-AddonManifest -Path $repositoryManifestPath

New-Item -ItemType Directory -Path $RepositoryOutputDirectory -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $RepositoryOutputDirectory 'zips') -Force | Out-Null

Add-VersionedPackage -AddonId ([string]$fenManifest.addon.id) -Version ([string]$fenManifest.addon.version) `
    -SourcePackage (Join-Path $packageDirectory 'plugin.video.fenlight-private.zip') -OutputRoot $RepositoryOutputDirectory
Add-VersionedPackage -AddonId ([string]$cocoManifest.addon.id) -Version ([string]$cocoManifest.addon.version) `
    -SourcePackage (Join-Path $packageDirectory 'script.module.cocoscrapers-private.zip') -OutputRoot $RepositoryOutputDirectory

# Package the repository add-on itself with its required root folder.
$repositoryZipDirectory = Join-Path $RepositoryOutputDirectory ('zips\' + [string]$repositoryManifest.addon.id)
New-Item -ItemType Directory -Path $repositoryZipDirectory -Force | Out-Null
$repositoryZip = Join-Path $repositoryZipDirectory (([string]$repositoryManifest.addon.id) + '-' + ([string]$repositoryManifest.addon.version) + '.zip')
if (Test-Path -LiteralPath $repositoryZip) {
    Remove-Item -LiteralPath $repositoryZip -Force
}

$repositoryParent = Split-Path -Path $repositorySource -Parent
$repositoryFolder = Split-Path -Path $repositorySource -Leaf
Push-Location $repositoryParent
try {
    & $sevenZip a '-tzip' '-mx=9' $repositoryZip "$repositoryFolder\*"
    $sevenZipExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($sevenZipExitCode -gt 1) {
    throw "7-Zip failed while creating the repository package (exit code $sevenZipExitCode)."
}

# Keep a root-level copy for the first Kodi installation, matching the usual
# GitHub Pages repository layout used by other Kodi repositories.
$rootRepositoryZip = Join-Path $RepositoryOutputDirectory (([string]$repositoryManifest.addon.id) + '-' + ([string]$repositoryManifest.addon.version) + '.zip')
Copy-Item -LiteralPath $repositoryZip -Destination $rootRepositoryZip -Force
Write-Output "Published $rootRepositoryZip"

# Build the master index from the exact manifests that are being published.
$addonsDocument = New-Object System.Xml.XmlDocument
$declaration = $addonsDocument.CreateXmlDeclaration('1.0', 'UTF-8', 'yes')
$null = $addonsDocument.AppendChild($declaration)
$addonsRoot = $addonsDocument.CreateElement('addons')
$null = $addonsDocument.AppendChild($addonsRoot)

foreach ($manifest in @($repositoryManifest, $fenManifest, $cocoManifest)) {
    $null = $addonsRoot.AppendChild($addonsDocument.ImportNode($manifest.DocumentElement, $true))
}

$addonsXmlPath = Join-Path $RepositoryOutputDirectory 'addons.xml'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$repositoryPackageName = ([string]$repositoryManifest.addon.id) + '-' + ([string]$repositoryManifest.addon.version) + '.zip'
$indexHtmlPath = Join-Path $RepositoryOutputDirectory 'index.html'
$indexHtml = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Tinkerer Kodi Repository</title>
</head>
<body>
  <h1>Tinkerer Kodi Repository</h1>
  <p>Install this repository in Kodi:</p>
  <p><a href="$repositoryPackageName">$repositoryPackageName</a></p>
</body>
</html>
"@
[System.IO.File]::WriteAllText($indexHtmlPath, $indexHtml, $utf8NoBom)

$writerSettings = New-Object System.Xml.XmlWriterSettings
$writerSettings.Indent = $true
$writerSettings.Encoding = $utf8NoBom
$writer = [System.Xml.XmlWriter]::Create($addonsXmlPath, $writerSettings)
try {
    $addonsDocument.Save($writer)
}
finally {
    $writer.Dispose()
}

$md5 = [System.Security.Cryptography.MD5]::Create()
try {
    $digest = $md5.ComputeHash([System.IO.File]::ReadAllBytes($addonsXmlPath))
}
finally {
    $md5.Dispose()
}

$checksum = -join ($digest | ForEach-Object { $_.ToString('x2') })
$checksumPath = Join-Path $RepositoryOutputDirectory 'addons.xml.md5'
[System.IO.File]::WriteAllText($checksumPath, "$checksum`r`n", $utf8NoBom)

Write-Output "Created $addonsXmlPath"
Write-Output "Created $checksumPath"
