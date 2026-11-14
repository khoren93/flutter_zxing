// BarcodeReader on the real engine (built for the host by the build hook).
@Tags(<String>['native'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// zxing-cpp's samples, from the submodule the engine is built from.
Uint8List _sample(String name) => Uint8List.fromList(
  File('third_party/zxing-cpp/test/samples/$name').readAsBytesSync(),
);

void main() {
  const BarcodeReader reader = BarcodeReader();

  group('read', () {
    test('finds the barcode in a file', () async {
      final Barcode? barcode = await reader.read(_sample('qrcode-2/1.png'));
      expect(barcode, isNotNull);
      expect(barcode!.format, BarcodeFormat.qrCode);
      expect(
        barcode.text,
        File(
          'third_party/zxing-cpp/test/samples/qrcode-2/1.txt',
        ).readAsStringSync(),
      );
    });

    test('returns null when there is no barcode', () async {
      expect(await reader.read(_sample('falsepositives-1/#245.png')), isNull);
    });

    test('stops at the first barcode', () async {
      expect(await reader.read(_sample('multi-1/multi-qr.png')), isNotNull);
    });

    test('throws ImageDecodeException for something else', () async {
      await expectLater(
        reader.read(Uint8List.fromList(utf8.encode('no image'))),
        throwsA(isA<ImageDecodeException>()),
      );
    });

    test('applies the format filter', () async {
      const BarcodeReader ean = BarcodeReader(
        formats: <BarcodeFormat>{BarcodeFormat.ean13},
      );
      expect(await ean.read(_sample('qrcode-2/1.png')), isNull);
    });
  });

  group('readAll', () {
    test('finds every barcode', () async {
      final List<Barcode> all = await reader.readAll(
        _sample('multi-1/multi-qr.png'),
      );
      expect(all.length, greaterThan(1));
      expect(all.every((Barcode b) => b.format == BarcodeFormat.qrCode), true);
    });

    test('stops at the limit', () async {
      expect(
        await reader.readAll(_sample('multi-1/multi-qr.png'), limit: 2),
        hasLength(2),
      );
    });

    test('rejects a limit below 1', () async {
      await expectLater(
        reader.readAll(_sample('multi-1/multi-qr.png'), limit: 0),
        throwsRangeError,
      );
    });

    test('returns an empty list when there is no barcode', () async {
      expect(
        await reader.readAll(_sample('falsepositives-1/#245.png')),
        isEmpty,
      );
    });
  });

  group('EAN-2/5 add-on', () {
    final Uint8List book = _sample('ean13-extension-1/1.png');

    test('is ignored by default', () async {
      expect((await reader.read(book))!.text, '9780735200449');
    });

    test('is part of the text with EanAddOn.read', () async {
      const BarcodeReader withAddOn = BarcodeReader(
        options: ReaderOptions(eanAddOn: EanAddOn.read),
      );
      expect((await withAddOn.read(book))!.text, '978073520044951299');
    });

    test('EanAddOn.require skips EAN codes without one', () async {
      const BarcodeReader requireAddOn = BarcodeReader(
        options: ReaderOptions(eanAddOn: EanAddOn.require),
      );
      final Barcode plain = (await reader.read(_sample('ean8-1/1.png')))!;
      expect(plain.format, BarcodeFormat.ean8);
      expect(await requireAddOn.read(_sample('ean8-1/1.png')), isNull);
      expect((await requireAddOn.read(book))!.text, '978073520044951299');
    });
  });

  group('readPixels', () {
    late PixelBuffer image;

    setUpAll(() async {
      final BarcodeSymbol symbol = await const BarcodeWriter(
        BarcodeFormat.dataMatrix,
      ).encode('pixels');
      final BarcodeImage rendered = await symbol.toImage(moduleSize: 5);
      image = PixelBuffer(
        rendered.pixels,
        width: rendered.width,
        height: rendered.height,
      );
    });

    test('finds the barcode', () async {
      expect((await reader.readPixels(image))?.text, 'pixels');
    });

    test('respects the crop', () async {
      final PixelBuffer empty = PixelBuffer(
        image.bytes,
        width: image.width,
        height: image.height,
        crop: const Rect.fromLTWH(0, 0, 3, 3),
      );
      expect(await reader.readPixels(empty), isNull);
      expect(await reader.readAllPixels(empty), isEmpty);
    });

    test('readAllPixels finds it too', () async {
      expect(await reader.readAllPixels(image), hasLength(1));
    });

    test('rejects a buffer smaller than its size', () async {
      await expectLater(
        reader.readPixels(PixelBuffer(Uint8List(10), width: 10, height: 10)),
        throwsArgumentError,
      );
    });
  });
}
