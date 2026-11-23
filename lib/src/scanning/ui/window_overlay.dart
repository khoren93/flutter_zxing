import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;
import 'dart:ui' show ImageFilter, lerpDouble;

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
    this.searching = true,
  });

  /// The scanner layout.
  final ScannerLayout layout;

  /// Whether the window's brackets close in on a single barcode.
  final bool lockOn;

  /// A code has been taken into the window: the brackets frame the window
  /// in the accent color and the outlines are hidden.
  final bool settled;

  /// Whether the scanner looks for a code; `false` holds the brackets'
  /// breathing and the scan line, as while a verdict shows.
  final bool searching;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      ScanWindowOverlay(
        layout,
        lockOn: lockOn,
        settled: settled,
        searching: searching,
      ),
      if (!settled) BarcodeOutlines(layout),
    ],
  );
}

/// Dims the camera outside the scan window and draws the window's corner
/// brackets.
///
/// While searching, the brackets breathe ([ScannerTheme.breathing]) and the
/// theme's [ScannerTheme.scanLine] runs across the window. When one barcode
/// is in view they close in on it in the accent color ([lockOn]); with
/// several, they stay on the window. The window takes the theme's
/// [ScannerTheme.windowShape]. Animations follow the platform's reduce
/// motion setting.
class ScanWindowOverlay extends StatefulWidget {
  /// Creates the overlay.
  const ScanWindowOverlay(
    this.layout, {
    super.key,
    this.lockOn = true,
    this.settled = false,
    this.searching = true,
  });

  /// The scanner layout.
  final ScannerLayout layout;

  /// Whether the brackets close in on a single barcode.
  final bool lockOn;

  /// The brackets frame the window in the accent color, as when the code
  /// found has been taken into it.
  final bool settled;

  /// Whether the scanner looks for a code; `false` holds the brackets'
  /// breathing and the scan line, as while a verdict shows. Neither runs
  /// while the scanner is paused or a code is in view anyway.
  final bool searching;

  @override
  State<ScanWindowOverlay> createState() => _ScanWindowOverlayState();
}

