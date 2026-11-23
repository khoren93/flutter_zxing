// Create a code: what it holds, its format and style, a live preview that
// is read back to check it scans, and export as PNG, SVG or Dart. Many
// codes (create_batch.dart) shares the format and style and lays the codes
// out on label sheets.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data' show BytesBuilder;

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart' show XTypeGroup, openFile;

import 'package:flutter/services.dart';
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:share_plus/share_plus.dart';

import 'content.dart';
import 'history.dart';
import 'kinds.dart';
import 'style_editor.dart';
import 'tokens.dart';

part 'create_batch.dart';

/// The error correction a level gives in [format], as its menu shows it
/// (Micro QR has no H and rMQR no L: the writer takes the nearest).
String eccLabel(BarcodeFormat format, ErrorCorrection level) =>
    switch (format) {
      BarcodeFormat.microQrCode => const <String>['L', 'M', 'Q', 'Q'],
      BarcodeFormat.rmqrCode => const <String>['M', 'M', 'H', 'H'],
      BarcodeFormat.aztec ||
      BarcodeFormat.aztecCode => const <String>['10%', '23%', '36%', '50%'],
      BarcodeFormat.pdf417 || BarcodeFormat.compactPdf417 => const <String>[
        'Level 2',
        'Level 3',
        'Level 4',
        'Level 5',
      ],
      _ => const <String>['L', 'M', 'Q', 'H'],
    }[level.index];

/// What the QR levels recover, for the menu.
const List<String> _qrRecovery = <String>['7%', '15%', '25%', '30%'];

/// Opens the generator with a text, from elsewhere in the app.
final ValueNotifier<String?> createWithText = ValueNotifier<String?>(null);

/// Whether [link] (the app's own address by default) opens Create on
/// Many codes: `?tab=create&mode=batch` on the web, or
/// `--dart-define=CREATE_MODE=batch`.
bool opensManyCodes([Uri? link]) =>
    const String.fromEnvironment('CREATE_MODE') == 'batch' ||
    (link ?? Uri.base).queryParameters['mode'] == 'batch';

class CreatePage extends StatefulWidget {
  const CreatePage({super.key, this.wide = false, this.link});

  /// Two columns: the form and style, the preview and export.
  final bool wide;

  /// The address the page was opened with, for [opensManyCodes]; the app's
  /// own by default.
  final Uri? link;

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  CreateKind _kind = CreateKind.text;
  LinkService _service = LinkService.whatsApp;

