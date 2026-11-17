// Where a barcode, its title, caption and card go, in modules: one source
// for BarcodeView, the PNG and the SVG, so that they look the same. Not
// exported from the package.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../writing/symbol_layout.dart';
import 'barcode_style.dart';

/// Line height of captions, as a multiple of the font size.
const double captionLineHeight = 1.25;

/// A caption or title, laid out: the text, its box and font in modules.
final class FrameText {
  FrameText._(this.caption, this.rect, this.fontSize, this.style, this.lines);

  final BarcodeCaption caption;

  /// The text's box, in modules, in the frame.
  final Rect rect;

  /// Font size, in modules.
  final double fontSize;

  /// The full text style, without a size (see [fontSize]).
  final TextStyle style;

  /// The lines as wrapped, with the baseline of each from the box's top, in
  /// modules: for the SVG, which does not wrap.
  final List<(String, double)> lines;

  /// A painter for [scale] pixels per module, laid out to the box's width.
  TextPainter painter(double scale, TextDirection direction) => TextPainter(
    text: TextSpan(
      text: caption.text,
      style: style.copyWith(
        fontSize: fontSize * scale,
        height: captionLineHeight,
        // A fraction of the font size, like CSS em: it scales with it.
        letterSpacing: style.letterSpacing == null
            ? null
            : style.letterSpacing! * fontSize * scale,
      ),
    ),
    textAlign: caption.align,
    textDirection: direction,
    maxLines: caption.maxLines,
    ellipsis: '…',
  )..layout(minWidth: rect.width * scale, maxWidth: rect.width * scale);

  /// Lays out [caption] to [width] modules, its top at [top]; its size is a
  /// fraction of [unit], the symbol's width.
  static FrameText _measure(
    BarcodeCaption caption,
    double left,
    double top,
    double width,
    double unit,
    TextStyle base,
    Color color,
  ) {
    final double fontSize = caption.size * unit;
    final TextStyle style = base
        .merge(caption.style)
        .copyWith(
          color: caption.style?.color ?? color,
          fontWeight: caption.style?.fontWeight ?? FontWeight.w700,
          // The ink of the canvas, not a widget's decoration.
          decoration: TextDecoration.none,
        );
    // Measured at a comfortable pixel size: wrapping scales with the font.
    final double scale = 40 / math.max(fontSize, 0.01);
    final FrameText laidOut = FrameText._(
      caption,
      Rect.fromLTWH(left, top, width, 0),
      fontSize,
      style,
      const <(String, double)>[],
    );
    final TextPainter tp = laidOut.painter(scale, TextDirection.ltr);
    final List<ui.LineMetrics> metrics = tp.computeLineMetrics();
    final List<(String, double)> lines = <(String, double)>[];
    int start = 0;
    final String text = caption.text;
    for (final ui.LineMetrics m in metrics) {
      final TextRange range = tp.getLineBoundary(
        TextPosition(offset: math.min(start, text.length)),
      );
      String line = text.substring(range.start, range.end).trimRight();
      // The last line shown, with more text after it: as painted, with an
      // ellipsis.
      if (m.lineNumber == caption.maxLines - 1 &&
          range.end < text.trimRight().length) {
        line = '$line…';
      }
      lines.add((line, m.baseline / scale));
      start = range.end;
      while (start < text.length &&
          (text[start] == '\n' || text[start] == ' ')) {
        start++;
      }
    }
    final double height = tp.height / scale;
    tp.dispose();
    return FrameText._(
      caption,
      Rect.fromLTWH(left, top, width, height),
      fontSize,
      style,
      lines,
    );
  }
}

