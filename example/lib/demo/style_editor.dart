// Edits a BarcodeStyle: module and finder shapes, a color or a gradient,
// the background, a logo and the quiet zone.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image_picker/image_picker.dart';

import 'tokens.dart';

/// The colors offered for the modules, and the gradients built from them.
const List<(String, Color)> _inks = <(String, Color)>[
  ('Black', Color(0xFF0E1218)),
  ('Navy', Color(0xFF0B3D91)),
  ('Green', Color(0xFF00735D)),
  ('Plum', Color(0xFF5B2A86)),
  ('Rust', Color(0xFFB4380E)),
  ('Crimson', Color(0xFFB0123B)),
];

const List<(String, Color, Color)> _gradients = <(String, Color, Color)>[
  ('Lagoon', Color(0xFF00735D), Color(0xFF1D4ED8)),
  ('Dusk', Color(0xFF5B2A86), Color(0xFF0B3D91)),
  ('Ember', Color(0xFFB4380E), Color(0xFF5B2A86)),
  ('Berry', Color(0xFFB0123B), Color(0xFF3730A3)),
  ('Ocean', Color(0xFF0E7490), Color(0xFF0B3D91)),
  ('Forest', Color(0xFF00735D), Color(0xFF0E1218)),
];

const List<(String, Color)> _grounds = <(String, Color)>[
  ('White', Color(0xFFFFFFFF)),
  ('Cream', Color(0xFFF4EFE4)),
  ('Mist', Color(0xFFE8F1FF)),
  ('Mint', Color(0xFFE6F4EA)),
  ('Blush', Color(0xFFFBE9EC)),
  ('Lemon', Color(0xFFFFF6D6)),
];

/// A style with every field given, so that a gradient or a logo can be
/// taken away (copyWith keeps a field when given null).
BarcodeStyle rebuildStyle(
  BarcodeStyle s, {
  Color? color,
  Color? backgroundColor,
  Gradient? Function()? gradient,
  ModuleShape? moduleShape,
  FinderShape? finderShape,
  bool? quietZone,
  BarcodeLogo? Function()? logo,
  BarcodeCaption? Function()? title,
  BarcodeCaption? Function()? caption,
  BarcodeCard? Function()? card,
}) => BarcodeStyle(
  color: color ?? s.color,
  backgroundColor: backgroundColor ?? s.backgroundColor,
  gradient: gradient == null ? s.gradient : gradient(),
  moduleShape: moduleShape ?? s.moduleShape,
  finderShape: finderShape ?? s.finderShape,
  quietZone: quietZone ?? s.quietZone,
  logo: logo == null ? s.logo : logo(),
  title: title == null ? s.title : title(),
  caption: caption == null ? s.caption : caption(),
  card: card == null ? s.card : card(),
);

/// A sample logo drawn in code: the demo ships no image files.
Future<Uint8List> sampleLogoPng() async {
  const double s = 128;
  final ui.PictureRecorder r = ui.PictureRecorder();
  final Canvas c = Canvas(r)
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, s, s),
        const Radius.circular(30),
      ),
      Paint()..color = const Color(0xFF0E1218),
    );
  final Paint arc = Paint()
    ..color = Fz.lock
    ..style = PaintingStyle.stroke
    ..strokeWidth = 11
    ..strokeCap = StrokeCap.round;
  for (final double radius in <double>[44, 28]) {
    c.drawArc(
      Rect.fromCircle(center: const Offset(64, 88), radius: radius),
      -3.1416 * 0.78,
      3.1416 * 0.56,
      false,
      arc,
    );
  }
  c.drawCircle(const Offset(64, 88), 8, Paint()..color = Fz.lock);
  final ui.Image image = await r.endRecording().toImage(128, 128);
  final ByteData png = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!;
  image.dispose();
  return png.buffer.asUint8List();
}

class StyleEditor extends StatelessWidget {
  const StyleEditor({
    super.key,
    required this.style,
    required this.onChanged,
    required this.format,
    this.compact = false,
  });

