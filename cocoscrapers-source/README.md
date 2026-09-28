# Complete CocoScrapers source

This directory contains the complete CocoScrapers add-on source used to build
the private package installed by this repository.

- Add-on ID: `script.module.cocoscrapers`
- Current local version: `1.0.32.5`
- Package: `..\packages\script.module.cocoscrapers-private.zip`
- Changelog: `script.module.cocoscrapers\changelog.txt`

## This is the source of truth

Make CocoScrapers changes under:

`script.module.cocoscrapers\`

Do not make a change only in the live `kodi.app` copy. The normal installer
builds from this directory, not from `cocoscrapers-patches`.

## Local changes currently included

- The scraper worker pool uses bounded daemon workers so completed provider
  work does not leave non-daemon executor threads delaying Kodi shutdown.
- The PirateBay source has the `log_utils` import-scope fix needed on the
  successful scraping path.
- The local provider/source additions and related settings are part of this
  complete package.
- Release-name filtering honors Fen Light's preferred external-scraper source
  language when Fen Light is the caller. English is the default; Any Language
  and supported non-English choices are available in Fen Light's settings.
  CocoScrapers propagates that thread-local context into its nested provider
  workers, avoiding shared Kodi window state.

These changes are already included in the generated private package when it is
rebuilt.

The changelog starts with a marked `Private build 1.0.32.5` entry. Upstream
release history remains below it.

## Build

From the repository root:

```powershell
.\build-cocoscrapers-package.ps1
```

The builder reads `addon.xml`, creates
`packages\script.module.cocoscrapers-private.zip`, and excludes `__pycache__`,
`.pyc`, and `.pyo` files. `Install.bat` runs this builder before installing the
package during its CocoScrapers install flow.

## Legacy overlay

`..\cocoscrapers-patches\` is an older partial overlay retained for fallback
and reference. It is not a complete copy of this source and does not contain
every fix in this package. See its README before using the legacy script.
