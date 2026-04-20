// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_zxing",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "flutter-zxing", targets: ["flutter_zxing"])
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
