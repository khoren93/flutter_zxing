// The geometry of a rendered BarcodeSymbol, in modules: one source for the
// SVG, the raster image and (stage 7) BarcodeView, so that every output
// looks the same. Not exported from the package.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

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

/// Where everything of a symbol goes, in modules.
///
/// The symbol sits inside its quiet zone; human readable text, if any, goes
/// under the bars, inside the bottom quiet zone's frame:
///
/// ```text
///   quiet zone
///   +---------------------+
///   | bars / modules      |
///   +---------------------+
///   text (textHeight)
///   quiet zone
/// ```
@immutable
final class SymbolLayout {
  /// Lays out [symbol].
  factory SymbolLayout(BarcodeSymbol symbol) {
    final int q = symbol.quietZone;
    final String? text = symbol.text;
    final bool hasText = text != null && text.isNotEmpty;
    return SymbolLayout._(
      width: symbol.width + 2 * q,
      height:
          symbol.height + 2 * q + (hasText ? textGap + textFontSize + 1 : 0),
      rects: List<ModuleRect>.unmodifiable(_mergedRects(symbol, q)),
      text: hasText ? text : null,
      textTop: q + symbol.height + textGap,
    );
  }

  const SymbolLayout._({
    required this.width,
    required this.height,
    required this.rects,
    required this.text,
    required this.textTop,
  });

  /// Space between the bars and the text, in modules.
  static const int textGap = 1;

  /// Height of the text, in modules (about what EAN/UPC print).
  static const int textFontSize = 9;

  /// Total width, quiet zones included.
  final int width;

  /// Total height, quiet zones and text included.
  final int height;

  /// The dark modules, merged into as few rectangles as possible.
  final List<ModuleRect> rects;

  /// Human readable text under the bars, or `null`.
  final String? text;

  /// Top of the text box.
  final int textTop;

  /// Horizontal centre of the text.
  double get textCenter => width / 2;

  /// Runs of dark modules per row, merged with identical runs of the rows
  /// below (a bar of a linear barcode becomes one rectangle).
  static List<ModuleRect> _mergedRects(BarcodeSymbol s, int offset) {
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
        out.add(
          ModuleRect(k ~/ 65536 + offset, top + offset, k % 65536, y - top),
        );
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
