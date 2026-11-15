// Paints a BarcodeSymbol with a BarcodeStyle: the renderer behind
// BarcodeView. Not exported from the package.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show CustomPainter;

import '../barcode/barcode_format.dart';
import 'barcode_view.dart';
import 'barcode_writer.dart';
import 'symbol_layout.dart';

/// Whether [format] gets [BarcodeStyle.moduleShape] (2D symbols made of
/// square modules; PDF417's tall row modules stay rectangles).
bool hasModuleShapes(BarcodeFormat format) => switch (format.symbology) {
  BarcodeFormat.qrCode ||
  BarcodeFormat.aztec ||
  BarcodeFormat.dataMatrix => true,
  _ => false,
};

/// Whether [format] has the three finder patterns [BarcodeStyle.finderShape]
/// applies to.
bool hasFinderPatterns(BarcodeFormat format) =>
    format == BarcodeFormat.qrCode || format == BarcodeFormat.qrCodeModel2;

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
    final int q = symbol.quietZone;
    final Rect symbolArea = Rect.fromLTWH(
      q.toDouble(),
      q.toDouble(),
      symbol.width.toDouble(),
      symbol.height.toDouble(),
    );
    final Paint ink = Paint();
    final Gradient? gradient = style.gradient;
    if (gradient != null) {
      ink.shader = gradient.createShader(
        symbolArea,
        textDirection: textDirection,
      );
    } else {
      ink.color = style.color;
    }

    canvas
      ..save()
      ..translate(origin.dx, origin.dy)
      ..scale(m);
    final _Logo? logoBox = _logoBox();
    if (!hasModuleShapes(symbol.format) ||
        (style.moduleShape == ModuleShape.square &&
            (!hasFinderPatterns(symbol.format) ||
                style.finderShape == FinderShape.square) &&
            logoBox == null)) {
      final Path path = Path();
      for (final ModuleRect r in layout.rects) {
        path.addRect(
          Rect.fromLTWH(
            r.x.toDouble(),
            r.y.toDouble(),
            r.width.toDouble(),
            r.height.toDouble(),
          ),
        );
      }
      canvas.drawPath(path, ink);
    } else {
      canvas.drawPath(_modules(logoBox), ink);
      if (hasFinderPatterns(symbol.format)) {
        canvas.drawPath(_finders(), ink);
      }
    }
    final ui.Image? image = logo;
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

  /// The modules, finder patterns and logo area excluded.
  Path _modules(_Logo? logoBox) {
    final Path path = Path();
    final int q = symbol.quietZone;
    final int w = symbol.width;
    final int h = symbol.height;
    final bool finders = hasFinderPatterns(symbol.format);
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
            path.addRect(
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
        // neighbouring modules flow into one shape.
        const Radius r = Radius.circular(0.5);
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            if (!dark(x, y) || skip(x, y)) {
              continue;
            }
            final bool up = dark(x, y - 1) && !skip(x, y - 1);
            final bool down = dark(x, y + 1) && !skip(x, y + 1);
            final bool left = dark(x - 1, y) && !skip(x - 1, y);
            final bool right = dark(x + 1, y) && !skip(x + 1, y);
            path.addRRect(
              RRect.fromRectAndCorners(
                Rect.fromLTWH((q + x).toDouble(), (q + y).toDouble(), 1, 1),
                topLeft: up || left ? Radius.zero : r,
                topRight: up || right ? Radius.zero : r,
                bottomRight: down || right ? Radius.zero : r,
                bottomLeft: down || left ? Radius.zero : r,
              ),
            );
          }
        }
      case ModuleShape.circle:
        // Data Matrix is found by the solid edges of its data regions and
        // Aztec by its bullseye: those stay square, only the data becomes
        // dots.
        final bool Function(int x, int y) edge = switch (symbol.format) {
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
              path.addRect(Rect.fromCenter(center: at, width: 1, height: 1));
            } else {
              path.addOval(Rect.fromCircle(center: at, radius: 0.45));
            }
          }
        }
    }
    return path;
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

  /// The finder patterns: a ring and a core each, even-odd filled.
  Path _finders() {
    final Path path = Path()..fillType = PathFillType.evenOdd;
    final int q = symbol.quietZone;
    for (final (int fx, int fy) in _finderOrigins) {
      final double x = (q + fx).toDouble();
      final double y = (q + fy).toDouble();
      final Rect outer = Rect.fromLTWH(x, y, 7, 7);
      final Rect hole = Rect.fromLTWH(x + 1, y + 1, 5, 5);
      final Rect core = Rect.fromLTWH(x + 2, y + 2, 3, 3);
      switch (style.finderShape) {
        case FinderShape.square:
          path
            ..addRect(outer)
            ..addRect(hole)
            ..addRect(core);
        case FinderShape.rounded:
          path
            ..addRRect(RRect.fromRectAndRadius(outer, const Radius.circular(2)))
            ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(1)))
            ..addRRect(
              RRect.fromRectAndRadius(core, const Radius.circular(0.9)),
            );
        case FinderShape.circle:
          path
            ..addOval(outer)
            ..addOval(hole)
            ..addOval(core);
      }
    }
    return path;
  }

  /// Where the logo goes, in modules, or `null` without one (only QR codes
  /// have room for a logo: their error correction covers it).
  _Logo? _logoBox() {
    final BarcodeLogo? logo = style.logo;
    if (logo == null || symbol.format.symbology != BarcodeFormat.qrCode) {
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
      return _Logo(rect, null);
    }
    // Clear every module the logo touches, with half a module to spare.
    final Rect cleared = rect
        .inflate(0.5)
        .shift(Offset(-q.toDouble(), -q.toDouble()));
    return _Logo(rect, (
      cleared.left.floor(),
      cleared.top.floor(),
      cleared.right.ceil(),
      cleared.bottom.ceil(),
    ));
  }

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

/// The logo rectangle (module units, quiet zone included) and the modules
/// it clears (symbol coordinates, `right`/`bottom` exclusive), if any.
final class _Logo {
  _Logo(this.rect, this.cleared);

  final Rect rect;
  final (int, int, int, int)? cleared;

  bool clears(int x, int y) {
    final (int, int, int, int)? c = cleared;
    return c != null && x >= c.$1 && y >= c.$2 && x < c.$3 && y < c.$4;
  }
}
