#!/bin/bash

libfiles=(
ld-linux.so.3
ld-uClibc-0.9.33.2.so
ld-uClibc.so.0
libcharset.so
libcharset.so.1
libcharset.so.1.0.0
libcrypt-0.9.33.2.so
libcrypto.so
libcrypto.so.1.0.0
libcrypt.so
libcrypt.so.0
libc.so
libc.so.0
libcurl.so
libcurl.so.4
libcurl.so.4.3.0
libdl-0.9.33.2.so
libdl.so
libdl.so.0
libgcc_s.so
libgcc_s.so.1
libiconv.so
libiconv.so.2
libiconv.so.2.5.1
libitm.so
libitm.so.1
libitm.so.1.0.0
libitm.spec
libm-0.9.33.2.so
libm.so
libm.so.0
libnsl-0.9.33.2.so
libnsl.so
libnsl.so.0
libpthread-0.9.33.2.so
libpthread.so
libpthread.so.0
libresolv-0.9.33.2.so
libresolv.so
libresolv.so.0
librt-0.9.33.2.so
librt.so
librt.so.0
libssl.so
libssl.so.1.0.0
libssp.so
libssp.so.0
libssp.so.0.0.0
libstdc++.so
libstdc++.so.6
libstdc++.so.6.0.17
libuClibc++-0.2.4.so
libuClibc-0.9.33.2.so
libuClibc++.a
libuClibc++.so
libuClibc++.so.0
libutil-0.9.33.2.so
libutil.so
libutil.so.0
libz.so
libz.so.1
libz.so.1.2.8
)

# Remove existing library directory
rm -rf ./lib

# Make new library directory
mkdir -p ./lib

# Copy the specified library files into the directory
for file in "${libfiles[@]}"
do
   echo $file
   cp -a /usr/local/arm_linux_4.7/arm-none-linux-gnueabi/lib/$file lib
done

# Generate the library romfs
genromfs -f ../../image/lib_romfs.bin -d ./lib

