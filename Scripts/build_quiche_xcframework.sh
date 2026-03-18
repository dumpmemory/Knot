#!/bin/bash
#
# build_quiche_xcframework.sh
# Builds Cloudflare's quiche (QUIC + HTTP/3) as an iOS XCFramework.
#
set -euo pipefail

export PATH="$HOME/.cargo/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORK_DIR="$(mktemp -d)"
OUTPUT_DIR="$PROJECT_ROOT/Frameworks"

echo "=== Building quiche XCFramework ==="

# Step 1: Clone
echo "--- Clone quiche ---"
git clone --depth 1 --recursive https://github.com/cloudflare/quiche.git "$WORK_DIR/quiche" 2>&1 | tail -3
cd "$WORK_DIR/quiche"

# Step 2: Set up iOS SDK paths
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)

# Step 3: Build for iOS device
echo "--- Build for iOS device (aarch64-apple-ios) ---"
export CFLAGS="-isysroot $IOS_SDK"
export CARGO_TARGET_AARCH64_APPLE_IOS_LINKER=$(xcrun --sdk iphoneos --find clang)
export CC_aarch64_apple_ios="$(xcrun --sdk iphoneos --find clang)"
export AR_aarch64_apple_ios="$(xcrun --sdk iphoneos --find ar)"

cargo build \
    --package quiche \
    --release \
    --features ffi \
    --target aarch64-apple-ios \
    2>&1 | tail -5

# Step 4: Build for iOS Simulator
echo "--- Build for iOS Simulator (aarch64-apple-ios-sim) ---"
export CFLAGS="-isysroot $SIM_SDK"
export CARGO_TARGET_AARCH64_APPLE_IOS_SIM_LINKER=$(xcrun --sdk iphonesimulator --find clang)
export CC_aarch64_apple_ios_sim="$(xcrun --sdk iphonesimulator --find clang)"
export AR_aarch64_apple_ios_sim="$(xcrun --sdk iphonesimulator --find ar)"

cargo build \
    --package quiche \
    --release \
    --features ffi \
    --target aarch64-apple-ios-sim \
    2>&1 | tail -5

# Step 5: Prepare headers
echo "--- Prepare headers ---"
HEADER_DIR="$WORK_DIR/headers"
mkdir -p "$HEADER_DIR"
cp quiche/include/quiche.h "$HEADER_DIR/"

cat > "$HEADER_DIR/module.modulemap" << 'MAPEOF'
module CQuiche {
    header "quiche.h"
    link "quiche"
    export *
}
MAPEOF

# Step 6: Create XCFramework
echo "--- Create XCFramework ---"
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR/Quiche.xcframework"

xcodebuild -create-xcframework \
    -library "target/aarch64-apple-ios/release/libquiche.a" \
    -headers "$HEADER_DIR" \
    -library "target/aarch64-apple-ios-sim/release/libquiche.a" \
    -headers "$HEADER_DIR" \
    -output "$OUTPUT_DIR/Quiche.xcframework"

echo "=== Done ==="
find "$OUTPUT_DIR/Quiche.xcframework" -name "*.a" -exec ls -lh {} \;

rm -rf "$WORK_DIR"
