// BarcodeReader on the real engine (built for the host by the build hook).
@Tags(<String>['native'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// A grayscale PNG of [width] x [height] pixels, all [gray]; [header] only
/// writes the header, the pixels are left out.
Uint8List _grayPng(
  int width,
  int height, {
  int gray = 255,
  bool header = false,
}) {
  final BytesBuilder png = BytesBuilder()
    ..add(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final List<int> typed = <int>[...ascii.encode(type), ...data];
    int crc = 0xFFFFFFFF;
    for (final int b in typed) {
      crc ^= b;
      for (int k = 0; k < 8; k++) {
        crc = crc & 1 != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    png
      ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
      ..add(typed)
      ..add((ByteData(4)..setUint32(0, crc ^ 0xFFFFFFFF)).buffer.asUint8List());
  }

  chunk('IHDR', <int>[
    ...(ByteData(8)
          ..setUint32(0, width)
          ..setUint32(4, height))
        .buffer
        .asUint8List(),
    8, 0, 0, 0, 0, // 8-bit gray, deflate, no filter, no interlace
  ]);
  if (!header) {
    final Uint8List rows = Uint8List((width + 1) * height);
    for (int y = 0; y < height; y++) {
      rows.fillRange(y * (width + 1) + 1, (y + 1) * (width + 1), gray);
    }
    chunk('IDAT', zlib.encode(rows));
  }
  chunk('IEND', const <int>[]);
  return png.takeBytes();
}

/// zxing-cpp's samples, from the submodule the engine is built from.
Uint8List _sample(String name) => Uint8List.fromList(
  File('third_party/zxing-cpp/test/samples/$name').readAsBytesSync(),
);

void main() {
  const BarcodeReader reader = BarcodeReader();

  group('read', () {
    test('finds the barcode in a file', () async {
      final Barcode? barcode = await reader.read(_sample('qrcode-1/1.png'));
      expect(barcode, isNotNull);
      expect(barcode!.format, BarcodeFormat.qrCode);
      expect(
        barcode.text,
        File(
          'third_party/zxing-cpp/test/samples/qrcode-1/1.txt',
        ).readAsStringSync(),
      );
    });

    test('returns null when there is no barcode', () async {
      expect(await reader.read(_sample('none-1/#245.png')), isNull);
    });

    test('stops at the first barcode', () async {
      expect(await reader.read(_sample('multi-1/qr-x4.png')), isNotNull);
    });

    test('reads what Flutter decodes and the engine does not: WebP', () async {
      final Barcode? barcode = await reader.read(_sample('code128-1/2.webp'));
      expect(barcode?.format, BarcodeFormat.code128);
      expect(
        barcode?.text,
        File(
          'third_party/zxing-cpp/test/samples/code128-1/2.txt',
        ).readAsStringSync(),
      );
      expect(await reader.readAll(_sample('code128-1/2.webp')), hasLength(1));
    });

    test('throws ImageDecodeException for something else', () async {
      await expectLater(
        reader.read(Uint8List.fromList(utf8.encode('no image'))),
        throwsA(isA<ImageDecodeException>()),
      );
    });

    test('rejects an empty or unreadable format filter', () async {
      await expectLater(
        const BarcodeReader(
          formats: <BarcodeFormat>{},
        ).read(_sample('qrcode-1/1.png')),
        throwsArgumentError,
      );
      await expectLater(
        const BarcodeReader(
          formats: <BarcodeFormat>{BarcodeFormat.isbn},
        ).readAll(_sample('qrcode-1/1.png')),
        throwsArgumentError,
      );
    });

    test('applies the format filter', () async {
      const BarcodeReader ean = BarcodeReader(
        formats: <BarcodeFormat>{BarcodeFormat.ean13},
      );
      expect(await ean.read(_sample('qrcode-1/1.png')), isNull);
    });
  });

  group('readAll', () {
    test('finds every barcode', () async {
      final List<Barcode> all = await reader.readAll(
        _sample('multi-1/qr-x4.png'),
      );
      expect(all.length, greaterThan(1));
      expect(all.every((Barcode b) => b.format == BarcodeFormat.qrCode), true);
    });

    test('stops at maxBarcodes', () async {
      expect(
        await reader.readAll(_sample('multi-1/qr-x4.png'), maxBarcodes: 2),
        hasLength(2),
      );
    });

    test('rejects maxBarcodes below 1', () async {
      await expectLater(
        reader.readAll(_sample('multi-1/qr-x4.png'), maxBarcodes: 0),
        throwsA(
          isA<RangeError>().having(
            (RangeError e) => e.name,
            'name',
            'maxBarcodes',
          ),
        ),
      );
      await expectLater(
        reader.readAllPixels(
          PixelBuffer(Uint8List(100), width: 10, height: 10),
          maxBarcodes: -1,
        ),
        throwsRangeError,
      );
    });

    test('returns an empty list when there is no barcode', () async {
      expect(await reader.readAll(_sample('none-1/#245.png')), isEmpty);
    });
  });

  group('EAN-2/5 add-on', () {
    final Uint8List book = _sample('ean13-ext-1/1.png');

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

  test('tryDenoise reads a QR code printed with gaps on a rough surface', () async {
    // zxing-cpp's own test reads this sample only with tryDenoise.
    final Uint8List dots = _sample('qrcode-2/28.webp');
    const BarcodeReader qr = BarcodeReader(
      formats: <BarcodeFormat>{BarcodeFormat.qrCode},
    );
    expect(await qr.read(dots), isNull);
    final Barcode? denoised = await qr
        .copyWith(options: const ReaderOptions(tryDenoise: true))
        .read(dots);
    expect(denoised?.text, 'http://www.webtech.co.jp/k/');
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

    test('a crop is cut to the image, not moved into it', () async {
      PixelBuffer cropped(Rect crop) => PixelBuffer(
        image.bytes,
        width: image.width,
        height: image.height,
        crop: crop,
      );
      final double w = image.width.toDouble(), h = image.height.toDouble();
      // Left of the image: nothing there, not the image's left part.
      expect(
        await reader.readPixels(cropped(Rect.fromLTWH(-w, 0, w, h))),
        isNull,
      );
      // Empty: nothing, not the whole image.
      expect(
        await reader.readAllPixels(cropped(const Rect.fromLTWH(10, 10, 0, 0))),
        isEmpty,
      );
      // Larger than the image: all of it.
      expect(
        (await reader.readPixels(
          cropped(Rect.fromLTWH(-10, -10, w + 20, h + 20)),
        ))?.text,
        'pixels',
      );
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

  group('as documented on Barcode', () {
    Future<Barcode> roundTrip(BarcodeFormat format, String data) async {
      final Uint8List png = await BarcodeWriter(
        format,
      ).toPng(data, moduleSize: 4);
      return (await BarcodeReader(formats: <BarcodeFormat>{format}).read(png))!;
    }

    test('ecLevel and version in the terms of each format', () async {
      for (final (BarcodeFormat format, String ec, String? version)
          in <(BarcodeFormat, String, String?)>[
            (BarcodeFormat.qrCode, r'^[LMQH]$', r'^\d+$'),
            (BarcodeFormat.microQrCode, r'^[LMQ]$', r'^M[1-4]$'),
            (BarcodeFormat.rmqrCode, r'^[MH]$', r'^R\d+x\d+$'),
            (BarcodeFormat.aztec, r'^\d+%$', r'^\d+$'),
            (BarcodeFormat.pdf417, r'^\d+%$', null),
            (BarcodeFormat.microPdf417, r'^\d+%$', null),
          ]) {
        final Barcode b = await roundTrip(format, 'HELLO');
        expect(b.ecLevel, matches(ec), reason: format.name);
        expect(
          b.version,
          version == null ? isNull : matches(version),
          reason: format.name,
        );
      }
      final Barcode dm = await roundTrip(BarcodeFormat.dataMatrix, 'HELLO');
      expect(dm.ecLevel, isNull);
      expect(dm.version, '12x12');
    });

    test('text escapes binary content; bytes hold it', () async {
      final BarcodeSymbol symbol = await const BarcodeWriter(
        BarcodeFormat.qrCode,
      ).encodeBytes(Uint8List.fromList(<int>[0x00, 0x80, 0x41]));
      final Barcode b = (await reader.read(await symbol.toPng()))!;
      expect(b.contentType, BarcodeContentType.binary);
      expect(b.text, '<NUL><U+80>A');
      expect(b.bytes, <int>[0x00, 0x80, 0x41]);
    });
  });

  group('a transparent background reads as light', () {
    late BarcodeSymbol symbol;

    setUpAll(() async {
      symbol = await const BarcodeWriter(BarcodeFormat.qrCode).encode('alpha');
    });

    test('in a PNG exported without a background', () async {
      final Uint8List png = await const BarcodeStyle(
        backgroundColor: Color(0x00000000),
      ).toPng(symbol, moduleSize: 4);
      expect((await reader.read(png))?.text, 'alpha');
    });

    test('in RGBA pixels', () async {
      final BarcodeImage image = await symbol.toImage(moduleSize: 4);
      // Black modules, transparent black elsewhere: (0, 0, 0, 0).
      final Uint8List rgba = Uint8List(image.pixels.length * 4);
      for (int i = 0; i < image.pixels.length; i++) {
        rgba[i * 4 + 3] = image.pixels[i] < 128 ? 255 : 0;
      }
      expect(
        (await reader.readPixels(
          PixelBuffer(
            rgba,
            width: image.width,
            height: image.height,
            layout: PixelLayout.rgba,
          ),
        ))?.text,
        'alpha',
      );
    });

    test('not in pixels whose fourth byte is 0 everywhere (BGRX)', () async {
      final BarcodeImage image = await symbol.toImage(moduleSize: 4);
      final Uint8List bgrx = Uint8List(image.pixels.length * 4);
      for (int i = 0; i < image.pixels.length; i++) {
        bgrx.fillRange(i * 4, i * 4 + 3, image.pixels[i]);
      }
      expect(
        (await reader.readPixels(
          PixelBuffer(
            bgrx,
            width: image.width,
            height: image.height,
            layout: PixelLayout.bgra,
          ),
        ))?.text,
        'alpha',
      );
    });
  });

  group('an image too large to read', () {
    test('throws ImageDecodeException before it is decoded', () async {
      await expectLater(
        reader.read(_grayPng(20000, 20000, header: true)),
        throwsA(
          isA<ImageDecodeException>().having(
            (ImageDecodeException e) => e.message,
            'message',
            startsWith('Image too large: 20000 x 20000 pixels'),
          ),
        ),
      );
    });

    test('wider than 65535 pixels throws ImageDecodeException', () async {
      await expectLater(
        reader.readAll(_grayPng(65536, 1)),
        throwsA(isA<ImageDecodeException>()),
      );
    });
  });
}
