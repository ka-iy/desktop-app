@echo off

setlocal

set _SCRIPTDIR=%~dp0

rem Determine target architecture (x86_64 or arm64). Default: host arch.
if "%~1" == "" (
    if /I "%PROCESSOR_ARCHITECTURE%" == "ARM64" ( set "_ARCH=arm64" ) else ( set "_ARCH=x86_64" )
) else (
    set "_ARCH=%~1"
)

echo ### Building KEM-helper binaries (%_ARCH%) ###

PUSHD
call %_SCRIPTDIR%..\..\common\kem-helper\build.bat %_SCRIPTDIR%..\.deps %_ARCH% || goto :error
POPD

SET _KEM_BIN_DIR=%_SCRIPTDIR%..\kem\%_ARCH%
    if exist "%_KEM_BIN_DIR%" (
        echo [*] Deleting '%_KEM_BIN_DIR%\*' ...
        rmdir /s /q "%_KEM_BIN_DIR%"
    )

mkdir "%_KEM_BIN_DIR%" || goto :error

copy /Y %_SCRIPTDIR%..\.deps\kem-helper-bin\kem-helper.exe  "%_KEM_BIN_DIR%\kem-helper.exe" || goto :error

set _theResult_binary_path=%_KEM_BIN_DIR%\kem-helper.exe
for %%i in (%_theResult_binary_path%) do set _theResult_binary_path=%%~fi
echo [ ] RESULT BINARY:  %_theResult_binary_path%

:success
	echo [*] Success.    
	exit /b 0

:error
	set ERR=%errorlevel%
    if %ERR% == 0 (
        echo [!] FAILED
	    exit /b 1    
    )
	echo [!] FAILED with error #%ERR%.    
	exit /b %ERR%