  final BarcodeStyle style;
  final ValueChanged<BarcodeStyle> onChanged;
  final BarcodeFormat format;

  /// Segmented rows instead of tiles (the desktop column).
  final bool compact;

  bool get _shapes => switch (format) {
    BarcodeFormat.qrCode ||
    BarcodeFormat.aztec ||
    BarcodeFormat.aztecRune ||
    BarcodeFormat.dataMatrix => true,
    _ => false,
  };

  Future<void> _pickLogo(BuildContext context) async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
    );
    if (file == null) {
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    onChanged(
      rebuildStyle(
        style,
        logo: () =>
            BarcodeLogo(MemoryImage(bytes), size: style.logo?.size ?? 0.24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final Gradient? gradient = style.gradient;
    final bool isGradient = gradient != null;
    final BarcodeLogo? logo = style.logo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_shapes) ...<Widget>[
          const FzLabel('Modules'),
          const SizedBox(height: 8),
          _Options<ModuleShape>(
            compact: compact,
            value: style.moduleShape,
            options: const <(ModuleShape, String, IconData)>[
              (ModuleShape.square, 'Square', Icons.grid_view_sharp),
              (ModuleShape.rounded, 'Rounded', Icons.grid_view_rounded),
              (ModuleShape.circle, 'Dots', Icons.blur_on_rounded),
            ],
            onChanged: (ModuleShape m) =>
                onChanged(rebuildStyle(style, moduleShape: m)),
          ),
          const SizedBox(height: 16),
        ],
        if (format == BarcodeFormat.qrCode) ...<Widget>[
          const FzLabel('Eyes'),
          const SizedBox(height: 8),
          _Options<FinderShape>(
            compact: compact,
            value: style.finderShape,
            options: const <(FinderShape, String, IconData)>[
              (FinderShape.square, 'Square', Icons.crop_square_rounded),
              (FinderShape.rounded, 'Rounded', Icons.rounded_corner_rounded),
              (
                FinderShape.circle,
                'Circle',
                Icons.radio_button_checked_rounded,
              ),
            ],
            onChanged: (FinderShape f) =>
                onChanged(rebuildStyle(style, finderShape: f)),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: <Widget>[
            const Expanded(child: FzLabel('Color')),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text('Solid')),
                ButtonSegment<bool>(value: true, label: Text('Gradient')),
              ],
              selected: <bool>{isGradient},
              onSelectionChanged: (Set<bool> s) => onChanged(
                rebuildStyle(
                  style,
                  gradient: () => s.first
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[_gradients[0].$2, _gradients[0].$3],
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            if (!isGradient)
              for (final (String name, Color c) in _inks)
                _Swatch(
                  label: name,
                  fill: BoxDecoration(color: c, shape: BoxShape.circle),
                  selected: style.color == c,
                  onTap: () => onChanged(rebuildStyle(style, color: c)),
                )
            else
              for (final (String name, Color a, Color b) in _gradients)
                _Swatch(
                  label: name,
                  fill: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: <Color>[a, b]),
                  ),
                  selected:
                      gradient.colors.length == 2 &&
                      gradient.colors[0] == a &&
                      gradient.colors[1] == b,
                  onTap: () => onChanged(
                    rebuildStyle(
                      style,
                      gradient: () => LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[a, b],
                      ),
                    ),
                  ),
                ),
          ],
        ),
        const SizedBox(height: 16),
        const FzLabel('Background'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final (String name, Color c) in _grounds)
              _Swatch(
                label: name,
                fill: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: fz.line),
                ),
                selected: style.backgroundColor == c,
                onTap: () => onChanged(rebuildStyle(style, backgroundColor: c)),
              ),
          ],
        ),
        if (format == BarcodeFormat.qrCode) ...<Widget>[
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              const Expanded(child: FzLabel('Logo')),
              Text(
                logo == null
                    ? ''
                    : 'Error correction: '
                          '${const <String>['L', 'M', 'Q', 'H'][logo.neededErrorCorrection.index]}',
                style: TextStyle(fontSize: 13, color: fz.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _LogoTile(logo: logo, onTap: () => unawaited(_pickLogo(context))),
              const SizedBox(width: 12),
              if (logo == null) ...<Widget>[
                OutlinedButton(
                  onPressed: () async {
                    final Uint8List png = await sampleLogoPng();
                    onChanged(
                      rebuildStyle(
                        style,
                        logo: () => BarcodeLogo(MemoryImage(png), size: 0.24),
                      ),
                    );
                  },
                  child: const Text('Sample logo'),
                ),
              ] else ...<Widget>[
                Expanded(
                  child: Slider(
                    value: logo.size,
                    min: 0.12,
                    max: 0.3,
                    label: '${(logo.size * 100).round()}%',
                    semanticFormatterCallback: (double v) =>
                        '${(v * 100).round()}% of the width',
                    activeColor: fz.ink,
                    onChanged: (double v) => onChanged(
                      rebuildStyle(
                        style,
                        logo: () => BarcodeLogo(logo.image, size: v),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove the logo',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () =>
                      onChanged(rebuildStyle(style, logo: () => null)),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 16),
        TextAndCard(style: style, onChanged: onChanged),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Quiet zone',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'The blank margin readers need',
            style: TextStyle(color: fz.inkMuted),
          ),
          value: style.quietZone,
          onChanged: (bool v) => onChanged(rebuildStyle(style, quietZone: v)),
        ),
      ],
    );
  }
}

class _Options<T> extends StatelessWidget {
  const _Options({
    required this.value,
    required this.options,
    required this.onChanged,
    required this.compact,
  });

  final T value;
  final List<(T, String, IconData)> options;
  final ValueChanged<T> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    if (compact) {
      return SegmentedButton<T>(
        showSelectedIcon: false,
        segments: <ButtonSegment<T>>[
          for (final (T v, String label, IconData _) in options)
            ButtonSegment<T>(value: v, label: Text(label)),
        ],
        selected: <T>{value},
        onSelectionChanged: (Set<T> s) => onChanged(s.first),
      );
    }
    return Row(
      children: <Widget>[
        for (final (int i, (T v, String label, IconData icon))
            in options.indexed) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: v == value,
              child: Material(
                color: v == value ? fz.raised : fz.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: v == value ? fz.ink : fz.line,
                    width: v == value ? 2 : 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(v),
                  child: SizedBox(
                    height: 72,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(icon, size: 26),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.fill,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final BoxDecoration fill;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? fz.ink : Colors.transparent,
                width: 2,
              ),
            ),
            child: DecoratedBox(decoration: fill),
          ),
        ),
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile({required this.logo, required this.onTap});

  final BarcodeLogo? logo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final BarcodeLogo? l = logo;
    return Tooltip(
      message: 'Choose a logo from your photos',
      child: Material(
        color: fz.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: fz.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 48,
            child: l == null
                ? const Icon(Icons.add_photo_alternate_outlined)
                : Image(image: l.image, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

/// Text sizes of the editor, as fractions of the code's width.
const List<(String, double)> _textSizes = <(String, double)>[
  ('S', 0.06),
  ('M', 0.09),
  ('L', 0.12),
];

/// Card colors; `null` is the code's own background.
const List<(String, Color?)> _cards = <(String, Color?)>[
  ('Background', null),
  ('Black', Color(0xFF0E1218)),
  ('Cream', Color(0xFFF4EFE4)),
  ('Blue', Color(0xFFE8F0FF)),
];

/// Card corners: small, large.
const List<(String, double)> _corners = <(String, double)>[
  ('S', 0.05),
  ('L', 0.12),
];

/// Text above and under the code, and a card under all of it.
class TextAndCard extends StatefulWidget {
  const TextAndCard({super.key, required this.style, required this.onChanged});

  final BarcodeStyle style;
  final ValueChanged<BarcodeStyle> onChanged;

  @override
  State<TextAndCard> createState() => _TextAndCardState();
}

class _TextAndCardState extends State<TextAndCard> {
  late final TextEditingController _title = TextEditingController(
    text: widget.style.title?.text ?? '',
  );
  late final TextEditingController _caption = TextEditingController(
    text: widget.style.caption?.text ?? '',
  );

  @override
  void didUpdateWidget(TextAndCard old) {
    super.didUpdateWidget(old);
    // A preset or a reset replaced the style: show its text.
    void sync(TextEditingController c, BarcodeCaption? t) {
      if ((t?.text ?? '') != c.text) {
        c.text = t?.text ?? '';
      }
    }

    sync(_title, widget.style.title);
    sync(_caption, widget.style.caption);
  }

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    super.dispose();
  }

  double get _size =>
      widget.style.caption?.size ?? widget.style.title?.size ?? 0.09;

  /// Light text on a dark card; otherwise the code's color.
  TextStyle? _textStyle(BarcodeCard? card) {
    final Color? color = card?.color;
    return color != null && color.computeLuminance() < 0.3
        ? const TextStyle(color: Color(0xFFFFFFFF))
        : null;
  }

  BarcodeCaption? _line(String text, double size, BarcodeCard? card) =>
      text.trim().isEmpty
      ? null
      : BarcodeCaption(text.trim(), size: size, style: _textStyle(card));

  /// The style with this section's values.
  void _apply({
    String? title,
    String? caption,
    double? size,
    BarcodeCard? Function()? card,
  }) {
    final BarcodeCard? c = card == null ? widget.style.card : card();
    final double z = size ?? _size;
    widget.onChanged(
      rebuildStyle(
        widget.style,
        title: () => _line(title ?? _title.text, z, c),
        caption: () => _line(caption ?? _caption.text, z, c),
        card: () => c,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final BarcodeCard? card = widget.style.card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const FzLabel('Text'),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Above'),
                onChanged: (String v) => _apply(title: v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _caption,
                decoration: const InputDecoration(labelText: 'Below'),
                onChanged: (String v) => _apply(caption: v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<double>(
          showSelectedIcon: false,
          segments: <ButtonSegment<double>>[
            for (final (String label, double v) in _textSizes)
              ButtonSegment<double>(value: v, label: Text(label)),
          ],
          selected: <double>{
            _textSizes
                .map(((String, double) e) => e.$2)
                .reduce(
                  (double a, double b) =>
                      (a - _size).abs() <= (b - _size).abs() ? a : b,
                ),
          },
          onSelectionChanged: (Set<double> s) => _apply(size: s.first),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            const Expanded(child: FzLabel('Card')),
            Switch(
              value: card != null,
              onChanged: (bool on) => _apply(
                card: () => on ? const BarcodeCard(elevation: 0.03) : null,
              ),
            ),
          ],
        ),
        if (card != null) ...<Widget>[
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              for (final (String name, Color? c) in _cards)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _Swatch(
                    label: '$name card',
                    fill: BoxDecoration(
                      color: c ?? widget.style.backgroundColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: fz.line),
                    ),
                    selected: card.color == c,
                    onTap: () => _apply(
                      card: () => BarcodeCard(
                        color: c,
                        radius: card.radius,
                        elevation: card.elevation,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              SegmentedButton<double>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: <ButtonSegment<double>>[
                  for (final (String label, double v) in _corners)
                    ButtonSegment<double>(value: v, label: Text(label)),
                ],
                selected: <double>{
                  card.radius < 0.085 ? _corners[0].$2 : _corners[1].$2,
                },
                onSelectionChanged: (Set<double> s) => _apply(
                  card: () => BarcodeCard(
                    color: card.color,
                    radius: s.first,
                    elevation: card.elevation,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
