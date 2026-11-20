import 'dart:async';
import 'dart:io' show zlib;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/barcode/barcode_format.dart'
    show BarcodeFormatInternal;
import 'package:flutter_zxing/src/engine/engine.dart';
import 'package:flutter_zxing/src/engine/engine_protocol.dart';

/// A backend that answers [version] and can be made to stop.
class _FakeBackend implements EngineBackend {
  _FakeBackend(this.id);

  final int id;
  final Completer<void> _done = Completer<void>();
  bool disposed = false;

  /// readImage fails like stb_image on a format it does not know.
  bool cannotDecode = false;

  /// readImage fails like the engine on an image over its size limit.
  bool tooLarge = false;

  /// The buffers readPixels was called with.
  final List<PixelBuffer> pixels = <PixelBuffer>[];

  void crash() => _done.complete();

  @override
  Future<void> get done => _done.future;

  @override
  void dispose() {
    disposed = true;
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<String> version() async => 'fake $id';

  @override
  Future<EngineMerged> merge(Uint8List data, int characterSet) =>
      throw UnimplementedError();

  @override
  Future<EngineReadResult> readImage(
    Uint8List encodedImage,
    EngineReadOptions options,
  ) async {
    if (tooLarge) {
      throw const ImageDecodeException('Image too large: 20000 x 20000 pixels');
    }
    if (cannotDecode) {
      throw const ImageDecodeException('Cannot decode image: unknown type');
    }
    return const EngineReadResult(
      barcodes: <Barcode>[],
      imageWidth: 0,
      imageHeight: 0,
    );
  }

  @override
  Future<EngineReadResult> readPixels(
    PixelBuffer image,
    EngineReadOptions options, {
    bool mirrored = false,
  }) async {
    pixels.add(image);
    return EngineReadResult(
      barcodes: const <Barcode>[],
      imageWidth: image.width,
      imageHeight: image.height,
    );
  }

  @override
  Future<EngineSymbol> write(
    Uint8List data, {
    required bool binary,
    required String format,
    required String options,
  }) => throw UnimplementedError();
}

void main() {
  group('BarcodeEngine', () {
    late List<_FakeBackend> started;
    late List<Object> failures;

    BarcodeEngine engine() => BarcodeEngine(
      'test',
      factory: (String name) async {
        if (failures.isNotEmpty) {
          Error.throwWithStackTrace(failures.removeAt(0), StackTrace.current);
        }
        final _FakeBackend b = _FakeBackend(started.length);
        started.add(b);
        return b;
      },
    );

    setUp(() {
      started = <_FakeBackend>[];
      failures = <Object>[];
    });

    test('starts lazily, once', () async {
      final BarcodeEngine e = engine();
      expect(started, isEmpty);
      await Future.wait(<Future<String>>[e.version(), e.version()]);
      expect(started, hasLength(1));
      expect(await e.version(), 'fake 0');
    });

    test('starts a new backend after the old one stopped', () async {
      final BarcodeEngine e = engine();
      await e.warmUp();
      started.single.crash();
      await pumpEventQueue();
      expect(await e.version(), 'fake 1');
    });

    test('a failed start throws EngineException and is retried', () async {
      final BarcodeEngine e = engine();
      failures.add(StateError('no library'));
      await expectLater(e.version(), throwsA(isA<EngineException>()));
      expect(await e.version(), 'fake 0');
    });

    test('keeps ZxingExceptions from the factory', () async {
      final BarcodeEngine e = engine();
      failures.add(const EngineException('ABI mismatch'));
      await expectLater(
        e.warmUp(),
        throwsA(
          isA<EngineException>().having(
            (EngineException x) => x.message,
            'message',
            'ABI mismatch',
          ),
        ),
      );
    });

    test('tryWarmUp never fails: the next call starts again', () async {
      final BarcodeEngine e = engine();
      failures.add(StateError('no library'));
      await e.tryWarmUp();
      expect(e.isStarted, isFalse);
      expect(await e.version(), 'fake 0');
    });

    test('tryWarmUp leaves the reason to the first real call', () async {
      final BarcodeEngine e = engine();
      failures
        ..add(StateError('no library'))
        ..add(StateError('still no library'));
      await e.tryWarmUp();
      await expectLater(e.version(), throwsA(isA<EngineException>()));
      expect(await e.version(), 'fake 0');
    });

    test('an image the backend cannot decode is decoded by Flutter', () async {
      final BarcodeEngine e = engine();
      await e.warmUp();
      started.single.cannotDecode = true;
      // A 3 x 2 PNG: red, then transparent white (straight, not
      // premultiplied, as stb_image gives it).
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
        ..drawRect(
          const ui.Rect.fromLTWH(0, 0, 3, 1),
          ui.Paint()..color = const ui.Color(0xFFFF0000),
        )
        ..drawRect(
          const ui.Rect.fromLTWH(0, 1, 3, 1),
          ui.Paint()
            ..color = const ui.Color(0x80FFFFFF)
            ..blendMode = ui.BlendMode.src,
        );
      final ui.Image image = await recorder.endRecording().toImage(3, 2);
      final ByteData png = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      image.dispose();

      final EngineReadResult result = await e.readImage(
        png.buffer.asUint8List(),
        const EngineReadOptions(),
      );
      expect(result.imageWidth, 3);
      expect(result.imageHeight, 2);
      final PixelBuffer pixels = started.single.pixels.single;
      expect(pixels.layout, PixelLayout.rgba);
      expect(pixels.bytes.sublist(0, 4), <int>[255, 0, 0, 255]);
      expect(pixels.bytes.sublist(12, 15), <int>[255, 255, 255]);
    });

    test(
      'an image too large for the engine is not decoded by Flutter',
      () async {
        final BarcodeEngine e = engine();
        await e.warmUp();
        started.single.tooLarge = true;
        await expectLater(
          e.readImage(await _png(3, 2), const EngineReadOptions()),
          throwsA(isA<ImageDecodeException>()),
        );
        expect(started.single.pixels, isEmpty);
      },
    );

    test('Flutter does not decode an image too large to read', () async {
      final BarcodeEngine e = engine();
      await e.warmUp();
      started.single.cannotDecode = true;
      // 65536 x 1 white pixels: a valid PNG, wider than the engine reads.
      final BytesBuilder png = BytesBuilder()
        ..add(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      void chunk(String type, List<int> data) {
        final List<int> typed = <int>[...type.codeUnits, ...data];
        png
          ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
          ..add(typed)
          ..add(
            (ByteData(4)..setUint32(0, _crc32(typed))).buffer.asUint8List(),
          );
      }

      chunk('IHDR', <int>[0, 1, 0, 0, 0, 0, 0, 1, 8, 0, 0, 0, 0]);
      chunk('IDAT', zlib.encode(Uint8List(65537)..fillRange(1, 65537, 255)));
      chunk('IEND', const <int>[]);
      final Uint8List wide = png.takeBytes();
      await expectLater(
        e.readImage(wide, const EngineReadOptions()),
        throwsA(
          isA<ImageDecodeException>().having(
            (ImageDecodeException x) => x.message,
            'message',
            startsWith('Image too large: 65536 x 1 pixels'),
          ),
        ),
      );
      expect(started.single.pixels, isEmpty);
    });

    test("an image nobody decodes keeps the backend's exception", () async {
      final BarcodeEngine e = engine();
      await e.warmUp();
      started.single.cannotDecode = true;
      await expectLater(
        e.readImage(
          Uint8List.fromList(<int>[1, 2, 3]),
          const EngineReadOptions(),
        ),
        throwsA(
          isA<ImageDecodeException>().having(
            (ImageDecodeException x) => x.message,
            'message',
            'Cannot decode image: unknown type',
          ),
        ),
      );
      expect(started.single.pixels, isEmpty);
    });

    test('shutdown disposes the backend; the next call restarts', () async {
      final BarcodeEngine e = engine();
      await e.warmUp();
      await e.shutdown();
      expect(started.single.disposed, isTrue);
      expect(await e.version(), 'fake 1');
    });

    test('rejects a pixel buffer smaller than its geometry', () async {
      final BarcodeEngine e = engine();
      await expectLater(
        e.readPixels(
          PixelBuffer(Uint8List(99), width: 10, height: 10),
          const EngineReadOptions(),
        ),
        throwsArgumentError,
      );
      await expectLater(
        e.readPixels(
          PixelBuffer(Uint8List(400), width: 10, height: 10, rowStride: 9),
          const EngineReadOptions(),
        ),
        throwsArgumentError,
      );
      // Padded rows: the last row does not need its padding.
      await e.readPixels(
        PixelBuffer(
          Uint8List(16 * 9 + 10),
          width: 10,
          height: 10,
          rowStride: 16,
        ),
        const EngineReadOptions(),
      );
      expect(started, hasLength(1));
    });
  });

  group('EngineReadOptions.from', () {
    test('maps every reader option', () {
      // The 4.0 API gives UPC codes as printed; the 3.x API does not.
      expect(
        EngineReadOptions.from(null, const ReaderOptions()),
        const EngineReadOptions(upcAsPrinted: true),
      );
      expect(
        EngineReadOptions.from(null, const ReaderOptions()),
        isNot(const EngineReadOptions()),
      );
      final EngineReadOptions o = EngineReadOptions.from(
        const <BarcodeFormat>{BarcodeFormat.qrCode, BarcodeFormat.ean13},
        const ReaderOptions(
          tryHarder: false,
          tryRotate: false,
          tryInvert: false,
          tryDownscale: false,
          isPure: true,
          returnErrors: true,
          validateOptionalChecksum: true,
          binarizer: Binarizer.boolCast,
          minLineCount: 3,
        ),
        maxSymbols: 1,
      );
      expect(o.formats, 'QRCode,EAN13');
      expect(
        o.flags,
        FzxFlags.isPure |
            FzxFlags.returnErrors |
            FzxFlags.validateOptionalChecksum,
      );
      expect(o.binarizer, 3);
      expect(o.maxSymbols, 1);
      expect(o.minLineCount, 3);
    });

    test('camera options', () {
      expect(
        EngineReadOptions.from(null, const ReaderOptions.camera()).flags,
        FzxFlags.tryHarder | FzxFlags.tryRotate | FzxFlags.tryDownscale,
      );
    });

    test('null means all formats', () {
      expect(EngineReadOptions.from(null, const ReaderOptions()).formats, '');
    });

    test('rejects an empty format set', () {
      expect(
        () => EngineReadOptions.from(
          const <BarcodeFormat>{},
          const ReaderOptions(),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'message',
            contains('Pass null to read every format'),
          ),
        ),
      );
    });

    test('rejects every format that cannot be read', () {
      for (final BarcodeFormat format in BarcodeFormat.values) {
        if (format.canRead) {
          expect(
            EngineReadOptions.formatsToEngine(<BarcodeFormat>{format}),
            format.zxingName,
          );
        } else {
          expect(
            () => EngineReadOptions.formatsToEngine(<BarcodeFormat>{format}),
            throwsA(
              isA<ArgumentError>().having(
                (ArgumentError e) => e.message,
                'message',
                contains('BarcodeFormat.${format.name} cannot be'),
              ),
            ),
            reason: format.name,
          );
        }
      }
    });

    test('says how to read what cannot be read', () {
      String why(BarcodeFormat format) {
        try {
          EngineReadOptions.formatsToEngine(<BarcodeFormat>{
            BarcodeFormat.qrCode,
            format,
          });
        } on ArgumentError catch (e) {
          return e.message as String;
        }
        fail('${format.name} accepted');
      }

      expect(why(BarcodeFormat.isbn), contains('BarcodeFormat.ean13'));
      expect(why(BarcodeFormat.ean5), contains('ReaderOptions.eanAddOn'));
      expect(why(BarcodeFormat.unknown), contains('cannot be searched for'));
    });
  });

  test('throwFzxError maps codes to the documented exceptions', () {
    expect(
      () => throwFzxError(FzxError.image, 'x'),
      throwsA(isA<ImageDecodeException>()),
    );
    expect(
      () => throwFzxError(FzxError.write, 'x'),
      throwsA(isA<BarcodeWriteException>()),
    );
    expect(() => throwFzxError(FzxError.argument, 'x'), throwsArgumentError);
    expect(
      () => throwFzxError(FzxError.internal, 'x'),
      throwsA(isA<EngineException>()),
    );
    expect(
      () => throwFzxError(FzxError.noWriter, 'x'),
      throwsA(isA<EngineException>()),
    );
  });

  test("write errors drop zint's error number and return value", () {
    expect(
      writeErrorMessage(
        "Error 275: Invalid check digit '4', expecting '3' (retval: 7)",
      ),
      "Invalid check digit '4', expecting '3'",
    );
    expect(writeErrorMessage('Nothing to encode'), 'Nothing to encode');
  });
}

/// A PNG of [width] x [height] white pixels.
Future<Uint8List> _png(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData png = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!;
  image.dispose();
  return png.buffer.asUint8List();
}

int _crc32(List<int> bytes) {
  int crc = 0xFFFFFFFF;
  for (final int b in bytes) {
    crc ^= b;
    for (int k = 0; k < 8; k++) {
      crc = crc & 1 != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
