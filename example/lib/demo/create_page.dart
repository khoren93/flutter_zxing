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

/// The formats the generator offers.
const List<BarcodeFormat> _formats = <BarcodeFormat>[
  BarcodeFormat.qrCode,
  BarcodeFormat.dataMatrix,
  BarcodeFormat.aztec,
  BarcodeFormat.pdf417,
  BarcodeFormat.code128,
];

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

  String get _data =>
      _raw ??
      _kind.encode(<String, String>{
        for (final MapEntry<String, TextEditingController> e in _fields.entries)
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
      bool ok;
      try {
        final Uint8List png = await BarcodeWriter(
          _format,
        ).toPng(data, moduleSize: 4, style: _style);
        final Barcode? read = await BarcodeReader(
          formats: <BarcodeFormat>{_format},
        ).read(png);
        ok = read?.text == data;
      } on Object {
        ok = false;
      }
      if (mounted && run == _check) {
        setState(() => _reads = ok);
      }
    });
  }

  String get _fileName {
    final String base = _kind.name;
    return 'flutter_zxing_$base';
  }

  Future<void> _export(String what) async {
    final String data = _data;
    final BarcodeWriter writer = BarcodeWriter(_format);
    try {
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
          fileNameOverrides: <String>[file.name],
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
        text: dartCode(_data, _format, _style, presetName: _preset),
      ),
    );
    _toast('Dart code copied');
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _openStyleSheet() {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Fz.of(context).raised,
        builder: (BuildContext context) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheet) =>
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Style',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () => unawaited(_copyDart()),
                          child: const Text('Copy as Dart'),
                        ),
                        TextButton(
                          onPressed: () {
                            _setStyle(BarcodeStyle.classic, preset: 'classic');
                            setSheet(() {});
                          },
                          child: Text(
                            'Reset',
                            style: TextStyle(color: Fz.of(context).inkMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(child: _Preview(this, size: 168)),
                    const SizedBox(height: 16),
                    StyleEditor(
                      style: _style,
                      format: _format,
                      onChanged: (BarcodeStyle s) {
                        _setStyle(s);
                        setSheet(() {});
                      },
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      widget.wide ? _buildWide(context) : _buildPhone(context);

  Widget _buildPhone(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(
      0,
      MediaQuery.paddingOf(context).top + 12,
      0,
      120,
    ),
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Create',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      const SizedBox(height: 14),
      _KindChips(this, scroll: true),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FzCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _FormatMenu(this),
                  const Spacer(),
                  ReadCheck(reads: _reads),
                ],
              ),
              const SizedBox(height: 12),
              Center(child: _Preview(this, size: 216)),
              const SizedBox(height: 12),
              _ExportRow(this),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: <Widget>[
            const Expanded(child: FzLabel('Style')),
            TextButton(
              onPressed: _openStyleSheet,
              child: const Text('Customize'),
            ),
          ],
        ),
      ),
      _Presets(this),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _Form(this),
      ),
    ],
  );

  Widget _buildWide(BuildContext context) {
    final Fz fz = Fz.of(context);
    // Two equal columns: the code and its export on the left, the settings
    // on the right.
    final Widget preview = ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Create', style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            ReadCheck(reads: _reads, long: true),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            // Sized by the width and the height both: on a phone in
            // landscape the code, the export buttons and the title still fit
            // on one screen.
            final double side = math
                .min(c.maxWidth - 64, MediaQuery.sizeOf(context).height - 190)
                .clamp(140, 300);
            return FzCard(
              child: SizedBox(
                height: side + 24,
                child: Center(child: _Preview(this, size: side)),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        _ExportRow(this),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            const Expanded(child: FzLabel('In your app')),
            TextButton(
              onPressed: () => unawaited(_copyDart()),
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
            border: Border.all(color: fz.line),
          ),
          child: SelectableText(
            dartCode(_data, _format, _style, presetName: _preset),
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
    final Widget settings = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: fz.line)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: FzLabel('Content')),
              _FormatMenu(this),
            ],
          ),
          const SizedBox(height: 12),
          _KindChips(this, scroll: false),
          const SizedBox(height: 16),
          _Form(this),
          const SizedBox(height: 24),
          const FzLabel('Style'),
          const SizedBox(height: 10),
          _Presets(this, padding: EdgeInsets.zero),
          const SizedBox(height: 18),
          StyleEditor(
            style: _style,
            format: _format,
            compact: true,
            onChanged: _setStyle,
          ),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: preview),
        Expanded(child: settings),
      ],
    );
  }
}

class _KindChips extends StatelessWidget {
  const _KindChips(this.page, {required this.scroll});

  final _CreatePageState page;
  final bool scroll;

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
    if (!scroll) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }
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
    onSelected: (BarcodeFormat f) {
      page._update(() => page._format = f);
      page._scheduleCheck();
    },
    itemBuilder: (BuildContext context) => <PopupMenuEntry<BarcodeFormat>>[
      for (final BarcodeFormat f in _formats)
        PopupMenuItem<BarcodeFormat>(value: f, child: Text(f.displayName)),
    ],
    child: Container(
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
            page._format.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
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
    final bool square =
        page._format != BarcodeFormat.pdf417 &&
        page._format != BarcodeFormat.code128;
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

class _ExportRow extends StatelessWidget {
  const _ExportRow(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        flex: 14,
        child: FilledButton.icon(
          onPressed: () => unawaited(page._export('png')),
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: const Text('Share'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 10,
        child: OutlinedButton(
          onPressed: () => unawaited(page._export('png')),
          child: const Text('PNG'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 10,
        child: OutlinedButton(
          onPressed: page._style.gradient is SweepGradient
              ? null
              : () => unawaited(page._export('svg')),
          child: const Text('SVG'),
        ),
      ),
    ],
  );
}

class _Presets extends StatelessWidget {
  const _Presets(
    this.page, {
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final _CreatePageState page;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    String title(String s) => '${s[0].toUpperCase()}${s.substring(1)}';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
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
