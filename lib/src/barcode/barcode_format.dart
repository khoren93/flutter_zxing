import 'barcode_input.dart';

/// A barcode symbology, or a specific variant of one.
///
/// **Filtering by format.** A base symbology also matches all of its variants:
/// `{BarcodeFormat.qrCode}` finds QR codes, Micro QR and rMQR codes, and
/// `{BarcodeFormat.eanUpc}` finds EAN-13, EAN-8, UPC-A and UPC-E. A variant
/// matches only itself: `{BarcodeFormat.ean13}` finds EAN-13 only.
///
/// **Reported format.** A found barcode reports the format its reader
/// knows: [ean13] rather than [eanUpc], [code39Extended] rather than
/// [code39]. Some variants are found by their filter but reported as their
/// base format: [itf14] as [itf], [compactPdf417] as [pdf417],
/// [dataBarStackedOmni] as [dataBarStacked], [aztecCode] and [aztecRune] as
/// [aztec], [qrCodeModel2] as [qrCode], [code39Standard] as [code39],
/// [telepenNumeric] as [telepenAlpha]. Use [symbology] to group results.
///
/// Every value carries the zxing-cpp format id, which is derived from the
/// ISO/IEC 15424 symbology identifier, so it is stable across versions.
///
/// Errors name a format as it is written in code, `BarcodeFormat.isbn`
/// ([name]), not by its [displayName]: a format that cannot be read or
/// written throws an `ArgumentError` saying `BarcodeFormat.isbn cannot be
/// read`.
enum BarcodeFormat {
  // --- 1D (linear) -----------------------------------------------------------

  /// Codabar.
  codabar('Codabar', 'Codabar', 'F', ' ', _linear | _read | _write),

  /// Code 39, all variants.
  code39('Code39', 'Code 39', 'A', ' ', _linear | _read | _write),

  /// Code 39 Standard.
  code39Standard(
    'Code39Std',
    'Code 39 Standard',
    'A',
    's',
    _linear | _read | _write,
  ),

  /// Code 39 Extended (full ASCII).
  code39Extended(
    'Code39Ext',
    'Code 39 Extended',
    'A',
    'e',
    _linear | _read | _write,
  ),

  /// Code 32 (Italian pharmacode).
  code32('Code32', 'Code 32', 'A', '2', _linear | _read | _write),

  /// Pharmazentralnummer (German pharmacode).
  pzn('PZN', 'Pharmazentralnummer', 'A', 'p', _linear | _read | _write),

  /// Code 93.
  code93('Code93', 'Code 93', 'G', ' ', _linear | _read | _write),

  /// Code 128.
  code128('Code128', 'Code 128', 'C', ' ', _linear | _read | _write),

  /// Interleaved 2 of 5, all variants.
  itf('ITF', 'ITF', 'I', ' ', _linear | _read | _write),

  /// ITF-14.
  itf14('ITF14', 'ITF-14', 'I', '4', _linear | _read),

  /// GS1 DataBar, all variants.
  dataBar('DataBar', 'DataBar', 'e', ' ', _linear | _read | _write),

  /// GS1 DataBar Omnidirectional.
  dataBarOmni(
    'DataBarOmni',
    'DataBar Omni',
    'e',
    'o',
    _linear | _read | _write,
  ),

  /// GS1 DataBar Stacked.
  dataBarStacked(
    'DataBarStk',
    'DataBar Stacked',
    'e',
    's',
    _linear | _read | _write,
  ),

  /// GS1 DataBar Stacked Omnidirectional.
  dataBarStackedOmni(
    'DataBarStkOmni',
    'DataBar Stacked Omni',
    'e',
    'O',
    _linear | _read | _write,
  ),

  /// GS1 DataBar Limited.
  dataBarLimited(
    'DataBarLtd',
    'DataBar Limited',
    'e',
    'l',
    _linear | _read | _write,
  ),

