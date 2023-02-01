@echo off

:: # Kodi Portable Installer v0.03
:: # [if executed with "--debug" print all executed commands]
:: #####################################################################
set kpi_ver=0.03

:: # Command line arguments:
:: #
:: # [to be implemented, possible list of commands]
:: # 
:: # install build nexus 20.03 64
:: #      -- open
:: #         open debug [0-3]
:: #         portabledata save [file]
:: #         portabledata load [file]
:: #         --help
:: #         --debug (debug this script)
:: ###################################################
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

IF "%~1"=="/?" (
    goto :KUSAGE
    EXIT /B
)

:: remove '::' for console only
::if [%1]==[] goto :KUSAGE

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
setlocal enabledelayedexpansion & cd /d %~dp0
if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
:: -------------------------------------------------------------------->

:: #####################################################################
:: # Start of main script - load config, env, stay in loop until
:: # ExitMenu=1
:: #####################################################################
Title Kodi Portable - v%kpi_ver%
:start
cls
call :load_config

rem %$KCodename%-x%CPU%
rem echo %$KCodename%-x%CPU%
rem set $fSearch=*.nsis
rem set $sTitle=Kodi Installations: 
rem call :getfilelist
rem echo %file%
rem pause

if "%$KInstall%"=="0" (
	call :kbuild
) else (
	call :kinstall_menu
)

call :save_config

if "%ExitMenu%"=="1" (goto :eof)
goto :start
:: ---------------------------------------------------------------------

:: # Kodi Portable Main Menu
:: #####################################################################
:kinstall_menu
color 1F
:topmenu
cls
	echo *-------------------------------------------------------------*
	echo * Install Dir: [.\%$KInstallDir%] Codename: [%$KCodename%] 
	echo * Ver: [%$KVer%] Architecture: [x%CPU%]
	echo *-------------------------------------------------------------*
	echo. 
	echo   1^) Rebuild ^(this will delete the current build^)
	echo   2^) Open Kodi
    echo   3^) Open Kodi (debug kodi.log)
	echo   4^) Save 'Portable_data'
    echo   5^) Create Portable App ^(PortableApps.com^)
	echo   x^) Exit 
	echo. 
	echo. 
	choice /C 12345x /N /M "Choose an option: "
	echo.

	if "%errorlevel%" == "1" (
		rd /q /s %KODI_ROOT%
		set $KArchitecture=unset
		set CPU=unset
		set $KInstall=0
		ver > nul
        EXIT /B 0
	)

	if "%errorlevel%" == "2" (
        start /wait %KODI_ROOT%\start-kodi.bat
        timeout /t 1 /nobreak > NUL
	)

	if "%errorlevel%" == "3" (
        call :kdebugkodilog
	)

	if "%errorlevel%" == "4" (
        call :save_portabledata
        ver > nul
	)

	if "%errorlevel%" == "5" (
        call :create_papp
	)

	if "%errorlevel%" == "6" (
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
color 1F
cls

echo *-------------------------------------------------------------*
echo * Kodi Codename
echo *-------------------------------------------------------------*
echo. 
echo   1. Nexus 
echo   2. Matrix
echo   3. Leia
echo. 
echo. 
choice /C 123 /N /M "Select the codename to install: "

:: # x86, x64 Win32, Win64
:: #########################
if "%errorlevel%" == "1" (
    set $KCodename=Nexus
    set Redistributable=vc2019
    set fList=%$_Nexus%
)

if "%errorlevel%" == "2" (
    set $KCodename=Matrix
    set Redistributable=vc2019
    set fList=%$_Matrix%
)

if "%errorlevel%" == "3" (
    set $KCodename=Leia
    set Redistributable=vc2017
    set fList=%$_Leia%
)

call :setversion
call :set_env

set $KVer=%$file%
set $pfile=portable_data_%$KVer%-%$KCodename%-x%CPU%.tar
set $file=kodi-%$KVer%-%$KCodename%-x%CPU%

set $sh_url=%$_DownloadBaseUrl%win%$KArchitecture%/%$file%.exe
::set $sh_url=http://mirrors.kodi.tv/releases/windows/win%$KArchitecture%/kodi-%$KVer%-%$KCodename%-x%CPU%.exe

ver > nul
:: # clear the choice returned
:: # make errorlevel 0
:: #############################

if not exist %PPATH%%$file%.nsis (
    echo Downloading %$file%.nsis
    echo %PPATH%bin\wget -q %$sh_url% --show-progress -O %PPATH%%$file%.nsis
    %PPATH%bin\wget -q %$sh_url% --show-progress -O %PPATH%%$file%.nsis
)

if %errorlevel% NEQ 0 (
    echo Error downloading file, Error: %errorlevel%
    del %PPATH%%$file%.nsis
    goto :fail
) else (
    echo Extracting: [%PPATH%%$file%.nsis]
    %PPATH%bin\7z.exe x -o"%KODI_ROOT%" %PPATH%%$file%.nsis
    
    rem If it exists extract portable_data
    if exist %PPATH%%$pfile% (
    rem if exist %PPATH%portable_data_%$KVer%-%$KCodename%-x%CPU%.tar (
    	echo Extracting: Portable Data [%PPATH%%$pfile%]
    	%PPATH%bin\7z.exe x -o"%KODI_ROOT%" "%PPATH%%$pfile%"
    )
    
    rem # install Visual C++ 2017(x%CPU%) Redistributable
    rem ###################################################
    echo Installing: Visual C++ 2017^(x%CPU%^) Redistributable
    if exist %KODI_ROOT%\$TEMP\%Redistributable%\vcredist_x%CPU%.exe (
        start /wait %KODI_ROOT%\$TEMP\%Redistributable%\vcredist_x%CPU%.exe /s
        timeout /t 4
    )

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

echo *-------------------------------------------------------------*
echo * Kodi Portable Installation Complete..                       *
echo *-------------------------------------------------------------*
echo ** Move the 'kodi-portable' directory to your location of    **
echo ** choice and run 'start-kodi.bat' to setup shortcut.        **
echo ** -- Alternatively use the (PortableApps.com) option --     **
echo ***************************************************************
echo.
timeout /t 8
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

echo *-------------------------------------------------------------*
echo * Kodi %$kCodename% Architecture
echo *-------------------------------------------------------------*
echo.
echo   1^) Set Automatically ^(x%CPU%^)
echo   2^) Manual Selection
echo.
echo.
choice /C 12 /N /M "Choose an option: "
echo.

if "%errorlevel%" == "2" (
    cls
    echo *-------------------------------------------------------------*
	echo * Select Architecture
	echo *-------------------------------------------------------------*
	echo.
	echo   1^) x86 ^(32^)
	echo   2^) x64 ^(64^)
	echo.
    echo.
	choice /C 12 /N /M "Choose an option: "
	echo.
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
cls

