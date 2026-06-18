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

rem Update this line if using another version of VisualStudio or it is installed in another location
set _VS_VARS_BAT="C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"

echo ==================================================
echo ============ BUILDING IVPN Service ===============
echo ==================================================

rem Getting info about current date
FOR /F "tokens=* USEBACKQ" %%F IN (`date /T`) DO SET DATE=%%F
rem remove spaces
set DATE=%DATE: =%

rem Getting info about commit
cd %SCRIPTDIR%\..\..\..
FOR /F "tokens=* USEBACKQ" %%F IN (`git rev-list -1 HEAD`) DO SET COMMIT=%%F

echo APPVER: %APPVER%
echo COMMIT: %COMMIT%
echo DATE  : %DATE%
echo ARCH  : %_ARCH%

rem Validate llvm-mingw is available for ARM64 CGO builds
if /I "%_ARCH%" == "arm64" (
    if not defined LLVM_MINGW (
        echo [!] LLVM_MINGW environment variable is not set.
        echo [!] Set it to the llvm-mingw install directory ^(e.g. D:\llvm-mingw^)
        echo [!] Download: https://github.com/mstorsjo/llvm-mingw/releases/latest
        goto :error
    )
    if not exist "%LLVM_MINGW%\bin\aarch64-w64-mingw32-clang.exe" (
        echo [!] aarch64-w64-mingw32-clang.exe not found in "%LLVM_MINGW%\bin\"
        goto :error
    )
)

rem Checking if msbuild available
WHERE msbuild >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
	echo [!] 'msbuild' is not recognized as an internal or external command
	echo [!] Ensure you are running this script from Developer Command Prompt for Visual Studio

	if not defined VSCMD_VER (
		if not exist %_VS_VARS_BAT% (
			echo [!] File '%_VS_VARS_BAT%' not exists!
			echo [!] Please install Visual Studio or update file location in '%~f0'
			goto :error
		)
		set TARGET_ARCH=%_ARCH%
		call :get_vcvarsall_arg
		echo [*] Initialising VS build environment ^(%_VC_ARG%^) ...
		call %_VS_VARS_BAT% %_VC_ARG% || goto :error
	) else (
		goto :error
	)
)

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

	if /I "%_ARCH%" == "arm64" (
		set "GOARCH=arm64"
		set "CGO_ENABLED=1"
		set "CC=%LLVM_MINGW%\bin\aarch64-w64-mingw32-clang.exe"
	) else (
		set "GOARCH=amd64"
		set "CGO_ENABLED="
		set "CC="
	)

	echo [*] Building IVPN service (%_ARCH%) ...
	if exist "bin\%_ARCH%\IVPN Service.exe" del "bin\%_ARCH%\IVPN Service.exe" || exit /b 1

	go build -tags release -o "bin\%_ARCH%\IVPN Service.exe" -trimpath -ldflags "-s -w -X github.com/ivpn/desktop-app/daemon/version._version=%APPVER% -X github.com/ivpn/desktop-app/daemon/version._commit=%COMMIT% -X github.com/ivpn/desktop-app/daemon/version._time=%DATE%" || exit /b 1

	echo Compiled binary: "bin\%_ARCH%\IVPN Service.exe"
	goto :eof

:build_native_libs
	if /I "%_ARCH%" == "arm64" ( set "_MSBUILD_PLATFORM=ARM64" ) else ( set "_MSBUILD_PLATFORM=x64" )
	echo [*] Building Native projects %_MSBUILD_PLATFORM%

	if "%GITHUB_ACTIONS%" == "true" (
	  echo "! GITHUB_ACTIONS detected ! It is just a build test."
	  echo "! Skipped compilation of Native projects !"
		goto :eof
	)

	msbuild "%SCRIPTDIR%..\Native Projects\ivpn-windows-native.sln" /verbosity:quiet /t:Build /property:Configuration=Release /property:Platform=%_MSBUILD_PLATFORM% || exit /b 1
	goto :eof

:build_obfs4proxy
	if exist "%SCRIPTDIR%..\OpenVPN\obfsproxy\%_ARCH%\obfs4proxy.exe" (
		echo [ ] obfs4proxy binaries already available. Compilation skipped.
		goto :eof
	)

	echo ### obfs4proxy binary not found ###
	echo ### Building obfs4proxy         ###
	call "%SCRIPTDIR%\build-obfs4proxy.bat" %_ARCH% || goto error

	goto :eof

:build_v2ray
	if exist "%SCRIPTDIR%..\v2ray\%_ARCH%\v2ray.exe" (
		echo [ ] v2ray binaries already available. Compilation skipped.
		goto :eof
	)

	echo ### v2ray binary not found ###
	echo ### Building v2ray         ###
	call "%SCRIPTDIR%\build-v2ray.bat" %_ARCH% || goto error

	goto :eof

:build_dnscrypt_proxy
	if exist "%SCRIPTDIR%..\dnscrypt-proxy\%_ARCH%\dnscrypt-proxy.exe" (
		echo [ ] dnscrypt-proxy binaries already available. Compilation skipped.
		goto :eof
	)

	echo ### dnscrypt-proxy binary not found ###
	echo ### Building dnscrypt-proxy         ###
	call "%SCRIPTDIR%\build-dnscrypt-proxy.bat" %_ARCH% || goto error

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
	call "%SCRIPTDIR%\build-wireguard.bat" || goto error

	goto :eof

:build_kem_helper
	if exist "%SCRIPTDIR%..\kem\%_ARCH%\kem-helper.exe" (
		echo [ ] KEM helper already available. Compilation skipped.
		goto :eof
	)

	echo ### KEM-helper binaries not found ###
	call "%SCRIPTDIR%\build-kem-helper.bat" %_ARCH% || goto error

	goto :eof

:get_vcvarsall_arg
	rem Sets _VC_ARG based on TARGET_ARCH and host architecture (%PROCESSOR_ARCHITECTURE%)
	if /I "%PROCESSOR_ARCHITECTURE%" == "ARM64" (
		if /I "%TARGET_ARCH%" == "arm64" ( set _VC_ARG=arm64     ) else ( set _VC_ARG=arm64_x64 )
	) else (
		if /I "%TARGET_ARCH%" == "arm64" ( set _VC_ARG=x64_arm64 ) else ( set _VC_ARG=x64       )
	)
	goto :eof

:success
	echo [*] Success.
	go version
	exit /b 0

:error
	set ERR=%errorlevel%
	echo [!] IVPN Service build script FAILED with error #%errorlevel%.
	rem echo [!] Removing files:
	rem echo [ ] "%SCRIPTDIR%..\OpenVPN\obfsproxy\obfs4proxy.exe"
	rem echo [ ] "%SCRIPTDIR%..\WireGuard\x86_64\wg.exe"
	rem echo [ ] "%SCRIPTDIR%..\WireGuard\x86_64\wireguard.exe"
	rem del "%SCRIPTDIR%..\OpenVPN\obfsproxy\obfs4proxy.exe"
	rem del "%SCRIPTDIR%..\WireGuard\x86_64\wg.exe"
	rem del "%SCRIPTDIR%..\WireGuard\x86_64\wireguard.exe"

	exit /b %ERR%
