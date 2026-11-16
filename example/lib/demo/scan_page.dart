// The Scan tab: a scanner template picked from a menu, every read code kept
// in the history, and the decoder's numbers for developers.
import 'dart:async';
import 'dart:ui' as ui;

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
// The decoder numbers are not public API.
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug, ScannerFrameSample;

import 'content.dart';
import 'cpu_usage_stub.dart' if (dart.library.ffi) 'cpu_usage.dart';
import 'history.dart';
import 'lens_numbers.dart';
import 'tokens.dart';

/// The templates of the picker.
enum DemoTemplate {
  minimal('Minimal', 'Any code, one at a time', Icons.crop_free_rounded),
  payment('Payments', 'Pay, receipts', Icons.credit_card_rounded),
  retail('Retail', 'Many barcodes, counted', Icons.view_week_outlined),
  ticket('Tickets', 'Boarding passes, IDs', Icons.confirmation_number_outlined),
  content('Content', 'Wi‑Fi, contacts, links', Icons.wifi_rounded);

  const DemoTemplate(this.label, this.note, this.icon);

  final String label;
  final String note;
  final IconData icon;
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.bottomInset = 0, required this.onOpen});

  /// The gap between the template's sheet and the tab bar. The tab bar's
  /// own height comes from the Scaffold, as the body's bottom padding.
  final double bottomInset;

  /// Opens a history item.
  final ValueChanged<HistoryItem> onOpen;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  DemoTemplate _picked = DemoTemplate.minimal;
  late ScannerTemplate _template = _build(_picked);
  late final ScannerController _controller = _configure(ScannerController());
  bool _menu = false;
  bool _numbers = false;

  /// Glass blur, switched off from the numbers panel to measure what it
  /// costs.
  bool _blur = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ScannerController _configure(ScannerController c) => c
    ..formats = _template.formats
    ..scanWindow = _template.scanWindow
    ..detection = _template.detection
    ..maxBarcodes = _template.maxBarcodes;

  void _pick(DemoTemplate t) {
    setState(() {
      _picked = t;
      _template = _build(t);
      _menu = false;
    });
    _configure(_controller);
    unawaited(_controller.resume());
  }

  ScannerTemplate _build(DemoTemplate t) => switch (t) {
    DemoTemplate.minimal => ScannerTemplate.minimal(
      closeButton: false,
      actionsBuilder: _actions,
    ),
    DemoTemplate.payment => ScannerTemplate.payment(
      closeButton: false,
      title: null, // The picker above names the template.
      actionsBuilder: _actions,
    ),
    DemoTemplate.retail => ScannerTemplate.retail(
      closeButton: false,
      onDone: (List<CollectedBarcode> items) {
        for (final CollectedBarcode b in items) {
          unawaited(HistoryStore.instance.addScan(b.barcode, cutOut: b.cutOut));
        }
      },
    ),
    DemoTemplate.ticket => ScannerTemplate.ticket(
      closeButton: false,
      title: null, // The picker above names the template.
      actionsBuilder: _actions,
    ),
    DemoTemplate.content => ScannerTemplate.content(
      closeButton: false,
      actionsBuilder: _actions,
    ),
  };

  List<ScannerAction> _actions(
    BuildContext context,
    Barcode barcode,
    VoidCallback scanAgain,
  ) {
    final Described d = describe(barcode);
    final Uri? open = d.open;
    final String copy = d.secret ?? barcode.text;
    return <ScannerAction>[
      ScannerAction.copy(copy),
      if (open != null)
        ScannerAction(
          label: d.openLabel ?? 'Open',
          icon: ScannerIcons.open,
          primary: true,
          onPressed: () => unawaited(openUri(context, open)),
        )
      else
        ScannerAction(label: 'Scan again', primary: true, onPressed: scanAgain),
    ];
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_template.collect) {
      return; // Retail keeps its own list; onDone saves it.
    }
    ui.Image? cut;
    if (BarcodeThumbnail.needsCutOut(capture.barcode)) {
      cut = await capture.snapshot();
    }
    await HistoryStore.instance.addScan(
      capture.barcode,
      source: capture.source == CaptureSource.image ? 'photo' : 'camera',
      cutOut: cut,
    );
    cut?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final EdgeInsets top = mq.viewPadding;
    final double bottom =
        (mq.viewPadding.bottom > mq.padding.bottom
            ? mq.viewPadding.bottom
            : mq.padding.bottom) +
        widget.bottomInset;
    // Without blur: the template's glass and scrim, and this page's own
    // glass (the picker, the panel).
    return ScannerScope(
      theme: ScannerTheme(blur: _blur, scrimBlur: _blur),
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // The template's bottom controls and sheet sit above the tab bar.
            // The Scaffold clears the body's bottom view padding and puts the
            // tab bar's height into its padding instead.
            MediaQuery(
              data: mq.copyWith(
                viewPadding: top.copyWith(bottom: bottom),
                padding: mq.padding.copyWith(bottom: bottom),
              ),
              child: BarcodeScanner(
                controller: _controller,
                template: _template,
                theme: ScannerTheme(blur: _blur, scrimBlur: _blur),
                onDetect: (BarcodeCapture c) => unawaited(_onDetect(c)),
              ),
            ),
            Positioned(
              left: 16,
              top: top.top + 8,
              child: Row(
                children: <Widget>[
                  _Picker(
                    picked: _picked,
                    open: _menu,
                    onTap: () => setState(() => _menu = !_menu),
                  ),
                  const SizedBox(width: 8),
                  ScannerButton(
                    icon: ScannerIcons.binary,
                    label: _numbers
                        ? 'Hide the developer numbers'
                        : 'Show the developer numbers',
                    isToggle: true,
                    selected: _numbers,
                    onPressed: () => setState(() => _numbers = !_numbers),
                  ),
                ],
              ),
            ),
            if (_menu) ...<Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _menu = false),
                ),
              ),
              Positioned(
                left: 16,
                top: top.top + 64,
                width: 260,
                child: _Menu(picked: _picked, onPick: _pick),
              ),
            ],
            if (_numbers)
              Positioned(
                left: 12,
                right: 12,
                top: top.top + 64,
                child: Center(
                  child: ConstrainedBox(
                    // A quarter of the screen; the numbers scroll inside.
                    constraints: BoxConstraints(
                      maxWidth: 420,
                      maxHeight: MediaQuery.sizeOf(context).height / 4,
                    ),
                    child: _Numbers(
                      controller: _controller,
                      blur: _blur,
                      onBlur: (bool on) => setState(() => _blur = on),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.picked,
    required this.open,
    required this.onTap,
  });

  final DemoTemplate picked;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    expanded: open,
    label: 'Scanner template: ${picked.label}',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: ScannerGlass(
        padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Fz.lock,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Fz.lock.withValues(alpha: 0.3),
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                picked.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ScannerTheme.of(context).inkColor,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 20,
                color: ScannerTheme.of(context).inkColor,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Menu extends StatelessWidget {
  const _Menu({required this.picked, required this.onPick});

  final DemoTemplate picked;
  final ValueChanged<DemoTemplate> onPick;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    return _menu(theme);
  }

  Widget _menu(ScannerTheme theme) => ScannerGlass(
    strong: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    padding: const EdgeInsets.all(8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final DemoTemplate t in DemoTemplate.values)
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onPick(t),
              child: Ink(
                decoration: BoxDecoration(
                  color: t == picked ? const Color(0x2E2EE6B5) : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(t.icon, size: 22, color: theme.inkColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.inkColor,
                              ),
                            ),
                            Text(
                              t.note,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.inkMutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (t == picked)
                        Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: theme.lockInkColor,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// The decoder's numbers over the camera: decode time, frame rate, drops,
/// and a bar for each of the last 30 frames.
class _Numbers extends StatefulWidget {
  const _Numbers({
    required this.controller,
    required this.blur,
    required this.onBlur,
  });

  final ScannerController controller;

  /// Whether the glass blurs the camera.
  final bool blur;
  final ValueChanged<bool> onBlur;

  @override
  State<_Numbers> createState() => _NumbersState();
}

class _NumbersState extends State<_Numbers> {
  StreamSubscription<ScannerFrameSample>? _sub;
  final List<ScannerFrameSample> _recent = <ScannerFrameSample>[];
  final List<DateTime> _times = <DateTime>[];
  int _dropped = 0;
  int _reads = 0;
  Size _frame = Size.zero;

  // The app's CPU use, once a second.
  final CpuMeter _cpu = CpuMeter();
  Timer? _cpuTimer;
  double? _cpuPercent;
  List<(String, double)>? _threads;

  /// The threads of the last second the app used more than 120% of a core.
  (double, List<(String, double)>)? _spike;

  @override
  void initState() {
    super.initState();
    _sub = widget.controller.frameSamples.listen(_onSample);
    _cpu.sample();
    _cpuTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _cpuPercent = _cpu.sample();
        _threads = _cpu.sampleThreads();
        final double? cpu = _cpuPercent;
        final List<(String, double)>? threads = _threads;
        if (cpu != null && cpu > 120 && threads != null) {
          _spike = (cpu, threads);
        }
      });
    });
  }

  @override
  void dispose() {
    _cpuTimer?.cancel();
    _redraw?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  /// Redraws the panel 4 times a second, not on every camera frame: the
  /// panel would otherwise cost more than what it measures.
  Timer? _redraw;

  void _onSample(ScannerFrameSample s) {
    final DateTime now = DateTime.now();
    _redraw ??= Timer(const Duration(milliseconds: 250), () {
      _redraw = null;
      if (mounted) {
        setState(() {});
      }
    });
    _recent.add(s);
    if (_recent.length > 120) {
      _recent.removeAt(0);
    }
    _times.add(now);
    _times.removeWhere(
      (DateTime t) => now.difference(t) > const Duration(seconds: 1),
    );
    _dropped += s.dropped;
    if (s.found) {
      _reads++;
    }
    _frame = s.frameSize;
  }

  static const TextStyle _mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    height: 1.4,
    color: Color(0xFFEEF1F5),
  );

  /// The five busiest threads, one a line.
  static String _threadLines(List<(String, double)> threads) => <String>[
    for (final (String name, double cpu) in threads.take(5))
      '${cpu.round().toString().padLeft(4)}%  $name',
  ].join('\n');

  double _percentile(double p) {
    if (_recent.isEmpty) {
      return 0;
    }
    final List<int> ms =
        _recent.map((ScannerFrameSample s) => s.engineMicros).toList()..sort();
    return ms[((ms.length - 1) * p).round()] / 1000;
  }

  @override
  Widget build(BuildContext context) {
    const TextStyle k = TextStyle(
      fontSize: 11,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
      color: Color(0xFFA7B0BD),
    );
    const TextStyle v = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color(0xFFEEF1F5),
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    );
    Widget stat(String key, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(key.toUpperCase(), style: k),
        const SizedBox(height: 2),
        Text(value, style: v),
      ],
    );
    final List<ScannerFrameSample> last = _recent.length > 30
        ? _recent.sublist(_recent.length - 30)
        : _recent;
    final ScannerController c = widget.controller;
    return ScannerScope(
      theme: ScannerTheme(brightness: Brightness.dark, blur: widget.blur),
      child: ScannerGlass(
        strong: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('DECODER · LIVE', style: k),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: stat(
                      'Decode p50',
                      '${_percentile(0.5).toStringAsFixed(1)} ms',
                    ),
                  ),
                  Expanded(
                    child: stat(
                      'p95',
                      '${_percentile(0.95).toStringAsFixed(1)} ms',
                    ),
                  ),
                  Expanded(child: stat('Frames', '${_times.length}/s')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(child: stat('Dropped', '$_dropped')),
                  Expanded(child: stat('With a code', '$_reads')),
                  Expanded(
                    child: stat(
                      'Restarts',
                      '${c.cameraRestarts + c.engineRestarts}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: stat(
                      'CPU, app',
                      _cpuPercent == null ? '—' : '${_cpuPercent!.round()}%',
                    ),
                  ),
                  Expanded(
                    child: stat(
                      'Of ${CpuMeter.cores} cores',
                      _cpuPercent == null || CpuMeter.cores == 0
                          ? '—'
                          : '${(_cpuPercent! / CpuMeter.cores).round()}%',
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 10),
              // Blur on and off, to see what it costs (the raster thread).
              GestureDetector(
                onTap: () => widget.onBlur(!widget.blur),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: <Widget>[
                    Text('GLASS BLUR', style: k),
                    const Spacer(),
                    IgnorePointer(
                      child: Switch(value: widget.blur, onChanged: (_) {}),
                    ),
                  ],
                ),
              ),
              if (_threads != null) ...<Widget>[
                const SizedBox(height: 10),
                const Text('THREADS, % OF A CORE', style: k),
                const SizedBox(height: 4),
                Text(_threadLines(_threads!), style: _mono),
              ],
              if (_spike != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'LAST SPIKE · ${_spike!.$1.round()}%',
                  style: k.copyWith(color: const Color(0xFFFBBF24)),
                ),
                const SizedBox(height: 4),
                Text(_threadLines(_spike!.$2), style: _mono),
              ],
              const SizedBox(height: 14),
              SizedBox(height: 44, child: CustomPaint(painter: _Bars(last))),
              const SizedBox(height: 10),
              Text(
                '${_frame.width.round()}×${_frame.height.round()} · '
                '${c.formats == null ? 'all formats' : '${c.formats!.length} formats'} · '
                'zxing-cpp $zxingCppVersion',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFFA7B0BD),
                ),
              ),
              LensNumbers(controller: c),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bars extends CustomPainter {
  _Bars(this.samples);

  final List<ScannerFrameSample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) {
      return;
    }
    const int slots = 30;
    final double w = size.width / slots;
    final int maxMicros = samples
        .map((ScannerFrameSample s) => s.engineMicros)
        .fold(8000, (int a, int b) => a > b ? a : b);
    for (final (int i, ScannerFrameSample s) in samples.indexed) {
      final double h = (s.engineMicros / maxMicros * size.height).clamp(
        2,
        size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * w + 1, size.height - h, w - 2, h),
          const Radius.circular(2),
        ),
        Paint()
          ..color = s.found
              ? Fz.lock
              : const Color(0xFFEEF1F5).withValues(alpha: 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_Bars old) => true;
}
