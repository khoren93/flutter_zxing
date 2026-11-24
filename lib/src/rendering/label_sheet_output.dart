// Where a code and its caption go on a label, and the pages of a
// BarcodeLabelSheet as SVG and PDF: one geometry for both files and the
// preview widget. Not exported from the package.
import 'dart:convert' show base64Encode, latin1;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../writing/barcode_writer.dart';
import '../writing/symbol_layout.dart';
import 'barcode_style.dart';
import 'frame_layout.dart';
import 'label_sheet.dart';
import 'pdf_deflate.dart' if (dart.library.io) 'pdf_deflate_io.dart';
import 'styled_export.dart';
import 'symbol_shapes.dart';

/// Space between a code and its caption, as a fraction of the caption size.
const double captionGap = 0.25;

/// Where the caption's baseline sits in its box, as a fraction of its
/// height: room for descenders under it.
const double captionBaseline = 0.78;

/// Width of a monospace character, as a fraction of the font size: exact
/// for Courier, about right for the monospace fonts SVG viewers pick.
const double monospaceAdvance = 0.6;

/// Points per millimetre.
const double pointsPerMm = 72 / 25.4;

/// Where the code and the caption of one label go, in millimetres.
@immutable
final class LabelPlacement {
  /// Creates a placement.
  const LabelPlacement({
    required this.code,
    required this.captionBox,
    required this.captionFontSize,
  });

  /// The code, quiet zone included, with the symbol's own proportions.
  final Rect code;

  /// The line of the caption, as wide as the label inside its padding;
  /// `null` when the sheet has no captions.
  final Rect? captionBox;

  /// The caption's font size: the sheet's, smaller for a caption that
  /// would not fit across.
  final double captionFontSize;

  /// The caption's baseline.
  double get baseline => captionBox!.top + captionBox!.height * captionBaseline;
}

/// The code of [layout] and [caption] on [label] (millimetres) of [sheet]:
/// the code as large as fits above the caption line, the two centered as
/// a group inside the padding.
LabelPlacement placeLabel(
  BarcodeLabelSheet sheet,
  Rect label,
  SymbolLayout layout,
  String? caption,
) {
  final double p = sheet.padding;
  final Rect inner = Rect.fromLTRB(
    label.left + p,
    label.top + p,
    label.right - p,
    label.bottom - p,
  );
  final double line = sheet.caption ? sheet.captionSize : 0;
  final double below = sheet.caption ? line * (1 + captionGap) : 0;
  double scale = math.min(
    inner.width / layout.width,
    (inner.height - below) / layout.height,
  );
  if (sheet.codeSize case final double size) {
    scale = math.min(scale, size / math.max(layout.width, layout.height));
  }
  final double w = layout.width * scale;
  final double h = layout.height * scale;
  final double top = inner.top + (inner.height - h - below) / 2;
  final Rect code = Rect.fromLTWH(
    inner.left + (inner.width - w) / 2,
    top,
    w,
    h,
  );
  if (!sheet.caption) {
    return LabelPlacement(code: code, captionBox: null, captionFontSize: 0);
  }
  final int chars = caption == null ? 0 : caption.runes.length;
  return LabelPlacement(
    code: code,
    captionBox: Rect.fromLTWH(
      inner.left,
      code.bottom + line * captionGap,
      inner.width,
      line,
    ),
    captionFontSize: chars == 0
        ? line
        : math.min(line, inner.width / (chars * monospaceAdvance)),
  );
}

/// Throws [ArgumentError] if the labels of [sheet] leave no room for a
/// code.
void checkRoom(BarcodeLabelSheet sheet) {
  final Rect label = sheet.labelRect(0);
  final double p = sheet.padding;
  final double below = sheet.caption ? sheet.captionSize * (1 + captionGap) : 0;
  if (label.width - 2 * p <= 0 || label.height - 2 * p - below <= 0) {
    throw ArgumentError(
      'The labels (${_n(label.width)} x ${_n(label.height)} mm) leave no '
      'room for a code inside the padding and caption',
    );
  }
}

/// A number with at most three decimals, without trailing zeros.
String _n(double v) {
  final int i = (v * 1000).round();
  if (i % 1000 == 0) {
    return (i ~/ 1000).toString();
  }
  // Integer arithmetic: a page of styled codes formats a lot of numbers.
  final int a = i.abs();
  return '${i < 0 ? '-' : ''}${a ~/ 1000}${_fractions[a % 1000]}';
}

