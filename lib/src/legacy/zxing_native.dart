// The 3.x API on native platforms, on the 4.0 engine.
//
// The synchronous calls (readBarcode, readBarcodes, encodeBarcode) call fzx
// directly on the calling isolate, as 3.x did. Everything that returns a
// Future runs on the engine isolates: image files and URLs on
// BarcodeEngine.shared, camera frames on BarcodeEngine.scanner. 3.x decoded
// image files on the calling isolate, which froze the UI for a second on a
// large photo (#74).
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:camera/camera.dart' show CameraImage, Plane, XFile;
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle;
import 'package:image/image.dart' as imglib;

import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import '../engine/barcode_engine.dart';
import '../engine/engine.dart';
import '../engine/engine_protocol.dart';
import '../engine/fzx_bindings.dart';
import '../engine/result_codec.dart';
import '../errors.dart';
import '../reading/pixel_buffer.dart';
import 'conversions.dart';
import 'image_converter.dart';
import 'models/models.dart';
import 'zxing.dart';

/// The [Zxing] of this platform.
Zxing getZxing() => ZxingNative();

/// Whether [Code.imageBytes] is filled in (`zx.setLogEnabled`).
bool _debugImages = false;

/// Callers of `startCameraProcessing` that have not stopped yet.
int _cameraUsers = 0;

/// Changes when the last camera user stops: frames still being read then
/// fail, as they did when 3.x stopped its isolate.
int _cameraSession = 0;

/// The 3.x [Zxing] on native platforms.
class ZxingNative implements Zxing {
  /// Creates the implementation; all instances share their state.
  ZxingNative();

  @override
  String version() => zxingCppVersion;

  @override
  void setLogEnabled(bool enabled) => _debugImages = enabled;

  @override
  String barcodeFormatName(int format) => barcodeNames[format] ?? 'Unknown';

  @override
  Encode encodeBarcode({
    required String contents,
    required EncodeParams params,
  }) {
    final BarcodeFormat? format = writeFormatOf(params.format);
    if (format == null) {
      return encodeError(
        params,
        contents,
        'Unsupported barcode format for encoding',
      );
    }
    try {
      final EngineSymbol symbol = _syncEngine.write(
        contents,
        format.zxingName,
        creatorOptionsOf(format, params),
      );
      return encodeOf(symbol, params, contents);
    } on Object catch (e) {
      return encodeError(params, contents, e);
    }
  }

  @override
  Future<void> startCameraProcessing() async {
    _cameraUsers++;
    try {
      await BarcodeEngine.scanner.warmUp();
    } on Object {
      if (_cameraUsers > 0) {
        _cameraUsers--;
      }
      rethrow;
    }
  }

  @override
  void stopCameraProcessing() {
    if (_cameraUsers > 0) {
      _cameraUsers--;
    }
    if (_cameraUsers == 0) {
      _cameraSession++;
    }
  }

  @override
  Future<Code> processCameraImage(
    CameraImage image,
    DecodeParams params,
  ) async {
    final int session = _cameraSessionOrThrow();
    final Stopwatch clock = Stopwatch()..start();
    Code code;
    try {
      final PixelBuffer pixels = _cameraPixels(image, params);
      final EngineReadResult first = await BarcodeEngine.scanner.readPixels(
        pixels,
        readOptionsOf(params, maxSymbols: 1, returnErrors: true),
      );
      Barcode? barcode = first.barcodes.firstOrNull;
      if (needsRetry(barcode)) {
        final EngineReadResult second = await BarcodeEngine.scanner.readPixels(
          pixels,
          readOptionsOf(params, maxSymbols: 1),
        );
        barcode = pickSingle(barcode, second.barcodes.firstOrNull);
      }
      code = codeOf(
        barcode,
        imageWidth: first.imageWidth,
        imageHeight: first.imageHeight,
        duration: clock.elapsedMilliseconds,
        source: CodeSource.camera,
        debugImage: _debugImages ? DebugImage.of(pixels) : null,
      );
    } on Object catch (e) {
      code = errorCode(e, CodeSource.camera);
    }
    _checkCameraSession(session);
    return code;
  }