:: check if 'portable_data' folder exists
if exist %PPATH%%$KInstallDir%\portable_data (
	if exist %PPATH%portable_data_%$KVer%-%$KCodename%-x%CPU%.tar (
    	echo File: [portable_data_%$KVer%-%$KCodename%-x%CPU%.tar] already exists, do you want to overwrite?
    	echo.
    	choice /C yn /N /M "(Y)es (N)o: "
	)

    if "!errorlevel!" == "2" (
        EXIT /B 0
    ) else (
		echo Saving:[portable_data]
		cd %KODI_ROOT%
		%PPATH%bin\7z.exe a %PPATH%portable_data_%$KVer%-%$KCodename%-x%CPU%.tar portable_data
		cd %PPATH%
	)
) else (echo Nothing to save. Open Kodi and configure first.)

timeout /t 2 /nobreak > NUL
EXIT /B 0

:: # Load Configuration Function
:: ###############################
:load_config
cls
color 0F

set PPATH=%~dp0
echo Loading config: [%~n0.conf]
if not exist %PPATH%%~n0.conf (
    echo Config not found.
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
timeout /t 1 /nobreak > NUL
EXIT /B 0

:: # Load config defaults
:: ########################
:config_defaults
echo Creating config defaults: [%~n0.conf] 
set $KInstallDir=kodi.app
set $KCodename%=
set $KInstall=0
set $KVer%=
set $KArchitecture=unset
set $Nexus=20.0
set $Matrix=19.5
set $Leia=18.9
set $Krypton=17.6
set $_DownloadBaseUrl=http://mirrors.kodi.tv/releases/windows/
set $_Nexus=20.0
set $_Matrix=19.5 19.4 19.3 19.2 19.0 
set $_Leia=18.9 18.8 18.7 

:: # Save configuration
:: ######################
:save_config
if exist %PPATH%%~n0.conf (del %PPATH%%~n0.conf)
set "kodi_config=%PPATH%%~n0.conf"
echo Saving config: [%~n0.conf]
(
  echo # kodi portable v%kpi_ver% config
  echo ###################################
  echo $KInstallDir=%$KInstallDir%
  echo $KCodename=%$KCodename%
  echo $KInstall=%$KInstall%
  echo $KVer=%$KVer%
  echo $KArchitecture=%$KArchitecture%
  echo.
  echo # Installer versions
  echo ###################################
  echo $_DownloadBaseUrl=%$_DownloadBaseUrl%
  echo $_Nexus=%$_Nexus%
  echo $_Matrix=%$_Matrix%
  echo $_Leia=%$_Leia%

) >"%kodi_config%" || goto :fail
ver > nul
EXIT /B 0

:: # Get file list function.
:: #
:: # Arguments: $fSearch=pattern e.g set $fSearch=*.doc
:: #            $sTitle=Title to display
:: # Return:     $file
:: #
:: #######################################################
:getfilelist
set n=1
set $file=
set cList=
set arr[1]=

echo *--------------------------------------------------------------------*
echo * %$sTitle%
echo *--------------------------------------------------------------------*
echo.

for /f tokens^=* %%i in ('where .:%$fSearch%') do (
	rem @echo/ !n!: Path: %%~dpi ^| Name: %%~nxi
	@echo/ !n!: %%i
	call set "cList=%%cList%%!n!"
	set arr[!n!]=%%i
	set /a n=n+1
)

rem # check if anything found
rem ###########################
if not defined arr[1] (
	set $file=0
	exit /b 0
)

:: # return the selected file
:: ############################
echo.
echo.
choice /c %cList% /n /m "Make a selection: "
set $file=!arr[%errorlevel%]!
exit /b 0

:: # Get versions function.
:: #
:: # Arguments: $fList=ver pattern list
:: #            $sTitle=Title to display
:: # Return:     $file
:: #
:: ###########################################################
:setversion
cls
set n=1
set cList=
set arr[1]=
set $file=

echo *--------------------------------------------------------------------*
echo * Kodi %$kCodename% Version
echo *--------------------------------------------------------------------*
echo.

for %%a in (%fList%) do (
    echo   !n!: Kodi-%%a-!$kCodename!
	call set "cList=%%cList%%!n!"
	set arr[!n!]=%%a
	set /a n=n+1
)

rem # check if anything found
rem ###########################
if not defined arr[1] (
	set $file=0
	exit /b 0
)

echo.
echo.
choice /c %cList% /n /m "Make a selection: "
set $file=!arr[%errorlevel%]!
exit /b 0

:: # Debug Kodi Log
:: #################################
:kdebugkodilog
cls

set "advancedsettingsxml=%KODI_ROOT%\portable_data\userdata\advancedsettings.xml"

echo *-------------------------------------------------------------*
echo * Kodi Log Level
echo *-------------------------------------------------------------*
echo.
echo   0^) Level 0
echo   1^) Level 1
echo   2^) Level 2
echo   3^) Level 3
echo.
echo.
choice /C 0123 /N /M "Choose an option: "
echo.

