import 'package:flutter/material.dart';

abstract class ScannerOverlay extends ShapeBorder {
  const ScannerOverlay({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 40),
    this.borderRadius = 0,
    this.borderLength = 40,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  abstract final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(
        rect.right,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.top,
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection});

  @override
  ScannerOverlay scale(double t);
}
