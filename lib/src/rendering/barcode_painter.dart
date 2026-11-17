// Paints a BarcodeSymbol with a BarcodeStyle: the renderer behind
// BarcodeView. Not exported from the package.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show CustomPainter;

import '../writing/barcode_writer.dart';
import '../writing/symbol_layout.dart';
import 'barcode_style.dart';
import 'symbol_shapes.dart';

/// Paints [symbol] into the painter's size: centred, keeping its aspect
/// ratio, with the module size snapped to whole device pixels where that
/// keeps it at least two pixels, so that the edges stay sharp.
final class BarcodePainter extends CustomPainter {
  /// Creates a painter.
  BarcodePainter({
    required this.symbol,
    required this.layout,
    required this.style,
    required this.devicePixelRatio,
    required this.textStyle,
    this.textDirection = TextDirection.ltr,
    this.logo,
  });

  /// The symbol to paint.
  final BarcodeSymbol symbol;

  /// Its geometry ([SymbolLayout] of [symbol]).
  final SymbolLayout layout;

  /// Colors and shapes.
  final BarcodeStyle style;

  /// Pixels per logical pixel, for snapping.
  final double devicePixelRatio;

  /// Base style of the human readable text.
  final TextStyle textStyle;

  /// Resolves directional gradients (`AlignmentDirectional`).
  final TextDirection textDirection;

  /// The decoded [BarcodeStyle.logo] image, once loaded.
  final ui.Image? logo;

  /// Size of one module in logical pixels when painted into [size].
  double moduleSize(Size size) {
    final double fit = math.min(
      size.width / layout.width,
      size.height / layout.height,
    );
    final double device = fit * devicePixelRatio;
    return device >= 2 ? device.floorToDouble() / devicePixelRatio : fit;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (style.backgroundColor.a > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = style.backgroundColor,
      );
    }
    final double m = moduleSize(size);
    if (m <= 0) {
      return;
    }
    final Offset origin = Offset(
      _snap((size.width - layout.width * m) / 2),
      _snap((size.height - layout.height * m) / 2),
    );
    final SymbolShapes shapes = SymbolShapes(symbol, layout, style);
    final Paint ink = Paint();
    final Gradient? gradient = style.gradient;
    if (gradient != null) {
      ink.shader = gradient.createShader(
        shapes.symbolArea,
        textDirection: textDirection,
      );
    } else {
      ink.color = style.color;
    }

    canvas
      ..save()
      ..translate(origin.dx, origin.dy)
      ..scale(m);
    final Path modules = Path();
    shapes.modules(PathSink(modules));
    canvas.drawPath(modules, ink);
    if (shapes.hasFinders) {
      final Path finders = Path()..fillType = PathFillType.evenOdd;
      shapes.finders(PathSink(finders));
      canvas.drawPath(finders, ink);
    }
    final ui.Image? image = logo;
    final LogoBox? logoBox = shapes.logo;
    if (logoBox != null && image != null) {
      _paintLogo(canvas, image, logoBox.rect);
    }
    canvas.restore();

    final String? text = layout.text;
    if (text != null) {
      _paintText(canvas, text, origin, m);
    }
  }

  double _snap(double v) =>
      (v * devicePixelRatio).roundToDouble() / devicePixelRatio;

  void _paintLogo(Canvas canvas, ui.Image image, Rect box) {
    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final FittedSizes fitted = applyBoxFit(BoxFit.contain, imageSize, box.size);
    final Rect dst = Alignment.center.inscribe(fitted.destination, box);
    canvas.drawImageRect(
      image,
      Offset.zero & imageSize,
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = true,
    );
  }

  void _paintText(Canvas canvas, String text, Offset origin, double m) {
    final double width = layout.width * m;
    double fontSize = SymbolLayout.textFontSize * m;
    TextPainter painter() => TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(
          color: style.color,
          fontSize: fontSize,
          height: 1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: width);
    TextPainter tp = painter();
    final double natural = tp.computeLineMetrics().isEmpty
        ? 0
        : tp.computeLineMetrics().first.width;
    if (natural > width && natural > 0) {
      tp.dispose();
      fontSize *= width / natural;
      tp = painter();
    }
    tp.paint(canvas, Offset(origin.dx, origin.dy + layout.textTop * m));
    tp.dispose();
  }

  @override
  bool shouldRepaint(BarcodePainter old) =>
      !identical(old.symbol, symbol) ||
      old.style != style ||
      old.devicePixelRatio != devicePixelRatio ||
      old.textStyle != textStyle ||
      old.textDirection != textDirection ||
      !identical(old.logo, logo);
}
