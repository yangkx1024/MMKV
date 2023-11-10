#!/bin/bash

cargo install cargo-expand
# Build static libs
for TARGET in \
        aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-sim \
        x86_64-apple-darwin aarch64-apple-darwin
do
    rustup target add $TARGET
    cargo build -r --target=$TARGET
done

HEADER="include"
mkdir $HEADER
cargo expand clib > $HEADER/mod.rs
cbindgen $HEADER/mod.rs -l C -s tag > $HEADER/rust_mmkv.h
rm $HEADER/mod.rs
touch $HEADER/module.modulemap
echo "module RustMMKV {
  header \"rust_mmkv.h\"
  export *
}" > $HEADER/module.modulemap

# Create XCFramework
FRAMEWORK="ios/MMKV/Sources/RustMMKV.xcframework"
rm -rf $FRAMEWORK
LIBNAME=libmmkv.a
mkdir mac-lipo ios-sim-lipo
IOS_SIM_LIPO=ios-sim-lipo/$LIBNAME
MAC_LIPO=mac-lipo/$LIBNAME
lipo -create -output $IOS_SIM_LIPO \
        target/aarch64-apple-ios-sim/release/$LIBNAME \
        target/x86_64-apple-ios/release/$LIBNAME
lipo -create -output $MAC_LIPO \
        target/aarch64-apple-darwin/release/$LIBNAME \
        target/x86_64-apple-darwin/release/$LIBNAME
xcodebuild -create-xcframework \
        -library $IOS_SIM_LIPO -headers $HEADER \
        -library $MAC_LIPO -headers $HEADER \
        -library target/aarch64-apple-ios/release/$LIBNAME -headers $HEADER \
        -output $FRAMEWORK

# Cleanup
rm -rf ios-sim-lipo mac-lipo $HEADER

