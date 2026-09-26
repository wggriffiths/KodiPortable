# Kodi Portable installation manual

This manual covers the two supported installation methods:

1. Install and maintain the complete portable Kodi build with `Install.bat`.
2. Install Fen Light and CocoScrapers from the Tinkerer Kodi Repository.

## Compatibility

The patched Fen Light and CocoScrapers packages require Kodi's Python 3
runtime. Use Kodi Matrix 19.x, Nexus 20.x, or Omega 21.x for these add-ons.
The installer can still download older Leia builds, but Fen Light and
CocoScrapers are not intended for Kodi Leia.

The current published versions are:

- Tinkerer Kodi Repository: `1.0.2`
- Fen Light: `2.2.05.3`
- CocoScrapers: `1.0.32.2`

## Method 1: local portable installation

### Before starting

- Extract or clone the project so that `Install.bat`, `bin`, the source
  folders, and the build scripts are in the same project root.
- The project root may contain spaces in its folder name (for example,
  `C:\Users\User\Desktop\Kodi Test\KodiPortable-main`).
- Keep an internet connection available while Kodi is downloaded.
- Close every Kodi process before rebuilding or installing an add-on package.
- If the existing Kodi profile matters, save it before rebuilding.

### First installation or rebuild

1. Run `Install.bat` from the project root.
2. Choose **1 - Rebuild** from the main menu.
3. Confirm the rebuild. This removes the current `kodi.app` installation.
4. Choose a Kodi codename and then the available Kodi version:
   - Omega
   - Nexus
   - Matrix
   - Leia (base Kodi only; not compatible with the patched add-ons)
5. If a portable-data backup is available, choose whether to restore it.
6. Allow the installer to download and extract Kodi.

The installer then applies the English preferred-audio setting, sets Fen
Light's default list view to **Media Info 3**, builds the complete Fen Light
and CocoScrapers packages, enables Kodi's **Unknown sources** setting for this
portable profile, installs the official Python dependencies required by the
packages, and installs them into the new portable profile. On the first Kodi
launch, a temporary Kodi service enables the two private add-ons silently and
then removes itself.

The temporary service runs inside Kodi's bundled Python runtime. Users do not
need to install Python on Windows, and `Install.bat` does not call a system
`python.exe`.

Start Kodi with the generated `kodi.app\start-kodi.bat` file, or choose
**2 - Open Kodi** from the installer menu.

### Main menu options

- **1 - Rebuild**: deletes and recreates the selected portable Kodi build.
- **2 - Open Kodi**: starts the current portable installation.
- **3 - Open Kodi (debug kodi.log)**: starts Kodi with the debug log view.
- **4 - Save Portable_data**: creates a portable-data backup in the project
  root. Use this before a rebuild if accounts and settings must be preserved.
- **6 - Build/install private Fen Light package**: rebuilds and installs both
  Fen Light and CocoScrapers.
- **7 - Build/install private CocoScrapers package**: rebuilds and installs
  CocoScrapers only.

Options 6 and 7 require Kodi to be closed. The installer warns and skips the
package installation if `kodi.exe` is still running. These options also prepare
the official Python dependencies and first-launch enable helper.

## Method 2: install from GitHub Pages

This method is useful for an existing clean Kodi installation. It does not
install Kodi itself; it installs the tracked add-ons through the repository.

### Install the Tinkerer repository

1. Download the repository ZIP:

   `https://wggriffiths.github.io/KodiPortable/repository.tinkerer-1.0.2.zip`

2. In Kodi, enable **Unknown sources** if Kodi asks for permission. This is
   still required for an existing clean Kodi profile because this method does
   not run `Install.bat` and the repository ZIP cannot change Kodi settings
   before it is installed.
3. Open **Add-ons â†’ Install from zip file**.
4. Select the downloaded `repository.tinkerer-1.0.2.zip` file.
5. Open **Add-ons â†’ Install from repository â†’ Tinkerer Kodi Repository**.

Fen Light and CocoScrapers can now be installed or updated from the same
repository. Kodi may install CocoScrapers as a dependency of Fen Light; it is
a scraper module rather than a normal video add-on.

The repository ZIP must be `1.0.2` or newer. Version `1.0.1` used a checksum
location that Kodi Nexus could reject with **Could not connect to repository**.

### Configure Fen Light to use CocoScrapers

On a clean Kodi profile, external scrapers are disabled by default:

1. Open Fen Light.
2. Open **Settings**.
3. Go to **Streaming Accounts â†’ External Scrapers**.
4. Turn **Enable** on.
5. Select **Choose External Scrapers Module**.
6. Select **CocoScrapers**.
7. Open **External Scraper Settings** and enable the providers you want.

If CocoScrapers is installed but does not appear in Fen Light, first check
that **External Scrapers â†’ Enable** is on. The module will not be selectable
while that setting is disabled.

## Preserving accounts and settings

The repository ZIPs contain add-on code and do not contain personal data.
Real-Debrid, Premiumize, Trakt, provider selections, Fen Light settings, and
other account data remain in Kodi's portable profile.

Before rebuilding, use **4 - Save Portable_data** in `Install.bat`. To restore
it, select the matching backup when the installer asks during the rebuild.
Only restore a backup made for the same Kodi codename when possible.

## Updating the add-ons

### From GitHub Pages

After a new package is published, restart Kodi or use **Check for updates** on
Tinkerer Kodi Repository. Kodi will only install an update when the add-on
manifest version is higher than the installed version.

### From the local project

1. Close Kodi completely.
2. Run `Install.bat`.
3. Choose **6** to rebuild and install both packages, or **7** for
   CocoScrapers only.
4. Start Kodi again and check the add-on versions under **My add-ons**.

## Troubleshooting

### â€œCould not connect to repositoryâ€

Install the current repository ZIP directly:

`https://wggriffiths.github.io/KodiPortable/repository.tinkerer-1.0.2.zip`

Then restart Kodi and open Tinkerer Kodi Repository again. Confirm that the
repository add-on is version `1.0.2` or newer.

### CocoScrapers is installed but Fen Light does not list it

Enable **Fen Light â†’ Settings â†’ Streaming Accounts â†’ External Scrapers â†’
Enable** first. Then use **Choose External Scrapers Module** and select
CocoScrapers.

### A package will not install

Close Kodi before using `Install.bat` to install a package. Also verify that
the selected Kodi version is Matrix, Nexus, or Omega and that the package is
not being installed into a different portable profile.

### Kodi hangs or crashes

Use **3 - Open Kodi (debug kodi.log)** in `Install.bat`, reproduce the issue,
and inspect `kodi.app\portable_data\kodi.log`. Do not patch the live
`kodi.app` directory; make source changes in the tracked source folders and
rebuild the package.

## Maintainer workflow

Make add-on changes in the complete source folders:

- `fenlight-source\plugin.video.fenlight`
- `cocoscrapers-source\script.module.cocoscrapers`

Update the relevant changelog and manifest version, run the package builders,
then run `build-kodi-repository.ps1` before publishing. Push the public
changes to the repository's `main` branch. The GitHub Actions workflow builds
and publishes the Kodi repository to GitHub Pages.

Do not commit credentials, Kodi profiles, logs, caches, `kodi.app`, or local
generated package ZIPs.
