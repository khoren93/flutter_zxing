// The load ladder (R4-02): steps that each add one layer of the scanner,
// from an empty screen to the demo's template, measured one after the other
// so that each layer's cost is the difference to the step before.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
// The frame samples are not public API.
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/camera/camera_source.dart'
    show CameraLens;
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug, ScannerFrameSample;
import 'package:path_provider/path_provider.dart';

import 'cpu_usage_stub.dart' if (dart.library.ffi) 'cpu_usage.dart';
import 'diag_metrics.dart';
import 'diag_runs.dart';
import 'ios_camera_numbers.dart';

/// One step of the ladder.
enum LadderStep {
  l0('Empty page, no animations'),
  l1('L0 and the numbers panel'),
  l2('Camera preview, no frame stream'),
  l3('L2 and the frame stream, empty handler'),
  l4('L3 and the scan window copied to native memory'),
  l5('L4 and the engine, minimal options'),
  l6('L5 with ReaderOptions.camera()'),
  l7('ScannerController alone, no widgets'),
  l8('L7 and BarcodeScanner, no overlay'),
  l9('L8 and the scan window overlay'),
  l10('L9 and blurred glass'),
  l11('The demo template');

  const LadderStep(this.description);

  final String description;

  String get label => name.toUpperCase();

  bool get panel => index >= LadderStep.l1.index;
  bool get rawCamera =>
      index >= LadderStep.l2.index && index <= LadderStep.l6.index;
  bool get scanner => index >= LadderStep.l7.index;

  static LadderStep? parse(String s) {
    final String n = s.toLowerCase();
    for (final LadderStep step in values) {
      if (step.name == n) {
        return step;
      }
    }
    return null;
  }
}

/// The value at [p] (0 to 1) of [sorted] numbers, 0 without values.
double _pct(List<num> sorted, double p) =>
    sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * p).round()].toDouble();

double _r(double v) => (v * 10).round() / 10;

/// Collects the numbers of one step while it is measured.
final class _Recorder {
  _Recorder(this.step, this.repeat, this.scene)
    : thermalStart = CpuMeter.thermalState;

  final LadderStep step;
  final int repeat;
  final String scene;
  final int? thermalStart;
  final Stopwatch clock = Stopwatch()..start();
  final List<CpuSecond> seconds = <CpuSecond>[];
  final List<FrameTiming> frames = <FrameTiming>[];
  final List<int> readMicros = <int>[];
  final List<int> engineMicros = <int>[];
  final List<int> rss = <int>[];
  int found = 0;
  int dropped = 0;
  int cameraFrames = 0;

  void onSecond(CpuSecond s) {
    seconds.add(s);
    final int? r = CpuMeter.residentBytes;
    if (r != null) {
      rss.add(r);
    }
  }

  void onRead(int micros, {int? engine, bool hit = false, int lost = 0}) {
    readMicros.add(micros);
    if (engine != null) {
      engineMicros.add(engine);
    }
    if (hit) {
      found++;
    }
    dropped += lost;
  }

  /// The means of [CpuSecond.work] over the seconds that have it.
  Map<String, double>? _work() {
    final List<Map<String, double>> w = <Map<String, double>>[
      for (final CpuSecond s in seconds) ?s.work,
    ];
    if (w.isEmpty) {
      return null;
    }
    return <String, double>{
      for (final String key in w.first.keys)
        key:
            (w
                        .map((Map<String, double> m) => m[key] ?? 0)
                        .reduce((double a, double b) => a + b) /
                    w.length *
                    1000)
                .round() /
            1000,
    };
  }

