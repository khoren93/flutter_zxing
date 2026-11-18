// The diagnostics page: the live camera, its numbers, and the tabs that change
// the settings and keep the runs.
import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'diag_metrics.dart';
import 'diag_runs.dart';
import 'diag_settings.dart';
import 'frame_recorder.dart';
import 'frame_saver.dart';
import 'frames_tab.dart';
import 'lens_numbers.dart';
import 'scan_benchmark.dart';
import 'settings_tab.dart';
import 'ui_stall.dart';

/// The page.
class DiagnosticsPage extends StatefulWidget {
  /// Creates the page.
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  /// How long each side of an A/B run stays on.
  static const Duration _abTurn = Duration(seconds: 3);

  DiagSettings _a = const DiagSettings();
  DiagSettings? _b;
  String _editing = 'A';
  String _live = 'A';
  Timer? _abTimer;

  late ScannerController _controller = _newController();
  final DiagMetrics _metrics = DiagMetrics();
  final DiagRunStore _runs = DiagRunStore();
  final FrameRecorder _recorder = FrameRecorder();
  final RecordingStore _recordings = RecordingStore();
  bool _reopening = false;
  ScanBenchmark? _benchmark;

  /// Apart from the page's state: it changes with every code read.
  final ValueNotifier<String?> _lastRead = ValueNotifier<String?>(null);

  DiagSettings get _shown => _editing == 'B' ? _b ?? _a : _a;
  DiagSettings get _active => _live == 'B' ? _b ?? _a : _a;

  ScannerController _newController() {
    final ScannerController c = ScannerController(resolution: _a.resolution);
    _a.applyTo(c);
    return c;
  }

  @override
  void initState() {
    super.initState();
    _metrics.attach(_controller);
    _recorder.attach(_controller);
    unawaited(_runs.load());
    unawaited(_recordings.load());
  }

