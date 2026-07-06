@ECHO OFF

setlocal
set SCRIPTDIR=%~dp0

rem Determine target architecture (x86_64, arm64, or "all"). Default: host arch.
if "%~1" == "" (
    set "_ARCH=all"
    rem if /I "%PROCESSOR_ARCHITECTURE%" == "ARM64" ( set "_ARCH=arm64" ) else ( set "_ARCH=x86_64" )
) else (
    set "_ARCH=%~1"
)

echo ==================================================
echo ============ CLEAN IVPN Service Artifacts ========
echo ==================================================
echo ARCH : %_ARCH%
echo.

if /I "%_ARCH%" == "all" (
    call :clean_arch x86_64
    call :clean_arch arm64
) else if /I "%_ARCH%" == "x86_64"  (
    call :clean_arch %_ARCH%
) else if /I "%_ARCH%" == "arm64"  (
    call :clean_arch %_ARCH%
) else (
    echo [!] Invalid architecture: %_ARCH%
    echo [!] Supported: all, x86_64, arm64
    exit /b 1
)

echo [*] Cleaning .deps ...
if exist "%SCRIPTDIR%..\.deps" rmdir /s /q "%SCRIPTDIR%..\.deps"

echo [*] Done.
exit /b 0

:clean_arch
    set "_A=%~1"
    set "_REF=%SCRIPTDIR%.."
    echo [*] Cleaning %_A% artifacts ...
    if exist "%_REF%\OpenVPN\obfsproxy\%_A%\obfs4proxy.exe"   del /f /q "%_REF%\OpenVPN\obfsproxy\%_A%\obfs4proxy.exe"
    if exist "%_REF%\v2ray\%_A%\v2ray.exe"                    del /f /q "%_REF%\v2ray\%_A%\v2ray.exe"
    if exist "%_REF%\WireGuard\%_A%\wg.exe"                   del /f /q "%_REF%\WireGuard\%_A%\wg.exe"
    if exist "%_REF%\WireGuard\%_A%\wireguard.exe"            del /f /q "%_REF%\WireGuard\%_A%\wireguard.exe"
    if exist "%_REF%\dnscrypt-proxy\%_A%\dnscrypt-proxy.exe"  del /f /q "%_REF%\dnscrypt-proxy\%_A%\dnscrypt-proxy.exe"
    if exist "%_REF%\kem\%_A%\kem-helper.exe"                 del /f /q "%_REF%\kem\%_A%\kem-helper.exe"
    if exist "%_REF%\..\bin\%_A%\IVPN Service.exe"            del /f /q "%_REF%\..\bin\%_A%\IVPN Service.exe"

    rem Native DLL build outputs: shared bin dir and per-project intermediate dirs
    set "_NATIVE=%_REF%\Native Projects"
    if /I "%_A%" == "x86_64" ( set "_MSBUILD_PLATFORM=x64" ) else ( set "_MSBUILD_PLATFORM=ARM64" )
    if exist "%_NATIVE%\bin\Release\%_MSBUILD_PLATFORM%" rmdir /s /q "%_NATIVE%\bin\Release\%_MSBUILD_PLATFORM%"
    if exist "%_NATIVE%\IVPN Firewall Native\%_MSBUILD_PLATFORM%" rmdir /s /q "%_NATIVE%\IVPN Firewall Native\%_MSBUILD_PLATFORM%"
    if exist "%_NATIVE%\IVPN Helpers Native\%_MSBUILD_PLATFORM%" rmdir /s /q "%_NATIVE%\IVPN Helpers Native\%_MSBUILD_PLATFORM%"
    goto :eof