  Map<String, Object?> finish() {
    final double span = clock.elapsedMicroseconds / 1e6;
    final List<double> cpu = seconds.map((CpuSecond s) => s.cpu).toList()
      ..sort();
    final Map<String, double> threads = <String, double>{};
    for (final CpuSecond s in seconds) {
      for (final (String name, double v) in s.threads) {
        final String key = switch (name) {
          'main' => 'main',
          'io.flutter.1.raster' => 'raster',
          'DartWorker' => 'worker',
          'unnamed' => 'unnamed',
          'io.flutter.1.profiler' ||
          'Dart Profiler ThreadInterrupter' => 'profiler',
          _ => 'other',
        };
        threads[key] = (threads[key] ?? 0) + v / seconds.length;
      }
    }
    final List<int> reads = List<int>.of(readMicros)..sort();
    final List<int> engine = List<int>.of(engineMicros)..sort();
    final List<int> ui = <int>[
      for (final FrameTiming f in frames) f.buildDuration.inMicroseconds,
    ]..sort();
    final List<int> raster = <int>[
      for (final FrameTiming f in frames) f.rasterDuration.inMicroseconds,
    ]..sort();
    final int slow = frames
        .where(
          (FrameTiming f) =>
              math.max(
                f.buildDuration.inMicroseconds,
                f.rasterDuration.inMicroseconds,
              ) >
              16000,
        )
        .length;
    return <String, Object?>{
      'step': step.label,
      'repeat': repeat,
      'scene': scene,
      'seconds': seconds.length,
      'cpuMedian': _r(_pct(cpu, 0.5)),
      'cpuMean': _r(
        cpu.isEmpty
            ? 0
            : cpu.reduce((double a, double b) => a + b) / cpu.length,
      ),
      'cpuP95': _r(_pct(cpu, 0.95)),
      'cpuMax': _r(cpu.isEmpty ? 0 : cpu.last),
      'threads': <String, double>{
        for (final MapEntry<String, double> e in threads.entries)
          e.key: _r(e.value),
      },
      'readsPerSecond': _r(reads.length / span),
      'cameraFps': _r(
        (step.scanner ? reads.length + dropped : cameraFrames) / span,
      ),
      'dropped': dropped,
      'foundPercent': _r(reads.isEmpty ? 0 : found / reads.length * 100),
      'readP50Ms': _r(_pct(reads, 0.5) / 1000),
      'readP95Ms': _r(_pct(reads, 0.95) / 1000),
      'readMaxMs': _r(reads.isEmpty ? 0 : reads.last / 1000),
      'engineP50Ms': _r(_pct(engine, 0.5) / 1000),
      'engineP95Ms': _r(_pct(engine, 0.95) / 1000),
      'frames': frames.length,
      'uiP95Ms': _r(_pct(ui, 0.95) / 1000),
      'rasterP95Ms': _r(_pct(raster, 0.95) / 1000),
      'slowFramesPercent': _r(frames.isEmpty ? 0 : slow / frames.length * 100),
      'rssMeanMb': _r(
        rss.isEmpty
            ? 0
            : rss.reduce((int a, int b) => a + b) / rss.length / 1048576,
      ),
      'rssMaxMb': _r(rss.isEmpty ? 0 : rss.reduce(math.max) / 1048576),
      'thermal': <int?>[thermalStart, CpuMeter.thermalState],
      'work': _work(),
    };
  }
}

/// What happened in one second of a spike watch (R4-03).
final class _WatchSecond {
  int reads = 0;
  int found = 0;
  int dropped = 0;
  int readMax = 0;
  int engineMax = 0;
  int uiFrames = 0;
  int buildMax = 0;
  int rasterMax = 0;
  int cameraSamples = 0;
  bool focusing = false;
  bool exposing = false;
  bool balancing = false;
  double isoMin = double.infinity;
  double isoMax = 0;
  double exposureMin = double.infinity;
  double exposureMax = 0;
  double maxFps = 0;
  double lensMin = double.infinity;
  double lensMax = 0;

  void onCamera(CameraNumbers n) {
    cameraSamples++;
    focusing |= n.adjustingFocus;
    exposing |= n.adjustingExposure;
    balancing |= n.adjustingWhiteBalance;
    isoMin = math.min(isoMin, n.iso);
    isoMax = math.max(isoMax, n.iso);
    exposureMin = math.min(exposureMin, n.exposureMs);
    exposureMax = math.max(exposureMax, n.exposureMs);
    maxFps = n.maxFps;
    lensMin = math.min(lensMin, n.lensPosition);
    lensMax = math.max(lensMax, n.lensPosition);
  }