  /// The form's fields, by kind and key: each kind keeps what was typed.
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};

  /// The kinds' choices, by kind and key.
  final Map<String, String> _choices = <String, String>{};

  /// Whether the service chips show all services, not the first few.
  bool _allServices = false;

  /// The groups open in the wide layout's rail.
  final Set<KindGroup> _openGroups = <KindGroup>{KindGroup.basics};
  BarcodeFormat _format = BarcodeFormat.qrCode;

  /// The value of a format that holds a short or restricted value (EAN-13,
  /// Micro QR...) instead of the kinds' forms.
  final TextEditingController _value = TextEditingController();

  /// `null`: the writer's default (H under a logo).
  ErrorCorrection? _ecc;

  /// Why the data cannot be encoded, from the writer; `null` if it can.
  String? _error;
  String? _preset = 'lagoon';
  BarcodeStyle _style = BarcodeStyle.lagoon;
  String? _raw;

  bool? _reads;
  int _check = 0;
  Timer? _debounce;

  /// Many codes instead of one: the same format and style, on label sheets.
  late bool _many = opensManyCodes(widget.link);

  /// Many codes' items, sheet and export; made when first shown and kept
  /// when switching back and forth.
  _Batch? _batchState;
  _Batch get _batch => _batchState ??= _Batch(this);

  @override
  void initState() {
    super.initState();
    createWithText.addListener(_onTextFromElsewhere);
    _onTextFromElsewhere();
    _scheduleCheck();
  }

  @override
  void dispose() {
    createWithText.removeListener(_onTextFromElsewhere);
    _debounce?.cancel();
    _batchState?.dispose();
    _value.dispose();
    for (final TextEditingController c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTextFromElsewhere() {
    final String? text = createWithText.value;
    if (text == null) {
      return;
    }
    createWithText.value = null;
    setState(() {
      _raw = text;
      _format = BarcodeFormat.qrCode;
    });
    _scheduleCheck();
  }

  /// The form of the kind in use: a service link asks for what its service
  /// takes.
  List<KindField> get _formFields => _kind == CreateKind.service
      ? <KindField>[
          serviceField(_service),
          if (_service == LinkService.whatsApp) whatsAppMessage,
        ]
      : _kind.fields;

  String _fieldId(KindField f) =>
      _kind == CreateKind.service && f.key == 'value'
      ? 'service/${_service.name}/value'
      : '${_kind.name}/${f.key}';

  /// The field's controller, made with the field's example the first time.
  TextEditingController _controller(KindField f) =>
      _fields.putIfAbsent(_fieldId(f), () {
        final TextEditingController c = TextEditingController(text: f.example);
        c.addListener(_onEdit);
        return c;
      });

  String _choice(KindChoice c) =>
      _choices['${_kind.name}/${c.key}'] ?? c.options.first.$1;

  void _setChoice(KindChoice c, String value) {
    setState(() => _choices['${_kind.name}/${c.key}'] = value);
    _scheduleCheck();
  }

  void _onEdit() {
    setState(() => _raw = null);
    _scheduleCheck();
  }

  void _pickKind(CreateKind kind, {LinkService? service}) {
    final CreateKind before = _kind;
    setState(() {
      _kind = kind;
      _service = service ?? _service;
      _raw = null;
      _openGroups.add(kind.group);
      // GS1 data goes in a Data Matrix; back to QR when leaving it.
      if (kind.format != before.format || !_anyText) {
        _format = kind.format;
      }
      // The error correction a standard asks for, and back to auto after.
      if (kind.errorCorrection != null) {
        _ecc = kind.errorCorrection;
      } else if (before.errorCorrection != null) {
        _ecc = null;
      }
      // The Swiss cross belongs to a QR-bill, and only to it.
      if (kind == CreateKind.swiss) {
        _style = BarcodeStyle.swissQrBill;
        _preset = null;
      } else if (identical(_style, BarcodeStyle.swissQrBill)) {
        _style = BarcodeStyle.lagoon;
        _preset = 'lagoon';
      }
    });
    _scheduleCheck();
  }

  /// Opens the sheet with every kind (phone layout).
  Future<void> _openKinds() async {
    final (CreateKind, LinkService?)? picked =
        await showModalBottomSheet<(CreateKind, LinkService?)>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (BuildContext context) =>
              _KindSheet(kind: _kind, service: _service),
        );
    if (picked != null && mounted) {
      _pickKind(picked.$1, service: picked.$2);
    }
  }

  /// Whether the format takes the kinds' forms (links, Wi-Fi, contacts):
  /// otherwise one field with the format's own value.
  bool get _anyText => _format.input!.anyText;

  /// Whether the code is written as GS1 (FNC1 first).
  bool get _gs1 => _anyText && _raw == null && _kind.gs1Flag;

  /// The code is square, or 1.4 by 0.7 (linear, PDF417 and rMQR).
  bool get _square =>
      _format.isMatrix &&
      _format.symbology != BarcodeFormat.pdf417 &&
      _format != BarcodeFormat.rmqrCode;

  void _setFormat(BarcodeFormat format) {
    setState(() {
      _format = format;
      if (!_anyText) {
        _raw = null;
      }
    });
    if (!_anyText) {
      // The example is a valid value: a start the user edits.
      _value.text = format.input!.example;
    }
    _scheduleCheck();
  }

  /// What the kind's form describes, or why it cannot: the library builds
  /// the text and finds the problems (`validate`).
  (BarcodeContent?, List<FieldProblem>) get _built {
    final Map<String, String> values = <String, String>{
      for (final KindField f in _formFields) f.key: _controller(f).text,
    };
    final Map<String, String> choices = <String, String>{
      for (final KindChoice c in _kind.choices) c.key: _choice(c),
    };
    try {
      final BarcodeContent content = _kind.content(
        values,
        choices,
        linkService: _service,
      );
      return (
        content,
        <FieldProblem>[
          for (final ContentIssue i in content.validate())
            FieldProblem(i.field, i.message),
        ],
      );
    } on FieldProblem catch (p) {
      return (null, <FieldProblem>[p]);
    }
  }

  /// What is wrong with the form; empty when it builds.
  List<FieldProblem> get _problems =>
      !_anyText || _raw != null ? const <FieldProblem>[] : _built.$2;

  /// The field a problem belongs to: its own, or the first of its group
  /// (`creditor` → `creditor.name`); `null` for the form as a whole.
  String? _fieldOf(FieldProblem p) {
    for (final KindField f in _formFields) {
      if (f.key == p.field || f.key.startsWith('${p.field}.')) {
        return f.key;
      }
    }
    return null;
  }

  String get _data {
    if (!_anyText) {
      return _value.text;
    }
    if (_raw != null) {
      return _raw!;
    }
    final (BarcodeContent? content, List<FieldProblem> problems) = _built;
    return content == null || problems.isNotEmpty ? '' : content.toPayload();
  }

  /// The Dart that builds the form's content, for "Copy as Dart".
  String? get _contentDart {
    if (!_anyText || _raw != null) {
      return null;
    }
    final (BarcodeContent? content, List<FieldProblem> problems) = _built;
    if (content == null || problems.isNotEmpty) {
      return null;
    }
    return _kind.dart(<String, String>{
          for (final KindField f in _formFields) f.key: _controller(f).text,
        }, linkService: _service) ??
        contentDart(content);
  }

  String get _dart => dartCode(
    _data,
    _format,
    _style,
    presetName: _preset,
    errorCorrection: _level,
    content: _contentDart,
    gs1: _gs1,
    showText: _showText,
  );

  BarcodeWriter get _writer => BarcodeWriter(
    _format,
    errorCorrection: _level,
    gs1: _gs1,
    showText: _showText,
  );

  /// The error correction chosen, unless it is too little for the logo (a
  /// level picked before the logo was added): then Auto, the logo's.
  ErrorCorrection? get _level {
    final ErrorCorrection? ecc = _ecc;
    final BarcodeLogo? logo = _style.logo;
    return ecc != null &&
            logo != null &&
            _format == BarcodeFormat.qrCode &&
            ecc.index < logo.neededErrorCorrection.index
        ? null
        : ecc;
  }

  /// Whether linear barcodes show their digits under the bars.
  bool _textUnderBars = true;

  /// The switch for linear barcodes, `null` (the format's custom) for the
  /// others.
  bool? get _showText => _format.isLinear ? _textUnderBars : null;

  /// The level Auto picks, in words: M for a QR code, or what its logo
  /// needs.
  String? get _autoLevel {
    if (_format != BarcodeFormat.qrCode) {
      return null;
    }
    final BarcodeLogo? logo = _style.logo;
    final ErrorCorrection level =
        logo?.neededErrorCorrection ?? ErrorCorrection.medium;
    return eccLabel(_format, level);
  }

  /// Changes state from the page's parts, which are separate widgets.
  void _update(VoidCallback change) => setState(change);

  void _setStyle(BarcodeStyle style, {String? preset}) {
    setState(() {
      _style = style;
      _preset = preset;
    });
    _scheduleCheck();
  }

  /// Renders the code as exported and reads it back with the package's
  /// reader: the badge says whether this style still scans.
  void _scheduleCheck() {
    _debounce?.cancel();
    setState(() => _reads = null);
    // The format, its options or the style changed: Many codes checks its
    // items again (only if the writer did change).
    _batchState?.lookChanged();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final int run = ++_check;
      final String data = _data;
      final BarcodeFormat format = _format;
      bool ok;
      String? error;
      if (data.isEmpty) {
        // The form has a problem: the preview says which, the badge says
        // the data is invalid.
        if (mounted && run == _check) {
          setState(() {
            _reads = false;
            _error = null;
          });
        }
        return;
      }
      try {
        final Uint8List png = await _style.encodePng(
          data,
          writer: _writer,
          moduleSize: 4,
        );
        // Every variant of the symbology: Telepen Numeric, for one, is
        // only read when asked for.
        final Barcode? read = await BarcodeReader(
          formats: <BarcodeFormat>{
            for (final BarcodeFormat f in BarcodeFormat.values)
              if (f.symbology == format.symbology && f.canRead) f,
          },
        ).read(png);
        // Formats with a restricted value may read back normalized: with
        // the check digit added, a GTIN as (01)...
        ok = read != null && (read.text == data || !format.input!.anyText);
      } on BarcodeWriteException catch (e) {
        ok = false;
        error = e.message;
      } on Object {
        ok = false;
      }
      if (mounted && run == _check) {
        setState(() {
          _reads = ok;
          _error = error;
        });
      }
    });
  }

  String get _fileName => 'flutter_zxing_${_kind.name}';

  Future<void> _export(String what) async {
    final String data = _data;
    if (data.isEmpty) {
      _toast(_problems.firstOrNull?.message ?? 'Nothing to export');
      return;
    }
    final BarcodeWriter writer = _writer;
    try {
      // XFile.fromData has no path off the web, so its own name is empty:
      // the share needs the name given separately.
      final String name = '$_fileName.${what == 'svg' ? 'svg' : 'png'}';
      final XFile file = switch (what) {
        'svg' => XFile.fromData(
          Uint8List.fromList(
            utf8.encode(await _style.encodeSvg(data, writer: writer)),
          ),
          mimeType: 'image/svg+xml',
          name: '$_fileName.svg',
        ),
        _ => XFile.fromData(
          await _style.encodePng(data, writer: writer, size: 1024),
          mimeType: 'image/png',
          name: '$_fileName.png',
        ),
      };
      if (!mounted) {
        return;
      }
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final ShareResult shared = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[file],
          fileNameOverrides: <String>[name],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (shared.status != ShareResultStatus.dismissed) {
        HistoryStore.instance.addCreated(
          data,
          writer.format,
          _preset ?? 'custom',
          errorCorrection: writer.errorCorrection,
          gs1: writer.gs1,
          showText: writer.showText,
        );
      }
    } on BarcodeWriteException catch (e) {
      _toast(e.message);
    } on UnsupportedError catch (e) {
      _toast(e.message ?? 'Not supported here');
    }
  }

  Future<void> _copyDart() async {
    await Clipboard.setData(ClipboardData(text: _dart));
    _toast('Dart code copied');
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// The style section's title with its actions, the same in both layouts.
  Widget _styleHeader() => Row(
    children: <Widget>[
      const Expanded(child: FzLabel('Style')),
      TextButton(
        onPressed: () => _setStyle(BarcodeStyle.classic, preset: 'classic'),
        child: Text('Reset', style: TextStyle(color: Fz.of(context).inkMuted)),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => _many
      ? (widget.wide ? _buildBatchWide(context) : _buildBatchPhone(context))
      : (widget.wide ? _buildWide(context) : _buildPhone(context));

  /// The code card: its format and read check, the preview, and export.
  /// The same card in both layouts; in the wide one the preview fills the
  /// height the card is given.
  Widget _codeCard({required bool fill}) {
    final Widget preview = fill
        ? Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                // The preview of a linear or stacked code is 1.4 by 0.7 of
                // its size; a square code is size by size.
                final bool square = _square;
                final double side = math.max(
                  0,
                  square
                      ? math.min(c.maxWidth, c.maxHeight)
                      : math.min(c.maxWidth / 1.4, c.maxHeight / 0.7),
                );
                return Center(child: _Preview(this, size: side));
              },
            ),
          )
        : Center(child: _Preview(this, size: 176));
    return FzCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          preview,
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              _FormatMenu(this),
              if (_format.hasErrorCorrection) ...<Widget>[
                const SizedBox(width: 8),
                _EccMenu(this),
              ],
              const Spacer(),
              _ShareMenu(this),
            ],
          ),
        ],
      ),
    );
  }

  Widget _title(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Create',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        if (!_many)
          ReadCheck(
            reads: _reads,
            invalid: _error != null || _problems.isNotEmpty,
          ),
      ],
    ),
  );

  /// One code or many: the switch under the title, in both layouts.
  Widget _modeSwitch() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const <ButtonSegment<bool>>[
          ButtonSegment<bool>(
            value: false,
            label: Text('One code'),
            icon: Icon(Icons.qr_code_2_rounded),
          ),
          ButtonSegment<bool>(
            value: true,
            label: Text('Many codes'),
            icon: Icon(Icons.grid_view_rounded),
          ),
        ],
        selected: <bool>{_many},
        onSelectionChanged: (Set<bool> s) => setState(() => _many = s.first),
      ),
    ),
  );

  /// The digits switch of a linear format and the style: the same in one
  /// code and in many.
  List<Widget> _look(BuildContext context) => <Widget>[
    if (_format.isLinear && _format != BarcodeFormat.dxFilmEdge)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Digits under the bars',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'showText: the human-readable line',
            style: TextStyle(color: Fz.of(context).inkMuted),
          ),
          value: _textUnderBars,
          onChanged: (bool v) {
            setState(() => _textUnderBars = v);
            _scheduleCheck();
          },
        ),
      ),
    const SizedBox(height: 12),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _styleHeader(),
    ),
    const SizedBox(height: 4),
    _Presets(this),
    const SizedBox(height: 18),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StyleEditor(style: _style, format: _format, onChanged: _setStyle),
    ),
  ];

  /// Everything but the code card: the kind, the form, the style. The
  /// title goes first in the wide layout; the phone keeps it above the card.
  /// With the rail, the kind is picked there.
  List<Widget> _sections(
    BuildContext context, {
    bool title = false,
    bool rail = false,
  }) => <Widget>[
    if (title) ...<Widget>[
      _title(context),
      const SizedBox(height: 14),
      _modeSwitch(),
      const SizedBox(height: 14),
    ],
    if (_anyText && !rail) ...<Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _KindButton(this),
      ),
      const SizedBox(height: 18),
    ] else if (_anyText && rail) ...<Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _KindHeading(this),
      ),
      const SizedBox(height: 14),
    ]
    // Room for the field's floating label.
    else
      const SizedBox(height: 10),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _Form(this),
    ),
    ..._look(context),
    const SizedBox(height: 24),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _DartCode(this),
    ),
  ];

  /// The title and the code card stay put; the rest scrolls under them.
  Widget _buildPhone(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      SizedBox(height: MediaQuery.paddingOf(context).top + 12),
      _title(context),
      const SizedBox(height: 14),
      _modeSwitch(),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _codeCard(fill: false),
      ),
      const SizedBox(height: 14),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: _sections(context),
        ),
      ),
    ],
  );

  /// The phone layout split in two: the settings on the left, scrolling,
  /// and the code card on the right, filling the height. With room, a rail
  /// of every kind, in groups, comes first.
  Widget _buildWide(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints c) {
      final bool rail = c.maxWidth >= 960 && _anyText;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (rail)
            SizedBox(
              width: 220,
              child: SafeArea(
                right: false,
                bottom: false,
                child: _KindRail(this),
              ),
            ),
          Expanded(
            child: SafeArea(
              left: !rail,
              right: false,
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
                children: _sections(context, title: true, rail: rail),
              ),
            ),
          ),
          Expanded(
            // The same 12 points above and below the card: the bottom inset
            // is left out, as it is at the top, where landscape has none.
            child: SafeArea(
              left: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: _codeCard(fill: true),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// The code that builds this style in an app, with a copy button.
class _DartCode extends StatelessWidget {
  const _DartCode(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          const Expanded(child: FzLabel('In your app')),
          TextButton(
            onPressed: () => unawaited(page._copyDart()),
            child: const Text('Copy'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1218),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Fz.of(context).line),
        ),
        child: SelectableText(
          page._dart,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.5,
            color: Color(0xFFE6EBF2),
          ),
        ),
      ),
    ],
  );
}

