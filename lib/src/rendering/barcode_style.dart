import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../writing/barcode_writer.dart';
import '../writing/symbol_layout.dart';
import 'styled_export.dart';
import 'swiss_cross.dart';
import 'symbol_shapes.dart';

/// How a barcode is drawn: by `BarcodeView`, and by [toPng], [toSvg],
/// [encodePng] and [encodeSvg] when exported.
///
/// ```dart
/// const writer = BarcodeWriter(BarcodeFormat.qrCode);
/// final png = await BarcodeStyle.dots.encodePng(writer, 'https://pub.dev', size: 1024);
/// final svg = await BarcodeStyle.dots.toSvg(await writer.encode('https://pub.dev'));
/// ```
@immutable
final class BarcodeStyle {
  /// Creates a style. The defaults are black on white with square modules.
  const BarcodeStyle({
    this.color = const Color(0xFF000000),
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.gradient,
    this.moduleShape = ModuleShape.square,
    this.finderShape = FinderShape.square,
    this.quietZone = true,
    this.logo,
  });

  /// Black squares on white: the default.
  static const BarcodeStyle classic = BarcodeStyle();

  /// A Swiss QR-bill: black on white with the Swiss cross in the middle,
  /// 7 mm on a 46 mm code as the Swiss Payment Standards require, and error
  /// correction M.
  ///
  /// ```dart
  /// BarcodeView(bill.toPayload(), style: BarcodeStyle.swissQrBill)
  /// ```
  static final BarcodeStyle swissQrBill = BarcodeStyle(
    logo: BarcodeLogo(
      MemoryImage(swissCrossPng),
      size: 7 / 46,
      clearBackground: false,
      errorCorrection: ErrorCorrection.medium,
    ),
  );

  /// Rounded modules that flow into each other, rounded eyes.
  static const BarcodeStyle soft = BarcodeStyle(
    moduleShape: ModuleShape.rounded,
    finderShape: FinderShape.rounded,
  );

  /// Navy dots with round eyes.
  static const BarcodeStyle dots = BarcodeStyle(
    color: Color(0xFF0B3D91),
    moduleShape: ModuleShape.circle,
    finderShape: FinderShape.circle,
  );

