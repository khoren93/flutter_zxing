// BarcodeStyle.toPng and BarcodeStyle.toSvg: the
// same shapes as BarcodeView, written to a PNG or an SVG document. Not
// exported from the package.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../writing/barcode_writer.dart';
import '../writing/symbol_layout.dart';
import 'barcode_painter.dart';
import 'barcode_style.dart';
import 'frame_layout.dart';
import 'logo_symbol.dart';
import 'symbol_shapes.dart';

/// Loads the image of [logo], or `null` without one, sharp enough to be
/// drawn [pixels] wide: an asset with resolution variants (`2.0x/`,
/// `3.0x/`) is loaded in the variant for that size. The caller disposes
/// the result.
///
/// Completes with the image's error if it fails to load.
Future<ImageInfo?> loadLogo(BarcodeLogo? logo, double pixels) async {
  if (logo == null) {
    return null;
  }
  final ImageInfo info = await _resolve(logo.image, 1);
  final int width = info.image.width;
  if (width >= pixels || width == 0) {
    return info;
  }
  // The image's own size in logical pixels: what a resolution variant is
  // the multiple of.
  final double logical = width / info.scale;
  info.dispose();
  return _resolve(logo.image, pixels / logical);
}

Future<ImageInfo> _resolve(ImageProvider image, double devicePixelRatio) {
  final ImageStream stream = image.resolve(
    ImageConfiguration(devicePixelRatio: devicePixelRatio),
  );
  final Completer<ImageInfo> done = Completer<ImageInfo>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo info, bool synchronousCall) {
      stream.removeListener(listener);
      if (!done.isCompleted) {
        done.complete(info);
      }
    },
    onError: (Object error, StackTrace? stack) {
      stream.removeListener(listener);
      if (!done.isCompleted) {
        done.completeError(error, stack);
      }
    },
  );
  stream.addListener(listener);
  return done.future;
}

/// [symbol] drawn with [style] as a PNG, its frame included: [size] or
/// [moduleSize] as in `BarcodeStyle.toPng`.
Future<Uint8List> styledPng(
  BarcodeSymbol symbol,
  BarcodeStyle style, {
  int? size,
  int? moduleSize,
}) async {
  assert(logoFits(symbol, style.logo), logoFitsMessage(symbol, style.logo!));
  final BarcodeSymbol shown = styledSymbol(symbol, style);
  final SymbolLayout layout = SymbolLayout(shown);
  final FrameLayout frame = FrameLayout(layout, style);
  // Whole pixels: modules between two pixels would blur.
  double outsetAt(int m) => (frame.outset * m).ceilToDouble();
  (int, int) content(int m) => (
    (frame.width * m + 2 * outsetAt(m)).ceil(),
    (frame.height * m + 2 * outsetAt(m)).ceil(),
  );
  final ExportSize pixels = exportSize(
    frame.width + 2 * frame.outset,
    frame.height + 2 * frame.outset,
    size,
    moduleSize,
    content: content,
  );
  final int m = pixels.moduleSize;
  final LogoBox? logoBox = SymbolShapes(shown, layout, style).logo;
  final ImageInfo? logo = logoBox != null
      ? await loadLogo(style.logo, logoBox.rect.width * m)
      : null;
  try {
    final (int cw, int ch) = content(m);
    final double outset = outsetAt(m);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    // The whole image, the margin [size] leaves included, and the last row
    // the frame covers only in part: the background, transparent around a
    // card.
    if (frame.card == null && style.backgroundColor.a > 0) {
      canvas.drawColor(style.backgroundColor, ui.BlendMode.src);
    }
    canvas.translate(
      ((pixels.width - cw) ~/ 2) + outset,
      ((pixels.height - ch) ~/ 2) + outset,
    );
    BarcodePainter(
      symbol: shown,
      layout: layout,
      frame: frame,
      style: style,
      devicePixelRatio: 1,
      textStyle: const TextStyle(
        fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
      ),
      logo: logo?.image,
    ).paint(canvas, ui.Size(frame.width * m, frame.height * m));
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(pixels.width, pixels.height);
    picture.dispose();
    try {
      final ByteData png = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image.dispose();
    }
  } finally {
    logo?.dispose();
  }
}

