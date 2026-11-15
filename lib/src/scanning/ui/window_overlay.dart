import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../scanner_controller.dart';
import 'scanner_theme.dart';

/// The default overlay: [ScanWindowOverlay] and [BarcodeOutlines] in the
/// [ScannerTheme] of the scanner.
///
/// Use it in an `overlayBuilder` to keep the default look under your own
/// widgets:
///
/// ```dart
/// overlayBuilder: (context, layout) => Stack(
///   children: [ScannerOverlay(layout), MyButtons(layout.controller)],
/// )
/// ```
class ScannerOverlay extends StatelessWidget {
  /// Creates the default overlay.
  const ScannerOverlay(
    this.layout, {
    super.key,
    this.lockOn = true,
    this.settled = false,
  });

  /// The scanner layout.
  final ScannerLayout layout;

  /// Whether the window's brackets close in on a single barcode.
  final bool lockOn;

  /// A code has been taken into the window: the brackets frame the window
  /// in the accent color and the outlines are hidden.
  final bool settled;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      ScanWindowOverlay(layout, lockOn: lockOn, settled: settled),
      if (!settled) BarcodeOutlines(layout),
    ],
  );
}

/// Dims the camera outside the scan window and draws the window's corner
/// brackets.
///
/// While searching, the brackets breathe. When one barcode is in view they
/// close in on it in the accent color ([lockOn]); with several, they stay
/// on the window. Animations follow the platform's reduce motion setting.
class ScanWindowOverlay extends StatefulWidget {
  /// Creates the overlay.
  const ScanWindowOverlay(
    this.layout, {
    super.key,
    this.lockOn = true,
    this.settled = false,
  });

  /// The scanner layout.
  final ScannerLayout layout;

  /// Whether the brackets close in on a single barcode.
  final bool lockOn;

  /// The brackets frame the window in the accent color, as when the code
  /// found has been taken into it.
  final bool settled;

  @override
  State<ScanWindowOverlay> createState() => _ScanWindowOverlayState();
}

