#Requires -Version 5.1
<#
.SYNOPSIS
    Builds the NSIS installer; optionally signs all IVPN-owned binaries and the
    installer when CERT_SHA1 is set.

.DESCRIPTION
    Must be run AFTER build.bat has produced a complete staged output in
    ui/References/Windows/bin/temp/.

    Modes
    -----
    Unsigned (CERT_SHA1 not set):
      - Verifies SHA256 checksums of vendor files
      - Runs makensis to build unsigned installer
      - Prints a notice that binaries and installer are not signed

    Signed (CERT_SHA1 set via env var or -CertSha1 parameter):
      - Validates all expected binaries exist
      - Prompts once to connect EV USB dongle
      - Signs all IVPN-owned binaries via signtool
      - Verifies SHA256 checksums of vendor files
      - Verifies all staged .exe signatures
      - Runs makensis to build installer from signed binaries
      - Signs the installer
      - Prints summary of signed outputs

    Does NOT re-sign vendor pre-signed binaries (OpenVPN, OpenSSL DLLs,
    TAP driver, devcon).

.PARAMETER CertSha1
    SHA1 thumbprint of the EV code-signing certificate.
    Overrides the CERT_SHA1 environment variable when provided.

.EXAMPLE
    # Unsigned installer only:
    .\package-release.ps1

.EXAMPLE
    # Signed release via env var:
    $env:CERT_SHA1 = 'abcd1234...'
    .\package-release.ps1

.EXAMPLE
    # Signed release via parameter:
    .\package-release.ps1 -CertSha1 'abcd1234...'
#>

