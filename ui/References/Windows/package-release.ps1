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
    [string]$CertSha1 = $env:CERT_SHA1
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
$InstallerTmpDir  = Join-Path $InstallerOutDir 'temp'
$InstallerNsiDir  = Join-Path $ScriptDir 'Installer'
$Sha256ListFile   = Join-Path $InstallerNsiDir 'release-files-SHA256.txt'
$DaemonRefsWin    = Join-Path $PathDaemonRepo 'References\Windows'
$NativeDllsDir    = Join-Path $DaemonRefsWin   'Native Projects\bin\Release'
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

$InstallerFile = Join-Path $InstallerOutDir "IVPN-Client-v${version}.exe"

$Signing = -not [string]::IsNullOrWhiteSpace($CertSha1)

Write-Host "    APPVER       : $version"
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
    Write-Host "    Run this script from 'Developer PowerShell for VS 2022'."
    exit 1
}

if (-not (Test-Path $InstallerTmpDir -PathType Container)) {
    Write-Host "[!] Staging directory not found: $InstallerTmpDir"
    Write-Host "    Run build.bat first to compile and stage all binaries."
    exit 1
}

# ---------------------------------------------------------------------------
# IVPN-owned binaries to sign.
# Vendor pre-signed binaries (OpenVPN, OpenSSL DLLs, TAP driver, devcon) are
# intentionally omitted - re-signing them would invalidate their vendor signatures.
# ---------------------------------------------------------------------------
$DaemonBin   = Join-Path $PathDaemonRepo 'bin\x86_64'
$CliBin      = Join-Path $PathCliRepo    'bin\x86_64\cli'
$OpenVpnRefs = Join-Path $DaemonRefsWin  'OpenVPN'
$WireGuardBin= Join-Path $DaemonRefsWin  'WireGuard\x86_64'

# Each entry: Src = source path used for signtool; TmpRel = relative path inside
# InstallerTmpDir (as laid down by build.bat's copy_files step).
$IvpnBinaries = @(
    [pscustomobject]@{ Src = "$DaemonBin\IVPN Service.exe";                              TmpRel = 'IVPN Service.exe' }
    [pscustomobject]@{ Src = "$CliBin\ivpn.exe";                                         TmpRel = 'cli\ivpn.exe' }
    [pscustomobject]@{ Src = "$OpenVpnRefs\obfsproxy\obfs4proxy.exe";                    TmpRel = 'OpenVPN\obfsproxy\obfs4proxy.exe' }
    [pscustomobject]@{ Src = "$DaemonRefsWin\v2ray\v2ray.exe";                           TmpRel = 'v2ray\v2ray.exe' }
    [pscustomobject]@{ Src = "$DaemonRefsWin\dnscrypt-proxy\dnscrypt-proxy.exe";         TmpRel = 'dnscrypt-proxy\dnscrypt-proxy.exe' }
    [pscustomobject]@{ Src = "$WireGuardBin\wg.exe";                                     TmpRel = 'WireGuard\x86_64\wg.exe' }
    [pscustomobject]@{ Src = "$WireGuardBin\wireguard.exe";                              TmpRel = 'WireGuard\x86_64\wireguard.exe' }
    [pscustomobject]@{ Src = "$DaemonRefsWin\kem\kem-helper.exe";                        TmpRel = 'kem\kem-helper.exe' }
    [pscustomobject]@{ Src = "$NativeDllsDir\IVPN Helpers Native x64.dll";               TmpRel = 'IVPN Helpers Native x64.dll' }
    [pscustomobject]@{ Src = "$NativeDllsDir\IVPN Firewall Native x64.dll";              TmpRel = 'IVPN Firewall Native x64.dll' }
    # Electron UI binary - signed in source location, then the staging copy (already
    # renamed to "IVPN Client.exe" by build.bat) is overwritten with the signed version.
    [pscustomobject]@{ Src = "$UiDistUnpacked\IVPN.exe";                                 TmpRel = 'ui\IVPN Client.exe' }
)

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

    # Phase 1 - Validate all source binaries exist before touching the dongle
    Write-Host "[*] Validating build outputs ..."
    $missing = @()
    foreach ($b in $IvpnBinaries) {
        if (-not (Test-Path $b.Src)) { $missing += $b.Src }
    }
    if ($missing.Count -gt 0) {
        Write-Host ""
        Write-Host "[!] Missing binaries - run build.bat first:"
        $missing | ForEach-Object { Write-Host "      $_" }
        exit 1
    }
    Write-Host "    All binaries present."
    Write-Host ""

    # Phase 2 - Single dongle prompt
    Write-Host "Connect the EV USB dongle, then press Enter to begin signing ..."
    $null = Read-Host
    Write-Host ""

    # Phase 3 - Sign all IVPN-owned binaries in one signtool call (single PIN prompt)
    Write-Host "[*] Signing IVPN binaries ..."
    Invoke-Sign ($IvpnBinaries | ForEach-Object { $_.Src })
    Write-Host ""

    # Phase 4 - Overwrite staging copies with signed versions
    Write-Host "[*] Updating staging directory with signed binaries ..."
    foreach ($b in $IvpnBinaries) {
        $dest = Join-Path $InstallerTmpDir $b.TmpRel
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -Path $b.Src -Destination $dest -Force
        Write-Host "    $($b.TmpRel)"
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# SHA256 checksum verification (vendor files - always run regardless of signing)
# ---------------------------------------------------------------------------
Write-Host "[*] Verifying vendor file checksums ..."
foreach ($line in (Get-Content $Sha256ListFile)) {
    # Format: <relative-path> : <sha256> : <optional comment>
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

$prevLocation = Get-Location
Set-Location $InstallerNsiDir
try {
    & $MAKENSIS /DPRODUCT_VERSION=$version "/DOUT_FILE=$InstallerFile" "/DSOURCE_DIR=$InstallerTmpDir" "IVPN Client.nsi"
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
    Write-Host "[*] Release packaging complete. Signed outputs:"
    Write-Host ""
    foreach ($b in $IvpnBinaries) { Write-Host "  $($b.Src)" }
    Write-Host ""
    Write-Host "  Installer : $InstallerFile"
} else {
    Write-Host "[*] Installer built (unsigned)."
    Write-Host ""
    Write-Host "  Installer : $InstallerFile"
    Write-Host ""
    Write-Host "  NOTE: Binaries and installer are NOT signed."
    Write-Host "        To produce a signed release, set CERT_SHA1 and re-run this script."
}
Write-Host ""


