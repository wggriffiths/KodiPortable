@echo off

:: # Kodi Portable Installer v0.03
:: # [if executed with "--debug" print all executed commands]
:: #####################################################################

for %%a in (%*) do (
    if [%%~a]==[--help] (
        call ::KUSAGE
        exit /B 0
    )
    if [%%~a]==[build] (
        call ::KUSAGE
        exit /B 0
    )

    if [%%~a]==[--debug] (echo on)
)

:: if [%1]==[] goto :KUSAGE

:: # Get Admin
:: #############
:: mode con:cols=55 lines=2
:: BatchGotAdmin
:: <--------------------------------------------------------------------
REM --> Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
echo Requesting administrative privileges...
goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
echo UAC.ShellExecute "%~s0","%ARGS%", "", "runas", 1 >> "%temp%\getadmin.vbs"
"%temp%\getadmin.vbs"
exit /B

:gotAdmin
setlocal  & cd /d %~dp0
if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
:: -------------------------------------------------------------------->

:: #####################################################################
:: # Start of main script - load config and env, stay in loop until
:: # ExitMenu=1
:: #####################################################################
Title Kodi Portable
cls
:start
color 0F
call :load_config

if [%$KArchitecture%]==[unset] (
    call :set_env
)

call :save_config
ver > nul

if "%$KInstall%"=="0" (
	call :kbuild
) else (
	call :kinstall_menu
	call :save_config
)

if "%ExitMenu%"=="1" (goto :eof)
goto :start
:: ---------------------------------------------------------------------

:: # 
:: #####################################################################
:kinstall_menu
color 1F
:topmenu
cls
	echo *---------------------------------------------------------*
	echo * Warning: Kodi has been built before
	echo *---------------------------------------------------------*
	echo * Install Dir: [..\%$KInstallDir%] Build: [%$KBuild%] 
	echo * Ver: [%$KVer%] Architecture: [x%CPU%]
	echo *---------------------------------------------------------*
	echo. 
	echo   1^) Rebuild ^(this will delete the current build^)
	echo   2^) Open Kodi
	echo   3^) Save 'Portable_data'
	echo   4^) Create Portable App ^(PortableApps.com^)
	echo   5^) Exit 
	echo. 
	echo. 
	choice /C 12345 /N /M "Choose an option: "
	echo.

	if "%errorlevel%" == "1" (
		rd /q /s %KODI_ROOT%
		set $KArchitecture=unset
		set CPU=unset
		set $KInstall=0
		call :save_config
		call :set_env
		ver > nul
	EXIT /B 0
	)

	if "%errorlevel%" == "2" (
	start /wait %KODI_ROOT%\start-kodi.bat
	timeout /t 1 /nobreak > NUL
	)

	if "%errorlevel%" == "3" (
	call :save_portabledata
	ver > nul
	)

	if "%errorlevel%" == "4" (
	call :create_papp
	)

	if "%errorlevel%" == "5" (
	set ExitMenu=1
	goto :exitmenu
	)

if "%$KInstall%"=="1" (goto :topmenu)
:exitmenu
timeout /t 1 /nobreak > NUL
EXIT /B 0

:: # Kodi Build Function - build base image
:: #####################################################################
:kbuild
cls
echo *---------------------------------------------------------*
echo * Kodi Portable Installer v1
echo *---------------------------------------------------------*
echo. 
echo Select the release to install.
echo. 
echo. 
choice /C ml /M "(M)atrix, (L)eia: "

:: # x86, x64 Win32, Win64
:: #########################
if "%errorlevel%" == "1" (
    set $KBuild=Matrix
    set $KVer=%$Matrix%
    set Redistributable=vc2019
) else (
    set $KBuild=Leia
    set $KVer=%$Leia%
    set Redistributable=vc2017
)

set $sh_url=http://mirrors.kodi.tv/releases/windows/win%$KArchitecture%/kodi-%$KVer%-%$KBuild%-x%CPU%.exe

:: # clear the choice returned
:: # make errorlevel 0
:: #############################
ver > nul

if not exist %PPATH%kodi-%$KBuild%-%$KVer%-x%CPU%.nsis (
    echo Downloading Kodi %$KBuild% v19.5
    echo %PPATH%bin\wget -q %$sh_url% --show-progress -O %PPATH%kodi-%$KBuild%-%$KVer%-x%CPU%.nsis
    %PPATH%bin\wget -q %$sh_url% --show-progress -O %PPATH%kodi-%$KBuild%-%$KVer%-x%CPU%.nsis
)

