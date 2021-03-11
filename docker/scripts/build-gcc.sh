#! /bin/bash
set -e
trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG
trap 'echo FAILED COMMAND: $previous_command' EXIT

#-------------------------------------------------------------------------------------------
# This script will download packages for, configure, build and install a GCC cross-compiler.
# Customize the variables (INSTALL_PATH, TARGET, etc.) to your liking before running.
# If you get an error and need to resume the script from some point in the middle,
# just delete/comment the preceding lines before running it again.
#
# See: http://preshing.com/20141119/how-to-build-a-gcc-cross-compiler
#-------------------------------------------------------------------------------------------

INSTALL_PATH=/opt/cross
TARGET=${CROSS_TRIPLE}
USE_NEWLIB=0
LINUX_ARCH=arm64
CONFIGURATION_OPTIONS="--disable-multilib" # --disable-threads --disable-shared
PARALLEL_MAKE=-j$(cat /proc/cpuinfo | grep processor | wc -l)
BINUTILS_VERSION=binutils-2.30
GCC_VERSION=gcc-8.1.0
LINUX_KERNEL_VERSION=linux-3.17.2
GLIBC_VERSION=glibc-2.20
MPFR_VERSION=mpfr-3.1.2
GMP_VERSION=gmp-6.0.0a
MPC_VERSION=mpc-1.0.2
ISL_VERSION=isl-0.15
CLOOG_VERSION=cloog-0.18.1
export PATH=$INSTALL_PATH/bin:$PATH

# Download packages
export http_proxy=$HTTP_PROXY https_proxy=$HTTP_PROXY ftp_proxy=$HTTP_PROXY
wget -nc https://ftp.gnu.org/gnu/binutils/$BINUTILS_VERSION.tar.gz
wget -nc https://ftp.gnu.org/gnu/gcc/$GCC_VERSION/$GCC_VERSION.tar.gz
if [ $USE_NEWLIB -ne 0 ]; then
    wget -nc -O newlib-master.zip https://github.com/bminor/newlib/archive/master.zip || true
    unzip -qo newlib-master.zip
else
    wget -nc https://www.kernel.org/pub/linux/kernel/v3.x/$LINUX_KERNEL_VERSION.tar.xz
    wget -nc https://ftp.gnu.org/gnu/glibc/$GLIBC_VERSION.tar.xz
fi
wget -nc https://ftp.gnu.org/gnu/mpfr/$MPFR_VERSION.tar.xz
wget -nc https://ftp.gnu.org/gnu/gmp/$GMP_VERSION.tar.xz
wget -nc https://ftp.gnu.org/gnu/mpc/$MPC_VERSION.tar.gz
wget -nc ftp://gcc.gnu.org/pub/gcc/infrastructure/$ISL_VERSION.tar.bz2
wget -nc ftp://gcc.gnu.org/pub/gcc/infrastructure/$CLOOG_VERSION.tar.gz

# Extract everything
for f in *.tar*; do tar xfk $f; done

# Make symbolic links
cd $GCC_VERSION
ln -sf `ls -1d ../mpfr-*/` mpfr
ln -sf `ls -1d ../gmp-*/` gmp
ln -sf `ls -1d ../mpc-*/` mpc
ln -sf `ls -1d ../isl-*/` isl
ln -sf `ls -1d ../cloog-*/` cloog
cd ..

# Step 1. Binutils
mkdir -p build-binutils
cd build-binutils
../$BINUTILS_VERSION/configure --prefix=$INSTALL_PATH --target=$TARGET $CONFIGURATION_OPTIONS
make $PARALLEL_MAKE
make install
cd ..

# Step 2. Linux Kernel Headers
if [ $USE_NEWLIB -eq 0 ]; then
    cd $LINUX_KERNEL_VERSION
    make ARCH=$LINUX_ARCH INSTALL_HDR_PATH=$INSTALL_PATH/$TARGET headers_install
    cd ..
fi

# Step 3. C/C++ Compilers
mkdir -p build-gcc
cd build-gcc
if [ $USE_NEWLIB -ne 0 ]; then
    NEWLIB_OPTION=--with-newlib
