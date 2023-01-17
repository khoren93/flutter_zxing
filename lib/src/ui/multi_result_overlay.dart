import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../flutter_zxing.dart';

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
    return Positioned.fill(
      child: RotatedBox(
        quarterTurns: _getQuarterTurns(),
        child: CustomPaint(
          painter: MultiScanPainter(
            context: context,
            codes: results,
            color: Theme.of(context).primaryColor,
            onCodeTap: onCodeTap,
          ),
        ),
      ),
    );
  }

  int _getQuarterTurns() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return 0;
    }
    final Map<DeviceOrientation, int> turns = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 1,
      DeviceOrientation.landscapeRight: 2,
      DeviceOrientation.portraitDown: 1,
      DeviceOrientation.landscapeLeft: 0,
    };
    return turns[_getApplicableOrientation()]!;
  }

  DeviceOrientation _getApplicableOrientation() {
    return controller?.value.deviceOrientation ?? DeviceOrientation.portraitUp;
  }
}

class MultiScanPainter extends CustomPainter {
  MultiScanPainter({
    required this.context,
    required this.codes,
    this.onCodeTap,
    this.offset = Offset.zero,
    this.color = Colors.blue,
  });

  final BuildContext context;
  final List<Code> codes;
  final Offset offset;
  final Color color;

  final Function(Code code)? onCodeTap;

  final Map<Rect, Code> _codeRects = <Rect, Code>{};

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final Code code in codes) {
      final Position? position = code.position;
      if (position == null) {
        continue;
      }
      final double scale = size.width / position.imageWidth;

      // position to points
      final List<Offset> points = positionToPoints(position);
      final List<Offset> scaledPoints = points
          .map((Offset point) => Offset(
                point.dx * scale + offset.dx,
                point.dy * scale + offset.dy,
              ))
          .toList();
      canvas.drawPoints(PointMode.polygon, scaledPoints, paint);

      final Rect rect = Rect.fromPoints(scaledPoints[0], scaledPoints[2]);

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: code.text,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
        maxLines: 2,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.layout(maxWidth: rect.width);
      textPainter.paint(canvas, rect.topLeft.translate(0, -textPainter.height));

      _codeRects[rect] = code;
    }
  }

  @override
  bool? hitTest(Offset position) {
    for (final Rect rect in _codeRects.keys) {
      if (rect.contains(position)) {
        final Code? code = _codeRects[rect];
        if (code != null) {
          onCodeTap?.call(code);
        }
        return false;
      }
    }
    return super.hitTest(position);
  }

  @override
  bool shouldRepaint(MultiScanPainter oldDelegate) {
    return true;
  }

  List<Offset> positionToPoints(Position pos) {
    return <Offset>[
      Offset(pos.topLeftX.toDouble(), pos.topLeftY.toDouble()),
      Offset(pos.topRightX.toDouble(), pos.topRightY.toDouble()),
      Offset(pos.bottomRightX.toDouble(), pos.bottomRightY.toDouble()),
      Offset(pos.bottomLeftX.toDouble(), pos.bottomLeftY.toDouble()),
      Offset(pos.topLeftX.toDouble(), pos.topLeftY.toDouble()),
    ];
  }
}
