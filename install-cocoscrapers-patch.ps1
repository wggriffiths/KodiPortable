[CmdletBinding()]
param(
    [string]$KodiRoot,
    [switch]$DisableUnproductiveProviders
)

$ErrorActionPreference = 'Stop'

$scriptRoot = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    Split-Path -Path $MyInvocation.MyCommand.Path -Parent
} else {
    $PSScriptRoot
}

if ([string]::IsNullOrWhiteSpace($KodiRoot)) {
    $KodiRoot = Join-Path $scriptRoot 'kodi.app'
}

$patchRoot = Join-Path $scriptRoot 'cocoscrapers-patches\script.module.cocoscrapers'
$addonRoot = Join-Path $KodiRoot 'portable_data\addons\script.module.cocoscrapers'

if (-not (Test-Path -LiteralPath $patchRoot -PathType Container)) {
    throw "CocoScrapers patch files were not found: $patchRoot"
}

if (-not (Test-Path -LiteralPath $addonRoot -PathType Container)) {
    Write-Warning "CocoScrapers is not installed under $KodiRoot; skipping its patch."
    exit 0
}

$manifestPath = Join-Path $addonRoot 'addon.xml'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Write-Warning "CocoScrapers manifest was not found; skipping its patch."
    exit 0
}

[xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
$version = [string]$manifest.addon.version
if ($version -ne '1.0.32') {
    Write-Warning "CocoScrapers $version is installed; this patch targets 1.0.32, so it was skipped."
    exit 0
}

Get-ChildItem -LiteralPath $patchRoot -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($patchRoot.Length).TrimStart('\', '/')
    $destination = Join-Path $addonRoot $relative
    $destinationDirectory = Split-Path -Path $destination -Parent
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
}

# Keep the provider overlay small: append only the two new localized labels
# instead of replacing the complete language file from the installed addon.
$stringsPath = Join-Path $addonRoot 'resources\language\resource.language.en_gb\strings.po'
if (Test-Path -LiteralPath $stringsPath -PathType Leaf) {
    $stringsText = Get-Content -LiteralPath $stringsPath -Raw
    foreach ($label in @(
        @{Id = '32579'; Text = 'RUTOR (Pack capable)'},
        @{Id = '32580'; Text = 'SHOWRSS (Episodes only)'}
    )) {
        $marker = 'msgctxt "#' + $label.Id + '"'
        if (-not $stringsText.Contains($marker)) {
            $entry = "`r`n$marker`r`nmsgid `"$($label.Text)`"`r`nmsgstr `"`"`r`n"
            [System.IO.File]::AppendAllText($stringsPath, $entry, [System.Text.Encoding]::UTF8)
            $stringsText += $entry
        }
    }
}

if ($DisableUnproductiveProviders) {
    $settingsPath = Join-Path $KodiRoot 'portable_data\userdata\addon_data\script.module.cocoscrapers\settings.xml'
    if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
        [xml]$settings = Get-Content -LiteralPath $settingsPath -Raw
        foreach ($id in @('provider.bitsearch', 'provider.eztv', 'provider.torrentquest')) {
            $setting = $settings.settings.setting | Where-Object { $_.id -eq $id }
            if ($null -ne $setting) { $setting.InnerText = 'false' }
        }
        $settings.Save($settingsPath)
    }
}

Write-Output "Installed the CocoScrapers 1.0.32 performance and opt-in provider patch."
