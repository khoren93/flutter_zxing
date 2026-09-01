cmake_minimum_required(VERSION 3.16)

project(flutter_zxing LANGUAGES C CXX)

add_library(
    flutter_zxing
    SHARED
    zxcommon.cpp
    native_zxing.cpp
)

set (ZXING_WRITERS ON)

add_subdirectory(zxing/core EXCLUDE_FROM_ALL)

target_link_libraries(flutter_zxing ZXing)

# use log-lib only for android platform
if (ANDROID)
    find_library(log-lib log)
    target_link_libraries(flutter_zxing ${log-lib})

    # The max-page-size linker option is required to enable support for 16KB page
    # size on Android with NDK 27.x, which is what this plugin pins (NDK 28+
    # cannot build zxing-cpp v2.3.0 -- see android/build.gradle). NDK 28+
    # defaults to 16KB, where this option is simply a no-op, so it is also safe
    # for anyone overriding the NDK version.
    target_link_options(flutter_zxing PRIVATE "-Wl,-z,max-page-size=16384")
endif (ANDROID)

# Command to update zxing submodule
# cd src/zxing
# git checkout v2.2.0
# git submodule update --init --recursive