// What the Dart side and native/fzx.h agree on: option flags, error codes,
// and the values passed to and returned from the engine. Platform
// independent; used by both backends and by the result codec.
import 'package:flutter/foundation.dart';

import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import '../barcode/upc.dart';
import '../errors.dart';
import '../reading/reader_options.dart';

/// `FZX_ABI_VERSION` this Dart code is written against. The engine refuses
/// to start with a library or WebAssembly module of another version.
const int fzxExpectedAbiVersion = 4;

/// `FZX_MAX_IMAGE_PIXELS`: images over this many pixels are not read.
const int fzxMaxImagePixels = 128000000;

/// `FZX_MAX_IMAGE_SIDE`: images wider or taller than this are not read.
const int fzxMaxImageSide = 65535;

/// Throws the [ImageDecodeException] of the engine (`fzx_read_file`) if an
/// image of [width] x [height] pixels is too large to read: a small file
/// can declare an image of gigabytes.
void checkImageSize(int width, int height) {
  if (width > fzxMaxImageSide ||
      height > fzxMaxImageSide ||
      width * height > fzxMaxImagePixels) {
    throw ImageDecodeException(
      'Image too large: $width x $height pixels, at most 128 megapixels and '
      '65535 pixels a side are read',
    );
  }
}

/// Whether [e] says that an image is too large to read ([checkImageSize]
/// or `fzx_read_file`): decoding it another way would not help.
bool isImageTooLarge(ImageDecodeException e) =>
    e.message.startsWith('Image too large');

/// Flags for zxing-cpp's downscaleFactor and downscaleThreshold, for the
/// example's diagnostics page. [factor] is 2, 3 or 4, [threshold] in pixels
/// below 4096; `null` keeps zxing-cpp's default.
int fzxDownscaleFlags({int? factor, int? threshold}) =>
    (factor == null ? 0 : (factor - 1) << 14) |
    (threshold == null ? 0 : threshold << 16);

/// Reader flags (`FZX_TRY_*`, ...).
abstract final class FzxFlags {
  static const int tryHarder = 1 << 0;
  static const int tryRotate = 1 << 1;
  static const int tryInvert = 1 << 2;
  static const int tryDownscale = 1 << 3;
  static const int isPure = 1 << 4;
  static const int returnErrors = 1 << 5;
  static const int validateOptionalChecksum = 1 << 6;

  /// Read without alpha, as zxing-cpp does: the 3.x API. Otherwise pixels
  /// that are not opaque are put on white.
  static const int ignoreAlpha = 1 << 7;

  /// zxing-cpp `TextMode::Plain` instead of the default HRI. Engine
  /// internal: the corpus tests compare text the way zxing-cpp's do.
  static const int textPlain = (0 + 1) << 8;

  /// Shift of the EAN-2/EAN-5 add-on mode, `EanAddOn.index` (zxing-cpp's
  /// order).
  static const int eanAddOnShift = 12;
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
      throw BarcodeWriteException(writeErrorMessage(message));
    case FzxError.argument:
      throw ArgumentError(message);
    default:
      throw EngineException(message);
  }
}

