@ECHO OFF

REM ===========================================================================
REM IVPN Service Build Script for Windows
REM ===========================================================================
REM
REM Builds the IVPN Service and all necessary artifacts with support for
REM cross-compilation (x86_64/arm64)
REM
REM Requirements:
REM   - Visual Studio 2022 with C++ workload
REM   - Go compiler (1.20 or later)
REM   - For x64->arm64 cross-compile: LLVM_MINGW environment variable
REM
REM Usage:
REM   Command Prompt:
REM     build-all.bat [APP_VERSION] [TARGET_ARCH]
REM     build-all.bat 1.2.3 x86_64
REM     build-all.bat 1.2.3 arm64
REM
REM   PowerShell:
REM     .\build-all.bat 1.2.3 x86_64
REM     .\build-all.bat 1.2.3 arm64
REM
REM Parameters:
REM   APP_VERSION    Version string (e.g., 1.2.3). Default: empty
REM   TARGET_ARCH    Target architecture: x86_64 or arm64. Default: host architecture
REM
REM For x64->arm64 cross-compile, LLVM_MINGW environment variable must be set:
REM
REM   Command Prompt:
REM     set "LLVM_MINGW=C:\llvm-mingw" && build-all.bat 1.2.3 arm64
REM
REM   PowerShell:
REM     $env:LLVM_MINGW='C:\llvm-mingw'; .\build-all.bat 1.2.3 arm64
REM
REM   Download LLVM_MINGW: https://github.com/mstorsjo/llvm-mingw/releases/latest
REM
REM ===========================================================================

setlocal

set SCRIPTDIR=%~dp0
set "APPVER=%~1"
rem Update this line if using another version of VisualStudio or it is installed in another location
set _VS_VARS_BAT="C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"

rem Determine target architecture (x86_64 or arm64). Default: host arch.
if "%~2" == "" (
    set "_TARGET_ARCH=x86_64"
    if /I "%PROCESSOR_ARCHITECTURE%" == "ARM64" set "_TARGET_ARCH=arm64"
    if /I "%PROCESSOR_ARCHITEW6432%"  == "ARM64" set "_TARGET_ARCH=arm64"
) else (
    set "_TARGET_ARCH=%~2"
)

echo ==================================================
echo ============ BUILDING IVPN Service ===============
echo ==================================================

rem Initialise VS build environment for the target architecture (native or cross-compile).
call :init_vs_environment || goto :error

set "COMMIT="
set "BUILD_DATE="

rem Getting info about current date
FOR /F "tokens=* USEBACKQ" %%F IN (`date /T`) DO SET BUILD_DATE=%%F
rem remove spaces
set BUILD_DATE=%BUILD_DATE: =%

rem Getting info about commit
cd %SCRIPTDIR%\..\..\..
FOR /F "tokens=* USEBACKQ" %%F IN (`git rev-list -1 HEAD`) DO SET COMMIT=%%F

echo APPVER: %APPVER%
echo COMMIT: %COMMIT%
echo DATE  : %BUILD_DATE%
echo ARCH  : %_TARGET_ARCH%

if "%GITHUB_ACTIONS%" == "true" (
	  echo "! GITHUB_ACTIONS detected ! It is just a build test."
	  echo "! Skipped compilation of Native projects and third-party dependencies: WireGuard, obfs4proxy, dnscrypt_proxy !"
) else (
	call :build_native_libs || goto :error
	call :build_obfs4proxy   || goto :error
	call :build_v2ray        || goto :error
	call :build_wireguard    || goto :error
	call :build_dnscrypt_proxy || goto :error
	call :build_kem_helper   || goto :error
)

call :update_servers_info || goto :error
call :build_agent || goto :error

rem THE END
goto :success

:update_servers_info
	echo [*] Updating servers.json ...
	curl -#fLo %SCRIPTDIR%..\..\common\etc\servers.json https://api.ivpn.net/v5/servers.json || exit /b 1
	goto :eof

