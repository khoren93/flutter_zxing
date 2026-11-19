// The codes of the sheet 1-formats/all-grid (`make sheets`), as the scanner
// reports them: the field test of the diagnostics page knows a code by these.
// The sheets test fails when this list and the sheet differ.

/// One code of the sheet.
final class FieldCode {
  /// Creates the entry.
  const FieldCode(this.id, this.title, this.format, this.text, {this.addOn});

  /// The id printed on the sheet.
  final String id;

  /// The name printed on the sheet.
  final String title;

  /// The name of the `BarcodeFormat` it reads as.
  final String format;

  /// The text it reads as.
  final String text;

  /// The text with its EAN add-on, read only when the add-on is asked for.
  final String? addOn;

  /// Whether a read of [readFormat] and [readText] is this code.
  bool matches(String readFormat, String readText) {
    final String read = readText.trim();
    return readFormat == format &&
        (read == text.trim() || read == addOn?.trim());
  }
}

/// The sheet, in its order.
const List<FieldCode> fieldCodes = <FieldCode>[
  FieldCode(
    'W1',
    'QR Code',
    'qrCode',
    'https://pub.dev/packages/flutter_zxing',
  ),
  FieldCode('W2', 'Micro QR Code', 'microQrCode', 'HELLO 42'),
  FieldCode('W3', 'rMQR Code', 'rmqrCode', 'rMQR Code'),
  FieldCode(
    'W4',
    'Data Matrix',
    'dataMatrix',
    'https://pub.dev/packages/flutter_zxing',
  ),
  FieldCode('W5', 'Aztec', 'aztec', 'https://pub.dev/packages/flutter_zxing'),
  FieldCode('W6', 'Aztec Rune', 'aztec', '025'),
  FieldCode('W7', 'PDF417', 'pdf417', 'https://pub.dev/packages/flutter_zxing'),
  FieldCode('W8', 'Compact PDF417', 'pdf417', 'Compact PDF417'),
  FieldCode('W9', 'MicroPDF417', 'microPdf417', 'MicroPDF417'),
  FieldCode('W10', 'Code 128', 'code128', 'Code 128'),
  FieldCode('W11', 'Code 39', 'code39', 'CODE 39'),
  FieldCode('W12', 'Code 39 Extended', 'code39Extended', 'Hello, world!'),
  FieldCode('W13', 'Code 93', 'code93', 'Hello, world!'),
  FieldCode('W14', 'Codabar', 'codabar', 'A40156B'),
  FieldCode('W15', 'ITF', 'itf', '12345678'),
  FieldCode('W16', 'EAN-13', 'ean13', '9501101530003'),
  FieldCode('W17', 'EAN-8', 'ean8', '96385074'),
  FieldCode('W18', 'UPC-A', 'upcA', '012345678905'),
  FieldCode('W19', 'UPC-E', 'upcE', '01234565'),
  FieldCode('W20', 'ISBN', 'ean13', '9781234567897'),
  FieldCode('W21', 'DataBar', 'dataBarOmni', '(01)09501101530003'),
  FieldCode('W22', 'DataBar Stacked', 'dataBarStacked', '(01)09501101530010'),
  FieldCode(
    'W23',
    'DataBar Stacked Omni',
    'dataBarStacked',
    '(01)09501101530027',
  ),
  FieldCode('W24', 'DataBar Limited', 'dataBarLimited', '(01)09501101530003'),
  FieldCode(
    'W25',
    'DataBar Expanded',
    'dataBarExpanded',
    '(01)09501101530003(17)250101',
  ),
  FieldCode(
    'W26',
    'DataBar Expanded Stacked',
    'dataBarExpandedStacked',
    '(01)09501101530003(17)250101',
  ),
  FieldCode('W27', 'Code 32', 'code32', 'A123456788'),
  FieldCode('W28', 'Pharmazentralnummer', 'pzn', '-12345678'),
  FieldCode('W29', 'Telepen', 'telepenAlpha', 'Telepen'),
  FieldCode('W30', 'DX Film Edge', 'dxFilmEdge', '115-10/11A'),
  FieldCode('R1', 'MaxiCode', 'maxiCode', '[)>␞01␝96123450000␝222␝111␝MODE2'),
  FieldCode('R2', 'QR Code Model 1', 'qrCode', 'QR Code Model 1 '),
  FieldCode(
    'R3',
    'EAN-5 add-on',
    'ean13',
    '9780735200449',
    addOn: '978073520044951299',
  ),
  FieldCode(
    'R4',
    'EAN-2 add-on',
    'ean13',
    '4006381333931',
    addOn: '400638133393112',
  ),
  FieldCode('R5', 'ITF-14', 'itf', '00012345600012'),
];
