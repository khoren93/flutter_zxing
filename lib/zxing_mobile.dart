import 'dart:typed_data';

import 'package:camera/camera.dart';

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
  Encode encodeBarcode(
    String contents, {
    int format = Format.qrCode,
    int width = 300,
    int height = 300,
    int margin = 0,
    int eccLevel = 0,
  }) =>
      zxingEncodeBarcode(
        contents,
        format: format,
        width: width,
        height: height,
        margin: margin,
        eccLevel: eccLevel,
      );

  @override
  Future<void> startCameraProcessing() => zxingStartCameraProcessing();

  @override
  void stopCameraProcessing() => zxingStopCameraProcessing();

  @override
  Future<Code> processCameraImage(
    CameraImage image, {
    Params? params,
  }) =>
      zxingProcessCameraImage(
        image,
        params: params,
      );

  @override
  Future<Code?> readBarcodeImagePathString(
    String path, {
    Params? params,
  }) =>
      zxingReadBarcodeImagePathString(
        path,
        params: params,
      );

  @override
  Future<Code?> readBarcodeImagePath(
    XFile path, {
    Params? params,
  }) =>
      zxingReadBarcodeImagePath(
        path,
        params: params,
      );

  @override
  Future<Code?> readBarcodeImageUrl(
    String url, {
    Params? params,
  }) =>
      zxingReadBarcodeImageUrl(
        url,
        params: params,
      );

  @override
  Code readBarcode(
    Uint8List bytes, {
    required int width,
    required int height,
    Params? params,
  }) =>
      zxingReadBarcode(
        bytes,
        width: width,
        height: height,
        params: params,
      );

  @override
  Future<List<Code>> readBarcodesImagePathString(
    String path, {
    Params? params,
  }) =>
      zxingReadBarcodesImagePathString(
        path,
        params: params,
      );

  @override
  Future<List<Code>> readBarcodesImagePath(
    XFile path, {
    Params? params,
  }) =>
      zxingReadBarcodesImagePath(
        path,
        params: params,
      );

  @override
  Future<List<Code>> readBarcodesImageUrl(
    String url, {
    Params? params,
  }) =>
      zxingReadBarcodesImageUrl(
        url,
        params: params,
      );

  @override
  List<Code> readBarcodes(
    Uint8List bytes, {
    required int width,
    required int height,
    Params? params,
  }) =>
      zxingReadBarcodes(
        bytes,
        width: width,
        height: height,
        params: params,
      );
}
