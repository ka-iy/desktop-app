@echo off

setlocal
set SCRIPTDIR=%~dp0

rem Determine target architecture (%1 = x86_64 | arm64; default = x86_64)
if "%~1" == "" (
    set "_ARCH=x86_64"
) else (
    set "_ARCH=%~1"
)

rem Validate architecture early for clear failures
if /I not "%_ARCH%"=="x86_64" if /I not "%_ARCH%"=="arm64" (
	echo [!] ERROR: Unsupported architecture "%_ARCH%".
	echo [!] Allowed values: x86_64, arm64
	echo [!] Usage: build.bat [x86_64^|arm64]
	exit /b 1
)

SET "MANIFEST_FILE=%SCRIPTDIR%Installer\release-manifest.txt"
SET "MANIFEST_CI_FILE=%SCRIPTDIR%Installer\release-manifest-ci.txt"

set APPVER=???
set SERVICE_REPO=%SCRIPTDIR%..\..\..\daemon
set CLI_REPO=%SCRIPTDIR%..\..\..\cli

call :read_app_version 				|| goto :error
echo     APPVER         : '%APPVER%'
echo     ARCH           : '%_ARCH%'
echo     SOURCES Service: %SERVICE_REPO%
echo     SOURCES CLI    : %CLI_REPO%

call :build_service						|| goto :error
call :build_cli								|| goto :error
call :build_ui								|| goto :error

call :copy_files 							|| goto :error

rem THE END
goto :success

:read_app_version
	echo [*] Reading App version ...

	set VERSTR=???
	set PackageJsonFile=%SCRIPTDIR%..\..\package.json
	set VerRegExp=^ *\"version\": *\".*\", *

	set cmd=findstr /R /C:"%VerRegExp%" "%PackageJsonFile%"
	rem Find string in file
	FOR /F "tokens=* USEBACKQ" %%F IN (`%cmd%`) DO SET VERSTR=%%F
	if	"%VERSTR%" == "???" (
		echo [!] ERROR: The file shall contain '"version": "X.X.X"' string
		exit /b 1
 	)
	rem Get substring in quotes
	for /f tokens^=3^ delims^=^" %%a in ("%VERSTR%") do (
			set APPVER=%%a
	)

	goto :eof

:build_service
	echo [*] Building IVPN service and dependencies...
	call "%SERVICE_REPO%\References\Windows\scripts\build-all.bat" %APPVER% %_ARCH% || exit /b 1
	goto :eof

:build_cli
	echo [*] Building IVPN CLI...
	echo "%CLI_REPO%\References\Windows\build.bat"
	call "%CLI_REPO%\References\Windows\build.bat" %APPVER% %_ARCH% || exit /b 1
	goto :eof

:build_ui
	echo ==================================================
	echo ============ BUILDING IVPN UI ====================
	echo ==================================================
	cd %SCRIPTDIR%\..\..  || exit /b 1

	echo [*] Installing NPM dependencies...
	call npm install  || exit /b 1

	echo [*] Building UI...
	if /I "%_ARCH%" == "arm64" (
		call npm run electron:build:win:arm64 || exit /b 1
	) else (
		call npm run electron:build:win:x64 || exit /b 1
	)

	cd %SCRIPTDIR%  || exit /b 1
	goto :eof