  @override
  void dispose() {
    _abTimer?.cancel();
    _metrics.dispose();
    _runs.dispose();
    _recorder.dispose();
    _recordings.dispose();
    _lastRead.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _change(DiagSettings next) async {
    final bool newCamera = next.resolution != _shown.resolution;
    setState(() {
      if (_editing == 'B') {
        _b = next;
      } else {
        _a = next;
      }
      if (newCamera) {
        // One camera for both sides.
        _a = _a.copyWith(resolution: next.resolution);
        _b = _b?.copyWith(resolution: next.resolution);
      }
    });
    if (newCamera) {
      await _reopen();
    } else if (_editing == _live) {
      _active.applyTo(_controller);
    }
    _metrics.reset(_editing);
  }

  /// A new resolution needs a new camera.
  Future<void> _reopen() async {
    setState(() => _reopening = true);
    final ScannerController old = _controller;
    await old.stop();
    old.dispose();
    if (!mounted) {
      return;
    }
    setState(() {
      _controller = _newController();
      _active.applyTo(_controller);
      _reopening = false;
    });
    _metrics.attach(_controller);
    _recorder.attach(_controller);
  }

  void _toggleAb() {
    _abTimer?.cancel();
    setState(() {
      if (_b == null) {
        _b = _a;
        _abTimer = Timer.periodic(_abTurn, (_) => _turn());
      } else {
        _b = null;
        _abTimer = null;
        _editing = 'A';
        _live = 'A';
        _a.applyTo(_controller);
        _metrics.switchTo('A');
      }
    });
  }

  void _turn() {
    setState(() => _live = _live == 'A' ? 'B' : 'A');
    _active.applyTo(_controller);
    _metrics.switchTo(_live);
  }

  Future<void> _saveRun() async {
    final DiagSettings? b = _b;
    await _runs.add(
      DiagRun.now(b == null ? 'Run' : 'A', _a, _metrics.snapshot('A')),
    );
    if (b != null) {
      await _runs.add(DiagRun.now('B', b, _metrics.snapshot('B')));
    }
    _say('Saved');
  }

  void _saveFrame() {
    final String? path = saveLastFrame(_controller, <String, Object?>{
      'settings': _active.toJson(),
      'last': _lastRead.value,
    });
    _say(path == null ? 'No frame yet' : 'Saved $path');
  }

  void _say(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  /// Hold the camera on a QR code until 1000 frames with a code are decoded.
  Future<void> _runBenchmark() async {
    final ScanBenchmark? running = _benchmark;
    if (running != null) {
      running.cancel();
      setState(() => _benchmark = null);
      return;
    }
    _controller
      ..scanWindow = benchmarkWindow
      ..detection = DetectionMode.continuous;
    final ScanBenchmark benchmark = ScanBenchmark(_controller);
    setState(() => _benchmark = benchmark);
    final Map<String, Object?> result = await benchmark.run();
    _active.applyTo(_controller);
    if (!mounted) {
      return;
    }
    setState(() => _benchmark = null);
    await _report(
      'Benchmark',
      (result['summary']! as List<Object?>).join('\n'),
    );
  }

  /// How much reading a 12 MP photo holds up the UI, with the camera off.
  Future<void> _measureStall() async {
    await _controller.stop();
    if (!mounted) {
      return;
    }
    // Animates every frame, so that Flutter draws frames during the read.
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );
    final Map<String, Object> r = await measureUiStall();
    await _controller.start();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    await _report(
      'UI stall',
      <String>[
        for (final String k in <String>[
          'idle',
          'read',
          'readAll',
          'readPixels',
        ])
          '$k: ${r[k]}',
      ].join('\n'),
    );
  }

  Future<void> _report(String title, String text) => showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final Widget camera = _reopening
        ? const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          )
        : BarcodeScanner(
            key: ObjectKey(_controller),
            controller: _controller,
            theme: ScannerTheme(blur: _active.blur, scrimBlur: _active.blur),
            onDetect: (BarcodeCapture c) => _lastRead.value =
                '${c.barcode.format.displayName}: ${c.barcode.text}',
          );
    final Widget tabs = DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(height: 36, text: 'Settings'),
              Tab(height: 36, text: 'Frames'),
              Tab(height: 36, text: 'Runs'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                DiagSettingsTab(
                  settings: _shown,
                  onChanged: (DiagSettings s) => unawaited(_change(s)),
                  controller: _controller,
                  side: _b == null ? null : _editing,
                  onSide: (String s) => setState(() => _editing = s),
                ),
                DiagFramesTab(
                  recorder: _recorder,
                  store: _recordings,
                  settings: _active,
                  controller: _controller,
                ),
                DiagRunsTab(store: _runs),
              ],
            ),
          ),
        ],
      ),
    );
    // Opened on a small phone, the numbers scroll instead of pushing the
    // tabs off the screen.
    final Widget numbers = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
      ),
      child: SingleChildScrollView(
        child: _Numbers(
          metrics: _metrics,
          controller: _controller,
          abOn: _b != null,
          live: _live,
          lastRead: _lastRead,
        ),
      ),
    );
    final Widget actions = _Actions(
      controller: _controller,
      abOn: _b != null,
      benchmark: _benchmark,
      onAb: _toggleAb,
      onSaveRun: _saveRun,
      onSaveFrame: _saveFrame,
      onBenchmark: _runBenchmark,
      onStall: _measureStall,
    );
    // Dark also when the demo opens it from its own theme.
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        body: SafeArea(
          child: OrientationBuilder(
            builder: (BuildContext context, Orientation orientation) =>
                orientation == Orientation.portrait
                ? Column(
                    children: <Widget>[
                      Expanded(flex: 4, child: camera),
                      actions,
                      numbers,
                      Expanded(flex: 5, child: tabs),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      Expanded(child: camera),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            actions,
                            numbers,
                            Expanded(child: tabs),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.controller,
    required this.abOn,
    required this.benchmark,
    required this.onAb,
    required this.onSaveRun,
    required this.onSaveFrame,
    required this.onBenchmark,
    required this.onStall,
  });

  final ScannerController controller;
  final bool abOn;
  final ScanBenchmark? benchmark;
  final VoidCallback onAb;
  final VoidCallback onSaveRun;
  final VoidCallback onSaveFrame;
  final VoidCallback onBenchmark;
  final VoidCallback onStall;

  @override
  Widget build(BuildContext context) {
    final ScanBenchmark? running = benchmark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          if (Navigator.of(context).canPop())
            IconButton(
              tooltip: 'Back to the scanner',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ValueListenableBuilder<ScannerState>(
            valueListenable: controller,
            builder: (BuildContext context, ScannerState state, _) {
              final bool paused = state.status == ScannerStatus.paused;
              return IconButton(
                tooltip: paused ? 'Resume' : 'Pause',
                icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                onPressed: paused ? controller.resume : controller.pause,
              );
            },
          ),
          IconButton(
            tooltip: 'Torch',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: controller.toggleTorch,
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: controller.switchCamera,
          ),
          IconButton(
            tooltip: abOn ? 'Stop the A/B run' : 'Start an A/B run',
            isSelected: abOn,
            icon: const Icon(Icons.compare_arrows),
            onPressed: onAb,
          ),
          IconButton(
            tooltip: 'Save this run',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: onSaveRun,
          ),
          IconButton(
            tooltip: 'Save the frame',
            icon: const Icon(Icons.save_alt),
            onPressed: onSaveFrame,
          ),
          IconButton(
            tooltip: 'Benchmark 1000',
            icon: Icon(running == null ? Icons.speed : Icons.stop),
            onPressed: onBenchmark,
          ),
          IconButton(
            tooltip: 'UI stall while reading a photo',
            icon: const Icon(Icons.hourglass_bottom),
            onPressed: onStall,
          ),
          if (running != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('${running.collected} / ${running.target}'),
            ),
        ],
      ),
    );
  }
}

