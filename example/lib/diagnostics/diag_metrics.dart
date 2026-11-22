// The numbers of the diagnostics page: decoding from the scanner's frame
// samples, CPU and memory from the process, frame times from Flutter.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
// The frame samples are not public API.
// ignore: implementation_imports
import 'package:flutter_zxing/src/engine/engine_protocol.dart'
    show EngineBarcodeDetails;
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug, ScannerFrameSample;

import 'cpu_usage_stub.dart' if (dart.library.ffi) 'cpu_usage.dart';

/// The value at [p] (0 to 1) of [sorted], 0 without values.
int percentile(List<int> sorted, double p) =>
    sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * p).round()];

/// One decoded frame, as the numbers need it.
@immutable
final class DiagSample {
  /// Creates a sample.
  const DiagSample({
    required this.atMicros,
    required this.engineMicros,
    required this.latencyMicros,
    required this.found,
    this.failed = 0,
    this.dropped = 0,
  });

  /// When it was decoded.
  final int atMicros;
  final int engineMicros;
  final int latencyMicros;
  final bool found;
  final int failed;
  final int dropped;
}

/// The numbers at one moment.
@immutable
final class DiagSnapshot {
  /// Creates a snapshot.
  const DiagSnapshot({
    this.reads = 0,
    this.withCodePercent = 0,
    this.decodeP50Ms = 0,
    this.decodeP95Ms = 0,
    this.decodeMaxMs = 0,
    this.latencyP50Ms = 0,
    this.fps = 0,
    this.dropped = 0,
    this.failed = 0,
    this.firstReadMs,
    this.cpuPercent,
    this.cores = 0,
    this.memoryMb,
    this.milliwatts,
    this.uiP95Ms = 0,
    this.rasterP95Ms = 0,
    this.slowFramesPercent = 0,
    this.frame = Size.zero,
    this.window,
    this.lineCount,
    this.uec,
    this.dataMask,
    this.threads = const <(String, double)>[],
    this.cameraRestarts = 0,
    this.engineRestarts = 0,
  });

  /// The numbers of [samples], the decoded frames of a stretch of time.
  factory DiagSnapshot.of(List<DiagSample> samples, {int? firstReadMs}) {
    if (samples.isEmpty) {
      return DiagSnapshot(firstReadMs: firstReadMs);
    }
    final List<int> engine =
        samples.map((DiagSample s) => s.engineMicros).toList()..sort();
    final List<int> latency =
        samples.map((DiagSample s) => s.latencyMicros).toList()..sort();
    final int last = samples.last.atMicros;
    final int recent = samples
        .where((DiagSample s) => last - s.atMicros < 1000000)
        .length;
    return DiagSnapshot(
      reads: samples.length,
      withCodePercent:
          samples.where((DiagSample s) => s.found).length /
          samples.length *
          100,
      decodeP50Ms: percentile(engine, 0.5) / 1000,
      decodeP95Ms: percentile(engine, 0.95) / 1000,
      decodeMaxMs: engine.last / 1000,
      latencyP50Ms: percentile(latency, 0.5) / 1000,
      fps: recent.toDouble(),
      dropped: samples.fold(0, (int n, DiagSample s) => n + s.dropped),
      failed: samples.fold(0, (int n, DiagSample s) => n + s.failed),
      firstReadMs: firstReadMs,
    );
  }

  final int reads;
  final double withCodePercent;
  final double decodeP50Ms;
  final double decodeP95Ms;
  final double decodeMaxMs;
  final double latencyP50Ms;

  /// Frames decoded in the last second.
  final double fps;
  final int dropped;

  /// Codes found but not decoded.
  final int failed;

  /// From the last change of the settings to the first code read.
  final int? firstReadMs;

  /// Of one core: 100 is one core busy all the time.
  final double? cpuPercent;
  final int cores;
  final double? memoryMb;

  /// The process's CPU energy over the last second, in milliwatts (iOS and
  /// macOS): unlike [cpuPercent] it does not grow when the system moves
  /// the work to slower, thriftier cores.
  final double? milliwatts;
  final double uiP95Ms;
  final double rasterP95Ms;