/// `.001` to `.999` without trailing zeros, by thousandths.
final List<String> _fractions = List<String>.generate(1000, (int f) {
  String s = '.${f.toString().padLeft(3, '0')}';
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
});

/// [v] with at most [decimals] decimals, without trailing zeros.
String _fixed(double v, int decimals) {
  String s = v.toStringAsFixed(decimals);
  if (s.contains('.')) {
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) {
      s = s.substring(0, s.length - 1);
    }
  }
  return s == '-0' ? '0' : s;
}

/// [v] rounded to three decimals.
double _r(double v) => (v * 1000).roundToDouble() / 1000;

/// The style of [sheet] without what a label does not draw: its title,
/// caption and card.
BarcodeStyle codeStyleOf(BarcodeLabelSheet sheet) {
  final BarcodeStyle style = sheet.style;
  return style.title == null && style.caption == null && style.card == null
      ? style
      : style.copyWith(
          title: () => null,
          caption: () => null,
          card: () => null,
        );
}

/// Whether [style] draws a code as the plain black rectangles of
/// `BarcodeSymbol.toSvgElement` and the PDF's black `re`: black modules,
/// no gradient, on white (or no) paper, square shapes and no logo for
/// [shown].
bool _plainInk(BarcodeStyle style, BarcodeSymbol shown) =>
    style.color.toARGB32() == 0xFF000000 &&
    style.gradient == null &&
    _blankBackground(style) &&
    SymbolShapes(shown, SymbolLayout(shown), style).plain;

/// Whether the code's background is the white of the paper (or none).
bool _blankBackground(BarcodeStyle style) =>
    style.backgroundColor.a == 0 ||
    style.backgroundColor.toARGB32() == 0xFFFFFFFF;

/// The id of the logo's `<symbol>` in an SVG page.
const String svgLogoId = 'zx-logo';

/// One page of [sheet] as an SVG document in millimetres: [symbols] on
/// the labels [slots] name (see [BarcodeLabelSheet.labelRect]; by default
/// the first, in order), [captions] under them (`null`: none), each code
/// drawn with [BarcodeLabelSheet.style]. [logo] is the style's logo,
/// loaded once for the whole sheet; without it the codes have none.
String svgPage(
  BarcodeLabelSheet sheet,
  List<BarcodeSymbol> symbols,
  List<String?> captions, {
  List<int>? slots,
  SheetLogo? logo,
}) {
  final PaperSize paper = sheet.paper;
  final BarcodeStyle style = codeStyleOf(sheet);
  final Map<String, String> defs = <String, String>{};
  bool usesLogo = false;
  final StringBuffer labels = StringBuffer();
  for (int i = 0; i < symbols.length; i++) {
    final BarcodeSymbol shown = styledSymbol(symbols[i], style);
    final String? caption = captions[i];
    final LabelPlacement at = placeLabel(
      sheet,
      sheet.labelRect(slots?[i] ?? i),
      SymbolLayout(shown),
      caption,
    );
    if (_plainInk(style, shown)) {
      labels.write(
        shown.toSvgElement(
          x: _r(at.code.left),
          y: _r(at.code.top),
          width: _r(at.code.width),
          height: _r(at.code.height),
        ),
      );
    } else {
      final String? logoId = logo == null ? null : svgLogoId;
      usesLogo |=
          logoId != null &&
          SymbolShapes(shown, SymbolLayout(shown), style).logo != null;
      labels.write(
        styledSvgElement(
          shown,
          style,
          x: _r(at.code.left),
          y: _r(at.code.top),
          width: _r(at.code.width),
          height: _r(at.code.height),
          defs: defs,
          logoId: logoId,
        ),
      );
    }
    final Rect? box = at.captionBox;
    if (box != null && caption != null && caption.isNotEmpty) {
      labels
        ..write('<text x="${_n(box.center.dx)}" y="${_n(at.baseline)}" ')
        ..write('font-family="monospace" ')
        ..write('font-size="${_n(at.captionFontSize)}" ')
        ..write('text-anchor="middle" fill="#000">')
        ..write(xmlEscape(caption))
        ..write('</text>');
    }
  }
  final StringBuffer svg = StringBuffer()
    ..write('<svg xmlns="http://www.w3.org/2000/svg" ');
  if (usesLogo) {
    svg.write('xmlns:xlink="http://www.w3.org/1999/xlink" ');
  }
  svg
    ..write('width="${_n(paper.width)}mm" height="${_n(paper.height)}mm" ')
    ..write('viewBox="0 0 ${_n(paper.width)} ${_n(paper.height)}">')
    ..write('<rect width="100%" height="100%" fill="#fff"/>');
  if (defs.isNotEmpty || usesLogo) {
    svg
      ..write('<defs>')
      ..writeAll(defs.values);
    if (usesLogo) {
      svg.write(svgLogoSymbol(svgLogoId, logo!.png!, logo.width, logo.height));
    }
    svg.write('</defs>');
  }
  svg
    ..write(labels)
    ..write('</svg>');
  return svg.toString();
}