  /// GS1 DataBar Expanded.
  dataBarExpanded(
    'DataBarExp',
    'DataBar Expanded',
    'e',
    'e',
    _linear | _read | _write,
  ),

  /// GS1 DataBar Expanded Stacked.
  dataBarExpandedStacked(
    'DataBarExpStk',
    'DataBar Expanded Stacked',
    'e',
    'E',
    _linear | _read | _write,
  ),

  /// EAN and UPC, all variants.
  eanUpc('EANUPC', 'EAN/UPC', 'E', ' ', _linear | _read | _write),

  /// EAN-13.
  ean13('EAN13', 'EAN-13', 'E', '1', _linear | _read | _write),

  /// EAN-8.
  ean8('EAN8', 'EAN-8', 'E', '8', _linear | _read | _write),

  /// EAN-5 add-on. Not read on its own: it comes as part of the EAN-13 or
  /// UPC-A text when `ReaderOptions.eanAddOn` reads add-ons.
  ean5('EAN5', 'EAN-5', 'E', '5', _linear),

  /// EAN-2 add-on. Not read on its own, like [ean5].
  ean2('EAN2', 'EAN-2', 'E', '2', _linear),

  /// ISBN (an EAN-13 starting with 978/979). Written as such, read as
  /// [ean13]: filter by [ean13] and check that the text starts with 978 or
  /// 979.
  isbn('ISBN', 'ISBN', 'E', 'i', _linear | _write),

  /// UPC-A.
  upcA('UPCA', 'UPC-A', 'E', 'a', _linear | _read | _write),

  /// UPC-E.
  upcE('UPCE', 'UPC-E', 'E', 'e', _linear | _read | _write),

  /// Telepen, all variants.
  telepen('Telepen', 'Telepen', 'B', ' ', _linear | _read | _write),

  /// Telepen in its full ASCII mode.
  telepenAlpha(
    'TelepenAlpha',
    'Telepen Alpha',
    'B',
    '0',
    _linear | _read | _write,
  ),

  /// Telepen in its numeric mode.
  telepenNumeric(
    'TelepenNumeric',
    'Telepen Numeric',
    'B',
    '1',
    _linear | _read | _write,
  ),

  /// DX film edge code.
  dxFilmEdge('DXFilmEdge', 'DX Film Edge', 'X', 'x', _linear | _read | _write),

  // --- 2D (matrix and stacked) -----------------------------------------------

  /// PDF417, all variants.
  pdf417('PDF417', 'PDF417', 'L', ' ', _matrix | _read | _write),

  /// Compact (truncated) PDF417.
  compactPdf417(
    'CompactPDF417',
    'Compact PDF417',
    'L',
    'c',
    _matrix | _read | _write,
  ),

  /// MicroPDF417.
  microPdf417('MicroPDF417', 'MicroPDF417', 'L', 'm', _matrix | _read | _write),

  /// Aztec, all variants.
  aztec('Aztec', 'Aztec', 'z', ' ', _matrix | _read | _write),

  /// Aztec Code.
  aztecCode('AztecCode', 'Aztec Code', 'z', 'c', _matrix | _read | _write),

  /// Aztec Rune.
  aztecRune('AztecRune', 'Aztec Rune', 'z', 'r', _matrix | _read | _write),

  /// QR Code, all variants (including Micro QR and rMQR when filtering).
  qrCode('QRCode', 'QR Code', 'Q', ' ', _matrix | _read | _write),

  /// QR Code Model 1.
  qrCodeModel1('QRCodeModel1', 'QR Code Model 1', 'Q', '1', _matrix | _read),

  /// QR Code Model 2.
  qrCodeModel2(
    'QRCodeModel2',
    'QR Code Model 2',
    'Q',
    '2',
    _matrix | _read | _write,
  ),

  /// Micro QR Code.
  microQrCode(
    'MicroQRCode',
    'Micro QR Code',
    'Q',
    'm',
    _matrix | _read | _write,
  ),