  Map<String, Object?> camera() => cameraSamples == 0
      ? <String, Object?>{}
      : <String, Object?>{
          'iso': <double>[_r(isoMin), _r(isoMax)],
          'expMs': <double>[
            (exposureMin * 100).round() / 100,
            (exposureMax * 100).round() / 100,
          ],
          'maxFps': _r(maxFps),
          'lens': <double>[
            (lensMin * 1000).round() / 1000,
            (lensMax * 1000).round() / 1000,
          ],
          'af': focusing,
          'ae': exposing,
          'awb': balancing,
        };
}

/// malloc and free of the C library, for the copy of step L4.
final class _Native {
  _Native._(DynamicLibrary lib)
    : malloc = lib
          .lookupFunction<
            Pointer<Uint8> Function(IntPtr),
            Pointer<Uint8> Function(int)
          >('malloc'),
      free = lib
          .lookupFunction<
            Void Function(Pointer<Uint8>),
            void Function(Pointer<Uint8>)
          >('free');

  static final _Native instance = _Native._(DynamicLibrary.process());

  final Pointer<Uint8> Function(int) malloc;
  final void Function(Pointer<Uint8>) free;
}

/// The ladder, full screen over the diagnostics page.
class LadderPage extends StatefulWidget {
  /// Creates the page.
  const LadderPage({required this.metrics, super.key});

  /// Where the CPU of every second comes from.
  final DiagMetrics metrics;

  @override
  State<LadderPage> createState() => LadderPageState();
}

/// The ladder's state; the diagnostics page drives it from the VM service.
class LadderPageState extends State<LadderPage> {
  LadderStep _step = LadderStep.l0;
  int _generation = 0;

  cam.CameraController? _camera;
  cam.CameraImage? _latest;
  cam.CameraImage? _lastDone;
  Completer<void>? _frameWaiter;

  ScannerController? _scanner;
  StreamSubscription<ScannerFrameSample>? _samples;

  StreamSubscription<CpuSecond>? _seconds;
  _Recorder? _recorder;
  final ValueNotifier<String> _panel = ValueNotifier<String>('');
  CpuSecond? _lastSecond;
  final List<int> _recentReads = <int>[];

  int _run = 0;
  bool _running = false;
  String _progress = '';
  final List<Map<String, Object?>> _results = <Map<String, Object?>>[];
  String? _savedTo;

  /// The step on screen.
  LadderStep get step => _step;

  /// Whether an automatic run is going on.
  bool get running => _running;

  /// The results of the last automatic run.
  List<Map<String, Object?>> get results => _results;

  /// What the run is doing.
  String get progress => _progress;

  @override
  void initState() {
    super.initState();
    _seconds = widget.metrics.seconds.listen(_onSecond);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    _run++;
    _cameraTimer?.cancel();
    _generation++;
    unawaited(_seconds?.cancel());
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    unawaited(_closeCamera());
    unawaited(_closeScanner());
    _panel.dispose();
    super.dispose();
  }

  void _onSecond(CpuSecond s) {
    _lastSecond = s;
    _recorder?.onSecond(s);
    _watchTick(s);
    _updatePanel();
  }

  void _onTimings(List<FrameTiming> timings) {
    _recorder?.frames.addAll(timings);
    final _WatchSecond? w = _watchSecond;
    if (w != null) {
      for (final FrameTiming f in timings) {
        w.uiFrames++;
        w.buildMax = math.max(w.buildMax, f.buildDuration.inMicroseconds);
        w.rasterMax = math.max(w.rasterMax, f.rasterDuration.inMicroseconds);
      }
    }
  }

