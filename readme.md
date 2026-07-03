# IVPN for Desktop (Windows/macOS/Linux)

[![CodeQL](https://github.com/ivpn/desktop-app/actions/workflows/codeql-analysis.yml/badge.svg)](https://github.com/ivpn/desktop-app/actions/workflows/codeql-analysis.yml)
[![Security Scan (gosec)](https://github.com/ivpn/desktop-app/actions/workflows/gosec.yml/badge.svg)](https://github.com/ivpn/desktop-app/actions/workflows/gosec.yml)
[![CI](https://github.com/ivpn/desktop-app/actions/workflows/ci.yml/badge.svg)](https://github.com/ivpn/desktop-app/actions/workflows/ci.yml)
[![ivpn](https://snapcraft.io/ivpn/badge.svg)](https://snapcraft.io/ivpn)

**IVPN for Desktop** is the official IVPN app for desktop platforms. Some of the features include: multiple protocols (OpenVPN, WireGuard), Kill-switch, Multi-Hop, Trusted Networks, AntiTracker, Custom DNS, Dark mode, and more.  
IVPN Client app is distributed on the official site [www.ivpn.net](https://www.ivpn.net).

![IVPN application image](/.github/readme_images/ivpn_app.png#gh-light-mode-only)
![IVPN application image](/.github/readme_images/ivpn_app_dark.png#gh-dark-mode-only)

* [About this Repo](#about-repo)
* [Installation](#installation)
  * [Requirements](#requirements)
    * [Windows](#requirements_windows)
    * [macOS](#requirements_macos)
    * [Linux](#requirements_linux)
  * [Compilation](#compilation)
    * [Windows](#compilation_windows)
    * [macOS](#compilation_macos)
    * [Linux](#compilation_linux)
* [Versioning](#versioning)
* [Contributing](#contributing)
* [Security Policy](#security)
* [License](#license)
* [Authors](#Authors)
* [Acknowledgements](#acknowledgements)

<a name="about-repo"></a>

## About this Repo

This is the official Git repo of the [IVPN for Desktop](https://github.com/ivpn/desktop-app) app.

The project is divided into three parts:  

* **daemon**: Core module of the IVPN software built mostly using the Go language. It runs with privileged rights as a system service/daemon.  
* **UI**: Graphical User Interface built using Electron.  
* **CLI**: Command Line Interface.  

<a name="installation"></a>

## Installation

These instructions enable you to get the project up and running on your local machine for development and testing purposes.

<a name="requirements"></a>

### Requirements

<a name="requirements_windows"></a>

#### Windows

[Go 1.26+](https://golang.org/); Git; [npm](https://www.npmjs.com/get-npm); [Node.js (22.12.0)](https://nodejs.org/); [nsis3](https://nsis.sourceforge.io/Download); Visual Studio 2022 with 'Windows 10 SDK 10.0.19041.0', 'Windows 11 SDK 10.0.22000.0', 'MSVC v143 C++ x64 build tools', 'C++ ATL for latest v143 build tools'; gcc compiler (e.g. [MSYS2 MinGW-w64 UCRT](https://www.msys2.org/)).  

**Additional requirements for ARM64 builds:**  
Visual Studio 2022 individual components (VS Installer > Modify > Individual components):  
- 'MSVC v143 - VS 2022 C++ ARM64 build tools (Latest)'  
- 'C++ ATL for latest v143 build tools (ARM64/ARM64EC)' - required for native DLL (IVPN Helpers Native) ARM64 build  

[llvm-mingw](https://github.com/mstorsjo/llvm-mingw/releases/latest) x86_64-hosted cross-compiler (`llvm-mingw-YYYYMMDD-ucrt-x86_64.zip`) - required for CGO cross-compilation of the daemon (wifiNotifier) targeting ARM64; set the `LLVM_MINGW` environment variable to its root folder.  

<a name="requirements_macos"></a>

#### macOS

[Go 1.26+](https://golang.org/); Git; [npm](https://www.npmjs.com/get-npm); [Node.js (22.12.0)](https://nodejs.org/); Xcode Command Line Tools.  
To compile the OpenVPN/OpenSSL binaries locally, additional packages are required:  
```bash
brew install autoconf automake libtool
```
To compile  [liboqs](https://github.com/open-quantum-safe/liboqs), additional packages are required:  

```bash
brew install cmake ninja openssl@1.1 wget doxygen graphviz astyle valgrind
pip3 install pytest pytest-xdist pyyaml
```

<a name="requirements_linux"></a>

#### Linux

[Go 1.26+](https://golang.org/); Git; [npm](https://www.npmjs.com/get-npm); [Node.js (22.12.0)](https://nodejs.org/); gcc; make; [FPM](https://fpm.readthedocs.io/en/latest/installation.html); curl; rpm; libiw-dev.  

To compile  [liboqs](https://github.com/open-quantum-safe/liboqs), additional packages are required:  
`sudo apt install astyle cmake gcc ninja-build libssl-dev python3-pytest python3-pytest-xdist unzip xsltproc doxygen graphviz python3-yaml valgrind`

**Additional requirements for ARM64 cross-compilation** (on x86_64 host):  
```bash
sudo apt-get install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
sudo dpkg --add-architecture arm64 && sudo apt-get update
sudo apt-get install libssl-dev:arm64 liblz4-dev:arm64 liblzo2-dev:arm64 libpam0g-dev:arm64
```

<a name="compilation"></a>

### Compilation

<a name="compilation_windows"></a>

#### Windows

Instructions to build installer of IVPN Client *(daemon + CLI + UI)*:  
Use **Developer PowerShell for VS 2022** (required for building native sub-projects).  

```powershell
git clone https://github.com/ivpn/desktop-app.git
cd desktop-app/ui/References/Windows

# Compile all binaries (no signing, no installer)
.\build.bat

# Build unsigned installer
.\package-release.ps1
```

Compiled installer can be found at: `ui/References/Windows/bin`  

<a name="compilation_macos"></a>

#### macOS

Instructions to build DMG package of IVPN Client *(daemon + CLI + UI)*:  

```bash
git clone https://github.com/ivpn/desktop-app.git
cd desktop-app/ui/References/macOS

# Build for Apple Silicon (arm64):
ARCH_TARGET=arm64 ./build.sh -c <APPLE_DevID_CERTIFICATE>

# Build for Intel (x86_64):
ARCH_TARGET=x86_64 ./build.sh -c <APPLE_DevID_CERTIFICATE>
```

Compiled DMG files can be found at: `ui/References/macOS/_compiled/`  
- `IVPN-X.X.X-arm64.dmg` — Apple Silicon (M1/M2/M3)  
- `IVPN-X.X.X.dmg` — Intel (x86_64)  

*([some info](https://github.com/ivpn/desktop-app/issues/161) about Apple Developer ID)*  

<a name="compilation_linux"></a>

#### Linux

```bash
# get sources
git clone https://github.com/ivpn/desktop-app.git
cd desktop-app
```

Base package *(daemon + CLI)*:

```bash
# native build (host architecture)
./cli/References/Linux/build.sh

# ARM64 cross-compile (on x86_64 host)
ARCH_TARGET=arm64 ./cli/References/Linux/build.sh
```

Compiled DEB/RPM packages can be found at `cli/References/Linux/_out_bin/<arch>/`  
*Note: You can refer to [manual installation guide for Linux](docs/readme-build-manual.md).*

Graphical User Interface *(UI)*:

```bash
# native build
./ui/References/Linux/build.sh

# ARM64 cross-compile
ARCH_TARGET=arm64 ./ui/References/Linux/build.sh
```

Compiled DEB/RPM packages can be found at `ui/References/Linux/_out_bin/<arch>/`  
*Note: It is required to have installed IVPN Daemon before running IVPN UI.*  

<a name="versioning"></a>

## Versioning

Project is using [Semantic Versioning (SemVer)](https://semver.org) for creating release versions.

SemVer is a 3-component system in the format of `x.y.z` where:

`x` stands for a **major** version  
`y` stands for a **minor** version  
`z` stands for a **patch**

So we have: `Major.Minor.Patch`

<a name="contributing"></a>

## Contributing

If you are interested in contributing to IVPN for Desktop project, please read our [Contributing Guidelines](/.github/CONTRIBUTING.md).

<a name="security"></a>

## Security Policy

If you want to report a security problem, please read our [Security Policy](/.github/SECURITY.md).

<a name="license"></a>

## License

This project is licensed under the GPLv3 - see the [License](/LICENSE.md) file for details.

<a name="Authors"></a>

## Authors

See the [Authors](/AUTHORS) file for the list of contributors who participated in this project.

<a name="acknowledgements"></a>

## Acknowledgements

See the [Acknowledgements](/ACKNOWLEDGEMENTS.md) file for the list of third party libraries used in this project.
