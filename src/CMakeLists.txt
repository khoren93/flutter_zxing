cmake_minimum_required(VERSION 3.10)

project(flutter_zxing LANGUAGES C CXX)

add_library(
    flutter_zxing
    SHARED
    common.cpp
    native_zxing.cpp
)

set (BUILD_WRITERS ON)

add_subdirectory(zxing/core)

find_library(log-lib log)
target_link_libraries(flutter_zxing ZXing ${log-lib})