  /// Flutter frames that took longer than 16 ms.
  final double slowFramesPercent;
  final Size frame;
  final Size? window;

  /// Scan lines that agreed on the last linear code.
  final int? lineCount;

  /// The error correction left unused on the last code, 0 to 1.
  final double? uec;
  final int? dataMask;

  /// The busiest threads, by share of one core (iOS and macOS).
  final List<(String, double)> threads;
  final int cameraRestarts;
  final int engineRestarts;

  /// CPU as a share of the whole device.
  double? get devicePercent {
    final double? cpu = cpuPercent;
    return cpu == null || cores == 0 ? null : cpu / cores;
  }

  /// The numbers of a saved run.
  Map<String, Object?> toJson() {
    double r(double v) => (v * 100).round() / 100;
    final double? cpu = cpuPercent;
    final double? device = devicePercent;
    final double? memory = memoryMb;
    final double? power = milliwatts;
    return <String, Object?>{
      'reads': reads,
      'withCodePercent': r(withCodePercent),
      'decodeP50Ms': r(decodeP50Ms),
      'decodeP95Ms': r(decodeP95Ms),
      'decodeMaxMs': r(decodeMaxMs),
      'latencyP50Ms': r(latencyP50Ms),
      'fps': r(fps),
      'dropped': dropped,
      'failed': failed,
      'firstReadMs': firstReadMs,
      'cpuPercent': cpu == null ? null : r(cpu),
      'devicePercent': device == null ? null : r(device),
      'memoryMb': memory == null ? null : r(memory),
      'milliwatts': power == null ? null : r(power),
      'uiP95Ms': r(uiP95Ms),
      'rasterP95Ms': r(rasterP95Ms),
      'slowFramesPercent': r(slowFramesPercent),
      'frame': '${frame.width.round()}x${frame.height.round()}',
      'cameraRestarts': cameraRestarts,
      'engineRestarts': engineRestarts,
    };
  }
}

/// Reads [key] of zxing-cpp's extra metadata, `null` if it is not there.
String? extraValue(String extra, String key) {
  if (extra.isEmpty) {
    return null;
  }
  try {
    final Object? value = (jsonDecode(extra) as Map<String, dynamic>)[key];
    return value?.toString();
  } on FormatException {
    return null;
  }
}

/// One second of CPU: the process and its threads, as shares of one core.
@immutable
final class CpuSecond {
  /// Creates a second.
  const CpuSecond(
    this.cpu,
    this.threads, [
    this.quarters = const <double>[],
    this.work,
  ]);

  /// The work of the second where the kernel counts it (iOS, macOS):
  /// `instructionsG` (billions), `cyclesG`, `milliwatts` (the process's
  /// energy over the second), `pShare` (share of CPU time on performance
  /// cores, 0 to 1), `ghz` (cycles per second of CPU time).
  final Map<String, double>? work;

  final double cpu;
  final List<(String, double)> threads;

  /// The process in each quarter of the second.
  final List<double> quarters;
}

