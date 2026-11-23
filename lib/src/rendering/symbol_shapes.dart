// The shapes of a BarcodeSymbol drawn with a BarcodeStyle, in module units:
// one source for BarcodeView, the styled PNG and the styled SVG, so that
// every output looks the same. Not exported from the package.
import 'dart:ui';

import '../barcode/barcode_format.dart';
import '../writing/barcode_writer.dart';
import '../writing/symbol_layout.dart';
import 'barcode_style.dart';

/// Receives shapes, in module units (quiet zone included).
abstract interface class ShapeSink {
  /// A rectangle.
  void rect(Rect rect);

  /// A rectangle with rounded corners.
  void rrect(RRect rrect);

  /// An ellipse inscribed in [rect].
  void oval(Rect rect);
}

/// Collects shapes into a [Path].
final class PathSink implements ShapeSink {
  /// Creates a sink that adds to [path].
  PathSink(this.path);

  /// The path the shapes are added to.
  final Path path;

  @override
  void rect(Rect rect) => path.addRect(rect);

  @override
  void rrect(RRect rrect) => path.addRRect(rrect);

  @override
  void oval(Rect rect) => path.addOval(rect);
}

/// Whether [format] gets [BarcodeStyle.moduleShape] (2D symbols made of
/// square modules; PDF417's tall row modules stay rectangles, and the
/// single finder of Micro QR and rMQR needs its square modules).
bool hasModuleShapes(BarcodeFormat format) => switch (format) {
  BarcodeFormat.qrCode ||
  BarcodeFormat.qrCodeModel2 ||
  BarcodeFormat.aztec ||
  BarcodeFormat.aztecCode ||
  BarcodeFormat.aztecRune ||
  BarcodeFormat.dataMatrix => true,
  _ => false,
};

/// Whether [format] has the three finder patterns [BarcodeStyle.finderShape]
/// applies to.
bool hasFinderPatterns(BarcodeFormat format) =>
    format == BarcodeFormat.qrCode || format == BarcodeFormat.qrCodeModel2;

/// [symbol] as [style] shows it: without its quiet zone when the style
/// leaves it out.
BarcodeSymbol styledSymbol(BarcodeSymbol symbol, BarcodeStyle style) =>
    style.quietZone ? symbol : withoutQuietZone(symbol);

/// The shapes of [symbol] drawn with [style].
final class SymbolShapes {
  /// Computes the shapes of [symbol] laid out as [layout].
  SymbolShapes(this.symbol, this.layout, this.style)
    : logo = _logoBox(symbol, style);

  /// The symbol.
  final BarcodeSymbol symbol;

  /// Its geometry.
  final SymbolLayout layout;

  /// Colors and shapes.
  final BarcodeStyle style;

  /// Where the logo goes, or `null` without one.
  final LogoBox? logo;

  /// The symbol without its quiet zone, in module units: what a gradient
  /// spans.
  Rect get symbolArea => Rect.fromLTWH(
    // Where the layout puts it: EAN/UPC without a quiet zone keep room for
    // their digits outside.
    layout.marginX.toDouble(),
    layout.quietZone.toDouble(),
    symbol.width.toDouble(),
    symbol.height.toDouble(),
  );

  /// Whether everything is plain rectangles ([SymbolLayout.rects]).
  bool get plain =>
      !hasModuleShapes(symbol.format) ||
      (style.moduleShape == ModuleShape.square &&
          (!hasFinderPatterns(symbol.format) ||
              style.finderShape == FinderShape.square) &&
          logo == null);

  /// Whether [finders] has shapes: they go into a separate even-odd path.
  bool get hasFinders => !plain && hasFinderPatterns(symbol.format);