if %errorlevel% NEQ 0 (
    echo Error downloading file, Error: %errorlevel%
    goto :fail
) else (
    echo Extracting: [%PPATH%kodi-%$KBuild%-%$KVer%-x%CPU%.nsis]
    %PPATH%bin\7z.exe x -o"%KODI_ROOT%" %PPATH%kodi-%$KBuild%-%$KVer%-x%CPU%.nsis
    rem If it exists extract portable_data
    if exist %PPATH%portable_data (
    	echo Extracting: Portable Data [%PPATH%portable_data.tar]
    	%PPATH%bin\7z.exe x -o"%KODI_ROOT%" "%PPATH%portable_data_%$KBuild%.tar"
    )
    
    rem # install Visual C++ 2017(x%CPU%) Redistributable
    rem ###################################################
    echo Installing: Visual C++ 2017^(x%CPU%^) Redistributable
    start /wait %KODI_ROOT%\$TEMP\%Redistributable%\vcredist_x%CPU%.exe /s
    timeout /t 4

    rem # remove unwanted directories and files
    rd /q /s %KODI_ROOT%\$TEMP
    rd /q /s %KODI_ROOT%\$PLUGINSDIR
    del /q %KODI_ROOT%\Uninstall.exe
	set $KInstall=1
    echo.
)

:: # Create start-kodi.bat
:: #########################
set "start_kodi=%KODI_ROOT%\start-kodi.bat"
echo Creating [%start_kodi%]...
(
  echo @echo off
  echo mode con:cols=55 lines=3
  echo.
  echo pushd "%%CD%%"
  echo CD /D "%%~dp0%"
  echo set PPATH=%%~dp0%
  echo.
  echo if exist "%%USERPROFILE%%\Desktop\Kodi.lnk" (
  echo     :start_kodi
  echo     echo starting kodi
  echo     kodi.exe -p
  echo     goto eof
  echo ^)
  echo.
  echo echo creating shortcut
  echo set SCRIPT="%%PPATH%%\%%RANDOM%%-%%RANDOM%%-%%RANDOM%%-%%RANDOM%%.vbs"
  echo echo Set oWS = WScript.CreateObject("WScript.Shell"^) ^>^> %%SCRIPT%%
  echo echo Set oWS = WScript.CreateObject("WScript.Shell"^) ^>^> %%SCRIPT%%
  echo ^echo sLinkFile = "%USERPROFILE%\Desktop\Kodi.lnk" ^>^> %%SCRIPT%%
  echo ^echo Set oLink = oWS.CreateShortcut(sLinkFile^) ^>^> %%SCRIPT%%
  echo ^echo oLink.TargetPath = "%%PPATH%%start-kodi.bat" ^>^> %%SCRIPT%%
  echo ^echo oLink.IconLocation = "%%PPATH%%\kodi.exe" ^>^> %%SCRIPT%%
  echo ^echo oLink.Save ^>^> %%SCRIPT%%
  echo.
  echo.
  echo cscript /nologo %%SCRIPT%%
  echo del %%SCRIPT%%
  echo goto start_kodi
  echo.
  echo :eof
  echo exit
) >"%start_kodi%" || goto :fail

echo *---------------------------------------------------------*
echo * Kodi Portable Installation Complete..                   *
echo *---------------------------------------------------------*
echo * Move the 'kodi-portable' directory to your location of  *
echo * choice and run 'start-kodi.bat' to setup shortcut.      *
echo * -- Alternatively use the (PortableApps.com) option --   *
echo *---------------------------------------------------------*
echo.
timeout /t 8 /nobreak
call :save_config
EXIT /B 0

:: # Set environment Function
:: ############################
:set_env
cls
color 1F

rem https://blogs.msdn.microsoft.com/david.wang/2006/03/27/howto-detect-process-bitness/
if "%PROCESSOR_ARCHITECTURE%" == "x86" (
    if defined PROCESSOR_ARCHITEW6432 (
        set $KArchitecture=64
        set CPU=64
    ) else (
        set $KArchitecture=32
        set CPU=86
    )
) else (
    set $KArchitecture=64
    set CPU=64
)

