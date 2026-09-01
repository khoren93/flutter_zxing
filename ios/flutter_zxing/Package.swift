// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_zxing",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        // Must be a dynamic library. The Dart side resolves the FFI entry
        // points at runtime via `DynamicLibrary.process()`. As a static library
        // these symbols are linked into the app's executable, where the App
        // Store archive's `strip` step removes them, breaking barcode detection.
        // A dynamic framework keeps them in its export table, which `strip`
        // preserves and `dlsym` can still find.
        .library(name: "flutter-zxing", type: .dynamic, targets: ["flutter_zxing"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_zxing",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            publicHeadersPath: "src",
            cSettings: [
                // libzint, the backend behind zxing-cpp's writer API. Matches
                // the COMPILE_OPTIONS the zxing CMake build sets on these files.
                .define("ZINT_NO_PNG"),
                .define("NDEBUG", .when(configuration: .release)),
                .headerSearchPath("src"),
                .headerSearchPath("src/zxing"),
                .headerSearchPath("src/zxing/libzint"),
            ],
            cxxSettings: [
                // ZXING_READERS / ZXING_WRITERS / ZXING_USE_ZINT and the
                // ZXING_ENABLE_* switches come from the Version.h that
                // scripts/update_ios_macos_src.sh generates, so they must not be
                // repeated here. ZXING_INTERNAL is the one zxing-cpp expects to
                // be set while building the library itself.
                .define("ZXING_INTERNAL"),
                // zxing-cpp guards internal geometry invariants with `assert`,
                // which aborts the whole app when one trips on an awkward
                // frame -- for example
                // "Assertion failed: (l1.isValid() && l2.isValid()), function
                // intersect, file RegressionLine.h". A library must not take a
                // shipped app down over that, so release builds compile the
                // asserts out, exactly as the CMake release build does for
                // Android, Linux and Windows. Debug builds keep them.
                .define("NDEBUG", .when(configuration: .release)),
                .headerSearchPath("src"),
                .headerSearchPath("src/zxing"),
                // <zint.h>, included by CreateBarcode.cpp and WriteBarcode.cpp
                .headerSearchPath("src/zxing/libzint"),
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        )
    ],
    cxxLanguageStandard: .gnucxx20
)