  @override
  Future<Codes> processCameraImageMulti(
    CameraImage image,
    DecodeParams params,
  ) async {
    final int session = _cameraSessionOrThrow();
    final Stopwatch clock = Stopwatch()..start();
    Codes codes;
    try {
      final PixelBuffer pixels = _cameraPixels(image, params);
      final EngineReadResult result = await BarcodeEngine.scanner.readPixels(
        pixels,
        readOptionsOf(params, maxSymbols: maxSymbolsOf(params)),
      );
      codes = _codesOf(
        result,
        clock.elapsedMilliseconds,
        CodeSource.camera,
        _debugImages ? DebugImage.of(pixels) : null,
      );
    } on Object catch (e) {
      codes = Codes(error: errorMessage(e));
    }
    _checkCameraSession(session);
    return codes;
  }

  @override
  Future<Code> readBarcodeImagePathString(String path, DecodeParams params) =>
      readBarcodeImagePath(XFile(path), params);

  @override
  Future<Code> readBarcodeImagePath(XFile path, DecodeParams params) async {
    final Uint8List bytes;
    try {
      bytes = await path.readAsBytes();
    } on Object catch (e) {
      return Code(
        error: 'Failed to read image: $e',
        source: CodeSource.localImageFile,
      );
    }
    return _readImage(bytes, params, CodeSource.localImageFile);
  }

  @override
  Future<Code> readBarcodeImageUrl(String url, DecodeParams params) async {
    final Uint8List bytes;
    try {
      bytes = await _download(url);
    } on Object catch (e) {
      return Code(
        error: 'Failed to load image from $url: $e',
        source: CodeSource.remoteImageFile,
      );
    }
    return _readImage(bytes, params, CodeSource.remoteImageFile);
  }

  @override
  Code readBarcode(Uint8List bytes, DecodeParams params) {
    final Stopwatch clock = Stopwatch()..start();
    try {
      final PixelBuffer image = pixelBufferOf(bytes, params);
      final EngineReadResult first = _syncEngine.read(
        image,
        readOptionsOf(params, maxSymbols: 1, returnErrors: true),
      );
      Barcode? barcode = first.barcodes.firstOrNull;
      if (needsRetry(barcode)) {
        barcode = pickSingle(
          barcode,
          _syncEngine
              .read(image, readOptionsOf(params, maxSymbols: 1))
              .barcodes
              .firstOrNull,
        );
      }
      return codeOf(
        barcode,
        imageWidth: first.imageWidth,
        imageHeight: first.imageHeight,
        duration: clock.elapsedMilliseconds,
        source: CodeSource.byteStream,
        debugImage: _debugImages ? DebugImage.of(image) : null,
      );
    } on Object catch (e) {
      return errorCode(e, CodeSource.byteStream);
    }
  }

  @override
  Future<Codes> readBarcodesImagePathString(String path, DecodeParams params) =>
      readBarcodesImagePath(XFile(path), params);

  @override
  Future<Codes> readBarcodesImagePath(XFile path, DecodeParams params) async {
    final Uint8List bytes;
    try {
      bytes = await path.readAsBytes();
    } on Object catch (e) {
      return Codes(error: 'Failed to read image: $e');
    }
    return _readImageAll(bytes, params, CodeSource.localImageFile);
  }

  @override
  Future<Codes> readBarcodesImageUrl(String url, DecodeParams params) async {
    final Uint8List bytes;
    try {
      bytes = await _download(url);
    } on Object catch (e) {
      return Codes(error: 'Failed to load image from $url: $e');
    }
    return _readImageAll(bytes, params, CodeSource.remoteImageFile);
  }

  @override
  Codes readBarcodes(Uint8List bytes, DecodeParams params) {
    final Stopwatch clock = Stopwatch()..start();
    try {
      final PixelBuffer image = pixelBufferOf(bytes, params);
      final EngineReadResult result = _syncEngine.read(
        image,
        readOptionsOf(params, maxSymbols: maxSymbolsOf(params)),
      );
      return _codesOf(
        result,
        clock.elapsedMilliseconds,
        CodeSource.byteStream,
        _debugImages ? DebugImage.of(image) : null,
      );
    } on Object catch (e) {
      return Codes(error: errorMessage(e));
    }
  }
}

