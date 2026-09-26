[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KodiRoot,

    [ValidateSet('both', 'fenlight', 'cocoscrapers')]
    [string]$Targets = 'both'
)

$ErrorActionPreference = 'Stop'

$KodiRoot = [System.IO.Path]::GetFullPath($KodiRoot)
$scriptRoot = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    Split-Path -Path $MyInvocation.MyCommand.Path -Parent
} else {
    $PSScriptRoot
}

$sourceRoot = Join-Path $scriptRoot 'installer-bootstrap\service.tinkerer.bootstrap'
$addonRoot = Join-Path $KodiRoot 'portable_data\addons'
$destinationRoot = Join-Path $addonRoot 'service.tinkerer.bootstrap'
$manifestPath = Join-Path $KodiRoot 'system\addon-manifest.xml'
$targetFile = Join-Path $destinationRoot 'targets.txt'

if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Bootstrap source was not found: $sourceRoot"
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Kodi add-on manifest was not found: $manifestPath"
}

New-Item -ItemType Directory -Path $addonRoot -Force | Out-Null
New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
Copy-Item -Path (Join-Path $sourceRoot '*') -Destination $destinationRoot -Recurse -Force

$targetAddons = switch ($Targets) {
    'fenlight' { @('plugin.video.fenlight') }
    'cocoscrapers' { @('script.module.cocoscrapers') }
    default { @('plugin.video.fenlight', 'script.module.cocoscrapers') }
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($targetFile, $targetAddons, $utf8NoBom)

$manifest = [System.IO.File]::ReadAllText($manifestPath)
$bootstrapId = 'service.tinkerer.bootstrap'
if ($manifest -notmatch [regex]::Escape($bootstrapId)) {
    $entry = '  <addon optional="true">' + $bootstrapId + '</addon>'
    $updated = [regex]::Replace($manifest, '</addons>', "$entry`r`n</addons>", 1)
    if ($updated -eq $manifest) {
        throw "Kodi add-on manifest has no closing addons element: $manifestPath"
    }

    [System.IO.File]::WriteAllText($manifestPath, $updated, $utf8NoBom)
}

Write-Output 'Installed the one-time private add-on bootstrap.'