  void _onRead(int micros, {int? engine, bool hit = false, int lost = 0}) {
    _recorder?.onRead(micros, engine: engine, hit: hit, lost: lost);
    final _WatchSecond? w = _watchSecond;
    if (w != null) {
      w.reads++;
      if (hit) {
        w.found++;
      }
      w.dropped += lost;
      w.readMax = math.max(w.readMax, micros);
      w.engineMax = math.max(w.engineMax, engine ?? 0);
    }
    _recentReads.add(micros);
    if (_recentReads.length > 60) {
      _recentReads.removeAt(0);
    }
  }

  void _updatePanel() {
    final CpuSecond? s = _lastSecond;
    if (s == null || !_step.panel) {
      return;
    }
    final List<int> reads = List<int>.of(_recentReads)..sort();
    _panel.value = <String>[
      '${_step.label}  ${_step.description}',
      'CPU ${s.cpu.toStringAsFixed(1)} %  '
          '${s.threads.take(4).map(((String, double) t) => '${t.$1} ${t.$2.toStringAsFixed(1)}').join(' · ')}',
      'read p50 ${(_pct(reads, 0.5) / 1000).toStringAsFixed(1)} ms  '
          'p95 ${(_pct(reads, 0.95) / 1000).toStringAsFixed(1)} ms',
      if (_progress.isNotEmpty) _progress,
    ].join('\n');
  }

  /// Shows [next]: opens and closes what the step needs.
  Future<void> setStep(LadderStep next) async {
    final int generation = ++_generation;
    _recentReads.clear();
    if (!next.rawCamera) {
      await _closeCamera();
    }
    if (!next.scanner) {
      await _closeScanner();
    }
    if (!mounted || generation != _generation) {
      return;
    }
    setState(() => _step = next);
    if (next.rawCamera) {
      await _openCamera();
      final cam.CameraController? camera = _camera;
      if (camera == null || generation != _generation) {
        return;
      }
      final bool stream = next.index >= LadderStep.l3.index;
      if (stream && !camera.value.isStreamingImages) {
        await camera.startImageStream(_onImage);
      } else if (!stream && camera.value.isStreamingImages) {
        await camera.stopImageStream();
      }
      if (next.index >= LadderStep.l4.index) {
        unawaited(_work(generation, next));
      }
    }
    if (next.scanner) {
      final ScannerController scanner = _scanner ??= _newScanner();
      if (next == LadderStep.l7) {
        await scanner.start();
      }
    }
  }

  ScannerController _newScanner() {
    final ScannerController c = ScannerController();
    _samples = c.frameSamples.listen(
      (ScannerFrameSample s) => _onRead(
        s.roundTripMicros,
        engine: s.engineMicros,
        hit: s.found,
        lost: s.dropped,
      ),
    );
    return c;
  }

  Future<void> _closeScanner() async {
    final ScannerController? scanner = _scanner;
    _scanner = null;
    await _samples?.cancel();
    _samples = null;
    if (scanner != null) {
      if (mounted) {
        setState(() {}); // the scanner leaves the tree before it goes
      }
      await SchedulerBinding.instance.endOfFrame;
      scanner.dispose();
    }
  }

  Future<void> _openCamera() async {
    if (_camera != null) {
      return;
    }
    final List<cam.CameraDescription> cameras = await cam.availableCameras();
    final cam.CameraDescription back = cameras.firstWhere(
      (cam.CameraDescription c) =>
          c.lensDirection == cam.CameraLensDirection.back &&
          c.lensType == cam.CameraLensType.wide,
      orElse: () => cameras.firstWhere(
        (cam.CameraDescription c) =>
            c.lensDirection == cam.CameraLensDirection.back,
        orElse: () => cameras.first,
      ),
    );
    // As the scanner opens it: hd, Y plane first.
    final cam.CameraController camera = cam.CameraController(
      back,
      cam.ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: cam.ImageFormatGroup.yuv420,
    );
    await camera.initialize();
    if (Platform.isIOS) {
      await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
    }
    if (!mounted || !_step.rawCamera) {
      await camera.dispose();
      return;
    }
    setState(() => _camera = camera);
  }

