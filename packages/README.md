# Generated private packages

This directory holds the generated ZIPs that `Install.bat` installs into the
portable Kodi application. The ZIP files are intentionally ignored by Git;
this README is kept so the directory remains self-explanatory.

## Package map

| Package | Built from | Add-on version |
| --- | --- | --- |
| `script.module.cocoscrapers-private.zip` | `..\cocoscrapers-source\script.module.cocoscrapers` | `1.0.32.2` |
| `plugin.video.fenlight-private.zip` | `..\fenlight-source\plugin.video.fenlight` | `2.2.05.3` |

The ZIPs contain the integrated source changes and their corresponding
changelogs. They are not hand-edited: make changes in the source directories
and rebuild them.

## Rebuild commands

Run from the repository root:

```powershell
.\build-cocoscrapers-package.ps1
.\build-fenlight-package.ps1
```

Each builder replaces its corresponding ZIP. `Install.bat` invokes the
builders and then extracts the packages into `kodi.app` during the normal
install/rebuild flow.

If `kodi.app` is deleted, running `Install.bat` recreates the selected Kodi
installation and reinstalls these packages. Kodi profile data such as accounts,
credentials, databases, and settings still requires a separate backup.
