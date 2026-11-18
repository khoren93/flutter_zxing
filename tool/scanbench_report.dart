// Builds benchmark/BENCHMARKS.md from benchmark/scan/*.json, one row per
// run of the example's scan benchmark (example/lib/scan_benchmark.dart).
//
//   cd tool && dart run scanbench_report.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final Directory root = Directory.fromUri(Platform.script.resolve('..'));
  final Directory runs = Directory('${root.path}/benchmark/scan');
  final List<File> files =
      runs
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.endsWith('.json'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  String stats(Object? s) {
    if (s is! Map<String, Object?>) {
      return '—';
    }
    String ms(String key) => (s[key]! as num).toStringAsFixed(1);
    return '${ms('avg_ms')} / ${ms('min_ms')} / ${ms('max_ms')} / ${ms('p95_ms')}';
  }

  final List<String> rows = <String>[
    for (final File f in files)
      () {
        final Map<String, Object?> d =
            jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
        final Map<String, Object?>? ui =
            d['ui_frames'] as Map<String, Object?>?;
        final Map<String, Object?>? build =
            ui?['build'] as Map<String, Object?>?;
        final String camera = d['camera_fps'] == null
            ? '—'
            : '${d['camera_fps']} fps, skipped ${d['skipped_frames']}';
        final String uiFrames = build == null
            ? '—'
            : '${(build['avg_ms']! as num).toStringAsFixed(1)} / '
                  '${(build['max_ms']! as num).toStringAsFixed(1)}, '
                  '${ui!['over_16ms']} of ${ui['count']} over 16 ms';
        final String date = (d['date']! as String)
            .substring(0, 16)
            .replaceFirst('T', ' ');
        return '| $date | ${d['device']} | ${d['pipeline']} | ${d['frame']} | '
            '${d['found_frames']} | ${d['hit_rate']}% | ${d['decoded_frames_per_s']} | '
            '$camera | ${stats(d['scan_latency'])} | ${stats(d['engine'])} | $uiFrames | '
            '`${f.uri.pathSegments.last}` |';
      }(),
  ];

  File('${root.path}/benchmark/BENCHMARKS.md').writeAsStringSync('''
# Scan benchmarks

Camera scan timing, one row per run, to compare camera pipelines: the
prototype of 4.0 (`camera plugin 0.12 ...`), flutter_zxing 4.0, and later a
custom zero-copy camera.

How a run works: `cd example && flutter run --release -t lib/diagnostics.dart
--dart-define=DEVICE="<device name>"`, tap the speed button and hold the
phone on a QR code until 1000 frames *with a found code* are decoded (the
first 20 frames are warm-up and ignored). The result is printed in the log
in numbered pieces, `[scanbench 1/3] ...` (joined, the JSON), and saved in the app's temporary directory; put the
JSON into `benchmark/scan/` and run `dart run scanbench_report.dart` in
`tool/`.

- **Scan latency**: the camera frame reaches Dart → its barcodes are back on
  the UI isolate (copying the scan window, the hop to the engine isolate,
  decoding, the hop back). Excludes the camera's own exposure and processing
  delay: the `camera` plugin gives no capture time.
- **Engine**: decoding time inside the engine isolate.
- **Camera**: frames the camera delivered per second, and how many were
  skipped because the engine was still busy.
- **UI frames**: Flutter frame build time avg / max while scanning, and how
  many frames took over 16 ms (build + raster).
- Times are **avg / min / max / p95** in ms. Scan window: 60% x 80% in the
  centre, release build, portrait.

| Date | Device | Pipeline | Frame | Found frames | Hit rate | Decodes/s | Camera | Scan latency, ms | Engine, ms | UI frames (build ms avg / max) | Raw |
|---|---|---|---|---|---|---|---|---|---|---|---|
${rows.join('\n')}
''');
  stdout.writeln('benchmark/BENCHMARKS.md: ${rows.length} run(s)');
}