/// Collects the numbers of a scanner, separately for A and B.
final class DiagMetrics extends ChangeNotifier {
  /// Starts measuring.
  DiagMetrics() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _cpu.sample();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), _onTick);
  }

  /// Decoded frames kept per side.
  static const int _keep = 300;

  /// Frames ignored after a switch of A and B: they were read before it.
  static const int _settle = 2;

  final CpuMeter _cpu = CpuMeter();
  final Stopwatch _clock = Stopwatch()..start();
  final Map<String, List<DiagSample>> _samples = <String, List<DiagSample>>{};
  final Map<String, int?> _firstRead = <String, int?>{};
  final Map<String, int> _changedAt = <String, int>{};
  final List<FrameTiming> _frames = <FrameTiming>[];
  late final Timer _ticker;
  StreamSubscription<ScannerFrameSample>? _subscription;
  ScannerController? _controller;

  /// Prints every CPU sample (`--dart-define=DIAG_LOG=true`).
  static const bool _log = bool.fromEnvironment('DIAG_LOG');

  final List<double> _quarters = <double>[];
  RusageCounters? _lastCounters;
  int _lastCountersWall = 0;
  Map<String, double>? _work;

  /// The work since the last call, see [CpuSecond.work].
  Map<String, double>? _sampleWork(int wall) {
    final RusageCounters? now = CpuMeter.counters;
    final RusageCounters? last = _lastCounters;
    final int span = wall - _lastCountersWall;
    _lastCounters = now;
    _lastCountersWall = wall;
    if (now == null || last == null || span <= 0) {
      return null;
    }
    final int time = now.userNs + now.systemNs - last.userNs - last.systemNs;
    final int pTime =
        now.userPNs + now.systemPNs - last.userPNs - last.systemPNs;
    final int cycles = now.cycles - last.cycles;
    double r(double v) => (v * 1000).round() / 1000;
    return <String, double>{
      'instructionsG': r((now.instructions - last.instructions) / 1e9),
      'cyclesG': r(cycles / 1e9),
      'milliwatts': r((now.energyNj - last.energyNj) / 1e6 / (span / 1e6)),
      'pShare': time <= 0 ? 0 : r(pTime / time),
      'ghz': time <= 0 ? 0 : r(cycles / time),
    };
  }

  int? _quarterProcess;
  int _quarterWall = 0;

  String _side = 'A';
  int _skip = 0;
  int _ticks = 0;
  bool _dirty = false;
  double? _cpuPercent;
  List<(String, double)> _threads = const <(String, double)>[];
  Size _frame = Size.zero;
  Size? _window;
  int? _lineCount;
  double? _uec;
  int? _dataMask;

  /// The side being measured.
  String get side => _side;

  final StreamController<CpuSecond> _seconds =
      StreamController<CpuSecond>.broadcast(sync: true);

  /// The CPU of every second, as it is measured.
  Stream<CpuSecond> get seconds => _seconds.stream;

  /// Whether listeners stop hearing about new numbers: nothing on screen
  /// needs them. Measuring and the log go on.
  bool quiet = false;

  /// Measures [controller] from now on.
  void attach(ScannerController controller) {
    unawaited(_subscription?.cancel());
    _controller = controller;
    _subscription = controller.frameSamples.listen(_onSample);
  }

  /// Starts [side] anew: its settings changed.
  void reset([String? side]) {
    final String s = side ?? _side;
    _samples.remove(s);
    _firstRead.remove(s);
    _changedAt[s] = _clock.elapsedMilliseconds;
    _skip = _settle;
    _dirty = true;
  }

  /// Measures [side] from the next frames on.
  void switchTo(String side) {
    _side = side;
    _skip = _settle;
  }

  void _onSample(ScannerFrameSample s) {
    _frame = s.frameSize;
    _window = s.crop?.size;
    if (_skip > 0) {
      _skip--;
      return;
    }
    final List<DiagSample> samples = _samples[_side] ??= <DiagSample>[];
    samples.add(
      DiagSample(
        atMicros: _clock.elapsedMicroseconds,
        engineMicros: s.engineMicros,
        latencyMicros: s.latencyMicros,
        found: s.found,
        failed: s.failed,
        dropped: s.dropped,
      ),
    );
    if (samples.length > _keep) {
      samples.removeAt(0);
    }
    if (s.found) {
      _firstRead[_side] ??=
          _clock.elapsedMilliseconds - (_changedAt[_side] ?? 0);
    }
    if (s.details.isNotEmpty) {
      final EngineBarcodeDetails d = s.details.first;
      _lineCount = d.lineCount > 0 ? d.lineCount : null;
      _uec = double.tryParse(extraValue(d.extra, 'UEC') ?? '');
      _dataMask = int.tryParse(extraValue(d.extra, 'DataMask') ?? '');
    }
    _dirty = true;
  }

  void _onTimings(List<FrameTiming> timings) {
    _frames.addAll(timings);
    if (_frames.length > 240) {
      _frames.removeRange(0, _frames.length - 240);
    }
  }

  void _onTick(Timer _) {
    // Each 250 ms quarter on its own, to see what the 1 s average hides.
    final int? process = _cpu.processMicros;
    final int wall = _clock.elapsedMicroseconds;
    final int? lastProcess = _quarterProcess;
    if (process != null && lastProcess != null && wall > _quarterWall) {
      _quarters.add((process - lastProcess) / (wall - _quarterWall) * 100);
    }
    _quarterProcess = process;
    _quarterWall = wall;
    if (++_ticks % 4 == 0) {
      final Stopwatch meter = Stopwatch()..start();
      _work = _sampleWork(wall);
      _cpuPercent = _cpu.sample();
      _threads = _cpu.sampleThreads() ?? const <(String, double)>[];
      meter.stop();
      final double? cpu = _cpuPercent;
      if (cpu != null && _seconds.hasListener) {
        _seconds.add(
          CpuSecond(cpu, _threads, List<double>.of(_quarters), _work),
        );
      }
      if (_log) {
        _printSample(meter.elapsedMicroseconds);
      }
      _quarters.clear();
      _dirty = true;
    }
    if (_dirty && !quiet) {
      _dirty = false;
      notifyListeners();
    }
  }

  /// Prints the CPU of the last second for comparison with the system
  /// profilers (R4-01): process, its 250 ms quarters, the meter's own time
  /// and the threads.
  void _printSample(int meterMicros) {
    String f(double v) => v.toStringAsFixed(1);
    final double? cpu = _cpuPercent;
    debugPrint(
      'DIAGCPU t=${(_clock.elapsedMilliseconds / 1000).toStringAsFixed(2)}'
      ' cpu=${cpu == null ? '-' : f(cpu)}'
      ' q=${_quarters.map(f).join(',')}'
      ' meter=${meterMicros}us'
      ' work=${jsonEncode(_work)}'
      ' reads=${_samples[_side]?.where((DiagSample s) => _clock.elapsedMicroseconds - s.atMicros < 1000000).length ?? 0}'
      ' thr=${_threads.map(((String, double) t) => '${t.$1}:${f(t.$2)}').join('|')}',
    );
  }

  /// The numbers of [side], by default the one being measured.
  DiagSnapshot snapshot([String? side]) {
    final String s = side ?? _side;
    final DiagSnapshot d = DiagSnapshot.of(
      _samples[s] ?? const <DiagSample>[],
      firstReadMs: _firstRead[s],
    );
    final List<int> ui = <int>[
      for (final FrameTiming f in _frames) f.buildDuration.inMicroseconds,
    ]..sort();
    final List<int> raster = <int>[
      for (final FrameTiming f in _frames) f.rasterDuration.inMicroseconds,
    ]..sort();
    final int slow = _frames
        .where(
          (FrameTiming f) =>
              math.max(
                f.buildDuration.inMicroseconds,
                f.rasterDuration.inMicroseconds,
              ) >
              16000,
        )
        .length;
    final int? resident = CpuMeter.residentBytes;
    return DiagSnapshot(
      reads: d.reads,
      withCodePercent: d.withCodePercent,
      decodeP50Ms: d.decodeP50Ms,
      decodeP95Ms: d.decodeP95Ms,
      decodeMaxMs: d.decodeMaxMs,
      latencyP50Ms: d.latencyP50Ms,
      fps: d.fps,
      dropped: d.dropped,
      failed: d.failed,
      firstReadMs: d.firstReadMs,
      cpuPercent: _cpuPercent,
      cores: CpuMeter.cores,
      memoryMb: resident == null ? null : resident / 1024 / 1024,
      milliwatts: _work?['milliwatts'],
      uiP95Ms: percentile(ui, 0.95) / 1000,
      rasterP95Ms: percentile(raster, 0.95) / 1000,
      slowFramesPercent: _frames.isEmpty ? 0 : slow / _frames.length * 100,
      frame: _frame,
      window: _window,
      lineCount: _lineCount,
      uec: _uec,
      dataMask: _dataMask,
      threads: _threads,
      cameraRestarts: _controller?.cameraRestarts ?? 0,
      engineRestarts: _controller?.engineRestarts ?? 0,
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    unawaited(_seconds.close());
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
