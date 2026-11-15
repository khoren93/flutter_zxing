import 'package:flutter/widgets.dart';

/// A line icon of the scanner widgets, drawn from SVG path data in a 24 × 24
/// box. The scanner draws its own icons, so it needs no icon font.
///
/// [stroke] is drawn with round caps and joins, [fill] is filled; both use
/// the icon's color.
@immutable
final class ScannerIconData {
  /// Creates an icon from SVG path data (`M`, `L`, `H`, `V`, `A`, `C`, `Q`,
  /// `Z` and their relative forms) in a 24 × 24 box.
  const ScannerIconData({
    this.stroke = '',
    this.fill = '',
    this.strokeWidth = 1.8,
  });

  /// Path data drawn as lines.
  final String stroke;

  /// Path data filled.
  final String fill;

  /// Line width in the 24 × 24 box.
  final double strokeWidth;

  @override
  bool operator ==(Object other) =>
      other is ScannerIconData &&
      other.stroke == stroke &&
      other.fill == fill &&
      other.strokeWidth == strokeWidth;

  @override
  int get hashCode => Object.hash(stroke, fill, strokeWidth);
}

/// The icons of the scanner widgets.
abstract final class ScannerIcons {
  static const String _camera =
      'M3 8.5A1.5 1.5 0 0 1 4.5 7H7l1.5-2h7L17 7h2.5A1.5 1.5 0 0 1 21 8.5 '
      'v9a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5z';
  static const String _torch =
      'M8 3h8v3l-2 4v10a1 1 0 0 1-1 1h-2a1 1 0 0 1-1-1V10L8 6z';

  /// A cross.
  static const ScannerIconData close = ScannerIconData(
    stroke: 'M6 6l12 12M18 6L6 18',
    strokeWidth: 2,
  );

  /// A torch, crossed out: the torch is off.
  static const ScannerIconData torchOff = ScannerIconData(
    stroke: '${_torch}M4 4l16 16',
  );

  /// A torch, filled: the torch is on.
  static const ScannerIconData torchOn = ScannerIconData(
    stroke: _torch,
    fill: _torch,
  );

  /// A picture: read a code from a photo.
  static const ScannerIconData photo = ScannerIconData(
    stroke:
        'M5 4h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z '
        'M3 16l5-5 4 4 3-3 6 6 '
        'M14.5 9a1.5 1.5 0 1 0 3 0a1.5 1.5 0 1 0-3 0z',
  );

  /// A camera with turning arrows.
  static const ScannerIconData switchCamera = ScannerIconData(
    stroke: '${_camera}M9 13a3 3 0 0 1 5.2-2M15 13a3 3 0 0 1-5.2 2',
  );

  /// A QR code.
  static const ScannerIconData qrCode = ScannerIconData(
    stroke:
        'M5 4h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1z '
        'M15 4h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1z '
        'M5 14h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-4a1 1 0 0 1 1-1z '
        'M14 14h2v2h-2zM18 18h2v2h-2zM18 14h2M14 18h2',
  );

  /// Bars of a linear barcode.
  static const ScannerIconData barcode = ScannerIconData(
    stroke: 'M4 5v14M7 5v14M10 5v14M14 5v14M16.5 5v14M20 5v14',
  );

  /// An arrow out of a box: open.
  static const ScannerIconData open = ScannerIconData(
    stroke:
        'M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7 '
        'a1 1 0 0 1 1-1h5',
    strokeWidth: 2,
  );

  /// Two sheets: copy.
  static const ScannerIconData copy = ScannerIconData(
    stroke:
        'M10 8h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-8a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2z '
        'M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3',
    strokeWidth: 2,
  );

  /// A check mark.
  static const ScannerIconData check = ScannerIconData(
    stroke: 'M5 12.5l4.5 4.5L19 7.5',
    strokeWidth: 2,
  );

  /// Wi‑Fi waves.
  static const ScannerIconData wifi = ScannerIconData(
    stroke:
        'M2 9a15 15 0 0 1 20 0M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0',
    fill: 'M10.8 19.5a1.2 1.2 0 1 0 2.4 0a1.2 1.2 0 1 0-2.4 0z',
  );

  /// Chain links.
  static const ScannerIconData link = ScannerIconData(
    stroke:
        'M10 14a4 4 0 0 0 5.66 0l3-3a4 4 0 0 0-5.66-5.66l-1 1 '
        'M14 10a4 4 0 0 0-5.66 0l-3 3a4 4 0 0 0 5.66 5.66l1-1',
  );

  /// A person.
  static const ScannerIconData contact = ScannerIconData(
    stroke: 'M8 8a4 4 0 1 0 8 0a4 4 0 1 0-8 0zM4 20a8 8 0 0 1 16 0',
  );

  /// A calendar.
  static const ScannerIconData event = ScannerIconData(
    stroke:
        'M5 5h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z '
        'M3 10h18M8 3v4M16 3v4',
  );

  /// An envelope.
  static const ScannerIconData email = ScannerIconData(
    stroke:
        'M5 5h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z '
        'M3 7l9 6 9-6',
  );

