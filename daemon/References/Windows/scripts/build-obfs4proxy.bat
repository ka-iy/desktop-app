@ECHO OFF

setlocal

rem TODO: define here obfs4proxy version to build
set _VERSION=obfs4proxy-0.0.14

set SCRIPTDIR=%~dp0

rem Determine target architecture (x86_64 or arm64). Default: host arch.
if "%~1" == "" (
    if /I "%PROCESSOR_ARCHITECTURE%" == "ARM64" ( set "_ARCH=arm64" ) else ( set "_ARCH=x86_64" )
) else (
    set "_ARCH=%~1"
)

if exist "%SCRIPTDIR%..\OpenVPN\obfsproxy\%_ARCH%" (
  echo [*] Erasing OpenVPN\obfsproxy\%_ARCH%\*.exe ...
  del /f /q "%SCRIPTDIR%..\OpenVPN\obfsproxy\%_ARCH%\obfs4proxy.exe"  >nul 2>&1
) else (
  mkdir "%SCRIPTDIR%..\OpenVPN\obfsproxy\%_ARCH%" || exit /b 1
)

if exist "%SCRIPTDIR%..\.deps\obfsproxy" (
  echo [*] Erasing '"%SCRIPTDIR%..\.deps\obfsproxy' ...
  rmdir /s /q "%SCRIPTDIR%..\.deps\obfsproxy" || exit /b 1
)

echo [*] Creating .deps\obfsproxy ...
mkdir "%SCRIPTDIR%..\.deps\obfsproxy" || exit /b 1

echo [*] Cloning obfs4proxy sources...
cd "%SCRIPTDIR%..\.deps\obfsproxy"
git clone https://github.com/Yawning/obfs4.git || exit /b 1
cd obfs4

echo [*] Checkout version '%_VERSION%'' of obfs4proxy..."
git checkout tags/%_VERSION%

echo [*] Compiling obfs4proxy (%_ARCH%) ...

if /I "%_ARCH%" == "arm64" ( set "GOARCH=arm64" ) else ( set "GOARCH=amd64" )
set "GOOS=windows"
go build -o "%SCRIPTDIR%..\OpenVPN\obfsproxy\%_ARCH%\obfs4proxy.exe" -trimpath -ldflags "-s -w" ./obfs4proxy || exit /b 1

echo [ ] SUCCESS
echo [ ] The compiled 'obfs4proxy.exe' binary located at:
echo [ ] "%SCRIPTDIR%..\OpenVPN\obfsproxy\%_ARCH%\obfs4proxy.exe"