echo *---------------------------------------------------------*
echo * Architecture not set
echo *---------------------------------------------------------*
echo.
echo   1^) Set Automatically ^(x%CPU%^)
echo   2^) Manual Selection
echo.
choice /C 12 /N /M "Choose an option: "
echo.

if "%errorlevel%" == "2" (
	echo *---------------------------------------------------------*
	echo * Select Architecture
	echo *---------------------------------------------------------*
	echo.
	echo   1^) x86 ^(32^)
	echo   2^) x64 ^(64^)
	echo.
	choice /C 12 /N /M "Choose an option: "
	echo.
) 

if "%errorlevel%" == "1" (
	set CPU=86
	set $KArchitecture=32
) else (
	set CPU=64
	set $KArchitecture=64
)

timeout /t 1 /nobreak > NUL
EXIT /B 0

:: # Create portable app (portableapps.com) Function
:: # 
:: #  
:: ###################################################
:create_papp
echo Create portable app
timeout /t 2 /nobreak > NUL
EXIT /B 0

:: # Save portable data Function
:: ###############################
:save_portabledata

:: check if 'portable_data' folder exists
if exist %PPATH%portable_data_% (
	if exist %PPATH%portable_data_%$KBuild%-test.tar (
    	echo File: [portable_data_%$KBuild%-test.tar] already exists, do you want to overwrite?
    	echo.
    	choice /C yn /M "^(Y^)es ^(N^)o :"
	)

	if "%errorlevel%" == "1" (
		echo Saving: [portable_data]
		cd %KODI_ROOT%
		%PPATH%bin\7z.exe a %PPATH%portable_data_%$KBuild%-test.tar portable_data
		cd %PPATH%
	)
) else (echo Nothing to save. Open Kodi first.)

timeout /t 2 /nobreak > NUL
EXIT /B 0

:: # Load Configuration Function
:: ###############################
:load_config
set PPATH=%~dp0
echo Loading: [%~n0.conf]
if not exist %PPATH%%~n0.conf (
    echo Config not found..
    call :config_defaults
)

for /f "tokens=1,2 delims== eol=#" %%a in (%PPATH%%~n0.conf) do (
    rem # set env for each line, set <name>=<value>
    echo %%a: %%b	
    set %%a=%%b
)

if %$KArchitecture%==64 (set CPU=64)
if %$KArchitecture%==32 (set CPU=86)

set KODI_ROOT=%PPATH%%$KInstallDir%
timeout /t 2 /nobreak > NUL
EXIT /B 0

:: # Load config defaults
:: ########################
:config_defaults
echo Creating [%~n0.conf] defaults...
set $KInstallDir=kodi.app
set $KBuild%=
set $KInstall=0
set $KVer%=
set $KArchitecture=unset
set $Nexus=20.0
set $Matrix=19.5
set $Leia=18.9
set $Krypton=17.6

:: # Save configuration
:: ######################
:save_config
if exist %PPATH%%~n0.conf (del %PPATH%%~n0.conf)
set "kodi_config=%PPATH%%~n0.conf"
echo Saving: [%~n0.conf]
(
  echo # config file for install-kodi.bat
  echo ###################################
  echo $KInstallDir=%$KInstallDir%
  echo $KBuild=%$KBuild%
  echo $KInstall=%$KInstall%
  echo $KVer=%$KVer%
  echo $KArchitecture=%$KArchitecture%
  echo.
  echo # Installer versions
  echo ###################################
  echo $Nexus=%$Nexus%
  echo $Matrix=%$Matrix%
  echo $Leia=%$Leia%
  echo $Krypton=%$Krypton%
) >"%kodi_config%" || goto :fail
rem timeout /t 1 /nobreak > NUL
EXIT /B 0

:: # Error Handling
:: ##################
:fail
  set exit_code=%ERRORLEVEL%
  echo.
  echo #####################################################################
  echo # Kodi Portable FAILED! Err: %errorlevel%
  echo #####################################################################
  echo.
  timeout /T 60
  exit /B %exit_code%

:KUSAGE
echo KPortable v0.2 help
for %%f in ("%0") do set cmdline=%%~nf
echo Usage: %cmdline% ^<SUBJECT^> ^<BODY^> ^<ATTACHMENT^>
exit /B 1

:eof
