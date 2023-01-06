import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'src/models/models.dart';

import 'zxing_cross.dart'
    if (dart.library.io) 'zxing_mobile.dart'
    if (dart.library.html) 'zxing_web.dart';

export 'src/models/models.dart';
export 'src/ui/ui.dart';

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
  Future<Code> processCameraImage(
    CameraImage image, {
    DecodeParams? params,
  });

  /// Reads barcode from String image path
  Future<Code?> readBarcodeImagePathString(
    String path, {
    DecodeParams? params,
  });

  /// Reads barcode from XFile image path
  Future<Code?> readBarcodeImagePath(
    XFile path, {
    DecodeParams? params,
  });

  /// Reads barcode from image url
  Future<Code?> readBarcodeImageUrl(
    String url, {
    DecodeParams? params,
  });

// Reads barcode from Uint8List image bytes
  Code readBarcode(
    Uint8List bytes, {
    required int width,
    required int height,
    DecodeParams? params,
  });

  /// Reads barcodes from String image path
  Future<List<Code>> readBarcodesImagePathString(
    String path, {
    DecodeParams? params,
  });

  /// Reads barcodes from XFile image path
  Future<List<Code>> readBarcodesImagePath(
    XFile path, {
    DecodeParams? params,
  });

  /// Reads barcodes from image url
  Future<List<Code>> readBarcodesImageUrl(
    String url, {
    DecodeParams? params,
  });

  /// Reads barcodes from Uint8List image bytes
  List<Code> readBarcodes(
    Uint8List bytes, {
    required int width,
    required int height,
    DecodeParams? params,
  });
}
