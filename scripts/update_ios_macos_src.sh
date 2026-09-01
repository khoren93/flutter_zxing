#!/usr/bin/env bash

set -euxo pipefail

# This script copies the source files from the src directory to the ios and macos directories.
# Should be run every time the src directory files are updated.

REPO_DIR="$(git rev-parse --show-toplevel)"

SRC_DIR="$REPO_DIR/src"
ZXING_SRC_DIR="$REPO_DIR/src/zxing/core/src"
IOS_SRC_DIR="$REPO_DIR/ios/flutter_zxing/Sources/flutter_zxing/src"
MACOS_SRC_PATH="$REPO_DIR/macos/flutter_zxing/Sources/flutter_zxing/src"

# Remove the source files if they exist
rm -rf "$IOS_SRC_DIR"
rm -rf "$MACOS_SRC_PATH"

# create the source directories
mkdir -p "$IOS_SRC_DIR"
mkdir -p "$MACOS_SRC_PATH"

# Create a temporary build dir for CMake-generated headers
BUILD_DIR="$REPO_DIR/scripts/build_temp"
mkdir -p "$BUILD_DIR"

# Run CMake to generate Version.h. The options must match src/CMakeLists.txt:
# Version.h is what tells the Apple builds which readers, writers and symbologies
# are compiled in, and zxing-cpp 3.x reads ZXING_ENABLE_* from it in
# BarcodeFormat.h, MultiFormatWriter.cpp and libzint/stubs.c.
cmake -S "$ZXING_SRC_DIR/.." -B "$BUILD_DIR" -DZXING_READERS=ON -DZXING_WRITERS=BOTH

# Files SwiftPM must not see. Unlike CMake, it compiles every source in the
# target directory and exposes every header, so anything conditional upstream
# has to be filtered out here:
#   ZXingQt.h    - includes <QImage> and friends
#   ZXingC.{h,cpp} - the C API, built by CMake only when ZXING_C_API is set
ZXING_EXCLUDES=(--exclude 'ZXingQt.h' --exclude 'ZXingC.h' --exclude 'ZXingC.cpp')

# Copy the source files, -L follows symlinks, -v is verbose, -a is archive mode (preserves permissions, timestamps, etc.)
rsync -aLv --exclude '*.txt' --exclude "zxing/" "$SRC_DIR/" "$IOS_SRC_DIR/"
rsync -aLv "${ZXING_EXCLUDES[@]}" "$ZXING_SRC_DIR/" "$IOS_SRC_DIR/zxing/"

rsync -aLv --exclude '*.txt' --exclude "zxing/" "$SRC_DIR/" "$MACOS_SRC_PATH/"
rsync -aLv "${ZXING_EXCLUDES[@]}" "$ZXING_SRC_DIR/" "$MACOS_SRC_PATH/zxing/"

# core/src/libzint holds one-line forwarders into the nested `zint` submodule
# (`#include "../../../zint/backend/<file>"`), a relative layout that only
# resolves inside a zxing-cpp checkout. Substitute the real sources so the
# copied tree is self-contained. stubs.c is zxing's own file and has no target.
ZINT_BACKEND_DIR="$REPO_DIR/src/zxing/zint/backend"
if [ ! -f "$ZINT_BACKEND_DIR/zint.h" ]; then
    echo "error: $ZINT_BACKEND_DIR is missing." >&2
    echo "       Run: git submodule update --init --recursive" >&2
    exit 1
fi

inline_libzint() {
    local dir="$1/libzint"
    local file target
    while IFS= read -r file; do
        target="$(sed -n '1s|^#include "\.\./\.\./\.\./zint/backend/\(.*\)"$|\1|p' "$file")"
        [ -n "$target" ] || continue
        cp "$ZINT_BACKEND_DIR/$target" "$file"
    done < <(find "$dir" -type f)
}

inline_libzint "$IOS_SRC_DIR/zxing"
inline_libzint "$MACOS_SRC_PATH/zxing"

# Copy the generated Version.h to iOS and macOS
cp "$BUILD_DIR/Version.h" "$IOS_SRC_DIR/zxing/"
cp "$BUILD_DIR/Version.h" "$MACOS_SRC_PATH/zxing/"

# Clean up the build_temp directory
rm -rf "$BUILD_DIR"