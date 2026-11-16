// The camera's lens in the developer numbers (iPhones): which physical
// camera is open, where its lens is focused, and where automatic zoom is
// heading. Read by the library itself for automatic zoom; shown here to tune
// AutoLensTuning (lib/src/scanning/auto_lens.dart).
import 'dart:async';

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
// The lens values are not public API.
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/camera/camera_source.dart'
    show CameraLens, LensFocus;
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug, ScannerFrameSample;

/// The lens block of the numbers panel; nothing where the camera does not
/// report its focus.
class LensNumbers extends StatefulWidget {
  const LensNumbers({super.key, required this.controller});

  final ScannerController controller;

  @override
  State<LensNumbers> createState() => _LensNumbersState();
}

/// One frame of the lens history.
typedef _Point = ({double position, bool adjusting, bool switched});

class _LensNumbersState extends State<LensNumbers> {
  StreamSubscription<ScannerFrameSample>? _sub;
  ({CameraLens lens, LensFocus? focus, double? autoTarget})? _now;

  /// The last 3 seconds or so (one point a frame).
  final List<_Point> _history = <_Point>[];
  final Stopwatch _focusing = Stopwatch();
  int? _lastFocusMs;
  CameraLens? _lastLens;

  @override
  void initState() {
    super.initState();
    _sub = widget.controller.frameSamples.listen((_) => _onFrame());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _onFrame() {
    final ({CameraLens lens, LensFocus? focus, double? autoTarget}) now =
        widget.controller.lensSample;
    // Kept, not drawn: the numbers panel redraws 4 times a second.
    final LensFocus? focus = now.focus;
    if (focus == null) {
      _now = null;
      return;
    }
    if (focus.adjusting && !_focusing.isRunning) {
      _focusing
        ..reset()
        ..start();
    } else if (!focus.adjusting && _focusing.isRunning) {
      _focusing.stop();
      _lastFocusMs = _focusing.elapsedMilliseconds;
    }
    final bool switched = _lastLens != null && now.lens != _lastLens;
    _lastLens = now.lens;
    _now = now;
    _history.add((
      position: focus.position,
      adjusting: focus.adjusting,
      switched: switched,
    ));
    if (_history.length > 90) {
      _history.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ({CameraLens lens, LensFocus? focus, double? autoTarget})? now = _now;
    final LensFocus? focus = now?.focus;
    if (now == null || focus == null) {
      return const SizedBox.shrink();
    }
    const TextStyle k = TextStyle(
      fontSize: 11,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
      color: Color(0xFFA7B0BD),
    );
    const TextStyle v = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xFFEEF1F5),
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    );
    const TextStyle mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      color: Color(0xFFA7B0BD),
    );
    Widget stat(String key, String value, {Color? color}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(key.toUpperCase(), style: k),
        const SizedBox(height: 2),
        Text(value, style: color == null ? v : v.copyWith(color: color)),
      ],
    );
    final ScannerState state = widget.controller.value;
    final double? target = now.autoTarget;
    final String camera = switch (now.lens) {
      CameraLens.ultraWide => 'ultra-wide',
      CameraLens.main => 'main',
      CameraLens.telephoto => 'telephoto',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: 16),
        Text(
          'LENS · $camera camera · auto zoom ${state.autoZoom.name}',
          style: k,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: stat('lensPosition', focus.position.toStringAsFixed(3)),
            ),
            Expanded(
              child: stat(
                'Focusing',
                focus.adjusting
                    ? 'yes'
                    : _lastFocusMs == null
                    ? 'no'
                    : 'no · $_lastFocusMs ms',
                color: focus.adjusting ? const Color(0xFFFBBF24) : null,
              ),
            ),
            Expanded(
              child: stat(
                'Min focus',
                focus.minimumDistance == null
                    ? '—'
                    : '${focus.minimumDistance} mm',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(child: stat('Zoom', _format(state.zoom))),
            Expanded(
              child: stat(
                'Heading to',
                target == null ? '—' : _format(target),
                color: target == null ? null : const Color(0xFF34D399),
              ),
            ),
            Expanded(
              child: stat(
                'Telephoto',
                state.telephotoZoom == null
                    ? '—'
                    : _format(state.telephotoZoom!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // lensPosition over the last frames: 0 at the bottom (the nearest
        // the lens can focus), 1 at the top; amber while focusing, a green
        // line where the camera changed.
        SizedBox(height: 40, child: CustomPaint(painter: _History(_history))),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('lensPosition, 3 s', style: mono),
            Text('0 = nearest · 1 = far', style: mono),
          ],
        ),
      ],
    );
  }

  static String _format(double zoom) {
    final double rounded = (zoom * 10).roundToDouble() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.round()}×'
        : '${rounded.toStringAsFixed(1)}×';
  }
}

class _History extends CustomPainter {
  _History(this.points);

  final List<_Point> points;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)),
      Paint()..color = const Color(0x22FFFFFF),
    );
    if (points.length < 2) {
      return;
    }
    const int slots = 90;
    final double w = size.width / (slots - 1);
    final double x0 = (slots - points.length) * w;
    for (final (int i, _Point p) in points.indexed) {
      final double x = x0 + i * w;
      if (p.adjusting) {
        canvas.drawRect(
          Rect.fromLTWH(x - w / 2, 0, w, size.height),
          Paint()..color = const Color(0x33FBBF24),
        );
      }
      if (p.switched) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..color = const Color(0xFF34D399)
            ..strokeWidth = 2,
        );
      }
    }
    final Path path = Path();
    for (final (int i, _Point p) in points.indexed) {
      final Offset o = Offset(
        x0 + i * w,
        size.height - 2 - p.position.clamp(0, 1) * (size.height - 4),
      );
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFEEF1F5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_History old) => true;
}
