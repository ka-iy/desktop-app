@ECHO OFF

setlocal

rem TODO: define here dnscrypt-proxy version to build
set _VERSION=2.1.14

set SCRIPTDIR=%~dp0

rem Determine target architecture (x86_64 or arm64). Default: host arch.
if "%~1" == "" (
    if /I "%PROCESSOR_ARCHITECTURE%" == "ARM64" ( set "_ARCH=arm64" ) else ( set "_ARCH=x86_64" )
) else (
    set "_ARCH=%~1"
)

if exist "%SCRIPTDIR%..\dnscrypt-proxy\%_ARCH%" (
  echo [*] Erasing dnscrypt-proxy\%_ARCH%\*.exe ...
  del /f /q "%SCRIPTDIR%..\dnscrypt-proxy\%_ARCH%\dnscrypt-proxy.exe"  >nul 2>&1
) else (
  mkdir "%SCRIPTDIR%..\dnscrypt-proxy\%_ARCH%" || exit /b 1
)

if exist "%SCRIPTDIR%..\.deps\dnscrypt-proxy" (
  echo [*] Erasing '"%SCRIPTDIR%..\.deps\dnscrypt-proxy' ...
  rmdir /s /q "%SCRIPTDIR%..\.deps\dnscrypt-proxy" || exit /b 1
)

echo [*] Creating .deps\dnscrypt-proxy ...
mkdir "%SCRIPTDIR%..\.deps\dnscrypt-proxy" || exit /b 1

echo [*] Cloning dnscrypt-proxy sources...
cd "%SCRIPTDIR%..\.deps\dnscrypt-proxy"
git clone https://github.com/DNSCrypt/dnscrypt-proxy.git || exit /b 1
cd dnscrypt-proxy

echo [*] Checkout version '%_VERSION%' of 'dnscrypt-proxy'..."
git checkout tags/%_VERSION%

echo [*] Compiling dnscrypt-proxy (%_ARCH%) ...

if /I "%_ARCH%" == "arm64" ( set "GOARCH=arm64" ) else ( set "GOARCH=amd64" )
set "GOOS=windows"
go build -o "%SCRIPTDIR%..\dnscrypt-proxy\%_ARCH%\dnscrypt-proxy.exe" -trimpath -ldflags "-s -w" ./dnscrypt-proxy || exit /b 1

echo [ ] SUCCESS
echo [ ] The compiled 'dnscrypt-proxy.exe' binary located at:
echo [ ] "%SCRIPTDIR%..\dnscrypt-proxy\%_ARCH%\dnscrypt-proxy.exe"