/// The kind in use, with its group; a tap opens every kind.
class _KindButton extends StatelessWidget {
  const _KindButton(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final CreateKind kind = page._kind;
    return Semantics(
      button: true,
      label: 'What goes in the code: ${_kindTitle(page)}',
      excludeSemantics: true,
      child: Material(
        color: fz.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: fz.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => unawaited(page._openKinds()),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: fz.lockSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: kind == CreateKind.service
                      ? ScannerIcon(
                          BarcodeResultSheet.serviceIconOf(page._service),
                          size: 22,
                          color: fz.lockInk,
                        )
                      : Icon(kind.icon, size: 22, color: fz.lockInk),
                ),
                const SizedBox(width: 12),
                Expanded(child: _KindTitle(page)),
                const Icon(Icons.expand_more_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The kind's title over the form, when the rail picks the kind.
class _KindHeading extends StatelessWidget {
  const _KindHeading(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) => _KindTitle(page, large: true);
}

String _kindTitle(_CreatePageState page) => page._raw != null
    ? 'Text from a scan'
    : page._kind == CreateKind.service
    ? page._service == LinkService.whatsApp
          ? 'WhatsApp chat'
          : page._service.displayName
    : page._kind.title;

class _KindTitle extends StatelessWidget {
  const _KindTitle(this.page, {this.large = false});

  final _CreatePageState page;
  final bool large;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        page._kind.group.label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          height: 14 / 11,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          color: Fz.of(context).inkMuted,
        ),
      ),
      Text(
        _kindTitle(page),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: large
            ? Theme.of(context).textTheme.titleLarge
            : const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

/// The tiles of the "Social and apps" group: a few services and the rest.
const List<LinkService> _featured = <LinkService>[
  LinkService.whatsApp,
  LinkService.telegram,
  LinkService.instagram,
];

/// Every kind, in groups, with a search: the phone's picker.
class _KindSheet extends StatefulWidget {
  const _KindSheet({required this.kind, required this.service});

  final CreateKind kind;
  final LinkService service;

  @override
  State<_KindSheet> createState() => _KindSheetState();
}

class _KindSheetState extends State<_KindSheet> {
  String _query = '';

  bool _matches(String s) => s.toLowerCase().contains(_query.toLowerCase());

  void _pick(CreateKind kind, [LinkService? service]) =>
      Navigator.of(context).pop((kind, service));

  @override
  Widget build(BuildContext context) {
    final List<Widget> groups = <Widget>[];
    for (final KindGroup g in KindGroup.values) {
      final bool groupMatches = _query.isEmpty || _matches(g.label);
      final List<Widget> tiles = <Widget>[
        if (g == KindGroup.social) ...<Widget>[
          for (final LinkService s in LinkService.values)
            if (_query.isEmpty
                ? _featured.contains(s)
                : groupMatches || _matches(s.displayName))
              _KindTile(
                label: s.displayName,
                icon: BarcodeResultSheet.serviceIconOf(s),
                selected:
                    widget.kind == CreateKind.service && widget.service == s,
                onTap: () => _pick(CreateKind.service, s),
              ),
          if (_query.isEmpty)
            _KindTile(
              label: 'All ${LinkService.values.length}',
              icon: Icons.apps_rounded,
              selected:
                  widget.kind == CreateKind.service &&
                  !_featured.contains(widget.service),
              onTap: () => _pick(CreateKind.service),
            ),
        ] else
          for (final CreateKind k in g.kinds)
            if (groupMatches || _matches(k.label) || _matches(k.title))
              _KindTile(
                label: k.label,
                icon: k.icon,
                selected: widget.kind == k,
                onTap: () => _pick(k),
              ),
      ];
      if (tiles.isEmpty) {
        continue;
      }
      groups.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: FzLabel(g.label)),
                  Text(
                    switch (g) {
                      KindGroup.social =>
                        '${LinkService.values.length} services',
                      KindGroup.payments => '${g.kinds.length} standards',
                      _ => '',
                    },
                    style: TextStyle(
                      fontSize: 12,
                      color: Fz.of(context).inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GridView(
                // As many columns as fit, at a height that holds two lines
                // of the label at any text size.
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 92,
                  mainAxisExtent:
                      40 + MediaQuery.textScalerOf(context).scale(32),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: tiles,
              ),
            ],
          ),
        ),
      );
    }
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: <Widget>[
          Text(
            'What goes in the code',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search kinds and services',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (String q) => setState(() => _query = q.trim()),
          ),
          const SizedBox(height: 18),
          ...groups,
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Nothing called “$_query”',
                textAlign: TextAlign.center,
                style: TextStyle(color: Fz.of(context).inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;

  /// An [IconData] or a [ScannerIconData].
  final Object icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? fz.lockSoft : fz.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? Fz.lock : fz.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _glyph(icon, 20, selected ? fz.lockInk : fz.inkMuted),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? fz.lockInk : fz.ink,
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

/// Every kind, in groups that open and close: the wide layout's picker.
class _KindRail extends StatelessWidget {
  const _KindRail(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    Widget item(CreateKind k) {
      final bool selected = page._kind == k && page._raw == null;
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: selected ? fz.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => page._pickKind(k),
            child: SizedBox(
              height: 36,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 12),
                  Icon(
                    k.icon,
                    size: 18,
                    color: selected ? fz.raised : fz.inkMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      k == CreateKind.service ? 'Link to a service' : k.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? fz.raised : fz.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: fz.line)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: FzLabel('What goes in'),
          ),
          for (final KindGroup g in KindGroup.values) ...<Widget>[
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => page._update(() {
                if (!page._openGroups.remove(g)) {
                  page._openGroups.add(g);
                }
              }),
              child: SizedBox(
                height: 36,
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: 10),
                    Expanded(child: FzLabel(g.label)),
                    Text(
                      '${g == KindGroup.social ? LinkService.values.length : g.kinds.length}',
                      style: TextStyle(fontSize: 12, color: fz.inkMuted),
                    ),
                    Icon(
                      page._openGroups.contains(g)
                          ? Icons.expand_more_rounded
                          : Icons.chevron_right_rounded,
                      size: 18,
                      color: fz.inkMuted,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            if (page._openGroups.contains(g))
              for (final CreateKind k in g.kinds) item(k),
          ],
        ],
      ),
    );
  }
}

/// How many services the chips show before "+N more".
const int _firstServices = 7;

/// A name and a category mark for a service: never a brand's logo.
class _ServiceChips extends StatelessWidget {
  const _ServiceChips(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          const Expanded(child: FzLabel('Service')),
          Text(
            'LinkService · ${LinkService.values.length}',
            style: TextStyle(fontSize: 12, color: Fz.of(context).inkMuted),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final LinkService s in LinkService.values)
            if (page._allServices ||
                s.index < _firstServices ||
                s == page._service)
              ChoiceChip(
                avatar: ScannerIcon(
                  BarcodeResultSheet.serviceIconOf(s),
                  size: 18,
                ),
                label: Text(s.displayName),
                selected: page._service == s,
                onSelected: (_) =>
                    page._pickKind(CreateKind.service, service: s),
              ),
          if (!page._allServices)
            ActionChip(
              label: Text(
                '+${LinkService.values.length - _firstServices - (page._service.index >= _firstServices ? 1 : 0)} more',
              ),
              onPressed: () => page._update(() => page._allServices = true),
            ),
        ],
      ),
      const SizedBox(height: 16),
    ],
  );
}

