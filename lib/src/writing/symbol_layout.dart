// The geometry of a rendered BarcodeSymbol, in modules: one source for the
// SVG, the raster image and (stage 7) BarcodeView, so that every output
// looks the same. Not exported from the package.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../barcode/barcode_format.dart';
import 'barcode_writer.dart';

/// An axis-aligned rectangle of dark modules, in module units.
@immutable
final class ModuleRect {
  /// Creates a rectangle.
  const ModuleRect(this.x, this.y, this.width, this.height);

  /// Left edge.
  final int x;

  /// Top edge.
  final int y;

  /// Width.
  final int width;

  /// Height.
  final int height;

  @override
  bool operator ==(Object other) =>
      other is ModuleRect &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'ModuleRect($x, $y, $width x $height)';
}

/// A piece of the human readable text: [text] centred on [x], its box's top
/// at [top], [fontSize] high; all in modules.
@immutable
final class TextRun {
  /// Creates a run.
  const TextRun(this.text, this.x, this.top, this.fontSize, {this.fit = false});

  /// The characters.
  final String text;

  /// Horizontal centre.
  final double x;

  /// Top of the text box.
  final double top;

  /// Font size (and box height).
  final double fontSize;

  /// Shrink to the symbol's width if wider (one line under a whole code).
  final bool fit;
}

/// Where everything of a symbol goes, in modules.
///
/// The symbol sits inside its quiet zone; human readable text, if any, goes
/// under the bars:
///
/// ```text
///   quiet zone
///   +---------------------+
///   | bars / modules      |
///   +---------------------+
///   text
///   quiet zone
/// ```
///
/// EAN-13, EAN-8, UPC-A and UPC-E print their digits as GS1 lays them out:
/// each under its own symbol character, between the guard bars that reach
/// down past the data bars; the first digit of an EAN-13 and the outer
/// digits of a UPC-A and UPC-E stand outside, in the quiet zone, the UPC
/// ones smaller.
@immutable
final class SymbolLayout {
  /// Lays out [symbol].
  factory SymbolLayout(BarcodeSymbol symbol) {
    final int q = symbol.quietZone;
    final String? text = symbol.text;
    final bool hasText = text != null && text.isNotEmpty;
    final List<_Digit>? digits = hasText ? _eanUpcDigits(symbol, text) : null;
    if (digits != null) {
      // Outside digits need room even without a quiet zone.
      final bool outside = digits.any(
        (_Digit d) => d.x < 0 || d.x > symbol.width,
      );
      final int mx = outside ? math.max(q, _outsideRoom) : q;
      final int top = q + _dataBarHeight(symbol) + textGap;
      return SymbolLayout._(
        width: symbol.width + 2 * mx,
        height: top + textFontSize + textGap + q,
        rects: List<ModuleRect>.unmodifiable(_mergedRects(symbol, mx, q)),
        text: text,
        textRuns: List<TextRun>.unmodifiable(<TextRun>[
          for (final _Digit d in digits)
            TextRun(
              d.digit,
              mx + d.x,
              (top + (d.small ? textFontSize - smallFontSize : 0)).toDouble(),
              (d.small ? smallFontSize : textFontSize).toDouble(),
            ),
        ]),
        quietZone: q,
        marginX: mx,
      );
    }
    final int top = q + symbol.height + textGap;
    return SymbolLayout._(
      width: symbol.width + 2 * q,
      height:
          symbol.height + 2 * q + (hasText ? textGap + textFontSize + 1 : 0),
      rects: List<ModuleRect>.unmodifiable(_mergedRects(symbol, q, q)),
      text: hasText ? text : null,
      textRuns: hasText
          ? List<TextRun>.unmodifiable(<TextRun>[
              TextRun(
                text,
                (symbol.width + 2 * q) / 2,
                top.toDouble(),
                textFontSize.toDouble(),
                fit: true,
              ),
            ])
          : const <TextRun>[],
      quietZone: q,
      marginX: q,
    );
  }

  const SymbolLayout._({
    required this.width,
    required this.height,
    required this.rects,
    required this.text,
    required this.textRuns,
    required this.quietZone,
    required this.marginX,
  });

  /// Space between the bars and the text, in modules.
  static const int textGap = 1;

  /// Height of the text, in modules (about what EAN/UPC print).
  static const int textFontSize = 9;

  /// Height of the outer digits of a UPC-A and UPC-E, in modules.
  static const int smallFontSize = 7;

  /// Room the outer EAN/UPC digits need beside the symbol, in modules.
  static const int _outsideRoom = 7;

  /// Total width, quiet zones included.
  final int width;

  /// Total height, quiet zones and text included.
  final int height;

  /// The dark modules, merged into as few rectangles as possible.
  final List<ModuleRect> rects;

  /// Human readable text under the bars, or `null`.
  final String? text;

  /// Where the human readable text goes.
  final List<TextRun> textRuns;