  /// Rectangular Micro QR Code (rMQR).
  rmqrCode('RMQRCode', 'rMQR Code', 'Q', 'r', _matrix | _read | _write),

  /// Data Matrix.
  dataMatrix('DataMatrix', 'Data Matrix', 'd', ' ', _matrix | _read | _write),

  /// MaxiCode.
  maxiCode('MaxiCode', 'MaxiCode', 'U', ' ', _matrix | _read),

  /// A format this version of the package does not know yet. Only ever
  /// reported for results, never valid as a filter or for writing.
  unknown('', 'Unknown', '\u0000', '\u0000', 0);

  const BarcodeFormat(
    this._zxName,
    this.displayName,
    this._symbol,
    this._variant,
    this._flags,
  );

  final String _zxName;
  final String _symbol;
  final String _variant;
  final int _flags;

  /// Human readable name, e.g. `QR Code` or `EAN-13`.
  final String displayName;

  /// Whether this format can be read: used as a filter, it finds barcodes.
  /// False for the EAN-2/EAN-5 add-ons (read with their EAN-13 or UPC-A),
  /// [isbn] (read as [ean13]) and [unknown].
  bool get canRead => _flags & _read != 0;

  /// Whether this format can be created with `BarcodeWriter`.
  ///
  /// Every format zxing-cpp creates (through zint) and reads back, except
  /// the EAN-2/EAN-5 add-ons (not symbols on their own), ITF-14 (zint draws
  /// its bearer bars against the bars) and MaxiCode (hexagonal modules).
  /// For a format picker use [writable], which lists each kind of symbol
  /// once.
  bool get canWrite => _flags & _write != 0;

  /// Whether `BarcodeWriter.errorCorrection` applies: QR (with Micro QR and
  /// rMQR), Aztec and PDF417. The other formats have fixed error correction
  /// or none, and ignore it.
  bool get hasErrorCorrection => switch (this) {
    qrCode ||
    qrCodeModel2 ||
    microQrCode ||
    rmqrCode ||
    aztec ||
    aztecCode ||
    pdf417 ||
    compactPdf417 => true,
    _ => false,
  };

  /// What `BarcodeWriter` accepts for this format: a description for a
  /// form field, an example and the kind of keyboard. `null` if it cannot
  /// be written.
  ///
  /// It guides the input; the writer checks it. An invalid input throws a
  /// `BarcodeWriteException` that says what is wrong, e.g. `Invalid check
  /// digit '4', expecting '3'`.
  ///
  /// ```dart
  /// final BarcodeInput input = BarcodeFormat.ean13.input!;
  /// TextField(
  ///   decoration: InputDecoration(helperText: input.description, hintText: input.example),
  ///   keyboardType: input.digitsOnly ? TextInputType.number : TextInputType.text,
  /// );
  /// ```
  BarcodeInput? get input => switch (this) {
    qrCode || qrCodeModel2 => _qrCode,
    microQrCode => _microQrCode,
    rmqrCode => _rmqrCode,
    dataMatrix => _dataMatrix,
    aztec || aztecCode => _aztec,
    aztecRune => _aztecRune,
    pdf417 || compactPdf417 => _pdf417,
    microPdf417 => _microPdf417,
    code128 => _code128,
    code39 || code39Standard => _code39,
    code39Extended || code93 || telepenAlpha => _ascii,
    codabar => _codabar,
    itf || telepenNumeric => _evenDigits,
    eanUpc || ean13 => _ean13,
    ean8 => _ean8,
    upcA => _upcA,
    upcE => _upcE,
    isbn => _isbn,
    dataBar || dataBarOmni || dataBarStacked || dataBarStackedOmni => _gtin,
    dataBarLimited => _gtinLimited,
    dataBarExpanded || dataBarExpandedStacked => _gs1,
    code32 => _code32,
    pzn => _pzn,
    telepen => _telepen,
    dxFilmEdge => _dxFilmEdge,
    _ => null,
  };

