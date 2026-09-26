[CmdletBinding()]
param(
    [string]$KodiRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

$settingsPath = Join-Path -Path $KodiRoot -ChildPath 'portable_data\userdata\guisettings.xml'
$settingsDirectory = Split-Path -Parent $settingsPath
$utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false

try {
    New-Item -ItemType Directory -Path $settingsDirectory -Force | Out-Null
} catch {
    exit 1
}

if (-not (Test-Path -LiteralPath $settingsPath)) {
    $newSettings = @(
        '<settings version="2">',
        '    <setting id="addons.unknownsources">true</setting>',
        '</settings>'
    ) -join [Environment]::NewLine

    try {
        [System.IO.File]::WriteAllText($settingsPath, $newSettings, $utf8NoBom)
        exit 0
    } catch {
        exit 1
    }
}

try {
    $settings = [System.IO.File]::ReadAllText($settingsPath)
} catch {
    exit 1
}

$unknownSources = [regex]::Match(
    $settings,
    '<setting\s+id="addons\.unknownsources"[^>]*>(?<value>[^<]*)</setting>'
)

if ($unknownSources.Success -and $unknownSources.Groups['value'].Value -match '^(?i:true|1)$') {
    exit 0
}

$updated = [regex]::Replace(
    $settings,
    '(<setting\s+id="addons\.unknownsources")[^>]*>[^<]*(</setting>)',
    '$1>true$2',
    1
)

if ($updated -eq $settings) {
    $updated = [regex]::Replace(
        $settings,
        '<setting\s+id="addons\.unknownsources"[^>]*/>',
        '<setting id="addons.unknownsources">true</setting>',
        1
    )
}

if ($updated -eq $settings -and $settings -notmatch '<setting\s+id="addons\.unknownsources"' -and $settings -match '</settings>') {
    $newline = if ($settings.Contains("`r`n")) { "`r`n" } else { "`n" }
    $newSetting = '    <setting id="addons.unknownsources">true</setting>' + $newline + '</settings>'
    $updated = $settings -replace '</settings>', $newSetting
}

if ($updated -ne $settings) {
    try {
        [System.IO.File]::WriteAllText($settingsPath, $updated, $utf8NoBom)
    } catch {
        exit 1
    }
}

exit 0