/// [symbol] drawn with [style] as an SVG document, its frame included; one
/// unit of the `viewBox` is one module, `width` and `height` are [size] or
/// [moduleSize] as in `BarcodeStyle.toSvg`.
///
/// Throws [UnsupportedError] for a [SweepGradient], which SVG cannot draw.
Future<String> styledSvg(
  BarcodeSymbol symbol,
  BarcodeStyle style, {
  int? size,
  int? moduleSize,
}) async {
  assert(logoFits(symbol, style.logo), logoFitsMessage(symbol, style.logo!));
  final BarcodeSymbol shown = styledSymbol(symbol, style);
  final SymbolLayout layout = SymbolLayout(shown);
  final FrameLayout frame = FrameLayout(layout, style);
  final SymbolShapes shapes = SymbolShapes(shown, layout, style);
  final Gradient? gradient = style.gradient;
  if (gradient is SweepGradient) {
    throw UnsupportedError(
      'SVG has no sweep gradients: export a SweepGradient with toPng',
    );
  }
  final double o = frame.outset;
  final (String pixelWidth, String pixelHeight) = svgSize(
    frame.width + 2 * o,
    frame.height + 2 * o,
    size,
    moduleSize,
  );
  final String? logoPng;
  final LogoBox? logoBox = shapes.logo;
  if (logoBox != null) {
    // Sharp on a screen of three pixels per point at the document's size.
    final double scale = double.parse(pixelWidth) / (frame.width + 2 * o);
    final ImageInfo? logo = await loadLogo(
      style.logo,
      logoBox.rect.width * scale * 3,
    );
    try {
      final ByteData? png = await logo?.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      logoPng = png == null
          ? null
          : base64Encode(
              png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
            );
    } finally {
      logo?.dispose();
    }
  } else {
    logoPng = null;
  }

  final String w = _n(frame.width + 2 * o);
  final String h = _n(frame.height + 2 * o);
  // Ids named after their definition: SVGs inlined in one HTML page share
  // one id space, and a fixed id would make them all use the first one's.
  final String? gradientDef = gradient == null
      ? null
      : _gradient(gradient, shapes.symbolArea);
  final String ink = 'ink-${_hash(gradientDef ?? '')}';
  final String sigma = _n(Shadow.convertRadiusToSigma(frame.shadowBlur));
  final String shadowId = 'shadow-${_hash(sigma)}';
  final String fill = gradient == null ? _color(style.color) : 'url(#$ink)';
  final String opacity = gradient == null ? _opacity('fill', style.color) : '';
  final StringBuffer svg = StringBuffer()
    ..write('<svg xmlns="http://www.w3.org/2000/svg" ');
  if (logoPng != null) {
    svg.write('xmlns:xlink="http://www.w3.org/1999/xlink" ');
  }
  svg
    ..write('viewBox="${_n(-o)} ${_n(-o)} $w $h" ')
    ..write('width="$pixelWidth" height="$pixelHeight">');
  final bool shadow = frame.shadowBlur > 0;
  if (gradient != null || shadow) {
    svg.write('<defs>');
    if (gradientDef != null) {
      svg.write(gradientDef.replaceFirst('id="ink"', 'id="$ink"'));
    }
    if (shadow) {
      svg.write(
        '<filter id="$shadowId" x="-50%" y="-50%" width="200%" height="200%"> '
        '<feGaussianBlur stdDeviation="$sigma"/></filter>',
      );
    }
    svg.write('</defs>');
  }
  final Color? cardColor = frame.cardColor;
  if (cardColor != null) {
    final String size =
        'width="${_n(frame.width)}" height="${_n(frame.height)}" '
        'rx="${_n(frame.cardRadius)}"';
    if (shadow) {
      svg.write(
        '<rect y="${_n(frame.shadowOffset)}" $size '
        'fill="${_color(FrameLayout.shadowColor)}"'
        '${_opacity('fill', FrameLayout.shadowColor)} filter="url(#$shadowId)"/>',
      );
    }
    if (cardColor.a > 0) {
      svg.write(
        '<rect $size fill="${_color(cardColor)}"'
        '${_opacity('fill', cardColor)}/>',
      );
    }
  } else if (style.backgroundColor.a > 0) {
    svg.write(
      '<rect width="${_n(frame.width)}" height="${_n(frame.height)}" '
      'fill="${_color(style.backgroundColor)}"'
      '${_opacity('fill', style.backgroundColor)}/>',
    );
  }
  // A card of another color: the code keeps its own background.
  if (cardColor != null &&
      cardColor != style.backgroundColor &&
      style.backgroundColor.a > 0) {
    final ui.Rect r = frame.codeRect;
    svg.write(
      '<rect x="${_n(r.left)}" y="${_n(r.top)}" '
      'width="${_n(r.width)}" height="${_n(r.height)}" '
      'fill="${_color(style.backgroundColor)}"'
      '${_opacity('fill', style.backgroundColor)}/>',
    );
  }
  final ui.Offset at = frame.codeOrigin;
  svg.write('<g');
  if (at != ui.Offset.zero) {
    svg.write(' transform="translate(${_n(at.dx)} ${_n(at.dy)})"');
  }
  if (shapes.plain) {
    svg.write(' shape-rendering="crispEdges"');
  }
  svg.write('>');
  _writeCode(
    svg,
    shapes,
    style,
    fill: fill,
    opacity: opacity,
    logo: logoBox != null && logoPng != null
        ? (ui.Rect r) => svg.write(
            '<image x="${_n(r.left)}" y="${_n(r.top)}" '
            'width="${_n(r.width)}" height="${_n(r.height)}" '
            'preserveAspectRatio="xMidYMid meet" '
            'xlink:href="data:image/png;base64,$logoPng"/>',
          )
        : null,
  );
  svg.write('</g>');
  for (final FrameText? t in <FrameText?>[frame.title, frame.caption]) {
    if (t != null) {
      _caption(svg, t);
    }
  }
  svg.write('</svg>');
  return svg.toString();
}