  /// Whether this is a one-dimensional (linear) symbology.
  bool get isLinear => _flags & _linear != 0;

  /// Whether this is a two-dimensional (matrix or stacked) symbology.
  bool get isMatrix => _flags & _matrix != 0;

  /// The base symbology: [qrCodeModel2] → [qrCode], [ean13] → [eanUpc].
  /// A format without a base of its own ([dxFilmEdge]) is its own symbology.
  BarcodeFormat get symbology {
    final BarcodeFormat base = BarcodeFormatInternal.fromId(
      _symbol.codeUnitAt(0) | (0x20 << 8),
    );
    return base == unknown ? this : base;
  }

  /// All linear (1D) symbologies.
  static const Set<BarcodeFormat> linear = <BarcodeFormat>{
    codabar,
    code39,
    code93,
    code128,
    itf,
    dataBar,
    eanUpc,
    telepen,
    dxFilmEdge,
  };

  /// All two-dimensional symbologies.
  static const Set<BarcodeFormat> matrix = <BarcodeFormat>{
    pdf417,
    aztec,
    qrCode,
    dataMatrix,
    maxiCode,
  };

  /// The formats `BarcodeWriter` creates, each kind of symbol once, 2D
  /// first: the list for a format picker. Left out are the variants a
  /// listed format already creates ([qrCodeModel2] is [qrCode],
  /// [code39Standard] is [code39], [aztecCode] is [aztec], [eanUpc] is
  /// [ean13], [dataBarOmni] is [dataBar], [telepenAlpha] and
  /// [telepenNumeric] are [telepen], which picks the mode from the data).
  static const Set<BarcodeFormat> writable = <BarcodeFormat>{
    qrCode,
    microQrCode,
    rmqrCode,
    dataMatrix,
    aztec,
    aztecRune,
    pdf417,
    compactPdf417,
    microPdf417,
    code128,
    code39,
    code39Extended,
    code93,
    codabar,
    itf,
    ean13,
    ean8,
    upcA,
    upcE,
    isbn,
    dataBar,
    dataBarStacked,
    dataBarStackedOmni,
    dataBarLimited,
    dataBarExpanded,
    dataBarExpandedStacked,
    code32,
    pzn,
    telepen,
    dxFilmEdge,
  };

  /// Retail products: EAN/UPC and GS1 DataBar.
  static const Set<BarcodeFormat> retail = <BarcodeFormat>{eanUpc, dataBar};

  /// Logistics and industry: Code 128, Code 39, ITF, Data Matrix, PDF417.
  static const Set<BarcodeFormat> industrial = <BarcodeFormat>{
    code128,
    code39,
    itf,
    dataMatrix,
    pdf417,
  };
}

/// Engine protocol details. Not exported from the package.
extension BarcodeFormatInternal on BarcodeFormat {
  /// The zxing-cpp format id (ISO/IEC 15424 symbology + variant key).
  int get id => _symbol.codeUnitAt(0) | (_variant.codeUnitAt(0) << 8);

  /// The name zxing-cpp uses for this format in option strings.
  String get zxingName => _zxName;

  /// Looks a format up by its zxing-cpp [id]; [BarcodeFormat.unknown] if there is none.
  static BarcodeFormat fromId(int id) => _byId[id] ?? BarcodeFormat.unknown;

  static final Map<int, BarcodeFormat> _byId = <int, BarcodeFormat>{
    for (final BarcodeFormat f in BarcodeFormat.values)
      if (f != BarcodeFormat.unknown) f.id: f,
  };
}

const int _linear = 1;
const int _matrix = 2;
const int _read = 4;
const int _write = 8;

