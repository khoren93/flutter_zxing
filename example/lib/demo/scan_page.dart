// The Scan tab: a scanner template picked from a menu, every read code kept
// in the history.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../diagnostics/diagnostics_stub.dart'
    if (dart.library.ffi) '../diagnostics/diagnostics_page.dart';
import 'content.dart';
import 'field_demo_page.dart';
import 'history.dart';
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
  const ScanPage({super.key, this.bottomInset = 0});

  /// The gap between the template's sheet and the tab bar. The tab bar's
  /// own height comes from the Scaffold, as the body's bottom padding.
  final double bottomInset;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // --dart-define=TEMPLATE=payment (or ?template=payment on the web, as the
  // documentation site embeds the demo) opens a template directly. The
  // names are the constructors': payment, checkIn, signIn...
  DemoTemplate _picked = DemoTemplate.values.firstWhere(
    (DemoTemplate t) =>
        t.name == const String.fromEnvironment('TEMPLATE') ||
        t.name == Uri.base.queryParameters['template'],
    orElse: () => DemoTemplate.minimal,
  );
  late ScannerTemplate _template = _build(_picked);
  late final ScannerController _controller = ScannerController.fromTemplate(
    _template,
  );
  bool _menu = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The camera stays open while the template changes: its settings go to
  /// the controller in place, and the camera turns to the template's side.
  void _configure(ScannerController c) {
    c
      ..formats = _template.formats
      ..scanWindow = _template.scanWindow
      ..detection = _template.detection
      ..maxBarcodes = _template.maxBarcodes
      ..initialZoom = _template.initialZoom;
    unawaited(c.switchCamera(_template.facing ?? CameraFacing.back));
  }

  void _pick(DemoTemplate t) {
    setState(() {
      _checkedIn.clear();
      _savedFromList.clear();
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
      onPick: (Barcode barcode, BarcodeCapture capture) =>
          unawaited(_save(barcode, capture)),
    ),
    DemoTemplate.fullscreen => ScannerTemplate.fullscreen(
      closeButton: false,
      actionsBuilder: _actions,
    ),
    DemoTemplate.payment => ScannerTemplate.payment(
      closeButton: false,
      title: '', // The picker above names the template.
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
      title: '', // The picker above names the template.
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
    // Only a ticket let in goes to the history.
    unawaited(HistoryStore.instance.addScan(barcode));
    return ScanVerdict.accept(title: title, message: 'Welcome in');
  }

  /// The codes of the list already saved: the list keeps them after Done,
  /// and the next Done brings them again.
  final Set<(BarcodeFormat, String)> _savedFromList =
      <(BarcodeFormat, String)>{};

  void _saveAll(List<CollectedBarcode> items) {
    for (final CollectedBarcode b in items) {
      if (_savedFromList.add((b.barcode.format, b.barcode.text))) {
        unawaited(HistoryStore.instance.addScan(b.barcode, cutOut: b.cutOut));
      }
    }
  }

  List<ScannerAction> _actions(BuildContext context, ScannerResult result) {
    final Barcode barcode = result.barcode;
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
        ScannerAction(
          label: 'Scan again',
          primary: true,
          onPressed: result.scanAgain,
        ),
    ];
  }

  /// Opens the diagnostics page. It has a camera of its own; the scanner
  /// under it pauses and lets its camera go by itself.
  Future<void> _openDiagnostics() =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const DiagnosticsPage(),
        ),
      );

  Future<void> _onDetect(BarcodeCapture capture) async {
    // Retail keeps its own list, onDone saves it; onPick saves a picked code;
    // a check saves the codes it lets in, onDetect sees the rejected ones too.
    if (_template.mode == ScannerMode.collect ||
        _template.mode == ScannerMode.pick ||
        _template.check != null) {
      return;
    }
    await _save(capture.barcode, capture);
  }

  Future<void> _save(Barcode barcode, BarcodeCapture capture) async {
    ui.Image? cut;
    if (BarcodeThumbnail.needsCutOut(barcode)) {
      cut = await capture.snapshot(barcode);
    }
    await HistoryStore.instance.addScan(
      barcode,
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
    // The blur is left to the scanner: on, off where the phone is too slow.
    return ScannerScope(
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
                onDetect: (BarcodeCapture c) => unawaited(_onDetect(c)),
                // Over the template's screen in its theme: the template
                // picker where the close button would be (it is off), and the
                // diagnostics button in the top bar, left of the torch or of
                // the button that leaves a paused scan, in their place
                // without them.
                foregroundBuilder: (BuildContext context, ScannerLayout _) =>
                    Positioned.fill(
                      child: ValueListenableBuilder<ScannerState>(
                        valueListenable: _controller,
                        builder:
                            (
                              BuildContext context,
                              ScannerState state,
                              Widget? _,
                            ) {
                              final bool taken =
                                  state.status == ScannerStatus.paused ||
                                  state.status == ScannerStatus.error ||
                                  (_template.torchButton &&
                                      state.torch != TorchState.unavailable);
                              return Stack(
                                children: <Widget>[
                                  Positioned(
                                    left: top.left + 16,
                                    top: top.top + 8,
                                    child: _Picker(
                                      picked: _picked,
                                      open: _menu,
                                      onTap: () =>
                                          setState(() => _menu = !_menu),
                                    ),
                                  ),
                                  if (!kIsWeb)
                                    Positioned(
                                      right:
                                          top.right + 20 + (taken ? 48 + 8 : 0),
                                      top: top.top + 12,
                                      child: ScannerButton(
                                        icon: ScannerIcons.binary,
                                        label: 'Open diagnostics',
                                        onPressed: () =>
                                            unawaited(_openDiagnostics()),
                                      ),
                                    ),
                                ],
                              );
                            },
                      ),
                    ),
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
