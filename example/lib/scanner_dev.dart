// Developer screen for the 4.0 scanner: the camera, the default overlay and
// live decoder numbers. Run it with
//   flutter run -t lib/scanner_dev.dart [--dart-define=FACING=front]
// (native platforms: the save button writes files with dart:io).
// The final scanner design comes later; this screen is for checking that the
// outlines sit on the codes in every orientation and on both cameras.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
// The decoder numbers and the last frame are not public API.
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug, ScannerFrameSample;

import 'scan_benchmark.dart';
import 'ui_stall.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ScannerDevPage(),
    ),
  );
}

/// The scanner with its numbers.
class ScannerDevPage extends StatefulWidget {
  /// Creates the page.
  const ScannerDevPage({super.key});

  @override
  State<ScannerDevPage> createState() => _ScannerDevPageState();
}

class _ScannerDevPageState extends State<ScannerDevPage> {
  // --dart-define=FACING=front starts with the front camera.
  final ScannerController _controller = ScannerController(
    facing: const String.fromEnvironment('FACING') == 'front'
        ? CameraFacing.front
        : CameraFacing.back,
  );
  StreamSubscription<ScannerFrameSample>? _samples;
  final List<ScannerFrameSample> _window = <ScannerFrameSample>[];
  final Stopwatch _clock = Stopwatch()..start();
  String _stats = '';
  String? _last;
  bool _fullWindow = false;
  final Stopwatch _sinceFrame = Stopwatch()..start();
  late final Timer _ticker;
  ScanBenchmark? _benchmark;
  bool _measuring = false;
  String? _stall;

  @override
  void initState() {
    super.initState();
    _samples = _controller.frameSamples.listen(_onSample);
    // Shows when frames stop coming, and the watchdogs' restarts.
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
    // --dart-define=MEASURE=ui_stall: read a 12 MP photo once the camera
    // runs and report how much it held up the UI.
    if (const String.fromEnvironment('MEASURE') == 'ui_stall') {
      unawaited(_measureStall());
    }
  }

  void _onSample(ScannerFrameSample sample) {
    _sinceFrame.reset();
    _window.add(sample);
    if (_clock.elapsedMilliseconds < 500) {
      return;
    }
    final double seconds = _clock.elapsedMilliseconds / 1000;
    final double engine =
        _window.fold<int>(
          0,
          (int s, ScannerFrameSample f) => s + f.engineMicros,
        ) /
        _window.length /
        1000;
    final double roundTrip =
        _window.fold<int>(
          0,
          (int s, ScannerFrameSample f) => s + f.roundTripMicros,
        ) /
        _window.length /
        1000;
    final ScannerFrameSample latest = _window.last;
    final Rect? crop = latest.crop;
    setState(() {
      _stats =
          '${(_window.length / seconds).toStringAsFixed(1)} fps · '
          'engine ${engine.toStringAsFixed(1)} ms · '
          'round trip ${roundTrip.toStringAsFixed(1)} ms\n'
          'frame ${latest.frameSize.width.toInt()}×'
          '${latest.frameSize.height.toInt()}'
          '${crop == null ? '' : ' · window ${crop.width.toInt()}×${crop.height.toInt()}'}';
    });
    // The numbers in the log too, for runs attached to `flutter run`.
    debugPrint('scanner_dev: $_stats');
    _window.clear();
    _clock.reset();
  }

