# CMake project of the fzx engine. Apps never use it: native builds go through
# hook/build.dart. It serves the tools only:
#   - tool/gen_sources.dart configures it to learn zxing-cpp's source list,
#     defines and Version.h (CMake is the source of truth for those);
#   - tool/build_wasm.sh builds the WebAssembly modules with Emscripten.
cmake_minimum_required(VERSION 3.16)
project(fzx CXX C)
set(CMAKE_CXX_STANDARD 20)
if (NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

# OFF builds the reader-only module (no zint): the smaller WebAssembly file
# the web worker loads first.
option(FZX_WRITERS "Include barcode creation (zint)" ON)

set(ZXING_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../third_party/zxing-cpp)
set(STB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../third_party/stb)
set(ZXING_READERS ON CACHE BOOL "" FORCE)
if (FZX_WRITERS)
  set(ZXING_WRITERS NEW CACHE STRING "" FORCE)
else()
  set(ZXING_WRITERS OFF CACHE STRING "" FORCE)
endif()
set(ZXING_C_API OFF CACHE BOOL "" FORCE)
set(ZXING_EXPERIMENTAL_API OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF)
if (EMSCRIPTEN)
  # Native WebAssembly exceptions: zxing-cpp throws on invalid input.
  string(APPEND CMAKE_CXX_FLAGS " -fwasm-exceptions")
endif()
add_subdirectory(${ZXING_ROOT}/core ${CMAKE_BINARY_DIR}/zxing)

if (EMSCRIPTEN)
  add_executable(fzx fzx.cpp)
  target_link_options(fzx PRIVATE
    -sMODULARIZE=1 -sEXPORT_ES6=1 -sEXPORT_NAME=createFzx -sENVIRONMENT=web,worker,node
    -sFILESYSTEM=0 -sALLOW_MEMORY_GROWTH=1 -sDYNAMIC_EXECUTION=0
    -sEXPORTED_FUNCTIONS=_malloc,_free -sEXPORTED_RUNTIME_METHODS=HEAPU8,UTF8ToString
    -fwasm-exceptions)
else()
  add_library(fzx SHARED fzx.cpp)
endif()
target_include_directories(fzx PRIVATE ${STB_DIR})
target_link_libraries(fzx PRIVATE ZXing::ZXing)
