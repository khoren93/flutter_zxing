import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../barcode/barcode_format.dart';
import '../engine/engine.dart';
import '../engine/engine_protocol.dart';
import 'creator_options.dart' as writing;
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
    this.quietZone = true,
    this.showText = false,
    this.options,
  });

  /// The symbology to create.
  final BarcodeFormat format;

  /// Error correction, for formats that have it; `null` uses the format's
  /// default. See [ErrorCorrection].
  final ErrorCorrection? errorCorrection;

  /// Symbol size, for formats that have versions (QR: 1–40, Data Matrix:
  /// size index, Aztec: layers). `null` picks the smallest that fits.
  final int? version;

  /// Encode the data as GS1 (Application Identifiers in parentheses:
  /// `(01)09501101530003(17)250101`).
  final bool gs1;

  /// Add the quiet zone (blank margin) the symbology requires.
  final bool quietZone;

  /// Print the human readable text under linear barcodes.
  final bool showText;

  /// Raw zxing-cpp creator options for anything not covered above, e.g.
  /// `'eci=26, readerInit'`. Applied after the typed fields.
  final String? options;

  /// Encodes text into the module matrix (UTF-8, or the character set the
  /// symbology requires).
  ///
  /// ```dart
  /// final BarcodeSymbol symbol = await const BarcodeWriter(BarcodeFormat.dataMatrix).encode('ABC-123');
  /// print('${symbol.width} x ${symbol.height} modules');
  /// ```
  ///
  /// Throws [BarcodeWriteException] if [data] cannot be encoded, and
  /// [ArgumentError] if [format] cannot be written.
  Future<BarcodeSymbol> encode(String data) =>
      _encode(utf8.encode(data), binary: false);

  /// Encodes binary data into the module matrix, byte for byte (formats
  /// with a byte mode: QR, Data Matrix, Aztec, PDF417).
  ///
  /// ```dart
  /// final Uint8List key = Uint8List.fromList([0x00, 0xff, 0x10, 0x80]);
  /// final String svg = (await const BarcodeWriter(BarcodeFormat.qrCode).encodeBytes(key)).toSvg();
  /// ```
  ///
  /// Throws [BarcodeWriteException] if [data] cannot be encoded, and
  /// [ArgumentError] if [format] cannot be written.
  Future<BarcodeSymbol> encodeBytes(Uint8List data) =>
      _encode(data, binary: true);

  Future<BarcodeSymbol> _encode(Uint8List data, {required bool binary}) async {
    if (!format.canWrite) {
      throw ArgumentError.value(
        format,
        'format',
        '${format.displayName} cannot be written',
      );
    }
    final EngineSymbol s = await BarcodeEngine.shared.write(
      data,
      binary: binary,
      format: format.zxingName,
      options: creatorOptions,
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
      // of an EAN-13: 11 modules), at least one module for 2D symbols
      // (zint gives Aztec none).
      quietZone: quietZone ? math.max(quiet, format.isMatrix ? 1 : 0) : 0,
      text: showText && format.isLinear && s.text.isNotEmpty ? s.text : null,
    );
  }

  /// The zxing-cpp creator options for this writer: the typed fields, then
  /// [options].
  @visibleForTesting
  String get creatorOptions => writing.creatorOptions(
    format,
    errorCorrection: errorCorrection,
    version: version,
    gs1: gs1,
    options: options,
  );

  /// Encodes text and returns it as an SVG document. Same as
  /// `(await encode(data)).toSvg()`.
  ///
  /// Throws [BarcodeWriteException] if [data] cannot be encoded.
  Future<String> toSvg(String data) async => (await encode(data)).toSvg();

  /// Encodes text and returns it as a grayscale image. Same as
  /// `(await encode(data)).toImage(...)`; see [BarcodeSymbol.toImage].
  ///
  /// Throws [BarcodeWriteException] if [data] cannot be encoded.
  Future<BarcodeImage> toImage(
    String data, {
    int? size,
    int? moduleSize,
  }) async => (await encode(data)).toImage(size: size, moduleSize: moduleSize);

  /// Creates a copy with the given fields replaced.
  BarcodeWriter copyWith({
    BarcodeFormat? format,
    ErrorCorrection? errorCorrection,
    int? version,
    bool? gs1,
    bool? quietZone,
    bool? showText,
    String? options,
  }) => BarcodeWriter(
    format ?? this.format,
    errorCorrection: errorCorrection ?? this.errorCorrection,
    version: version ?? this.version,
    gs1: gs1 ?? this.gs1,
    quietZone: quietZone ?? this.quietZone,
    showText: showText ?? this.showText,
    options: options ?? this.options,
  );

  @override
  bool operator ==(Object other) =>
      other is BarcodeWriter &&
      other.format == format &&
      other.errorCorrection == errorCorrection &&
      other.version == version &&
      other.gs1 == gs1 &&
      other.quietZone == quietZone &&
      other.showText == showText &&
      other.options == options;

  @override
  int get hashCode => Object.hash(
    format,
    errorCorrection,
    version,
    gs1,
    quietZone,
    showText,
    options,
  );
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
  });

  /// The symbology.
  final BarcodeFormat format;

  /// Width in modules, without the quiet zone.
  final int width;

  /// Height in modules, without the quiet zone.
  final int height;

  /// One byte per module, row by row: non-zero is dark.
  final Uint8List modules;

  /// Blank margin to keep on each side, in modules (0 if the writer was
  /// created with `quietZone: false`).
  final int quietZone;

  /// Human readable text to print under a linear barcode, or `null`.
  final String? text;

  /// Whether the module at column [x], row [y] is dark.
  bool isDark(int x, int y) => modules[y * width + x] != 0;

  /// Renders the symbol as an SVG document (one path, crisp at any size).
  ///
  /// One SVG unit is one module, quiet zone included; scale it with the
  /// `width`/`height` of the element that shows it.
  ///
  /// ```dart
  /// final symbol = await const BarcodeWriter(BarcodeFormat.qrCode).encode('https://pub.dev');
  /// await File('qr.svg').writeAsString(symbol.toSvg());
  /// ```
  String toSvg() {
    final SymbolLayout layout = SymbolLayout(this);
    final StringBuffer path = StringBuffer();
    for (final ModuleRect r in layout.rects) {
      path.write('M${r.x} ${r.y}h${r.width}v${r.height}h-${r.width}z');
    }
    final String? text = layout.text;
    final StringBuffer svg = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 ${layout.width} ${layout.height}" ')
      ..write('width="${layout.width}" height="${layout.height}" ')
      ..write('shape-rendering="crispEdges">')
      ..write('<rect width="100%" height="100%" fill="#fff"/>')
      ..write('<path d="$path" fill="#000"/>');
    if (text != null) {
      svg
        ..write('<text x="${layout.textCenter}" ')
        ..write('y="${layout.textTop + SymbolLayout.textFontSize}" ')
        ..write('font-family="monospace" ')
        ..write('font-size="${SymbolLayout.textFontSize}" ')
        ..write('text-anchor="middle" fill="#000">')
        ..write(_xmlEscape(text))
        ..write('</text>');
    }
    svg.write('</svg>');
    return svg.toString();
  }

  /// Renders the symbol as an 8-bit grayscale image.
  ///
  /// Give either [size] (fit into `size` × `size` pixels with whole-pixel
  /// modules) or [moduleSize] (pixels per module). Defaults to 4 pixels per
  /// module. Asynchronous because [text] is drawn with the Flutter engine.
  ///
  /// Throws [ArgumentError] if both are given or one is not positive.
  ///
  /// ```dart
  /// final image = await symbol.toImage(size: 300); // fits 300 x 300
  /// final png = await image.toPng();
  /// ```
  Future<BarcodeImage> toImage({int? size, int? moduleSize}) async {
    if (size != null && moduleSize != null) {
      throw ArgumentError('Give either size or moduleSize, not both');
    }
    if ((size ?? 1) < 1 || (moduleSize ?? 1) < 1) {
      throw ArgumentError('size and moduleSize must be positive');
    }
    final SymbolLayout layout = SymbolLayout(this);
    final int m = size != null ? layout.moduleSizeFor(size) : moduleSize ?? 4;
    final int w = layout.width * m;
    final int h = layout.height * m;
    final Uint8List pixels = Uint8List(w * h)..fillRange(0, w * h, 255);
    for (final ModuleRect r in layout.rects) {
      for (int y = r.y * m; y < (r.y + r.height) * m; y++) {
        pixels.fillRange(y * w + r.x * m, y * w + (r.x + r.width) * m, 0);
      }
    }
    final String? text = layout.text;
    if (text != null) {
      await _drawText(pixels, w, layout, m, text);
    }
    return BarcodeImage(width: w, height: h, pixels: pixels);
  }

  /// Draws [text] into the text box of [layout] with the Flutter engine.
  static Future<void> _drawText(
    Uint8List pixels,
    int width,
    SymbolLayout layout,
    int m,
    String text,
  ) async {
    final int top = layout.textTop * m;
    final int boxHeight = (SymbolLayout.textFontSize + 1) * m;
    final ui.ParagraphBuilder builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: ui.TextAlign.center,
              fontSize: SymbolLayout.textFontSize * m.toDouble(),
              height: 1,
              maxLines: 1,
            ),
          )
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF000000)))
          ..addText(text);
    final ui.Paragraph paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width.toDouble()));
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src)
      ..drawParagraph(paragraph, ui.Offset.zero);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(width, boxHeight);
    picture.dispose();
    paragraph.dispose();
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

  static String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
