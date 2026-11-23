import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../barcode/barcode_format.dart';
import '../barcode/upc.dart';
import '../engine/engine.dart';
import '../engine/engine_protocol.dart';
import 'creator_options.dart' as writing;
import 'creator_options.dart' show errorCorrectionOf;
import 'symbol_layout.dart';

/// Creates barcodes from text or binary data.
///
/// The engine encodes the data into a [BarcodeSymbol] (the module matrix);
/// SVG, images and `BarcodeView` are all drawn from that matrix in Dart, so
/// the result looks the same on every platform. Encoding runs in the
/// background and never blocks the UI.
///
/// ```dart
/// const writer = BarcodeWriter(BarcodeFormat.qrCode, errorCorrection: ErrorCorrection.high);
///
/// // Text: shortcuts for the common case.
/// final String svg = await writer.toSvg('https://pub.dev/packages/flutter_zxing');
/// final BarcodeImage image = await writer.toImage('https://…', size: 512);
///
/// // Binary data: encode, then render the symbol.
/// final BarcodeSymbol symbol = await writer.encodeBytes(bytes);
/// final String binarySvg = symbol.toSvg();
/// ```
@immutable
final class BarcodeWriter {
  /// Creates a writer for [format], which must be writable
  /// ([BarcodeFormat.canWrite]).
  const BarcodeWriter(
    this.format, {
    this.errorCorrection,
    this.version,
    this.gs1 = false,
    this.showText,
    this.zxingOptions,
  });

  /// The symbology to create.
  final BarcodeFormat format;

  /// Error correction, for formats that have it; `null` uses the format's
  /// default: [ErrorCorrection.medium] for QR codes (zxing-cpp's own
  /// default is low), zxing-cpp's for the others. See [ErrorCorrection].
  final ErrorCorrection? errorCorrection;

  /// Symbol size, for formats that have versions; `null` picks the
  /// smallest that fits. The values zint takes:
  ///
  /// | Format | Version |
  /// |---|---|
  /// | QR Code | 1–40: 17 + 4 × version modules across |
  /// | Micro QR | 1–4: M1–M4 |
  /// | rMQR | 1–32: a fixed size, R7x43 to R17x139; 33–38: a fixed height (7, 9, 11, 13, 15 or 17 rows), the width to fit |
  /// | Data Matrix | 1–48: 1–24 square (10×10 to 144×144), 25–30 rectangular, 31–48 rectangular DMRE |
  /// | Aztec | 1–36: 1–4 compact with 1–4 layers, 5–36 full range with 1–32 layers |
  /// | PDF417, Compact PDF417 | 1–30: data columns |
  /// | MicroPDF417 | 1–4: data columns |
  ///
  /// Encoding throws [RangeError] for a version outside the range and
  /// [ArgumentError] for a format without versions (linear formats, Aztec
  /// Rune; DataBar Expanded Stacked takes `columns`/`rows` in
  /// [zxingOptions]). A version too small for the data throws
  /// [BarcodeWriteException].
  final int? version;

  /// Encode the data as GS1 (Application Identifiers in parentheses:
  /// `(01)09501101530003(17)250101`).
  final bool gs1;

  /// Print the human readable text under linear barcodes (not DX Film
  /// Edge, which has none). `null` (the default) follows the custom of the
  /// format: the digits under EAN-13, EAN-8, UPC-A, UPC-E and ISBN, which
  /// are printed on every product, and no text under the others.
  final bool? showText;