param(
    [string]$CertSha1 = $env:CERT_SHA1,
    [ValidateSet('x86_64', 'arm64')]
    [string]$Arch = 'x86_64'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ===========================================================================
# CONFIG - update MAKENSIS path if NSIS is installed in a non-default location.
# TIMESTAMP_SERVER may be changed to an alternative RFC 3161 server.
# ===========================================================================

# CONFIG: Full path to the NSIS makensis compiler.
$MAKENSIS = 'C:\Program Files (x86)\NSIS\makensis.exe'

# CONFIG: RFC 3161 timestamp server URL.
$TIMESTAMP_SERVER = 'http://timestamp.digicert.com'

# ===========================================================================

# ---------------------------------------------------------------------------
# Resolve paths (this script lives in ui/References/Windows/)
# ---------------------------------------------------------------------------
$ScriptDir      = $PSScriptRoot
$PathUiRepo     = [System.IO.Path]::GetFullPath("$ScriptDir\..\..")
$PathDaemonRepo = [System.IO.Path]::GetFullPath("$PathUiRepo\..\daemon")
$PathCliRepo    = [System.IO.Path]::GetFullPath("$PathUiRepo\..\cli")

$PackageJson      = Join-Path $PathUiRepo 'package.json'
$InstallerOutDir  = Join-Path $ScriptDir 'bin'
$InstallerNsiDir  = Join-Path $ScriptDir 'Installer'
$DaemonRefsWin    = Join-Path $PathDaemonRepo 'References\Windows'
$NativeDllsDir    = Join-Path $DaemonRefsWin   'Native Projects\bin\Release\x64'
$UiDistUnpacked   = Join-Path $PathUiRepo       'dist\win-unpacked'

# ---------------------------------------------------------------------------
# Read version
# ---------------------------------------------------------------------------
if (-not (Test-Path $PackageJson)) {
    Write-Host "[!] package.json not found: $PackageJson"; exit 1
}
$version = (Get-Content $PackageJson -Raw | ConvertFrom-Json).version
if ([string]::IsNullOrWhiteSpace($version)) {
    Write-Host "[!] Could not read 'version' from $PackageJson"; exit 1
}

$InstallerFile = if ($Arch -eq 'arm64') {
    Join-Path $InstallerOutDir "IVPN-Client-v${version}-arm64.exe"
} else {
    Join-Path $InstallerOutDir "IVPN-Client-v${version}.exe"
}

$InstallerTmpDir = if ($Arch -eq 'arm64') {
    Join-Path $InstallerOutDir 'temp-arm64'
} else {
    Join-Path $InstallerOutDir 'temp'
}

$Sha256ListFile = if ($Arch -eq 'arm64') {
    Join-Path $InstallerNsiDir 'release-files-SHA256-arm64.txt'
} else {
    Join-Path $InstallerNsiDir 'release-files-SHA256.txt'
}

$Signing = -not [string]::IsNullOrWhiteSpace($CertSha1)

Write-Host "    APPVER       : $version"
Write-Host "    ARCH         : $Arch"
Write-Host "    CERT_SHA1    : $(if ($Signing) { $CertSha1 } else { '(not set - unsigned build)' })"
Write-Host ""

# ---------------------------------------------------------------------------
# Validate prerequisites
# ---------------------------------------------------------------------------
if (-not (Test-Path $MAKENSIS)) {
    Write-Host "[!] NSIS not found: $MAKENSIS"
    Write-Host "    Install NSIS from https://nsis.sourceforge.io/ or update `$MAKENSIS in this script."
    exit 1
}

if ($Signing -and -not (Get-Command signtool -ErrorAction SilentlyContinue)) {
    Write-Host "[!] 'signtool' not found in PATH."
    Write-Host "    Run this script from 'Developer PowerShell for VS'."
    exit 1
}

if (-not (Test-Path $InstallerTmpDir -PathType Container)) {
    Write-Host "[!] Staging directory not found: $InstallerTmpDir"
    Write-Host "    Run build.bat first to compile and stage all binaries."
    exit 1
}

# ---------------------------------------------------------------------------
# Validate all required files from manifest are staged
# ---------------------------------------------------------------------------
function Test-StagedFiles {
    param([string]$ManifestFile, [string]$StagingDir, [string]$TargetArch)
    
    Write-Host "[*] Validating staged files from manifest ..."
    $missing = @()
    $validated = 0
    
    foreach ($line in (Get-Content $ManifestFile)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith(';')) { continue }
        
        # Handle arch-specific lines: [x86_64] or [arm64]
        $archFilter = $null
        if ($line -match '^\[(x86_64|arm64)\]\s+(.+)$') {
            $archFilter = $Matches[1]
            $line = $Matches[2]
            if ($archFilter -ne $TargetArch) { continue }
        }
        
        # Parse DEST[=SOURCE] format - we only care about DEST
        $dest = ($line -split '=', 2)[0].Trim()
        if ([string]::IsNullOrWhiteSpace($dest)) { continue }
        
        $validated++
        $filePath = Join-Path $StagingDir $dest
        if (-not (Test-Path $filePath)) {
            $missing += $dest
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-Host ""
        Write-Host "[!] Missing files in staging directory:"
        $missing | ForEach-Object { Write-Host "      $_" }
        Write-Host ""
        Write-Host "    Run build.bat first to stage all required files."
        return $false
    }
    
    $fileCount = (Get-ChildItem $StagingDir -Recurse -File | Measure-Object).Count
    Write-Host "    All required files present ($validated validated, $fileCount files total)."
    return $true
}

$ManifestFile = Join-Path $InstallerNsiDir 'release-manifest.txt'
if (-not (Test-StagedFiles -ManifestFile $ManifestFile -StagingDir $InstallerTmpDir -TargetArch $Arch)) {
    exit 1
}
Write-Host ""

# ---------------------------------------------------------------------------
# Binaries to sign in the staging directory.
# All IVPN-compiled binaries (including vendor tools built from source) are signed.
# Only truly pre-compiled (and pre-signed) binaries are excluded.
# ---------------------------------------------------------------------------
# Helper function to build list of binaries to sign in staging directory.
function Get-BinariesToSign {
    return @(
        Join-Path $InstallerTmpDir 'IVPN Service.exe'
        Join-Path $InstallerTmpDir 'cli\ivpn.exe'
        Join-Path $InstallerTmpDir 'OpenVPN\obfsproxy\obfs4proxy.exe'
        Join-Path $InstallerTmpDir 'v2ray\v2ray.exe'
        Join-Path $InstallerTmpDir 'dnscrypt-proxy\dnscrypt-proxy.exe'
        Join-Path $InstallerTmpDir 'WireGuard\wg.exe'
        Join-Path $InstallerTmpDir 'WireGuard\wireguard.exe'
        Join-Path $InstallerTmpDir 'kem\kem-helper.exe'
        Join-Path $InstallerTmpDir 'IVPN Helpers Native.dll'
        Join-Path $InstallerTmpDir 'IVPN Firewall Native.dll'
        Join-Path $InstallerTmpDir 'ui\IVPN Client.exe'
    )
}

$BinariesToSign = Get-BinariesToSign

# ---------------------------------------------------------------------------
# Helper: sign one or more files in a single signtool invocation.
# Passing all paths at once means the PIN is requested only once.
# ---------------------------------------------------------------------------
function Invoke-Sign([string[]]$FilePaths) {
    foreach ($f in $FilePaths) { Write-Host "  [>] $f" }
    signtool.exe sign /tr $TIMESTAMP_SERVER /td sha256 /fd sha256 /sha1 $CertSha1 /v $FilePaths
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] signtool failed."
        exit $LASTEXITCODE
    }
}

