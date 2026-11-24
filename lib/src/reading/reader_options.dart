import 'package:flutter/foundation.dart';

/// How thoroughly the engine searches an image.
///
/// The defaults are tuned for photos and files (robust, still fast because
/// `BarcodeReader.read` stops at the first barcode). For camera frames use
/// [ReaderOptions.camera], which leaves out what a camera rarely sees.
@immutable
final class ReaderOptions {
  /// Options for photos and files: every search strategy on.
  const ReaderOptions({
    this.tryHarder = true,
    this.tryRotate = true,
    this.tryInvert = true,
    this.tryDownscale = true,
    this.tryDenoise = false,
    this.isPure = false,
    this.returnErrors = false,
    this.validateOptionalChecksum = false,
    this.binarizer = Binarizer.localAverage,
    this.minLineCount = 2,
    this.eanAddOn = EanAddOn.ignore,
    this.characterSet,
  });

  /// Options for live camera frames: like the defaults, without looking for
  /// inverted (light on dark) barcodes.
  ///
  /// [tryHarder] stays on: without it zxing-cpp runs only its fast Data
  /// Matrix detector, which misses a rectangular Data Matrix at some angles
  /// in every frame, not just in one. With it, a frame takes up to three
  /// times longer when it has no barcode (a few milliseconds on a 2020
  /// phone, well inside the time between two camera frames) and is often
  /// faster when it has one.
  const ReaderOptions.camera()
    : this(
        tryHarder: true,
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

  /// Also look for 2D codes (QR, Data Matrix, Aztec) in a cleaned-up copy
  /// of the image, where small gaps between dark modules are closed. Helps
  /// with dot-printed, worn or poorly printed codes. Off by default: it
  /// adds a second pass to every image without a code.
  final bool tryDenoise;

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
  /// Higher values reduce false positives on noisy images. The engine
  /// takes 1 to 255: a larger value counts as 255, and 0 or less as the
  /// default, 2.
  final int minLineCount;

  /// What to do with the EAN-2/EAN-5 add-on symbol printed next to some
  /// EAN and UPC codes (the price on books, the issue on magazines). It
  /// comes with an EAN-13, EAN-8, UPC-A or UPC-E.
  final EanAddOn eanAddOn;

  /// The character set of barcodes that do not declare one (with an ECI),
  /// e.g. [CharacterSet.cp1251] for old Russian labels or
  /// [CharacterSet.shiftJis] for Japanese ones. `null`: the engine guesses
  /// it from the bytes, which can go wrong for short texts.
  final CharacterSet? characterSet;

  /// Creates a copy with the given fields replaced.
  ///
  /// A `null` argument keeps the field, so `copyWith` cannot set
  /// [characterSet] back to `null` (guess). Create the options anew for
  /// that, or start from `const ReaderOptions()`.
  ReaderOptions copyWith({
    bool? tryHarder,
    bool? tryRotate,
    bool? tryInvert,
    bool? tryDownscale,
    bool? tryDenoise,
    bool? isPure,
    bool? returnErrors,
    bool? validateOptionalChecksum,
    Binarizer? binarizer,
    int? minLineCount,
    EanAddOn? eanAddOn,
    CharacterSet? characterSet,
  }) => ReaderOptions(
    tryHarder: tryHarder ?? this.tryHarder,
    tryRotate: tryRotate ?? this.tryRotate,
    tryInvert: tryInvert ?? this.tryInvert,
    tryDownscale: tryDownscale ?? this.tryDownscale,
    tryDenoise: tryDenoise ?? this.tryDenoise,
    isPure: isPure ?? this.isPure,
    returnErrors: returnErrors ?? this.returnErrors,
    validateOptionalChecksum:
        validateOptionalChecksum ?? this.validateOptionalChecksum,
    binarizer: binarizer ?? this.binarizer,
    minLineCount: minLineCount ?? this.minLineCount,
    eanAddOn: eanAddOn ?? this.eanAddOn,
    characterSet: characterSet ?? this.characterSet,
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderOptions &&
      other.tryHarder == tryHarder &&
      other.tryRotate == tryRotate &&
      other.tryInvert == tryInvert &&
      other.tryDownscale == tryDownscale &&
      other.tryDenoise == tryDenoise &&
      other.isPure == isPure &&
      other.returnErrors == returnErrors &&
      other.validateOptionalChecksum == validateOptionalChecksum &&
      other.binarizer == binarizer &&
      other.minLineCount == minLineCount &&
      other.eanAddOn == eanAddOn &&
      other.characterSet == characterSet;

  @override
  int get hashCode => Object.hash(
    tryHarder,
    tryRotate,
    tryInvert,
    tryDownscale,
    tryDenoise,
    isPure,
    returnErrors,
    validateOptionalChecksum,
    binarizer,
    minLineCount,
    eanAddOn,
    characterSet,
  );

  /// The fields that differ from the defaults: `ReaderOptions()` for the
  /// defaults, `ReaderOptions(tryInvert: false)` for [ReaderOptions.camera].
  @override
  String toString() {
    const ReaderOptions d = ReaderOptions();
    return 'ReaderOptions(${<String>[if (tryHarder != d.tryHarder) 'tryHarder: $tryHarder', if (tryRotate != d.tryRotate) 'tryRotate: $tryRotate', if (tryInvert != d.tryInvert) 'tryInvert: $tryInvert', if (tryDownscale != d.tryDownscale) 'tryDownscale: $tryDownscale', if (tryDenoise != d.tryDenoise) 'tryDenoise: $tryDenoise', if (isPure != d.isPure) 'isPure: $isPure', if (returnErrors != d.returnErrors) 'returnErrors: $returnErrors', if (validateOptionalChecksum != d.validateOptionalChecksum) 'validateOptionalChecksum: $validateOptionalChecksum', if (binarizer != d.binarizer) 'binarizer: ${binarizer.name}', if (minLineCount != d.minLineCount) 'minLineCount: $minLineCount', if (eanAddOn != d.eanAddOn) 'eanAddOn: ${eanAddOn.name}', if (characterSet case final CharacterSet c) 'characterSet: ${c.name}'].join(', ')})';
  }
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

/// A character set for [ReaderOptions.characterSet].
enum CharacterSet {
  /// US-ASCII.
  ascii(1),

  /// ISO-8859-1 (Latin-1, Western European).
  iso8859_1(2),

  /// ISO-8859-2 (Latin-2, Central European).
  iso8859_2(3),

  /// ISO-8859-3 (Latin-3, South European).
  iso8859_3(4),

  /// ISO-8859-4 (Latin-4, North European).
  iso8859_4(5),

  /// ISO-8859-5 (Cyrillic).
  iso8859_5(6),

  /// ISO-8859-6 (Arabic).
  iso8859_6(7),

  /// ISO-8859-7 (Greek).
  iso8859_7(8),

  /// ISO-8859-8 (Hebrew).
  iso8859_8(9),

  /// ISO-8859-9 (Latin-5, Turkish).
  iso8859_9(10),

  /// ISO-8859-10 (Latin-6, Nordic).
  iso8859_10(11),

  /// ISO-8859-11 (Thai).
  iso8859_11(12),

  /// ISO-8859-13 (Latin-7, Baltic).
  iso8859_13(13),

  /// ISO-8859-14 (Latin-8, Celtic).
  iso8859_14(14),

  /// ISO-8859-15 (Latin-9, Western European with €).
  iso8859_15(15),

  /// ISO-8859-16 (Latin-10, South-Eastern European).
  iso8859_16(16),

  /// Code page 437 (DOS, US).
  cp437(17),

  /// Windows-1250 (Central European).
  cp1250(18),

  /// Windows-1251 (Cyrillic).
  cp1251(19),

  /// Windows-1252 (Western European).
  cp1252(20),

  /// Windows-1256 (Arabic).
  cp1256(21),

  /// Shift_JIS (Japanese).
  shiftJis(22),

  /// Big5 (Traditional Chinese).
  big5(23),

  /// GB2312 (Simplified Chinese).
  gb2312(24),

  /// GB18030 (Chinese).
  gb18030(25),

  /// EUC-JP (Japanese).
  eucJp(26),

  /// EUC-KR (Korean).
  eucKr(27),

  /// UTF-16, big-endian.
  utf16be(28),

  /// UTF-8.
  utf8(29),

  /// UTF-16, little-endian.
  utf16le(30),

  /// UTF-32, big-endian.
  utf32be(31),

  /// UTF-32, little-endian.
  utf32le(32);

  const CharacterSet(this.engineId);

  /// zxing-cpp's `CharacterSet` value.
  @internal
  final int engineId;
}
