// Barcode.symbol: the grid of modules the reader sampled. A code created by
// BarcodeWriter and read back gives exactly the modules it was created with.
@Tags(<String>['native'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

void main() {
  setUpAll(warmUpBarcodeEngine);

  Future<(BarcodeSymbol, Barcode?)> roundTrip(
    BarcodeFormat format,
    String text,
  ) async {
    final BarcodeWriter writer = BarcodeWriter(format);
    final BarcodeSymbol written = await writer.encode(text);
    final BarcodeImage image = await writer.toImage(text, moduleSize: 4);
    final Barcode? read = await BarcodeReader(
      formats: <BarcodeFormat>{format},
    ).read(await image.toPng());
    return (written, read);
  }

  for (final (BarcodeFormat format, String text) in <(BarcodeFormat, String)>[
    (BarcodeFormat.qrCode, 'https://pub.dev/packages/flutter_zxing'),
    (BarcodeFormat.dataMatrix, 'flutter_zxing 4.0'),
    (BarcodeFormat.aztec, 'flutter_zxing 4.0'),
  ]) {
    test('${format.displayName}: the modules as written', () async {
      final (BarcodeSymbol written, Barcode? read) = await roundTrip(
        format,
        text,
      );
      final BarcodeSymbol symbol = read!.symbol!;
      expect(symbol.format.symbology, format);
      expect(symbol.width, written.width);
      expect(symbol.height, written.height);
      expect(symbol.modules, written.modules);
    });
  }

  test('PDF417 has no grid: zxing-cpp reads it by its bar widths', () async {
    final (BarcodeSymbol _, Barcode? read) = await roundTrip(
      BarcodeFormat.pdf417,
      'flutter_zxing 4.0 PDF417',
    );
    expect(read!.text, 'flutter_zxing 4.0 PDF417');
    expect(read.symbol, isNull);
  });

  test('linear codes have no grid', () async {
    final (BarcodeSymbol _, Barcode? read) = await roundTrip(
      BarcodeFormat.ean13,
      '5901234123457',
    );
    expect(read!.text, '5901234123457');
    expect(read.symbol, isNull);
  });
}