/// zint's message without its error number and return value:
/// `Error 275: Invalid check digit '4', expecting '3' (retval: 7)` becomes
/// `Invalid check digit '4', expecting '3'`.
String writeErrorMessage(String message) => message
    .replaceFirst(RegExp(r'^Error \d+: '), '')
    .replaceFirst(RegExp(r' \(retval: \d+\)$'), '');

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
    this.characterSet = 0,
    this.upcAsPrinted = false,
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
            : 0) |
        options.eanAddOn.index << FzxFlags.eanAddOnShift,
    binarizer: options.binarizer.index,
    maxSymbols: maxSymbols,
    minLineCount: options.minLineCount,
    characterSet: options.characterSet?.engineId ?? 0,
    upcAsPrinted: true,
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

  /// zxing-cpp `CharacterSet` of barcodes that declare none; 0 guesses.
  final int characterSet;

  /// Give UPC-A and UPC-E as printed (12 and 8 digits, UPC-A not as
  /// EAN-13): the 4.0 API. The 3.x API keeps zxing-cpp's 13 digits.
  final bool upcAsPrinted;

  /// The same options with [extra] flags added.
  EngineReadOptions withFlags(int extra) => EngineReadOptions(
    formats: formats,
    flags: flags | extra,
    binarizer: binarizer,
    maxSymbols: maxSymbols,
    minLineCount: minLineCount,
    characterSet: characterSet,
    upcAsPrinted: upcAsPrinted,
  );

  /// The same options with another [maxSymbols].
  EngineReadOptions withMaxSymbols(int maxSymbols) => EngineReadOptions(
    formats: formats,
    flags: flags,
    binarizer: binarizer,
    maxSymbols: maxSymbols,
    minLineCount: minLineCount,
    characterSet: characterSet,
    upcAsPrinted: upcAsPrinted,
  );

  /// The engine form of a format filter: `null` (all formats) becomes `''`.
  ///
  /// The one check of a format filter, for `BarcodeReader` and
  /// `ScannerController` alike. Throws [ArgumentError] for an empty set
  /// (a filter that finds nothing is a mistake: `null` means all formats)
  /// and for formats that cannot be read ([BarcodeFormat.canRead]): the
  /// EAN-2/EAN-5 add-ons, [BarcodeFormat.isbn] and [BarcodeFormat.unknown].
  /// The message names each format as it is written in code.
  static String formatsToEngine(Set<BarcodeFormat>? formats) {
    if (formats == null) {
      return '';
    }
    if (formats.isEmpty) {
      throw ArgumentError.value(
        formats,
        'formats',
        'Empty: no barcode would ever be found. Pass null to read every '
            'format',
      );
    }
    final List<BarcodeFormat> unreadable = <BarcodeFormat>[
      for (final BarcodeFormat f in formats)
        if (!f.canRead) f,
    ];
    if (unreadable.isNotEmpty) {
      throw ArgumentError.value(
        formats,
        'formats',
        unreadable.map(_whyUnreadable).join('; '),
      );
    }
    return formats.map((BarcodeFormat f) => f.zxingName).join(',');
  }

  static String _whyUnreadable(BarcodeFormat format) {
    final String name = 'BarcodeFormat.${format.name}';
    return switch (format) {
      BarcodeFormat.unknown => '$name cannot be searched for',
      BarcodeFormat.isbn =>
        '$name cannot be read: ISBNs are read as BarcodeFormat.ean13',
      BarcodeFormat.ean2 || BarcodeFormat.ean5 =>
        '$name cannot be read on its own: add-ons come with their EAN-13, '
            'EAN-8, UPC-A or UPC-E, see ReaderOptions.eanAddOn',
      _ => '$name cannot be read',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is EngineReadOptions &&
      other.formats == formats &&
      other.flags == flags &&
      other.binarizer == binarizer &&
      other.maxSymbols == maxSymbols &&
      other.minLineCount == minLineCount &&
      other.characterSet == characterSet;

  @override
  int get hashCode => Object.hash(
    formats,
    flags,
    binarizer,
    maxSymbols,
    minLineCount,
    characterSet,
  );
}

/// What the engine knows about a barcode beyond the public [Barcode], for
/// the example's diagnostics page.
@immutable
final class EngineBarcodeDetails {
  /// Creates the details.
  const EngineBarcodeDetails({required this.lineCount, required this.extra});

  /// Scan lines that agreed on a linear barcode.
  final int lineCount;

  /// zxing-cpp's extra metadata as a JSON object, may be empty.
  final String extra;
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
    this.details = const <EngineBarcodeDetails>[],
  });

  /// The barcodes, positions in pixels of the whole image.
  final List<Barcode> barcodes;

  /// The details of [barcodes], in the same order.
  final List<EngineBarcodeDetails> details;

  /// Width of the decoded image in pixels.
  final int imageWidth;

  /// Height of the decoded image in pixels.
  final int imageHeight;

  /// Time spent inside the engine call, without message passing. For
  /// benchmarks only.
  final int engineMicros;

  /// This result with UPC-A and UPC-E as printed, if [options] ask for it.
  EngineReadResult asPrinted(EngineReadOptions options) =>
      !options.upcAsPrinted ||
          !barcodes.any(
            (Barcode b) => b.format.symbology == BarcodeFormat.eanUpc,
          )
      ? this
      : EngineReadResult(
          barcodes: <Barcode>[
            for (final Barcode b in barcodes) upcAsPrinted(b, options.formats),
          ],
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          engineMicros: engineMicros,
          details: details,
        );

  /// The same result with [engineMicros] set.
  EngineReadResult withEngineMicros(int micros) => EngineReadResult(
    barcodes: barcodes,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    engineMicros: micros,
    details: details,
  );
}

/// The parts of a structured append sequence joined by the engine
/// (`fzx_merge`).
@immutable
final class EngineMerged {
  /// Creates a merged message.
  const EngineMerged({
    required this.contentType,
    required this.text,
    required this.bytes,
  });

  /// How to interpret the payload.
  final BarcodeContentType contentType;

  /// The text, decoded as zxing-cpp decodes it.
  final String text;

  /// The raw bytes of every part, in order.
  final Uint8List bytes;
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
