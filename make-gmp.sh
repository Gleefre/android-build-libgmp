#!/bin/sh
set -e

# Download source
version=6.3.0
ext=tar.xz
if [ ! -f gmp-$version.$ext ]; then
    wget https://gmplib.org/download/gmp/gmp-$version.$ext
fi
# Clean old folders if they exist
rm -rf gmp
rm -rf gmp-$version
# Unpack
tar -xf gmp-$version.$ext
mv gmp-$version gmp

# Configure NDK.

if [ -z $NDK ]; then
    echo "Please set NDK path variable." && exit 1
fi

if [ -z $ABI ]; then
    echo "Running adb to determine target ABI..."
    ABI=`adb shell uname -m`
    echo $ABI
fi
case $ABI in
    arm64-v8a) TARGET=aarch64-linux-android ;;
    armeabi-v7a) TARGET=armv7a-linux-androideabi ;;
    x86) TARGET=i686-linux-android ;;
    x86_64) TARGET=x86_64-linux-android ;;
    all)
        ABI=arm64-v8a ./make-gmp.sh
        ABI=armeabi-v7a ./make-gmp.sh
        ABI=x86 ./make-gmp.sh
        ABI=x86_64 ./make-gmp.sh
        echo "Done."
        exit 0 ;;
    *) echo "Unsupported CPU ABI" && exit 1 ;;
esac

case `uname` in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *) echo "Unsupported OS" && exit 1 ;;
esac
TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/$os-x86_64

if [ -z $API ]; then
    echo "Android API not set. Using 21 by default."
    API=21
fi


export AR=$TOOLCHAIN/bin/llvm-ar
export CC=$TOOLCHAIN/bin/$TARGET$API-clang
export AS=$CC
export CXX=$TOOLCHAIN/bin/$TARGET$API-clang++
export LD=$TOOLCHAIN/bin/ld.lld
export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
export STRIP=$TOOLCHAIN/bin/llvm-strip

(
cd gmp ;
ABI= ./configure --disable-static --host $TARGET;
make ;
make check TESTS=
)

# Copy shared library
mkdir -p lib/$ABI
cp gmp/.libs/libgmp.so lib/$ABI
# ...and headers
mkdir -p headers/$ABI
cp gmp/gmp.h headers/$ABI
# ...and tests
mkdir -p tests/$ABI
for file in $(cd gmp/tests; find -name 't-*' -perm /111); do
    dir=$(dirname $file)
    mkdir -p tests/$ABI/$dir
    cp gmp/tests/$file tests/$ABI/$dir
done