  Future<void> _closeCamera() async {
    final cam.CameraController? camera = _camera;
    if (camera == null) {
      return;
    }
    _camera = null;
    _latest = null;
    _lastDone = null;
    if (mounted) {
      setState(() {});
    }
    await SchedulerBinding.instance.endOfFrame;
    await camera.dispose();
  }

  void _onImage(cam.CameraImage image) {
    _latest = image;
    _recorder?.cameraFrames++;
    final Completer<void>? waiter = _frameWaiter;
    _frameWaiter = null;
    waiter?.complete();
  }

  /// The centered 70 % square of the scanner's default scan window, in
  /// frame pixels.
  static Rect _window(int width, int height) {
    final double side = math.min(width, height) * 0.7;
    return Rect.fromLTWH(
      ((width - side) / 2).floorToDouble(),
      ((height - side) / 2).floorToDouble(),
      side.floorToDouble(),
      side.floorToDouble(),
    );
  }

  /// Steps L4 to L6: each new frame is copied (L4) or read (L5, L6), one at
  /// a time, like the scanner's loop.
  Future<void> _work(int generation, LadderStep step) async {
    const BarcodeReader minimal = BarcodeReader(
      options: ReaderOptions(
        tryHarder: false,
        tryRotate: false,
        tryInvert: false,
        tryDownscale: false,
      ),
    );
    const BarcodeReader camera = BarcodeReader(options: ReaderOptions.camera());
    while (generation == _generation && mounted) {
      final cam.CameraImage? image = _latest;
      if (image == null || identical(image, _lastDone)) {
        await (_frameWaiter ??= Completer<void>()).future;
        continue;
      }
      _lastDone = image;
      final cam.Plane y = image.planes.first;
      final Rect crop = _window(image.width, image.height);
      final Stopwatch clock = Stopwatch()..start();
      if (step == LadderStep.l4) {
        _copy(y.bytes, y.bytesPerRow, crop);
        _onRead(clock.elapsedMicroseconds);
        continue;
      }
      final PixelBuffer pixels = PixelBuffer(
        y.bytes,
        width: image.width,
        height: image.height,
        rowStride: y.bytesPerRow,
        crop: crop,
      );
      final Barcode? read = await (step == LadderStep.l5 ? minimal : camera)
          .readPixels(pixels);
      if (generation == _generation) {
        _onRead(clock.elapsedMicroseconds, hit: read != null);
      }
    }
  }

  /// Copies [crop] of a frame into fresh native memory and frees it, as
  /// the engine's readPixels does before it hands the frame over.
  static void _copy(Uint8List src, int stride, Rect crop) {
    final int w = crop.width.toInt();
    final int h = crop.height.toInt();
    final Pointer<Uint8> p = _Native.instance.malloc(w * h);
    final Uint8List dst = p.asTypedList(w * h);
    for (int y = 0; y < h; y++) {
      final int from = (crop.top.toInt() + y) * stride + crop.left.toInt();
      dst.setRange(y * w, (y + 1) * w, src, from);
    }
    _Native.instance.free(p);
  }

