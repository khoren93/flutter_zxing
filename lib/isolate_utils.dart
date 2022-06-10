import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import 'flutter_zxing.dart';

// Inspired from https://github.com/am15h/object_detection_flutter

/// Bundles data to pass between Isolate
class IsolateData {
  IsolateData(
    this.cameraImage,
    this.format,
    this.cropPercent,
  );
  CameraImage cameraImage;
  int format;
  double cropPercent;

  SendPort? responsePort;
}

/// Manages separate Isolate instance for inference
class IsolateUtils {
  static const String kDebugName = 'ZxingIsolate';

  // ignore: unused_field
  Isolate? _isolate;
  final ReceivePort _receivePort = ReceivePort();
  SendPort? _sendPort;

  SendPort? get sendPort => _sendPort;

  Future<void> startReadingBarcode() async {
    _isolate = await Isolate.spawn<SendPort>(
      readBarcodeEntryPoint,
      _receivePort.sendPort,
      debugName: kDebugName,
    );

    _sendPort = await _receivePort.first;
  }

  void stopReadingBarcode() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
  }

  static Future<void> readBarcodeEntryPoint(SendPort sendPort) async {
    final ReceivePort port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final IsolateData? isolateData in port) {
      if (isolateData != null) {
        try {
          final CameraImage image = isolateData.cameraImage;
          final double cropPercent = isolateData.cropPercent;
          final Uint8List bytes = await convertImage(image);
          final int cropSize =
              (min(image.width, image.height) * cropPercent).round();

          final CodeResult result = FlutterZxing.readBarcode(
              bytes,
              isolateData.format,
              image.width,
              image.height,
              cropSize,
              cropSize);

          isolateData.responsePort?.send(result);
        } catch (e) {
          isolateData.responsePort?.send(e);
        }
      }
    }
  }
}
