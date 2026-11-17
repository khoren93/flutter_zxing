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

  /// A banknote: a payment.
  static const ScannerIconData payment = ScannerIconData(
    stroke:
        'M4.5 6h15a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-15a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2z '
        'M9.5 12a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0zM6 9.5h0.01M18 14.5h0.01',
  );

  /// A key: a one-time password.
  static const ScannerIconData otp = ScannerIconData(
    stroke: 'M4 15a4 4 0 1 0 8 0a4 4 0 1 0-8 0zM11 12l9-9M16 7l3 3M14 9l2 2',
  );

  /// A SIM card: an eSIM.
  static const ScannerIconData esim = ScannerIconData(
    stroke:
        'M7 3h7l5 5v12a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM10 11h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1v-4a1 1 0 0 1 1-1z',
  );

  /// A coin: a cryptocurrency payment.
  static const ScannerIconData crypto = ScannerIconData(
    stroke:
        'M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0zM9.5 7.5h4a2.25 2.25 0 0 1 0 4.5h-4zM9.5 12h4.5a2.25 2.25 0 0 1 0 4.5H9.5zM9.5 7.5v9M11 6v1.5M11 16.5V18',
  );

  /// A router: a Wi‑Fi device to add.
  static const ScannerIconData wifiDevice = ScannerIconData(
    stroke:
        'M5 13h14a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2h-14a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2zM15 13V9.5M12 8Q15 5.5 18 8M9.5 5.5Q15 1 20.5 5.5',
    fill:
        'M6.2 16.5a0.8 0.8 0 1 0 1.6 0a0.8 0.8 0 1 0-1.6 0zM9.7 16.5a0.8 0.8 0 1 0 1.6 0a0.8 0.8 0 1 0-1.6 0z',
  );

  /// A house: a smart home device.
  static const ScannerIconData smartHome = ScannerIconData(
    stroke: 'M3 11l9-7 9 7M5 9.5V20h14V9.5M10 20v-5h4v5',
  );

  /// An airplane: a boarding pass.
  static const ScannerIconData boardingPass = ScannerIconData(
    stroke:
        'M3 13.5l7-2.5V5a2 2 0 0 1 4 0v6l7 2.5V16l-7-1.5v4l2 1.5v1.5L12 20.5 8 21.5V20l2-1.5v-4L3 16z',
  );

  /// An ID card: a driver's license.
  static const ScannerIconData driverLicense = ScannerIconData(
    stroke:
        'M5 5h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2h-14a2 2 0 0 1-2-2v-10a2 2 0 0 1 2-2zM7 11a2 2 0 1 0 4 0a2 2 0 1 0-4 0zM5.5 16c0.7-1.4 1.9-2 3.5-2c1.6 0 2.8 0.6 3.5 2M14.5 10h4M14.5 13h3',
  );

  /// A car: a vehicle identification number.
  static const ScannerIconData vehicle = ScannerIconData(
    stroke:
        'M4 16v-4l2.2-5A2 2 0 0 1 8 6h8a2 2 0 0 1 1.8 1L20 12v4M3 16h18v2a1 1 0 0 1-1 1h-2v-3M6 19H4a1 1 0 0 1-1-1M4 12h16',
    fill:
        'M6.7 15a0.8 0.8 0 1 0 1.6 0a0.8 0.8 0 1 0-1.6 0zM15.7 15a0.8 0.8 0 1 0 1.6 0a0.8 0.8 0 1 0-1.6 0z',
  );

  /// A book: an ISBN or ISSN.
  static const ScannerIconData book = ScannerIconData(
    stroke:
        'M5 5a2 2 0 0 1 2-2h12v15H7a2 2 0 0 0-2 2zM5 20a2 2 0 0 0 2 2h12v-4M9 7h6',
  );

  /// A video camera: a FaceTime call.
  static const ScannerIconData faceTime = ScannerIconData(
    stroke:
        'M5 7h8a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2h-8a2 2 0 0 1-2-2v-6a2 2 0 0 1 2-2zM15 11l6-3v8l-6-3',
  );

  /// A chat bubble: a link to a messenger.
  static const ScannerIconData messenger = ScannerIconData(
    stroke: 'M4 5h16v11H9l-5 4zM8 9.5h8M8 12.5h5',
  );

  /// A profile: a link to a social network.
  static const ScannerIconData profile = ScannerIconData(
    stroke:
        'M8.5 9a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0-7 0zM5 20c1.2-3.5 3.8-5 7-5c3.2 0 5.8 1.5 7 5',
  );

  /// A player: a link to a video service.
  static const ScannerIconData video = ScannerIconData(
    stroke:
        'M6 5h12a3 3 0 0 1 3 3v8a3 3 0 0 1-3 3h-12a3 3 0 0 1-3-3v-8a3 3 0 0 1 3-3zM10 9.5v5l4.5-2.5z',
  );

  /// A note: a link to a music service.
  static const ScannerIconData music = ScannerIconData(
    stroke:
        'M9 18V5l11-2v13M4 18a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0zM15 16a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0z',
  );

  /// Four tiles: a link to an app store.
  static const ScannerIconData apps = ScannerIconData(
    stroke:
        'M5.5 4h4a1.5 1.5 0 0 1 1.5 1.5v4a1.5 1.5 0 0 1-1.5 1.5h-4a1.5 1.5 0 0 1-1.5-1.5v-4a1.5 1.5 0 0 1 1.5-1.5zM14.5 4h4a1.5 1.5 0 0 1 1.5 1.5v4a1.5 1.5 0 0 1-1.5 1.5h-4a1.5 1.5 0 0 1-1.5-1.5v-4a1.5 1.5 0 0 1 1.5-1.5zM5.5 13h4a1.5 1.5 0 0 1 1.5 1.5v4a1.5 1.5 0 0 1-1.5 1.5h-4a1.5 1.5 0 0 1-1.5-1.5v-4a1.5 1.5 0 0 1 1.5-1.5zM14.5 13h4a1.5 1.5 0 0 1 1.5 1.5v4a1.5 1.5 0 0 1-1.5 1.5h-4a1.5 1.5 0 0 1-1.5-1.5v-4a1.5 1.5 0 0 1 1.5-1.5z',
  );

  /// A star: a link to write a review.
  static const ScannerIconData review = ScannerIconData(
    stroke:
        'M12 3.5l2.6 5.4 5.9 0.8-4.3 4.1 1 5.8L12 16.8l-5.2 2.8 1-5.8-4.3-4.1 5.9-0.8z',
  );

  /// An eye: show a hidden value.
  static const ScannerIconData show = ScannerIconData(
    stroke:
        'M2 12c0 0 3.5-7 10-7c6.5 0 10 7 10 7c0 0-3.5 7-10 7C5.5 19 2 12 2 12zM9 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0z',
  );

  /// An eye, crossed out: hide a value again.
  static const ScannerIconData hide = ScannerIconData(
    stroke:
        'M2 12c0 0 3.5-7 10-7c6.5 0 10 7 10 7c0 0-3.5 7-10 7C5.5 19 2 12 2 12zM9 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0zM4 4l16 16',
  );

  /// A plus: add.
  static const ScannerIconData add = ScannerIconData(
    stroke: 'M12 5v14M5 12h14',
    strokeWidth: 2,
  );

  /// A circle with an exclamation mark: a code that needs a look.
  static const ScannerIconData alert = ScannerIconData(
    stroke: 'M12 7.5v5.5M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0z',
    fill: 'M10.8 16.5a1.2 1.2 0 1 0 2.4 0a1.2 1.2 0 1 0-2.4 0z',
    strokeWidth: 2,
  );

  /// A person: people checked in.
  static const ScannerIconData person = ScannerIconData(
    stroke: 'M8 8a4 4 0 1 0 8 0a4 4 0 1 0-8 0zM4 21a8 8 0 0 1 16 0',
  );

  /// A magnifier with a plus: move closer to a small code.
  static const ScannerIconData closer = ScannerIconData(
    stroke: 'M5 11a6 6 0 1 0 12 0a6 6 0 1 0-12 0zM20 20l-4.5-4.5M11 8v6M8 11h6',
  );

  /// A plastic card: a loyalty card.
  static const ScannerIconData card = ScannerIconData(
    stroke:
        'M5.5 5h13A2.5 2.5 0 0 1 21 7.5v9a2.5 2.5 0 0 1-2.5 2.5h-13 '
        'A2.5 2.5 0 0 1 3 16.5v-9A2.5 2.5 0 0 1 5.5 5zM3 10h18M7 15h4',
  );

  /// Corners of a scan window around bars: scan a code into a field.
  static const ScannerIconData scan = ScannerIconData(
    stroke:
        'M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2 '
        'M8 20H6a2 2 0 0 1-2-2v-2M8 9v6M11 9v6M14 9v6M17 9v6',
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

final RegExp _number = RegExp(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

/// Parses SVG path data: `M`, `L`, `H`, `V`, `A`, `C`, `Q`, `Z` and their
/// relative forms, also minified (`a5 5 0 0110 0`: arc flags are single
/// digits). Throws [FormatException] on anything else.
@visibleForTesting
Path svgPath(String data) {
  final Path path = Path();
  int i = 0;
  void skip() {
    while (i < data.length && ' ,\t\n\r'.contains(data[i])) {
      i++;
    }
  }

  Never fail(String what) => throw FormatException(what, data, i);
  double next() {
    skip();
    final Match? m = _number.matchAsPrefix(data, i);
    if (m == null) {
      fail('Expected a number');
    }
    i = m.end;
    return double.parse(m[0]!);
  }

  bool flag() {
    skip();
    if (i < data.length && (data[i] == '0' || data[i] == '1')) {
      return data[i++] == '1';
    }
    fail('Expected an arc flag');
  }

  String? command;
  Offset current = Offset.zero;
  Offset start = Offset.zero;
  while (true) {
    skip();
    if (i >= data.length) {
      break;
    }
    final String c = data[i];
    if (RegExp('[A-Za-z]').hasMatch(c)) {
      command = c;
      i++;
    } else if (command == null || command.toUpperCase() == 'Z') {
      // Numbers need a command; Z takes none.
      fail('Expected a command');
    }
    final String cmd = command;
    final bool relative = cmd.toLowerCase() == cmd;
    Offset point(double x, double y) =>
        relative ? current + Offset(x, y) : Offset(x, y);
    switch (cmd.toUpperCase()) {
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
        final bool largeArc = flag();
        final bool clockwise = flag();
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
        final Offset q = point(next(), next());
        current = point(next(), next());
        path.quadraticBezierTo(q.dx, q.dy, current.dx, current.dy);
      case 'Z':
        path.close();
        current = start;
      default:
        i--;
        fail('Unsupported path command');
    }
  }
  return path;
}