class _Form extends StatelessWidget {
  const _Form(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) {
    final BarcodeInput input = page._format.input!;
    if (!input.anyText) {
      // The format's own value: what it holds, and the writer's word on
      // what is wrong with it.
      return TextField(
        controller: page._value,
        onChanged: (_) => page._scheduleCheck(),
        decoration: InputDecoration(
          labelText: page._format.displayName,
          helperText: input.description,
          helperMaxLines: 2,
          errorText: page._error,
          errorMaxLines: 3,
        ),
        keyboardType: input.digitsOnly
            ? TextInputType.number
            : TextInputType.text,
        style: const TextStyle(fontFamily: 'monospace'),
      );
    }
    final String? raw = page._raw;
    if (raw != null) {
      return FzCard(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                raw,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            IconButton(
              tooltip: 'Edit as a form instead',
              icon: const Icon(Icons.close_rounded),
              onPressed: page._onEdit,
            ),
          ],
        ),
      );
    }
    final List<FieldProblem> problems = page._problems;
    String? problemOf(KindField f) => problems
        .where((FieldProblem p) => page._fieldOf(p) == f.key)
        .map((FieldProblem p) => p.message)
        .firstOrNull;
    final List<FieldProblem> general = <FieldProblem>[
      for (final FieldProblem p in problems)
        if (page._fieldOf(p) == null) p,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (page._kind == CreateKind.service) _ServiceChips(page),
        for (final KindField f in page._formFields)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: page._controller(f),
              decoration: InputDecoration(
                labelText: f.optional ? '${f.label} · optional' : f.label,
                helperText: f.hint,
                helperMaxLines: 2,
                errorText: problemOf(f),
                errorMaxLines: 3,
              ),
              keyboardType: switch (f.input) {
                FieldInput.url => TextInputType.url,
                FieldInput.email => TextInputType.emailAddress,
                FieldInput.phone => TextInputType.phone,
                FieldInput.multiline => TextInputType.multiline,
                FieldInput.number => TextInputType.number,
                FieldInput.decimal => const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                _ => TextInputType.text,
              },
              maxLines: f.input == FieldInput.multiline ? null : 1,
              style: f.mono ? const TextStyle(fontFamily: 'monospace') : null,
            ),
          ),
        for (final KindChoice c in page._kind.choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (page._kind.choices.length > 1 ||
                    page._kind != CreateKind.wifi) ...<Widget>[
                  FzLabel(c.label),
                  const SizedBox(height: 6),
                ],
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: <ButtonSegment<String>>[
                    for (final (String value, String label) in c.options)
                      ButtonSegment<String>(value: value, label: Text(label)),
                  ],
                  selected: <String>{page._choice(c)},
                  onSelectionChanged: (Set<String> s) =>
                      page._setChoice(c, s.first),
                ),
              ],
            ),
          ),
        for (final FieldProblem p in general)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              p.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

