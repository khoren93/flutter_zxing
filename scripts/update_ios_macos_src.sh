#!/usr/bin/env bash

set -euxo pipefail

# This script copies the source files from the src directory to the ios and macos directories.
# Should be run every time the src directory files are updated.

REPO_DIR="$(git rev-parse --show-toplevel)"

SRC_DIR="$REPO_DIR/src"
ZXING_SRC_DIR="$REPO_DIR/src/zxing/core/src"
IOS_SRC_DIR="$REPO_DIR/ios/Classes/src"
MACOS_SRC_PATH="$REPO_DIR/macos/Classes/src"

# Remove the source files if they exist
rm -rf "$IOS_SRC_DIR"
rm -rf "$MACOS_SRC_PATH"

# create the source directories
mkdir -p "$IOS_SRC_DIR"
mkdir -p "$MACOS_SRC_PATH"

# Create a temporary build dir for CMake-generated headers
BUILD_DIR="$REPO_DIR/scripts/build_temp"
mkdir -p "$BUILD_DIR"

# Run CMake to generate Version.h
cmake -S "$ZXING_SRC_DIR/.." -B "$BUILD_DIR"

# Copy the source files, -L follows symlinks, -v is verbose, -a is archive mode (preserves permissions, timestamps, etc.)
rsync -aLv --exclude '*.txt' --exclude "zxing/" "$SRC_DIR/" "$IOS_SRC_DIR/"
rsync -aLv "$ZXING_SRC_DIR/" "$IOS_SRC_DIR/zxing/"

rsync -aLv --exclude '*.txt' --exclude "zxing/" "$SRC_DIR/" "$MACOS_SRC_PATH/"
rsync -aLv "$ZXING_SRC_DIR/" "$MACOS_SRC_PATH/zxing/"

# Copy the generated Version.h to iOS and macOS
cp "$BUILD_DIR/Version.h" "$IOS_SRC_DIR/zxing/"
cp "$BUILD_DIR/Version.h" "$MACOS_SRC_PATH/zxing/"

# Clean up the build_temp directory
rm -rf "$BUILD_DIR"