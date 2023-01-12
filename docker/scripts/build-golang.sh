#!/usr/bin/env bash
set -ex

scripts_path=$(dirname "$(readlink -f "$0")")
source "${scripts_path}/common.sh"

mkdir -p ${CROSS_ROOT}/bootstrap
# install go
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.17.5.linux-arm64.tar.gz
export PATH=$PATH:/usr/local/go/bin
# build bootstrap


#cd ${CROSS_ROOT}/bootstrap/go/src
# run ./make.bash

cd /build
if [ ! -f "golang.tar.gz" ]; then
  wget -q "https://golang.org/dl/go${GOLANG_VERSION}.src.tar.gz" -O golang.tar.gz
fi
echo "$GOLANG_SRC_SHA256  golang.tar.gz" | sha256sum -c -
tar -C ${CROSS_ROOT} -xzf golang.tar.gz
rm golang.tar.gz
mkdir ${CROSS_ROOT}/go/script
cd ${CROSS_ROOT}/go/script
cp /build/bootstrap.bash ./

GOOS=${GOLANG_OS} GOARCH=${GOLANG_ARCH} ./bootstrap.bash
export GOROOT_BOOTSTRAP=${CROSS_ROOT}/go-darwin-arm64-bootstrap

# run ./make.bash

 cd ${CROSS_ROOT}/go/src
CC_FOR_TARGET=${GOLANG_CC} \
  CXX_FOR_TARGET=${GOLANG_CXX} \
  GOOS=${GOLANG_OS} \
  GOARCH=${GOLANG_ARCH} \
  GOARM=${GOLANG_ARM} \
  CGO_ENABLED=1 \
  ./make.bash --no-clean
rm -rf ${CROSS_ROOT}/bootstrap ${CROSS_ROOT}/go/pkg/bootstrap