/// A Material icon or one of the scanner's own.
Widget _glyph(Object icon, double size, Color color) => switch (icon) {
  final ScannerIconData i => ScannerIcon(i, size: size, color: color),
  final IconData i => Icon(i, size: size, color: color),
  _ => SizedBox.square(dimension: size),
};

class _FormatMenu extends StatelessWidget {
  const _FormatMenu(this.page, {this.menuKey});

  final _CreatePageState page;

  /// Opens the menu from elsewhere ("Change format" under a code that does
  /// not fit).
  final GlobalKey<PopupMenuButtonState<BarcodeFormat>>? menuKey;

  @override
  Widget build(BuildContext context) => PopupMenuButton<BarcodeFormat>(
    key: menuKey,
    tooltip: 'Format',
    initialValue: page._format,
    onSelected: page._setFormat,
    itemBuilder: (BuildContext context) => <PopupMenuEntry<BarcodeFormat>>[
      // Every format the package creates, 2D first, as the package lists
      // them.
      for (final (String title, bool linear) in const <(String, bool)>[
        ('2D', false),
        ('Linear', true),
      ]) ...<PopupMenuEntry<BarcodeFormat>>[
        if (linear) const PopupMenuDivider(),
        PopupMenuItem<BarcodeFormat>(
          enabled: false,
          height: 32,
          child: FzLabel(title),
        ),
        for (final BarcodeFormat f in BarcodeFormat.writable)
          if (f.isLinear == linear)
            PopupMenuItem<BarcodeFormat>(
              value: f,
              child: Row(
                children: <Widget>[
                  _FormatThumb(f),
                  const SizedBox(width: 14),
                  Text(f.displayName),
                ],
              ),
            ),
      ],
    ],
    child: _Pill(page._format.displayName),
  );
}