# ---------------------------------------------------------------------------
# SIGNED path
# ---------------------------------------------------------------------------
if ($Signing) {

    # Phase 1 - Validate all staged binaries exist before touching the dongle
    Write-Host "[*] Validating binaries to sign ..."
    $missing = @()
    foreach ($file in $BinariesToSign) {
        if (-not (Test-Path $file)) { $missing += $file }
    }
    if ($missing.Count -gt 0) {
        Write-Host ""
        Write-Host "[!] Missing binaries to sign - run build.bat first:"
        $missing | ForEach-Object { Write-Host "      $_" }
        exit 1
    }
    Write-Host "    All binaries to sign are present."
    Write-Host ""

    # Phase 2 - Single dongle prompt
    Write-Host "Connect the EV USB dongle, then press Enter to begin signing ..."
    $null = Read-Host
    Write-Host ""

    # Phase 3 - Sign IVPN-built binaries directly in staging (single PIN prompt)
    Write-Host "[*] Signing IVPN binaries in staging directory ..."
    Invoke-Sign $BinariesToSign
    Write-Host ""
}

# ---------------------------------------------------------------------------
# SHA256 checksum verification (vendor files - always run regardless of signing)
# ---------------------------------------------------------------------------
Write-Host "[*] Verifying vendor file checksums ..."
foreach ($line in (Get-Content $Sha256ListFile)) {
    # Format: <relative-path> : <sha256> : <optional comment>
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line.TrimStart().StartsWith(';'))    { continue }
    $parts = $line -split '\s*:\s*', 3
    if ($parts.Count -lt 2) { continue }
    $relPath  = $parts[0].Trim()
    $expected = $parts[1].Trim()
    if ([string]::IsNullOrWhiteSpace($relPath) -or [string]::IsNullOrWhiteSpace($expected)) { continue }

    $filePath = Join-Path $InstallerTmpDir $relPath
    if (-not (Test-Path $filePath)) {
        Write-Host "[!] File not found for checksum verification: $filePath"; exit 1
    }

    $actual = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $expected.ToLower()) {
        Write-Host "[!] Checksum mismatch: $relPath"
        Write-Host "    expected : $expected"
        Write-Host "    actual   : $actual"
        exit 1
    }
    Write-Host "    [ ] OK: $relPath"
}
Write-Host ""

# ---------------------------------------------------------------------------
# Signature verification of all staged .exe files (signed path only)
# ---------------------------------------------------------------------------
if ($Signing) {
    Write-Host "[*] Verifying staged binary signatures ..."
    $signErrors = @()
    Get-ChildItem -Path $InstallerTmpDir -Filter '*.exe' -Recurse | ForEach-Object {
        signtool.exe verify /pa $_.FullName > $null 2>&1
        if ($LASTEXITCODE -ne 0) { $signErrors += $_.FullName }
    }
    if ($signErrors.Count -gt 0) {
        Write-Host "[!] Signature verification FAILED for:"
        $signErrors | ForEach-Object { Write-Host "      $_" }
        exit 1
    }
    Write-Host "    All staged signatures valid."
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Build NSIS installer
# ---------------------------------------------------------------------------
Write-Host "[*] Building installer ..."
if (Test-Path $InstallerFile) { Remove-Item $InstallerFile -Force }

$nsisArgs = @(
    "/DPRODUCT_VERSION=$version",
    "/DOUT_FILE=$InstallerFile",
    "/DSOURCE_DIR=$InstallerTmpDir"
)
if ($Arch -eq 'arm64') {
    $nsisArgs += '/DTARGET_ARCH=arm64'
    $nsisArgs += '/DTARGET_ARM64'
}

$prevLocation = Get-Location
Set-Location $InstallerNsiDir
try {
    & $MAKENSIS @nsisArgs "IVPN Client.nsi"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] NSIS failed (exit code $LASTEXITCODE)."; exit $LASTEXITCODE
    }
} finally {
    Set-Location $prevLocation
}

if (-not (Test-Path $InstallerFile)) {
    Write-Host "[!] Installer not produced: $InstallerFile"; exit 1
}
Write-Host ""

# ---------------------------------------------------------------------------
# Sign installer (signed path only)
# ---------------------------------------------------------------------------
if ($Signing) {
    Write-Host "[*] Signing installer ..."
    Invoke-Sign @($InstallerFile)
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if ($Signing) {
    Write-Host "[*] Release packaging complete. Signed IVPN-built binaries:"
    Write-Host ""
    foreach ($file in $BinariesToSign) { Write-Host "  $file" }
    Write-Host ""
    Write-Host "  Installer ($Arch) : $InstallerFile"
} else {
    Write-Host "[*] Installer built (unsigned)."
    Write-Host ""
    Write-Host "  Installer ($Arch) : $InstallerFile"
    Write-Host ""
    Write-Host "  NOTE: Binaries and installer are NOT signed."
    Write-Host "        To produce a signed release, set CERT_SHA1 and re-run this script."
}
Write-Host ""


