// The real engine on the host: the build hook compiles it for macOS, Linux
// or Windows when the tests run.
@Tags(<String>['native'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/engine/engine.dart';
import 'package:flutter_zxing/src/engine/engine_protocol.dart';

/// zxing-cpp's samples: always there, the engine is built from the same
/// submodule.
const String _samples = 'third_party/zxing-cpp/test/samples';

Uint8List _sample(String name) =>
    Uint8List.fromList(File('$_samples/$name').readAsBytesSync());

void main() {
  final BarcodeEngine engine = BarcodeEngine.shared;

  test('the engine is the zxing-cpp version the package declares', () async {
    expect(await engine.version(), zxingCppVersion);
  });

  test('warmUpBarcodeEngine starts the engines', () async {
    await warmUpBarcodeEngine();
    expect(await BarcodeEngine.scanner.version(), zxingCppVersion);
  });

  test('a file that is not an image throws ImageDecodeException', () async {
    await expectLater(
      engine.readImage(
        Uint8List.fromList(utf8.encode('not an image')),
        const EngineReadOptions(),
      ),
      throwsA(isA<ImageDecodeException>()),
    );
    await expectLater(
      engine.readImage(Uint8List(0), const EngineReadOptions()),
      throwsA(isA<ImageDecodeException>()),
    );
  });

  test('data that cannot be encoded throws BarcodeWriteException', () async {
    await expectLater(
      engine.write(
        utf8.encode('letters'),
        binary: false,
        format: 'EAN13',
        options: '',
      ),
      throwsA(isA<BarcodeWriteException>()),
    );
  });

  test('an unknown format name is an argument error', () async {
    await expectLater(
      engine.write(
        utf8.encode('x'),
        binary: false,
        format: 'NoSuchFormat',
        options: '',
      ),
      throwsArgumentError,
    );
  });

  test('the engine keeps working after errors', () async {
    final EngineReadResult r = await engine.readImage(
      _sample('qrcode-2/1.png'),
      const EngineReadOptions(),
    );
    expect(r.barcodes, isNotEmpty);
  });

  test('maxSymbols limits the barcodes found', () async {
    final Uint8List image = _sample('multi-1/multi-qr.png');
    final EngineReadResult all = await engine.readImage(
      image,
      const EngineReadOptions(),
    );
    final EngineReadResult first = await engine.readImage(
      image,
      const EngineReadOptions(maxSymbols: 1),
    );
    expect(all.barcodes.length, greaterThan(1));
    expect(first.barcodes, hasLength(1));
  });

  test('the format filter applies', () async {
    final EngineReadResult r = await engine.readImage(
      _sample('qrcode-2/1.png'),
      EngineReadOptions.from(const <BarcodeFormat>{
        BarcodeFormat.ean13,
      }, const ReaderOptions()),
    );
    expect(r.barcodes, isEmpty);
  });

  group('readPixels', () {
    late EngineSymbol symbol;
    late PixelBuffer image;
    const int scale = 4;
    const int left = 37;
    const int top = 23;

    setUpAll(() async {
      symbol = await engine.write(
        utf8.encode('pixels'),
        binary: false,
        format: 'QRCode',
        options: '',
      );
      // The symbol at (left, top) of a larger white RGBA image.
      const int width = 200;
      const int height = 160;
      final Uint8List rgba = Uint8List(width * height * 4)
        ..fillRange(0, width * height * 4, 255);
      for (int y = 0; y < symbol.height * scale; y++) {
        for (int x = 0; x < symbol.width * scale; x++) {
          if (symbol.modules[(y ~/ scale) * symbol.width + x ~/ scale] != 0) {
            final int o = ((top + y) * width + left + x) * 4;
            rgba.fillRange(o, o + 3, 0);
          }
        }
      }
      image = PixelBuffer(
        rgba,
        width: width,
        height: height,
        layout: PixelLayout.rgba,
      );
    });

    test('positions are in pixels of the whole image', () async {
      final EngineReadResult r = await engine.readPixels(
        image,
        const EngineReadOptions(),
      );
      expect(r.imageWidth, 200);
      expect(r.barcodes.single.text, 'pixels');
      expect(r.barcodes.single.position.topLeft.dx, closeTo(left, 1));
      expect(r.barcodes.single.position.topLeft.dy, closeTo(top, 1));
    });

    test('a crop keeps whole-image coordinates', () async {
      final EngineReadResult r = await engine.readPixels(
        PixelBuffer(
          image.bytes,
          width: image.width,
          height: image.height,
          layout: PixelLayout.rgba,
          crop: const Rect.fromLTWH(20, 10, 150, 130),
        ),
        const EngineReadOptions(),
      );
      expect(r.barcodes.single.position.topLeft.dx, closeTo(left, 1));
      expect(r.barcodes.single.position.topLeft.dy, closeTo(top, 1));
    });

    test('a crop without the barcode finds nothing', () async {
      final EngineReadResult r = await engine.readPixels(
        PixelBuffer(
          image.bytes,
          width: image.width,
          height: image.height,
          layout: PixelLayout.rgba,
          crop: const Rect.fromLTWH(150, 0, 50, 160),
        ),
        const EngineReadOptions(),
      );
      expect(r.barcodes, isEmpty);
    });
  });

  test('a shut down engine restarts on the next call', () async {
    final BarcodeEngine e = BarcodeEngine('restart test');
    await e.warmUp();
    // A large image, so that the call is still running at shutdown.
    final Future<EngineReadResult> pending = e.readPixels(
      PixelBuffer(Uint8List(4000 * 3000), width: 4000, height: 3000),
      const EngineReadOptions(),
    );
    await e.shutdown();
    await expectLater(pending, throwsA(isA<EngineException>()));
    expect(await e.version(), zxingCppVersion);
    await e.shutdown();
  });
}
