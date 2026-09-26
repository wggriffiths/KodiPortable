# Private Fen Light source

This directory contains the complete Fen Light add-on source used by the
private package installed by this repository.

- Add-on ID: `plugin.video.fenlight`
- Current local version: `2.2.05.5`
- Package: `..\packages\plugin.video.fenlight-private.zip`
- Changelog: `plugin.video.fenlight\resources\text\changelog.txt`

## This is the source of truth

Fen Light changes are integrated directly under:

`plugin.video.fenlight\`

There is no separate Fen Light patch overlay. Do not patch only the live
`kodi.app` copy or the generated ZIP.

## Local changes currently included

The fork contains the local language/audio behavior, Fanart view defaults,
playback and shutdown hardening, and the disabled upstream updater. The
Premiumize-specific behavior was left outside the requested changes.

The source manifest uses `2.2.05.5`, incrementing the upstream `2.2.05`
version for this private patch release. The private package name also
distinguishes this locally built package from an upstream download.

New private profiles automatically select the paired CocoScrapers module for
Fen Light. Existing external-scraper selections are preserved. Fen metadata
changes are applied on the next Kodi launch instead of hot-restarting the
add-on service, and background skin/Trakt work checks Kodi's abort state.

The changelog begins with a marked private-build entry, followed by the
upstream Fen Light release history.

## Build

From the repository root:

```powershell
.\build-fenlight-package.ps1
```

The builder reads `addon.xml`, creates
`packages\plugin.video.fenlight-private.zip`, and excludes Python cache files.
`Install.bat` runs this builder before installing the package during its Fen
Light install flow.

User accounts, debrid credentials, databases, caches, logs, and Kodi profile
settings are not stored in this source tree. Preserve those separately with a
portable-data backup if required.