class _ScanWindowOverlayState extends State<ScanWindowOverlay>
    with TickerProviderStateMixin {
  final _Clock _clock = _Clock();

  /// Whether the scan line is drawn.
  bool _lineOn = false;
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

  /// 1 while the brackets frame a code, with its smaller corners; back on
  /// the window they take the window's corners, even in the accent color.
  double _fromTight = 0;
  double _toTight = 0;

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
    _clock.dispose();
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

  /// Whether a code the brackets frame has only trembled from [from] to
  /// [to]: its corners, found anew in every frame, wander by a pixel or two
  /// even when nothing moves. Following each of these restarted the flight
  /// 30 times a second and kept the screen drawing at its full rate.
  static bool _trembles(Rect? from, Rect? to) {
    if (from == null || to == null) {
      return false;
    }
    final double slack = math.max(3, 0.04 * math.min(from.width, from.height));
    return (from.left - to.left).abs() <= slack &&
        (from.top - to.top).abs() <= slack &&
        (from.right - to.right).abs() <= slack &&
        (from.bottom - to.bottom).abs() <= slack;
  }

  void _retarget({required bool initial}) {
    final Rect? target = _target();
    final ScannerLayout layout = widget.layout;
    final ScannerTheme theme = ScannerTheme.of(context);
    // Hidden (another page over the scanner), it rests like an animation.
    final bool searching =
        widget.searching &&
        !widget.settled &&
        layout.state.status == ScannerStatus.running &&
        !_reduceMotion &&
        TickerMode.valuesOf(context).enabled;
    // The line runs in a window, while no code is in view.
    _lineOn =
        searching &&
        theme.resolvedScanLine != null &&
        layout.barcodes.isEmpty &&
        !_isWholeView(layout);
    _clock.run(
      breath: searching && target == null && theme.resolvedBreathing,
      line: _lineOn,
    );

    final double lock = target == null && !widget.settled ? 0 : 1;
    final double tight = target == null ? 0 : 1;
    if (initial) {
      _from = _to = target;
      _fromLock = _toLock = lock;
      _fromTight = _toTight = tight;
      return;
    }
    if (lock == _toLock && (target == _to || _trembles(_to, target))) {
      return;
    }
    final Rect window = widget.layout.scanWindow;
    final double t = Curves.easeOutCubic.transform(_move.value);
    _from = Rect.lerp(_from ?? window, _to ?? window, t);
    _fromLock = lerpDouble(_fromLock, _toLock, t)!;
    _fromTight = lerpDouble(_fromTight, _toTight, t)!;
    final bool following = _to != null && target != null;
    _version++;
    _to = target;
    _toLock = lock;
    _toTight = tight;
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
    final ScannerWindowShape shape = theme.resolvedWindowShape;
    final Rect window = layout.scanWindow;
    // A window over the whole scanner is no window: its brackets show only
    // on a code.
    final bool noWindow = _isWholeView(layout);
    final ScanLine? line = theme.resolvedScanLine;
    double lock() => lerpDouble(
      _fromLock,
      _toLock,
      Curves.easeOutCubic.transform(_move.value),
    )!;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (!noWindow && shape != ScannerWindowShape.bracketsOnly)
            WindowScrim(window: window),
          if (_lineOn && line != null)
            CustomPaint(
              size: layout.size,
              painter: ScanLinePainter(
                repaint: _clock.line,
                progress: _clock.lineProgress,
                line: line,
                window: window,
                radius: radius,
                circle: shape == ScannerWindowShape.circle,
                color: line.color ?? theme.lockColor,
              ),
            ),
          CustomPaint(
            size: layout.size,
            painter: BracketsPainter(
              repaint: Listenable.merge(<Listenable>[_clock.breath, _move]),
              rect: () {
                final double t = Curves.easeOutCubic.transform(_move.value);
                final Rect window = layout.scanWindow;
                return Rect.lerp(_from ?? window, _to ?? window, t)!;
              },
              lock: lock,
              opacity: noWindow ? lock : null,
              tight: () => lerpDouble(
                _fromTight,
                _toTight,
                Curves.easeOutCubic.transform(_move.value),
              )!,
              scale: () =>
                  1 - 0.02 * Curves.easeInOut.transform(_clock.breathValue),
              radius: radius,
              circle: shape == ScannerWindowShape.circle,
              color: theme.windowColor,
              lockColor: theme.lockColor,
              strokeWidth: theme.resolvedBracketWidth,
              armLength: theme.bracketLength,
              version: Object.hash(layout.scanWindow, _version),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether [layout]'s window covers the whole scanner, as with
/// `ScanWindow.full()`: then there is no window to draw.
bool _isWholeView(ScannerLayout layout) {
  final Rect window = layout.scanWindow;
  return window.left <= 0.5 &&
      window.top <= 0.5 &&
      window.right >= layout.size.width - 0.5 &&
      window.bottom >= layout.size.height - 0.5;
}

/// The clock of the window's slow animations while the scanner searches:
/// the brackets' breathing, 2.4 s each way, and the scan line. One timer
/// draws both 30 times a second, on the same frames. An
/// AnimationController would redraw the screen at its full rate, 120 times
/// a second on a ProMotion display, for a change of a fraction of a pixel
/// per frame; two timers out of step would double the frames.
final class _Clock {
  static const int _stepMicros = 33333;
  static const int _breathMicros = 2400000;

  /// Notifies on each frame of the breathing.
  final _Channel breath = _Channel();

  /// Notifies on each frame of the scan line.
  final _Channel line = _Channel();

  Timer? _timer;

  /// Frames since the clock was made; the timer's own count, which skips
  /// ahead over frames it was late for.
  int _ticks = 0;
  int _ticksBefore = 0;
  int? _breathFrom;
  int? _lineFrom;

  /// 0 to 1 and back: the breathing.
  double get breathValue {
    final int? from = _breathFrom;
    if (from == null) {
      return 0;
    }
    final double t = ((_ticks - from) * _stepMicros / _breathMicros) % 2;
    return t <= 1 ? t : 2 - t;
  }

  /// Time the scan line has been running, in passes.
  double lineProgress(Duration pass) {
    final int? from = _lineFrom;
    if (from == null || pass.inMicroseconds <= 0) {
      return 0;
    }
    return (_ticks - from) * _stepMicros / pass.inMicroseconds;
  }

  /// Starts or stops each animation; the timer runs while one does.
  void run({required bool breath, required bool line}) {
    if (breath != (_breathFrom != null)) {
      _breathFrom = breath ? _ticks : null;
      this.breath.ping();
    }
    if (line != (_lineFrom != null)) {
      _lineFrom = line ? _ticks : null;
      this.line.ping();
    }
    if ((breath || line) && _timer == null) {
      _ticksBefore = _ticks;
      _timer = Timer.periodic(const Duration(microseconds: _stepMicros), (
        Timer timer,
      ) {
        _ticks = _ticksBefore + timer.tick;
        if (_breathFrom != null) {
          this.breath.ping();
        }
        if (_lineFrom != null) {
          this.line.ping();
        }
      });
    } else if (!breath && !line && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  void dispose() {
    _timer?.cancel();
    breath.dispose();
    line.dispose();
  }
}

final class _Channel extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Draws a [ScanLine] across a scan window, clipped to its shape. Values
/// are read when painting, so the line moves without rebuilding.
class ScanLinePainter extends CustomPainter {
  /// Creates the painter.
  ScanLinePainter({
    required Listenable repaint,
    required this.progress,
    required this.line,
    required this.window,
    required this.radius,
    required this.circle,
    required this.color,
  }) : super(repaint: repaint);

  /// The time the line has run for a pass of the given length, in passes.
  final double Function(Duration pass) progress;

  /// The line.
  final ScanLine line;

  /// The scan window.
  final Rect window;

  /// Corner radius of the window.
  final double radius;

  /// Whether the window is an oval.
  final bool circle;

  /// The line's color.
  final Color color;

  /// The line's place from the top of its way (0) to the bottom (1), and
  /// its opacity, after [passes] passes.
  static (double, double) at(ScanLineStyle style, double passes) {
    switch (style) {
      case ScanLineStyle.sweep:
        final double t = passes % 1;
        // Fades in at the top and out at the bottom instead of jumping.
        return (t, math.min(1, math.min(t, 1 - t) / 0.12));
      case ScanLineStyle.bounce:
        final double t = passes % 2;
        return (Curves.easeInOut.transform(t <= 1 ? t : 2 - t), 1);
    }
  }

  /// The area the line runs in: the window inside its inset.
  Rect get area => window.deflate(line.inset);

  Shader? _shader;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect area = this.area;
    if (area.width <= 0 || area.height <= 0) {
      return;
    }
    final (double t, double alpha) = at(line.style, progress(line.duration));
    if (alpha <= 0) {
      return;
    }
    final double y = area.top + t * area.height;
    // Faded at both ends; the same for every frame.
    final Shader shader = _shader ??= ui.Gradient.linear(
      area.centerLeft,
      area.centerRight,
      <Color>[
        color.withValues(alpha: 0),
        color,
        color,
        color.withValues(alpha: 0),
      ],
      const <double>[0, 0.15, 0.85, 1],
    );
    final double thickness = line.thickness;
    canvas
      ..save()
      ..clipPath(
        circle
            ? (Path()..addOval(area))
            : (Path()..addRRect(
                RRect.fromRectAndRadius(
                  area,
                  Radius.circular(math.max(0, radius - line.inset)),
                ),
              )),
      );
    if (line.glow) {
      canvas.drawRect(
        Rect.fromLTRB(
          area.left,
          y - thickness * 2,
          area.right,
          y + thickness * 2,
        ),
        Paint()
          ..shader = shader
          ..color = Color.fromRGBO(0, 0, 0, 0.45 * alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + thickness),
      );
    }
    canvas
      ..drawRect(
        Rect.fromLTRB(
          area.left,
          y - thickness / 2,
          area.right,
          y + thickness / 2,
        ),
        Paint()
          ..shader = shader
          ..color = Color.fromRGBO(0, 0, 0, alpha),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(ScanLinePainter old) =>
      old.line != line ||
      old.window != window ||
      old.radius != radius ||
      old.circle != circle ||
      old.color != color;
}

/// The dimmed camera outside the scan window, in the theme's
/// [ScannerTheme.windowBorder], blurred unless [ScannerTheme.scrimBlur] is
/// `false`.
class WindowScrim extends StatelessWidget {
  /// Creates the scrim around [window].
  const WindowScrim({super.key, required this.window});

  /// The scan window, left clear.
  final Rect window;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final ShapeBorder shape = theme.windowBorder;
    final Widget scrim = CustomPaint(
      painter: _ScrimPainter(window, shape, theme.scrimColor),
      child: const SizedBox.expand(),
    );
    if (!theme.resolvedScrimBlur) {
      return scrim;
    }
    return ClipPath(
      clipper: _OutsideClipper(window, shape),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 6,
          sigmaY: 6,
          tileMode: TileMode.clamp,
        ),
        child: scrim,
      ),
    );
  }
}

class _OutsideClipper extends CustomClipper<Path> {
  const _OutsideClipper(this.window, this.shape);

  final Rect window;
  final ShapeBorder shape;

  @override
  Path getClip(Size size) => _outside(size, window, shape);

  @override
  bool shouldReclip(_OutsideClipper old) =>
      old.window != window || old.shape != shape;
}

Path _outside(Size size, Rect window, ShapeBorder shape) => Path()
  ..fillType = PathFillType.evenOdd
  ..addRect(Offset.zero & size)
  ..addPath(shape.getOuterPath(window), Offset.zero);

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter(this.window, this.shape, this.color);

  final Rect window;
  final ShapeBorder shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawPath(_outside(size, window, shape), Paint()..color = color);

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.window != window || old.shape != shape || old.color != color;
}

/// Draws the four corner brackets of a scan window. Values are read when
/// painting, so animations repaint without rebuilding.
class BracketsPainter extends CustomPainter {
  /// Creates the painter.
  BracketsPainter({
    required Listenable repaint,
    required this.rect,
    required this.lock,
    this.tight,
    required this.scale,
    required this.radius,
    this.circle = false,
    required this.color,
    required this.lockColor,
    this.strokeWidth = 5,
    this.armLength,
    this.opacity,
    this.version = 0,
  }) : super(repaint: repaint);

  /// Repaints when it changes: the inputs of [rect] changed.
  final Object version;

  /// The rectangle the brackets frame.
  final Rect Function() rect;

  /// 0 on the window, 1 locked on a code.
  final double Function() lock;

  /// 0 with the window's corners, 1 with the smaller corners of a code;
  /// default [lock].
  final double Function()? tight;

  /// The breathing scale.
  final double Function() scale;

  /// Optional fading, for the starting state.
  final double Function()? opacity;

  /// Corner radius of the window; brackets on a code have a smaller one.
  final double radius;

  /// Whether the window is an oval: its brackets are four arcs, which turn
  /// into corners on a code.
  final bool circle;

  /// Color of the brackets on the window.
  final Color color;

  /// Color of the brackets on a code.
  final Color lockColor;

  /// Line width of the brackets.
  final double strokeWidth;

  /// Length of each bracket's straight arm; `null` for 22 % of the shorter
  /// side, from 12 to 44.
  final double? armLength;

  @override
  void paint(Canvas canvas, Size size) {
    final double lock = this.lock();
    final double alpha = opacity?.call() ?? 1;
    final Rect r = rect();
    final double s = scale();
    final double tight = this.tight?.call() ?? lock;
    // A round window's arcs fade into a code's corners on the way to it.
    final double round = circle ? 1 - tight : 0;
    canvas.save();
    if (s != 1) {
      canvas
        ..translate(r.center.dx, r.center.dy)
        ..scale(s)
        ..translate(-r.center.dx, -r.center.dy);
    }
    final Color stroke = Color.lerp(color, lockColor, lock)!;
    void draw(Path path, double alpha) {
      if (lock > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round
            ..color = lockColor.withValues(alpha: 0.65 * lock * alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = stroke.withValues(alpha: stroke.a * alpha),
      );
    }

    if (round < 1) {
      draw(
        bracketPath(
          r,
          lerpDouble(radius, radius / 2.4, tight)!,
          arm: armLength,
        ),
        alpha * (1 - round),
      );
    }
    if (round > 0) {
      draw(arcPath(r, radius, arm: armLength), alpha * round);
    }
    canvas.restore();
  }

  /// The four brackets of a round window in [r]: arcs of its oval around
  /// the diagonals, each as long as a bracket of [bracketPath] with corners
  /// of [radius] and arms of [arm].
  static Path arcPath(Rect r, double radius, {double? arm}) {
    final double side = math.min(r.width, r.height);
    arm ??= (side * 0.22).clamp(12, 44);
    final double rr = math.min(radius, side / 2);
    final double sweep = ((2 * arm + math.pi / 2 * rr) / (side / 2)).clamp(
      0.2,
      math.pi / 2 - 0.3,
    );
    final Path path = Path();
    for (int i = 0; i < 4; i++) {
      final double middle = -3 * math.pi / 4 + i * math.pi / 2;
      path.addArc(r, middle - sweep / 2, sweep);
    }
    return path;
  }

  /// The four brackets of [r]: rounded corners with straight arms of
  /// [arm], or of 22 % of the shorter side (12 to 44).
  static Path bracketPath(Rect r, double radius, {double? arm}) {
    final double rr = math.min(radius, math.min(r.width, r.height) / 2);
    arm ??= (math.min(r.width, r.height) * 0.22).clamp(12, 44);
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
      old.circle != circle ||
      old.color != color ||
      old.lockColor != lockColor ||
      old.strokeWidth != strokeWidth ||
      old.armLength != armLength;
}

/// Outlines the barcodes in [ScannerLayout.barcodes] in the theme's
/// [ScannerTheme.outlineColor] and [ScannerTheme.outlineWidth].
class BarcodeOutlines extends StatelessWidget {
  /// Creates the overlay.
  const BarcodeOutlines(this.layout, {super.key, this.color});

  /// The scanner layout.
  final ScannerLayout layout;

  /// Outline color; default [ScannerTheme.outlineColor].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final Color color = this.color ?? theme.outlineColor;
    return IgnorePointer(
      child: CustomPaint(
        size: layout.size,
        painter: OutlinePainter(
          layout.barcodes,
          color,
          this.color == null
              ? theme.outlineFillColor
              : color.withValues(alpha: 0.18),
          theme.resolvedOutlineWidth,
        ),
      ),
    );
  }
}

/// Draws the outlines of [barcodes].
class OutlinePainter extends CustomPainter {
  /// Creates the painter.
  const OutlinePainter(this.barcodes, this.color, this.fill, this.width);

  /// The codes outlined.
  final List<VisibleBarcode> barcodes;

  /// The outline's color.
  final Color color;

  /// The color inside the outline.
  final Color fill;

  /// The outline's line width.
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final Paint area = Paint()..color = fill;
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
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
  bool shouldRepaint(OutlinePainter old) =>
      old.barcodes != barcodes ||
      old.color != color ||
      old.fill != fill ||
      old.width != width;
}
