#!/usr/bin/env bash
# Builds zxing-cpp's own command line reader from the submodule into
# build/zxing_reader/. `make accuracy` reads every frame with it as well: where
# it reads a frame and flutter_zxing does not, the fault is in our layer.
#
# ZXingReader includes stb_image_write.h for its -pngout option only. The stub
# below replaces it, so that the build needs no download.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build/zxing_reader"
stb="$out/stb"

mkdir -p "$stb"
cp "$root/third_party/stb/stb_image.h" "$stb/stb_image.h"
cat > "$stb/stb_image_write.h" <<'EOF'
// -pngout is not used by the accuracy bench.
#pragma once
inline int stbi_write_png(const char*, int, int, int, const void*, int) { return 0; }
inline int stbi_write_jpg(const char*, int, int, int, const void*, int) { return 0; }
EOF

cmake -S "$root/third_party/zxing-cpp" -B "$out/cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DZXING_READERS=ON \
  -DZXING_WRITERS=OFF \
  -DZXING_C_API=OFF \
  -DZXING_EXAMPLES=ON \
  -DZXING_EXPERIMENTAL_API=OFF \
  -DZXING_DEPENDENCIES=LOCAL \
  -DSTB_IMAGE_INCLUDE_DIR="$stb" \
  > "$out/configure.log"

cmake --build "$out/cmake" --target ZXingReader --parallel > "$out/build.log"

cp "$out/cmake/example/ZXingReader" "$out/ZXingReader"
"$out/ZXingReader" -version