:build_agent
	cd "%SCRIPTDIR%..\..\.."
	set "GOOS=windows"

	if /I "%_TARGET_ARCH%" == "arm64" (
		set "GOARCH=arm64"
		set "CGO_ENABLED=1"
		set "CC=%LLVM_MINGW%\bin\aarch64-w64-mingw32-clang.exe"
	) else (
		set "GOARCH=amd64"
		set "CGO_ENABLED="
		set "CC="
	)

	echo [*] Building IVPN service (%_TARGET_ARCH%) ...
	if exist "bin\%_TARGET_ARCH%\IVPN Service.exe" del "bin\%_TARGET_ARCH%\IVPN Service.exe" || exit /b 1

	go build -tags release -o "bin\%_TARGET_ARCH%\IVPN Service.exe" -trimpath -ldflags "-s -w -X github.com/ivpn/desktop-app/daemon/version._version=%APPVER% -X github.com/ivpn/desktop-app/daemon/version._commit=%COMMIT% -X github.com/ivpn/desktop-app/daemon/version._time=%BUILD_DATE%" || exit /b 1

	echo Compiled binary: "bin\%_TARGET_ARCH%\IVPN Service.exe"
	goto :eof

:build_native_libs
	if /I "%_TARGET_ARCH%" == "arm64" ( set "_MSBUILD_PLATFORM=ARM64" ) else ( set "_MSBUILD_PLATFORM=x64" )
	echo [*] Building Native projects %_MSBUILD_PLATFORM%

	if "%GITHUB_ACTIONS%" == "true" (
	  echo "! GITHUB_ACTIONS detected ! It is just a build test."
	  echo "! Skipped compilation of Native projects !"
		goto :eof
	)

	msbuild "%SCRIPTDIR%..\Native Projects\ivpn-windows-native.sln" /verbosity:quiet /t:Build /property:Configuration=Release /property:Platform=%_MSBUILD_PLATFORM% || exit /b 1
	goto :eof

:build_obfs4proxy
	if exist "%SCRIPTDIR%..\OpenVPN\obfsproxy\%_TARGET_ARCH%\obfs4proxy.exe" (
		echo [ ] obfs4proxy binaries already available. Compilation skipped.
		goto :eof
	)

	echo ### obfs4proxy binary not found ###
	echo ### Building obfs4proxy         ###
	call "%SCRIPTDIR%\build-obfs4proxy.bat" %_TARGET_ARCH% || exit /b 1

	goto :eof

:build_v2ray
	if exist "%SCRIPTDIR%..\v2ray\%_TARGET_ARCH%\v2ray.exe" (
		echo [ ] v2ray binaries already available. Compilation skipped.
		goto :eof
	)

	echo ### v2ray binary not found ###
	echo ### Building v2ray         ###
	call "%SCRIPTDIR%\build-v2ray.bat" %_TARGET_ARCH% || exit /b 1

	goto :eof

:build_dnscrypt_proxy
	if exist "%SCRIPTDIR%..\dnscrypt-proxy\%_TARGET_ARCH%\dnscrypt-proxy.exe" (
		echo [ ] dnscrypt-proxy binaries already available. Compilation skipped.
		goto :eof
	)

	echo ### dnscrypt-proxy binary not found ###
	echo ### Building dnscrypt-proxy         ###
	call "%SCRIPTDIR%\build-dnscrypt-proxy.bat" %_TARGET_ARCH% || exit /b 1

	goto :eof

:build_wireguard
	if exist "%SCRIPTDIR%..\WireGuard\x86_64\wg.exe" (
 		if exist "%SCRIPTDIR%..\WireGuard\x86_64\wireguard.exe" (
			if exist "%SCRIPTDIR%..\WireGuard\arm64\wg.exe" (
				if exist "%SCRIPTDIR%..\WireGuard\arm64\wireguard.exe" (
					echo [ ] WireGuard binaries already available. Compilation skipped.
					goto :eof
				)
			)
		)
	)

	echo ### WireGuard binaries not found ###
	call "%SCRIPTDIR%\build-wireguard.bat" || exit /b 1

	goto :eof