  /// Raw zxing-cpp creator options for anything not covered above, e.g.
  /// `'eci=26, readerInit'`: `key` or `key=value`, separated by commas.
  /// A key given here wins over the typed field it sets (`ecLevel` over
  /// [errorCorrection], `version` over [version]).
  ///
  /// The keys zxing-cpp knows (case and underscores do not matter):
  ///
  /// - `ecLevel`: error correction in the format's own terms: `L`, `M`,
  ///   `Q`, `H` (or a percentage) for QR, Micro QR and rMQR, a percentage
  ///   for Aztec (`23%`), a security level 0–8 for PDF417.
  /// - `eci`: the character set to declare, by a name zxing-cpp knows
  ///   (`UTF-8`, `ISO-8859-5`, `Shift_JIS`) or ECI number (0–999999);
  ///   `eci=0` declares none.
  /// - `gs1`: the same as [gs1].
  /// - `readerInit`: mark the symbol for reader programming.
  /// - `forceSquare`: Data Matrix in a square size only.
  /// - `extraEscapeMode`: zint's extra escape sequences in Code 128 data.
  /// - `columns`, `rows`: the layout of PDF417 and DataBar Expanded
  ///   Stacked (`columns` also of MicroPDF417).
  /// - `version`: the same as [version].
  /// - `dataMask`: the mask pattern of a QR code (0–7) or Micro QR (0–3).
  ///
  /// Numbers are written plainly (`-?[0-9]+`, as zxing-cpp parses them:
  /// no `+`, no hex). Encoding throws [ArgumentError] for any other key
  /// and for a value of the wrong kind (`version=abc`, `ecLevel=Z`,
  /// `ecLevel=L` for Aztec, an `eci` name zxing-cpp does not know,
  /// `columns=0`).
  final String? zxingOptions;

  /// Encodes text into the module matrix (UTF-8, or the character set the
  /// symbology requires).
  ///
  /// ```dart
  /// final BarcodeSymbol symbol = await const BarcodeWriter(BarcodeFormat.dataMatrix).encode('ABC-123');
  /// print('${symbol.width} x ${symbol.height} modules');
  /// ```
  ///
  /// Throws [BarcodeWriteException] if [data] cannot be encoded, and
  /// [ArgumentError] if [format] cannot be written or [version] or
  /// [zxingOptions] are not valid for it.
  Future<BarcodeSymbol> encode(String data) =>
      _encode(utf8.encode(data), binary: false);

  /// Encodes binary data into the module matrix, byte for byte (formats
  /// with a byte mode: QR, Data Matrix, Aztec, PDF417).
  ///
  /// ```dart
  /// final Uint8List key = Uint8List.fromList([0x00, 0xff, 0x10, 0x80]);
  /// final symbol = await const BarcodeWriter(BarcodeFormat.qrCode).encodeBytes(key);
  /// final String svg = symbol.toSvg();
  /// ```
  ///
  /// Throws [BarcodeWriteException] if [data] cannot be encoded, and
  /// [ArgumentError] if [format] cannot be written or [version] or
  /// [zxingOptions] are not valid for it.
  Future<BarcodeSymbol> encodeBytes(Uint8List data) =>
      _encode(data, binary: true);

  Future<BarcodeSymbol> _encode(Uint8List data, {required bool binary}) async {
    if (!format.canWrite) {
      throw ArgumentError.value(
        format,
        'format',
        'BarcodeFormat.${format.name} cannot be written',
      );
    }
    writing.checkWriter(this);
    final EngineSymbol s = await BarcodeEngine.shared.write(
      data,
      binary: binary,
      format: format.zxingName,
      options: writing.writerCreatorOptions(this),
    );
    final int quiet = math.max(
      math.max(s.quietZoneLeft, s.quietZoneRight),
      math.max(s.quietZoneTop, s.quietZoneBottom),
    );
    return BarcodeSymbol(
      format: s.format == BarcodeFormat.unknown ? format : s.format,
      width: s.width,
      height: s.height,
      modules: s.modules,
      // One margin on every side: the largest one the symbology needs (left
      // of an EAN-13: 11 modules), at least one module (zint gives Aztec
      // and DX Film Edge none).
      quietZone: math.max(quiet, 1),
      errorCorrection: errorCorrectionOf(format, s.ecLevel),
      // DX Film Edge is six modules tall: text under it stops it reading.
      text:
          (showText ?? _textByDefault(format)) &&
              format.isLinear &&
              format != BarcodeFormat.dxFilmEdge &&
              s.text.isNotEmpty
          ? _printed(s.text)
          : null,
    );
  }

