[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KodiRoot,

    [Parameter(Mandatory = $true)]
    [string]$KodiCodename
)

$ErrorActionPreference = 'Stop'

$KodiRoot = [System.IO.Path]::GetFullPath($KodiRoot)
$scriptRoot = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    Split-Path -Path $MyInvocation.MyCommand.Path -Parent
} else {
    $PSScriptRoot
}

$addonRoot = Join-Path $KodiRoot 'portable_data\addons'
$packageRoot = Join-Path $addonRoot 'packages'
$sevenZip = Join-Path $scriptRoot 'bin\7z.exe'
$branch = $KodiCodename.Trim().ToLowerInvariant()

if ($branch -notin @('matrix', 'nexus', 'omega')) {
    throw "Kodi $KodiCodename is not supported by the private Fen Light/CocoScrapers packages. Use Matrix, Nexus, or Omega."
}

if (-not (Test-Path -LiteralPath $KodiRoot -PathType Container)) {
    throw "Kodi root was not found: $KodiRoot"
}

if (-not (Test-Path -LiteralPath $sevenZip -PathType Leaf)) {
    throw "7-Zip was not found: $sevenZip"
}

New-Item -ItemType Directory -Path $addonRoot -Force | Out-Null
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

# These are the official Kodi Python modules required by requests 2.31.0.
# The same versions are published for the Matrix, Nexus, and Omega branches.
$dependencies = @(
    @{ Id = 'script.module.certifi'; Version = '2023.5.7' },
    @{ Id = 'script.module.chardet'; Version = '5.1.0' },
    @{ Id = 'script.module.idna'; Version = '3.4.0' },
    @{ Id = 'script.module.urllib3'; Version = '1.26.16+matrix.1' },
    @{ Id = 'script.module.requests'; Version = '2.31.0' }
)

foreach ($dependency in $dependencies) {
    $id = $dependency.Id
    $version = $dependency.Version
    $zipName = "$id-$version.zip"
    $zipPath = Join-Path $packageRoot $zipName
    $addonPath = Join-Path $addonRoot $id
    $manifestPath = Join-Path $addonPath 'addon.xml'

    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
        $url = "https://mirrors.kodi.tv/addons/$branch/$id/$zipName"
        Write-Output "Downloading official Kodi dependency $zipName"
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zipPath
    }

    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        Write-Output "Installing official Kodi dependency $id $version"
        & $sevenZip x '-aoa' ("-o$addonRoot") $zipPath
        if ($LASTEXITCODE -gt 1) {
            throw "7-Zip failed while installing $zipName (exit code $LASTEXITCODE)."
        }
    } else {
        Write-Output "Official Kodi dependency already installed: $id"
    }
}

Write-Output 'Official Kodi Python dependencies are ready.'
