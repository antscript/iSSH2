#!/bin/sh
                                   #########
#################################### iSSH2 #####################################
#                                  #########                                   #
# Copyright (c) 2013 Tommaso Madonia. All rights reserved.                     #
#                                                                              #
# Permission is hereby granted, free of charge, to any person obtaining a copy #
# of this software and associated documentation files (the "Software"), to deal#
# in the Software without restriction, including without limitation the rights #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell    #
# copies of the Software, and to permit persons to whom the Software is        #
# furnished to do so, subject to the following conditions:                     #
#                                                                              #
# The above copyright notice and this permission notice shall be included in   #
# all copies or substantial portions of the Software.                          #
#                                                                              #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR   #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,     #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,#
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN    #
# THE SOFTWARE.                                                                #
################################################################################

set -e

mkdir -p "${LIBSSLDIR}"

if [ ! -f "${LIBSSLDIR}/openssl-${LIBSSL_VERSION}.tar.gz" ];
then
	echo "Downloading openssl-${LIBSSL_VERSION}.tar.gz"
	curl --progress-bar "http://www.openssl.org/source/openssl-${LIBSSL_VERSION}.tar.gz" > "${LIBSSLDIR}/openssl-${LIBSSL_VERSION}.tar.gz"
else
	echo "openssl-${LIBSSL_VERSION}.tar.gz already exists"
fi

mkdir -p "${LIBSSLDIR}/src/"

set +e
echo "Extracting openssl-${LIBSSL_VERSION}.tar.gz"
tar -zxkf "${LIBSSLDIR}/openssl-${LIBSSL_VERSION}.tar.gz" -C "${LIBSSLDIR}/src" --strip-components 1 2>&-
set -e

LIPO_LIBSSL="lipo -create"
LIPO_LIBCRYPTO="lipo -create"

for ARCH in ${ARCHS}
do
	if [ "${ARCH}" == "i386" -o "${ARCH}" == "x86_64" ];
	then
		PLATFORM="iPhoneSimulator"
	else
		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "${LIBSSLDIR}/src/crypto/ui/ui_openssl.c"
		PLATFORM="iPhoneOS"
	fi

	CONF="no-gost no-asm"

	if [ "${ARCH}" == "arm64" -o "${ARCH}" == "x86_64" ];
	then
		HOST="BSD-generic64"
		CONF="${CONF} enable-ec_nistp_64_gcc_128"
	else
		HOST="BSD-generic32"
	fi

	OPENSSLDIR="${LIBSSLDIR}/${PLATFORM}${SDK_VERSION}-${ARCH}"

	LIPO_LIBSSL="${LIPO_LIBSSL} ${OPENSSLDIR}/lib/libssl.a"
	LIPO_LIBCRYPTO="${LIPO_LIBCRYPTO} ${OPENSSLDIR}/lib/libcrypto.a"

	echo "Building for ${PLATFORM} ${ARCH}, please wait..."
	if [ -f "${OPENSSLDIR}/lib/libssl.a" -a -f "${OPENSSLDIR}/lib/libcrypto.a" ];
	then
		echo "libssl.a and libcrypto.a for ${ARCH} already exist."
		continue
	fi

	rm -rf "${LIBSSLDIR}/tmp/"
	mkdir -p "${LIBSSLDIR}/tmp/"
	cp -R "${LIBSSLDIR}/src/" "${LIBSSLDIR}/tmp/"
	cd "${LIBSSLDIR}/tmp/"

	rm -rf "${OPENSSLDIR}"
	mkdir -p "${OPENSSLDIR}"

	LOG="${OPENSSLDIR}/build-openssl.log"

	export DEVROOT="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export SDKROOT="${DEVROOT}/SDKs/${PLATFORM}${SDK_VERSION}.sdk"
	export CC="${CLANG} -arch ${ARCH}"

	./Configure ${HOST} ${CONF} --openssldir="${OPENSSLDIR}" > "${LOG}" 2>&1

	sed -ie "s!^CFLAG=!CFLAG=-isysroot ${SDKROOT} -miphoneos-version-min=${IPHONEOS_MINVERSION} !" "Makefile"

	make >> "${LOG}" 2>&1
	make install >> "${LOG}" 2>&1
	make clean >> "${LOG}" 2>&1

	echo "Building done."
	cd "${BASEPATH}"
done

echo "Building fat library..."
rm -rf "${BASEPATH}/openssl/lib/"
mkdir -p "${BASEPATH}/openssl/lib/"
eval "${LIPO_LIBSSL} -output ${BASEPATH}/openssl/lib/libssl.a"
eval "${LIPO_LIBCRYPTO} -output ${BASEPATH}/openssl/lib/libcrypto.a"

echo "Copying headers..."
rm -rf "${BASEPATH}/openssl/include/"
mkdir -p "${BASEPATH}/openssl/include/"
cp -RL "${LIBSSLDIR}/src/include/" "${BASEPATH}/openssl/include/"

echo "Cleaning up..."
rm -rf "${LIBSSLDIR}/src/"
rm -rf "${LIBSSLDIR}/tmp/"

echo "Building done."