  /// Whether [format] prints its text by default: the retail codes.
  static bool _textByDefault(BarcodeFormat format) => switch (format) {
    BarcodeFormat.ean13 ||
    BarcodeFormat.ean8 ||
    BarcodeFormat.upcA ||
    BarcodeFormat.upcE ||
    BarcodeFormat.isbn ||
    BarcodeFormat.eanUpc => true,
    _ => false,
  };

  /// [text] as printed under the bars: zxing-cpp gives a UPC-A and a UPC-E
  /// as 13 digits, as they are transmitted, and an EAN-8 too when an add-on
  /// follows; their labels show 12, 8 and 8.
  String _printed(String text) {
    final RegExpMatch? withAddOn = RegExp(
      r'^(\d{13})(\d{2}|\d{5})$',
    ).firstMatch(text);
    final String digits = withAddOn?.group(1) ?? text;
    final String addOn = withAddOn?.group(2) ?? '';
    if (!RegExp(r'^0\d{12}$').hasMatch(digits)) {
      return text;
    }
    final String printed = switch (format) {
      BarcodeFormat.upcA => digits.substring(1),
      BarcodeFormat.upcE => upcEFromUpcA(digits.substring(1)) ?? digits,
      BarcodeFormat.ean8 when digits.startsWith('00000') => digits.substring(5),
      _ => digits,
    };
    return '$printed$addOn';
  }

  /// Encodes text and returns it as an SVG document, black on white. Same
  /// as `(await encode(data)).toSvg(...)` (see [BarcodeSymbol.toSvg]); for
  /// colors, shapes and a logo use `BarcodeStyle.encodeSvg`.
  ///
  /// Throws [BarcodeWriteException] if [data] cannot be encoded, and
  /// [ArgumentError] for a [size] or [moduleSize] [BarcodeSymbol.toSvg]
  /// does not take.
  Future<String> toSvg(
    String data, {
    int? size,
    int? moduleSize,
    bool quietZone = true,
  }) async => (await encode(
    data,
  )).toSvg(size: size, moduleSize: moduleSize, quietZone: quietZone);

  /// Encodes text and returns it as a PNG, black on white. Same as
  /// `(await encode(data)).toPng(...)` (see [BarcodeSymbol.toPng]); for
  /// colors, shapes and a logo use `BarcodeStyle.encodePng`.
  ///
  /// Throws [BarcodeWriteException] if [data] cannot be encoded, and
  /// [ArgumentError] for a [size] or [moduleSize] [BarcodeSymbol.toPng]
  /// does not take.
  Future<Uint8List> toPng(
    String data, {
    int? size,
    int? moduleSize,
    bool quietZone = true,
  }) async => (await encode(
    data,
  )).toPng(size: size, moduleSize: moduleSize, quietZone: quietZone);

  /// Encodes text and returns it as a grayscale image (black on white, no
  /// style: for printers and image processing). Same as
  /// `(await encode(data)).toImage(...)`; see [BarcodeSymbol.toImage].
  ///
  /// Throws [BarcodeWriteException] if [data] cannot be encoded, and
  /// [ArgumentError] for a [size] or [moduleSize] [BarcodeSymbol.toImage]
  /// does not take.
  Future<BarcodeImage> toImage(
    String data, {
    int? size,
    int? moduleSize,
    bool quietZone = true,
  }) async => (await encode(
    data,
  )).toImage(size: size, moduleSize: moduleSize, quietZone: quietZone);

