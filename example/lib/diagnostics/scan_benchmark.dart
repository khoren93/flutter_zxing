// Camera scan benchmark, the method of the 4.0 prototype: collects 1000
// frames that contained a barcode (after 20 warm-up frames) and reports
// avg / min / max / p50 / p95 of the scan latency and the engine time, the
// camera's frame rate and skipped frames, and how long Flutter frames took.
//
// The result is printed in numbered pieces, `[scanbench 1/3] ...` (collected
// from the `flutter run` log; Android cuts longer lines), and saved as JSON
// in the app's temporary directory. benchmark/BENCHMARKS.md is built from such
// files with `cd tool && dart run scanbench_report.dart`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
// Frame timings are not public API.
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug, ScannerFrameSample;

/// The scan window of the prototype's runs: 60% x 80% in the centre.
const ScanWindow benchmarkWindow = ScanWindow.fromRect(
  Rect.fromLTWH(0.2, 0.1, 0.6, 0.8),
);

/// Which camera pipeline produced the numbers. Change it when the pipeline
/// changes, so that old and new results stay comparable.
String get pipelineName => kIsWeb
    ? 'flutter_zxing 4.0: getUserMedia <video> -> createImageBitmap(window) '
          '-> fzx wasm worker'
    : 'flutter_zxing 4.0: camera plugin (startImageStream) -> window rows '
          'into native memory -> fzx isolate';

/// avg / min / max / percentiles of microsecond samples, in milliseconds.
class Stats {
  /// Statistics of [micros].
  Stats(List<int> micros)
    : n = micros.length,
      _sorted = <int>[...micros]..sort();

  /// Number of samples.
  final int n;
  final List<int> _sorted;

  double get _avg =>
      _sorted.isEmpty ? 0 : _sorted.reduce((int a, int b) => a + b) / n / 1000;
  double _at(double p) =>
      _sorted.isEmpty ? 0 : _sorted[math.min(n - 1, (p * n).floor())] / 1000;

  static double _r(double v) => (v * 100).round() / 100;

  /// The JSON form of the prototype's results.
  Map<String, Object> toJson() => <String, Object>{
    'n': n,
    'avg_ms': _r(_avg),
    'min_ms': _r(_at(0)),
    'max_ms': _r(_sorted.isEmpty ? 0 : _sorted.last / 1000),
    'p50_ms': _r(_at(.5)),
    'p95_ms': _r(_at(.95)),
  };

  /// One line for the summary.
  String line(String name) =>
      '${name.padRight(16)} avg ${_avg.toStringAsFixed(1)}  '
      'max ${(_sorted.isEmpty ? 0 : _sorted.last / 1000).toStringAsFixed(1)}  '
      'p95 ${_at(.95).toStringAsFixed(1)} ms';
}

/// One run of the benchmark on [controller].
class ScanBenchmark {
  /// Creates a run that stops after [target] frames with a barcode.
  ScanBenchmark(
    this.controller, {
    this.target = 1000,
    this.warmup = 20,
    this.reader,
  });

  /// The scanner being measured.
  final ScannerController controller;

  /// The reader settings of the run, saved with the result.
  final Object? reader;

  /// Frames with a barcode to collect.
  final int target;

  /// Frames ignored at the start.
  final int warmup;

  final List<ScannerFrameSample> _found = <ScannerFrameSample>[];
  final List<int> _build = <int>[];
  final List<int> _raster = <int>[];
  int _frames = 0;
  int _dropped = 0;
  int _skipped = 0;
  Size? _frameSize;
  final Stopwatch _clock = Stopwatch();
  StreamSubscription<ScannerFrameSample>? _samples;
  final Completer<Map<String, Object?>?> _done =
      Completer<Map<String, Object?>?>();

  /// Frames with a barcode so far.
  int get collected => _found.length;

  void _onTimings(List<FrameTiming> timings) {
    if (!_clock.isRunning) {
      return;
    }
    for (final FrameTiming t in timings) {
      _build.add(t.buildDuration.inMicroseconds);
      _raster.add(t.rasterDuration.inMicroseconds);
    }
  }

