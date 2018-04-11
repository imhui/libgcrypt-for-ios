#!/bin/bash

#  Automatic build script for libgcrypt 
#  for iPhoneOS and iPhoneSimulator
#
#  Created by Felix Schulze on 31.01.11.
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
VERSION="1.8.2"
#
###########################################################################
#
# Don't change anything here
SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`                                                          
CURRENTPATH=`pwd`
ARCHS="x86_64 i386 armv7 armv7s arm64"
DEVELOPER=`xcode-select -print-path`
FWNAME="gcrypt"
OPT_FLAGS="-Os -g3"
MAKE_JOBS=16
##########
set -e
if [ ! -e libgcrypt-${VERSION}.tar.bz2 ]; then
	echo "Downloading libgcrypt-${VERSION}.tar.bz2"
    curl -O https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-${VERSION}.tar.bz2
else
	echo "Using libgcrypt-${VERSION}.tar.bz2"
fi

if [ -f ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-i386.sdk/lib/libgpg-error.a ];
then 
  echo "Using libgpg-error"
else
  echo "Please build libgpg-error first"
  exit 1
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
	echo "Building libgcrypt for ${PLATFORM} ${SDKVERSION} ${ARCH}"
	echo "Please stand by..."
	if [[ ! -f ${CURRENTPATH}/src/libgcrypt-${VERSION}/configure ]]; 
		then
		echo 'extract source code'
		tar zxf libgcrypt-${VERSION}.tar.bz2 -C src
		yes | cp -rf ${CURRENTPATH}/inject/libgcrypt/tests/random.c ${CURRENTPATH}/src/libgcrypt-${VERSION}/tests/random.c
	fi
	
	cd src/libgcrypt-${VERSION}
	
	mkdir -p "${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"

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

	# make distclean

	if [ "${ARCH}" == "i386" ];
	then
		./configure --host=${CHOST} --prefix=${PREFIX} --enable-static --disable-shared --disable-aesni-support --with-gpg-error-prefix="${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
	elif [ "${ARCH}" == "x86_64" ];
	then
		./configure --host=${CHOST} --prefix=${PREFIX} --enable-static --disable-shared --disable-asm --disable-aesni-support --with-gpg-error-prefix="${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
	else
		./configure --host=${CHOST} --prefix=${PREFIX} --enable-static --disable-shared --disable-asm --with-gpg-error-prefix="${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
	fi

    make clean
    make -j${MAKE_JOBS} 
    make install 
    make distclean

	cd ${CURRENTPATH}

done

rm -rf src/libgcrypt-${VERSION}

echo "Build library..."
lipo -create ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-i386.sdk/lib/libgcrypt.a ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-x86_64.sdk/lib/libgcrypt.a ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-armv7.sdk/lib/libgcrypt.a ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-armv7s.sdk/lib/libgcrypt.a ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-arm64.sdk/lib/libgcrypt.a -output ${CURRENTPATH}/lib/libgcrypt.a
mkdir -p ${CURRENTPATH}/include/libgcrypt
cp -R ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-i386.sdk/include/gcrypt* ${CURRENTPATH}/include/libgcrypt/

if [ -d $FWNAME.framework ];
then
    echo "Removing previous $FWNAME.framework copy"
    rm -rf $FWNAME.framework
fi

echo "Creating $FWNAME.framework"
mkdir -p $FWNAME.framework/Headers
libtool -no_warning_for_no_symbols -static -o $FWNAME.framework/$FWNAME lib/libgcrypt.a lib/libgpg-error.a
cp -r include/libgcrypt/* $FWNAME.framework/Headers/
cp -r include/libgpg-error/* $FWNAME.framework/Headers/
echo "Created $FWNAME.framework"

echo "Building done."