  /// Creates a copy with the given fields replaced.
  ///
  /// A `null` argument keeps the field, so `copyWith` cannot set
  /// [errorCorrection], [version] or [zxingOptions] back to `null`. Create
  /// a new writer for that.
  BarcodeWriter copyWith({
    BarcodeFormat? format,
    ErrorCorrection? errorCorrection,
    int? version,
    bool? gs1,
    bool? showText,
    String? zxingOptions,
  }) => BarcodeWriter(
    format ?? this.format,
    errorCorrection: errorCorrection ?? this.errorCorrection,
    version: version ?? this.version,
    gs1: gs1 ?? this.gs1,
    showText: showText ?? this.showText,
    zxingOptions: zxingOptions ?? this.zxingOptions,
  );

  @override
  bool operator ==(Object other) =>
      other is BarcodeWriter &&
      other.format == format &&
      other.errorCorrection == errorCorrection &&
      other.version == version &&
      other.gs1 == gs1 &&
      other.showText == showText &&
      other.zxingOptions == zxingOptions;

  @override
  int get hashCode => Object.hash(
    format,
    errorCorrection,
    version,
    gs1,
    showText,
    zxingOptions,
  );

  /// The format and the fields that differ from the defaults, e.g.
  /// `BarcodeWriter(qrCode, errorCorrection: high)`.
  @override
  String toString() =>
      'BarcodeWriter(${<String>[format.name, if (errorCorrection case final ErrorCorrection e) 'errorCorrection: ${e.name}', if (version != null) 'version: $version', if (gs1) 'gs1: true', if (showText case final bool t) 'showText: $t', if (zxingOptions != null) "zxingOptions: '$zxingOptions'"].join(', ')})';
}

/// Error correction level: how much of the symbol can be damaged and still
/// read. Higher levels make the symbol larger.
///
/// QR codes use the levels directly (L ≈ 7%, M ≈ 15%, Q ≈ 25%, H ≈ 30%).
/// Aztec maps them to 10%, 23%, 36% and 50% of the symbol, PDF417 to
/// security levels 2 to 5. Data Matrix and linear formats have fixed error
/// correction and ignore it.
enum ErrorCorrection {
  /// About 7% recoverable (QR L).
  low,

  /// About 15% recoverable (QR M).
  medium,

  /// About 25% recoverable (QR Q).
  quartile,

  /// About 30% recoverable (QR H). Use with a logo in the middle.
  high,
}

/// A created barcode as an 8-bit grayscale raster (0 = black, 255 = white).
@immutable
final class BarcodeImage {
  /// Wraps a raster.
  const BarcodeImage({
    required this.width,
    required this.height,
    required this.pixels,
  });

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// One byte per pixel, row by row.
  final Uint8List pixels;

  @override
  String toString() => 'BarcodeImage($width x $height)';