  /// Runs [steps] [repeats] times over (the whole ladder each time, so heat
  /// spreads over every step), each [warmup] then [measure] long. The
  /// results print to the log as `DIAGLADDER` lines and go to a JSON file.
  Future<void> run({
    List<LadderStep> steps = LadderStep.values,
    Duration warmup = const Duration(seconds: 10),
    Duration measure = const Duration(seconds: 60),
    int repeats = 3,
    String scene = 'A',
  }) async {
    final int run = ++_run;
    setState(() {
      _running = true;
      _results.clear();
      _savedTo = null;
    });
    final Stopwatch total = Stopwatch()..start();
    final int count = steps.length * repeats;
    int done = 0;
    for (int r = 1; r <= repeats && run == _run; r++) {
      for (final LadderStep step in steps) {
        if (run != _run || !mounted) {
          break;
        }
        _progress =
            'run ${done + 1}/$count: ${step.label} (repeat $r, scene $scene)';
        await setStep(step);
        await Future<void>.delayed(warmup);
        if (run != _run || !mounted) {
          break;
        }
        _recorder = _Recorder(step, r, scene);
        await Future<void>.delayed(measure);
        final _Recorder? recorder = _recorder;
        _recorder = null;
        if (recorder == null || run != _run) {
          break;
        }
        final Map<String, Object?> result = recorder.finish();
        _results.add(result);
        debugPrint('DIAGLADDER ${jsonEncode(result)}');
        done++;
      }
    }
    if (run != _run || !mounted) {
      return;
    }
    await setStep(LadderStep.l0);
    _progress = '';
    final String? saved = await _save(scene, total.elapsed);
    if (!mounted) {
      return;
    }
    setState(() {
      _running = false;
      _savedTo = saved;
    });
    debugPrint('DIAGLADDER done ${_results.length} steps in ${total.elapsed}');
  }

  // --- spike watch (R4-03) ---------------------------------------------------

  _WatchSecond? _watchSecond;
  final Stopwatch _watchClock = Stopwatch();
  final List<Map<String, Object?>> _watchRows = <Map<String, Object?>>[];
  Timer? _cameraTimer;
  List<cam.CameraDescription>? _cameras;
  final Map<String, IosCameraNumbers?> _cameraNumbers =
      <String, IosCameraNumbers?>{};

  /// The camera in use: the plugin's for L2 to L6, the scanner's lens after.
  String? _cameraName() {
    final cam.CameraController? camera = _camera;
    if (camera != null) {
      return camera.description.name;
    }
    final ScannerController? scanner = _scanner;
    final List<cam.CameraDescription>? cameras = _cameras;
    if (scanner == null || cameras == null) {
      return null;
    }
    final cam.CameraLensType type = switch (scanner.lensSample.lens) {
      CameraLens.main => cam.CameraLensType.wide,
      CameraLens.ultraWide => cam.CameraLensType.ultraWide,
      CameraLens.telephoto => cam.CameraLensType.telephoto,
    };
    for (final cam.CameraDescription c in cameras) {
      if (c.lensDirection == cam.CameraLensDirection.back &&
          c.lensType == type) {
        return c.name;
      }
    }
    return null;
  }

  void _sampleCamera() {
    final _WatchSecond? w = _watchSecond;
    final String? name = _cameraName();
    if (w == null || name == null) {
      return;
    }
    final IosCameraNumbers? numbers = _cameraNumbers.putIfAbsent(
      name,
      () => IosCameraNumbers.open(name),
    );
    if (numbers != null) {
      w.onCamera(numbers.read());
    }
  }

  void _watchTick(CpuSecond s) {
    final _WatchSecond? w = _watchSecond;
    if (w == null) {
      return;
    }
    _watchSecond = _WatchSecond();
    String? lens;
    if (_scanner case final ScannerController scanner?) {
      lens = scanner.lensSample.lens.name;
    }
    final int? rss = CpuMeter.residentBytes;
    final Map<String, Object?> row = <String, Object?>{
      't': _r(_watchClock.elapsedMilliseconds / 1000),
      'cpu': _r(s.cpu),
      'q': s.quarters.map(_r).toList(),
      'thr': <String, double>{
        for (final (String name, double v) in s.threads)
          if (v >= 0.1) name: _r(v),
      },
      'reads': w.reads,
      'found': w.found,
      'dropped': w.dropped,
      'readMaxMs': _r(w.readMax / 1000),
      'engineMaxMs': _r(w.engineMax / 1000),
      'uiFrames': w.uiFrames,
      'buildMaxMs': _r(w.buildMax / 1000),
      'rasterMaxMs': _r(w.rasterMax / 1000),
      'thermal': CpuMeter.thermalState,
      'work': ?s.work,
      'rssMb': rss == null ? null : _r(rss / 1048576),
      'lens': ?lens,
      'cam': w.camera(),
    };
    _watchRows.add(row);
    debugPrint('DIAGSEC ${jsonEncode(row)}');
  }

