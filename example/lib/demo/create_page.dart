// Create a code: what it holds, its format and style, a live preview that
// is read back to check it scans, and export as PNG, SVG or Dart.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:share_plus/share_plus.dart';

import 'content.dart';
import 'history.dart';
import 'style_editor.dart';
import 'tokens.dart';

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

class CreatePage extends StatefulWidget {
  const CreatePage({super.key, this.wide = false});

  /// Two columns: the form and style, the preview and export.
  final bool wide;

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  CreateKind _kind = CreateKind.wifi;
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};
  WifiSecurity _security = WifiSecurity.wpa;
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

  @override
  void initState() {
    super.initState();
    _fillDefaults();
    createWithText.addListener(_onTextFromElsewhere);
    _onTextFromElsewhere();
    _scheduleCheck();
  }

  @override
  void dispose() {
    createWithText.removeListener(_onTextFromElsewhere);
    _debounce?.cancel();
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

  void _fillDefaults() {
    for (final (String key, String _, String example) in _kind.fields) {
      _fields.putIfAbsent(key, () {
        final TextEditingController c = TextEditingController(text: example);
        c.addListener(_onEdit);
        return c;
      });
    }
  }

  void _onEdit() {
    setState(() => _raw = null);
    _scheduleCheck();
  }

  /// Whether the format takes the kinds' forms (links, Wi-Fi, contacts):
  /// otherwise one field with the format's own value.
  bool get _anyText => _format.input!.anyText;

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

  String get _data => !_anyText
      ? _value.text
      : _raw ??
            _kind.encode(<String, String>{
              for (final MapEntry<String, TextEditingController> e
                  in _fields.entries)
                e.key: e.value.text,
            }, security: _security);

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
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final int run = ++_check;
      final String data = _data;
      final BarcodeFormat format = _format;
      bool ok;
      String? error;
      try {
        final Uint8List png = await BarcodeWriter(
          format,
          errorCorrection: _ecc,
        ).toPng(data, moduleSize: 4, style: _style);
        // Every variant of the symbology: Telepen Numeric, for one, is
        // only read when asked for.
        final Barcode? read = await BarcodeReader(
          formats: <BarcodeFormat>{
            for (final BarcodeFormat f in BarcodeFormat.values)
              if (f.symbology == format.symbology) f,
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

  String get _fileName {
    final String base = _kind.name;
    return 'flutter_zxing_$base';
  }

  Future<void> _export(String what) async {
    final String data = _data;
    final BarcodeWriter writer = BarcodeWriter(_format, errorCorrection: _ecc);
    try {
      // XFile.fromData has no path off the web, so its own name is empty:
      // the share needs the name given separately.
      final String name = '$_fileName.${what == 'svg' ? 'svg' : 'png'}';
      final XFile file = switch (what) {
        'svg' => XFile.fromData(
          Uint8List.fromList(
            utf8.encode(await writer.toSvg(data, style: _style)),
          ),
          mimeType: 'image/svg+xml',
          name: '$_fileName.svg',
        ),
        _ => XFile.fromData(
          await writer.toPng(data, size: 1024, style: _style),
          mimeType: 'image/png',
          name: '$_fileName.png',
        ),
      };
      HistoryStore.instance.addCreated(data, _format, _preset ?? 'custom');
      if (!mounted) {
        return;
      }
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[file],
          fileNameOverrides: <String>[name],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on BarcodeWriteException catch (e) {
      _toast(e.message);
    } on UnsupportedError catch (e) {
      _toast(e.message ?? 'Not supported here');
    }
  }

  Future<void> _copyDart() async {
    await Clipboard.setData(
      ClipboardData(
        text: dartCode(
          _data,
          _format,
          _style,
          presetName: _preset,
          errorCorrection: _ecc,
        ),
      ),
    );
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
  Widget build(BuildContext context) =>
      widget.wide ? _buildWide(context) : _buildPhone(context);

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
        ReadCheck(reads: _reads, invalid: _error != null),
      ],
    ),
  );

  /// Everything but the code card: the kinds, the form, the style. The
  /// title goes first in the wide layout; the phone keeps it above the card.
  List<Widget> _sections(
    BuildContext context, {
    bool title = false,
  }) => <Widget>[
    if (title) ...<Widget>[_title(context), const SizedBox(height: 14)],
    if (_anyText) ...<Widget>[_KindChips(this), const SizedBox(height: 18)]
    // Room for the field's floating label.
    else
      const SizedBox(height: 10),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _Form(this),
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

  /// The phone layout split in two: the code card on the left, filling the
  /// height, and the rest on the right, scrolling.
  Widget _buildWide(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Expanded(
        // The same 12 points above and below the card: the bottom inset is
        // left out, as it is at the top, where landscape has none.
        child: SafeArea(
          right: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _codeCard(fill: true),
          ),
        ),
      ),
      Expanded(
        child: SafeArea(
          left: false,
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
            children: _sections(context, title: true),
          ),
        ),
      ),
    ],
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
          dartCode(
            page._data,
            page._format,
            page._style,
            presetName: page._preset,
            errorCorrection: page._ecc,
          ),
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

class _KindChips extends StatelessWidget {
  const _KindChips(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = <Widget>[
      for (final CreateKind k in CreateKind.values)
        ChoiceChip(
          avatar: page._kind == k
              ? Icon(k.icon, size: 18, color: Fz.of(context).raised)
              : null,
          label: Text(k.label),
          selected: page._kind == k && page._raw == null,
          onSelected: (_) {
            page._update(() {
              page._kind = k;
              page._raw = null;
              page._fillDefaults();
            });
            page._scheduleCheck();
          },
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          for (final Widget c in chips)
            Padding(padding: const EdgeInsets.only(right: 8), child: c),
        ],
      ),
    );
  }
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
        keyboardType: input.digits ? TextInputType.number : TextInputType.text,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (String key, String label, String _) in page._kind.fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: page._fields[key],
              decoration: InputDecoration(labelText: label),
              keyboardType: switch (key) {
                'url' => TextInputType.url,
                'email' || 'to' => TextInputType.emailAddress,
                'phone' || 'number' => TextInputType.phone,
                'text' => TextInputType.multiline,
                _ => TextInputType.text,
              },
              maxLines: key == 'text' ? null : 1,
              style: key == 'password'
                  ? const TextStyle(fontFamily: 'monospace')
                  : null,
            ),
          ),
        if (page._kind == CreateKind.wifi)
          SegmentedButton<WifiSecurity>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<WifiSecurity>>[
              ButtonSegment<WifiSecurity>(
                value: WifiSecurity.wpa,
                label: Text('WPA / WPA2'),
              ),
              ButtonSegment<WifiSecurity>(
                value: WifiSecurity.wep,
                label: Text('WEP'),
              ),
              ButtonSegment<WifiSecurity>(
                value: WifiSecurity.none,
                label: Text('None'),
              ),
            ],
            selected: <WifiSecurity>{page._security},
            onSelectionChanged: (Set<WifiSecurity> s) {
              page._update(() => page._security = s.first);
              page._scheduleCheck();
            },
          ),
      ],
    );
  }
}

