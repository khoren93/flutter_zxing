/// A barcode symbology, or a specific variant of one.
///
/// **Filtering by format.** A base symbology also matches all of its variants:
/// `{BarcodeFormat.qrCode}` finds QR codes, Micro QR and rMQR codes, and
/// `{BarcodeFormat.eanUpc}` finds EAN-13, EAN-8, UPC-A and UPC-E. A variant
/// matches only itself: `{BarcodeFormat.ean13}` finds EAN-13 only.
///
/// **Reported format.** A found barcode reports its most specific known
/// format, e.g. [ean13] rather than [eanUpc]. Use [symbology] to group results.
///
/// Every value carries the zxing-cpp format id, which is derived from the
/// ISO/IEC 15424 symbology identifier, so it is stable across versions.
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
  code39Extended('Code39Ext', 'Code 39 Extended', 'A', 'e', _linear | _read),

  /// Code 32 (Italian pharmacode).
  code32('Code32', 'Code 32', 'A', '2', _linear | _read),

  /// Pharmazentralnummer (German pharmacode).
  pzn('PZN', 'Pharmazentralnummer', 'A', 'p', _linear | _read),

  /// Code 93.
  code93('Code93', 'Code 93', 'G', ' ', _linear | _read | _write),

  /// Code 128.
  code128('Code128', 'Code 128', 'C', ' ', _linear | _read | _write),

  /// Interleaved 2 of 5, all variants.
  itf('ITF', 'ITF', 'I', ' ', _linear | _read | _write),

  /// ITF-14.
  itf14('ITF14', 'ITF-14', 'I', '4', _linear | _read),

  /// GS1 DataBar, all variants.
  dataBar('DataBar', 'DataBar', 'e', ' ', _linear | _read),

  /// GS1 DataBar Omnidirectional.
  dataBarOmni('DataBarOmni', 'DataBar Omni', 'e', 'o', _linear | _read),

  /// GS1 DataBar Stacked.
  dataBarStacked('DataBarStk', 'DataBar Stacked', 'e', 's', _linear | _read),

  /// GS1 DataBar Stacked Omnidirectional.
  dataBarStackedOmni(
    'DataBarStkOmni',
    'DataBar Stacked Omni',
    'e',
    'O',
    _linear | _read,
  ),

  /// GS1 DataBar Limited.
  dataBarLimited('DataBarLtd', 'DataBar Limited', 'e', 'l', _linear | _read),

  /// GS1 DataBar Expanded.
  dataBarExpanded('DataBarExp', 'DataBar Expanded', 'e', 'e', _linear | _read),

  /// GS1 DataBar Expanded Stacked.
  dataBarExpandedStacked(
    'DataBarExpStk',
    'DataBar Expanded Stacked',
    'e',
    'E',
    _linear | _read,
  ),

  /// EAN and UPC, all variants.
  eanUpc('EANUPC', 'EAN/UPC', 'E', ' ', _linear | _read),

  /// EAN-13.
  ean13('EAN13', 'EAN-13', 'E', '1', _linear | _read | _write),

  /// EAN-8.
  ean8('EAN8', 'EAN-8', 'E', '8', _linear | _read | _write),

  /// EAN-5 add-on.
  ean5('EAN5', 'EAN-5', 'E', '5', _linear | _read),

  /// EAN-2 add-on.
  ean2('EAN2', 'EAN-2', 'E', '2', _linear | _read),

  /// ISBN (an EAN-13 starting with 978/979).
  isbn('ISBN', 'ISBN', 'E', 'i', _linear | _read),

  /// UPC-A.
  upcA('UPCA', 'UPC-A', 'E', 'a', _linear | _read | _write),

  /// UPC-E.
  upcE('UPCE', 'UPC-E', 'E', 'e', _linear | _read | _write),

  /// Telepen, all variants.
  telepen('Telepen', 'Telepen', 'B', ' ', _linear | _read),

  /// DX film edge code.
  dxFilmEdge('DXFilmEdge', 'DX Film Edge', 'X', 'x', _linear | _read),

  // --- 2D (matrix and stacked) -----------------------------------------------

  /// PDF417, all variants.
  pdf417('PDF417', 'PDF417', 'L', ' ', _matrix | _read | _write),

  /// Compact (truncated) PDF417.
  compactPdf417('CompactPDF417', 'Compact PDF417', 'L', 'c', _matrix | _read),

  /// MicroPDF417.
  microPdf417('MicroPDF417', 'MicroPDF417', 'L', 'm', _matrix | _read),

  /// Aztec, all variants.
  aztec('Aztec', 'Aztec', 'z', ' ', _matrix | _read | _write),

  /// Aztec Code.
  aztecCode('AztecCode', 'Aztec Code', 'z', 'c', _matrix | _read),

  /// Aztec Rune.
  aztecRune('AztecRune', 'Aztec Rune', 'z', 'r', _matrix | _read),

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
  microQrCode('MicroQRCode', 'Micro QR Code', 'Q', 'm', _matrix | _read),

  /// Rectangular Micro QR Code (rMQR).
  rmqrCode('RMQRCode', 'rMQR Code', 'Q', 'r', _matrix | _read),

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

  /// Whether this format can be read.
  bool get canRead => _flags & _read != 0;

  /// Whether this format can be created with `BarcodeWriter`.
  bool get canWrite => _flags & _write != 0;

  /// Whether this is a one-dimensional (linear) symbology.
  bool get isLinear => _flags & _linear != 0;

  /// Whether this is a two-dimensional (matrix or stacked) symbology.
  bool get isMatrix => _flags & _matrix != 0;

  /// The base symbology: [qrCodeModel2] → [qrCode], [ean13] → [eanUpc].
  BarcodeFormat get symbology =>
      BarcodeFormatInternal.fromId(_symbol.codeUnitAt(0) | (0x20 << 8));

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