/// The code of [shapes] in module units: the modules and finders filled
/// with [fill], the logo drawn by [logo] in its box, the digits under
/// EAN/UPC.
void _writeCode(
  StringBuffer svg,
  SymbolShapes shapes,
  BarcodeStyle style, {
  required String fill,
  required String opacity,
  void Function(ui.Rect box)? logo,
}) {
  final _SvgSink modules = _SvgSink();
  shapes.modules(modules);
  svg.write('<path d="$modules" fill="$fill"$opacity/>');
  if (shapes.hasFinders) {
    final _SvgSink finders = _SvgSink();
    shapes.finders(finders);
    svg.write('<path d="$finders" fill="$fill"$opacity fill-rule="evenodd"/>');
  }
  final LogoBox? logoBox = shapes.logo;
  if (logoBox != null && logo != null) {
    logo(logoBox.rect);
  }
  final Color digits = textColorOf(style);
  for (final TextRun t in shapes.layout.textRuns) {
    svg
      ..write('<text x="${_n(t.x)}" ')
      ..write('y="${_n(t.top + t.fontSize)}" ')
      ..write('font-family="monospace" ')
      ..write('font-size="${_n(t.fittedSize(shapes.layout.width))}" ')
      ..write('$_preserveSpaces ')
      ..write('text-anchor="middle" fill="${_color(digits)}"')
      ..write('${_opacity('fill', digits)}>')
      ..write(xmlEscape(t.text))
      ..write('</text>');
  }
}

/// [shown] (a symbol as [style] shows it: `styledSymbol`) drawn with the
/// code part of [style] as a nested `<svg>` at [x], [y], [width] x
/// [height] in the units of the page around it: the background (unless
/// white), the modules and finders in the style's color or gradient, the
/// logo and the digits under EAN/UPC. No title, caption or card.
///
/// A gradient goes into [defs] (id to definition) under an id named after
/// its definition, so codes of one size share it; the page writes [defs].
/// The logo is a `<use>` of [logoId], a `<symbol>` the page defines, so
/// the image is in the page once. Without [logoId] the logo is left out.
///
/// Throws [UnsupportedError] for a [SweepGradient], which SVG cannot draw.
String styledSvgElement(
  BarcodeSymbol shown,
  BarcodeStyle style, {
  required double x,
  required double y,
  required double width,
  required double height,
  required Map<String, String> defs,
  String? logoId,
}) {
  final SymbolLayout layout = SymbolLayout(shown);
  final SymbolShapes shapes = SymbolShapes(shown, layout, style);
  final Gradient? gradient = style.gradient;
  final String fill;
  final String opacity;
  if (gradient == null) {
    fill = _color(style.color);
    opacity = _opacity('fill', style.color);
  } else {
    final String def = _gradient(gradient, shapes.symbolArea);
    final String id = 'ink-${_hash(def)}';
    defs[id] ??= def.replaceFirst('id="ink"', 'id="$id"');
    fill = 'url(#$id)';
    opacity = '';
  }
  final StringBuffer svg = StringBuffer()
    ..write('<svg x="${_n(x)}" y="${_n(y)}" ')
    ..write('width="${_n(width)}" height="${_n(height)}" ')
    ..write('viewBox="0 0 ${layout.width} ${layout.height}"');
  if (shapes.plain) {
    svg.write(' shape-rendering="crispEdges"');
  }
  svg.write('>');
  final Color background = style.backgroundColor;
  if (background.a > 0 && background.toARGB32() != 0xFFFFFFFF) {
    svg.write(
      '<rect width="${layout.width}" height="${layout.height}" '
      'fill="${_color(background)}"${_opacity('fill', background)}/>',
    );
  }
  _writeCode(
    svg,
    shapes,
    style,
    fill: fill,
    opacity: opacity,
    logo: logoId == null
        ? null
        : (ui.Rect r) => svg.write(
            '<use xlink:href="#$logoId" x="${_n(r.left)}" y="${_n(r.top)}" '
            'width="${_n(r.width)}" height="${_n(r.height)}"/>',
          ),
  );
  svg.write('</svg>');
  return svg.toString();
}