/// A small picture of [format] for the format menu: its example, drawn
/// by the package.
class _FormatThumb extends StatelessWidget {
  const _FormatThumb(this.format);

  final BarcodeFormat format;

  @override
  Widget build(BuildContext context) {
    final BarcodeInput input = format.input!;
    return ExcludeSemantics(
      child: Container(
        width: 52,
        height: 34,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Fz.of(context).line),
        ),
        child: BarcodeView(
          // Free text gets a short value: a long link makes a dense blur.
          input.anyText ? 'zxing' : input.example,
          writer: BarcodeWriter(format),
          style: const BarcodeStyle(quietZone: false),
        ),
      ),
    );
  }
}

/// The error correction, for the formats that let it be chosen.
class _EccMenu extends StatelessWidget {
  const _EccMenu(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) {
    final BarcodeFormat format = page._format;
    final ErrorCorrection? ecc = page._level;
    final bool qr = format.symbology == BarcodeFormat.qrCode;
    // Under a logo, the levels it needs and more.
    final ErrorCorrection? least = format == BarcodeFormat.qrCode
        ? page._style.logo?.neededErrorCorrection
        : null;
    String label(ErrorCorrection e) {
      final String level = eccLabel(format, e);
      return qr ? '$level  ·  ${_qrRecovery['LMQH'.indexOf(level)]}' : level;
    }

    // Menu values are indexes: a null value would close the menu as a
    // cancel, so Auto is -1.
    return PopupMenuButton<int>(
      tooltip: 'Error correction',
      initialValue: ecc?.index ?? -1,
      onSelected: (int i) {
        page._update(
          () => page._ecc = i < 0 ? null : ErrorCorrection.values[i],
        );
        page._scheduleCheck();
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
        const PopupMenuItem<int>(
          enabled: false,
          height: 32,
          child: FzLabel('Error correction'),
        ),
        PopupMenuItem<int>(
          value: -1,
          child: Text(switch (page._autoLevel) {
            null => 'Auto',
            final String l when page._style.logo != null =>
              'Auto: $l, for the logo',
            final String l => 'Auto: $l',
          }),
        ),
        for (final ErrorCorrection e in ErrorCorrection.values)
          PopupMenuItem<int>(
            value: e.index,
            enabled: least == null || e.index >= least.index,
            child: Text(label(e)),
          ),
      ],
      child: _Pill(
        ecc != null
            ? 'ECC ${eccLabel(format, ecc)}'
            : page._autoLevel == null
            ? 'ECC auto'
            : 'ECC auto · ${page._autoLevel}',
      ),
    );
  }
}