/// The content stream of one page of [sheet] as a PDF draws it: in
/// millimetres with y down, the codes drawn with [BarcodeLabelSheet.style]
/// (black rectangles for the classic style), Courier for the text.
/// [symbols] go on the labels [slots] name, as for [svgPage].
///
/// A style with a gradient or a logo needs [resources], which adds the
/// shadings and the logo image to the document and lists those the page
/// uses; throws [ArgumentError] without it.
String pdfPageContent(
  BarcodeLabelSheet sheet,
  List<BarcodeSymbol> symbols,
  List<String?> captions, {
  List<int>? slots,
  PdfPageResources? resources,
}) {
  final BarcodeStyle style = codeStyleOf(sheet);
  final StringBuffer out = StringBuffer()
    ..write('q\n')
    ..write('${pointsPerMm.toStringAsFixed(7)} 0 0 ')
    ..write('-${pointsPerMm.toStringAsFixed(7)} 0 ')
    ..write('${_n(sheet.paper.height * pointsPerMm)} cm\n')
    ..write('0 g\n');
  for (int i = 0; i < symbols.length; i++) {
    final BarcodeSymbol shown = styledSymbol(symbols[i], style);
    final SymbolLayout layout = SymbolLayout(shown);
    final String? caption = captions[i];
    final LabelPlacement at = placeLabel(
      sheet,
      sheet.labelRect(slots?[i] ?? i),
      layout,
      caption,
    );
    // The code in module units.
    final double m = at.code.width / layout.width;
    final String scale = m.toStringAsFixed(6);
    out.write(
      'q $scale 0 0 $scale ${_n(at.code.left)} ${_n(at.code.top)} cm\n',
    );
    if (_plainInk(style, shown)) {
      for (final ModuleRect r in layout.rects) {
        out.write('${r.x} ${r.y} ${r.width} ${r.height} re\n');
      }
      out.write('f\n');
    } else {
      // Module units to the page's default space (points, y up), for a
      // gradient's pattern.
      final double s = double.parse(scale);
      final List<double> toPage = _concat(<double>[
        s,
        0,
        0,
        s,
        double.parse(_n(at.code.left)),
        double.parse(_n(at.code.top)),
      ], _pageSpace(sheet));
      _pdfStyledCode(out, shown, layout, style, resources, toPage);
      final Color text = textColorOf(style);
      if (layout.textRuns.isNotEmpty && text.toARGB32() != 0xFF000000) {
        out.write('${_rgb(text)} rg\n');
      }
    }
    for (final TextRun t in layout.textRuns) {
      final double size = t.fittedSize(layout.width);
      _pdfText(out, t.text, t.x, t.top + t.fontSize, size);
    }
    out.write('Q\n');
    if (at.captionBox != null && caption != null && caption.isNotEmpty) {
      _pdfText(
        out,
        caption,
        at.captionBox!.center.dx,
        at.baseline,
        at.captionFontSize,
      );
    }
  }
  out.write('Q\n');
  return out.toString();
}

/// Millimetres with y down to the page's default space, as the content
/// stream's first `cm`.
List<double> _pageSpace(BarcodeLabelSheet sheet) {
  final double k = double.parse(pointsPerMm.toStringAsFixed(7));
  return <double>[
    k,
    0,
    0,
    -k,
    0,
    double.parse(_n(sheet.paper.height * pointsPerMm)),
  ];
}

/// The PDF matrix [a] then [b]: `a b cm` in one.
List<double> _concat(List<double> a, List<double> b) => <double>[
  a[0] * b[0] + a[1] * b[2],
  a[0] * b[1] + a[1] * b[3],
  a[2] * b[0] + a[3] * b[2],
  a[2] * b[1] + a[3] * b[3],
  a[4] * b[0] + a[5] * b[2] + b[4],
  a[4] * b[1] + a[5] * b[3] + b[5],
];

