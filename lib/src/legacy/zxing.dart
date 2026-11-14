// The 3.x entry point `zx`. Since 4.0 it runs on the same engine as
// BarcodeReader and BarcodeWriter (lib/src/engine).
import 'dart:typed_data';

import 'package:camera/camera.dart' show CameraImage, XFile;

import 'models/models.dart';
import 'zxing_stub.dart'
    if (dart.library.js_interop) 'zxing_web.dart'
    if (dart.library.ffi) 'zxing_native.dart';

/// The 3.x API: reads and creates barcodes.
@Deprecated(
  'Use BarcodeReader and BarcodeWriter instead. Will be removed in 5.0.',
)
final Zxing zx = Zxing();

/// The 3.x API behind [zx].
@Deprecated(
  'Use BarcodeReader and BarcodeWriter instead. Will be removed in 5.0.',
)
abstract class Zxing {
  /// factory constructor to return the correct implementation.
  @Deprecated(
    'Use BarcodeReader and BarcodeWriter instead. Will be removed in 5.0.',
  )
  factory Zxing() => getZxing();

  /// The zxing-cpp version.
  @Deprecated('Use zxingCppVersion instead. Will be removed in 5.0.')
  String version() => '';

  /// Turns on [Code.imageBytes] for raw pixel and camera input.
  @Deprecated('No replacement. Will be removed in 5.0.')
  void setLogEnabled(bool enabled) {}

  /// A readable name of a [Format].
  @Deprecated('Use BarcodeFormat.displayName instead. Will be removed in 5.0.')
  String barcodeFormatName(int format) => '';

  /// Creates barcode from the given contents
  @Deprecated(
    'Use BarcodeWriter(format).toImage(contents) instead. '
    'Will be removed in 5.0.',
  )
  Encode encodeBarcode({
    required String contents,
    required EncodeParams params,
  });

  /// Starts reading barcode from the camera
  @Deprecated('Use BarcodeScanner instead. Will be removed in 5.0.')
  Future<void> startCameraProcessing();

  /// Stops reading barcode from the camera
  @Deprecated('Use BarcodeScanner instead. Will be removed in 5.0.')
  void stopCameraProcessing();

  /// Reads barcode from the camera
  @Deprecated(
    'Use BarcodeScanner or BarcodeReader.readPixels instead. '
    'Will be removed in 5.0.',
  )
  Future<Code> processCameraImage(CameraImage image, DecodeParams params);

  /// Reads barcodes from the camera
  @Deprecated(
    'Use BarcodeScanner or BarcodeReader.readAllPixels instead. '
    'Will be removed in 5.0.',
  )
  Future<Codes> processCameraImageMulti(CameraImage image, DecodeParams params);

  /// Reads barcode from String image path
  @Deprecated(
    'Use BarcodeReader().read(await File(path).readAsBytes()) instead. '
    'Will be removed in 5.0.',
  )
  Future<Code> readBarcodeImagePathString(String path, DecodeParams params);

  /// Reads barcode from XFile image path
  @Deprecated(
    'Use BarcodeReader().read(await file.readAsBytes()) instead. '
    'Will be removed in 5.0.',
  )
  Future<Code> readBarcodeImagePath(XFile path, DecodeParams params);

  /// Reads barcode from image url
  @Deprecated(
    'Use BarcodeReader().read() with the downloaded bytes instead. '
    'Will be removed in 5.0.',
  )
  Future<Code> readBarcodeImageUrl(String url, DecodeParams params);

  /// Reads barcode from Uint8List image bytes
  @Deprecated(
    'Use BarcodeReader().readPixels(PixelBuffer(...)) instead. '
    'Will be removed in 5.0.',
  )
  Code readBarcode(Uint8List bytes, DecodeParams params);

  /// Reads barcodes from String image path
  @Deprecated(
    'Use BarcodeReader().readAll(await File(path).readAsBytes()) instead. '
    'Will be removed in 5.0.',
  )
  Future<Codes> readBarcodesImagePathString(String path, DecodeParams params);

  /// Reads barcodes from XFile image path
  @Deprecated(
    'Use BarcodeReader().readAll(await file.readAsBytes()) instead. '
    'Will be removed in 5.0.',
  )
  Future<Codes> readBarcodesImagePath(XFile path, DecodeParams params);

  /// Reads barcodes from image url
  @Deprecated(
    'Use BarcodeReader().readAll() with the downloaded bytes instead. '
    'Will be removed in 5.0.',
  )
  Future<Codes> readBarcodesImageUrl(String url, DecodeParams params);

  /// Reads barcodes from Uint8List image bytes
  @Deprecated(
    'Use BarcodeReader().readAllPixels(PixelBuffer(...)) instead. '
    'Will be removed in 5.0.',
  )
  Codes readBarcodes(Uint8List bytes, DecodeParams params);
}
