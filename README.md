# Kodi Portable build

This repository contains the Windows portable Kodi installer, its private
add-on sources, and the generated packages installed by the setup.

Read these files first:

- [AGENTS.md](AGENTS.md) — source-of-truth rules and change workflow.
- [cocoscrapers-source/README.md](cocoscrapers-source/README.md) — complete
  CocoScrapers package source.
- [cocoscrapers-patches/README.md](cocoscrapers-patches/README.md) — legacy
  partial overlay and limitations.
- [fenlight-source/README.md](fenlight-source/README.md) — complete Fen Light
  fork source.
- [packages/README.md](packages/README.md) — generated package map.

The normal `Install.bat` path builds from the complete source directories and
installs the ZIPs in `packages`. It does not use the legacy
`cocoscrapers-patches` overlay.

## Public Kodi repository

This project also publishes a Kodi repository through GitHub Pages at:

`https://wggriffiths.github.io/KodiPortable/`

Run `build-kodi-repository.ps1` after source changes. It rebuilds the tracked
Fen Light and CocoScrapers packages, creates the `repository.tinkerer` ZIP,
and regenerates the Kodi repository index and checksum. The GitHub Actions
workflow repeats this build and commits the generated `kodi-repo` output when
changes are pushed to `main`.

Install `kodi-repo\repository.tinkerer-1.0.1.zip`
once in Kodi with **Install from zip file**. Later add-on versions can then be
installed from Tinkerer Kodi Repository.

## Script Overview

The Kodi Portable Installer is designed to install and manage portable versions of Kodi on a Windows system. It handles various tasks such as downloading builds, managing portable data, and creating shortcuts for easy access. The script uses command-line arguments for functionality and supports both user interaction and debugging modes.

## Outline of Functions

1. **Main Loop**
   - **:start**: Initializes the script, loads the configuration, and checks the installation status. It loops until the user decides to exit.

2. **Configuration Management**
   - **:load_config**: Loads configuration settings from a .conf file. If the file does not exist, it calls :config_defaults.
   - **:config_defaults**: Sets default configuration values for various parameters (installation directory, Kodi versions, architecture).
   - **:save_config**: Saves the current configuration settings back to the .conf file.

3. **Installation and Building**
   - **:kinstall_menu**: Displays the main installation menu, allowing the user to choose various options (rebuild, open Kodi, save portable data, etc.).
   - **:kbuild**: Handles the downloading and installation of the specified Kodi version. It selects the version based on user input and checks for the appropriate architecture (32/64 bit).
   - **:set_env**: Sets the environment variables related to the architecture and CPU type.
   - **:restore_portabledata**: Prompts the user to restore previously saved portable data, if available.

4. **Data Management**
   - **:save_portabledata**: Saves the current Kodi configuration and data to a tar file, allowing the user to back up their setup.
   - **:create_papp**: A placeholder for functionality to create a PortableApps.com version of Kodi (not implemented).

5. **User Interaction**
   - **:kdebugkodilog**: Opens Kodi in debug mode, presenting a debugging window for users to select the desired debugging level, enabling detailed logs for troubleshooting.
   - **:UACPrompt**: Requests administrative privileges to ensure the script can perform all required actions.

6. **Utility Functions**
   - **:fail**: A placeholder for error handling (not fully implemented).
   - **:exitmenu**: Handles cleanup and exit procedures when the user chooses to leave the script.

## Command-Line Arguments
- `--help`: Displays usage instructions.
- `--debug`: Enables debugging output.
- `build`: Triggers the build process for a specified Kodi version.

## Execution Flow
1. The script begins by parsing command-line arguments.
2. It checks for administrative privileges and prompts if necessary.
3. The main menu is presented, where the user can choose actions like building a new Kodi version, opening Kodi, or saving data.
4. Depending on the user's selection, the appropriate functions are called to perform the actions (install, open Kodi, etc.).
5. The configuration is loaded and saved as needed throughout the process.
6. The script loops until the user decides to exit, at which point it performs any necessary cleanup and exits.

This structure allows the script to be modular, making it easier to maintain and extend with additional features in the future.

## Private Fen Light source and package

The current installed Fen Light add-on is kept as clean source under:

`fenlight-source\plugin.video.fenlight`

The source includes the local Media Info 3 defaults, but does not include Kodi's profile, databases, credentials, logs, or cache files. Run `build-fenlight-package.ps1` to create the ignored package:

`packages\plugin.video.fenlight-private.zip`

`Install.bat` builds and installs that package automatically after a Kodi rebuild. From its main menu, option 6 rebuilds and installs it on demand. The ZIP has the normal Kodi add-on layout, so it can also be installed through Kodi's Add-on manager using **Install from zip file**.

## Private CocoScrapers source and package

The complete CocoScrapers 1.0.32 base is kept as source under:

`cocoscrapers-source\script.module.cocoscrapers`

The local performance changes and additional provider modules are merged into
that source. Run `build-cocoscrapers-package.ps1` to create the ignored package:

`packages\script.module.cocoscrapers-private.zip`

`Install.bat` builds and installs this complete package automatically after a
Kodi rebuild. The existing `install-cocoscrapers-patch.ps1` remains available
as a legacy overlay fallback; it is no longer the normal installation path.

## Git tracking

The repository tracks the installer, helper scripts, package source, and 7-Zip tools. The live `kodi.app` profile, generated portable app, large Kodi archives, logs, package ZIPs, and runtime data are ignored by `.gitignore`.

The public GitHub remote is `https://github.com/wggriffiths/KodiPortable.git`.