/// [shown] drawn with [style] in module units (y down): its background
/// unless white, the modules as one path and the finders as another
/// (even-odd), dots as round dots of a stroke, in the color or in the
/// gradient's shading pattern, then the logo image. [toPage] maps module
/// units to the page's default space, where a pattern is placed.
void _pdfStyledCode(
  StringBuffer out,
  BarcodeSymbol shown,
  SymbolLayout layout,
  BarcodeStyle style,
  PdfPageResources? resources,
  List<double> toPage,
) {
  final SymbolShapes shapes = SymbolShapes(shown, layout, style);
  final Gradient? gradient = style.gradient;
  if ((gradient != null || shapes.logo != null) && resources == null) {
    throw ArgumentError(
      'A style with a gradient or a logo needs the resources of the PDF',
    );
  }
  if (!_blankBackground(style)) {
    out.write(
      '${_rgb(style.backgroundColor)} rg\n'
      '0 0 ${layout.width} ${layout.height} re f\n',
    );
  }
  if (gradient == null) {
    final String rgb = _rgb(style.color);
    out.write('$rgb rg\n');
    _pdfModules(out, shapes, '$rgb RG\n');
  } else {
    final (String dict, List<double> space) = pdfShading(
      gradient,
      shapes.symbolArea,
    );
    final String name = resources!.pattern(dict, _concat(space, toPage));
    out.write('/Pattern cs /$name scn\n');
    _pdfModules(out, shapes, '/Pattern CS /$name SCN\n');
  }
  final LogoBox? logoBox = shapes.logo;
  final SheetLogo? logo = resources?.logo;
  if (logoBox != null && logo != null) {
    final String name = resources!.logoName();
    final FittedSizes fitted = applyBoxFit(
      BoxFit.contain,
      Size(logo.width.toDouble(), logo.height.toDouble()),
      logoBox.rect.size,
    );
    final Rect r = Alignment.center.inscribe(fitted.destination, logoBox.rect);
    // Image space is a unit square, y up.
    out.write(
      'q ${_n(r.width)} 0 0 ${_n(-r.height)} ${_n(r.left)} ${_n(r.bottom)} '
      'cm /$name Do Q\n',
    );
  }
}

/// The modules and finders of [shapes] filled in the current color; the
/// dots of [ModuleShape.circle] as one stroke of round dots in the stroke
/// color [stroke] sets: a few bytes a dot instead of four curves.
void _pdfModules(StringBuffer out, SymbolShapes shapes, String stroke) {
  final _PdfSink sink = _PdfSink(out, dots: StringBuffer());
  shapes.modules(sink);
  out.write('f\n');
  final double? dot = sink.dotSize;
  if (dot != null) {
    out
      ..write(stroke)
      ..write('${_n(dot)} w 1 J\n')
      ..write(sink.dots)
      ..write('S\n');
  }
  if (shapes.hasFinders) {
    shapes.finders(_PdfSink(out));
    out.write('f*\n');
  }
}

/// [c] as PDF RGB components, opaque.
String _rgb(Color c) {
  final int v = c.toARGB32();
  return '${_n(((v >> 16) & 0xFF) / 255)} ${_n(((v >> 8) & 0xFF) / 255)} '
      '${_n((v & 0xFF) / 255)}';
}

/// Writes shapes as PDF path operators (module units, y down).
final class _PdfSink implements ShapeSink {
  _PdfSink(this._out, {this.dots});

  final StringBuffer _out;

  /// Where circles of one size go as zero-length lines, to be stroked with
  /// round caps (a filled circle, by the PDF specification); `null` draws
  /// them as curves.
  final StringBuffer? dots;

  /// The diameter of the circles in [dots].
  double? dotSize;

  /// The control point distance of a quarter circle drawn with one cubic
  /// Bézier, as a fraction of the radius.
  static const double _k = 0.5522847498;

  @override
  void rect(Rect r) => _out.write(
    '${_n(r.left)} ${_n(r.top)} ${_n(r.width)} ${_n(r.height)} re\n',
  );

