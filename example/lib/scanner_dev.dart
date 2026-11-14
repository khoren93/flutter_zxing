// Developer screen for the 4.0 scanner: the camera, the default overlay and
// live decoder numbers. Run it with
//   flutter run -t lib/scanner_dev.dart
// The final scanner design comes later; this screen is for checking that the
// outlines sit on the codes in every orientation and on both cameras.
import 'dart:async';

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
// The decoder numbers are not public API.
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug, ScannerFrameSample;

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
  final ScannerController _controller = ScannerController();
  StreamSubscription<ScannerFrameSample>? _samples;
  final List<ScannerFrameSample> _window = <ScannerFrameSample>[];
  final Stopwatch _clock = Stopwatch()..start();
  String _stats = '';
  String? _last;
  bool _fullWindow = false;

  @override
  void initState() {
    super.initState();
    _samples = _controller.frameSamples.listen(_onSample);
  }

  void _onSample(ScannerFrameSample sample) {
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
    _window.clear();
    _clock.reset();
  }

  @override
  void dispose() {
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
                '${capture.barcode.format.displayName}: ${capture.barcode.text}',
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
                          '${MediaQuery.orientationOf(context).name}\n$_stats'
                          '${state.error == null ? '' : '\n${state.error}'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                  ),
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