  /// Encodes the image as PNG (with the Flutter engine's encoder).
  ///
  /// ```dart
  /// final image = await const BarcodeWriter(BarcodeFormat.qrCode).toImage('hello', size: 512);
  /// await File('qr.png').writeAsBytes(await image.toPng());
  /// ```
  Future<Uint8List> toPng() async {
    final ui.Image image = await toUiImage();
    try {
      final ByteData? png = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  /// Converts the image for drawing with `Canvas` or `RawImage`. The caller
  /// owns the result and should `dispose()` it.
  ///
  /// ```dart
  /// final ui.Image image = await barcodeImage.toUiImage();
  /// return RawImage(image: image, filterQuality: FilterQuality.none);
  /// ```
  Future<ui.Image> toUiImage() {
    final Uint8List rgba = Uint8List(width * height * 4);
    for (int i = 0, o = 0; i < pixels.length; i++, o += 4) {
      final int v = pixels[i];
      rgba[o] = v;
      rgba[o + 1] = v;
      rgba[o + 2] = v;
      rgba[o + 3] = 255;
    }
    final Completer<ui.Image> done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }
}

/// An encoded barcode: the module matrix plus what is needed to render it.
///
/// For 2D formats a module is one cell. Linear formats are a bar raster in
/// module units: [width] is the number of modules across, [height] the bar
/// height (EAN/UPC guard bars extend lower than the data bars).
///
/// Two symbols are equal when they draw the same: the same [format], size,
/// dark modules, [quietZone], [text] and [errorCorrection].
@immutable
final class BarcodeSymbol {
  /// Wraps a module matrix.
  const BarcodeSymbol({
    required this.format,
    required this.width,
    required this.height,
    required this.modules,
    this.quietZone = 0,
    this.text,
    this.errorCorrection,
  });

  /// The symbology.
  final BarcodeFormat format;

  /// Width in modules, without the quiet zone.
  final int width;

  /// Height in modules, without the quiet zone.
  final int height;

  /// One byte per module, row by row: non-zero is dark.
  final Uint8List modules;

  /// Blank margin the symbology needs on each side, in modules. Exports
  /// and `BarcodeView` draw it unless told otherwise (`quietZone: false`,
  /// `BarcodeStyle.quietZone`).
  final int quietZone;

  /// Human readable text to print under a linear barcode, or `null`.
  final String? text;

  /// The error correction level of a QR code, Micro QR code or rMQR code,
  /// as the engine created or read it; `null` for other formats or when it
  /// is not known. A logo needs enough of it: see
  /// `BarcodeLogo.neededErrorCorrection`.
  final ErrorCorrection? errorCorrection;

  /// Whether the module at column [x], row [y] is dark.
  bool isDark(int x, int y) => modules[y * width + x] != 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! BarcodeSymbol ||
        other.format != format ||
        other.width != width ||
        other.height != height ||
        other.quietZone != quietZone ||
        other.text != text ||
        other.errorCorrection != errorCorrection ||
        other.modules.length != modules.length) {
      return false;
    }
    for (int i = 0; i < modules.length; i++) {
      if ((modules[i] != 0) != (other.modules[i] != 0)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    format,
    width,
    height,
    quietZone,
    text,
    errorCorrection,
    Object.hashAll(<bool>[for (final int m in modules) m != 0]),
  );

  @override
  String toString() =>
      'BarcodeSymbol(${format.name}, $width x $height'
      '${quietZone == 0 ? '' : ', quietZone: $quietZone'}'
      '${text == null ? '' : ', text: "$text"'}'
      '${errorCorrection == null ? '' : ', errorCorrection: ${errorCorrection!.name}'})';

  /// Renders the symbol as an SVG document, black on white: one path,
  /// crisp at any size. For colors, shapes and a logo use
  /// `BarcodeStyle.toSvg`.
  ///
  /// The `viewBox` is in modules; `width` and `height` are pixels:
  /// [moduleSize] pixels per module (4 by default), or [size] pixels across
  /// the longer side. [quietZone] `false` leaves the blank margin out.
  ///
  /// Throws [ArgumentError] if both [size] and [moduleSize] are given, one
  /// is not positive, or [size] is smaller than the symbol in modules.
  ///
  /// ```dart
  /// final symbol = await const BarcodeWriter(BarcodeFormat.qrCode).encode('https://pub.dev');
  /// await File('qr.svg').writeAsString(symbol.toSvg(size: 512));
  /// ```
  String toSvg({int? size, int? moduleSize, bool quietZone = true}) {
    final SymbolLayout layout = SymbolLayout(
      quietZone ? this : withoutQuietZone(this),
    );
    final (String width, String height) = svgSize(
      layout.width.toDouble(),
      layout.height.toDouble(),
      size,
      moduleSize,
    );
    final StringBuffer svg = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 ${layout.width} ${layout.height}" ')
      ..write('width="$width" height="$height" ')
      ..write('shape-rendering="crispEdges">')
      ..write('<rect width="100%" height="100%" fill="#fff"/>');
    _writeSvgBody(svg, layout);
    svg.write('</svg>');
    return svg.toString();
  }

  /// Renders the symbol as an SVG element to place in an SVG of your own,
  /// such as a page of labels to print: a nested `<svg>` at [x], [y] that
  /// fits [width] by [height], in the units of the page around it
  /// (millimetres, points…). Black modules and text, no background.
  ///
  /// Without [height] the element has the symbol's proportions. With both,
  /// the symbol keeps its proportions and is centered in the box.
  /// [quietZone] `false` leaves the blank margin out.
  ///
  /// Throws [ArgumentError] if [width] or [height] is not positive.
  ///
  /// ```dart
  /// // A 40 mm code at 10 mm from the top left corner of an A4 page.
  /// final page = StringBuffer(
  ///   '<svg xmlns="http://www.w3.org/2000/svg" width="210mm" height="297mm" viewBox="0 0 210 297">',
  /// )
  ///   ..write(symbol.toSvgElement(x: 10, y: 10, width: 40))
  ///   ..write('</svg>');
  /// ```
  String toSvgElement({
    required double width,
    double? height,
    double x = 0,
    double y = 0,
    bool quietZone = true,
  }) {
    if (width <= 0 || (height != null && height <= 0)) {
      throw ArgumentError('width and height must be positive');
    }
    final SymbolLayout layout = SymbolLayout(
      quietZone ? this : withoutQuietZone(this),
    );
    final double h = height ?? width * layout.height / layout.width;
    final StringBuffer svg = StringBuffer()
      ..write('<svg x="${_svgNumber(x)}" y="${_svgNumber(y)}" ')
      ..write('width="${_svgNumber(width)}" height="${_svgNumber(h)}" ')
      ..write('viewBox="0 0 ${layout.width} ${layout.height}" ')
      ..write('shape-rendering="crispEdges">');
    _writeSvgBody(svg, layout);
    svg.write('</svg>');
    return svg.toString();
  }

  /// The modules as one black path and the text under a linear barcode.
  static void _writeSvgBody(StringBuffer svg, SymbolLayout layout) {
    final StringBuffer path = StringBuffer();
    for (final ModuleRect r in layout.rects) {
      path.write('M${r.x} ${r.y}h${r.width}v${r.height}h-${r.width}z');
    }
    svg.write('<path d="$path" fill="#000"/>');
    for (final TextRun t in layout.textRuns) {
      svg
        ..write('<text x="${_svgNumber(t.x)}" ')
        ..write('y="${_svgNumber(t.top + t.fontSize)}" ')
        ..write('font-family="monospace" ')
        ..write('font-size="${_svgNumber(t.fittedSize(layout.width))}" ')
        ..write('text-anchor="middle" fill="#000">')
        ..write(xmlEscape(t.text))
        ..write('</text>');
    }
  }

  static String _svgNumber(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  /// Renders the symbol as a PNG, black on white: [toImage] encoded as
  /// PNG. For colors, shapes and a logo use `BarcodeStyle.toPng`.
  ///
  /// Give either [size] or [moduleSize] (pixels per module; 4 by default).
  /// With [size] the longer side is exactly [size] pixels and the shorter
  /// one in proportion: the modules are the most whole pixels that fit, the
  /// rest is white margin. [quietZone] `false` leaves the blank margin out.
  ///
  /// Throws [ArgumentError] if both are given, one is not positive, or
  /// [size] is smaller than the symbol in modules.
  ///
  /// ```dart
  /// await File('qr.png').writeAsBytes(await symbol.toPng(size: 1024));
  /// ```
  Future<Uint8List> toPng({
    int? size,
    int? moduleSize,
    bool quietZone = true,
  }) async => (await toImage(
    size: size,
    moduleSize: moduleSize,
    quietZone: quietZone,
  )).toPng();

  /// Renders the symbol as an 8-bit grayscale image.
  ///
  /// Give either [size] or [moduleSize] (pixels per module; 4 by default).
  /// With [size] the longer side is exactly [size] pixels and the shorter
  /// one in proportion: the modules are the most whole pixels that fit, the
  /// rest is white margin. [quietZone] `false` leaves the blank margin out.
  /// Asynchronous because [text] is drawn with the Flutter engine.
  ///
  /// Throws [ArgumentError] if both are given, one is not positive, or
  /// [size] is smaller than the symbol in modules.
  ///
  /// ```dart
  /// final image = await symbol.toImage(size: 300); // 300 x 300
  /// final png = await image.toPng();
  /// ```
  Future<BarcodeImage> toImage({
    int? size,
    int? moduleSize,
    bool quietZone = true,
  }) async {
    final SymbolLayout layout = SymbolLayout(
      quietZone ? this : withoutQuietZone(this),
    );
    final ExportSize pixels = exportSize(
      layout.width.toDouble(),
      layout.height.toDouble(),
      size,
      moduleSize,
    );
    final int m = pixels.moduleSize;
    final int w = pixels.width;
    final int h = pixels.height;
    // Whole pixels: the margin [size] leaves, split around the symbol.
    final int left = (w - layout.width * m) ~/ 2;
    final int top = (h - layout.height * m) ~/ 2;
    final Uint8List raster = Uint8List(w * h)..fillRange(0, w * h, 255);
    for (final ModuleRect r in layout.rects) {
      for (int y = top + r.y * m; y < top + (r.y + r.height) * m; y++) {
        raster.fillRange(
          y * w + left + r.x * m,
          y * w + left + (r.x + r.width) * m,
          0,
        );
      }
    }
    if (layout.textRuns.isNotEmpty) {
      await _drawText(raster, w, h, layout, m, left, top);
    }
    return BarcodeImage(width: w, height: h, pixels: raster);
  }

  /// Draws the text of [layout] with the Flutter engine.
  static Future<void> _drawText(
    Uint8List pixels,
    int width,
    int height,
    SymbolLayout layout,
    int m,
    int dx,
    int dy,
  ) async {
    final List<TextRun> runs = layout.textRuns;
    final int top =
        dy + runs.map((TextRun t) => (t.top * m).floor()).reduce(math.min);
    final int bottom = math.min(
      height,
      dy +
          runs
              .map((TextRun t) => ((t.top + t.fontSize + 1) * m).ceil())
              .reduce(math.max),
    );
    final int boxHeight = bottom - top;
    final List<(ui.Paragraph, ui.Offset)> paragraphs =
        <(ui.Paragraph, ui.Offset)>[
          for (final TextRun t in runs)
            () {
              // A whole line spans the width; a digit gets a box of its own.
              final double box = t.fit
                  ? (layout.width * m).toDouble()
                  : t.fontSize * m * 2;
              final ui.Paragraph p =
                  (ui.ParagraphBuilder(
                          ui.ParagraphStyle(
                            textAlign: ui.TextAlign.center,
                            fontSize: t.fittedSize(layout.width) * m,
                            height: 1,
                            maxLines: 1,
                          ),
                        )
                        ..pushStyle(
                          ui.TextStyle(color: const ui.Color(0xFF000000)),
                        )
                        ..addText(t.text))
                      .build()
                    ..layout(ui.ParagraphConstraints(width: box));
              return (
                p,
                ui.Offset(
                  dx + (t.fit ? 0 : t.x * m - box / 2),
                  dy + t.top * m - top,
                ),
              );
            }(),
        ];
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
    for (final (ui.Paragraph p, ui.Offset at) in paragraphs) {
      canvas.drawParagraph(p, at);
      p.dispose();
    }
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(width, boxHeight);
    picture.dispose();
    try {
      final ByteData rgba = (await image.toByteData())!;
      for (int y = 0; y < boxHeight; y++) {
        for (int x = 0; x < width; x++) {
          final int o = (y * width + x) * 4;
          // Luminance of the antialiased text on white.
          final int v =
              (306 * rgba.getUint8(o) +
                  601 * rgba.getUint8(o + 1) +
                  117 * rgba.getUint8(o + 2) +
                  0x200) >>
              10;
          final int p = (top + y) * width + x;
          if (v < pixels[p]) {
            pixels[p] = v;
          }
        }
      }
    } finally {
      image.dispose();
    }
  }
}