:copy_files
	set "INSTALLER_OUT_DIR=%SCRIPTDIR%bin"
	if /I "%_ARCH%" == "arm64" (
		set "INSTALLER_TMP_DIR=%INSTALLER_OUT_DIR%\temp-arm64"
	) else (
		set "INSTALLER_TMP_DIR=%INSTALLER_OUT_DIR%\temp"
	)

	if /I "%_ARCH%" == "arm64" (
		set "UI_BINARIES_FOLDER=%SCRIPTDIR%..\..\dist\win-arm64-unpacked"
	) else (
		set "UI_BINARIES_FOLDER=%SCRIPTDIR%..\..\dist\win-unpacked"
	)
	for %%R in ("%SCRIPTDIR%..\..\..") do set "PROJECT_ROOT=%%~fR"

	echo [*] Copying files...
	IF exist "%INSTALLER_TMP_DIR%" (
		rmdir /s /q "%INSTALLER_TMP_DIR%"
	)
	mkdir "%INSTALLER_TMP_DIR%"

	echo     Copying UI '%UI_BINARIES_FOLDER%' ...
	xcopy /E /I  "%UI_BINARIES_FOLDER%" "%INSTALLER_TMP_DIR%\ui" || exit /b 1
	echo     Renaming UI binary to 'IVPN Client.exe' ...
	rename  "%INSTALLER_TMP_DIR%\ui\IVPN.exe" "IVPN Client.exe" || exit /b 1

	echo     Copying other files ...
	set "MANIFEST=%MANIFEST_FILE%"
	if "%GITHUB_ACTIONS%" == "true" (
	  echo "! GITHUB_ACTIONS detected ! It is just a build test."
	  echo "! Skipped compilation integration of some binaries into installer !"
		set "MANIFEST=%MANIFEST_CI_FILE%"
	)

	setlocal EnableDelayedExpansion
	for /f "usebackq eol=; tokens=*" %%i in ("%MANIFEST%") do (
		set "LINE=%%i"
		set "SKIP=NO"
		rem Check for arch-filter prefix: [x86_64] or [arm64]
		if "!LINE:~0,9!"=="[x86_64] " (
			if /I not "%_ARCH%"=="x86_64" set "SKIP=YES"
			set "LINE=!LINE:~9!"
		)
		if "!LINE:~0,8!"=="[arm64] " (
			if /I not "%_ARCH%"=="arm64" set "SKIP=YES"
			set "LINE=!LINE:~8!"
		)
		if "!SKIP!"=="NO" (
			rem Split on '=' to get DEST and SOURCE
			for /f "tokens=1,* delims==" %%d in ("!LINE!") do (
				set "DEST=%%d"
				set "SRC=%%e"
			)
			rem Trim whitespace from DEST and SRC (for manifest formatting flexibility)
			call :trim_var DEST
			if not "!SRC!"=="" call :trim_var SRC
			rem If no explicit source, source path equals destination path
			if "!SRC!"=="" set "SRC=!DEST!"
			rem Expand {ARCH} placeholder in source path
			set "SRC=!SRC:{ARCH}=%_ARCH%!"
			rem Resolve source path from project root
			set "SRCPATH=%PROJECT_ROOT%\!SRC!"
			if not exist "!SRCPATH!" (
				echo FILE NOT FOUND: !SRCPATH!
				exit /b 1
			)
			echo     !SRCPATH! -^> !DEST!

			IF NOT EXIST "%INSTALLER_TMP_DIR%\!DEST!\.." (
				MKDIR "%INSTALLER_TMP_DIR%\!DEST!\.."
			)

			copy /y "!SRCPATH!" "%INSTALLER_TMP_DIR%\!DEST!" > NUL
			IF !errorlevel! NEQ 0 (
				ECHO     Error: failed to copy "!SRCPATH!" to "%INSTALLER_TMP_DIR%\!DEST!"
				EXIT /B 1
			)
		)
	)
	goto :eof

:trim_var
	rem Trims leading and trailing whitespace from variable named %1
	setlocal EnableDelayedExpansion
	set "_val=!%1!"
	rem Trim leading spaces
	for /f "tokens=*" %%a in ("!_val!") do set "_val=%%a"
	rem Trim trailing spaces
	:trim_var_loop
	if "!_val:~-1!"==" " (
		set "_val=!_val:~0,-1!"
		goto :trim_var_loop
	)
	endlocal & set "%1=%_val%"
	goto :eof

:success
	endlocal
	exit /b 0

:error
	set ERR=%errorlevel%
	if %ERR% == 0 set ERR=1
	echo [!] IVPN Client installer build FAILED with error #%ERR%.
	endlocal & exit /b %ERR%