/// The look of the card's menus: a label with a chevron.
class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Fz.of(context).surface,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.expand_more_rounded, size: 18),
      ],
    ),
  );
}

class _Preview extends StatelessWidget {
  const _Preview(
    this.page, {
    required this.size,
    this.data,
    this.writer,
    this.trouble,
  });

  final _CreatePageState page;
  final double size;

  /// The code to show, with [writer]: the first of many. The form's code
  /// when `null`.
  final String? data;
  final BarcodeWriter? writer;

  /// What to show instead of [data]'s code: a title and a line.
  final (String, String)? trouble;

  @override
  Widget build(BuildContext context) {
    final BarcodeStyle style = page._style;
    final bool square = page._square;
    final List<FieldProblem> formProblems = data != null
        ? const <FieldProblem>[]
        : page._problems;
    final (String, String)? trouble = data != null
        ? this.trouble
        : formProblems.isEmpty
        ? null
        : (
            formProblems.length == 1
                ? '1 field to fix'
                : '${formProblems.length} fields to fix',
            formProblems.first.message,
          );
    final bool problems = trouble != null;
    final Fz fz = Fz.of(context);
    final Color bad = Theme.of(context).colorScheme.error;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: square ? size : size * 1.4,
      height: square ? size : size * 0.7,
      // The symbology's own quiet zone (four modules around a QR code) looks
      // like empty space on screen: the tile keeps a narrower margin in its
      // place. Exports keep the full one.
      padding: problems
          ? const EdgeInsets.all(16)
          : EdgeInsets.all(style.quietZone ? size * 0.07 : 6),
      decoration: BoxDecoration(
        // A card brings its own ground: around it, the page's.
        color: problems
            ? bad.withValues(alpha: 0.10)
            : style.card != null
            ? fz.surface
            : style.backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: problems
          // What validate() found: the code appears once it has nothing to
          // say.
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.error_outline_rounded, size: 28, color: bad),
                    const SizedBox(height: 8),
                    Text(
                      trouble.$1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: fz.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trouble.$2,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: fz.inkMuted),
                    ),
                  ],
                ),
              ),
            )
          : BarcodeView(
              data ?? page._data,
              writer: writer ?? page._writer,
              // Without text or a card, the quiet zone would look like empty
              // space; with them it sets the spacing, as in the export.
              style:
                  style.title == null &&
                      style.caption == null &&
                      style.card == null
                  ? style.copyWith(quietZone: false)
                  : style,
              errorBuilder: (BuildContext context, BarcodeWriteException e) =>
                  Center(
                    child: Text(
                      e.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF4B5563)),
                    ),
                  ),
            ),
    );
  }
}

