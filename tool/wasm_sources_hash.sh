#!/usr/bin/env bash
# Prints a hash of everything the WebAssembly modules are built from: the fzx
# sources, the pinned zxing-cpp and zint commits, stb_image and the
# Emscripten version. tool/build_wasm.sh embeds it in the generated JS and
# skips the build when it has not changed.
set -euo pipefail
cd "$(dirname "$0")/.."
source tool/wasm_config.sh

sha() { if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi; }

{
  echo "emscripten $FZX_EMSCRIPTEN_VERSION"
  # Commits as recorded in this repository, so the hash does not depend on
  # whether the submodules are checked out.
  git ls-files -s third_party/zxing-cpp | awk '{print "zxing-cpp " $2}'
  git -C third_party/zxing-cpp ls-files -s zint | awk '{print "zint " $2}'
  for f in native/fzx.h native/fzx.cpp native/CMakeLists.txt native/generated/Version.h \
           third_party/stb/stb_image.h tool/wasm_config.sh; do
    echo "$f $(tr -d '\r' < "$f" | sha | cut -d' ' -f1)"
  done
} | sha | cut -c1-16
