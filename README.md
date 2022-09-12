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

A barcode and QR code scanner based on [ZXing C++](https://github.com/nu-book/zxing-cpp) library natively in Flutter with Dart FFI.


## Demo Screenshots
<pre>
<img alt="01_scanner_screen" src="https://user-images.githubusercontent.com/11523360/174789425-b33861aa-dbe5-49c1-a84a-a02b514a5e0f.png" width="240">&nbsp; <img alt="02_creator_screen" src="https://user-images.githubusercontent.com/11523360/174789816-a2a4ab74-f5ef-41a1-98f3-e514447dff5a.png" width="240">&nbsp;
</pre>

## Supported Barcode Formats

| 1D product | 1D industrial     | 2D
| ---------- | ----------------- | --------------
| UPC-A      | Code 39           | QR Code
| UPC-E      | Code 93           | DataMatrix
| EAN-8      | Code 128          | Aztec
| EAN-13     | Codabar           | PDF417
| DataBar    | ITF               | MaxiCode (beta)
|            | DataBar Expanded  |

## Features
- Scan barcode from camera stream, image path or url
- Scan multiple barcodes from camera stream, image path or url
- Create barcode from text
- Return scanned barcode position points
- Flashlight and pinch to zoom support

## Todo
- Write tests

## Getting Started
### To read barcode:
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
await startCameraProcessing(); // Call this in initState
cameraController?.startImageStream((image) async {
    CodeResult result = await processCameraImage(image);
    if (result.isValidBool) {
        debugPrint(result.textString);
    }
    return null;
});
stopCameraProcessing(); // Call this in dispose

// To read barcode from XFile, String, url or Uint8List bytes
XFile xFile = XFile('Your image path');
CodeResult? resultFromXFile = await readBarcodeImagePath(xFile);

String path = 'Your local image path';
CodeResult? resultFromPath = await readBarcodeImagePathString(path);

String url = 'Your remote image url';
CodeResult? resultFromUrl = await readBarcodeImageUrl(url);

Uint8List bytes = Uint8List.fromList(yourImageBytes);
CodeResult? resultFromBytes = await readBarcode(bytes);
```

### To create barcode:
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
final result = encodeBarcode(
    'Text to encode',
    format: Format.QRCode,
    width: 300,
    height: 300,
    margin: 10,
    eccLevel: 0,
);
if (result.isValidBool) {
    final img = imglib.Image.fromBytes(width, height, result.bytes);
    final encodedBytes = Uint8List.fromList(imglib.encodeJpg(img));
    // use encodedBytes as you wish
}
```

## License

MIT License. See [LICENSE](https://github.com/khoren93/flutter_zxing/blob/master/LICENSE).
