# Installation

```bash
flutter pub add flutter_zxing:^%VERSION%
```

flutter_zxing needs Flutter 3.41 or newer. A build hook compiles zxing-cpp
into your app on every platform: there is nothing to set up in CMake,
CocoaPods or Gradle. The first build takes a minute longer; later builds use
the cache. After upgrading from 3.x, run `flutter clean` once.

Reading images and creating barcodes need nothing more. The camera scanner
needs the settings below.

## Android

The `camera` plugin declares the camera permission. Its CameraX
implementation also adds `RECORD_AUDIO`, and `WRITE_EXTERNAL_STORAGE` on
Android 9 and older, to every app. If your app does not record video, remove
them in `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
  <uses-permission android:name="android.permission.RECORD_AUDIO" tools:node="remove" />
  <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" tools:node="remove" />
```

## iOS

Add `NSCameraUsageDescription` to `ios/Runner/Info.plist`, and
`NSPhotoLibraryUsageDescription` if users pick photos. App Store Connect may
ask for the camera text even without a scanner: the camera plugin is always
linked.

```xml
<key>NSCameraUsageDescription</key>
<string>Scans barcodes</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Reads barcodes from your photos</string>
```

## Web

`flutter build web` and `flutter build web --wasm` both work. The engine is
WebAssembly in a Web Worker, loaded from the app's assets:

- An app served under a sub-path needs `--base-href /sub-path/`.
- The camera works on pages served over HTTPS, or on `localhost`.
- The package on pub.dev has the WebAssembly engine built in, and adds it
  to web builds only. A git or path dependency on the repository has not:
  run `make wasm` in a clone and depend on it by path.

## macOS, Linux and Windows

Reading and creating work as they are. For the camera, add
[`camera_desktop`](https://pub.dev/packages/camera_desktop): see
[Platforms](./platforms#camera-on-the-desktop).

## What to import

The package is zxing-cpp for Flutter first. Each layer on top of it can be
imported on its own, and exports the ones it builds on:

| Import | What it has |
|---|---|
| `package:flutter_zxing/core.dart` | zxing-cpp: `BarcodeReader`, `BarcodeWriter`, `Barcode`, `BarcodeFormat`, `ReaderOptions`, `BarcodeSymbol` with plain SVG and PNG |
| `package:flutter_zxing/content.dart` | `barcode.content`: parsed links, Wi-Fi, contacts, events, GS1…; `toPayload()` builds them |
| `package:flutter_zxing/rendering.dart` | `BarcodeView`, `BarcodeStyle` and styled export |
| `package:flutter_zxing/scanner.dart` | `BarcodeScanner`, `ScannerController`, templates, themes, widgets |
| `package:flutter_zxing/flutter_zxing.dart` | all of the above and the deprecated 3.x API |

The package works in Flutter apps, not in plain Dart programs. `camera` and
`image_picker` come with any of the imports.
