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
            cxxSettings: [
                .define("ZXING_READERS"),
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
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        )
    ],
    cxxLanguageStandard: .gnucxx20
)
