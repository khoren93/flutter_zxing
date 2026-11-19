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

  /// [fontSize], with [fit] shrunk to [width] modules where the text cannot
  /// be measured: a monospace digit is about 0.6 of the size wide.
  double fittedSize(num width) => fit && text.isNotEmpty
      ? math.min(fontSize, width / (text.length * 0.6))
      : fontSize;
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
}

/// The size of an exported image: [moduleSize] pixels per module, and the
/// image [width] x [height] pixels.
typedef ExportSize = ({int moduleSize, int width, int height});

/// The size of an image of something [width] x [height] modules large, for
/// [size] or [moduleSize] as `BarcodeSymbol.toPng` takes them: [moduleSize]
/// pixels per module (4 without either), or the most whole pixels per
/// module that fit [size] across the longer side, which is then exactly
/// [size] pixels, the shorter one in proportion. [content] gives the pixels
/// the drawing itself takes at a module size; it may be a few pixels more
/// than the modules (a shadow rounded out to whole pixels).
///
/// Throws [ArgumentError] if both are given, one is not positive, or [size]
/// is smaller than the longer side in modules.
ExportSize exportSize(
  double width,
  double height,
  int? size,
  int? moduleSize, {
  (int, int) Function(int moduleSize)? content,
}) {
  if (size != null && moduleSize != null) {
    throw ArgumentError('Give either size or moduleSize, not both');
  }
  if ((size ?? 1) < 1 || (moduleSize ?? 1) < 1) {
    throw ArgumentError('size and moduleSize must be positive');
  }
  (int, int) pixels(int m) =>
      content?.call(m) ?? ((width * m).ceil(), (height * m).ceil());
  if (size == null) {
    final int m = moduleSize ?? 4;
    final (int w, int h) = pixels(m);
    return (moduleSize: m, width: w, height: h);
  }
  final double longer = math.max(width, height);
  int m = (size / longer).floor();
  while (m >= 1) {
    final (int w, int h) = pixels(m);
    if (math.max(w, h) <= size) {
      final bool wide = width >= height;
      final int shorter = math.max(
        wide ? h : w,
        (size * math.min(width, height) / longer).round(),
      );
      return (
        moduleSize: m,
        width: wide ? size : shorter,
        height: wide ? shorter : size,
      );
    }
    m--;
  }
  throw ArgumentError.value(
    size,
    'size',
    'is smaller than the code, ${longer.ceil()} modules across',
  );
}

/// Escapes text for XML content and attributes.
String xmlEscape(String s) => s
    // Characters XML 1.0 cannot hold, not even escaped.
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\uFFFE\uFFFF]'), '')
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
    case BarcodeFormat.ean13 || BarcodeFormat.isbn || BarcodeFormat.eanUpc
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
    case BarcodeFormat.ean8 || BarcodeFormat.eanUpc
        when text.length == 8 && s.width == 67:
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

/// The `width` and `height` of an SVG document of [width] x [height]
/// modules: [moduleSize] pixels per module (4 without either), or [size]
/// across the longer side.
///
/// Throws [ArgumentError] as [exportSize] does.
(String, String) svgSize(
  double width,
  double height,
  int? size,
  int? moduleSize,
) {
  final ExportSize checked = exportSize(width, height, size, moduleSize);
  final double scale = size == null
      ? checked.moduleSize.toDouble()
      : size / math.max(width, height);
  String n(double v) {
    final double r = (v * 1000).roundToDouble() / 1000;
    return r == r.roundToDouble() ? r.round().toString() : r.toString();
  }

  return (n(width * scale), n(height * scale));
}

/// [symbol] without its quiet zone.
BarcodeSymbol withoutQuietZone(BarcodeSymbol symbol) => symbol.quietZone == 0
    ? symbol
    : BarcodeSymbol(
        format: symbol.format,
        width: symbol.width,
        height: symbol.height,
        modules: symbol.modules,
        text: symbol.text,
        errorCorrection: symbol.errorCorrection,
      );
