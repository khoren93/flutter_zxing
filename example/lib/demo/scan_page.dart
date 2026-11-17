// The Scan tab: a scanner template picked from a menu, every read code kept
// in the history, and the decoder's numbers for developers.
import 'dart:async';
import 'dart:math' as math;
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
import 'field_demo_page.dart';
import 'history.dart';
import 'lens_numbers.dart';
import 'tokens.dart';

/// The groups of the template picker.
enum TemplateGroup {
  everyday('Everyday'),
  shopping('Shopping and payments'),
  work('Work');

  const TemplateGroup(this.label);

  final String label;
}

/// The templates of the picker: every preset of [ScannerTemplate].
enum DemoTemplate {
  minimal(
    'Minimal',
    'minimal()',
    TemplateGroup.everyday,
    Icons.crop_free_rounded,
  ),
  content('Content', 'content()', TemplateGroup.everyday, Icons.wifi_rounded),
  signIn('Sign in', 'signIn()', TemplateGroup.everyday, Icons.login_rounded),
  small(
    'Small codes',
    'small()',
    TemplateGroup.everyday,
    Icons.zoom_in_rounded,
  ),
  pick(
    'Pick from many',
    'pick()',
    TemplateGroup.everyday,
    Icons.touch_app_outlined,
  ),
  fullscreen(
    'Fullscreen',
    'fullscreen()',
    TemplateGroup.everyday,
    Icons.fullscreen_rounded,
  ),
  payment(
    'Payments',
    'payment()',
    TemplateGroup.shopping,
    Icons.credit_card_rounded,
  ),
  product(
    'Product, book',
    'product()',
    TemplateGroup.shopping,
    Icons.menu_book_outlined,
  ),
  retail(
    'Retail',
    'retail()',
    TemplateGroup.shopping,
    Icons.view_week_outlined,
  ),
  loyalty(
    'Loyalty card',
    'loyalty()',
    TemplateGroup.shopping,
    Icons.loyalty_outlined,
  ),
  logistics(
    'Logistics',
    'logistics()',
    TemplateGroup.work,
    Icons.inventory_2_outlined,
  ),
  pharma('Pharma', 'pharma()', TemplateGroup.work, Icons.medication_outlined),
  vin(
    'Vehicle VIN',
    'vin()',
    TemplateGroup.work,
    Icons.directions_car_outlined,
  ),
  checkIn(
    'Event check-in',
    'checkIn()',
    TemplateGroup.work,
    Icons.how_to_reg_outlined,
  ),
  kiosk('Kiosk', 'kiosk()', TemplateGroup.work, Icons.desktop_windows_outlined),
  ticket(
    'Tickets, IDs',
    'ticket()',
    TemplateGroup.work,
    Icons.confirmation_number_outlined,
  );

  const DemoTemplate(this.label, this.api, this.group, this.icon);

  final String label;

