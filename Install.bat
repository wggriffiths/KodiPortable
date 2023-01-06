@echo off

rem # Kodi Portable Installer v1
rem #############################

rem # directory to install kodi portable
rem #####################################
rem set KodiDir=kodi-portable

rem #if executed with "--debug" print all executed commands
rem ########################################################
for %%a in (%*) do (
    if [%%~a]==[--debug] echo on
)

rem mode con:cols=55 lines=2
rem BatchGotAdmin
rem -------------------------------------
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

cls

Title Kodi Portable

rem ## get architecture
rem #########################
rem reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set OS=32 || set OS=64

set PPATH=%~dp0

if not exist %PPATH%%~n0.conf (
    echo Config not found..
    call :config_defaults
)

rem # load config
rem #################################
echo Loading configuration: [%~n0.conf]
echo. 
call :load_config
ver > nul

set KODI_ROOT=%PPATH%%$KInstallDir%

rem set KODI_ROOT=%PPATH%%KodiDir%
rem set PATH=%PATH%;"%~dp0bin"

:top
cls

rem # check if built before
rem # if built before show menu
rem #################################

color 1F

if exist %KODI_ROOT% (
	echo *---------------------------------------------------------*
	echo * Warning: Kodi has been built before
	echo *---------------------------------------------------------*
	echo * Install Dir: [..\%$KInstallDir%] Build: [%$KBuild%] 
	echo * Ver: [%$KVer%] Architecture: [x%$KArchitecture%]
	echo *---------------------------------------------------------*
	echo. 
	echo   1. Rebuild ^(this will delete the current build^)
	echo   2. Open Kodi
	echo   3. Save 'Portable_data'
	echo   4. Exit 
	echo. 
	echo. 
	:top
	choice /C 1234 /N /M "Choose an option: "
	echo. 
)

if exist %KODI_ROOT% (
    echo %errorlevel%

	if "%errorlevel%" == "1" (
		rmdir/q /s %KODI_ROOT%
	)

	if "%errorlevel%" == "2" (
    		start /wait %KODI_ROOT%\start-kodi.bat
            timeout /t 3 /nobreak > NUL
            goto top
	)

	if "%errorlevel%" == "3" (
    		call :save_portabledata
            goto top
	)

	if "%errorlevel%" == "4" (
            call :save_config
    		goto eof
	)

)

echo *---------------------------------------------------------*
echo * Kodi Portable Installer v1
echo *---------------------------------------------------------*
echo. 
echo Select the release to install.
echo. 
echo. 
choice /C ml /M "(M)atrix, (L)eia :"

rem # x86, x64 Win32, Win64
rem ########################
if "%errorlevel%" == "1" (
    set $sh_url=http://mirrors.kodi.tv/releases/windows/win%OS%/kodi-19.5-Matrix-x%OS%.exe
    set $KBuild=Matrix
    set $KVer=19.5
    set Redistributable=vc2019
) else (
    set $sh_url=http://mirrors.kodi.tv/releases/windows/win%OS%/kodi-18.8-Leia-x%OS%.exe
    set $KBuild=Leia
    set $KVer=18.5
    set Redistributable=vc2017
)

rem # clear the choice returned
rem # make errorlevel 0
rem ##############################
ver > nul

if not exist %PPATH%kodi-%$KBuild%-x%OS%.nsis (
    echo Downloading Kodi %$KBuild% v19.5
    echo %PPATH%bin\wget -q %$sh_url% --show-progress -O %PPATH%kodi-%$KBuild%-x%OS%.nsis
    %PPATH%bin\wget -q %$sh_url% --show-progress -O %PPATH%kodi-%$KBuild%-x%OS%.nsis
)

