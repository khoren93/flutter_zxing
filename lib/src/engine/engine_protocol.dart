// What the Dart side and native/fzx.h agree on: option flags, error codes,
// and the values passed to and returned from the engine. Platform
// independent; used by both backends and by the result codec.
import 'package:flutter/foundation.dart';

import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import '../errors.dart';
import '../reading/reader_options.dart';

/// `FZX_ABI_VERSION` this Dart code is written against. The engine refuses
/// to start with a library or WebAssembly module of another version.
const int fzxExpectedAbiVersion = 1;

/// Reader flags (`FZX_TRY_*`, ...).
abstract final class FzxFlags {
  static const int tryHarder = 1 << 0;
  static const int tryRotate = 1 << 1;
  static const int tryInvert = 1 << 2;
  static const int tryDownscale = 1 << 3;
  static const int isPure = 1 << 4;
  static const int returnErrors = 1 << 5;
  static const int validateOptionalChecksum = 1 << 6;

  /// zxing-cpp `TextMode::Plain` instead of the default HRI. Engine
  /// internal: the corpus tests compare text the way zxing-cpp's do.
  static const int textPlain = (0 + 1) << 8;
}

/// Error codes returned by the fzx functions (`FZX_ERR_*`).
abstract final class FzxError {
  static const int argument = -1;
  static const int image = -2;
  static const int write = -3;
  static const int noWriter = -4;
  static const int internal = -5;
}

/// Throws the exception the public API documents for an fzx error [code].
Never throwFzxError(int code, String message) {
  switch (code) {
    case FzxError.image:
      throw ImageDecodeException(message);
    case FzxError.write:
      throw BarcodeWriteException(message);
    case FzxError.argument:
      throw ArgumentError(message);
    default:
      throw EngineException(message);
  }
}

/// Reader settings in the form the engine takes them.
@immutable
final class EngineReadOptions {
  /// Creates options from raw engine values.
  const EngineReadOptions({
    this.formats = '',
    this.flags =
        FzxFlags.tryHarder |
        FzxFlags.tryRotate |
        FzxFlags.tryInvert |
        FzxFlags.tryDownscale,
    this.binarizer = 0,
    this.maxSymbols = 0,
    this.minLineCount = 2,
  });

  /// Converts the public reader settings. [maxSymbols] 0 means no limit.
  factory EngineReadOptions.from(
    Set<BarcodeFormat>? formats,
    ReaderOptions options, {
    int maxSymbols = 0,
  }) => EngineReadOptions(
    formats: formatsToEngine(formats),
    flags:
        (options.tryHarder ? FzxFlags.tryHarder : 0) |
        (options.tryRotate ? FzxFlags.tryRotate : 0) |
        (options.tryInvert ? FzxFlags.tryInvert : 0) |
        (options.tryDownscale ? FzxFlags.tryDownscale : 0) |
        (options.isPure ? FzxFlags.isPure : 0) |
        (options.returnErrors ? FzxFlags.returnErrors : 0) |
        (options.validateOptionalChecksum
            ? FzxFlags.validateOptionalChecksum
            : 0),
    binarizer: options.binarizer.index,
    maxSymbols: maxSymbols,
    minLineCount: options.minLineCount,
  );

  /// Comma separated zxing-cpp format names, `''` for all formats.
  final String formats;

  /// `FzxFlags` bits.
  final int flags;

  /// `Binarizer.index`, which follows zxing-cpp's order.
  final int binarizer;

  /// Stop after this many barcodes; 0 means no limit.
  final int maxSymbols;

  /// Scan lines that must agree on a linear barcode.
  final int minLineCount;

  /// The same options with another [maxSymbols].
  EngineReadOptions withMaxSymbols(int maxSymbols) => EngineReadOptions(
    formats: formats,
    flags: flags,
    binarizer: binarizer,
    maxSymbols: maxSymbols,
    minLineCount: minLineCount,
  );

  /// The engine form of a format filter: `null` (all formats) becomes `''`.
  ///
  /// Throws [ArgumentError] for [BarcodeFormat.unknown], which only ever
  /// describes results.
  static String formatsToEngine(Set<BarcodeFormat>? formats) {
    if (formats == null || formats.isEmpty) {
      return '';
    }
    if (formats.contains(BarcodeFormat.unknown)) {
      throw ArgumentError.value(
        formats,
        'formats',
        'BarcodeFormat.unknown cannot be searched for',
      );
    }
    return formats.map((BarcodeFormat f) => f.zxingName).join(',');
  }

  @override
  bool operator ==(Object other) =>
      other is EngineReadOptions &&
      other.formats == formats &&
      other.flags == flags &&
      other.binarizer == binarizer &&
      other.maxSymbols == maxSymbols &&
      other.minLineCount == minLineCount;

  @override
  int get hashCode =>
      Object.hash(formats, flags, binarizer, maxSymbols, minLineCount);
}

/// Barcodes found by one engine call.
@immutable
final class EngineReadResult {
  /// Creates a result.
  const EngineReadResult({
    required this.barcodes,
    required this.imageWidth,
    required this.imageHeight,
    this.engineMicros = 0,
  });

  /// The barcodes, positions in pixels of the whole image.
  final List<Barcode> barcodes;

  /// Width of the decoded image in pixels.
  final int imageWidth;

  /// Height of the decoded image in pixels.
  final int imageHeight;

  /// Time spent inside the engine call, without message passing. For
  /// benchmarks only.
  final int engineMicros;

  /// The same result with [engineMicros] set.
  EngineReadResult withEngineMicros(int micros) => EngineReadResult(
    barcodes: barcodes,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    engineMicros: micros,
  );
}

/// A barcode created by the engine: the module matrix and its metadata.
@immutable
final class EngineSymbol {
  /// Creates a symbol.
  const EngineSymbol({
    required this.format,
    required this.width,
    required this.height,
    required this.modules,
    this.quietZoneLeft = 0,
    this.quietZoneTop = 0,
    this.quietZoneRight = 0,
    this.quietZoneBottom = 0,
    this.text = '',
    this.ecLevel = '',
    this.version = '',
  });

  /// The format zxing-cpp reports for the created symbol.
  final BarcodeFormat format;

  /// Width in modules, without quiet zones.
  final int width;

  /// Height in modules (bar height for linear formats), without quiet zones.
  final int height;

  /// `width * height` bytes, row by row: 1 is dark, 0 is light.
  final Uint8List modules;

  /// Quiet zone the symbology requires on the left, in modules.
  final int quietZoneLeft;

  /// Quiet zone the symbology requires at the top, in modules.
  final int quietZoneTop;

  /// Quiet zone the symbology requires on the right, in modules.
  final int quietZoneRight;

  /// Quiet zone the symbology requires at the bottom, in modules.
  final int quietZoneBottom;

  /// The encoded content as text (human readable form for GS1).
  final String text;

  /// Error correction level of the created symbol, `''` if none.
  final String ecLevel;

  /// Version (size) of the created symbol, `''` if none.
  final String version;
}