class _FormatMenu extends StatelessWidget {
  const _FormatMenu(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) => PopupMenuButton<BarcodeFormat>(
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
          format: format,
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
    final ErrorCorrection? ecc = page._ecc;
    final bool qr = format.symbology == BarcodeFormat.qrCode;
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
          child: Text(page._style.logo != null && qr ? 'Auto (H)' : 'Auto'),
        ),
        for (final ErrorCorrection e in ErrorCorrection.values)
          PopupMenuItem<int>(value: e.index, child: Text(label(e))),
      ],
      child: _Pill(ecc == null ? 'ECC auto' : 'ECC ${eccLabel(format, ecc)}'),
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
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.expand_more_rounded, size: 18),
      ],
    ),
  );
}

class _Preview extends StatelessWidget {
  const _Preview(this.page, {required this.size});

  final _CreatePageState page;
  final double size;

  @override
  Widget build(BuildContext context) {
    final BarcodeStyle style = page._style;
    final bool square = page._square;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: square ? size : size * 1.4,
      height: square ? size : size * 0.7,
      // The symbology's own quiet zone (four modules around a QR code) looks
      // like empty space on screen: the tile keeps a narrower margin in its
      // place. Exports keep the full one.
      padding: EdgeInsets.all(style.quietZone ? size * 0.07 : 6),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: BarcodeView(
        page._data,
        format: page._format,
        errorCorrection: page._ecc,
        style: style.copyWith(quietZone: false),
        errorBuilder: (BuildContext context, BarcodeWriteException e) => Center(
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
      const PopupMenuItem<String>(value: 'png', child: Text('Share')),
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
                  onTap: () => page._setStyle(
                    page._style.logo == null
                        ? p.value
                        : p.value.copyWith(logo: page._style.logo),
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
