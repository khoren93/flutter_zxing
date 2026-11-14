cmake_minimum_required(VERSION 3.16)

project(flutter_zxing LANGUAGES C CXX)

add_library(
    flutter_zxing
    SHARED
    zxcommon.cpp
    format_bridge.cpp
    native_zxing.cpp
)

# zxing-cpp 3.x redefined this option: `ON` now selects the *new*, libzint based
# writer backend, where it used to mean `MultiFormatWriter`. `BOTH` builds both,
# so `encodeBarcode` can keep using `MultiFormatWriter` while the new
# `CreateBarcodeFromText` API stays available for the formats it cannot write.
set (ZXING_WRITERS BOTH)

add_subdirectory(../third_party/zxing-cpp/core "${CMAKE_CURRENT_BINARY_DIR}/zxing" EXCLUDE_FROM_ALL)

target_link_libraries(flutter_zxing ZXing)

# Linux: keep the C++ runtime inside the library, symbols hidden. Flutter
# 3.50's Linux engine exports _Unwind_RaiseException from its own libunwind;
# with a shared libstdc++ the first C++ exception thrown here binds to it and
# aborts the app (std::terminate).
if (CMAKE_SYSTEM_NAME STREQUAL "Linux")
    target_link_options(flutter_zxing PRIVATE -static-libstdc++ -static-libgcc -Wl,--exclude-libs,ALL)
endif ()

# use log-lib only for android platform
if (ANDROID)
    find_library(log-lib log)
    target_link_libraries(flutter_zxing ${log-lib})

    # Required for 16KB page size support on NDK 27.x. NDK 28+ already defaults
    # to 16KB, where this option is simply a no-op, so it is safe either way.
    target_link_options(flutter_zxing PRIVATE "-Wl,-z,max-page-size=16384,--build-id=none")
endif (ANDROID)

# Command to update zxing submodule
# cd third_party/zxing-cpp
# git checkout v3.1.1
# git submodule update --init --recursive
