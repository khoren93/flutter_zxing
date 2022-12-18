import 'dart:typed_data';

import 'package:camera/camera.dart';

import 'flutter_zxing.dart';

Zxing getZxing() => ZxingWeb();

class ZxingWeb implements Zxing {
  ZxingWeb();

  @override
  String version() => 'Unsupported';

  @override
  void setLogEnabled(bool enabled) {}

  @override
  String barcodeFormatName(int format) => 'Unsupported';

  @override
  Encode encodeBarcode(
    String contents, {
    int format = Format.qrCode,
    int width = 300,
    int height = 300,
    int margin = 0,
    int eccLevel = 0,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> startCameraProcessing() => throw UnimplementedError();

  @override
  void stopCameraProcessing() => throw UnimplementedError();

  @override
  Future<Code> processCameraImage(
    CameraImage image, {
    Params? params,
  }) =>
      throw UnimplementedError();

  @override
  Future<Code?> readBarcodeImagePathString(
    String path, {
    Params? params,
  }) =>
      throw UnimplementedError();

  @override
  Future<Code?> readBarcodeImagePath(
    XFile path, {
    Params? params,
  }) =>
      throw UnimplementedError();

  @override
  Future<Code?> readBarcodeImageUrl(
    String url, {
    Params? params,
  }) =>
      throw UnimplementedError();

  @override
  Code readBarcode(
    Uint8List bytes, {
    required int width,
    required int height,
    Params? params,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<Code>> readBarcodesImagePathString(
    String path, {
    Params? params,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<Code>> readBarcodesImagePath(
    XFile path, {
    Params? params,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<Code>> readBarcodesImageUrl(
    String url, {
    Params? params,
  }) =>
      throw UnimplementedError();

  @override
  List<Code> readBarcodes(
    Uint8List bytes, {
    required int width,
    required int height,
    Params? params,
  }) =>
      throw UnimplementedError();
}
