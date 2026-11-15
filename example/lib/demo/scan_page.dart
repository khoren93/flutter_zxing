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
import 'history.dart';
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

  /// Room the tab bar takes over the camera.
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
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // The template's bottom controls and sheet sit above the tab bar.
          MediaQuery(
            data: mq.copyWith(
              viewPadding: top.copyWith(
                bottom: top.bottom + widget.bottomInset,
              ),
              padding: mq.padding.copyWith(
                bottom: mq.padding.bottom + widget.bottomInset,
              ),
            ),
            child: BarcodeScanner(
              controller: _controller,
              template: _template,
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
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _Numbers(controller: _controller),
                ),
              ),
            ),
        ],
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0E1218),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 20,
                color: const Color(0xFF0E1218),
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
  Widget build(BuildContext context) => ScannerGlass(
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
                      Icon(t.icon, size: 22, color: const Color(0xFF0E1218)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              t.label,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0E1218),
                              ),
                            ),
                            Text(
                              t.note,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (t == picked)
                        const Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: Color(0xFF00735D),
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
  const _Numbers({required this.controller});

  final ScannerController controller;

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

  @override
  void initState() {
    super.initState();
    _sub = widget.controller.frameSamples.listen(_onSample);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _onSample(ScannerFrameSample s) {
    final DateTime now = DateTime.now();
    setState(() {
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
    });
  }

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
      theme: const ScannerTheme(brightness: Brightness.dark),
      child: ScannerGlass(
        strong: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
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
          ],
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
