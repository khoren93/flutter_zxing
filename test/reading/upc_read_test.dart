// UPC-A and UPC-E read and written as printed, on the real engine.
@Tags(<String>['native'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/writing/symbol_layout.dart';

Future<Uint8List> _png(BarcodeFormat format, String data) async =>
    (await BarcodeWriter(format).encode(data)).toPng(moduleSize: 3);

void main() {
  test('the writer prints a UPC-A with 12 digits, a UPC-E with 8', () async {
    expect(
      (await const BarcodeWriter(
        BarcodeFormat.upcA,
        showText: true,
      ).encode('69792911003')).text,
      '697929110035',
    );
    expect(
      (await const BarcodeWriter(
        BarcodeFormat.upcE,
        showText: true,
      ).encode('01234565')).text,
      '01234565',
    );
  });

  test('a UPC-A reads as UPC-A with its 12 digits', () async {
    final Uint8List png = await _png(BarcodeFormat.upcA, '697929110035');
    for (final BarcodeReader reader in <BarcodeReader>[
      const BarcodeReader(),
      const BarcodeReader(options: ReaderOptions.camera()),
      const BarcodeReader(formats: <BarcodeFormat>{BarcodeFormat.eanUpc}),
      const BarcodeReader(formats: <BarcodeFormat>{BarcodeFormat.upcA}),
    ]) {
      final Barcode? b = await reader.read(png);
      expect(b?.format, BarcodeFormat.upcA);
      expect(b?.text, '697929110035');
    }
  });

  test('asked for EAN-13 alone, it stays an EAN-13 of 13 digits', () async {
    final Barcode? b = await const BarcodeReader(
      formats: <BarcodeFormat>{BarcodeFormat.ean13},
    ).read(await _png(BarcodeFormat.upcA, '697929110035'));
    expect(b?.format, BarcodeFormat.ean13);
    expect(b?.text, '0697929110035');
  });

  test(
    'a UPC-E reads with its 8 digits, a product without an add-on',
    () async {
      final Barcode? b = await const BarcodeReader().read(
        await _png(BarcodeFormat.upcE, '01234565'),
      );
      expect(b?.format, BarcodeFormat.upcE);
      expect(b?.text, '01234565');
      final ProductContent product = b!.content as ProductContent;
      expect(product.gtin, '01234565');
      expect(product.addOn, isNull);
    },
  );

  test('a UPC-A with the digits under it still reads', () async {
    final Uint8List png = await (await const BarcodeWriter(
      BarcodeFormat.upcA,
      showText: true,
    ).encode('697929110035')).toPng(moduleSize: 3);
    expect((await const BarcodeReader().read(png))?.text, '697929110035');
  });

  test('the digits start under the short bars, beside the long ones', () async {
    for (final (BarcodeFormat format, String data) in <(BarcodeFormat, String)>[
      (BarcodeFormat.upcA, '697929110035'),
      (BarcodeFormat.ean13, '4006381333931'),
      (BarcodeFormat.ean8, '96385074'),
      (BarcodeFormat.upcE, '01234565'),
    ]) {
      final BarcodeSymbol s = await BarcodeWriter(
        format,
        showText: true,
      ).encode(data);
      // The guards (and a UPC-A's first and last characters) reach lower
      // than the data bars.
      int shortest = s.height;
      for (int x = 0; x < s.width; x++) {
        int h = 0;
        for (int y = 0; y < s.height; y++) {
          if (s.isDark(x, y)) {
            h = y + 1;
          }
        }
        if (h > 0 && h < shortest) {
          shortest = h;
        }
      }
      expect(shortest, lessThan(s.height), reason: '$format has long bars');
      final SymbolLayout layout = SymbolLayout(s);
      expect(
        layout.textRuns[1].top,
        s.quietZone + shortest + SymbolLayout.textGap,
        reason: format.displayName,
      );
    }
  });
}
