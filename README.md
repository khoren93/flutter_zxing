<p align="center">
  <img src="https://user-images.githubusercontent.com/11523360/178162663-57ec28ac-7075-43ab-ac31-35058298c73e.png" alt="ZXScanner logo" height="100" >
</p>

<p align="center">
  <a href="https://apps.apple.com/am/app/zxscanner/id1629106248">
    <img alt="Download on the App Store" title="App Store" src="https://user-images.githubusercontent.com/11523360/178162313-182568ae-c9a2-48bd-9a51-883562788d9e.png" height="50">
  </a>
  
  <a href="https://play.google.com/store/apps/details?id=com.markosyan.zxscanner">
    <img alt="Download on the Google Play" title="Google Play" src="https://user-images.githubusercontent.com/11523360/178162318-533a29de-750f-4d4b-b117-f3d01c2c9340.png" height="50">
  </a>
</p>

# flutter_zxing

Flutter ZXing is a Flutter plugin for scanning and generating QR codes using the ZXing (Zebra Crossing) barcode scanning library. The plugin is implemented using the Dart FFI (Foreign Function Interface) and the ZXing-CPP library, and allows you to easily integrate barcode scanning and generation functionality into your Flutter apps.

## Demo Screenshots

<pre>
<img alt="01_scanner_screen" src="https://user-images.githubusercontent.com/11523360/174789425-b33861aa-dbe5-49c1-a84a-a02b514a5e0f.png" width="240">&nbsp; <img alt="02_creator_screen" src="https://user-images.githubusercontent.com/11523360/174789816-a2a4ab74-f5ef-41a1-98f3-e514447dff5a.png" width="240">&nbsp;
</pre>

## Features

- Scan QR codes and barcodes from the camera stream (on mobile platforms only), image file or URL
- Scan multiple barcodes at once from the camera stream (on mobile platforms only), image file or URL 
- Generate QR codes with customizable content and size
- Return the position points of the scanned barcode
- Customizable scanner frame size and color, and ability to enable or disable features like torch and pinch to zoom

## Supported Formats

| Linear product | Linear industrial | Matrix             |
|----------------|-------------------|--------------------|
| UPC-A          | Code 39           | QR Code            |
| UPC-E          | Code 93           | Micro QR Code      |
| EAN-8          | Code 128          | Aztec              |
| EAN-13         | Codabar           | DataMatrix         |
| DataBar        | DataBar Expanded  | PDF417             |
|                | ITF               | MaxiCode (partial) |

## Supported platforms

Flutter ZXing supports the following platforms:

- Android (minimum API level 21)
- iOS (minimum iOS 11.0)
- MacOS (minimum osx 10.15) (beta)
- Linux (beta)
- Windows (beta)

Note that flutter_zxing relies on the Dart FFI (Foreign Function Interface) feature, which is currently only available for the mobile and desktop platforms. As a result, the plugin is not currently supported on the web platform.

In addition, flutter_zxing uses the camera plugin to access the device's camera for scanning barcodes. This plugin is only supported on mobile platforms, and is not available for desktop platforms. Therefore, some features of flutter_zxing, such as scanning barcodes using the camera, are not available on desktop platforms.



## Getting Started

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
    ),
);

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
    ),
);

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
