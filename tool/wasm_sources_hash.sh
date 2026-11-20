#!/usr/bin/env bash
# Prints a hash of everything the WebAssembly modules are built from: the fzx
# sources, the zxing-cpp and zint commits, stb_image, the build script and
# the Emscripten version. tool/build_wasm.sh embeds it in the generated JS and
# skips the build when it has not changed.
set -euo pipefail
cd "$(dirname "$0")/.."
source tool/wasm_config.sh

sha() { if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi; }

{
  echo "emscripten $FZX_EMSCRIPTEN_VERSION"
  # The commits checked out, which the build compiles: after `git submodule
  # update --remote` they differ from the ones recorded in this repository.
  # The recorded ones where a submodule is not checked out.
  commit() { # <submodule path> <path in its parent> <parent>
    if [ -e "$1/.git" ]; then
      git -C "$1" rev-parse HEAD
    else
      git -C "$3" ls-files -s "$2" | awk '{print $2}'
    fi
  }
  echo "zxing-cpp $(commit third_party/zxing-cpp third_party/zxing-cpp .)"
  echo "zint $(commit third_party/zxing-cpp/zint zint third_party/zxing-cpp)"
  for f in native/fzx.h native/fzx.cpp native/CMakeLists.txt native/generated/Version.h \
           third_party/stb/stb_image.h tool/wasm_config.sh tool/build_wasm.sh; do
    echo "$f $(tr -d '\r' < "$f" | sha | cut -d' ' -f1)"
  done
} | sha | cut -c1-16