  /// A phone handset.
  static const ScannerIconData phone = ScannerIconData(
    stroke:
        'M5 4h3.5l2 5-2.5 1.5a11 11 0 0 0 5.5 5.5l1.5-2.5 5 2V19a1 1 0 0 1-1 1 '
        'A16 16 0 0 1 4 5a1 1 0 0 1 1-1z',
  );

  /// A speech bubble.
  static const ScannerIconData sms = ScannerIconData(
    stroke: 'M6 5h12a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H9l-5 3.5V7a2 2 0 0 1 2-2z',
  );

  /// A map pin.
  static const ScannerIconData location = ScannerIconData(
    stroke:
        'M12 21C12 21 5 14.8 5 10a7 7 0 0 1 14 0c0 4.8-7 11-7 11z '
        'M9.5 10a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0z',
  );

  /// A parcel: GS1 data.
  static const ScannerIconData parcel = ScannerIconData(
    stroke: 'M3 7.5L12 3l9 4.5v9L12 21l-9-4.5zM3 7.5l9 4.5 9-4.5M12 12v9',
  );

  /// Lines of text.
  static const ScannerIconData text = ScannerIconData(
    stroke: 'M5 6h14M5 10h14M5 14h10M5 18h7',
  );

  /// Ones and zeros: binary data.
  static const ScannerIconData binary = ScannerIconData(
    stroke: 'M6 4h3v7H6zM15 4v7M6 13v7M15 13h3v7h-3z',
  );

  /// A camera, crossed out: no camera permission.
  static const ScannerIconData cameraOff = ScannerIconData(
    stroke: '${_camera}M8.5 13a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0-7 0zM3 3l18 18',
  );

  /// A camera with an exclamation mark: the camera failed.
  static const ScannerIconData cameraAlert = ScannerIconData(
    stroke: '${_camera}M12 10v3.5',
    fill: 'M10.9 16.2a1.1 1.1 0 1 0 2.2 0a1.1 1.1 0 1 0-2.2 0z',
  );
}

/// Draws a [ScannerIconData].
class ScannerIcon extends StatelessWidget {
  /// Creates an icon.
  const ScannerIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  /// The icon.
  final ScannerIconData icon;

  /// Width and height in logical pixels.
  final double size;

  /// The color; default the color of the surrounding text.
  final Color? color;

  /// Read by screen readers; `null` hides the icon from them.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color color =
        this.color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFF000000);
    final Widget painted = CustomPaint(
      size: Size.square(size),
      painter: _IconPainter(icon, color),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: painted)
        : Semantics(label: semanticLabel, image: true, child: painted);
  }
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this.icon, this.color);

  final ScannerIconData icon;
  final Color color;

  static final Map<String, Path> _paths = <String, Path>{};

  static Path _path(String data) => _paths[data] ??= svgPath(data);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 24, size.height / 24);
    if (icon.fill.isNotEmpty) {
      canvas.drawPath(_path(icon.fill), Paint()..color = color);
    }
    if (icon.stroke.isNotEmpty) {
      canvas.drawPath(
        _path(icon.stroke),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = icon.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color;
}

final RegExp _token = RegExp(
  r'[A-DF-Za-df-z]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?',
);

/// Parses SVG path data: `M`, `L`, `H`, `V`, `A`, `C`, `Q`, `Z` and their
/// relative forms.
@visibleForTesting
Path svgPath(String data) {
  final Path path = Path();
  final List<String> tokens = <String>[
    for (final Match m in _token.allMatches(data)) m[0]!,
  ];
  int i = 0;
  String command = 'M';
  Offset current = Offset.zero;
  Offset start = Offset.zero;
  double next() => double.parse(tokens[i++]);
  bool isCommand(String t) => RegExp('^[A-Za-z]').hasMatch(t);

  while (i < tokens.length) {
    if (isCommand(tokens[i])) {
      command = tokens[i++];
    }
    final bool relative = command.toLowerCase() == command;
    Offset point(double x, double y) =>
        relative ? current + Offset(x, y) : Offset(x, y);
    switch (command.toUpperCase()) {
      case 'M':
        current = point(next(), next());
        start = current;
        path.moveTo(current.dx, current.dy);
        // Further pairs after a moveto are linetos.
        command = relative ? 'l' : 'L';
      case 'L':
        current = point(next(), next());
        path.lineTo(current.dx, current.dy);
      case 'H':
        final double x = next();
        current = Offset(relative ? current.dx + x : x, current.dy);
        path.lineTo(current.dx, current.dy);
      case 'V':
        final double y = next();
        current = Offset(current.dx, relative ? current.dy + y : y);
        path.lineTo(current.dx, current.dy);
      case 'A':
        final double rx = next();
        final double ry = next();
        final double rotation = next();
        final bool largeArc = next() != 0;
        final bool clockwise = next() != 0;
        current = point(next(), next());
        path.arcToPoint(
          current,
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: clockwise,
        );
      case 'C':
        final Offset c1 = point(next(), next());
        final Offset c2 = point(next(), next());
        current = point(next(), next());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, current.dx, current.dy);
      case 'Q':
        final Offset c = point(next(), next());
        current = point(next(), next());
        path.quadraticBezierTo(c.dx, c.dy, current.dx, current.dy);
      case 'Z':
        path.close();
        current = start;
      default:
        throw FormatException('Unsupported path command', data);
    }
  }
  return path;
}
