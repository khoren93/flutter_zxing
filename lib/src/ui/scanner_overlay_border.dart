import 'package:flutter/material.dart';

/// Universal border for a scanner overlay with a transparent cut-out.
/// [cutOutSize] > 1 — size in pixels, <= 1 — percentage of the smaller side.
/// Offsets: -1.0..1.0 (left/right, up/down).
class ScannerOverlayBorder extends ShapeBorder {
  const ScannerOverlayBorder({
    this.cutOutSize = 250,
    this.horizontalOffset = 0,
    this.verticalOffset = 0,
    this.borderColor = Colors.white,
    this.borderWidth = 4,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 0.5),
    this.borderRadius = 16,
    this.borderLength = 32,
  });

  /// Size of the cut-out area. If > 1, treated as pixels; if <= 1, as a percentage of the smaller side.
  final double cutOutSize;

  /// Horizontal offset for the cut-out center (-1.0..1.0).
  final double horizontalOffset;

  /// Vertical offset for the cut-out center (-1.0..1.0).
  final double verticalOffset;

  /// Color of the border corners.
  final Color borderColor;

  /// Width of the border corners.
  final double borderWidth;

  /// Color of the overlay outside the cut-out.
  final Color overlayColor;

  /// Border radius of the cut-out rectangle.
  final double borderRadius;

  /// Length of the border corners.
  final double borderLength;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  ShapeBorder scale(double t) => this;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    // Calculate width and height of the available area
    final double width = rect.width;
    final double height = rect.height;

    // Determine the size of the cut-out
    final double cutOut = cutOutSize > 1
        ? cutOutSize.clamp(0.0, width < height ? width : height)
        : (width < height ? width : height) * cutOutSize;

    // Calculate offsets for the cut-out center
    final double dx = horizontalOffset * ((width - cutOut) / 2);
    final double dy = verticalOffset * ((height - cutOut) / 2);

    // Define the cut-out rectangle
    final Rect cutOutRect = Rect.fromLTWH(
      width / 2 - cutOut / 2 + dx,
      height / 2 - cutOut / 2 + dy,
      cutOut,
      cutOut,
    );

    // Return the path for the cut-out with rounded corners
    return Path()
      ..addRRect(
          RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    // Outer rectangle (entire area)
    final Path outer = Path()..addRect(rect);

    // Calculate width and height of the available area
    final double width = rect.width;
    final double height = rect.height;

    // Determine the size of the cut-out
    final double cutOut = cutOutSize > 1
        ? cutOutSize.clamp(0.0, width < height ? width : height)
        : (width < height ? width : height) * cutOutSize;

    // Calculate offsets for the cut-out center
    final double dx = horizontalOffset * ((width - cutOut) / 2);
    final double dy = verticalOffset * ((height - cutOut) / 2);

    // Define the cut-out rectangle
    final Rect cutOutRect = Rect.fromLTWH(
      width / 2 - cutOut / 2 + dx,
      height / 2 - cutOut / 2 + dy,
      cutOut,
      cutOut,
    );

    // Path for the cut-out with rounded corners
    final Path cutOutPath = Path()
      ..addRRect(
          RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)));

    // Return the difference: everything minus the cut-out
    return Path.combine(PathOperation.difference, outer, cutOutPath);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final double width = rect.width;
    final double height = rect.height;

    final double cutOut = cutOutSize > 1
        ? cutOutSize.clamp(0.0, width < height ? width : height)
        : (width < height ? width : height) * cutOutSize;

    final double dx = horizontalOffset * ((width - cutOut) / 2);
    final double dy = verticalOffset * ((height - cutOut) / 2);

    final Rect cutOutRect = Rect.fromLTWH(
      width / 2 - cutOut / 2 + dx,
      height / 2 - cutOut / 2 + dy,
      cutOut,
      cutOut,
    );

    // Draw the overlay outside the cut-out
    final Paint overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(getOuterPath(rect), overlayPaint);

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final double newBorderLength = borderLength.clamp(0.0, cutOut / 2);

    final Paint backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final Paint boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;
    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(
        rect,
        backgroundPaint,
      )
      // Draw top right corner
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          cutOutRect.right - newBorderLength,
          cutOutRect.top,
          cutOutRect.right,
          cutOutRect.top + newBorderLength,
          topRight: Radius.circular(borderRadius),
        ),
        borderPaint,
      )
      // Draw top left corner
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          cutOutRect.left,
          cutOutRect.top,
          cutOutRect.left + newBorderLength,
          cutOutRect.top + newBorderLength,
          topLeft: Radius.circular(borderRadius),
        ),
        borderPaint,
      )
      // Draw bottom right corner
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          cutOutRect.right - newBorderLength,
          cutOutRect.bottom - newBorderLength,
          cutOutRect.right,
          cutOutRect.bottom,
          bottomRight: Radius.circular(borderRadius),
        ),
        borderPaint,
      )
      // Draw bottom left corner
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          cutOutRect.left,
          cutOutRect.bottom - newBorderLength,
          cutOutRect.left + newBorderLength,
          cutOutRect.bottom,
          bottomLeft: Radius.circular(borderRadius),
        ),
        borderPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          cutOutRect,
          Radius.circular(borderRadius),
        ),
        boxPaint,
      )
      ..restore();
  }

  @override
  ShapeBorder lerpFrom(ShapeBorder? a, double t) => this;

  @override
  ShapeBorder lerpTo(ShapeBorder? b, double t) => this;
}
