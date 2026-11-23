// The scan line's cost: a tick of the clock repaints only the line (or,
// while breathing, the brackets), never the scrim; the line's glow is drawn
// without a blur, and looks as the blurred glow did.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;
import 'package:flutter_zxing/src/scanning/ui/window_overlay.dart'
    show BracketsPainter, ScanLinePainter, WindowScrim;

import 'fake_camera.dart';

const Size _phone = Size(390, 844);

/// The line as it was drawn before, with a blurred glow: what the new one
/// is compared with.
void _paintBlurred(
  Canvas canvas, {
  required ScanLine line,
  required Rect window,
  required double radius,
  required bool circle,
  required Color color,
  required double passes,
}) {
  final Rect area = window.deflate(line.inset);
  final (double t, double alpha) = ScanLinePainter.at(line.style, passes);
  if (alpha <= 0) {
    return;
  }
  final double y = area.top + t * area.height;
  final Shader shader = ui.Gradient.linear(
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

ScanLinePainter _painter(
  ScanLine line,
  Rect window, {
  required double passes,
  double radius = 24,
  bool circle = false,
  Color color = const Color(0xFF34C759),
}) => ScanLinePainter(
  repaint: ChangeNotifier(),
  progress: (Duration pass) => passes,
  line: line,
  window: window,
  radius: radius,
  circle: circle,
  color: color,
);

const Size _canvas = Size(240, 240);
const Color _camera = Color(0xFF3A4048);

Future<Uint8List> _pixels(void Function(Canvas canvas) paint) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)
    ..drawRect(Offset.zero & _canvas, Paint()..color = _camera);
  paint(canvas);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(
    _canvas.width.toInt(),
    _canvas.height.toInt(),
  );
  final ByteData bytes = (await image.toByteData())!;
  image.dispose();
  picture.dispose();
  return bytes.buffer.asUint8List();
}

/// A canvas that keeps the calls made on it.
final class _Recorder implements Canvas {
  final List<Invocation> calls = <Invocation>[];

  Iterable<Paint> get paints => calls
      .expand((Invocation call) => call.positionalArguments)
      .whereType<Paint>();

  int count(Symbol method) =>
      calls.where((Invocation call) => call.memberName == method).length;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (invocation.memberName == #getSaveCount) {
      return 1;
    }
    return null;
  }
}

