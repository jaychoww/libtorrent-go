CWD=`pwd`
DEST=${CWD}/../build/
CROSS_ROOT=${CWD}/../install/
CROSS_TRIPLE=x86_64-linux-gnu
CC=gcc
CXX=g++

export CROSS_ROOT 
export CROSS_TRIPLE
export CC
export CXX

apt-get update && apt-get -y install \
    bash \
    curl wget \
    pkg-config build-essential make automake autogen libtool \
    libpcre3-dev bison yodl \
    tar xz-utils bzip2 gzip unzip \
    file \
    rsync \
    sed \
    upx

mkdir -p ${DEST}
mkdir -p ${CROSS_ROOT}
cd ${DEST}

# Install Boost.System
cp ${CWD}/scripts/build-boost.sh ${DEST}
export BOOST_CC=gcc
export BOOST_CXX=g++
export BOOST_OS=linux
export BOOST_TARGET_OS=linux
./build-boost.sh

# Install OpenSSL
cp ${CWD}/scripts/build-openssl.sh ${DEST}
export OPENSSL_OPTS=linux-x86_64
./build-openssl.sh

# Install SWIG
cp ${CWD}/scripts/build-swig.sh ${DEST}
./build-swig.sh

# Install Golang
cp ${CWD}/scripts/build-golang.sh ${DEST}
export GOROOT_BOOTSTRAP=${DEST}/go
export GOLANG_CC=${CROSS_TRIPLE}-cc
export GOLANG_CXX=${CROSS_TRIPLE}-g++
export GOLANG_OS=linux
export GOLANG_ARCH=amd64
./build-golang.sh
export PATH=${PATH}:${DEST}/go/bin

# Install libtorrent
cp ${CWD}/scripts/build-libtorrent.sh ${DEST}
export LT_CC=${CROSS_TRIPLE}-gcc
export LT_CXX=${CROSS_TRIPLE}-g++
export LT_CXXFLAGS="-std=c++11 -Wno-psabi"
./build-libtorrent.sh

rm -rf ${DEST}