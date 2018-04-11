#!/bin/bash

#  Automatic build script for libgpg-error 
#  for iPhoneOS and iPhoneSimulator
#
#  Created by Felix Schulze on 30.01.11.
#  Copyright 2010-2015 Felix Schulze. All rights reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
###########################################################################
#  Change values here
#
VERSION="1.28"
#
###########################################################################
#
# Don't change anything here
SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`                                                          
CURRENTPATH=`pwd`
ARCHS="i386 x86_64 armv7 armv7s arm64"
DEVELOPER=`xcode-select -print-path`
OPT_FLAGS="-Os -g3"
MAKE_JOBS=16

##########
set -e
if [ ! -e libgpg-error-${VERSION}.tar.bz2 ]; then
	echo "Downloading libgpg-error-${VERSION}.tar.gz"
    curl -O https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-${VERSION}.tar.bz2
else
	echo "Using libgpg-error-${VERSION}.tar.gz"
fi

mkdir -p bin
mkdir -p lib
mkdir -p src

for ARCH in ${ARCHS}
do
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]];
	then
		PLATFORM="iPhoneSimulator"
		SDK="iphonesimulator"
	else
		PLATFORM="iPhoneOS"
		SDK="iphoneos"
	fi

	echo "Building libgpg-error for ${PLATFORM} ${SDKVERSION} ${ARCH}"
	echo "Please stand by..."
	tar xjf libgpg-error-${VERSION}.tar.bz2 -C src
	cd src/libgpg-error-${VERSION}

	HOST="${ARCH}"
	if [[ "${ARCH}" == "armv7" || "${ARCH}" == "armv7s" ]];
	then
		HOST="arm"
	elif [[ "${ARCH}" == "arm64" ]]; 
	then
		HOST="aarch64"
	fi
	
	ARCH_FLAGS="-arch ${ARCH}"
	HOST_FLAGS="${ARCH_FLAGS} -miphoneos-version-min=8.0 -isysroot $(xcrun -sdk ${SDK} --show-sdk-path)"
	CHOST="${HOST}-apple-darwin"

	PREFIX="${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
	mkdir -p ${PREFIX}

	export CC="$(xcrun -find -sdk ${SDK} cc)"
    export CXX="$(xcrun -find -sdk ${SDK} g++)"
    export CPP="$(xcrun -find -sdk ${SDK} cpp)"
    export CFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
    export CXXFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
    export LDFLAGS="${HOST_FLAGS}"

    ./configure --host=${CHOST} --prefix=${PREFIX} --enable-static --disable-shared

    make clean
    make -j${MAKE_JOBS}
    make install

	cd ${CURRENTPATH}
	rm -rf src/libgpg-error-${VERSION}
	
done


echo "Build library..."
lipo -create ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-i386.sdk/lib/libgpg-error.a ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-x86_64.sdk/lib/libgpg-error.a ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-armv7.sdk/lib/libgpg-error.a ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-armv7s.sdk/lib/libgpg-error.a ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-arm64.sdk/lib/libgpg-error.a  -output ${CURRENTPATH}/lib/libgpg-error.a
mkdir -p ${CURRENTPATH}/include/libgpg-error
cp -R ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-i386.sdk/include/ ${CURRENTPATH}/include/libgpg-error/
echo "Building done."