/// Share and export, in a dropdown from the icon at the card's corner.
class _ShareMenu extends StatelessWidget {
  const _ShareMenu(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Share',
    icon: const Icon(Icons.ios_share_rounded, size: 22),
    onSelected: (String v) => unawaited(page._export(v)),
    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
      const PopupMenuItem<String>(value: 'png', child: Text('PNG')),
      PopupMenuItem<String>(
        value: 'svg',
        enabled: page._style.gradient is! SweepGradient,
        child: const Text('SVG'),
      ),
    ],
  );
}

class _Presets extends StatelessWidget {
  const _Presets(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    String title(String s) => '${s[0].toUpperCase()}${s.substring(1)}';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          for (final MapEntry<String, BarcodeStyle> p
              in BarcodeStyle.presets.entries)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Semantics(
                button: true,
                selected: page._preset == p.key,
                label: '${title(p.key)} style',
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  // The preset's look; the logo, text and card stay.
                  onTap: () => page._setStyle(
                    p.value.copyWith(
                      logo: () => page._style.logo,
                      title: () => page._style.title,
                      caption: () => page._style.caption,
                      card: () => page._style.card,
                    ),
                    preset: p.key,
                  ),
                  child: SizedBox(
                    width: 76,
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: 72,
                          height: 72,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: p.value.backgroundColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: page._preset == p.key ? fz.ink : fz.line,
                              width: page._preset == p.key ? 2.5 : 1,
                            ),
                          ),
                          child: ExcludeSemantics(
                            child: BarcodeView(
                              'https://pub.dev/packages/flutter_zxing',
                              style: p.value.copyWith(quietZone: false),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title(p.key),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
}