:build_kem_helper
	if exist "%SCRIPTDIR%..\kem\%_TARGET_ARCH%\kem-helper.exe" (
		echo [ ] KEM helper already available. Compilation skipped.
		goto :eof
	)

	echo ### KEM-helper binaries not found ###
	call "%SCRIPTDIR%\build-kem-helper.bat" %_TARGET_ARCH% || exit /b 1

	goto :eof

:init_vs_environment
	rem Initialises the VS build environment for the target architecture.
	rem Native builds: skipped if msbuild is already on PATH.
	rem Cross-compile builds: always calls vcvarsall with the cross-compile arg.

	rem Detect true host architecture:
	rem 	PROCESSOR_ARCHITECTURE = 'x86' in 32-bit WOW64 processes and 'AMD64' in 64-bit processes.
	rem 	PROCESSOR_ARCHITEW6432 = 'AMD64' in 32-bit WOW64 processes and undefined in 64-bit processes.
	set "_HOST_ARCH=%PROCESSOR_ARCHITECTURE%"
	if /I "%PROCESSOR_ARCHITEW6432%" == "AMD64" set "_HOST_ARCH=AMD64"
	if /I "%PROCESSOR_ARCHITEW6432%" == "ARM64" set "_HOST_ARCH=ARM64"

	rem Map host/target to vcvarsall argument.
	set "_VC_ARG="
	if /I "%_HOST_ARCH%" == "AMD64"  if /I "%_TARGET_ARCH%" == "x86_64"  set "_VC_ARG=x64"
	if /I "%_HOST_ARCH%" == "AMD64"  if /I "%_TARGET_ARCH%" == "arm64"   set "_VC_ARG=x64_arm64"
	if /I "%_HOST_ARCH%" == "ARM64"  if /I "%_TARGET_ARCH%" == "arm64"   set "_VC_ARG=arm64"
	if /I "%_HOST_ARCH%" == "ARM64"  if /I "%_TARGET_ARCH%" == "x86_64"  set "_VC_ARG=arm64_x64"

	rem For native builds, skip if VS is already configured (msbuild on PATH).
	WHERE msbuild >nul 2>&1
	if not errorlevel 1 (
		if /I "%_VC_ARG%" == "x64"   goto :eof
		if /I "%_VC_ARG%" == "arm64" goto :eof
	)

	rem Validate that vcvarsall.bat is present.
	if not exist %_VS_VARS_BAT% (
		echo [!] msbuild not found and VS not found at:
		echo [!]   %_VS_VARS_BAT%
		echo [!] Install Visual Studio with the 'Desktop development with C++' workload,
		echo [!] update the path in this script, or run from a 'Developer Command Prompt'.
		exit /b 1
	)

	rem Validate LLVM_MINGW for x64->arm64 cross-compile.
	if /I "%_VC_ARG%" == "x64_arm64" (
		if not defined LLVM_MINGW (
			echo [!] LLVM_MINGW environment variable is not set.
			echo [!] Set it to the llvm-mingw install directory ^(e.g. set "LLVM_MINGW=C:\llvm-mingw"^)
			echo [!] Download: https://github.com/mstorsjo/llvm-mingw/releases/latest
			exit /b 1
		)
		if not exist "%LLVM_MINGW%\bin\aarch64-w64-mingw32-clang.exe" (
			echo [!] aarch64-w64-mingw32-clang.exe not found in "%LLVM_MINGW%\bin\"
			exit /b 1
		)
	)

	echo [*] Configuring VS build environment (%_VC_ARG%) ...
	call %_VS_VARS_BAT% %_VC_ARG%
	if not defined INCLUDE (
		echo [!] Failed to initialize VS build environment. Try running from a VS Developer Command Prompt.
		exit /b 1
	)
	goto :eof

:success
	echo [*] Success.
	go version
	exit /b 0

:error
	set ERR=%errorlevel%
	echo [!] IVPN Service build script FAILED with error #%ERR%.
	
	exit /b %ERR%
