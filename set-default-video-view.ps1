[CmdletBinding()]
param(
    [string]$KodiRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

# Confluence's Media Info 3 view is view id 515. Fen Light applies these
# settings when it opens movie, TV-show, season, and episode containers.
$viewId = '515'
$settingIds = @(
    'view.movies',
    'view.tvshows',
    'view.seasons',
    'view.episodes',
    'view.episodes_single'
)

$databasePath = Join-Path -Path $KodiRoot -ChildPath 'portable_data\userdata\addon_data\plugin.video.fenlight\databases\settings.db'
$sqlitePath = Join-Path -Path $KodiRoot -ChildPath 'sqlite3.dll'

# Fen Light may not be installed in a base Kodi build yet. That is not an
# installer error; the same helper can be run after a Fen Light pack is added.
if (-not (Test-Path -LiteralPath $databasePath)) {
    exit 0
}

if (-not (Test-Path -LiteralPath $sqlitePath)) {
    exit 1
}

$addonProfilePath = Split-Path -Parent (Split-Path -Parent $databasePath)
$backupPath = Join-Path -Path $addonProfilePath -ChildPath 'settings.db.media-info3.bak'
$database = [IntPtr]::Zero
$exitCode = 0

try {
    if (-not (Test-Path -LiteralPath $backupPath)) {
        Copy-Item -LiteralPath $databasePath -Destination $backupPath -ErrorAction Stop
    }

    $dllPathForCSharp = $sqlitePath.Replace('\', '\\').Replace('"', '\"')
    $nativeSource = @"
using System;
using System.Runtime.InteropServices;

public static class KodiPortableSqliteNative
{
    [DllImport("$dllPathForCSharp", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    public static extern int sqlite3_open([MarshalAs(UnmanagedType.LPStr)] string filename, out IntPtr database);

    [DllImport("$dllPathForCSharp", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    public static extern int sqlite3_exec(
        IntPtr database,
        [MarshalAs(UnmanagedType.LPStr)] string sql,
        IntPtr callback,
        IntPtr argument,
        out IntPtr errorMessage);

    [DllImport("$dllPathForCSharp", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr sqlite3_errmsg(IntPtr database);

    [DllImport("$dllPathForCSharp", CallingConvention = CallingConvention.Cdecl)]
    public static extern void sqlite3_free(IntPtr memory);

    [DllImport("$dllPathForCSharp", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_close(IntPtr database);
}
"@
    Add-Type -TypeDefinition $nativeSource -ErrorAction Stop

    $openResult = [KodiPortableSqliteNative]::sqlite3_open($databasePath, [ref]$database)
    if ($openResult -ne 0) {
        $message = if ($database -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::PtrToStringAnsi([KodiPortableSqliteNative]::sqlite3_errmsg($database))
        } else {
            'Could not open Fen Light settings database.'
        }
        throw $message
    }

    $quotedIds = ($settingIds | ForEach-Object { "'$_'" }) -join ', '
    $sql = @"
BEGIN IMMEDIATE;
UPDATE settings
SET setting_default = '$viewId',
    setting_value = CASE
        WHEN setting_value IN ('500', '55') THEN '$viewId'
        ELSE setting_value
    END
WHERE setting_id IN ($quotedIds);
COMMIT;
"@

    $errorMessage = [IntPtr]::Zero
    $execResult = [KodiPortableSqliteNative]::sqlite3_exec(
        $database,
        $sql,
        [IntPtr]::Zero,
        [IntPtr]::Zero,
        [ref]$errorMessage
    )
    if ($execResult -ne 0) {
        $message = if ($errorMessage -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::PtrToStringAnsi($errorMessage)
        } else {
            [Runtime.InteropServices.Marshal]::PtrToStringAnsi([KodiPortableSqliteNative]::sqlite3_errmsg($database))
        }
        if ($errorMessage -ne [IntPtr]::Zero) {
            [KodiPortableSqliteNative]::sqlite3_free($errorMessage)
        }
        throw $message
    }
} catch {
    Write-Verbose $_.Exception.Message
    $exitCode = 1
} finally {
    if ($database -ne [IntPtr]::Zero) {
        [KodiPortableSqliteNative]::sqlite3_close($database) | Out-Null
    }
}

exit $exitCode