class _ScanWindowOverlayState extends State<ScanWindowOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final AnimationController _move = AnimationController(
    vsync: this,
    value: 1,
  );

  /// Where the brackets started moving from, and where they go: `null` is
  /// the scan window, which may itself change size.
  Rect? _from;
  Rect? _to;
  double _fromLock = 0;
  double _toLock = 0;

  /// Changes whenever the brackets get a new target, to repaint even
  /// without an animation.
  int _version = 0;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first time places the brackets; later (a new theme, reduce
    // motion turned on) only updates the animations.
    _retarget(initial: !_placed);
    _placed = true;
  }

  bool _placed = false;

  @override
  void didUpdateWidget(ScanWindowOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _retarget(initial: false);
  }

  @override
  void dispose() {
    _breathe.dispose();
    _move.dispose();
    super.dispose();
  }

  Rect? _target() {
    final List<VisibleBarcode> barcodes = widget.layout.barcodes;
    if (!widget.lockOn || widget.settled || barcodes.length != 1) {
      return null;
    }
    final Rect bounds = barcodes.single.bounds;
    // A little air around the code, and never smaller than a finger.
    final Rect padded = bounds.inflate(8);
    return Rect.fromCenter(
      center: padded.center,
      width: math.max(padded.width, 48),
      height: math.max(padded.height, 48),
    );
  }

  void _retarget({required bool initial}) {
    final Rect? target = _target();
    final ScannerStatus status = widget.layout.state.status;
    final bool searching =
        target == null &&
        !widget.settled &&
        status == ScannerStatus.running &&
        !_reduceMotion;
    if (searching && !_breathe.isAnimating) {
      unawaited(_breathe.repeat(reverse: true));
    } else if (!searching && _breathe.isAnimating) {
      _breathe
        ..stop()
        ..value = 0;
    }

    final double lock = target == null && !widget.settled ? 0 : 1;
    if (initial) {
      _from = _to = target;
      _fromLock = _toLock = lock;
      return;
    }
    if (target == _to && lock == _toLock) {
      return;
    }
    final Rect window = widget.layout.scanWindow;
    final double t = Curves.easeOutCubic.transform(_move.value);
    _from = Rect.lerp(_from ?? window, _to ?? window, t);
    _fromLock = lerpDouble(_fromLock, _toLock, t)!;
    final bool following = _to != null && target != null;
    _version++;
    _to = target;
    _toLock = lock;
    if (_reduceMotion) {
      _move.value = 1;
      return;
    }
    // Back to the window with the code that flies in: as long as its flight.
    _move.duration = Duration(
      milliseconds: following
          ? 140
          : widget.settled
          ? 360
          : 280,
    );
    unawaited(_move.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final ScannerLayout layout = widget.layout;
    final double radius = theme.resolvedWindowRadius;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          WindowScrim(window: layout.scanWindow, radius: radius),
          CustomPaint(
            size: layout.size,
            painter: BracketsPainter(
              repaint: Listenable.merge(<Listenable>[_breathe, _move]),
              rect: () {
                final double t = Curves.easeOutCubic.transform(_move.value);
                final Rect window = layout.scanWindow;
                return Rect.lerp(_from ?? window, _to ?? window, t)!;
              },
              lock: () => lerpDouble(
                _fromLock,
                _toLock,
                Curves.easeOutCubic.transform(_move.value),
              )!,
              scale: () =>
                  1 - 0.02 * Curves.easeInOut.transform(_breathe.value),
              radius: radius,
              color: theme.windowColor,
              lockColor: theme.lockColor,
              version: Object.hash(layout.scanWindow, _version),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dimmed camera outside the scan window.
///
/// Not blurred: a full-screen backdrop blur has to be computed again for
/// every camera frame, which a 2020 phone does not manage in a frame's time.
class WindowScrim extends StatelessWidget {
  /// Creates the scrim around [window], whose corners have [radius].
  const WindowScrim({super.key, required this.window, required this.radius});

  /// The scan window, left clear.
  final Rect window;

  /// Corner radius of the window.
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ScrimPainter(window, radius, ScannerTheme.of(context).scrimColor),
    child: const SizedBox.expand(),
  );
}

Path _outside(Size size, Rect window, double radius) => Path()
  ..fillType = PathFillType.evenOdd
  ..addRect(Offset.zero & size)
  ..addRRect(RRect.fromRectAndRadius(window, Radius.circular(radius)));

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter(this.window, this.radius, this.color);

  final Rect window;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawPath(_outside(size, window, radius), Paint()..color = color);

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.window != window || old.radius != radius || old.color != color;
}

/// Draws the four corner brackets of a scan window. Values are read when
/// painting, so animations repaint without rebuilding.
class BracketsPainter extends CustomPainter {
  /// Creates the painter.
  BracketsPainter({
    required Listenable repaint,
    required this.rect,
    required this.lock,
    required this.scale,
    required this.radius,
    required this.color,
    required this.lockColor,
    this.opacity,
    this.version = 0,
  }) : super(repaint: repaint);

  /// Repaints when it changes: the inputs of [rect] changed.
  final Object version;

  /// The rectangle the brackets frame.
  final Rect Function() rect;

  /// 0 on the window, 1 locked on a code.
  final double Function() lock;

  /// The breathing scale.
  final double Function() scale;

  /// Optional fading, for the starting state.
  final double Function()? opacity;

  /// Corner radius of the window; locked brackets have a smaller one.
  final double radius;

  /// Color of the brackets on the window.
  final Color color;

  /// Color of the brackets on a code.
  final Color lockColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double lock = this.lock();
    final double alpha = opacity?.call() ?? 1;
    final Rect r = rect();
    final double s = scale();
    final Path path = bracketPath(r, lerpDouble(radius, radius / 2.4, lock)!);
    canvas.save();
    if (s != 1) {
      canvas
        ..translate(r.center.dx, r.center.dy)
        ..scale(s)
        ..translate(-r.center.dx, -r.center.dy);
    }
    final Color stroke = Color.lerp(color, lockColor, lock)!;
    if (lock > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = lockColor.withValues(alpha: 0.65 * lock * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = stroke.withValues(alpha: stroke.a * alpha),
      )
      ..restore();
  }

  /// The four brackets of [r]: rounded corners with straight arms.
  static Path bracketPath(Rect r, double radius) {
    final double rr = math.min(radius, math.min(r.width, r.height) / 2);
    final double arm = (math.min(r.width, r.height) * 0.22).clamp(12, 44);
    final double reach = math.min(rr + arm, math.min(r.width, r.height) / 2);
    final Radius c = Radius.circular(rr);
    return Path()
      // Top left.
      ..moveTo(r.left, r.top + reach)
      ..lineTo(r.left, r.top + rr)
      ..arcToPoint(Offset(r.left + rr, r.top), radius: c)
      ..lineTo(r.left + reach, r.top)
      // Top right.
      ..moveTo(r.right - reach, r.top)
      ..lineTo(r.right - rr, r.top)
      ..arcToPoint(Offset(r.right, r.top + rr), radius: c)
      ..lineTo(r.right, r.top + reach)
      // Bottom right.
      ..moveTo(r.right, r.bottom - reach)
      ..lineTo(r.right, r.bottom - rr)
      ..arcToPoint(Offset(r.right - rr, r.bottom), radius: c)
      ..lineTo(r.right - reach, r.bottom)
      // Bottom left.
      ..moveTo(r.left + reach, r.bottom)
      ..lineTo(r.left + rr, r.bottom)
      ..arcToPoint(Offset(r.left, r.bottom - rr), radius: c)
      ..lineTo(r.left, r.bottom - reach);
  }

  @override
  bool shouldRepaint(BracketsPainter old) =>
      old.version != version ||
      old.radius != radius ||
      old.color != color ||
      old.lockColor != lockColor;
}

/// Outlines the barcodes in [ScannerLayout.barcodes] in the accent color.
class BarcodeOutlines extends StatelessWidget {
  /// Creates the overlay.
  const BarcodeOutlines(this.layout, {super.key, this.color});

  /// The scanner layout.
  final ScannerLayout layout;

  /// Outline color; default [ScannerTheme.lockColor].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final Color color = this.color ?? theme.lockColor;
    return IgnorePointer(
      child: CustomPaint(
        size: layout.size,
        painter: _OutlinePainter(
          layout.barcodes,
          color,
          this.color == null
              ? theme.lockSoftColor
              : color.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter(this.barcodes, this.color, this.fill);

  final List<VisibleBarcode> barcodes;
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final Paint area = Paint()..color = fill;
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    for (final VisibleBarcode barcode in barcodes) {
      final Path path = Path()..addPolygon(barcode.corners, true);
      canvas
        ..drawPath(path, glow)
        ..drawPath(path, area)
        ..drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter old) =>
      old.barcodes != barcodes || old.color != color || old.fill != fill;
}
