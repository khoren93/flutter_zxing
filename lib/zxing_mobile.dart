import 'dart:typed_data';

// `CameraImage` and `XFile` come through the `flutter_zxing.dart` re-export.
import 'flutter_zxing.dart';
import 'src/logic/zxing.dart';

export 'generated_bindings.dart';
export 'src/logic/zxing.dart';
export 'src/models/models.dart';
export 'src/utils/extentions.dart';
export 'src/utils/image_converter.dart';

Zxing getZxing() => ZxingMobile();

class ZxingMobile implements Zxing {
  ZxingMobile();

  @override
  String version() => zxingVersion();

  @override
  void setLogEnabled(bool enabled) => setZxingLogEnabled(enabled);

  @override
  String barcodeFormatName(int format) => zxingBarcodeFormatName(format);

  @override
  Encode encodeBarcode({
    required String contents,
    required EncodeParams params,
  }) => zxingEncodeBarcode(contents: contents, params: params);

  @override
  Future<void> startCameraProcessing() => zxingStartCameraProcessing();

  @override
  void stopCameraProcessing() => zxingStopCameraProcessing();

  @override
  Future<Code> processCameraImage(
    CameraImage image,
    DecodeParams params,
  ) async {
    // The isolate picks single vs. multi decoding from `params.isMultiScan`, so
    // force it to match the method that was called instead of returning a
    // `Codes` that would fail an unrelated cast at the call site.
    final Object? result = await zxingProcessCameraImage(
      image,
      params.isMultiScan ? params.copyWith(isMultiScan: false) : params,
    );
    if (result is! Code) {
      throw StateError('Expected a Code from the decoder, got $result');
    }
    result.source = CodeSource.camera;
    return result;
  }

  @override
  Future<Codes> processCameraImageMulti(
    CameraImage image,
    DecodeParams params,
  ) async {
    final Object? result = await zxingProcessCameraImage(
      image,
      params.isMultiScan ? params : params.copyWith(isMultiScan: true),
    );
    if (result is! Codes) {
      throw StateError('Expected Codes from the decoder, got $result');
    }
    for (final Code code in result.codes) {
      code.source = CodeSource.camera;
    }
    return result;
  }

  @override
  Future<Code> readBarcodeImagePathString(String path, DecodeParams params) =>
      zxingReadBarcodeImagePathString(path, params);

  @override
  Future<Code> readBarcodeImagePath(XFile path, DecodeParams params) =>
      zxingReadBarcodeImagePath(path, params);

  @override
  Future<Code> readBarcodeImageUrl(String url, DecodeParams params) =>
      zxingReadBarcodeImageUrl(url, params);

  @override
  Code readBarcode(Uint8List bytes, DecodeParams params) =>
      zxingReadBarcode(bytes, params);

  @override
  Future<Codes> readBarcodesImagePathString(String path, DecodeParams params) =>
      zxingReadBarcodesImagePathString(path, params);

  @override
  Future<Codes> readBarcodesImagePath(XFile path, DecodeParams params) =>
      zxingReadBarcodesImagePath(path, params);

  @override
  Future<Codes> readBarcodesImageUrl(String url, DecodeParams params) =>
      zxingReadBarcodesImageUrl(url, params);

  @override
  Codes readBarcodes(Uint8List bytes, DecodeParams params) =>
      zxingReadBarcodes(bytes, params);
}