  /// Saves the part of the last frame the engine decoded, as a grayscale
  /// PGM with a JSON description, into the app's temporary directory: to
  /// read a frame that was not decoded again on a computer.
  Future<void> _saveFrame() async {
    final (PixelBuffer, Rect?)? last = _controller.lastFrame;
    if (last == null) {
      return;
    }
    final (PixelBuffer image, Rect? crop) = last;
    final Rect area =
        crop ??
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final int left = area.left.toInt();
    final int top = area.top.toInt();
    final int w = area.width.toInt();
    final int h = area.height.toInt();
    final int bpp = image.layout.bytesPerPixel;
    final int stride = image.rowStride ?? image.width * bpp;
    final Uint8List lum = Uint8List(w * h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int i = (top + y) * stride + (left + x) * bpp;
        lum[y * w + x] = switch (image.layout) {
          PixelLayout.luminance => image.bytes[i],
          PixelLayout.bgra =>
            (306 * image.bytes[i + 2] +
                    601 * image.bytes[i + 1] +
                    117 * image.bytes[i] +
                    0x200) >>
                10,
          _ =>
            (306 * image.bytes[i] +
                    601 * image.bytes[i + 1] +
                    117 * image.bytes[i + 2] +
                    0x200) >>
                10,
        };
      }
    }
    final Directory dir = Directory('${Directory.systemTemp.path}/frames')
      ..createSync(recursive: true);
    final String name = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    File(
      '${dir.path}/$name.pgm',
    ).writeAsBytesSync(<int>[...ascii.encode('P5\n$w $h\n255\n'), ...lum]);
    final ScannerState state = _controller.value;
    File('${dir.path}/$name.json').writeAsStringSync(
      jsonEncode(<String, Object?>{
        'frame': <int>[image.width, image.height],
        'layout': image.layout.name,
        'crop': <int>[left, top, w, h],
        'facing': state.facing.name,
        'orientation': MediaQuery.orientationOf(context).name,
        'zoom': state.zoom,
        'last': _last,
      }),
    );
    debugPrint('scanner_dev: saved ${dir.path}/$name.pgm');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved $name.pgm')));
    }
  }

  /// Runs the prototype's benchmark: hold the camera on a QR code until 1000
  /// frames with a code are decoded.
  Future<void> _runBenchmark() async {
    final ScanBenchmark? running = _benchmark;
    if (running != null) {
      running.cancel();
      setState(() => _benchmark = null);
      return;
    }
    final ScanWindow window = _controller.scanWindow;
    final DetectionMode detection = _controller.detection;
    _controller
      ..scanWindow = benchmarkWindow
      ..detection = DetectionMode.continuous;
    final ScanBenchmark benchmark = ScanBenchmark(_controller);
    setState(() => _benchmark = benchmark);
    final Map<String, Object?> result = await benchmark.run();
    _controller
      ..scanWindow = window
      ..detection = detection;
    if (!mounted) {
      return;
    }
    setState(() => _benchmark = null);
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Benchmark'),
        content: Text(
          (result['summary']! as List<Object?>).join('\n'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _measureStall() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    // The camera's frames make garbage on this isolate; without it the
    // numbers are the reader's alone.
    await _controller.stop();
    setState(() => _measuring = true);
    final Map<String, Object> r = await measureUiStall();
    await _controller.start();
    if (!mounted) {
      return;
    }
    setState(() {
      _measuring = false;
      _stall = <String>[
        for (final String k in <String>[
          'idle',
          'read',
          'readAll',
          'readPixels',
        ])
          '$k: ${(r[k]! as Map<String, Object?>).entries.map((MapEntry<String, Object?> e) => '${e.key} ${e.value}').join(', ')}',
      ].join('\n');
    });
  }

  String get _health {
    final int seconds = _sinceFrame.elapsed.inSeconds;
    final ScanBenchmark? benchmark = _benchmark;
    return '${seconds >= 2 ? 'NO FRAMES for $seconds s · ' : ''}'
        'camera restarts ${_controller.cameraRestarts} · '
        'engine restarts ${_controller.engineRestarts}'
        '${benchmark == null ? '' : '\nBENCHMARK ${benchmark.collected} / ${benchmark.target}'}'
        '${_measuring ? '\nMEASURING the UI while reading a 12 MP photo...' : ''}'
        '${_stall == null ? '' : '\n$_stall'}';
  }

  @override
  void dispose() {
    _ticker.cancel();
    unawaited(_samples?.cancel());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        BarcodeScanner(
          controller: _controller,
          onDetect: (BarcodeCapture capture) => setState(
            () => _last =
                '${capture.barcode.format.displayName}: ${capture.barcode.text}'
                '\n${capture.barcode.content}',
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Panel(
                  child: ValueListenableBuilder<ScannerState>(
                    valueListenable: _controller,
                    builder: (BuildContext context, ScannerState state, _) =>
                        Text(
                          '${state.status.name} · ${state.facing.name} · '
                          'zoom ${state.zoom.toStringAsFixed(1)}/'
                          '${state.maxZoom.toStringAsFixed(1)} · '
                          'preview ${state.previewSize?.width.toInt()}×'
                          '${state.previewSize?.height.toInt()} · '
                          '${MediaQuery.orientationOf(context).name}\n$_stats\n'
                          '$_health'
                          '${state.error == null ? '' : '\n${state.error}'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                  ),
                ),
                if (_measuring)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    // Animates every frame, so that Flutter draws frames
                    // while the photo is read.
                    child: Center(child: CircularProgressIndicator()),
                  ),
                const Spacer(),
                if (_last != null)
                  _Panel(
                    child: Text(_last!, style: const TextStyle(fontSize: 16)),
                  ),
                const SizedBox(height: 8),
                _Panel(
                  child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      TorchButton(_controller),
                      SwitchCameraButton(_controller),
                      IconButton(
                        tooltip: 'Save the frame',
                        icon: const Icon(Icons.save_alt),
                        onPressed: _saveFrame,
                      ),
                      IconButton(
                        tooltip: 'Benchmark 1000',
                        icon: Icon(
                          _benchmark == null ? Icons.speed : Icons.stop,
                        ),
                        onPressed: _runBenchmark,
                      ),
                      IconButton(
                        tooltip: 'Scan window',
                        icon: Icon(
                          _fullWindow ? Icons.fullscreen : Icons.crop_square,
                        ),
                        onPressed: () => setState(() {
                          _fullWindow = !_fullWindow;
                          _controller.scanWindow = _fullWindow
                              ? const ScanWindow.full()
                              : const ScanWindow.centered();
                        }),
                      ),
                      DropdownButton<DetectionMode>(
                        value: _controller.detection,
                        underline: const SizedBox.shrink(),
                        items: <DropdownMenuItem<DetectionMode>>[
                          for (final DetectionMode mode in DetectionMode.values)
                            DropdownMenuItem<DetectionMode>(
                              value: mode,
                              child: Text(mode.name),
                            ),
                        ],
                        onChanged: (DetectionMode? mode) =>
                            setState(() => _controller.detection = mode!),
                      ),
                      ValueListenableBuilder<ScannerState>(
                        valueListenable: _controller,
                        builder:
                            (BuildContext context, ScannerState state, _) =>
                                IconButton(
                                  tooltip: state.status == ScannerStatus.paused
                                      ? 'Resume'
                                      : 'Pause',
                                  icon: Icon(
                                    state.status == ScannerStatus.paused
                                        ? Icons.play_arrow
                                        : Icons.pause,
                                  ),
                                  onPressed:
                                      state.status == ScannerStatus.paused
                                      ? _controller.resume
                                      : _controller.pause,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(padding: const EdgeInsets.all(8), child: child),
  );
}
