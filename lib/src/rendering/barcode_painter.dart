// Paints a BarcodeSymbol with a BarcodeStyle: the renderer behind
// BarcodeView. Not exported from the package.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show CustomPainter;

import '../writing/barcode_writer.dart';
import '../writing/symbol_layout.dart';
import 'barcode_style.dart';
import 'frame_layout.dart';
import 'symbol_shapes.dart';

/// Paints [symbol] into the painter's size with its frame (title, caption,
/// card): centred, keeping its aspect ratio, with the module size snapped
/// to whole device pixels where that keeps it at least two pixels, so that
/// the edges stay sharp.
final class BarcodePainter extends CustomPainter {
  /// Creates a painter.
  BarcodePainter({
    required this.symbol,
    required this.layout,
    required this.frame,
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

  /// The code with its title, caption and card ([FrameLayout] of [layout]).
  final FrameLayout frame;

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
      size.width / frame.width,
      size.height / frame.height,
    );
    final double device = fit * devicePixelRatio;
    // A hair over, so that a size of exactly n modules is not floored to
    // n - 1 by rounding.
    return device >= 2
        ? (device + 1e-6).floorToDouble() / devicePixelRatio
        : fit;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double m = moduleSize(size);
    final Offset frameOrigin = Offset(
      _snap((size.width - frame.width * m) / 2),
      _snap((size.height - frame.height * m) / 2),
    );
    final Color? cardColor = frame.cardColor;
    if (cardColor != null) {
      final RRect card = frame.cardRRect;
      final RRect shown = RRect.fromLTRBR(
        frameOrigin.dx + card.left * m,
        frameOrigin.dy + card.top * m,
        frameOrigin.dx + card.right * m,
        frameOrigin.dy + card.bottom * m,
        Radius.circular(frame.cardRadius * m),
      );
      if (frame.shadowBlur > 0) {
        canvas.drawRRect(
          shown.shift(Offset(0, frame.shadowOffset * m)),
          Paint()
            ..color = FrameLayout.shadowColor
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              Shadow.convertRadiusToSigma(frame.shadowBlur * m),
            ),
        );
      }
      canvas.drawRRect(shown, Paint()..color = cardColor);
    } else if (style.backgroundColor.a > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = style.backgroundColor,
      );
    }
    if (m <= 0) {
      return;
    }
    final Offset origin = Offset(
      frameOrigin.dx + _snap(frame.codeOrigin.dx * m),
      frameOrigin.dy + _snap(frame.codeOrigin.dy * m),
    );
    // A card of another color: the code keeps its own background.
    if (cardColor != null &&
        cardColor != style.backgroundColor &&
        style.backgroundColor.a > 0) {
      canvas.drawRect(
        origin & Size(layout.width * m, layout.height * m),
        Paint()..color = style.backgroundColor,
      );
    }
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
    for (final FrameText? t in <FrameText?>[frame.title, frame.caption]) {
      if (t != null) {
        final TextPainter tp = t.painter(m, textDirection);
        tp.paint(
          canvas,
          Offset(
            frameOrigin.dx + t.rect.left * m,
            frameOrigin.dy + t.rect.top * m,
          ),
        );
        tp.dispose();
      }
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
      !identical(old.frame, frame) ||
      old.style != style ||
      old.devicePixelRatio != devicePixelRatio ||
      old.textStyle != textStyle ||
      old.textDirection != textDirection ||
      !identical(old.logo, logo);
}