  /// The preset's constructor.
  final String api;
  final TemplateGroup group;
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
      _checkedIn.clear();
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
    DemoTemplate.content => ScannerTemplate.content(
      closeButton: false,
      actionsBuilder: _actions,
    ),
    DemoTemplate.signIn => const ScannerTemplate.signIn(closeButton: false),
    DemoTemplate.small => ScannerTemplate.small(
      closeButton: false,
      actionsBuilder: _actions,
    ),
    DemoTemplate.pick => ScannerTemplate.pick(
      closeButton: false,
      actionsBuilder: _actions,
    ),
    DemoTemplate.fullscreen => ScannerTemplate.fullscreen(
      closeButton: false,
      actionsBuilder: _actions,
    ),
    DemoTemplate.payment => ScannerTemplate.payment(
      closeButton: false,
      title: null, // The picker above names the template.
      actionsBuilder: _actions,
    ),
    DemoTemplate.product => ScannerTemplate.product(
      closeButton: false,
      actionsBuilder: _actions,
    ),
    DemoTemplate.retail => ScannerTemplate.retail(
      closeButton: false,
      onDone: _saveAll,
    ),
    DemoTemplate.loyalty => ScannerTemplate.loyalty(
      closeButton: false,
      actionsBuilder: _actions,
    ),
    DemoTemplate.logistics => ScannerTemplate.logistics(
      closeButton: false,
      onDone: _saveAll,
    ),
    DemoTemplate.pharma => ScannerTemplate.pharma(
      closeButton: false,
      actionsBuilder: _actions,
    ),
    DemoTemplate.vin => ScannerTemplate.vin(
      closeButton: false,
      actionsBuilder: _actions,
    ),
    DemoTemplate.checkIn => ScannerTemplate.checkIn(
      check: _checkIn,
      closeButton: false,
    ),
    DemoTemplate.kiosk => ScannerTemplate.kiosk(check: _checkIn),
    DemoTemplate.ticket => ScannerTemplate.ticket(
      closeButton: false,
      title: null, // The picker above names the template.
      actionsBuilder: _actions,
    ),
  };

  /// The codes checked in since the template was picked.
  final Set<String> _checkedIn = <String>{};

  /// The demo's door: any ticket-like code (a text or a link) once; a
  /// second time it is already in; anything else is no ticket.
  ScanVerdict _checkIn(Barcode barcode) {
    final BarcodeContent content = barcode.content;
    if (content is! TextContent && content is! UrlContent) {
      return ScanVerdict.reject(
        title: 'Not a ticket',
        message: describe(barcode).kind,
      );
    }
    final String title = describe(barcode).title;
    if (!_checkedIn.add(barcode.text)) {
      return ScanVerdict.warn(title: title, message: 'Already checked in');
    }
    return ScanVerdict.accept(title: title, message: 'Welcome in');
  }

  void _saveAll(List<CollectedBarcode> items) {
    for (final CollectedBarcode b in items) {
      unawaited(HistoryStore.instance.addScan(b.barcode, cutOut: b.cutOut));
    }
  }

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
    if (_template.mode == ScannerMode.collect) {
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
                left: 8 + top.left,
                top: top.top + 64,
                bottom: bottom + 8,
                width: math.min(440, mq.size.width - 16 - top.horizontal),
                child: _Menu(
                  picked: _picked,
                  onPick: _pick,
                  onForm: () {
                    setState(() => _menu = false);
                    unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              const FieldDemoPage(),
                        ),
                      ),
                    );
                  },
                ),
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

/// Every template, in groups, two to a row; and the form that scans
/// into its fields.
class _Menu extends StatelessWidget {
  const _Menu({
    required this.picked,
    required this.onPick,
    required this.onForm,
  });

  final DemoTemplate picked;
  final ValueChanged<DemoTemplate> onPick;
  final VoidCallback onForm;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
          color: theme.inkMutedColor,
        ),
      ),
    );
    Widget row({
      required IconData icon,
      required String title,
      required String api,
      required bool selected,
      required VoidCallback onTap,
      bool trailing = false,
    }) => Semantics(
      button: true,
      selected: selected,
      label: title,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? const Color(0x2E2EE6B5) : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? Fz.lock
                          : theme.inkMutedColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: selected ? Fz.onLock : theme.inkColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.inkColor,
                          ),
                        ),
                        Text(
                          api,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: theme.inkMutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.inkMutedColor,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return ScannerGlass(
      strong: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      padding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Templates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.inkColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${DemoTemplate.values.length} presets of ScannerTemplate',
              style: TextStyle(fontSize: 13, color: theme.inkMutedColor),
            ),
          ),
          for (final TemplateGroup g in TemplateGroup.values) ...<Widget>[
            label(g.label),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final List<DemoTemplate> items = <DemoTemplate>[
                  for (final DemoTemplate t in DemoTemplate.values)
                    if (t.group == g) t,
                ];
                final double w = (c.maxWidth - 4) / 2;
                return Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: <Widget>[
                    for (final DemoTemplate t in items)
                      SizedBox(
                        width: w,
                        child: row(
                          icon: t.icon,
                          title: t.label,
                          api: t.api,
                          selected: t == picked,
                          onTap: () => onPick(t),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.inkMutedColor.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: row(
                icon: Icons.input_rounded,
                title: 'Scan into a form',
                api: 'ScanFieldButton',
                selected: false,
                onTap: onForm,
                trailing: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
