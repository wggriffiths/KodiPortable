# Legacy CocoScrapers overlay

This directory contains the older, partial CocoScrapers overlay used by
`install-cocoscrapers-patch.ps1` as a fallback for an installed CocoScrapers
`1.0.32` add-on.

It is **not** the normal installation path. The normal `Install.bat` flow now
builds and installs the complete source from:

`..\cocoscrapers-source\script.module.cocoscrapers\`

## What is in this overlay

The overlay contains selected worker/client changes and provider modules,
including the daemon-worker shutdown fix and the locally added provider files.
It is intentionally smaller than the complete CocoScrapers source tree.

## Important limitation

This overlay is not automatically kept equivalent to the complete source. In
particular, it does not contain the newer PirateBay `log_utils` fix that is
already present in the complete source and in
`packages\script.module.cocoscrapers-private.zip`.

Do not use this directory to decide what the current package contains. Use
`..\cocoscrapers-source\` and rebuild the private ZIP instead.

## Legacy use

The fallback script can be run from the repository root when deliberately
targeting an installed CocoScrapers `1.0.32` add-on:

```powershell
.\install-cocoscrapers-patch.ps1
```

It checks the installed version before copying files. Test the result and
inspect the Kodi log after using it. Any future fallback-only change must be
documented here and separately compared with the complete source.
