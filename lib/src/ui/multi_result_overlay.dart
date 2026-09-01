import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../flutter_zxing.dart';

/// A detected code together with the on-screen rect it occupies.
@immutable
class CodeHitRegion {
  const CodeHitRegion(this.code, this.rect);

  final Code code;
  final Rect rect;
}

/// Maps each code's [Position] onto the overlay's coordinate space.
///
/// Codes without a position, or whose position reports a zero-sized image, are
/// skipped: they carry no usable geometry and would scale to infinity.
List<CodeHitRegion> codeHitRegions(
  List<Code> codes,
  Size size, {
  Offset offset = Offset.zero,
}) {
  final List<CodeHitRegion> regions = <CodeHitRegion>[];
  for (final Code code in codes) {
    final Position? position = code.position;
    if (position == null || position.imageWidth <= 0) {
      continue;
    }
    final double scale = size.width / position.imageWidth;
    final List<Offset> points = _positionToPoints(position)
        .map(
          (Offset point) => Offset(
            point.dx * scale + offset.dx,
            point.dy * scale + offset.dy,
          ),
        )
        .toList();
    regions.add(CodeHitRegion(code, Rect.fromPoints(points[0], points[2])));
  }
  return regions;
}

List<Offset> _positionToPoints(Position pos) => <Offset>[
  Offset(pos.topLeftX.toDouble(), pos.topLeftY.toDouble()),
  Offset(pos.topRightX.toDouble(), pos.topRightY.toDouble()),
  Offset(pos.bottomRightX.toDouble(), pos.bottomRightY.toDouble()),
  Offset(pos.bottomLeftX.toDouble(), pos.bottomLeftY.toDouble()),
  Offset(pos.topLeftX.toDouble(), pos.topLeftY.toDouble()),
];

class MultiResultOverlay extends StatelessWidget {
  const MultiResultOverlay({
    super.key,
    this.results = const <Code>[],
    this.onCodeTap,
    this.controller,
  });

  final List<Code> results;
  final Function(Code code)? onCodeTap;
  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).primaryColor;
    return Positioned.fill(
      child: RotatedBox(
        quarterTurns: _getQuarterTurns(),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size size = constraints.biggest;
            final CustomPaint painter = CustomPaint(
              size: size,
              painter: MultiScanPainter(codes: results, color: color),
            );
            if (onCodeTap == null) {
              return painter;
            }
            // Hit testing lives in a gesture recogniser rather than in
            // `CustomPainter.hitTest`: that method runs for every pointer
            // event that reaches the overlay, so invoking the callback from
            // there fired it on drags and hovers as well as on taps.
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (TapUpDetails details) {
                for (final CodeHitRegion region in codeHitRegions(
                  results,
                  size,
                )) {
                  if (region.rect.contains(details.localPosition)) {
                    onCodeTap?.call(region.code);
                    return;
                  }
                }
              },
              child: painter,
            );
          },
        ),
      ),
    );
  }

  int _getQuarterTurns() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return 0;
    }
    const Map<DeviceOrientation, int> turns = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 1,
      DeviceOrientation.landscapeRight: 2,
      DeviceOrientation.portraitDown: 1,
      DeviceOrientation.landscapeLeft: 0,
    };
    return turns[_getApplicableOrientation()] ?? 0;
  }

  DeviceOrientation _getApplicableOrientation() {
    return controller?.value.deviceOrientation ?? DeviceOrientation.portraitUp;
  }
}

class MultiScanPainter extends CustomPainter {
  MultiScanPainter({
    required this.codes,
    this.offset = Offset.zero,
    this.color = Colors.blue,
  });

  final List<Code> codes;
  final Offset offset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final Code code in codes) {
      final Position? position = code.position;
      if (position == null || position.imageWidth <= 0) {
        continue;
      }
      final double scale = size.width / position.imageWidth;
      final List<Offset> scaledPoints = _positionToPoints(position)
          .map(
            (Offset point) => Offset(
              point.dx * scale + offset.dx,
              point.dy * scale + offset.dy,
            ),
          )
          .toList();
      canvas.drawPoints(PointMode.polygon, scaledPoints, paint);

      final String? text = code.text;
      if (text == null || text.isEmpty) {
        continue;
      }
      final Rect rect = Rect.fromPoints(scaledPoints[0], scaledPoints[2]);
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: 12),
        ),
        maxLines: 2,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: rect.width);
      textPainter.paint(canvas, rect.topLeft.translate(0, -textPainter.height));
      textPainter.dispose();
    }
  }

  @override
  bool shouldRepaint(MultiScanPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.offset != offset ||
      !identical(oldDelegate.codes, codes);
}