/// The `<symbol>` with id [id] holding [png] (base64), [width] x
/// [height] pixels, for the `<use>` of [styledSvgElement]: fitted into the
/// logo's box and centred, as the screen draws it.
String svgLogoSymbol(String id, String png, int width, int height) =>
    '<symbol id="$id" viewBox="0 0 $width $height"><image width="$width" height="$height" '
    'xlink:href="data:image/png;base64,$png"/></symbol>';

/// Keeps runs of spaces in `<text>`, as the screen and the PNG show them:
/// SVG collapses them otherwise.
const String _preserveSpaces = 'xml:space="preserve" style="white-space:pre"';

/// [t] as `<text>` lines: SVG does not wrap, so each line as laid out.
void _caption(StringBuffer svg, FrameText t) {
  final TextStyle s = t.style;
  final ui.Rect r = t.rect;
  final (String anchor, double x) = switch (t.caption.align) {
    TextAlign.center => ('middle', r.center.dx),
    TextAlign.right || TextAlign.end => ('end', r.right),
    _ => ('start', r.left),
  };
  final Color color = s.color ?? const Color(0xFF000000);
  final String family = <String>[
    ?s.fontFamily,
    ...?s.fontFamilyFallback,
    'sans-serif',
  ].map((String f) => f.contains(' ') ? "'$f'" : f).join(', ');
  svg
    ..write('<text $_preserveSpaces ')
    ..write('font-family="${xmlEscape(family)}" ')
    ..write('font-size="${_n(t.fontSize)}" ')
    ..write('font-weight="${(s.fontWeight ?? FontWeight.w700).value}" ');
  if (s.fontStyle == FontStyle.italic) {
    svg.write('font-style="italic" ');
  }
  if (t.caption.letterSpacing != 0) {
    svg.write('letter-spacing="${_n(t.caption.letterSpacing * t.fontSize)}" ');
  }
  svg.write(
    'text-anchor="$anchor" fill="${_color(color)}"'
    '${_opacity('fill', color)}>',
  );
  for (final (String line, double baseline) in t.lines) {
    svg.write(
      '<tspan x="${_n(x)}" y="${_n(r.top + baseline)}">'
      '${xmlEscape(line)}</tspan>',
    );
  }
  svg.write('</text>');
}

/// Writes shapes as SVG path data. Every shape runs clockwise, so that the
/// nonzero fill of overlapping shapes leaves no holes.
final class _SvgSink implements ShapeSink {
  final StringBuffer _d = StringBuffer();

  @override
  void rect(ui.Rect r) => _d.write(
    'M${_n(r.left)} ${_n(r.top)}h${_n(r.width)}v${_n(r.height)}'
    'h-${_n(r.width)}z',
  );

  @override
  void rrect(ui.RRect r) {
    final double tl = r.tlRadiusX;
    final double tr = r.trRadiusX;
    final double br = r.brRadiusX;
    final double bl = r.blRadiusX;
    _d.write('M${_n(r.left + tl)} ${_n(r.top)}H${_n(r.right - tr)}');
    _arc(tr, r.right, r.top + tr);
    _d.write('V${_n(r.bottom - br)}');
    _arc(br, r.right - br, r.bottom);
    _d.write('H${_n(r.left + bl)}');
    _arc(bl, r.left, r.bottom - bl);
    _d.write('V${_n(r.top + tl)}');
    _arc(tl, r.left + tl, r.top);
    _d.write('z');
  }

  void _arc(double radius, double x, double y) {
    if (radius > 0) {
      _d.write('A${_n(radius)} ${_n(radius)} 0 0 1 ${_n(x)} ${_n(y)}');
    }
  }

  @override
  void oval(ui.Rect r) {
    final String rx = _n(r.width / 2);
    final String ry = _n(r.height / 2);
    final double cy = r.center.dy;
    _d.write(
      'M${_n(r.left)} ${_n(cy)}'
      'A$rx $ry 0 1 1 ${_n(r.right)} ${_n(cy)}'
      'A$rx $ry 0 1 1 ${_n(r.left)} ${_n(cy)}z',
    );
  }

