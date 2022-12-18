// Format Enumerates barcode formats known to this package.
abstract class Format {
  // Used as a return value if no valid barcode has been detected
  static const int none = 0;

  static const int aztec = 1 << 0; // Aztec (2D)
  static const int codabar = 1 << 1; // Codabar (1D)
  static const int code39 = 1 << 2; // Code39 (1D)
  static const int code93 = 1 << 3; // Code93 (1D)
  static const int code128 = 1 << 4; // Code128 (1D)
  static const int dataBar = 1 << 5; // GS1 DataBar
  static const int dataBarExpanded = 1 << 6; // GS1 DataBar Expanded
  static const int dataMatrix = 1 << 7; // DataMatrix (2D)
  static const int ean8 = 1 << 8; // EAN-8 (1D)
  static const int ean13 = 1 << 9; // EAN-13 (1D)
  static const int itf = 1 << 10; // ITF (Interleaved Two of Five) (1D)
  static const int maxiCode = 1 << 11; // MaxiCode (2D)
  static const int pdf417 = 1 << 12; // PDF417 (1D) or (2D)
  static const int qrCode = 1 << 13; // QR Code (2D)
  static const int upca = 1 << 14; // UPC-A (1D)
  static const int upce = 1 << 15; // UPC-E (1D)

  static const int oneDCodes = codabar |
      code39 |
      code93 |
      code128 |
      ean8 |
      ean13 |
      itf |
      dataBar |
      dataBarExpanded |
      upca |
      upce;
  static const int twoDCodes = aztec | dataMatrix | maxiCode | pdf417 | qrCode;
  static const int any = oneDCodes | twoDCodes;
}

extension CodeFormat on Format {
  String get name => formatNames[this] ?? 'Unknown';

  static final List<int> writerFormats = <int>[
    Format.qrCode,
    Format.dataMatrix,
    Format.aztec,
    Format.pdf417,
    Format.codabar,
    Format.code39,
    Format.code93,
    Format.code128,
    Format.ean8,
    Format.ean13,
    Format.itf,
    Format.upca,
    Format.upce,
    // Format.dataBar,
    // Format.dataBarExpanded,
    // Format.maxiCode,
  ];
}

final Map<int, String> formatNames = <int, String>{
  Format.none: 'None',
  Format.aztec: 'Aztec',
  Format.codabar: 'CodaBar',
  Format.code39: 'Code39',
  Format.code93: 'Code93',
  Format.code128: 'Code128',
  Format.dataBar: 'DataBar',
  Format.dataBarExpanded: 'DataBarExpanded',
  Format.dataMatrix: 'DataMatrix',
  Format.ean8: 'EAN8',
  Format.ean13: 'EAN13',
  Format.itf: 'ITF',
  Format.maxiCode: 'MaxiCode',
  Format.pdf417: 'PDF417',
  Format.qrCode: 'QR Code',
  Format.upca: 'UPCA',
  Format.upce: 'UPCE',
  Format.oneDCodes: 'OneD',
  Format.twoDCodes: 'TwoD',
  Format.any: 'Any',
};
