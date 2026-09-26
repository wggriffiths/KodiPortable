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
        '    <setting id="locale.audiolanguage">English</setting>',
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
$audioLanguage = [regex]::Match(
    $settings,
    '<setting\s+id="locale\.audiolanguage"[^>]*>(?<value>[^<]*)</setting>'
)

if ($settings -match '<setting\s+id="locale\.audiolanguage">English</setting>') {
    exit 0
}

if ($audioLanguage.Success -and $audioLanguage.Groups['value'].Value -notmatch '^(?i:english|mediadefault|default)$') {
    exit 0
}

$updated = [regex]::Replace(
    $settings,
    '(<setting\s+id="locale\.audiolanguage")[^>]*>[^<]*(</setting>)',
    '$1>English$2',
    1
)

if ($updated -eq $settings) {
    $updated = [regex]::Replace(
        $settings,
        '<setting\s+id="locale\.audiolanguage"[^>]*/>',
        '<setting id="locale.audiolanguage">English</setting>',
        1
    )
}

if ($updated -eq $settings -and $settings -notmatch '<setting\s+id="locale\.audiolanguage"' -and $settings -match '</settings>') {
    $newline = if ($settings.Contains("`r`n")) { "`r`n" } else { "`n" }
    $updated = $settings -replace '</settings>', "    <setting id=""locale.audiolanguage"">English</setting>$newline</settings>"
}

if ($updated -ne $settings) {
    try {
        [System.IO.File]::WriteAllText($settingsPath, $updated, $utf8NoBom)
    } catch {
        exit 1
    }
}