  @override
  void rrect(RRect r) {
    final double tl = r.tlRadiusX;
    final double tr = r.trRadiusX;
    final double br = r.brRadiusX;
    final double bl = r.blRadiusX;
    const double k = _k;
    _move(r.left + tl, r.top);
    _line(r.right - tr, r.top);
    if (tr > 0) {
      _curve(
        r.right - tr * (1 - k),
        r.top,
        r.right,
        r.top + tr * (1 - k),
        r.right,
        r.top + tr,
      );
    }
    _line(r.right, r.bottom - br);
    if (br > 0) {
      _curve(
        r.right,
        r.bottom - br * (1 - k),
        r.right - br * (1 - k),
        r.bottom,
        r.right - br,
        r.bottom,
      );
    }
    _line(r.left + bl, r.bottom);
    if (bl > 0) {
      _curve(
        r.left + bl * (1 - k),
        r.bottom,
        r.left,
        r.bottom - bl * (1 - k),
        r.left,
        r.bottom - bl,
      );
    }
    if (tl > 0) {
      _line(r.left, r.top + tl);
      _curve(
        r.left,
        r.top + tl * (1 - k),
        r.left + tl * (1 - k),
        r.top,
        r.left + tl,
        r.top,
      );
    }
    _out.write('h\n');
  }

  /// The current point.
  double _x = 0;
  double _y = 0;

  void _move(double x, double y) {
    _out.write('${_n(x)} ${_n(y)} m\n');
    _x = x;
    _y = y;
  }

  /// A line to [x], [y], unless the current point is already there.
  void _line(double x, double y) {
    if (x != _x || y != _y) {
      _out.write('${_n(x)} ${_n(y)} l\n');
      _x = x;
      _y = y;
    }
  }

  void _curve(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    _out.write(
      '${_n(x1)} ${_n(y1)} ${_n(x2)} ${_n(y2)} ${_n(x3)} ${_n(y3)} c\n',
    );
    _x = x3;
    _y = y3;
  }

  @override
  void oval(Rect r) {
    final StringBuffer? dots = this.dots;
    if (dots != null &&
        r.width == r.height &&
        (dotSize == null || dotSize == r.width)) {
      dotSize = r.width;
      final String at = '${_n(r.center.dx)} ${_n(r.center.dy)}';
      dots.write('$at m $at l\n');
      return;
    }
    final double cx = r.center.dx;
    final double cy = r.center.dy;
    final double rx = r.width / 2;
    final double ry = r.height / 2;
    final double kx = rx * _k;
    final double ky = ry * _k;
    _move(cx + rx, cy);
    _curve(cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry);
    _curve(cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy);
    _curve(cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry);
    _curve(cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy);
    _out.write('h\n');
  }
}

/// [gradient] spanning [area] (module units) as a PDF shading dictionary,
/// and the matrix that maps the shading's space into module units.
///
/// The shading is in a space with its origin at the top left of [area]
/// and one unit its shorter side, so every code of the same proportions
/// shares one shading object. A [LinearGradient] is an axial shading
/// (type 2), a [RadialGradient] a radial one (type 3); two colors are one
/// exponential function (type 2), more a stitching function (type 3). The
/// colors are opaque, and [TileMode.repeated] and [TileMode.mirror] extend
/// the end colors as [TileMode.clamp] does: PDF shadings do not repeat.
///
/// Throws [UnsupportedError] for any other gradient.
(String, List<double>) pdfShading(Gradient gradient, Rect area) {
  const TextDirection direction = TextDirection.ltr;
  final double unit = area.shortestSide;
  Offset local(Offset p) => (p - area.topLeft) / unit;
  final StringBuffer d = StringBuffer();
  final bool extend;
  switch (gradient) {
    case LinearGradient(
      :final AlignmentGeometry begin,
      :final AlignmentGeometry end,
      :final TileMode tileMode,
    ):
      final Offset a = local(begin.resolve(direction).withinRect(area));
      final Offset b = local(end.resolve(direction).withinRect(area));
      extend = tileMode != TileMode.decal;
      d.write(
        '<</ShadingType 2/ColorSpace/DeviceRGB/Coords['
        '${_n(a.dx)} ${_n(a.dy)} ${_n(b.dx)} ${_n(b.dy)}]',
      );
    case RadialGradient(
      :final AlignmentGeometry center,
      :final double radius,
      :final AlignmentGeometry? focal,
      :final double focalRadius,
      :final TileMode tileMode,
    ):
      final Offset c = local(center.resolve(direction).withinRect(area));
      final Offset f = focal == null
          ? c
          : local(focal.resolve(direction).withinRect(area));
      extend = tileMode != TileMode.decal;
      d.write(
        '<</ShadingType 3/ColorSpace/DeviceRGB/Coords['
        '${_n(f.dx)} ${_n(f.dy)} ${_n(focal == null ? 0 : focalRadius)} '
        '${_n(c.dx)} ${_n(c.dy)} ${_n(radius)}]',
      );
    default:
      throw UnsupportedError(
        'Label sheets draw LinearGradient and RadialGradient, '
        'not ${gradient.runtimeType}',
      );
  }
  d
    ..write('/Function')
    ..write(_pdfFunction(gradient.colors, gradient.stops))
    ..write('/Extend[$extend $extend]>>');
  final List<double> unitSpace = <double>[
    unit,
    0,
    0,
    unit,
    area.left,
    area.top,
  ];
  final Float64List? t = gradient.transform
      ?.transform(area, textDirection: direction)
      ?.storage;
  final List<double> space = t == null
      ? unitSpace
      : _concat(unitSpace, <double>[t[0], t[1], t[4], t[5], t[12], t[13]]);
  return (d.toString(), space);
}

