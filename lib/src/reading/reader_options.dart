import 'package:flutter/foundation.dart';

/// How thoroughly the engine searches an image.
///
/// The defaults are tuned for photos and files (robust, still fast because
/// `BarcodeReader.read` stops at the first barcode). For camera frames use
/// [ReaderOptions.camera]: a missed frame costs nothing, the next one arrives
/// a few milliseconds later.
@immutable
final class ReaderOptions {
  /// Options for photos and files: every search strategy on.
  const ReaderOptions({
    this.tryHarder = true,
    this.tryRotate = true,
    this.tryInvert = true,
    this.tryDownscale = true,
    this.isPure = false,
    this.returnErrors = false,
    this.validateOptionalChecksum = false,
    this.binarizer = Binarizer.localAverage,
    this.minLineCount = 2,
    this.eanAddOn = EanAddOn.ignore,
  });

  /// Options for live camera frames: cheap per frame.
  const ReaderOptions.camera()
    : this(
        tryHarder: false,
        tryRotate: true,
        tryInvert: false,
        tryDownscale: true,
      );

  /// Spend more time to find barcodes in difficult images.
  final bool tryHarder;

  /// Also look for barcodes rotated by 90°, 180° and 270°.
  final bool tryRotate;

  /// Also look for inverted (light on dark) barcodes.
  final bool tryInvert;

  /// Also search a downscaled copy of large images (finds big, blurry codes).
  final bool tryDownscale;

  /// The image contains exactly one clean, unrotated, tightly cropped
  /// symbol (e.g. a generated barcode). Much faster, fails on photos.
  final bool isPure;

  /// Also return barcodes that were found but failed to decode, with
  /// `Barcode.error` set.
  final bool returnErrors;

  /// Check optional checksums (Code 39, ITF) and reject codes that fail.
  final bool validateOptionalChecksum;

  /// How the image is turned into black and white before detection.
  final Binarizer binarizer;

  /// For linear barcodes: how many scan lines must agree on a result.
  /// Higher values reduce false positives on noisy images.
  final int minLineCount;

  /// What to do with the EAN-2/EAN-5 add-on symbol printed next to some
  /// EAN-13 and UPC codes (the price on books, the issue on magazines).
  final EanAddOn eanAddOn;

  /// Creates a copy with the given fields replaced.
  ReaderOptions copyWith({
    bool? tryHarder,
    bool? tryRotate,
    bool? tryInvert,
    bool? tryDownscale,
    bool? isPure,
    bool? returnErrors,
    bool? validateOptionalChecksum,
    Binarizer? binarizer,
    int? minLineCount,
    EanAddOn? eanAddOn,
  }) => ReaderOptions(
    tryHarder: tryHarder ?? this.tryHarder,
    tryRotate: tryRotate ?? this.tryRotate,
    tryInvert: tryInvert ?? this.tryInvert,
    tryDownscale: tryDownscale ?? this.tryDownscale,
    isPure: isPure ?? this.isPure,
    returnErrors: returnErrors ?? this.returnErrors,
    validateOptionalChecksum:
        validateOptionalChecksum ?? this.validateOptionalChecksum,
    binarizer: binarizer ?? this.binarizer,
    minLineCount: minLineCount ?? this.minLineCount,
    eanAddOn: eanAddOn ?? this.eanAddOn,
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderOptions &&
      other.tryHarder == tryHarder &&
      other.tryRotate == tryRotate &&
      other.tryInvert == tryInvert &&
      other.tryDownscale == tryDownscale &&
      other.isPure == isPure &&
      other.returnErrors == returnErrors &&
      other.validateOptionalChecksum == validateOptionalChecksum &&
      other.binarizer == binarizer &&
      other.minLineCount == minLineCount &&
      other.eanAddOn == eanAddOn;

  @override
  int get hashCode => Object.hash(
    tryHarder,
    tryRotate,
    tryInvert,
    tryDownscale,
    isPure,
    returnErrors,
    validateOptionalChecksum,
    binarizer,
    minLineCount,
    eanAddOn,
  );
}

/// What to do with EAN-2/EAN-5 add-on symbols (see
/// [ReaderOptions.eanAddOn]).
///
/// ```dart
/// // Books: ISBN plus the price add-on, read as one barcode.
/// const reader = BarcodeReader(
///   formats: {BarcodeFormat.ean13},
///   options: ReaderOptions(eanAddOn: EanAddOn.require),
/// );
/// final book = await reader.read(bytes); // text: '978073520044951299'
/// ```
enum EanAddOn {
  /// Read the main symbol only, whether or not there is an add-on.
  ignore,

  /// Append the add-on to the text when there is one.
  read,

  /// Report EAN/UPC symbols only together with an add-on.
  require,
}

/// How an image is turned into black and white before detection.
enum Binarizer {
  /// Threshold from the local neighbourhood. Best for uneven lighting.
  localAverage,

  /// One threshold from the histogram. Fast, good for even lighting.
  globalHistogram,

  /// Fixed threshold at mid grey.
  fixedThreshold,

  /// Any non-zero pixel is light. For already binary images.
  boolCast,
}