set /a kLoglevel=%errorlevel%-1

if "%errorlevel%" NEQ "0" (
    (
    echo ^<advancedsettings^>
    echo     ^<loglevel^>%kLoglevel%^</loglevel^>
    echo ^</advancedsettings^>
    ) > "%advancedsettingsxml%" || goto :fail
)

start %KODI_ROOT%\start-kodi.bat

set filename=*.log
set curfiletime=0

cd %KODI_ROOT%\portable_data

:checkfiletime
for /f %%i in ('"forfiles /m %filename% /c "cmd /c echo @ftime" "') do set modif_time=%%i
if %curfiletime% NEQ 0 (
	if %curfiletime% NEQ %modif_time% (
		goto :loadkodilog
	)
)

set curfiletime=%modif_time%
timeout /T 1 > nul
goto :checkfiletime

:loadkodilog
start  "LOGLEVEL: %kLoglevel% [CTRL+C to Exit]" %PPATH%bin\tail -f %KODI_ROOT%\portable_data\kodi.log
if exist %KODI_ROOT%\portable_data\userdata\advancedsettings.xml (del %KODI_ROOT%\portable_data\userdata\advancedsettings.xml)
exit /B 0

:: # Get PID function.
:: #
:: # Arguments: [windows title]
:: # Return:     PID
:: # e.g call getpid kodi - get PID of windowstitle 'kodi'
:: #     call getpid kodi* - get PID of windowstitle that 
:: #     start with kodi
:: ################################################################
:getpid
for /f "delims=" %%a in ('tasklist /fo list /fi "WINDOWTITLE eq  %~1" ^| findstr /i "PID"') do set "PID=%%a"
for /f "tokens=2" %%i in ("%PID%") do set PID="%%i"
exit /B 0

:: # Error Handling
:: ##################
:fail
set exit_code=%errorlevel%
echo.
echo #####################################################################
echo # Kodi Portable FAILED! Err: %errorlevel%
echo #####################################################################
echo.
timeout /T 60
exit /B %exit_code%

:: # Command line usage
:: ######################
:KUSAGE
echo Kodi Portable v%kpi_ver% help
echo.
for %%f in ("%0") do set cmdline=%%~nf
echo Usage: %cmdline% ^<Codename^> ^<Version^> ^<Architecture^>
echo.
echo Example:
echo    install Nexus 20.0 64
echo    install Nexus 20.0 86
exit /B 1

:eof