/// [colors] at [stops] (evenly spread without) over 0–1 as a PDF function.
String _pdfFunction(List<Color> colors, List<double>? stops) {
  final List<(double, Color)> points = <(double, Color)>[
    for (int i = 0; i < colors.length; i++)
      (
        (stops?[i] ?? (colors.length == 1 ? 0 : i / (colors.length - 1))).clamp(
          0.0,
          1.0,
        ),
        colors[i],
      ),
  ];
  if (points.first.$1 > 0) {
    points.insert(0, (0, points.first.$2));
  }
  if (points.last.$1 < 1) {
    points.add((1, points.last.$2));
  }
  String segment(Color a, Color b) =>
      '<</FunctionType 2/Domain[0 1]/C0[${_rgb(a)}]/C1[${_rgb(b)}]/N 1>>';
  if (points.length == 2) {
    return segment(points[0].$2, points[1].$2);
  }
  final StringBuffer f = StringBuffer(
    '<</FunctionType 3/Domain[0 1]/Functions[',
  );
  for (int i = 0; i + 1 < points.length; i++) {
    f.write(segment(points[i].$2, points[i + 1].$2));
  }
  f.write(']/Bounds[');
  f.write(
    <String>[
      for (int i = 1; i + 1 < points.length; i++) _n(points[i].$1),
    ].join(' '),
  );
  f.write(']/Encode[');
  f.write(List<String>.filled(points.length - 1, '0 1').join(' '));
  f.write(']>>');
  return f.toString();
}

/// The logo of a sheet's style, loaded once for all its pages: the PNG
/// for SVG, the pixels for PDF.
final class SheetLogo {
  /// Creates a logo of [width] x [height] pixels.
  const SheetLogo({
    required this.width,
    required this.height,
    this.png,
    this.rgb,
    this.alpha,
  });

  /// Size in pixels.
  final int width;

  /// Size in pixels.
  final int height;

  /// The image as a PNG in base64, for SVG.
  final String? png;

  /// The pixels as RGB, 8 bits each, row by row, for PDF.
  final Uint8List? rgb;

  /// Their alpha, 8 bits each; `null` when the image is opaque.
  final Uint8List? alpha;
}

