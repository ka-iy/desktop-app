@ECHO OFF
setlocal
set SCRIPTDIR=%~dp0
set APPVER=%1

rem Determine target architecture (x86_64 or arm64). Default: host arch.
if "%~2" == "" (
    if /I "%PROCESSOR_ARCHITECTURE%" == "ARM64" ( set "_ARCH=arm64" ) else ( set "_ARCH=x86_64" )
) else (
    set "_ARCH=%~2"
)

set COMMIT=""
set DATE=""

echo ==================================================
echo ============ BUILDING IVPN CLI ===================
echo ==================================================

rem Getting info about current date
FOR /F "tokens=* USEBACKQ" %%F IN (`date /T`) DO SET DATE=%%F
rem remove spaces
set DATE=%DATE: =%

rem Getting info about commit
cd %SCRIPTDIR%\..\..
FOR /F "tokens=* USEBACKQ" %%F IN (`git rev-list -1 HEAD`) DO SET COMMIT=%%F

if "%APPVER%" == "" set APPVER=unknown
rem Removing spaces from input variables
if NOT "%APPVER%" == "" set APPVER=%APPVER: =%
if NOT "%COMMIT%" == "" set COMMIT=%COMMIT: =%
if NOT "%DATE%" == "" set DATE=%DATE: =%

echo APPVER: %APPVER%
echo COMMIT: %COMMIT%
echo DATE  : %DATE%
echo ARCH  : %_ARCH%

call :build || goto :error
goto :success

:build
	echo [*] Building IVPN CLI (%_ARCH%)

	if exist "bin\x86_64\cli\ivpn.exe" del "bin\x86_64\cli\ivpn.exe" || exit /b 1
	if exist "bin\arm64\cli\ivpn.exe"  del "bin\arm64\cli\ivpn.exe"  || exit /b 1

	set "GOOS=windows"

	if /I "%_ARCH%" == "arm64" (
		set "GOARCH=arm64"
	) else (
		set "GOARCH=amd64"
	)

	echo [ ] %_ARCH% ...
	go build -tags release -o "bin\%_ARCH%\cli\ivpn.exe" -trimpath -ldflags "-s -w -X github.com/ivpn/desktop-app/daemon/version._version=%APPVER% -X github.com/ivpn/desktop-app/daemon/version._commit=%COMMIT% -X github.com/ivpn/desktop-app/daemon/version._time=%DATE%" || exit /b 1

	goto :eof

:success
	echo [*] Success.
	go version
	exit /b 0

:error
	echo [!] IVPN Service build script FAILED with error #%errorlevel%.
	exit /b %errorlevel%