  /// Runs until [target] frames with a barcode were decoded; `null` when
  /// [cancel] stopped it.
  Future<Map<String, Object?>?> run() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _samples = controller.frameSamples.listen((ScannerFrameSample s) {
      if (_skipped < warmup) {
        _skipped++;
        return;
      }
      _clock.start();
      _frames++;
      _dropped += s.dropped;
      _frameSize = s.frameSize;
      if (s.found) {
        _found.add(s);
      }
      if (_found.length >= target) {
        _clock.stop();
        unawaited(_samples?.cancel());
        _samples = null;
        _finish();
      }
    });
    return _done.future;
  }

  /// Stops without a result: [run] completes with `null`.
  void cancel() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    unawaited(_samples?.cancel());
    _samples = null;
    _clock.stop();
    if (!_done.isCompleted) {
      _done.complete(null);
    }
  }

  void _finish() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    final double seconds = _clock.elapsedMicroseconds / 1e6;
    final Stats latency = Stats(<int>[
      for (final ScannerFrameSample s in _found) s.latencyMicros,
    ]);
    final Stats engine = Stats(<int>[
      for (final ScannerFrameSample s in _found) s.engineMicros,
    ]);
    final Stats build = Stats(_build);
    final Stats raster = Stats(_raster);
    final int janky = <int>[
      for (int i = 0; i < _build.length; i++)
        if (_build[i] + _raster[i] > 16667) i,
    ].length;
    final int delivered = _frames + _dropped;
    final Size? frame = _frameSize;
    final Map<String, Object?> result = <String, Object?>{
      'date': DateTime.now().toIso8601String(),
      'device': _device(),
      'platform': kIsWeb
          ? 'web${kIsWasm ? ' (wasm)' : ''}'
          : defaultTargetPlatform.name,
      'build': kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
      'pipeline': pipelineName,
      'frame': frame == null
          ? null
          : '${frame.width.toInt()}x${frame.height.toInt()}',
      'scan_window': 'LTWH 0.2, 0.1, 0.6, 0.8 of the preview',
      'reader': reader,
      'found_frames': _found.length,
      'all_frames': _frames,
      'camera_frames': kIsWeb ? null : delivered,
      'camera_fps': kIsWeb ? null : (delivered / seconds).toStringAsFixed(1),
      'skipped_frames': kIsWeb ? null : _dropped,
      'hit_rate': (_found.length / _frames * 100).toStringAsFixed(1),
      'decoded_frames_per_s': (_frames / seconds).toStringAsFixed(1),
      'duration_s': seconds.toStringAsFixed(1),
      'scan_latency': latency.toJson(),
      'engine': engine.toJson(),
      'ui_frames': <String, Object>{
        'count': build.n,
        'over_16ms': janky,
        'build': build.toJson(),
        'raster': raster.toJson(),
      },
      'summary': <String>[
        latency.line('scan latency'),
        engine.line('engine'),
        'decoded ${(_frames / seconds).toStringAsFixed(1)}/s'
            '${kIsWeb ? '' : ', camera ${(delivered / seconds).toStringAsFixed(1)} fps, skipped $_dropped'}',
        build.line('UI build'),
        'UI frames ${build.n}, over 16 ms: $janky',
      ],
    };
    result['saved_to'] = _save(result);
    _log(jsonEncode(result));
    _done.complete(result);
  }

  /// Prints [json] in pieces short enough for Android's log, which cuts
  /// longer lines: `[scanbench 1/3] ...`; joined, they are the JSON.
  static void _log(String json) {
    const int size = 700;
    final int parts = (json.length + size - 1) ~/ size;
    for (int i = 0; i < parts; i++) {
      final int end = math.min(json.length, (i + 1) * size);
      debugPrint(
        '[scanbench ${i + 1}/$parts] ${json.substring(i * size, end)}',
      );
    }
  }

  static String _device() {
    const String label = String.fromEnvironment('DEVICE');
    if (label.isNotEmpty) {
      return label;
    }
    return kIsWeb
        ? 'web'
        : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }

  static String? _save(Map<String, Object?> result) {
    if (kIsWeb) {
      return null;
    }
    try {
      final Directory dir = Directory(
        '${Directory.systemTemp.path}/scan_benchmarks',
      )..createSync(recursive: true);
      final String name = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final File file = File('${dir.path}/$name.json')
        ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
      return file.path;
    } on Object catch (e) {
      return 'save failed: $e';
    }
  }
}