/// The logo of [sheet]'s style (`null` without one), [png] for SVG or the
/// pixels for PDF, sharp at 300 dpi on the largest code the labels hold
/// and never more than twice that.
///
/// Throws [ArgumentError] naming the image's error if it cannot be loaded.
Future<SheetLogo?> loadSheetLogo(
  BarcodeLabelSheet sheet, {
  required bool png,
}) async {
  final BarcodeLogo? logo = sheet.style.logo;
  if (logo == null || !hasFinderPatterns(sheet.writer.format)) {
    return null;
  }
  final Rect label = sheet.labelRect(0).deflate(sheet.padding);
  final double below = sheet.caption ? sheet.captionSize * (1 + captionGap) : 0;
  double side = math.min(label.width, label.height - below);
  if (sheet.codeSize case final double size) {
    side = math.min(side, size);
  }
  final double pixels = math.max(
    32,
    side * logo.size.clamp(0.0, 0.3) / 25.4 * 300,
  );
  ImageInfo? info;
  try {
    info = await loadLogo(logo, pixels);
  } on Object catch (e) {
    throw ArgumentError('The logo of the style cannot be loaded: $e');
  }
  if (info == null) {
    return null;
  }
  ui.Image image = info.image;
  ui.Image? scaled;
  try {
    if (image.width > pixels * 2) {
      // A large image drawn small: embedded at the size it prints.
      final double f = pixels * 2 / image.width;
      final int w = math.max(1, (image.width * f).round());
      final int h = math.max(1, (image.height * f).round());
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );
      final ui.Picture picture = recorder.endRecording();
      scaled = await picture.toImage(w, h);
      picture.dispose();
      image = scaled;
    }
    if (png) {
      final ByteData data = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      return SheetLogo(
        width: image.width,
        height: image.height,
        png: base64Encode(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
      );
    }
    final ByteData data = (await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!;
    final Uint8List rgba = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final int n = image.width * image.height;
    final Uint8List rgb = Uint8List(n * 3);
    final Uint8List alpha = Uint8List(n);
    bool opaque = true;
    for (int i = 0; i < n; i++) {
      rgb[i * 3] = rgba[i * 4];
      rgb[i * 3 + 1] = rgba[i * 4 + 1];
      rgb[i * 3 + 2] = rgba[i * 4 + 2];
      final int a = rgba[i * 4 + 3];
      alpha[i] = a;
      opaque &= a == 255;
    }
    return SheetLogo(
      width: image.width,
      height: image.height,
      rgb: rgb,
      alpha: opaque ? null : alpha,
    );
  } finally {
    scaled?.dispose();
    info.dispose();
  }
}

/// The gradient patterns and the logo of one page, added to the document
/// the first time any page uses them: each shading, each pattern (a
/// shading placed on the page) and the logo image are in the file once.
final class PdfPageResources {
  /// Resources of a page of [document].
  PdfPageResources(this.document);

  /// What the pages of the document share.
  final PdfStyleResources document;

  final Map<String, int> _patterns = <String, int>{};
  bool _logo = false;

  /// The logo, if the style has one.
  SheetLogo? get logo => document.logo;

  /// The name on this page of the shading [dict] placed by [matrix]
  /// (shading space to the page's default space) as a pattern.
  String pattern(String dict, List<double> matrix) {
    final int object = document._pattern(dict, matrix);
    final String name = 'P$object';
    _patterns[name] = object;
    return name;
  }

  /// The name of the logo image on this page.
  String logoName() {
    document._logoObject();
    _logo = true;
    return 'Logo';
  }

  /// The entries of the page's `/Resources` besides the font.
  String get entries {
    final StringBuffer s = StringBuffer();
    if (_logo) {
      s.write('/XObject<</Logo ${document._logoObject()} 0 R>>');
    }
    if (_patterns.isNotEmpty) {
      s
        ..write('/Pattern<<')
        ..writeAll(<String>[
          for (final MapEntry<String, int> e in _patterns.entries)
            '/${e.key} ${e.value} 0 R',
        ])
        ..write('>>');
    }
    return s.toString();
  }
}

/// The shadings, patterns and the logo image of a whole document.
final class PdfStyleResources {
  /// Resources written into [writer]; [logo] is the style's logo.
  PdfStyleResources(this.writer, this.logo);

  /// The document.
  final PdfWriter writer;

  /// The style's logo, loaded once.
  final SheetLogo? logo;

  final Map<String, int> _shadings = <String, int>{};
  final Map<String, int> _patterns = <String, int>{};
  int? _logo;

  /// A shading pattern of [dict] placed by [matrix]: codes of one size at
  /// one place of a page share it on every page.
  int _pattern(String dict, List<double> matrix) {
    final int shading = _shadings[dict] ??= writer.addObject(dict);
    final String place = matrix.map((double v) => _fixed(v, 4)).join(' ');
    final String body =
        '<</PatternType 2/Shading $shading 0 R/Matrix[$place]>>';
    return _patterns[body] ??= writer.addObject(body);
  }

  int _logoObject() {
    if (_logo case final int n) {
      return n;
    }
    final SheetLogo image = logo!;
    final String size =
        '/Width ${image.width}/Height ${image.height}/BitsPerComponent 8';
    final Uint8List? alpha = image.alpha;
    final int? mask = alpha == null
        ? null
        : writer.addStream(
            '/Type/XObject/Subtype/Image$size/ColorSpace/DeviceGray',
            alpha,
          );
    return _logo = writer.addStream(
      '/Type/XObject/Subtype/Image$size/ColorSpace/DeviceRGB'
      '${mask == null ? '' : '/SMask $mask 0 R'}',
      image.rgb!,
    );
  }
}

/// [text] in Courier at [size], centered on [x], its baseline at [y], in
/// a space with y down.
void _pdfText(StringBuffer out, String text, double x, double y, double size) {
  final double width = text.runes.length * monospaceAdvance * size;
  out
    ..write('BT /F1 ${_n(size)} Tf 1 0 0 -1 ')
    ..write('${_n(x - width / 2)} ${_n(y)} Tm ')
    ..write(pdfString(text))
    ..write(' Tj ET\n');
}

/// [text] as a PDF string in WinAnsiEncoding, ASCII only: Latin-1
/// characters as octal escapes, any other character as `?`.
String pdfString(String text) {
  final StringBuffer s = StringBuffer('(');
  for (final int r in text.runes) {
    if (r == 0x28 || r == 0x29 || r == 0x5C) {
      s
        ..write(r'\')
        ..writeCharCode(r);
    } else if (r >= 0x20 && r < 0x7F) {
      s.writeCharCode(r);
    } else if (r >= 0xA0 && r <= 0xFF) {
      s.write('\\${r.toRadixString(8)}');
    } else {
      s.write('?');
    }
  }
  s.write(')');
  return s.toString();
}

/// Writes a PDF of pages that draw with the built-in Courier font: the
/// pages as they come, then the page tree and the cross-reference table.
final class PdfWriter {
  /// Starts a document.
  PdfWriter() {
    _write('%PDF-1.4\n');
    // A comment of high bytes: tells tools the file is binary.
    _bytes.add(const <int>[0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
    _object(1, '<</Type/Catalog/Pages 2 0 R>>');
    _object(
      3,
      '<</Type/Font/Subtype/Type1/BaseFont/Courier'
      '/Encoding/WinAnsiEncoding>>',
    );
  }

  final BytesBuilder _bytes = BytesBuilder(copy: false);

  /// The byte offset of each object, by number.
  final Map<int, int> _offsets = <int, int>{};
  final List<int> _pages = <int>[];
  int _next = 4;

  void _write(String s) => _bytes.add(latin1.encode(s));

  void _object(int number, String body) {
    _offsets[number] = _bytes.length;
    _write('$number 0 obj\n$body\nendobj\n');
  }

  /// Adds a page [width] x [height] millimetres drawn by [content], with
  /// [resources] (entries such as `/XObject<<…>>`) besides the font.
  void addPage(
    double width,
    double height,
    String content, {
    String resources = '',
  }) {
    final int page = _next++;
    final int stream = _next++;
    _pages.add(page);
    final String box =
        '0 0 ${_n(width * pointsPerMm)} '
        '${_n(height * pointsPerMm)}';
    _object(
      page,
      '<</Type/Page/Parent 2 0 R/MediaBox[$box]'
      ' /Resources<</Font<</F1 3 0 R>>$resources>> /Contents $stream 0 R>>',
    );
    _stream(stream, '', latin1.encode(content));
  }

  /// Adds an object of [body] and returns its number.
  int addObject(String body) {
    final int number = _next++;
    _object(number, body);
    return number;
  }

  /// Adds a stream of [data] with the entries [dict] (besides its length
  /// and filter) and returns its number.
  int addStream(String dict, Uint8List data) {
    final int number = _next++;
    _stream(number, dict, data);
    return number;
  }

  /// Writes stream [number], compressed where zlib is available.
  void _stream(int number, String dict, Uint8List raw) {
    final Uint8List? packed = deflate(raw);
    final Uint8List data = packed ?? raw;
    _offsets[number] = _bytes.length;
    _write(
      '$number 0 obj\n<<$dict/Length ${data.length}'
      '${packed == null ? '' : '/Filter/FlateDecode'}>>\nstream\n',
    );
    _bytes.add(data);
    _write('\nendstream\nendobj\n');
  }

  /// The finished document.
  Uint8List close() {
    _object(
      2,
      '<</Type/Pages/Kids[${_pages.map((int p) => '$p 0 R').join(' ')}]'
      '/Count ${_pages.length}>>',
    );
    final int xref = _bytes.length;
    final StringBuffer table = StringBuffer('xref\n0 $_next\n')
      ..write('0000000000 65535 f \n');
    for (int i = 1; i < _next; i++) {
      table.write('${_offsets[i]!.toString().padLeft(10, '0')} 00000 n \n');
    }
    table
      ..write('trailer\n<</Size $_next/Root 1 0 R>>\n')
      ..write('startxref\n$xref\n%%EOF\n');
    _write(table.toString());
    return _bytes.takeBytes();
  }
}
