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
  static const int microQRCode = 1 << 16; // Micro QR Code

  static const int linearCodes = codabar |
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
  static const int matrixCodes =
      aztec | dataMatrix | maxiCode | pdf417 | qrCode | microQRCode;
  static const int any = linearCodes | matrixCodes;
}

extension CodeFormat on int {
  String get name => barcodeNames[this] ?? 'Unknown';

  // The width divided by the height of the barcode
  double get ratio => barcodeRatios[this] ?? 1.0;
  String get demoText => barcodeDemoText[this] ?? '';
  int get maxTextLength => barcodeMaxTextLengths[this] ?? 0;
  bool get isSupportedEccLevel => eccSupported.contains(this);

  static final List<int> eccSupported = <int>[
    Format.qrCode,
  ];

  static final List<int> supportedEncodeFormats = <int>[
    Format.qrCode,
    // Format.microQRCode,
    Format.dataMatrix,
    Format.aztec,
    // Format.pdf417,
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

final Map<int, String> barcodeNames = <int, String>{
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
  Format.microQRCode: 'Micro QR Code',
  Format.linearCodes: 'OneD',
  Format.matrixCodes: 'TwoD',
  Format.any: 'Any',
};

final Map<int, double> barcodeRatios = <int, double>{
  Format.aztec: 3.0 / 3.0, // recommended ratio: 3:3 (square)
  Format.codabar: 3.0 / 1.0, // recommended ratio: 3:1
  Format.code39: 3.0 / 1.0, // recommended ratio: 3:1
  Format.code93: 3.0 / 1.0, // recommended ratio: 3:1
  Format.code128: 2.0 / 1.0, // recommended ratio: 2:1
  Format.dataBar: 3.0 / 1.0, // recommended ratio: 3:1
  Format.dataBarExpanded: 1.0 / 1.0, // recommended ratio: 1:1 (square)
  Format.dataMatrix: 3.0 / 3.0, // recommended ratio: 3:3 (square)
  Format.ean8: 3.0 / 1.0, // recommended ratio: 3:1
  Format.ean13: 3.0 / 1.0, // recommended ratio: 3:1
  Format.itf: 3.0 / 1.0, // recommended ratio: 3:1
  Format.maxiCode: 3.0 / 3.0, // recommended ratio: 3:3 (square)
  Format.pdf417: 3.0 / 1.0, // recommended ratio: 3:1
  Format.qrCode: 3.0 / 3.0, // recommended ratio: 3:3 (square)
  Format.upca: 3.0 / 1.0, // recommended ratio: 3:1
  Format.upce: 1.0 / 1.0, // recommended ratio: 1:1 (square)
  Format.microQRCode: 3.0 / 3.0, // recommended ratio: 3:3 (square)
};

final Map<int, String> barcodeDemoText = <int, String>{
  Format.aztec: 'This is an Aztec Code',
  Format.codabar: 'A123456789B',
  Format.code39: 'ABC-1234',
  Format.code93: 'ABC-1234-/+',
  Format.code128: 'ABC-abc-1234',
  Format.dataBar: '0123456789012',
  Format.dataBarExpanded: '011234567890123-ABCabc',
  Format.dataMatrix: 'This is a Data Matrix',
  Format.ean8: '9031101',
  Format.ean13: '978020137962',
  Format.itf: '00012345600012',
  Format.maxiCode: 'This is a MaxiCode',
  Format.pdf417: 'This is a PDF417',
  Format.qrCode: 'This is a QR Code',
  Format.upca: '72527273070',
  Format.upce: '0123456',
  Format.microQRCode: 'This is a Micro QR Code',
};

final Map<int, int> barcodeMaxTextLengths = <int, int>{
  Format.aztec: 3832,
  Format.codabar: 20,
  Format.code39: 43,
  Format.code93: 47,
  Format.code128: 2046,
  Format.dataBar: 74,
  Format.dataBarExpanded: 4107,
  Format.dataMatrix: 2335,
  Format.ean8: 8,
  Format.ean13: 13,
  Format.itf: 20,
  Format.maxiCode: 30,
  Format.pdf417: 2953,
  Format.qrCode: 4296,
  Format.upca: 12,
  Format.upce: 8,
  Format.microQRCode: 4296,
};