  /// Holds [step] for [length] after [warmup] and logs every second of it
  /// as a `DIAGSEC` line, for the spike catcher on the Mac.
  Future<void> watch({
    required LadderStep step,
    Duration warmup = const Duration(seconds: 10),
    Duration length = const Duration(minutes: 10),
    String scene = 'B',
  }) async {
    final int run = ++_run;
    _cameras ??= await cam.availableCameras();
    setState(() {
      _running = true;
      _results.clear();
      _savedTo = null;
    });
    _progress = 'watch ${step.label}, scene $scene';
    await setStep(step);
    await Future<void>.delayed(warmup);
    if (run != _run || !mounted) {
      return;
    }
    _watchRows.clear();
    _watchClock
      ..reset()
      ..start();
    _watchSecond = _WatchSecond();
    _cameraTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _sampleCamera(),
    );
    debugPrint('DIAGWATCH start ${step.label} scene $scene');
    await Future<void>.delayed(length);
    _cameraTimer?.cancel();
    _watchSecond = null;
    if (run != _run || !mounted) {
      return;
    }
    String? saved;
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final File file = File(
        '${dir.path}/watch-$scene-${step.label}-$stamp.json',
      );
      await file.writeAsString(
        jsonEncode(<String, Object?>{
          'device': diagDevice,
          'build': diagBuild,
          'step': step.label,
          'scene': scene,
          'rows': _watchRows,
        }),
      );
      saved = file.path;
    } on Object catch (e) {
      debugPrint('watch: not saved: $e');
    }
    debugPrint('DIAGWATCH done ${step.label} ${_watchRows.length} s');
    await setStep(LadderStep.l0);
    if (!mounted) {
      return;
    }
    setState(() {
      _running = false;
      _progress = '';
      _savedTo = saved;
    });
  }

  /// Pauses or resumes the scanner of steps L7 to L11.
  Future<void> pauseScanner({required bool paused}) async {
    final ScannerController? scanner = _scanner;
    if (scanner != null) {
      await (paused ? scanner.pause() : scanner.resume());
    }
  }

  /// Stops an automatic run.
  void stopRun() {
    _run++;
    _cameraTimer?.cancel();
    _watchSecond = null;
    _recorder = null;
    _progress = '';
    setState(() => _running = false);
  }

  Future<String?> _save(String scene, Duration took) async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final File file = File('${dir.path}/ladder-$scene-$stamp.json');
      await file.writeAsString(
        const JsonEncoder.withIndent(' ').convert(<String, Object?>{
          'device': diagDevice,
          'build': diagBuild,
          'cores': CpuMeter.cores,
          'scene': scene,
          'tookSeconds': took.inSeconds,
          'results': _results,
        }),
      );
      return file.path;
    } on Object catch (e) {
      debugPrint('ladder: not saved: $e');
      return null;
    }
  }

  Widget _stage() {
    final cam.CameraController? camera = _camera;
    final ScannerController? scanner = _scanner;
    switch (_step) {
      case LadderStep.l0 || LadderStep.l1 || LadderStep.l7:
        return const SizedBox.expand();
      case LadderStep.l2 ||
          LadderStep.l3 ||
          LadderStep.l4 ||
          LadderStep.l5 ||
          LadderStep.l6:
        if (camera == null || !camera.value.isInitialized) {
          return const SizedBox.expand();
        }
        return Center(child: cam.CameraPreview(camera));
      case LadderStep.l8:
        return scanner == null
            ? const SizedBox.expand()
            : BarcodeScanner(
                controller: scanner,
                overlayBuilder: (BuildContext context, ScannerLayout layout) =>
                    const SizedBox.shrink(),
                theme: const ScannerTheme(blur: false, scrimBlur: false),
              );
      case LadderStep.l9:
        return scanner == null
            ? const SizedBox.expand()
            : BarcodeScanner(
                controller: scanner,
                theme: const ScannerTheme(blur: false, scrimBlur: false),
              );
      case LadderStep.l10:
        return scanner == null
            ? const SizedBox.expand()
            : BarcodeScanner(
                controller: scanner,
                theme: const ScannerTheme(blur: true, scrimBlur: true),
              );
      case LadderStep.l11:
        return scanner == null
            ? const SizedBox.expand()
            : BarcodeScanner(
                controller: scanner,
                template: const ScannerTemplate.minimal(),
                theme: const ScannerTheme(blur: true, scrimBlur: true),
              );
    }
  }

  Widget _controls() => SafeArea(
    child: Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: Colors.black54,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: 'Close the ladder',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            IconButton(
              tooltip: _running ? 'Stop the run' : 'Run the ladder',
              icon: Icon(_running ? Icons.stop : Icons.play_arrow),
              onPressed: _running ? stopRun : () => unawaited(run()),
            ),
            DropdownButton<LadderStep>(
              value: _step,
              underline: const SizedBox.shrink(),
              items: <DropdownMenuItem<LadderStep>>[
                for (final LadderStep s in LadderStep.values)
                  DropdownMenuItem<LadderStep>(value: s, child: Text(s.label)),
              ],
              onChanged: _running
                  ? null
                  : (LadderStep? s) => s == null ? null : setStep(s),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _table() {
    final Map<String, List<Map<String, Object?>>> byStep =
        <String, List<Map<String, Object?>>>{};
    for (final Map<String, Object?> r in _results) {
      (byStep[r['step']! as String] ??= <Map<String, Object?>>[]).add(r);
    }
    double med(List<Map<String, Object?>> rs, String key) {
      final List<double> v = <double>[
        for (final Map<String, Object?> r in rs) (r[key]! as num).toDouble(),
      ]..sort();
      return _pct(v, 0.5);
    }

    double? before;
    final List<String> lines = <String>[
      'step   cpu  ±     Δ    reads read95  ui95  rs95',
    ];
    for (final MapEntry<String, List<Map<String, Object?>>> e
        in byStep.entries) {
      final List<double> cpus = <double>[
        for (final Map<String, Object?> r in e.value)
          (r['cpuMedian']! as num).toDouble(),
      ];
      final double cpu = med(e.value, 'cpuMedian');
      final double spread = cpus.reduce(math.max) - cpus.reduce(math.min);
      final double? delta = before == null ? null : cpu - before;
      before = cpu;
      lines.add(
        '${e.key.padRight(5)}'
        '${cpu.toStringAsFixed(1).padLeft(5)}'
        '${spread.toStringAsFixed(1).padLeft(5)}'
        '${(delta == null ? '' : delta.toStringAsFixed(1)).padLeft(6)}'
        '${med(e.value, 'readsPerSecond').toStringAsFixed(0).padLeft(6)}'
        '${med(e.value, 'readP95Ms').toStringAsFixed(1).padLeft(7)}'
        '${med(e.value, 'uiP95Ms').toStringAsFixed(1).padLeft(6)}'
        '${med(e.value, 'rasterP95Ms').toStringAsFixed(1).padLeft(6)}',
      );
    }
    if (_savedTo != null) {
      lines.add('saved: $_savedTo');
    }
    return SelectableText(
      lines.join('\n'),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _stage(),
        if (_step.panel)
          Align(
            alignment: Alignment.bottomLeft,
            child: SafeArea(
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(8),
                child: ValueListenableBuilder<String>(
                  valueListenable: _panel,
                  builder: (BuildContext context, String text, _) => Text(
                    text,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Nothing to tap while a run measures; a long press stops it.
        if (_running)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: stopRun,
          )
        else
          _controls(),
        if (!_running && _results.isNotEmpty)
          Center(
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(12),
              child: _table(),
            ),
          ),
      ],
    ),
  );
}
