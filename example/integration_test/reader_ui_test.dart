// Reading a 12 MP photo must not block the UI: the engine runs on its own
// isolate (a Web Worker on the web). A 1 ms timer on the UI isolate measures
// the longest stall while BarcodeReader reads the photo; 3.x froze the UI
// for a second on the same kind of image (#74).
//
// Integration tests run in debug mode (JIT, assertions), so the bound is
// loose; the measured numbers are printed for the record.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing_example/corpus/corpus_harness.dart';
import 'package:integration_test/integration_test.dart';

/// Longest stall of the UI isolate allowed while reading, in debug mode.
const Duration _maxStall = Duration(milliseconds: 100);

/// Runs [work] and returns its result with the longest gap between ticks
/// of a 1 ms timer on this isolate meanwhile.
Future<(T, Duration)> _measureStall<T>(Future<T> Function() work) async {
  final Stopwatch clock = Stopwatch()..start();
  Duration last = Duration.zero;
  Duration worst = Duration.zero;
  final Timer timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
    final Duration now = clock.elapsed;
    if (now - last > worst) {
      worst = now - last;
    }
    last = now;
  });
  try {
    final T result = await work();
    return (result, worst);
  } finally {
    timer.cancel();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reading a 12 MP photo does not block the UI', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await warmUpBarcodeEngine();
      final PixelBuffer photo = await syntheticPhoto();
      final Uint8List png = await BarcodeImage(
        width: photo.width,
        height: photo.height,
        pixels: photo.bytes,
      ).toPng();

      const BarcodeReader reader = BarcodeReader();
      final Stopwatch read = Stopwatch()..start();
      final (Barcode? first, Duration readStall) = await _measureStall(
        () => reader.read(png),
      );
      read.stop();
      final Stopwatch readAll = Stopwatch()..start();
      final (List<Barcode> all, Duration readAllStall) = await _measureStall(
        () => reader.readAll(png),
      );
      readAll.stop();
      final (Barcode? fromPixels, Duration pixelsStall) = await _measureStall(
        () => reader.readPixels(photo),
      );

      // ignore: avoid_print
      print(
        '12 MP PNG: read ${read.elapsedMilliseconds} ms '
        '(UI stall ${readStall.inMilliseconds} ms), '
        'readAll ${readAll.elapsedMilliseconds} ms '
        '(UI stall ${readAllStall.inMilliseconds} ms), '
        'readPixels UI stall ${pixelsStall.inMilliseconds} ms',
      );
      expect(first?.text, syntheticPhotoText);
      expect(all.map((Barcode b) => b.text), <String>[syntheticPhotoText]);
      expect(fromPixels?.text, syntheticPhotoText);
      expect(readStall, lessThan(_maxStall));
      expect(readAllStall, lessThan(_maxStall));
      expect(pixelsStall, lessThan(_maxStall));
    });
  });
}
