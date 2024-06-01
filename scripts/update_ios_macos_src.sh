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

# Copy the source files
rsync -av --exclude '*.txt' --exclude "zxing/" "$SRC_DIR/" "$IOS_SRC_DIR/"
rsync -av "$ZXING_SRC_DIR/" "$IOS_SRC_DIR/zxing/"

rsync -av --exclude '*.txt' --exclude "zxing/" "$SRC_DIR/" "$MACOS_SRC_PATH/"
rsync -av "$ZXING_SRC_DIR/" "$MACOS_SRC_PATH/zxing/"
