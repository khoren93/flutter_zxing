// The engine behind BarcodeReader, BarcodeWriter and the scanner: fzx running
// off the UI thread, on a long-lived isolate (native platforms) or in a Web
// Worker (web). Not exported from the package.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../errors.dart';
import '../reading/pixel_buffer.dart';
import 'engine_protocol.dart';
import 'engine_stub.dart'
    if (dart.library.js_interop) 'engine_web.dart'
    if (dart.library.ffi) 'engine_native.dart'
    as platform;

/// One running instance of the engine. Calls are processed in order.
abstract interface class EngineBackend {
  /// Decodes an encoded image (JPEG, PNG, ...) and reads its barcodes.
  Future<EngineReadResult> readImage(
    Uint8List encodedImage,
    EngineReadOptions options,
  );

  /// Reads the barcodes in raw pixels.
  Future<EngineReadResult> readPixels(
    PixelBuffer image,
    EngineReadOptions options,
  );

  /// Encodes [data] into a symbol of [format] (a zxing-cpp format name)
  /// with zxing-cpp creator [options].
  Future<EngineSymbol> write(
    Uint8List data, {
    required bool binary,
    required String format,
    required String options,
  });

  /// The zxing-cpp version inside the engine.
  Future<String> version();

  /// Completes when the backend stopped: disposed, crashed, or the isolate
  /// or worker exited. Pending calls fail with [EngineException].
  Future<void> get done;

  /// Stops the backend. Pending calls fail with [EngineException].
  void dispose();
}

/// Starts a backend for the current platform.
typedef BackendFactory = Future<EngineBackend> Function(String name);

/// A lazily started engine that restarts itself after a failure.
///
/// The backend starts on the first call. If it fails to start, or stops
/// unexpectedly, the failing calls throw [EngineException] and the next call
/// starts a new one.
final class BarcodeEngine {
  /// Creates an engine; [factory] is for tests.
  BarcodeEngine(this.name, {BackendFactory? factory})
    : _factory = factory ?? platform.spawnBackend;

  /// Reads files and creates barcodes for `BarcodeReader` and
  /// `BarcodeWriter`.
  static final BarcodeEngine shared = BarcodeEngine('flutter_zxing');

  /// Reads camera frames, so that reading a large file does not hold up
  /// the scanner.
  static final BarcodeEngine scanner = BarcodeEngine('flutter_zxing scanner');

  /// Name of the isolate or worker, for debugging.
  final String name;

  final BackendFactory _factory;
  Future<EngineBackend>? _backend;
  // Identifies the current start, so that a backend that stops after it
  // was replaced does not reset its successor.
  int _generation = 0;

  /// The running backend, started if necessary.
  Future<EngineBackend> get backend => _backend ??= _start(++_generation);

  Future<EngineBackend> _start(int generation) async {
    try {
      final EngineBackend backend = await _factory(name);
      unawaited(
        backend.done.whenComplete(() {
          if (_generation == generation) {
            _backend = null;
          }
        }),
      );
      return backend;
    } on Object catch (e) {
      if (_generation == generation) {
        _backend = null;
      }
      if (e is ZxingException) {
        rethrow;
      }
      throw EngineException('The barcode engine failed to start: $e');
    }
  }

  /// Starts the backend ahead of the first call.
  Future<void> warmUp() async {
    await backend;
  }

  /// See [EngineBackend.readImage].
  Future<EngineReadResult> readImage(
    Uint8List encodedImage,
    EngineReadOptions options,
  ) async => (await backend).readImage(encodedImage, options);

  /// See [EngineBackend.readPixels]. Throws [ArgumentError] if the buffer
  /// is smaller than its geometry says.
  Future<EngineReadResult> readPixels(
    PixelBuffer image,
    EngineReadOptions options,
  ) async {
    checkPixelBuffer(image);
    return (await backend).readPixels(image, options);
  }

  /// See [EngineBackend.write].
  Future<EngineSymbol> write(
    Uint8List data, {
    required bool binary,
    required String format,
    required String options,
  }) async => (await backend).write(
    data,
    binary: binary,
    format: format,
    options: options,
  );

  /// See [EngineBackend.version].
  Future<String> version() async => (await backend).version();

  /// Stops the backend; the next call starts a new one.
  Future<void> shutdown() async {
    final Future<EngineBackend>? backend = _backend;
    _backend = null;
    _generation++;
    if (backend != null) {
      try {
        (await backend).dispose();
      } on Object {
        // It never started: nothing to stop.
      }
    }
  }
}

/// Throws [ArgumentError] if [image] does not hold the pixels its geometry
/// describes.
void checkPixelBuffer(PixelBuffer image) {
  if (image.width <= 0 || image.height <= 0) {
    throw ArgumentError(
      'Invalid image size ${image.width} x ${image.height}',
      'image',
    );
  }
  final int rowBytes = image.width * image.layout.bytesPerPixel;
  final int stride = image.rowStride ?? rowBytes;
  if (stride < rowBytes) {
    throw ArgumentError.value(
      image.rowStride,
      'rowStride',
      'Smaller than width * bytesPerPixel ($rowBytes)',
    );
  }
  final int needed = stride * (image.height - 1) + rowBytes;
  if (image.bytes.length < needed) {
    throw ArgumentError(
      '${image.bytes.length} bytes for a ${image.width} x ${image.height} '
          '${image.layout.name} image, at least $needed expected',
      'image',
    );
  }
}
