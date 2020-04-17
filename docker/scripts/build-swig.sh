#!/usr/bin/env bash

set -ex
if [ ! -f "swig-${SWIG_VERSION}.tar.gz" ]; then
  wget -q https://github.com/swig/swig/archive/${SWIG_VERSION}.tar.gz -O swig-${SWIG_VERSION}.tar.gz
fi
tar -xzf swig-${SWIG_VERSION}.tar.gz
rm swig-${SWIG_VERSION}.tar.gz
cd swig-${SWIG_VERSION}/
./autogen.sh
./configure
make -j $(cat /proc/cpuinfo | grep processor | wc -l)
make install
rm -rf `pwd`