if %errorlevel% NEQ 0 (
    echo Error downloading file, Error: %errorlevel%
    goto :fail
) else (
    echo Extracting: [%PPATH%kodi-%$KBuild%-x%OS%.nsis]
    %PPATH%bin\7z.exe x -o"%KODI_ROOT%" %PPATH%kodi-%$KBuild%-x%OS%.nsis
    echo Extracting: Portable Data [%PPATH%portable_data.tar]
    %PPATH%bin\7z.exe x -o"%KODI_ROOT%" "%PPATH%portable_data_%$KBuild%.tar"
    
    rem echo Copy: [%PPATH%Start-Kodi.bat] to [%KODI_ROOT%]
    rem copy %PPATH%Start-Kodi.bat %KODI_ROOT%
    
    rem # install Visual C++ 2017(x%OS%) Redistributable
    rem #################################################
    rem echo Install: Visual C++ 2017(x%OS%) Redistributable
    echo %KODI_ROOT%\$TEMP\%Redistributable%\vcredist_x%OS%.exe
    start /wait %KODI_ROOT%\$TEMP\%Redistributable%\vcredist_x%OS%.exe /s
    timeout /t 5

    rem # remove unwanted directories and files
    rmdir/q /s %KODI_ROOT%\$TEMP
    rmdir/q /s %KODI_ROOT%\$PLUGINSDIR
    del /q %KODI_ROOT%\Uninstall.exe
    echo.
)

rem # Create start-kodi.bat
rem ##################################
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
  echo exity
) >"%start_kodi%" || goto :fail

echo.
echo Kodi Portable Installation Complete..
echo.
echo ** Move the 'kodi-portable' directory to your location of choice **
echo ** and run 'start-kodi.bat' to setup.                            **
echo.
timeout /t 3 /nobreak > NUL
call :save_config
goto :top
rem goto :eof

rem # Save portable data
rem ###################################
:save_portabledata
cd %KODI_ROOT%
if exist %PPATH%portable_data_%$KBuild%-test.tar (
    echo File already exists, do you want to overwrite?
    echo.
    choice /C yn /M "(Y)es (N)o :"
)

if "%errorlevel%" == "1" (
	echo Saving: [portable_data]
	%PPATH%bin\7z.exe a %PPATH%portable_data_%$KBuild%-test.tar portable_data
)
timeout /t 3 /nobreak > NUL
EXIT /B 0

rem # Load Configuration
rem ###################################
:load_config
for /f "tokens=1,2 delims== eol=#" %%a in (%PPATH%%~n0.conf) do (
    rem # set env for each line, set <name>=<value>
    echo %%a: %%b	
    set %%a=%%b
)
timeout /t 3 /nobreak > NUL
EXIT /B 0

rem # Load config defaults
rem ###################################
:config_defaults
echo Creating [%~n0.conf] defaults...
set $KInstallDir=kodi-portable
set $KBuild%=
set $KVer%=
set $KArchitecture=
set $Nexus=20.0-Nexus_rc2
set $Matrix=19.5-Matrix
set $Leia=18.9-Leia
set $Krypton=17.6-Krypton

rem # Save configuration
rem ###################################
:save_config
if exist %PPATH%%~n0.conf (del %PPATH%%~n0.conf)
set "kodi_config=%PPATH%%~n0.conf"
echo Updating: [%~n0.conf]...
(
  echo # config file for install-kodi.bat
  echo ###################################
  echo $KInstallDir=%$KInstallDir%
  echo $KBuild=%$KBuild%
  echo $KVer=%$KVer%
  echo $KArchitecture=%OS%
  echo.
  echo # Installer versions
  echo ###################################
  echo $Nexus=%$Nexus%
  echo $Matrix=%$Matrix%
  echo $Leia=%$Leia%
  echo $Krypton=%$Krypton%
) >"%kodi_config%" || goto :fail
timeout /t 2 /nobreak > NUL
EXIT /B 0

rem # Error Handling
rem ###################################
:fail
  set exit_code=%ERRORLEVEL%

  rem if exist "%DOWNLOADER%" (
  rem   del "%DOWNLOADER%"
  rem )

  echo.
  echo ###########################################################
  echo # Kodi Portable FAILED! Err: %errorlevel%
  echo ###########################################################
  echo.
  timeout /T 60
  exit /B %exit_code%

:eof


