// BarcodeWriter on the real engine: every writable format is created,
// rendered, encoded as PNG and read back.
@Tags(<String>['native'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// The reader settings that find a [format]: all of its symbology's
/// variants (Telepen Numeric is only read when asked for).
BarcodeReader _readerFor(BarcodeFormat format) => BarcodeReader(
  formats: <BarcodeFormat>{
    for (final BarcodeFormat f in BarcodeFormat.values)
      if (f.symbology == format.symbology && f.canRead) f,
  },
);

void main() {
  final List<BarcodeFormat> writable = <BarcodeFormat>[
    for (final BarcodeFormat f in BarcodeFormat.values)
      if (f.canWrite) f,
  ];

  for (final BarcodeFormat format in writable) {
    final String example = format.input!.example;
    test('${format.displayName}: its example is created, rendered and read '
        'back', () async {
      final BarcodeWriter writer = BarcodeWriter(format, showText: true);
      final BarcodeSymbol symbol = await writer.encode(example);
      expect(symbol.format.symbology, format.symbology);
      expect(symbol.modules, hasLength(symbol.width * symbol.height));
      expect(
        symbol.text != null,
        format.isLinear && format != BarcodeFormat.dxFilmEdge,
      );

      final BarcodeImage image = await symbol.toImage(moduleSize: 3);
      final Barcode? fromPixels = await _readerFor(format).readPixels(
        PixelBuffer(image.pixels, width: image.width, height: image.height),
      );
      expect(fromPixels, isNotNull, reason: 'read from pixels');
      expect(fromPixels!.format.symbology, format.symbology);
      // Linear formats may add a check digit or normalize the data (a GTIN
      // is read as `(01)…`), Aztec Runes are three digits; everything else
      // reads back as it was written.
      if (!format.isLinear && format != BarcodeFormat.aztecRune) {
        expect(fromPixels.text, example);
      }

      final Barcode? fromPng = await _readerFor(
        format,
      ).read(await image.toPng());
      expect(fromPng?.text, fromPixels.text, reason: 'read from PNG');
    });
  }

  group('error correction', () {
    for (final BarcodeFormat format in writable.where(
      (BarcodeFormat f) => f.hasErrorCorrection,
    )) {
      test('${format.displayName} takes every level', () async {
        for (final ErrorCorrection level in ErrorCorrection.values) {
          final BarcodeSymbol symbol = await BarcodeWriter(
            format,
            errorCorrection: level,
          ).encode(format.input!.example);
          expect(symbol.width, greaterThan(0), reason: level.name);
        }
      });
    }

    test('formats with fixed error correction ignore it', () async {
      for (final BarcodeFormat format in writable.where(
        (BarcodeFormat f) => !f.hasErrorCorrection,
      )) {
        await const BarcodeWriter(BarcodeFormat.qrCode)
            .copyWith(format: format, errorCorrection: ErrorCorrection.high)
            .encode(format.input!.example);
      }
    });
  });

  test("an invalid input says what is wrong, without zint's codes", () async {
    await expectLater(
      const BarcodeWriter(BarcodeFormat.ean13).encode('9501101530004'),
      throwsA(
        isA<BarcodeWriteException>().having(
          (BarcodeWriteException e) => e.message,
          'message',
          "Invalid check digit '4', expecting '3'",
        ),
      ),
    );
  });

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

    test('is left out of an export when turned off', () async {
      final BarcodeSymbol qr = await const BarcodeWriter(
        BarcodeFormat.qrCode,
      ).encode('x');
      expect(qr.quietZone, greaterThan(0));
      final BarcodeImage bare = await qr.toImage(
        moduleSize: 1,
        quietZone: false,
      );
      expect(bare.width, qr.width);
      expect(bare.pixels.first, 0, reason: 'a finder at the corner');
      final String svg = qr.toSvg(quietZone: false);
      expect(svg, contains('viewBox="0 0 ${qr.width} ${qr.height}"'));
      final BarcodeImage padded = await qr.toImage(moduleSize: 1);
      expect(padded.width, qr.width + 2 * qr.quietZone);
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

  test('zxingOptions win over the typed fields', () async {
    Future<Barcode?> read(BarcodeWriter writer) async {
      final BarcodeImage image = await (await writer.encode('x')).toImage();
      return const BarcodeReader().readPixels(
        PixelBuffer(image.pixels, width: image.width, height: image.height),
      );
    }

    // Over the QR default M and over errorCorrection.
    expect(
      (await read(
        const BarcodeWriter(BarcodeFormat.qrCode, zxingOptions: 'ecLevel=H'),
      ))?.ecLevel,
      'H',
    );
    expect(
      (await read(
        const BarcodeWriter(
          BarcodeFormat.qrCode,
          errorCorrection: ErrorCorrection.low,
          zxingOptions: 'ecLevel=Q',
        ),
      ))?.ecLevel,
      'Q',
    );
    expect(
      (await read(
        const BarcodeWriter(
          BarcodeFormat.qrCode,
          version: 2,
          zxingOptions: 'version=5',
        ),
      ))?.version,
      '5',
    );
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

  test('ReaderOptions.characterSet decodes text that declares none', () async {
    // "Привет" in Windows-1251, as raw bytes without an ECI (bytes are
    // otherwise written with the binary ECI, which the reader follows).
    final Uint8List cp1251 = Uint8List.fromList(<int>[
      0xCF, 0xF0, 0xE8, 0xE2, 0xE5, 0xF2, //
    ]);
    final BarcodeSymbol symbol = await const BarcodeWriter(
      BarcodeFormat.qrCode,
      zxingOptions: 'eci=0',
    ).encodeBytes(cp1251);
    final BarcodeImage image = await symbol.toImage();
    final PixelBuffer pixels = PixelBuffer(
      image.pixels,
      width: image.width,
      height: image.height,
    );
    final Barcode? guessed = await const BarcodeReader().readPixels(pixels);
    expect(guessed?.bytes, cp1251);
    expect(guessed?.text, isNot('Привет'));
    final Barcode? told = await const BarcodeReader(
      options: ReaderOptions(characterSet: CharacterSet.cp1251),
    ).readPixels(pixels);
    expect(told?.bytes, cp1251);
    expect(told?.text, 'Привет');
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

  test('the engine takes the largest version of each format', () async {
    for (final (BarcodeFormat format, int version, String data)
        in <(BarcodeFormat, int, String)>[
          (BarcodeFormat.qrCode, 40, 'x'),
          (BarcodeFormat.microQrCode, 4, 'x'),
          (BarcodeFormat.rmqrCode, 38, 'x'),
          (BarcodeFormat.dataMatrix, 48, 'x'),
          (BarcodeFormat.aztec, 36, 'x'),
          (BarcodeFormat.pdf417, 30, 'x'),
          (BarcodeFormat.microPdf417, 4, 'x'),
        ]) {
      final BarcodeSymbol symbol = await BarcodeWriter(
        format,
        version: version,
      ).encode(data);
      final Barcode? read = await _readerFor(
        format,
      ).readPixels(_pixels(await symbol.toImage()));
      expect(read?.text, data, reason: format.name);
    }
    expect(
      (await const BarcodeWriter(
        BarcodeFormat.qrCode,
        version: 40,
      ).encode('x')).width,
      177,
    );
  });

  test('a version or option the format does not take throws', () async {
    await expectLater(
      const BarcodeWriter(BarcodeFormat.qrCode, version: 41).encode('x'),
      throwsRangeError,
    );
    await expectLater(
      const BarcodeWriter(BarcodeFormat.ean13, version: 1).encode('x'),
      throwsArgumentError,
    );
    await expectLater(
      const BarcodeWriter(
        BarcodeFormat.dataMatrix,
        zxingOptions: 'nonsense=1',
      ).encode('x'),
      throwsArgumentError,
    );
  });
}

PixelBuffer _pixels(BarcodeImage image) =>
    PixelBuffer(image.pixels, width: image.width, height: image.height);
