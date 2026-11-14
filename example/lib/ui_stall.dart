// How much reading a 12 MP photo holds up the UI, in a release build:
// Flutter frames slower than 16 ms and the longest gap of a 1 ms timer on
// the UI isolate while BarcodeReader reads the photo. The integration test
// example/integration_test/reader_ui_test.dart measures the same in debug.
//
//   flutter run --release -t lib/scanner_dev.dart --dart-define=MEASURE=ui_stall
//
// prints `[uistall] {json}` and shows the numbers.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'corpus/corpus_harness.dart';

/// Reads a 12 MP photo three ways and returns what the UI saw meanwhile.
/// Keep something animating on screen, so that Flutter draws frames.
Future<Map<String, Object>> measureUiStall() async {
  await warmUpBarcodeEngine();
  final PixelBuffer photo = await syntheticPhoto();
  final Uint8List png = await BarcodeImage(
    width: photo.width,
    height: photo.height,
    pixels: photo.bytes,
  ).toPng();
  const BarcodeReader reader = BarcodeReader();
  final Map<String, Object> result = <String, Object>{
    'build': kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
    'platform': defaultTargetPlatform.name,
    'device': const String.fromEnvironment('DEVICE'),
  };
  for (final (String name, Future<Object?> Function() work)
      in <(String, Future<Object?> Function())>[
        // The noise floor: the same measurement while nothing is read.
        ('idle', () => Future<Object?>.delayed(const Duration(seconds: 1))),
        ('read', () => reader.read(png)),
        ('readAll', () => reader.readAll(png)),
        ('readPixels', () => reader.readPixels(photo)),
      ]) {
    result[name] = await _measure(work);
  }
  debugPrint('[uistall] ${jsonEncode(result)}');
  return result;
}

Future<Map<String, Object?>> _measure(Future<Object?> Function() work) async {
  final List<FrameTiming> frames = <FrameTiming>[];
  void onTimings(List<FrameTiming> timings) => frames.addAll(timings);
  SchedulerBinding.instance.addTimingsCallback(onTimings);
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
  final Object? found;
  try {
    found = await work();
  } finally {
    timer.cancel();
  }
  final int ms = clock.elapsedMilliseconds;
  // Release builds report timings in batches, about once a second: wait
  // for the last ones.
  await Future<void>.delayed(const Duration(milliseconds: 1200));
  SchedulerBinding.instance.removeTimingsCallback(onTimings);
  // As the prototype's benchmark counted them: build + raster over 16 ms.
  final int slow = frames
      .where(
        (FrameTiming t) =>
            t.buildDuration + t.rasterDuration >
            const Duration(microseconds: 16667),
      )
      .length;
  final int worstFrame = frames.isEmpty
      ? 0
      : frames
            .map((FrameTiming t) => t.totalSpan.inMicroseconds)
            .reduce((int a, int b) => a > b ? a : b);
  return <String, Object?>{
    'ms': ms,
    'found': switch (found) {
      null => null,
      final Barcode b => b.text == syntheticPhotoText,
      final List<Barcode> all => all.any(
        (Barcode b) => b.text == syntheticPhotoText,
      ),
      _ => false,
    },
    'timer_gap_ms': worst.inMilliseconds,
    'frames': frames.length,
    'frames_over_16ms': slow,
    'worst_frame_ms': (worstFrame / 1000).toStringAsFixed(1),
  };
}
