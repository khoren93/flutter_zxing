import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/engine/engine.dart';
import 'package:flutter_zxing/src/engine/engine_protocol.dart';

/// A backend that answers [version] and can be made to stop.
class _FakeBackend implements EngineBackend {
  _FakeBackend(this.id);

  final int id;
  final Completer<void> _done = Completer<void>();
  bool disposed = false;

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
  Future<EngineReadResult> readImage(
    Uint8List encodedImage,
    EngineReadOptions options,
  ) async => const EngineReadResult(
    barcodes: <Barcode>[],
    imageWidth: 0,
    imageHeight: 0,
  );

  @override
  Future<EngineReadResult> readPixels(
    PixelBuffer image,
    EngineReadOptions options,
  ) => readImage(image.bytes, options);

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
      expect(
        EngineReadOptions.from(null, const ReaderOptions()),
        const EngineReadOptions(),
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
        FzxFlags.tryRotate | FzxFlags.tryDownscale,
      );
    });

    test('an empty format set means all formats', () {
      expect(
        EngineReadOptions.from(
          const <BarcodeFormat>{},
          const ReaderOptions(),
        ).formats,
        '',
      );
    });

    test('rejects BarcodeFormat.unknown', () {
      expect(
        () => EngineReadOptions.from(const <BarcodeFormat>{
          BarcodeFormat.unknown,
        }, const ReaderOptions()),
        throwsArgumentError,
      );
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
}
