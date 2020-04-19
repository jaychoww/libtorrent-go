libtorrent-go 
=============

SWIG Go bindings for libtorrent-rasterbar

Forked from <https://github.com/steeve/libtorrent-go> and <https://github.com/scakemyer/libtorrent-go>


C/C++ Cross compiling environment containers

This has been designed to run `libtorrent-go` cross compilation and is not meant to be perfect nor minimal. Adapt as required.

## Overview

### Environment variables

- CROSS_TRIPLE
- CROSS_ROOT
- LD_LIBRARY_PATH
- PKG_CONFIG_PATH

Also adds CROSS_ROOT/bin in your PATH.

### Installed packages

Based on Debian Stretch:
- bash
- curl
- wget
- pkg-config
- build-essential
- make
- automake
- autogen
- libtool
- libpcre3-dev
- bison
- yodl
- tar
- xz-utils
- bzip2
- gzip
- unzip
- file
- rsync
- sed
- upx

And a selection of platform specific packages (see below).

### Platforms built

- android-arm (android-ndk-r14b with api 19, clang)
- android-arm64 (android-ndk-r14b with api 21, clang)
- android-x64 (android-ndk-r14b with api 21, clang)
- android-x86 (android-ndk-r14b with api 21, clang)
- darwin-x64 (clang-4.0, llvm-4.0-dev, libtool, libxml2-dev, uuid-dev, libssl-dev patch make cpio)
- darwin-x86 (clang-4.0, llvm-4.0-dev, libtool, libxml2-dev, uuid-dev, libssl-dev patch make cpio)
- linux-armv6 (gcc-9 with Musl)
- linux-armv7 (gcc-9 with Musl)
- linux-arm64 (gcc-9 with Musl)
- linux-x64 (gcc-9 with Musl)
- linux-x86 (gcc-9 with Musl)
- windows-x64 (mingw-w64)
- windows-x86 (mingw-w64)

### Software

+ BOOST_VERSION = 1.69.0
+ OPENSSL_VERSION = 1.1.1b
+ SWIG_VERSION = f042543c6f87cd1598495d23e0afa16d2f4775ed
+ GOLANG_VERSION = 1.12.5
+ LIBTORRENT_VERSION = 6f1250c6535730897909240ea0f4f2a81937d21a


# Download and Build

+ First, you need [Docker](https://docs.docker.com/engine/installation/) and [golang](https://golang.org/doc/install)

+ Create Go home folder and set $GOPATH environment variable:

        mkdir ~/go
        export GOPATH=~/go

+ Download libtorrent-go:

        go get github.com/ElementumOrg/libtorrent-go
        cd ~/go/src/github.com/ElementumOrg/libtorrent-go

* Pull the cross-compiler image for your platform:

        make pull PLATFORM=android-arm

+ Next, you need to prepare Docker environments. You can do it with two ways:

        make envs

    This will download and build all needed development packages and could take hours. But it can be necessary if you want to make your own customizations.

    You can also prepare specific environments like so:

        make env PLATFORM=android-arm

+ Build locally without Docker (for local development, for example)
    Is helpful if you need to have all the required stack locally on your OS. 
    By default it's the same as linux-x64.
    Everything is installed in `libtorrent-go/local-env/` directory.

        make local-env

    Then you can run libtorrent-go module compilation
        make re

    It will make sure to use `libtorrent-go/local-env/lib/pkgconfig/` to compile module and have all the dependencies.
        
+ Build libtorrent-go:

        make [ android-arm | android-arm64 | android-x86 | android-x64 |
               linux-x86   | linux-x64     | linux-armv6 | linux-armv7 | linux-arm64 |
               windows-x86 | windows-x64   | 
               darwin-x64  | darwin-x86 ]

    To build libtorrent bindings for all platforms use `make` or specify needed platform, e.g. `make android-arm`.
    Built packages will be placed under `~/go/pkg/<platform>`


Thanks
------
- [steeve](https://github.com/steeve) for his awesome work.
- [dimitriss](https://github.com/dimitriss) for his great updates.
- [scakemyer](https://github.com/scakemyer) for his huge work.