void main() {
  group('the glow', () {
    final Rect window = Rect.fromCenter(
      center: _canvas.center(Offset.zero),
      width: 200,
      height: 200,
    );

    test("is drawn without a blur, in bands of the line's gradient", () {
      final _Recorder canvas = _Recorder();
      _painter(const ScanLine(), window, passes: 0.5).paint(canvas, _canvas);
      expect(canvas.paints, isNotEmpty);
      for (final Paint paint in canvas.paints) {
        expect(paint.maskFilter, isNull);
        expect(paint.imageFilter, isNull);
        expect(paint.shader, isNotNull);
      }
      // The bands, then the line.
      expect(canvas.count(#drawRect), ScanLinePainter.glowBands + 1);
      expect(canvas.count(#saveLayer), 0);
      // Without a glow, the line alone.
      final _Recorder plain = _Recorder();
      _painter(
        const ScanLine(glow: false),
        window,
        passes: 0.5,
      ).paint(plain, _canvas);
      expect(plain.count(#drawRect), 1);
    });

    test("is clipped only near the window's corners, or in a circle", () {
      int clips(double passes, {bool circle = false}) {
        final _Recorder canvas = _Recorder();
        _painter(
          const ScanLine(),
          window,
          passes: passes,
          circle: circle,
        ).paint(canvas, _canvas);
        return canvas.count(#clipPath);
      }

      expect(clips(0.5), 0);
      expect(clips(0.05), 1);
      expect(clips(0.95), 1);
      expect(clips(0.5, circle: true), 1);
    });

    test('bands go out to where the blur fades', () {
      final Float64List halves = ScanLinePainter.glowHalfHeights(2);
      expect(halves.length, ScanLinePainter.glowBands);
      for (int k = 1; k < halves.length; k++) {
        expect(halves[k], lessThan(halves[k - 1]));
      }
      // Beyond the outermost band the blurred glow is under half a step.
      final double peak = ScanLinePainter.glowPeak(2, 1);
      expect(
        0.45 * ScanLinePainter.glowProfile(halves.first, 4, 5),
        moreOrLessEquals(0.5 / ScanLinePainter.glowBands * peak),
      );
    });

    testWidgets('looks as the blurred glow did', (WidgetTester t) async {
      await t.runAsync(() async {
        final List<(ScanLine, double, bool, Color)> cases =
            <(ScanLine, double, bool, Color)>[
              // Defaults, in the middle, at a fading end and near a corner.
              (const ScanLine(), 0.5, false, const Color(0xFF34C759)),
              (const ScanLine(), 0.06, false, const Color(0xFF34C759)),
              (const ScanLine(), 0.93, false, const Color(0xFF34C759)),
              (const ScanLine(), 0.2, true, const Color(0xFF34C759)),
              // Thick, bright and bouncing.
              (
                const ScanLine(thickness: 6, style: ScanLineStyle.bounce),
                0.3,
                false,
                const Color(0xFFFF2020),
              ),
              (
                const ScanLine(thickness: 1, inset: 0),
                0.5,
                false,
                const Color(0xFFFFFFFF),
              ),
            ];
        final Uint8List bare = await _pixels((Canvas canvas) {});
        for (final (ScanLine line, double passes, bool circle, Color color)
            in cases) {
          final Uint8List before = await _pixels(
            (Canvas canvas) => _paintBlurred(
              canvas,
              line: line,
              window: window,
              radius: 24,
              circle: circle,
              color: color,
              passes: passes,
            ),
          );
          final Uint8List after = await _pixels(
            (Canvas canvas) => _painter(
              line,
              window,
              passes: passes,
              circle: circle,
              color: color,
            ).paint(canvas, _canvas),
          );
          int worst = 0;
          int total = 0;
          int drawn = 0;
          for (int i = 0; i < before.length; i++) {
            final int d = (before[i] - after[i]).abs();
            worst = math.max(worst, d);
            total += d;
            if (after[i] != bare[i]) {
              drawn++;
            }
          }
          final String what = '$line at $passes${circle ? ', circle' : ''}';
          // The line and its glow are there, over many rows.
          expect(drawn, greaterThan(4000), reason: what);
          // No pixel more than a few levels off, and on average under one.
          expect(worst, lessThanOrEqualTo(12), reason: what);
          expect(total / before.length, lessThan(0.6), reason: what);
        }
      });
    });
  });

  group('a tick repaints', () {
    late FakeCamera camera;
    late ScannerController controller;

    setUp(() {
      camera = FakeCamera(transform: const FrameTransform(_phone));
      ScannerControllerDebug.cameraFactory = () => camera;
      controller = ScannerController();
    });
    tearDown(() => ScannerControllerDebug.cameraFactory = null);

    Future<void> open(WidgetTester t, ScannerTheme theme) async {
      t.view
        ..physicalSize = _phone
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: _phone),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: BarcodeScanner(controller: controller, theme: theme),
          ),
        ),
      );
      await t.pump();
      await t.pump();
    }

    Future<void> close(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async => controller.dispose());
    }

    RenderCustomPaint renderOf<T>(WidgetTester t) => t
        .renderObjectList<RenderCustomPaint>(find.byType(CustomPaint))
        .firstWhere((RenderCustomPaint r) => r.painter is T);

    RenderObject scrimOf(WidgetTester t) => t.renderObject(
      find.descendant(
        of: find.byType(WindowScrim),
        matching: find.byType(CustomPaint),
      ),
    );

    /// The render objects painted over a few ticks of the clock.
    Future<Set<RenderObject>> ticks(WidgetTester t) async {
      final Set<RenderObject> painted = <RenderObject>{};
      debugOnProfilePaint = painted.add;
      try {
        for (int i = 0; i < 4; i++) {
          await t.pump(const Duration(milliseconds: 34));
        }
      } finally {
        debugOnProfilePaint = null;
      }
      return painted;
    }

    testWidgets('only the scan line, not the scrim or the brackets', (
      WidgetTester t,
    ) async {
      await open(t, const ScannerTheme(scanLine: ScanLine(), breathing: false));
      final RenderCustomPaint line = renderOf<ScanLinePainter>(t);
      final RenderCustomPaint brackets = renderOf<BracketsPainter>(t);
      final RenderObject scrim = scrimOf(t);
      // The line moves.
      final double before = (line.painter! as ScanLinePainter).progress(
        const Duration(seconds: 1),
      );
      final Set<RenderObject> painted = await ticks(t);
      expect(
        (line.painter! as ScanLinePainter).progress(const Duration(seconds: 1)),
        greaterThan(before),
      );
      expect(painted, contains(line));
      expect(painted, isNot(contains(scrim)));
      expect(painted, isNot(contains(brackets)));
      // Each in a layer of its own.
      expect(line.parent, isA<RenderRepaintBoundary>());
      expect(brackets.parent, isA<RenderRepaintBoundary>());
      await close(t);
    });

    testWidgets('only the brackets while they breathe, with a blurred scrim', (
      WidgetTester t,
    ) async {
      await open(t, const ScannerTheme(scrimBlur: true));
      final RenderCustomPaint brackets = renderOf<BracketsPainter>(t);
      final RenderObject scrim = scrimOf(t);
      final Set<RenderObject> painted = await ticks(t);
      expect(painted, contains(brackets));
      expect(painted, isNot(contains(scrim)));
      await close(t);
    });

    testWidgets('both, line and breathing, but never the scrim', (
      WidgetTester t,
    ) async {
      await open(t, const ScannerTheme(scanLine: ScanLine()));
      final RenderCustomPaint line = renderOf<ScanLinePainter>(t);
      final RenderCustomPaint brackets = renderOf<BracketsPainter>(t);
      final RenderObject scrim = scrimOf(t);
      final Set<RenderObject> painted = await ticks(t);
      expect(painted, containsAll(<RenderObject>[line, brackets]));
      expect(painted, isNot(contains(scrim)));
      await close(t);
    });
  });
}