  /// The quiet zone above and under the symbol, in modules.
  final int quietZone;

  /// The margin left and right of the symbol, in modules: the quiet zone,
  /// or more where EAN/UPC digits stand outside a code without one.
  final int marginX;

  /// Runs of dark modules per row, merged with identical runs of the rows
  /// below (a bar of a linear barcode becomes one rectangle).
  static List<ModuleRect> _mergedRects(BarcodeSymbol s, int dx, int dy) {
    final List<ModuleRect> out = <ModuleRect>[];
    // Open rectangles by (x, width): their top row.
    Map<int, int> open = <int, int>{};
    int key(int x, int w) => x * 65536 + w;
    for (int y = 0; y <= s.height; y++) {
      final Map<int, int> next = <int, int>{};
      if (y < s.height) {
        int x = 0;
        while (x < s.width) {
          if (!s.isDark(x, y)) {
            x++;
            continue;
          }
          final int start = x;
          while (x < s.width && s.isDark(x, y)) {
            x++;
          }
          final int k = key(start, x - start);
          next[k] = open.remove(k) ?? y;
        }
      }
      // Whatever did not continue into this row ends above it.
      open.forEach((int k, int top) {
        out.add(ModuleRect(k ~/ 65536 + dx, top + dy, k % 65536, y - top));
      });
      open = next;
    }
    out.sort(
      (ModuleRect a, ModuleRect b) =>
          a.y != b.y ? a.y.compareTo(b.y) : a.x.compareTo(b.x),
    );
    return out;
  }

  /// The pixels per module that fit the layout into [size] x [size].
  int moduleSizeFor(int size) => math.max(1, size ~/ math.max(width, height));
}

/// Pixels per module for [size] (fit into `size` × `size`) or [moduleSize];
/// 4 without either.
///
/// Throws [ArgumentError] if both are given or one is not positive.
int pixelsPerModule(SymbolLayout layout, int? size, int? moduleSize) {
  if (size != null && moduleSize != null) {
    throw ArgumentError('Give either size or moduleSize, not both');
  }
  if ((size ?? 1) < 1 || (moduleSize ?? 1) < 1) {
    throw ArgumentError('size and moduleSize must be positive');
  }
  return size != null ? layout.moduleSizeFor(size) : moduleSize ?? 4;
}

/// Escapes text for XML content and attributes.
String xmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// A digit of EAN/UPC human readable text: its centre in symbol modules.
typedef _Digit = ({String digit, double x, bool small});

/// The rows of the data bars: the guard bars reach lower.
int _dataBarHeight(BarcodeSymbol s) {
  // The second symbol character: never long. The guards are, and so is the
  // first character of a UPC-A (its number system digit) and its last.
  int deepest = 0;
  for (int x = 10; x < 17 && x < s.width; x++) {
    for (int y = s.height - 1; y >= 0; y--) {
      if (s.isDark(x, y)) {
        deepest = math.max(deepest, y + 1);
        break;
      }
    }
  }
  return deepest == 0 ? s.height : deepest;
}

/// The GS1 layout of the digits of an EAN-13, EAN-8, UPC-A or UPC-E, or
/// `null` for other formats, an add-on, or text that does not fit it.
List<_Digit>? _eanUpcDigits(BarcodeSymbol s, String text) {
  ({String digit, double x, bool small}) at(
    int i,
    double x, {
    bool small = false,
  }) => (digit: text[i], x: x, small: small);
  // The centre of symbol character [c] after a guard at [start].
  double char(int start, int c) => start + 7.0 * c + 3.5;
  if (!RegExp(r'^\d+$').hasMatch(text)) {
    return null;
  }
  switch (s.format) {
    case BarcodeFormat.ean13 || BarcodeFormat.isbn
        when text.length == 13 && s.width == 95:
      return <_Digit>[
        at(0, -4.5),
        for (int i = 1; i < 7; i++) at(i, char(3, i - 1)),
        for (int i = 7; i < 13; i++) at(i, char(50, i - 7)),
      ];
    case BarcodeFormat.upcA when text.length == 12 && s.width == 95:
      return <_Digit>[
        at(0, -4, small: true),
        for (int i = 1; i < 6; i++) at(i, char(3, i)),
        for (int i = 6; i < 11; i++) at(i, char(50, i - 6)),
        at(11, 99, small: true),
      ];
    case BarcodeFormat.ean8 when text.length == 8 && s.width == 67:
      return <_Digit>[
        for (int i = 0; i < 4; i++) at(i, char(3, i)),
        for (int i = 4; i < 8; i++) at(i, char(36, i - 4)),
      ];
    case BarcodeFormat.upcE when text.length == 8 && s.width == 51:
      return <_Digit>[
        at(0, -4, small: true),
        for (int i = 1; i < 7; i++) at(i, char(3, i - 1)),
        at(7, 55, small: true),
      ];
    default:
      return null;
  }
}
