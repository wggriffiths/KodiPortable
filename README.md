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