  /// Rounded, with a green to blue gradient.
  static const BarcodeStyle lagoon = BarcodeStyle(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF00735D), Color(0xFF1D4ED8)],
    ),
    moduleShape: ModuleShape.rounded,
    finderShape: FinderShape.rounded,
  );

  /// Navy dots on cream paper, rounded eyes.
  static const BarcodeStyle ink = BarcodeStyle(
    color: Color(0xFF14213D),
    backgroundColor: Color(0xFFF4EFE4),
    moduleShape: ModuleShape.circle,
    finderShape: FinderShape.rounded,
  );

  /// Mint on black. Light modules on a dark ground are read by this
  /// package and most phone cameras, but not by every scanner.
  static const BarcodeStyle night = BarcodeStyle(
    color: Color(0xFF2EE6B5),
    backgroundColor: Color(0xFF0E1218),
    moduleShape: ModuleShape.rounded,
    finderShape: FinderShape.rounded,
  );

  /// The ready-made styles by name, for a style picker:
  /// [classic], [soft], [dots], [lagoon], [ink] and [night]. Add a [logo]
  /// with [copyWith].
  static const Map<String, BarcodeStyle> presets = <String, BarcodeStyle>{
    'classic': classic,
    'soft': soft,
    'dots': dots,
    'lagoon': lagoon,
    'ink': ink,
    'night': night,
  };

  /// Color of the dark modules.
  final Color color;

  /// Background color. Keep enough contrast with [color].
  final Color backgroundColor;

  /// Paints the dark modules with a gradient instead of [color].
  final Gradient? gradient;

  /// Shape of the data modules (2D formats).
  final ModuleShape moduleShape;

  /// Shape of the finder patterns ("eyes") of QR codes.
  final FinderShape finderShape;

  /// Keep the quiet zone (blank margin) around the symbol.
  final bool quietZone;

  /// An image in the middle of a QR code.
  final BarcodeLogo? logo;

  /// Renders [symbol] as an SVG document drawn with this style: the
  /// colors, gradient, module and finder shapes and logo of `BarcodeView`.
  ///
  /// One SVG unit is one module, quiet zone included; scale it with the
  /// `width`/`height` of the element that shows it. The logo is embedded
  /// as a PNG. Asynchronous because the logo is loaded first.
  ///
  /// Throws [UnsupportedError] for a [SweepGradient], which SVG cannot
  /// draw; use [toPng] for it.
  ///
  /// ```dart
  /// final symbol = await const BarcodeWriter(BarcodeFormat.qrCode).encode('https://pub.dev');
  /// await File('qr.svg').writeAsString(
  ///   await const BarcodeStyle(moduleShape: ModuleShape.rounded).toSvg(symbol),
  /// );
  /// ```
  Future<String> toSvg(BarcodeSymbol symbol) => styledSvg(symbol, this);

  /// Renders [symbol] as a PNG drawn with this style, like `BarcodeView`.
  ///
  /// Give either [size] (fit into `size` × `size` pixels with whole-pixel
  /// modules) or [moduleSize] (pixels per module). Defaults to 4 pixels per
  /// module.
  ///
  /// Throws [ArgumentError] if both are given or one is not positive.
  ///
  /// ```dart
  /// final png = await const BarcodeStyle(
  ///   color: Color(0xFF1B4DFF),
  ///   moduleShape: ModuleShape.circle,
  /// ).toPng(symbol, size: 1024);
  /// ```
  Future<Uint8List> toPng(
    BarcodeSymbol symbol, {
    int? size,
    int? moduleSize,
  }) async {
    final SymbolLayout layout = SymbolLayout(styledSymbol(symbol, this));
    return styledPng(symbol, this, pixelsPerModule(layout, size, moduleSize));
  }

  /// Encodes [data] with [writer] and renders it as an SVG document drawn
  /// with this style; see [toSvg]. A QR code with a [logo] gets the logo's
  /// [BarcodeLogo.errorCorrection] unless the writer sets its own, as in
  /// `BarcodeView`.
  ///
  /// Throws `BarcodeWriteException` if [data] cannot be encoded.
  Future<String> encodeSvg(BarcodeWriter writer, String data) async =>
      toSvg(await _writer(writer).encode(data));

  /// Encodes [data] with [writer] and renders it as a PNG drawn with this
  /// style; see [toPng]. A QR code with a [logo] gets the logo's
  /// [BarcodeLogo.errorCorrection] unless the writer sets its own, as in
  /// `BarcodeView`.
  ///
  /// Throws `BarcodeWriteException` if [data] cannot be encoded.
  Future<Uint8List> encodePng(
    BarcodeWriter writer,
    String data, {
    int? size,
    int? moduleSize,
  }) async => toPng(
    await _writer(writer).encode(data),
    size: size,
    moduleSize: moduleSize,
  );

  /// [writer] as `BarcodeView` uses it for this style: the most error
  /// correction under a logo.
  BarcodeWriter _writer(BarcodeWriter writer) =>
      logo != null &&
          writer.errorCorrection == null &&
          hasFinderPatterns(writer.format)
      ? writer.copyWith(errorCorrection: logo!.errorCorrection)
      : writer;

  /// Creates a copy with the given fields replaced.
  BarcodeStyle copyWith({
    Color? color,
    Color? backgroundColor,
    Gradient? gradient,
    ModuleShape? moduleShape,
    FinderShape? finderShape,
    bool? quietZone,
    BarcodeLogo? logo,
  }) => BarcodeStyle(
    color: color ?? this.color,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    gradient: gradient ?? this.gradient,
    moduleShape: moduleShape ?? this.moduleShape,
    finderShape: finderShape ?? this.finderShape,
    quietZone: quietZone ?? this.quietZone,
    logo: logo ?? this.logo,
  );

  @override
  bool operator ==(Object other) =>
      other is BarcodeStyle &&
      other.color == color &&
      other.backgroundColor == backgroundColor &&
      other.gradient == gradient &&
      other.moduleShape == moduleShape &&
      other.finderShape == finderShape &&
      other.quietZone == quietZone &&
      other.logo == logo;

  @override
  int get hashCode => Object.hash(
    color,
    backgroundColor,
    gradient,
    moduleShape,
    finderShape,
    quietZone,
    logo,
  );
}

/// Shape of the data modules of QR, Aztec and Data Matrix codes. Linear
/// barcodes and PDF417 always use plain bars and rows.
enum ModuleShape {
  /// Classic squares.
  square,

  /// Neighbouring modules flow into one shape; corners with no neighbour on
  /// either side are rounded.
  rounded,

  /// Dots.
  circle,
}

/// Shape of the finder patterns ("eyes") of a QR code.
enum FinderShape {
  /// Classic squares.
  square,

  /// Rounded squares.
  rounded,

  /// Circles.
  circle,
}

/// An image placed in the middle of a QR code.
@immutable
final class BarcodeLogo {
  /// Creates a logo. [size] is the fraction of the symbol width it covers.
  const BarcodeLogo(
    this.image, {
    this.size = 0.22,
    this.clearBackground = true,
    this.errorCorrection = ErrorCorrection.high,
  });

  /// The image.
  final ImageProvider image;

  /// Fraction of the symbol width, 0–0.3. Larger logos may not scan.
  final double size;

  /// Clear the modules behind the logo instead of drawing over them.
  final bool clearBackground;

  /// The error correction a QR code gets under this logo when the writer or
  /// `BarcodeView` sets none. Default [ErrorCorrection.high], which covers
  /// the most modules; a standard may fix it lower, such as the Swiss
  /// QR-bill's [ErrorCorrection.medium].
  final ErrorCorrection errorCorrection;

  @override
  bool operator ==(Object other) =>
      other is BarcodeLogo &&
      other.image == image &&
      other.size == size &&
      other.clearBackground == clearBackground &&
      other.errorCorrection == errorCorrection;

  @override
  int get hashCode =>
      Object.hash(image, size, clearBackground, errorCorrection);
}
