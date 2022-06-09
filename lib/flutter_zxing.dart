import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imglib;

import 'generated_bindings.dart';
import 'isolate_utils.dart';

export 'generated_bindings.dart';
export 'reader_widget.dart';
export 'writer_widget.dart';
export 'image_converter.dart';
export 'scanner_overlay.dart';

/// The main class for reading barcodes from images or camera.
class FlutterZxing {
  static const MethodChannel _channel = MethodChannel('flutter_zxing');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static final bindings = GeneratedBindings(dylib);

  static IsolateUtils? isolateUtils;

  /// Enables or disables the logging of the library
  static void setLogEnabled(bool enabled) =>
      bindings.setLogEnabled(enabled ? 1 : 0);

  /// Returns a version of the zxing library
  static String version() => bindings.version().cast<Utf8>().toDartString();

  /// Starts reading barcode from the camera
  static Future startCameraProcessing() async {
    // Spawn a new isolate
    isolateUtils = IsolateUtils();
    await isolateUtils?.startReadingBarcode();
  }

  /// Stops reading barcode from the camera
  static void stopCameraProcessing() => isolateUtils?.stopReadingBarcode();

  /// Reads barcode from String image path
  static Future<CodeResult?> readImagePathString(
    String path, {
    int format = Format.Any,
    int cropWidth = 0,
    int cropHeight = 0,
  }) =>
      readImagePath(XFile(path),
          format: format, cropWidth: cropWidth, cropHeight: cropHeight);

  /// Reads barcode from XFile image path
  static Future<CodeResult?> readImagePath(
    XFile path, {
    int format = Format.Any,
    int cropWidth = 0,
    int cropHeight = 0,
  }) async {
    final Uint8List imageBytes = await path.readAsBytes();
    imglib.Image? image = imglib.decodeImage(imageBytes);
    if (image == null) {
      return null;
    }
    return readBarcode(
      image.getBytes(format: imglib.Format.luminance),
      format,
      image.width,
      image.height,
      cropWidth,
      cropHeight,
    );
  }

  /// Reads barcode from image url
  static Future<CodeResult?> readImageUrl(
    String url, {
    int format = Format.Any,
    int cropWidth = 0,
    int cropHeight = 0,
  }) async {
    final Uint8List imageBytes =
        (await NetworkAssetBundle(Uri.parse(url)).load(url))
            .buffer
            .asUint8List();
    imglib.Image? image = imglib.decodeImage(imageBytes);
    if (image == null) {
      return null;
    }
    return readBarcode(
      image.getBytes(format: imglib.Format.luminance),
      format,
      image.width,
      image.height,
      cropWidth,
      cropHeight,
    );
  }

  static CodeResult readBarcode(Uint8List bytes, int format, int width,
      int height, int cropWidth, int cropHeight) {
    return bindings.readBarcode(
        bytes.allocatePointer(), format, width, height, cropWidth, cropHeight);
  }

  static List<CodeResult> readBarcodes(Uint8List bytes, int format, int width,
      int height, int cropWidth, int cropHeight) {
    final result = bindings.readBarcodes(
        bytes.allocatePointer(), format, width, height, cropWidth, cropHeight);
    List<CodeResult> results = [];
    for (int i = 0; i < result.count; i++) {
      results.add(result.results.elementAt(i).ref);
    }
    return results;
  }

  static EncodeResult encodeBarcode(String contents, int width, int height,
      int format, int margin, int eccLevel) {
    var result = bindings.encodeBarcode(contents.toNativeUtf8().cast<Char>(),
        width, height, format, margin, eccLevel);
    return result;
  }

  static Future<CodeResult> processCameraImage(CameraImage image,
      {int format = Format.Any, double cropPercent = 0.5}) async {
    var isolateData = IsolateData(image, format, cropPercent);
    CodeResult result = await _inference(isolateData);
    return result;
  }

  /// Runs inference in another isolate
  static Future<CodeResult> _inference(IsolateData isolateData) async {
    ReceivePort responsePort = ReceivePort();
    isolateUtils?.sendPort
        ?.send(isolateData..responsePort = responsePort.sendPort);
    var results = await responsePort.first;
    return results;
  }

  static String formatName(int format) => _formatNames[format] ?? 'Unknown';
}

// Getting a library that holds needed symbols
DynamicLibrary _openDynamicLibrary() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libflutter_zxing.so');
  } else if (Platform.isWindows) {
    return DynamicLibrary.open("flutter_zxing_windows_plugin.dll");
  }
  return DynamicLibrary.process();
}

DynamicLibrary dylib = _openDynamicLibrary();

extension Uint8ListBlobConversion on Uint8List {
  /// Allocates a pointer filled with the Uint8List data.
  Pointer<Char> allocatePointer() {
    final blob = calloc<Int8>(length);
    final blobBytes = blob.asTypedList(length);
    blobBytes.setAll(0, this);
    return blob.cast<Char>();
  }
}

extension CodeExt on CodeResult {
  bool get isValidBool => isValid == 1;
  String? get textString =>
      text == nullptr ? null : text.cast<Utf8>().toDartString();
  String get formatString => FlutterZxing.formatName(format);
}

extension EncodeExt on EncodeResult {
  bool get isValidBool => isValid == 1;
  String? get textString =>
      text == nullptr ? null : text.cast<Utf8>().toDartString();
  String get formatString => FlutterZxing.formatName(format);
  Uint32List get bytes => data.cast<Uint32>().asTypedList(length);
  String get errorMessage => error.cast<Utf8>().toDartString();
}

extension CodeFormat on Format {
  String get name => _formatNames[this] ?? 'Unknown';

  static final writerFormats = [
    Format.QRCode,
    Format.DataMatrix,
    Format.Aztec,
    Format.PDF417,
    Format.Codabar,
    Format.Code39,
    Format.Code93,
    Format.Code128,
    Format.EAN8,
    Format.EAN13,
    Format.ITF,
    Format.UPCA,
    Format.UPCE,
    // Format.DataBar,
    // Format.DataBarExpanded,
    // Format.MaxiCode,
  ];
}

final _formatNames = {
  Format.None: 'None',
  Format.Aztec: 'Aztec',
  Format.Codabar: 'CodaBar',
  Format.Code39: 'Code39',
  Format.Code93: 'Code93',
  Format.Code128: 'Code128',
  Format.DataBar: 'DataBar',
  Format.DataBarExpanded: 'DataBarExpanded',
  Format.DataMatrix: 'DataMatrix',
  Format.EAN8: 'EAN8',
  Format.EAN13: 'EAN13',
  Format.ITF: 'ITF',
  Format.MaxiCode: 'MaxiCode',
  Format.PDF417: 'PDF417',
  Format.QRCode: 'QR Code',
  Format.UPCA: 'UPCA',
  Format.UPCE: 'UPCE',
  Format.OneDCodes: 'OneD',
  Format.TwoDCodes: 'TwoD',
  Format.Any: 'Any',
};