/// The numbers under the camera, redrawn four times a second at most.
class _Numbers extends StatelessWidget {
  const _Numbers({
    required this.metrics,
    required this.controller,
    required this.abOn,
    required this.live,
    required this.lastRead,
  });

  final DiagMetrics metrics;
  final ScannerController controller;
  final bool abOn;
  final String live;
  final ValueListenable<String?> lastRead;

  static String _n(double? v, [int digits = 1]) =>
      v == null ? '—' : v.toStringAsFixed(digits);

  Widget _line(DiagSnapshot s, String? side) => Wrap(
    spacing: 14,
    runSpacing: 4,
    children: <Widget>[
      if (side != null) _Stat('Side', side),
      _Stat('Decode', '${_n(s.decodeP50Ms)} ms'),
      _Stat('p95', '${_n(s.decodeP95Ms)} ms'),
      _Stat('Max', '${_n(s.decodeMaxMs)} ms'),
      _Stat('With code', '${s.withCodePercent.round()}%'),
      _Stat('First read', s.firstReadMs == null ? '—' : '${s.firstReadMs} ms'),
      _Stat('Reads/s', _n(s.fps, 0)),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: metrics,
    builder: (BuildContext context, _) {
      final DiagSnapshot s = metrics.snapshot(abOn ? live : null);
      return ExpansionTile(
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: abOn
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _line(metrics.snapshot('A'), 'A'),
                  const SizedBox(height: 4),
                  _line(metrics.snapshot('B'), 'B'),
                ],
              )
            : _line(s, null),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 14,
            children: <Widget>[
              _Stat('CPU', '${_n(s.cpuPercent, 0)}%'),
              _Stat('Device', '${_n(s.devicePercent, 0)}%'),
              _Stat('Memory', '${_n(s.memoryMb, 0)} MB'),
              _Stat('Not decoded', '${s.failed}'),
            ],
          ),
        ),
        children: <Widget>[
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: <Widget>[
              _Stat('Latency', '${_n(s.latencyP50Ms)} ms'),
              _Stat('Dropped', '${s.dropped}'),
              _Stat('UI p95', '${_n(s.uiP95Ms)} ms'),
              _Stat('Raster p95', '${_n(s.rasterP95Ms)} ms'),
              _Stat('Slow frames', '${_n(s.slowFramesPercent)}%'),
              _Stat(
                'Frame',
                '${s.frame.width.round()}×${s.frame.height.round()}',
              ),
              if (s.window != null)
                _Stat(
                  'Window',
                  '${s.window!.width.round()}×${s.window!.height.round()}',
                ),
              _Stat('Lines', '${s.lineCount ?? '—'}'),
              _Stat('UEC', _n(s.uec, 2)),
              _Stat('Mask', '${s.dataMask ?? '—'}'),
              _Stat('Restarts', '${s.cameraRestarts + s.engineRestarts}'),
              _Stat('zxing-cpp', zxingCppVersion),
            ],
          ),
          ValueListenableBuilder<String?>(
            valueListenable: lastRead,
            builder: (BuildContext context, String? read, _) => read == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      read,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
          if (s.threads.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              <String>[
                for (final (String name, double cpu) in s.threads.take(6))
                  '${cpu.round().toString().padLeft(4)}%  $name',
              ].join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
          LensNumbers(key: ObjectKey(controller), controller: controller),
        ],
      );
    },
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}