/// The frame of a code: its [title], [caption] and [card] around the
/// [code], in modules.
final class FrameLayout {
  /// Lays out [code] with [style]'s title, caption and card. [base] gives
  /// the font (BarcodeView: the app's).
  factory FrameLayout(
    SymbolLayout code,
    BarcodeStyle style, {
    TextStyle base = const TextStyle(),
  }) {
    // Lengths are fractions of the symbol itself, without its quiet zone,
    // and measured from it. The quiet zone is the least they can be, so it
    // is never added on top: text stays out of it, and a card's padding
    // already keeps it clear.
    final double q = code.quietZone.toDouble();
    // Left and right: the quiet zone, or the room of EAN/UPC digits outside.
    final double qx = code.marginX.toDouble();
    final double unit = code.width - 2 * qx;
    final BarcodeCard? card = style.card;
    final double pad = card == null ? 0 : card.padding * unit;
    final double side = card == null ? qx : math.max(pad, qx);
    final double width = unit + 2 * side;
    final double textLeft = card == null ? 0 : pad;
    final double textWidth = width - 2 * textLeft;
    final Color ink = style.gradient?.colors.first ?? style.color;

    FrameText? title;
    double contentTop;
    if (style.title case final BarcodeCaption t when t.text.isNotEmpty) {
      title = FrameText._measure(t, textLeft, pad, textWidth, unit, base, ink);
      contentTop = title.rect.bottom + math.max(t.gap * unit, q);
    } else {
      contentTop = card == null ? q : math.max(pad, q);
    }
    final double contentBottom = contentTop + code.height - 2 * q;
    FrameText? caption;
    double bottom;
    if (style.caption case final BarcodeCaption c when c.text.isNotEmpty) {
      caption = FrameText._measure(
        c,
        textLeft,
        contentBottom + math.max(c.gap * unit, q),
        textWidth,
        unit,
        base,
        ink,
      );
      bottom = caption.rect.bottom + pad;
    } else {
      bottom = contentBottom + (card == null ? q : math.max(pad, q));
    }
    return FrameLayout._(
      code: code,
      width: width,
      height: bottom,
      codeOrigin: Offset(side - qx, contentTop - q),
      title: title,
      caption: caption,
      card: card,
      cardColor: card == null ? null : card.color ?? style.backgroundColor,
      cardRadius: card == null ? 0 : card.radius * unit,
      shadowBlur: card == null ? 0 : card.elevation * unit,
    );
  }

  FrameLayout._({
    required this.code,
    required this.width,
    required this.height,
    required this.codeOrigin,
    required this.title,
    required this.caption,
    required this.card,
    required this.cardColor,
    required this.cardRadius,
    required this.shadowBlur,
  });

  /// The code's own layout.
  final SymbolLayout code;

  /// Total width and height, in modules.
  final double width;
  final double height;

  /// The code's top-left corner, in modules.
  final Offset codeOrigin;

  final FrameText? title;
  final FrameText? caption;
  final BarcodeCard? card;

  /// The card's color, `null` without a card.
  final Color? cardColor;

  /// The card's corner radius, in modules.
  final double cardRadius;

  /// Blur of the card's shadow, in modules; 0 for none.
  final double shadowBlur;

  /// How far down the shadow falls, in modules.
  double get shadowOffset => shadowBlur / 2;

  /// The color of the shadow.
  static const Color shadowColor = Color(0x47000000);

  /// How far the shadow reaches past the frame on every side, in modules:
  /// the margin an export adds.
  double get outset => shadowBlur == 0 ? 0 : shadowBlur * 1.5 + shadowOffset;

  /// Whether the frame is the code alone.
  bool get plain => title == null && caption == null && card == null;

  /// The card's shape, in modules.
  RRect get cardRRect => RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, width, height),
    Radius.circular(cardRadius),
  );

  /// The code's box, in modules.
  Rect get codeRect => codeOrigin & Size(code.width * 1.0, code.height * 1.0);

  /// Pixels per module for [size] (fit `size` × `size`, shadow included) or
  /// [moduleSize]; 4 without either.
  ///
  /// Throws [ArgumentError] if both are given or one is not positive.
  int pixelsPerModule(int? size, int? moduleSize) {
    if (size != null && moduleSize != null) {
      throw ArgumentError('Give either size or moduleSize, not both');
    }
    if ((size ?? 1) < 1 || (moduleSize ?? 1) < 1) {
      throw ArgumentError('size and moduleSize must be positive');
    }
    if (size == null) {
      return moduleSize ?? 4;
    }
    final double side = math.max(width, height) + 2 * outset;
    return math.max(1, (size / side).floor());
  }
}
