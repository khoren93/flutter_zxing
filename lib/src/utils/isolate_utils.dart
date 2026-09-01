import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../logic/zxing.dart';
import '../models/models.dart';
import 'image_converter.dart';

// Inspired from https://github.com/am15h/object_detection_flutter

/// Bundles data to pass between Isolate
class IsolateData {
  IsolateData(this.cameraImage, this.params);
  CameraImage cameraImage;
  DecodeParams params;

  SendPort? responsePort;
}

/// Wraps an error raised while decoding so it can be sent back over a
/// [SendPort] and rethrown on the caller's isolate.
///
/// Sending the raw error object instead would make the caller's `as Code` cast
/// fail with an unrelated `TypeError`, hiding what actually went wrong.
class IsolateError {
  IsolateError(this.message, this.stackTrace);

  final String message;
  final String stackTrace;

  @override
  String toString() => message;
}

/// Manages separate Isolate instance for inference
class IsolateUtils {
  static const String kDebugName = 'ZxingIsolate';

  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;

  SendPort? get sendPort => _sendPort;

  /// Whether the worker isolate is up and able to accept work.
  bool get isRunning => _sendPort != null;

  Future<void>? _starting;

  /// Requests that have been sent but not answered yet. Tracked so that
  /// stopping the isolate can fail them instead of leaving their callers
  /// waiting forever on an isolate that no longer exists.
  final Set<Completer<Object?>> _pending = <Completer<Object?>>{};

  Future<void> startReadingBarcode() {
    // Concurrent callers must await the same spawn rather than racing to create
    // a second isolate (or returning before the first one is ready).
    return _starting ??= _start();
  }

  Future<void> _start() async {
    final ReceivePort receivePort = ReceivePort();
    _receivePort = receivePort;
    try {
      _isolate = await Isolate.spawn<SendPort>(
        readBarcodeEntryPoint,
        receivePort.sendPort,
        debugName: kDebugName,
      );
      _sendPort = await receivePort.first as SendPort;
    } catch (_) {
      // `first` closes the port on success; on failure we have to close it
      // ourselves or the isolate handshake port leaks.
      receivePort.close();
      _receivePort = null;
      _isolate = null;
      _starting = null;
      rethrow;
    }
  }

  void stopReadingBarcode() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _receivePort?.close();
    _receivePort = null;
    _starting = null;

    for (final Completer<Object?> pending in _pending.toList()) {
      if (!pending.isCompleted) {
        pending.completeError(
          StateError(
            'Camera processing was stopped before the image was decoded.',
          ),
        );
      }
    }
    _pending.clear();
  }

  /// Sends [isolateData] to the worker isolate and awaits its answer.
  ///
  /// Throws a [StateError] if the isolate is not running, and completes with an
  /// error if the isolate is stopped while the request is in flight — either way
  /// the caller gets an error instead of a future that never completes.
  Future<Object?> process(IsolateData isolateData) async {
    final SendPort? port = _sendPort;
    if (port == null) {
      throw StateError(
        'Camera processing is not running. '
        'Call `zx.startCameraProcessing()` before processing camera images.',
      );
    }

    final ReceivePort responsePort = ReceivePort();
    // A completer per in-flight request, rather than one shared "stopped"
    // future: a camera stream calls this many times a second, and every
    // listener attached to a shared future would be retained until that future
    // completed.
    final Completer<Object?> completer = Completer<Object?>();
    _pending.add(completer);
    responsePort.listen((Object? message) {
      if (!completer.isCompleted) {
        completer.complete(message);
      }
    });

    try {
      port.send(isolateData..responsePort = responsePort.sendPort);
      final Object? result = await completer.future;
      if (result is IsolateError) {
        Error.throwWithStackTrace(
          Exception(result.message),
          StackTrace.fromString(result.stackTrace),
        );
      }
      return result;
    } finally {
      _pending.remove(completer);
      responsePort.close();
    }
  }

  static Future<void> readBarcodeEntryPoint(SendPort sendPort) async {
    final ReceivePort port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final Object? message in port) {
      if (message is! IsolateData) {
        continue;
      }
      try {
        final CameraImage image = message.cameraImage;
        final Uint8List bytes = await convertImage(image);
        final DecodeParams params = message.params;

        final Object result = params.isMultiScan
            ? zxingReadBarcodes(bytes, params)
            : zxingReadBarcode(bytes, params);
        message.responsePort?.send(result);
      } catch (e, s) {
        message.responsePort?.send(IsolateError(e.toString(), s.toString()));
      }
    }
  }
}