// What each writable format accepts (BarcodeFormat.input). The limits are
// zint's; tests encode every example.
const BarcodeInput _qrCode = BarcodeInput(
  'Any text or binary data, up to 2953 bytes',
  'https://pub.dev/packages/flutter_zxing',
  anyText: true,
);
const BarcodeInput _microQrCode = BarcodeInput(
  'Short text: up to 35 digits, 21 capital letters or 15 bytes',
  'HELLO 42',
);
const BarcodeInput _rmqrCode = BarcodeInput(
  'Text: up to 361 digits, 219 capital letters or 150 bytes',
  'rMQR Code',
);
const BarcodeInput _dataMatrix = BarcodeInput(
  'Any text or binary data, up to 1556 bytes',
  'https://pub.dev/packages/flutter_zxing',
  anyText: true,
);
const BarcodeInput _aztec = BarcodeInput(
  'Any text or binary data, up to 1914 bytes',
  'https://pub.dev/packages/flutter_zxing',
  anyText: true,
);
const BarcodeInput _aztecRune = BarcodeInput(
  'A number from 0 to 255',
  '25',
  digitsOnly: true,
);
const BarcodeInput _pdf417 = BarcodeInput(
  'Any text or binary data, up to 1108 bytes',
  'https://pub.dev/packages/flutter_zxing',
  anyText: true,
);
const BarcodeInput _microPdf417 = BarcodeInput(
  'Text: up to 366 digits, 250 letters or 150 bytes',
  'MicroPDF417',
);
const BarcodeInput _code128 = BarcodeInput(
  'Text: ASCII and Latin-1 characters',
  'Code 128',
);
const BarcodeInput _code39 = BarcodeInput(
  r'Capital letters, digits, space and - . $ / + %',
  'CODE 39',
);
const BarcodeInput _ascii = BarcodeInput('ASCII text', 'Hello, world!');
const BarcodeInput _codabar = BarcodeInput(
  r'Digits and - $ : / . + between start and stop letters A-D',
  'A40156B',
);
const BarcodeInput _evenDigits = BarcodeInput(
  'Digits; an odd count gets a leading zero',
  '12345678',
  digitsOnly: true,
);
const BarcodeInput _ean13 = BarcodeInput(
  '12 digits, or 13 with the check digit',
  '9501101530003',
  digitsOnly: true,
);
const BarcodeInput _ean8 = BarcodeInput(
  '7 digits, or 8 with the check digit',
  '96385074',
  digitsOnly: true,
);
const BarcodeInput _upcA = BarcodeInput(
  '11 digits, or 12 with the check digit',
  '012345678905',
  digitsOnly: true,
);
const BarcodeInput _upcE = BarcodeInput(
  '6 or 7 digits, or 8 with the check digit',
  '01234565',
  digitsOnly: true,
);
const BarcodeInput _isbn = BarcodeInput(
  'ISBN-13, or ISBN-10, with its check digit',
  '9781234567897',
);
const BarcodeInput _gtin = BarcodeInput(
  'GTIN: up to 13 digits; the check digit is added',
  '0950110153000',
  digitsOnly: true,
);
const BarcodeInput _gtinLimited = BarcodeInput(
  'GTIN starting with 0 or 1: up to 13 digits; the check digit is added',
  '0950110153000',
  digitsOnly: true,
);
const BarcodeInput _gs1 = BarcodeInput(
  'GS1 data: Application Identifiers in parentheses',
  '(01)09501101530003(17)250101',
);
const BarcodeInput _code32 = BarcodeInput(
  'Up to 8 digits; the check digit is added',
  '12345678',
  digitsOnly: true,
);
const BarcodeInput _pzn = BarcodeInput(
  'Up to 7 digits; the check digit is added',
  '1234567',
  digitsOnly: true,
);
const BarcodeInput _telepen = BarcodeInput(
  'ASCII text; digits only are encoded as Telepen Numeric',
  'Telepen',
);
const BarcodeInput _dxFilmEdge = BarcodeInput(
  'DX number, 16-2047 or 1-127 and 0-15, with an optional frame: /11A',
  '115-10/11A',
);
