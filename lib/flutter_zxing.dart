import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'src/models/models.dart';

// `dart.library.js_interop` (not the legacy `dart.library.html`) is the flag
// that is also set when compiling to WasmGC, where `dart:html` does not exist.
import 'zxing_cross.dart'
    if (dart.library.io) 'zxing_mobile.dart'
    if (dart.library.js_interop) 'zxing_web.dart';

// `CameraImage` and `XFile` appear in this package's own public signatures, so
// they are re-exported: without them callers had to import `package:camera`
// directly, whose `ImageFormat` then collided with the `ImageFormat` constants
// this package expects in `DecodeParams`.
export 'package:camera/camera.dart'
    show
        CameraController,
        CameraImage,
        CameraLensDirection,
        ResolutionPreset,
        XFile;
export 'src/models/models.dart';
export 'src/ui/ui.dart';
export 'src/utils/image_converter.dart';

final Zxing zx = Zxing();

abstract class Zxing {
  /// factory constructor to return the correct implementation.
  factory Zxing() => getZxing();

  String version() => '';
  void setLogEnabled(bool enabled) {}
  String barcodeFormatName(int format) => '';

  /// Creates barcode from the given contents
  Encode encodeBarcode({
    required String contents,
    required EncodeParams params,
  });

  /// Starts reading barcode from the camera
  Future<void> startCameraProcessing();

  /// Stops reading barcode from the camera
  void stopCameraProcessing();

  /// Reads barcode from the camera
  Future<Code> processCameraImage(CameraImage image, DecodeParams params);

  /// Reads barcodes from the camera
  Future<Codes> processCameraImageMulti(CameraImage image, DecodeParams params);

  /// Reads barcode from String image path
  Future<Code> readBarcodeImagePathString(String path, DecodeParams params);

  /// Reads barcode from XFile image path
  Future<Code> readBarcodeImagePath(XFile path, DecodeParams params);

  /// Reads barcode from image url
  Future<Code> readBarcodeImageUrl(String url, DecodeParams params);

  /// Reads barcode from Uint8List image bytes
  Code readBarcode(Uint8List bytes, DecodeParams params);

  /// Reads barcodes from String image path
  Future<Codes> readBarcodesImagePathString(String path, DecodeParams params);

  /// Reads barcodes from XFile image path
  Future<Codes> readBarcodesImagePath(XFile path, DecodeParams params);

  /// Reads barcodes from image url
  Future<Codes> readBarcodesImageUrl(String url, DecodeParams params);

  /// Reads barcodes from Uint8List image bytes
  Codes readBarcodes(Uint8List bytes, DecodeParams params);
}
