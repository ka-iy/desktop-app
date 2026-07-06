@ECHO OFF

setlocal

rem TODO: define here version to build
set _VERSION=v5.12.1

set SCRIPTDIR=%~dp0

rem Determine target architecture (x86_64 or arm64). Default: host arch.
if "%~1" == "" (
    if /I "%PROCESSOR_ARCHITECTURE%" == "ARM64" ( set "_ARCH=arm64" ) else ( set "_ARCH=x86_64" )
) else (
    set "_ARCH=%~1"
)

if exist "%SCRIPTDIR%..\v2ray\%_ARCH%" (
  echo [*] Erasing v2ray\%_ARCH%\*.exe ...
  del /f /q "%SCRIPTDIR%..\v2ray\%_ARCH%\v2ray.exe"  >nul 2>&1
) else (
  mkdir "%SCRIPTDIR%..\v2ray\%_ARCH%" || exit /b 1
)

if exist "%SCRIPTDIR%..\.deps\v2ray" (
  echo [*] Erasing '"%SCRIPTDIR%..\.deps\v2ray' ...
  rmdir /s /q "%SCRIPTDIR%..\.deps\v2ray" || exit /b 1
)

echo [*] Creating .deps\v2ray ...
mkdir "%SCRIPTDIR%..\.deps\v2ray" || exit /b 1

echo [*] Cloning V2Ray sources...
cd "%SCRIPTDIR%..\.deps\v2ray"
git clone  --depth 1 --branch %_VERSION% https://github.com/v2fly/v2ray-core.git || exit /b 1
cd v2ray-core/main

echo [*] Compiling V2Ray (%_ARCH%) ...

if /I "%_ARCH%" == "arm64" ( set "GOARCH=arm64" ) else ( set "GOARCH=amd64" )
set "GOOS=windows"
go build -o "%SCRIPTDIR%..\v2ray\%_ARCH%\v2ray.exe" -trimpath -ldflags "-s -w" || exit /b 1

echo [ ] SUCCESS
echo [ ] The compiled 'v2ray.exe' binary located at:
echo [ ] "%SCRIPTDIR%..\v2ray\%_ARCH%\v2ray.exe"