int _cameraSessionOrThrow() {
  if (_cameraUsers == 0) {
    throw StateError(
      'Camera processing is not running. '
      'Call `zx.startCameraProcessing()` before processing camera images.',
    );
  }
  return _cameraSession;
}

void _checkCameraSession(int session) {
  if (session != _cameraSession) {
    throw StateError(
      'Camera processing was stopped before the image was decoded.',
    );
  }
}

/// The scanned plane of a camera frame: the luminance (Y) plane of YUV420
/// and NV21 frames, the only plane of BGRA ones; row padding is skipped
/// through the row stride, not copied away.
PixelBuffer _cameraPixels(CameraImage image, DecodeParams params) {
  final Plane plane = image.planes.first;
  return pixelBufferOf(
    plane.bytes,
    params,
    width: params.width > 0 ? params.width : image.width,
    height: params.height > 0 ? params.height : image.height,
    rowStride: plane.bytesPerRow,
  );
}

Future<Uint8List> _download(String url) async {
  final ByteData data = await NetworkAssetBundle(Uri.parse(url)).load(url);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// `readBarcodeImage*`: the first barcode of an image file.
Future<Code> _readImage(
  Uint8List bytes,
  DecodeParams params,
  CodeSource source,
) async {
  final Stopwatch clock = Stopwatch()..start();
  final _EncodedImage image = _EncodedImage(bytes);
  final bool downscale = params.maxSize > 0;
  try {
    final EngineReadResult first = await image.read(
      readOptionsOf(
        params,
        maxSymbols: 1,
        returnErrors: true,
        downscale: downscale,
      ),
    );
    Barcode? barcode = first.barcodes.firstOrNull;
    if (needsRetry(barcode)) {
      final EngineReadResult second = await image.read(
        readOptionsOf(params, maxSymbols: 1, downscale: downscale),
      );
      barcode = pickSingle(barcode, second.barcodes.firstOrNull);
    }
    return codeOf(
      barcode,
      imageWidth: first.imageWidth,
      imageHeight: first.imageHeight,
      duration: clock.elapsedMilliseconds,
      source: source,
    );
  } on ImageDecodeException catch (e) {
    return Code(error: 'Failed to decode image: ${e.message}', source: source);
  } on Object catch (e) {
    return errorCode(e, source);
  }
}

/// `readBarcodesImage*`: every barcode of an image file.
Future<Codes> _readImageAll(
  Uint8List bytes,
  DecodeParams params,
  CodeSource source,
) async {
  final Stopwatch clock = Stopwatch()..start();
  try {
    final EngineReadResult result = await _EncodedImage(bytes).read(
      readOptionsOf(
        params,
        maxSymbols: maxSymbolsOf(params),
        downscale: params.maxSize > 0,
      ),
    );
    return _codesOf(result, clock.elapsedMilliseconds, source);
  } on ImageDecodeException catch (e) {
    return Codes(error: 'Failed to decode image: ${e.message}');
  } on Object catch (e) {
    return Codes(error: errorMessage(e));
  }
}

/// The valid barcodes of [result] as 3.x [Codes].
Codes _codesOf(
  EngineReadResult result,
  int duration,
  CodeSource source, [
  DebugImage? debugImage,
]) => Codes(
  codes: <Code>[
    for (final Barcode barcode in result.barcodes)
      if (barcode.isValid)
        codeOf(
          barcode,
          imageWidth: result.imageWidth,
          imageHeight: result.imageHeight,
          duration: duration,
          source: source,
          debugImage: debugImage,
        ),
  ],
  duration: duration,
);

/// An image file, read by the engine (stb: JPEG, PNG, GIF, BMP) or, for the
/// other formats 3.x read through package:image (WebP, TIFF, ...), decoded
/// with package:image on a background isolate first.
final class _EncodedImage {
  _EncodedImage(this._bytes);

  final Uint8List _bytes;
  PixelBuffer? _pixels;

  Future<EngineReadResult> read(EngineReadOptions options) async {
    if (_pixels case final PixelBuffer pixels) {
      return BarcodeEngine.shared.readPixels(pixels, options);
    }
    try {
      return await BarcodeEngine.shared.readImage(_bytes, options);
    } on ImageDecodeException {
      final Uint8List bytes = _bytes;
      final PixelBuffer? pixels = await Isolate.run(
        () => _decodeWithImagePackage(bytes),
      );
      if (pixels == null) {
        rethrow;
      }
      _pixels = pixels;
      return BarcodeEngine.shared.readPixels(pixels, options);
    }
  }
}

PixelBuffer? _decodeWithImagePackage(Uint8List bytes) {
  try {
    final imglib.Image? image = imglib.decodeImage(bytes);
    if (image == null) {
      return null;
    }
    return PixelBuffer(
      rgbBytes(image),
      width: image.width,
      height: image.height,
      layout: PixelLayout.rgb,
    );
  } on Object {
    // A truncated or corrupt file can make a decoder throw rather than
    // decline.
    return null;
  }
}

/// fzx on the calling isolate, for the synchronous 3.x calls. One per
/// isolate (globals are per isolate), kept for the isolate's lifetime.
final _SyncEngine _syncEngine = _SyncEngine();

final class _SyncEngine {
  Pointer<FzxContext>? _context;

  Pointer<FzxContext> get _ctx {
    if (_context case final Pointer<FzxContext> ctx) {
      return ctx;
    }
    final int abi = fzxAbiVersion();
    if (abi != fzxExpectedAbiVersion) {
      throw EngineException(
        'The barcode engine library has ABI version $abi, this version of '
        'flutter_zxing needs $fzxExpectedAbiVersion. Run `flutter clean`.',
      );
    }
    final Pointer<FzxContext> ctx = fzxNew();
    if (ctx == nullptr) {
      throw const EngineException('The barcode engine is out of memory');
    }
    return _context = ctx;
  }

  /// [bytes] in the context's reusable input buffer.
  Pointer<Uint8> _input(Pointer<FzxContext> ctx, Uint8List bytes) {
    if (bytes.isEmpty) {
      return nullptr;
    }
    final Pointer<Uint8> input = fzxInput(ctx, bytes.length);
    if (input == nullptr) {
      throw const EngineException('The barcode engine is out of memory');
    }
    input.asTypedList(bytes.length).setAll(0, bytes);
    return input;
  }

  Never _fail(Pointer<FzxContext> ctx, int code) =>
      throwFzxError(code, fzxError(ctx).cast<Utf8>().toDartString());

  Uint8List _result(Pointer<FzxContext> ctx) =>
      fzxResult(ctx).asTypedList(fzxResultSize(ctx));

  EngineReadResult read(PixelBuffer image, EngineReadOptions options) {
    checkPixelBuffer(image);
    final Pointer<FzxContext> ctx = _ctx;
    final Pointer<Uint8> input = _input(ctx, image.bytes);
    final Pointer<Utf8> formats = options.formats.toNativeUtf8();
    try {
      final Rect? crop = image.crop;
      final int code = fzxRead(
        ctx,
        input,
        image.width,
        image.height,
        image.rowStride ?? 0,
        image.layout.index,
        crop?.left.round() ?? 0,
        crop?.top.round() ?? 0,
        crop?.width.round() ?? 0,
        crop?.height.round() ?? 0,
        formats.cast<Char>(),
        options.flags,
        options.binarizer,
        options.maxSymbols,
        options.minLineCount,
      );
      if (code < 0) {
        _fail(ctx, code);
      }
      return decodeBarcodes(_result(ctx));
    } finally {
      malloc.free(formats);
    }
  }

  EngineSymbol write(String contents, String format, String options) {
    final Pointer<FzxContext> ctx = _ctx;
    final Uint8List data = utf8.encode(contents);
    final Pointer<Uint8> input = _input(ctx, data);
    final Pointer<Utf8> formatName = format.toNativeUtf8();
    final Pointer<Utf8> creatorOptions = options.toNativeUtf8();
    try {
      final int code = fzxWrite(
        ctx,
        input,
        data.length,
        0,
        formatName.cast<Char>(),
        creatorOptions.cast<Char>(),
      );
      if (code < 0) {
        _fail(ctx, code);
      }
      return decodeSymbol(_result(ctx));
    } finally {
      malloc
        ..free(formatName)
        ..free(creatorOptions);
    }
  }
}
