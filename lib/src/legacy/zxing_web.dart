import 'dart:typed_data';

import 'package:camera/camera.dart' show CameraImage, XFile;

import 'models/models.dart';
import 'zxing.dart';

Zxing getZxing() => ZxingWeb();

/// Web stub.
///
/// The 3.x API was never available on the web and stays that way: on the web
/// only the 4.0 API works (BarcodeReader, BarcodeWriter), which runs the
/// engine in a Web Worker. Every call that would read or create a barcode
/// reports that clearly instead of failing somewhere deeper. Calls that only tear things down are no-ops so widget disposal on
/// web does not throw.
class ZxingWeb implements Zxing {
  ZxingWeb();

  static const String _unsupported =
      'The flutter_zxing 3.x API (zx, ReaderWidget, WriterWidget) is not '
      'supported on the web. Use BarcodeReader and BarcodeWriter, which work '
      'on every platform.';

  Never _unsupportedError(String method) =>
      throw UnsupportedError('$_unsupported (called `$method`)');

  @override
  String version() => 'Unsupported';

  @override
  void setLogEnabled(bool enabled) {
    // No-op: there is no native library to configure.
  }

  @override
  String barcodeFormatName(int format) => format.name;

  @override
  Encode encodeBarcode({
    required String contents,
    required EncodeParams params,
  }) => _unsupportedError('encodeBarcode');

  @override
  Future<void> startCameraProcessing() async {
    // No-op: nothing to start, and throwing here would break widget init.
  }

  @override
  void stopCameraProcessing() {
    // No-op: nothing to stop, and throwing here would break widget disposal.
  }

  @override
  Future<Code> processCameraImage(CameraImage image, DecodeParams params) =>
      _unsupportedError('processCameraImage');

  @override
  Future<Codes> processCameraImageMulti(
    CameraImage image,
    DecodeParams params,
  ) => _unsupportedError('processCameraImageMulti');

  @override
  Future<Code> readBarcodeImagePathString(String path, DecodeParams params) =>
      _unsupportedError('readBarcodeImagePathString');

  @override
  Future<Code> readBarcodeImagePath(XFile path, DecodeParams params) =>
      _unsupportedError('readBarcodeImagePath');

  @override
  Future<Code> readBarcodeImageUrl(String url, DecodeParams params) =>
      _unsupportedError('readBarcodeImageUrl');

  @override
  Code readBarcode(Uint8List bytes, DecodeParams params) =>
      _unsupportedError('readBarcode');

  @override
  Future<Codes> readBarcodesImagePathString(String path, DecodeParams params) =>
      _unsupportedError('readBarcodesImagePathString');

  @override
  Future<Codes> readBarcodesImagePath(XFile path, DecodeParams params) =>
      _unsupportedError('readBarcodesImagePath');

  @override
  Future<Codes> readBarcodesImageUrl(String url, DecodeParams params) =>
      _unsupportedError('readBarcodesImageUrl');

  @override
  Codes readBarcodes(Uint8List bytes, DecodeParams params) =>
      _unsupportedError('readBarcodes');
}
