#!/usr/bin/env bash

set -ex

if [ ! -f "llvmorg-${LLVM_VERSION}.tar.gz" ]; then
  wget -q https://github.com/llvm/llvm-project/archive/llvmorg-${LLVM_VERSION}.tar.gz
fi
tar -xzf llvmorg-${LLVM_VERSION}.tar.gz

cd llvm-project-llvmorg-${LLVM_VERSION}

cp -rf clang llvm/tools/

mkdir -p build_llvm && cd build_llvm
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DLLVM_BUILD_DOCS=OFF -DCMAKE_INSTALL_PREFIX=${CROSS_ROOT} -DCMAKE_CROSSCOMPILING=True -DLLVM_DEFAULT_TARGET_TRIPLE=${CROSS_TRIPLE} -DLLVM_TARGET_ARCH=${LLVM_ARCH} -DLLVM_TARGETS_TO_BUILD=${LLVM_ARCH} ../llvm
ninja
ninja install

ls -la ${CROSS_ROOT}/bin/

PATH=${CROSS_ROOT}/bin:$PATH
LD_LIBRARY_PATH=${CROSS_ROOT}/lib:$LD_LIBRARY_PATH

cd ..
mkdir -p build_libcxxabi && cd build_libcxxabi
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${CROSS_ROOT} -DLLVM_TARGETS_TO_BUILD=${LLVM_ARCH} -DCMAKE_C_COMPILER=${CROSS_ROOT}/bin/clang -DCMAKE_CXX_COMPILER=${CROSS_ROOT}/bin/clang++ ../libcxxabi
ninja
ninja install

ls -la ${CROSS_ROOT}/bin/

cd ..
mkdir -p build_libcxx && cd build_libcxx
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${CROSS_ROOT} -DLLVM_TARGETS_TO_BUILD=${LLVM_ARCH} -DCMAKE_C_COMPILER=${CROSS_ROOT}/bin/clang -DCMAKE_CXX_COMPILER=${CROSS_ROOT}/bin/clang++ ../libcxx
ninja
ninja install

ls -la ${CROSS_ROOT}/bin/

cd ..
mkdir -p build_openmp && cd build_openmp
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${CROSS_ROOT} -DCMAKE_C_COMPILER=${CROSS_ROOT}/bin/clang -DCMAKE_CXX_COMPILER=${CROSS_ROOT}/bin/clang++ -DLIBOMP_ARCH=${LLVM_ARCH} ../openmp
ninja
ninja install

ls -la ${CROSS_ROOT}/bin/

# if [ ! -f "boost_${BOOST_VERSION_FILE}.tar.bz2" ]; then
#   wget -q https://dl.bintray.com/boostorg/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION_FILE}.tar.bz2
# fi
# echo "$BOOST_SHA256  boost_${BOOST_VERSION_FILE}.tar.bz2" | sha256sum -c -
# tar -xjf boost_${BOOST_VERSION_FILE}.tar.bz2
# rm boost_${BOOST_VERSION_FILE}.tar.bz2
# cd boost_${BOOST_VERSION_FILE}/
# ./bootstrap.sh --prefix=${CROSS_ROOT} ${BOOST_BOOTSTRAP_OPTS}
# echo "using ${BOOST_CC} : ${BOOST_OS} : ${CROSS_TRIPLE}-${BOOST_CXX} ${BOOST_FLAGS} ;" > ${HOME}/user-config.jam
# ./b2 --with-date_time --with-system --with-chrono --with-random --prefix=${CROSS_ROOT} toolset=${BOOST_CC}-${BOOST_OS} ${BOOST_OPTS} link=static variant=release threading=multi target-os=${BOOST_TARGET_OS} install 1>/dev/null 2>/dev/null
# rm -rf ${HOME}/user-config.jam
# rm -rf `pwd`