  @override
  String toString() => _d.toString();
}

/// 32-bit FNV-1a of [s] in hex: the same on every platform and run.
String _hash(String s) {
  int h = 0x811c9dc5;
  for (final int unit in s.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

/// A number for SVG: whole numbers without a fraction, others to three
/// decimals without trailing zeros.
String _n(double v) {
  if (v == v.roundToDouble()) {
    return v.round().toString();
  }
  String s = v.toStringAsFixed(3);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}

/// `#rgb` where it can, else `#rrggbb`; alpha goes in [_opacity].
String _color(ui.Color c) {
  final int argb = c.toARGB32();
  final List<int> rgb = <int>[
    (argb >> 16) & 0xFF,
    (argb >> 8) & 0xFF,
    argb & 0xFF,
  ];
  final bool short = rgb.every((int v) => v >> 4 == (v & 0xF));
  return '#${rgb.map((int v) => short ? (v & 0xF).toRadixString(16) : v.toRadixString(16).padLeft(2, '0')).join()}';
}

/// ` name-opacity="a"` for a translucent [c], else nothing.
String _opacity(String name, ui.Color c) {
  final int a = c.toARGB32() >>> 24;
  return a == 0xFF ? '' : ' $name-opacity="${_n(a / 255)}"';
}

/// The `<linearGradient>` or `<radialGradient>` with id `ink`, in the
/// coordinates of [rect] (module units), as `Gradient.createShader(rect)`.
String _gradient(Gradient gradient, ui.Rect rect) {
  final StringBuffer g = StringBuffer();
  const TextDirection direction = TextDirection.ltr;
  final String spread;
  switch (gradient) {
    case LinearGradient(
      :final AlignmentGeometry begin,
      :final AlignmentGeometry end,
      :final TileMode tileMode,
    ):
      final ui.Offset a = begin.resolve(direction).withinRect(rect);
      final ui.Offset b = end.resolve(direction).withinRect(rect);
      spread = _spread(tileMode);
      g.write(
        '<linearGradient id="ink" gradientUnits="userSpaceOnUse" '
        'x1="${_n(a.dx)}" y1="${_n(a.dy)}" x2="${_n(b.dx)}" y2="${_n(b.dy)}"'
        '$spread',
      );
    case RadialGradient(
      :final AlignmentGeometry center,
      :final double radius,
      :final AlignmentGeometry? focal,
      :final double focalRadius,
      :final TileMode tileMode,
    ):
      final ui.Offset c = center.resolve(direction).withinRect(rect);
      final double r = radius * rect.shortestSide;
      spread = _spread(tileMode);
      g.write(
        '<radialGradient id="ink" gradientUnits="userSpaceOnUse" '
        'cx="${_n(c.dx)}" cy="${_n(c.dy)}" r="${_n(r)}"',
      );
      if (focal != null) {
        final ui.Offset f = focal.resolve(direction).withinRect(rect);
        g.write(
          ' fx="${_n(f.dx)}" fy="${_n(f.dy)}" '
          'fr="${_n(focalRadius * rect.shortestSide)}"',
        );
      }
      g.write(spread);
    default:
      throw UnsupportedError(
        'SVG export supports LinearGradient and RadialGradient, '
        'not ${gradient.runtimeType}',
      );
  }
  final Float64List? m = gradient.transform
      ?.transform(rect, textDirection: direction)
      ?.storage;
  if (m != null) {
    g.write(
      ' gradientTransform="matrix(${_n(m[0])} ${_n(m[1])} ${_n(m[4])} '
      '${_n(m[5])} ${_n(m[12])} ${_n(m[13])})"',
    );
  }
  g.write('>');
  final List<Color> colors = gradient.colors;
  final List<double>? stops = gradient.stops;
  for (int i = 0; i < colors.length; i++) {
    final double offset =
        stops?[i] ?? (colors.length == 1 ? 0 : i / (colors.length - 1));
    g.write(
      '<stop offset="${_n(offset)}" stop-color="${_color(colors[i])}"'
      '${_opacity('stop', colors[i])}/>',
    );
  }
  g.write(
    gradient is LinearGradient ? '</linearGradient>' : '</radialGradient>',
  );
  return g.toString();
}

String _spread(TileMode mode) => switch (mode) {
  TileMode.repeated => ' spreadMethod="repeat"',
  TileMode.mirror => ' spreadMethod="reflect"',
  TileMode.clamp || TileMode.decal => '',
};
