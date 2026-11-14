// BarcodeWriter on the real engine: every writable format is created,
// rendered, encoded as PNG and read back.
@Tags(<String>['native'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// Something every writable format can encode.
const Map<BarcodeFormat, String> _samples = <BarcodeFormat, String>{
  BarcodeFormat.codabar: 'A123456B',
  BarcodeFormat.code39: 'CODE39',
  BarcodeFormat.code39Standard: 'STANDARD',
  BarcodeFormat.code93: 'CODE93',
  BarcodeFormat.code128: 'Code 128',
  BarcodeFormat.itf: '12345678',
  BarcodeFormat.ean13: '950110153000',
  BarcodeFormat.ean8: '9638507',
  BarcodeFormat.upcA: '01234567890',
  BarcodeFormat.upcE: '0123456',
  BarcodeFormat.pdf417: 'PDF417',
  BarcodeFormat.aztec: 'Aztec',
  BarcodeFormat.qrCode: 'https://pub.dev',
  BarcodeFormat.qrCodeModel2: 'Model 2',
  BarcodeFormat.dataMatrix: 'Data Matrix',
};

void main() {
  test('the samples cover every writable format', () {
    expect(
      _samples.keys.toSet(),
      BarcodeFormat.values.where((BarcodeFormat f) => f.canWrite).toSet(),
    );
  });

  for (final MapEntry<BarcodeFormat, String> sample in _samples.entries) {
    final BarcodeFormat format = sample.key;
    test('${format.displayName}: created, rendered and read back', () async {
      final BarcodeWriter writer = BarcodeWriter(format, showText: true);
      final BarcodeSymbol symbol = await writer.encode(sample.value);
      expect(symbol.format.symbology, format.symbology);
      expect(symbol.modules, hasLength(symbol.width * symbol.height));
      expect(symbol.text != null, format.isLinear);

      final BarcodeReader reader = BarcodeReader(
        formats: <BarcodeFormat>{format.symbology},
      );
      final BarcodeImage image = await symbol.toImage(moduleSize: 3);
      final Barcode? fromPixels = await reader.readPixels(
        PixelBuffer(image.pixels, width: image.width, height: image.height),
      );
      expect(fromPixels, isNotNull, reason: 'read from pixels');
      // The text a reader reports for what was encoded (with check digits).
      if (symbol.text != null) {
        expect(fromPixels!.text, symbol.text);
      } else {
        expect(fromPixels!.text, sample.value);
      }

      final Barcode? fromPng = await reader.read(await image.toPng());
      expect(fromPng?.text, fromPixels.text, reason: 'read from PNG');
    });
  }

  group('quiet zone', () {
    test('is the largest margin the symbology needs', () async {
      // EAN-13 needs 11 modules on the left, 7 on the right.
      final BarcodeSymbol ean = await const BarcodeWriter(
        BarcodeFormat.ean13,
      ).encode('950110153000');
      expect(ean.quietZone, 11);
      final BarcodeSymbol qr = await const BarcodeWriter(
        BarcodeFormat.qrCode,
      ).encode('x');
      expect(qr.quietZone, 4);
    });

    test('is at least one module for 2D symbols', () async {
      final BarcodeSymbol aztec = await const BarcodeWriter(
        BarcodeFormat.aztec,
      ).encode('x');
      expect(aztec.quietZone, greaterThanOrEqualTo(1));
    });

    test('is 0 when turned off', () async {
      final BarcodeSymbol qr = await const BarcodeWriter(
        BarcodeFormat.qrCode,
        quietZone: false,
      ).encode('x');
      expect(qr.quietZone, 0);
    });
  });

  test('error correction and version shape the symbol', () async {
    final BarcodeSymbol low = await const BarcodeWriter(
      BarcodeFormat.qrCode,
      errorCorrection: ErrorCorrection.low,
    ).encode('error correction');
    final BarcodeSymbol high = await const BarcodeWriter(
      BarcodeFormat.qrCode,
      errorCorrection: ErrorCorrection.high,
    ).encode('error correction');
    expect(high.width, greaterThan(low.width));
    final BarcodeSymbol v10 = await const BarcodeWriter(
      BarcodeFormat.qrCode,
      version: 10,
    ).encode('x');
    expect(v10.width, 57); // 17 + 4 * version
  });

  test('GS1 data is encoded as GS1', () async {
    final BarcodeSymbol symbol = await const BarcodeWriter(
      BarcodeFormat.dataMatrix,
      gs1: true,
    ).encode('(01)09501101530003(17)250101');
    final BarcodeImage image = await symbol.toImage();
    final Barcode? read = await const BarcodeReader().readPixels(
      PixelBuffer(image.pixels, width: image.width, height: image.height),
    );
    expect(read?.contentType, BarcodeContentType.gs1);
    expect(read?.text, '(01)09501101530003(17)250101');
  });

  test('binary data is encoded byte for byte', () async {
    final Uint8List data = Uint8List.fromList(<int>[0, 1, 2, 127, 128, 255]);
    final BarcodeSymbol symbol = await const BarcodeWriter(
      BarcodeFormat.qrCode,
    ).encodeBytes(data);
    final BarcodeImage image = await symbol.toImage();
    final Barcode? read = await const BarcodeReader().readPixels(
      PixelBuffer(image.pixels, width: image.width, height: image.height),
    );
    expect(read?.bytes, data);
  });

  test('the writer shortcuts render text', () async {
    const BarcodeWriter writer = BarcodeWriter(BarcodeFormat.qrCode);
    expect(await writer.toSvg('svg'), startsWith('<svg'));
    final BarcodeImage image = await writer.toImage('image', size: 200);
    expect(image.width, lessThanOrEqualTo(200));
    expect(image.width, greaterThan(150));
  });

  test('data a format cannot hold throws BarcodeWriteException', () async {
    await expectLater(
      const BarcodeWriter(BarcodeFormat.ean13).encode('letters'),
      throwsA(isA<BarcodeWriteException>()),
    );
    await expectLater(
      const BarcodeWriter(BarcodeFormat.qrCode).encode(''),
      throwsA(isA<BarcodeWriteException>()),
    );
  });

  test('a format that cannot be written is an argument error', () async {
    await expectLater(
      const BarcodeWriter(BarcodeFormat.maxiCode).encode('x'),
      throwsArgumentError,
    );
  });
}
