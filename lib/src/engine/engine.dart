// The engine behind BarcodeReader, BarcodeWriter and the scanner: fzx running
// off the UI thread, on a long-lived isolate (native platforms) or in a Web
// Worker (web). Not exported from the package.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect;

import '../barcode/barcode.dart';

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

  /// Reads the barcodes in raw pixels. With [mirrored], the pixels show a
  /// mirror image (the front camera on iOS) and are flipped back before
  /// decoding, which some symbologies need (Data Matrix); positions are
  /// still in the pixels as given.
  Future<EngineReadResult> readPixels(
    PixelBuffer image,
    EngineReadOptions options, {
    bool mirrored = false,
  });

  /// Encodes [data] into a symbol of [format] (a zxing-cpp format name)
  /// with zxing-cpp creator [options].
  Future<EngineSymbol> write(
    Uint8List data, {
    required bool binary,
    required String format,
    required String options,
  });

  /// Joins the parts of a structured append sequence: [data] is
  /// `mergeInput`, [characterSet] a zxing-cpp `CharacterSet` (0 guesses).
  Future<EngineMerged> merge(Uint8List data, int characterSet);

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

  /// Whether a backend is running or starting.
  bool get isStarted => _backend != null;

  /// Starts the backend ahead of the first call.
  Future<void> warmUp() async {
    await backend;
  }

  /// Starts the backend ahead of the first call, never failing: if it
  /// cannot start, the first real call starts it again and reports why.
  Future<void> tryWarmUp() async {
    try {
      await backend;
    } on Object {
      // Left for the first real call to report.
    }
  }

  /// See [EngineBackend.readImage]. An image the backend cannot decode
  /// (on native platforms stb_image knows JPEG, PNG, GIF and BMP) is
  /// decoded by Flutter, which also knows WebP and WBMP and what the
  /// platform adds (HEIF/HEIC on Android 9+), and read as pixels. Throws the
  /// backend's [ImageDecodeException] if Flutter cannot decode it either,
  /// and an [ImageDecodeException] for an image too large to read
  /// ([checkImageSize]), which Flutter does not try.
  Future<EngineReadResult> readImage(
    Uint8List encodedImage,
    EngineReadOptions options,
  ) async {
    final EngineBackend b = await backend;
    try {
      return (await b.readImage(encodedImage, options)).asPrinted(options);
    } on ImageDecodeException catch (e, stack) {
      if (isImageTooLarge(e)) {
        rethrow;
      }
      final PixelBuffer? pixels = await decodeWithFlutter(encodedImage);
      if (pixels == null) {
        Error.throwWithStackTrace(e, stack);
      }
      return readPixels(pixels, options);
    }
  }

  /// See [EngineBackend.readPixels]. Throws [ArgumentError] if the buffer
  /// is smaller than its geometry says. A crop is cut to the image; one
  /// outside it, or empty, finds nothing.
  Future<EngineReadResult> readPixels(
    PixelBuffer image,
    EngineReadOptions options, {
    bool mirrored = false,
  }) async {
    checkPixelBuffer(image);
    final Rect? crop = image.crop;
    if (crop != null) {
      final Rect inside = crop.intersect(
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      );
      if (inside.width <= 0 || inside.height <= 0) {
        return EngineReadResult(
          barcodes: const <Barcode>[],
          imageWidth: image.width,
          imageHeight: image.height,
        );
      }
      if (inside != crop) {
        image = PixelBuffer(
          image.bytes,
          width: image.width,
          height: image.height,
          layout: image.layout,
          rowStride: image.rowStride,
          crop: inside,
        );
      }
    }
    return (await backend)
        .readPixels(image, options, mirrored: mirrored)
        .then((EngineReadResult r) => r.asPrinted(options));
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

  /// See [EngineBackend.merge].
  Future<EngineMerged> merge(Uint8List data, int characterSet) async =>
      (await backend).merge(data, characterSet);

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

/// [encodedImage] decoded by Flutter's image codecs (the first frame of an
/// animation), as straight (not premultiplied) RGBA like stb_image reads
/// it; `null` if Flutter cannot decode it, or cannot decode at all here
/// (a background isolate). Throws [ImageDecodeException] for an image too
/// large to read ([checkImageSize]), without decoding it where the size
/// is known from the header.
Future<PixelBuffer?> decodeWithFlutter(Uint8List encodedImage) async {
  if (encodedImage.isEmpty) {
    return null;
  }
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(encodedImage);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    // The size from the header, before decoding (not known on the web).
    final (int, int)? size = _headerSize(descriptor);
    if (size != null) {
      checkImageSize(size.$1, size.$2);
    }
    codec = await descriptor.instantiateCodec();
    image = (await codec.getNextFrame()).image;
    checkImageSize(image.width, image.height);
    final ByteData? rgba = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (rgba == null) {
      return null;
    }
    return PixelBuffer(
      rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
      width: image.width,
      height: image.height,
      layout: PixelLayout.rgba,
    );
  } on ImageDecodeException {
    rethrow;
  } on Object {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

(int, int)? _headerSize(ui.ImageDescriptor descriptor) {
  try {
    return (descriptor.width, descriptor.height);
  } on UnsupportedError {
    return null;
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