  /// The dark modules; without the finder patterns when [hasFinders].
  void modules(ShapeSink sink) {
    if (plain) {
      for (final ModuleRect r in layout.rects) {
        sink.rect(
          Rect.fromLTWH(
            r.x.toDouble(),
            r.y.toDouble(),
            r.width.toDouble(),
            r.height.toDouble(),
          ),
        );
      }
      return;
    }
    final int q = symbol.quietZone;
    final int w = symbol.width;
    final int h = symbol.height;
    final bool finders = hasFinderPatterns(symbol.format);
    final LogoBox? logoBox = logo;
    bool skip(int x, int y) =>
        (finders && _inFinder(x, y)) ||
        (logoBox != null && logoBox.clears(x, y));
    bool dark(int x, int y) =>
        x >= 0 && y >= 0 && x < w && y < h && symbol.isDark(x, y);

    switch (style.moduleShape) {
      case ModuleShape.square:
        // Runs per row: fewer subpaths, one seamless fill.
        for (int y = 0; y < h; y++) {
          int x = 0;
          while (x < w) {
            if (!dark(x, y) || skip(x, y)) {
              x++;
              continue;
            }
            final int start = x;
            while (x < w && dark(x, y) && !skip(x, y)) {
              x++;
            }
            sink.rect(
              Rect.fromLTWH(
                (q + start).toDouble(),
                (q + y).toDouble(),
                (x - start).toDouble(),
                1,
              ),
            );
          }
        }
      case ModuleShape.rounded:
        // A corner is rounded only where both of its sides are open, so
        // neighbouring modules flow into one shape. A run of modules in a
        // row is one shape: inside it no corner is rounded.
        const Radius r = Radius.circular(0.5);
        bool on(int x, int y) => dark(x, y) && !skip(x, y);
        for (int y = 0; y < h; y++) {
          int x = 0;
          while (x < w) {
            if (!on(x, y)) {
              x++;
              continue;
            }
            final int start = x;
            while (x + 1 < w && on(x + 1, y)) {
              x++;
            }
            final int end = x++;
            final bool topLeft = !on(start, y - 1) && !on(start - 1, y);
            final bool bottomLeft = !on(start, y + 1) && !on(start - 1, y);
            final bool topRight = !on(end, y - 1) && !on(end + 1, y);
            final bool bottomRight = !on(end, y + 1) && !on(end + 1, y);
            final Rect run = Rect.fromLTRB(
              (q + start).toDouble(),
              (q + y).toDouble(),
              (q + end + 1).toDouble(),
              (q + y + 1).toDouble(),
            );
            if (!topLeft && !bottomLeft && !topRight && !bottomRight) {
              sink.rect(run);
            } else {
              sink.rrect(
                RRect.fromRectAndCorners(
                  run,
                  topLeft: topLeft ? r : Radius.zero,
                  topRight: topRight ? r : Radius.zero,
                  bottomRight: bottomRight ? r : Radius.zero,
                  bottomLeft: bottomLeft ? r : Radius.zero,
                ),
              );
            }
          }
        }
      case ModuleShape.circle:
        // Data Matrix is found by the solid edges of its data regions and
        // Aztec by its bullseye: those stay square, only the data becomes
        // dots.
        final bool Function(int x, int y) edge =
            switch (symbol.format.symbology) {
              BarcodeFormat.dataMatrix => _dataMatrixEdge(w, h),
              BarcodeFormat.aztec => _aztecCore(),
              _ => (int x, int y) => false,
            };
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            if (!dark(x, y) || skip(x, y)) {
              continue;
            }
            final Offset at = Offset(q + x + 0.5, q + y + 0.5);
            if (edge(x, y)) {
              sink.rect(Rect.fromCenter(center: at, width: 1, height: 1));
            } else {
              sink.oval(Rect.fromCircle(center: at, radius: 0.45));
            }
          }
        }
    }
  }

  /// The finder patterns, a ring and a core each: fill them even-odd.
  /// Nothing unless [hasFinders].
  void finders(ShapeSink sink) {
    if (!hasFinders) {
      return;
    }
    final int q = symbol.quietZone;
    for (final (int fx, int fy) in _finderOrigins) {
      final double x = (q + fx).toDouble();
      final double y = (q + fy).toDouble();
      final Rect outer = Rect.fromLTWH(x, y, 7, 7);
      final Rect hole = Rect.fromLTWH(x + 1, y + 1, 5, 5);
      final Rect core = Rect.fromLTWH(x + 2, y + 2, 3, 3);
      switch (style.finderShape) {
        case FinderShape.square:
          sink
            ..rect(outer)
            ..rect(hole)
            ..rect(core);
        case FinderShape.rounded:
          sink
            ..rrect(RRect.fromRectAndRadius(outer, const Radius.circular(2)))
            ..rrect(RRect.fromRectAndRadius(hole, const Radius.circular(1)))
            ..rrect(RRect.fromRectAndRadius(core, const Radius.circular(0.9)));
        case FinderShape.circle:
          sink
            ..oval(outer)
            ..oval(hole)
            ..oval(core);
      }
    }
  }

  /// Whether a module belongs to the bullseye, orientation marks or
  /// reference grid of an Aztec symbol. The bullseye has its outermost dark
  /// ring at distance 4 from the centre (compact) or 6 (full); a full
  /// symbol's ring at distance 5 is all light.
  bool Function(int x, int y) _aztecCore() {
    final int c = symbol.width ~/ 2;
    bool fullRange = true;
    for (int i = -5; i <= 5 && fullRange; i++) {
      for (final (int x, int y) in <(int, int)>[
        (c + i, c - 5),
        (c + i, c + 5),
        (c - 5, c + i),
        (c + 5, c + i),
      ]) {
        if (x < 0 ||
            y < 0 ||
            x >= symbol.width ||
            y >= symbol.height ||
            symbol.isDark(x, y)) {
          fullRange = false;
          break;
        }
      }
    }
    final int core = fullRange ? 7 : 5;
    return (int x, int y) =>
        ((x - c).abs() <= core && (y - c).abs() <= core) ||
        (fullRange && ((x - c) % 16 == 0 || (y - c) % 16 == 0));
  }

  /// Whether a module of a [w] × [h] Data Matrix lies on the finder or
  /// timing edge of a data region. Square symbols up to 26 modules have one
  /// region per side, up to 52 two, up to 104 four, larger ones six;
  /// rectangular ones (8–16 high) one or two across.
  static bool Function(int x, int y) _dataMatrixEdge(int w, int h) {
    int regions(int size) => size <= 26
        ? 1
        : size <= 52
        ? 2
        : size <= 104
        ? 4
        : 6;
    final int across = regions(w);
    final int down = regions(h);
    final int bw = w % across == 0 ? w ~/ across : w;
    final int bh = h % down == 0 ? h ~/ down : h;
    return (int x, int y) {
      final int bx = x % bw;
      final int by = y % bh;
      return bx == 0 || by == 0 || bx == bw - 1 || by == bh - 1;
    };
  }

  /// Top-left corners of the three 7 × 7 finder patterns of a QR code.
  List<(int, int)> get _finderOrigins => <(int, int)>[
    (0, 0),
    (symbol.width - 7, 0),
    (0, symbol.height - 7),
  ];

  bool _inFinder(int x, int y) {
    for (final (int fx, int fy) in _finderOrigins) {
      if (x >= fx && x < fx + 7 && y >= fy && y < fy + 7) {
        return true;
      }
    }
    return false;
  }

  /// Where the logo goes, in modules, or `null` without one (only QR codes
  /// have room for a logo: their error correction covers it; not Micro QR
  /// or rMQR, too small for one).
  static LogoBox? _logoBox(BarcodeSymbol symbol, BarcodeStyle style) {
    final BarcodeLogo? logo = style.logo;
    if (logo == null || !hasFinderPatterns(symbol.format)) {
      return null;
    }
    final double side = logo.size.clamp(0.0, 0.3) * symbol.width;
    if (side <= 0) {
      return null;
    }
    final int q = symbol.quietZone;
    final Rect rect = Rect.fromCenter(
      center: Offset(q + symbol.width / 2, q + symbol.height / 2),
      width: side,
      height: side,
    );
    if (!logo.clearBackground) {
      return LogoBox(rect, null);
    }
    // Clear every module the logo touches, with half a module to spare.
    final Rect cleared = rect
        .inflate(0.5)
        .shift(Offset(-q.toDouble(), -q.toDouble()));
    return LogoBox(rect, (
      cleared.left.floor(),
      cleared.top.floor(),
      cleared.right.ceil(),
      cleared.bottom.ceil(),
    ));
  }
}

/// The logo rectangle (module units, quiet zone included) and the modules
/// it clears (symbol coordinates, `right`/`bottom` exclusive), if any.
final class LogoBox {
  /// Creates a logo box.
  LogoBox(this.rect, this.cleared);

  /// Where the logo image goes.
  final Rect rect;

  /// The modules left light behind it.
  final (int, int, int, int)? cleared;

  /// Whether the module at [x], [y] is left light.
  bool clears(int x, int y) {
    final (int, int, int, int)? c = cleared;
    return c != null && x >= c.$1 && y >= c.$2 && x < c.$3 && y < c.$4;
  }
}