fi
../$GCC_VERSION/configure --prefix=$INSTALL_PATH --target=$TARGET --enable-languages=c,c++ $CONFIGURATION_OPTIONS $NEWLIB_OPTION
make $PARALLEL_MAKE all-gcc
make install-gcc
cd ..

if [ $USE_NEWLIB -ne 0 ]; then
    # Steps 4-6: Newlib
    mkdir -p build-newlib
    cd build-newlib
    ../newlib-master/configure --prefix=$INSTALL_PATH --target=$TARGET $CONFIGURATION_OPTIONS
    make $PARALLEL_MAKE
    make install
    cd ..
else
    # Step 4. Standard C Library Headers and Startup Files
    mkdir -p build-glibc
    cd build-glibc
    ../$GLIBC_VERSION/configure --prefix=$INSTALL_PATH/$TARGET --build=$MACHTYPE --host=$TARGET --target=$TARGET --with-headers=$INSTALL_PATH/$TARGET/include $CONFIGURATION_OPTIONS libc_cv_forced_unwind=yes
    make install-bootstrap-headers=yes install-headers
    make $PARALLEL_MAKE csu/subdir_lib
    install csu/crt1.o csu/crti.o csu/crtn.o $INSTALL_PATH/$TARGET/lib
    $TARGET-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o $INSTALL_PATH/$TARGET/lib/libc.so
    touch $INSTALL_PATH/$TARGET/include/gnu/stubs.h
    cd ..

    # Step 5. Compiler Support Library
    cd build-gcc
    make $PARALLEL_MAKE all-target-libgcc
    make install-target-libgcc
    cd ..

    # Step 6. Standard C Library & the rest of Glibc
    cd build-glibc
    make $PARALLEL_MAKE
    make install
    cd ..
fi

# Step 7. Standard C++ Library & the rest of GCC
cd build-gcc
make $PARALLEL_MAKE all
make install
cd ..

trap - EXIT
echo 'Success!'

# #!/bin/bash
# set -e

# # Based on https://wiki.osdev.org/GCC_Cross-Compiler

# # install prerequisites
# apt-get update
# apt-get install -y curl nasm build-essential bison flex libgmp3-dev libmpc-dev libmpfr-dev texinfo libpthread-dev

# # download and extract sources
# mkdir ~/src && cd ~/src

# curl -s https://ftp.gnu.org/gnu/binutils/binutils-2.30.tar.gz --output binutils-2.30.tar.gz > /dev/null
# curl -s https://ftp.gnu.org/gnu/gcc/gcc-8.1.0/gcc-8.1.0.tar.gz --output gcc-8.1.0.tar.gz > /dev/null
# curl -s https://ftp.gnu.org/gnu/glibc/glibc-2.20.tar.xz --output glibc-2.20.tar.xz > /dev/null

# tar -xf binutils-2.30.tar.gz
# tar -xf gcc-8.1.0.tar.gz
# tar -xf glibc-2.20.tar.xz

# # export variables
# export PREFIX=${CROSS_ROOT}
# export TARGET=${GCC_ARCH}
# export PATH="$PREFIX/bin:$PATH"

# # build binutils 
# cd ~/src

# mkdir build-binutils
# cd build-binutils
# ../binutils-2.30/configure --target=$TARGET --prefix="$PREFIX" --with-sysroot --disable-nls --disable-werror
# make -j $(cat /proc/cpuinfo | grep processor | wc -l)
# make install

# # build gcc
# cd ~/src
 
# # The $PREFIX/bin dir _must_ be in the PATH.
# which -- $TARGET-as || echo $TARGET-as is not in the PATH
 
# mkdir build-gcc
# cd build-gcc
# ../gcc-8.1.0/configure --target=$TARGET --prefix="$PREFIX" --disable-nls --enable-languages=c,c++ --without-headers
# make -j $(cat /proc/cpuinfo | grep processor | wc -l) all-gcc
# make -j $(cat /proc/cpuinfo | grep processor | wc -l) all-target-libgcc
# make install-gcc
# make install-target-libgcc

# # cleanup
# rm -r ~/src

# # Test the new installation
# $TARGET-gcc --version