# Flutter ZXing

Flutter ZXing is a high-performance Flutter plugin for scanning and generating QR codes and barcodes. Built on the powerful [ZXing C++ library](https://github.com/zxing-cpp/zxing-cpp), it provides fast and reliable barcode processing capabilities for Flutter applications. Whether you need to scan barcodes from the camera or generate custom QR codes, Flutter ZXing makes it seamless and efficient.

---

## Table of Contents

- [Flutter ZXing](#flutter-zxing)
  - [Table of Contents](#table-of-contents)
  - [Demo Screenshots](#demo-screenshots)
  - [Features](#features)
  - [Supported Formats](#supported-formats)
  - [Supported Platforms](#supported-platforms)
  - [ZXScanner](#zxscanner)
    - [Features](#features-1)
    - [Try ZXScanner](#try-zxscanner)
  - [Getting Started](#getting-started)
    - [Cloning the flutter\_zxing project](#cloning-the-flutter_zxing-project)
    - [Installing dependencies](#installing-dependencies)
  - [Usage](#usage)
    - [To read barcode](#to-read-barcode)
    - [To create barcode](#to-create-barcode)
  - [License](#license)

---

## Demo Screenshots

<p align="center">
  <img alt="Scanner Screen" src="https://user-images.githubusercontent.com/11523360/222677044-a15841a7-e617-44bb-b3a0-66b2d5b57dce.png" width="240">
  <img alt="Creator Screen" src="https://user-images.githubusercontent.com/11523360/222677058-60a676fd-c229-4b51-8780-f40155cb5db6.png" width="240">
</p>
<p align="center">
  <i>Left: Barcode Scanner, Right: QR Code Creator</i>
</p>

---

## Features

- Scan QR codes and barcodes from the camera stream (on mobile platforms only), image file, or URL.
- Scan multiple barcodes at once from the camera stream (on mobile platforms only), image file, or URL.
- Generate QR codes with customizable content and size.
- Return the position points of the scanned barcode.
- Customizable scanner frame size and color, and the ability to enable or disable features like torch and pinch to zoom.

---

## Supported Formats

| Linear product | Linear industrial | Matrix             |
|----------------|-------------------|--------------------|
| UPC-A          | Code 39           | QR Code            |
| UPC-E          | Code 93           | Micro QR Code      |
| EAN-8          | Code 128          | rMQR Code          |
| EAN-13         | Codabar           | Aztec              |
| DataBar        | DataBar Expanded  | DataMatrix         |
|                | ITF               | PDF417             |
|                |                   | MaxiCode (partial) |

---

## Supported Platforms

| Platform   | Status               | Notes                                     |
|------------|----------------------|-------------------------------------------|
| Android    | ✅ Fully Supported   | Minimum API level 21                     |
| iOS        | ✅ Fully Supported   | Minimum iOS 11.0                         |
| MacOS      | ⚠️ Beta             | Minimum macOS 10.15                      |
| Linux      | ⚠️ Beta             | No camera support                        |
| Windows    | ⚠️ Beta             | No camera support                        |
| Web        | ❌ Not Supported    | Dart FFI is not available on the web     |

> Note: Flutter ZXing relies on the Dart FFI feature, making it unsupported on the web. Camera-based scanning is only available on mobile platforms.

---


## ZXScanner

ZXScanner is a free QR code and barcode scanner app for Android and iOS. It is built using Flutter and the [flutter_zxing](https://github.com/khoren93/flutter_zxing) plugin.

<p align="center">
    <a href="https://github.com/khoren93/flutter_zxing/tree/main/zxscanner">
        <img src="https://user-images.githubusercontent.com/11523360/178162663-57ec28ac-7075-43ab-ac31-35058298c73e.png" alt="ZXScanner logo" height="100">
    </a>
</p>

### Features
- Fast and reliable QR code and barcode scanning.
- Built-in support for multiple barcode formats.
- Fully open-source and customizable.

### Try ZXScanner
To learn more or contribute, visit the [ZXScanner repository](https://github.com/khoren93/flutter_zxing/tree/main/zxscanner).

## Getting Started

### Cloning the flutter_zxing project

To clone the flutter_zxing project from Github which includes submodules, use the following command:

```bash
git clone --recursive https://github.com/khoren93/flutter_zxing.git
```

### Installing dependencies

Use Melos to install the dependencies of the flutter_zxing project. Melos is a tool that helps you manage multiple Dart packages in a single repository. To install Melos, use the following command:

```bash
flutter pub global activate melos
```

To install the dependencies of the flutter_zxing project, use the following command:

```bash
melos bootstrap
```

To allow the building on iOS and MacOS, you need to run the following command:

```bash
./scripts/update_ios_macos_src.sh
```

To run the integration tests:

```bash
cd example
flutter test integration_test
```

Now you can run the flutter_zxing example app on your device or emulator.

## Usage

### To read barcode

```dart
import 'package:flutter_zxing/flutter_zxing.dart';

// Use ReaderWidget to quickly read barcode from camera image
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: ReaderWidget(
      onScan: (result) async {
        // Do something with the result
      },
    ),
  );
}

// Or use flutter_zxing plugin methods 
// To read barcode from camera image directly
await zx.startCameraProcessing(); // Call this in initState

cameraController?.startImageStream((image) async {
    Code result = await zx.processCameraImage(image);
    if (result.isValid) {
        debugPrint(result.text);
    }
    return null;
});

zx.stopCameraProcessing(); // Call this in dispose

// To read barcode from XFile, String, url or Uint8List bytes
XFile xFile = XFile('Your image path');
Code? resultFromXFile = await zx.readBarcodeImagePath(xFile);

String path = 'Your local image path';
Code? resultFromPath = await zx.readBarcodeImagePathString(path);

String url = 'Your remote image url';
Code? resultFromUrl = await zx.readBarcodeImageUrl(url);

Uint8List bytes = Uint8List.fromList(yourImageBytes);
Code? resultFromBytes = await zx.readBarcode(bytes);
```

### To create barcode

```dart
import 'package:flutter_zxing/flutter_zxing.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as imglib;

// Use WriterWidget to quickly create barcode
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: WriterWidget(
      onSuccess: (result, bytes) {
        // Do something with the result
      },
      onError: (error) {
        // Do something with the error
      },
    ),
  );
}

// Or use FlutterZxing to create barcode directly
final Encode result = zx.encodeBarcode(
    contents: 'Text to encode',
    params: EncodeParams(
        format: Format.QRCode,
        width: 120,
        height: 120,
        margin: 10,
        eccLevel: EccLevel.low,
    ),
);
if (result.isValid) {
    final img = imglib.Image.fromBytes(width, height, result.data);
    final encodedBytes = Uint8List.fromList(imglib.encodeJpg(img));
    // use encodedBytes as you wish
}
```

## License

MIT License. See [LICENSE](https://github.com/khoren93/flutter_zxing/blob/master/LICENSE).
