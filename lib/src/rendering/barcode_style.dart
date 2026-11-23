import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../barcode/barcode_format.dart';
import '../writing/barcode_writer.dart';
import 'logo_symbol.dart';
import 'styled_export.dart';
import 'swiss_cross.dart';

/// How a barcode is drawn: by `BarcodeView`, and by [toPng], [toSvg],
/// [encodePng] and [encodeSvg] when exported.
///
/// ```dart
/// // A QR code unless you give a writer.
/// final png = await BarcodeStyle.dots.encodePng('https://pub.dev', size: 1024);
/// final ean = await BarcodeStyle.classic.encodeSvg(
///   '4006381333931',
///   writer: const BarcodeWriter(BarcodeFormat.ean13),
/// );
///
/// // Encode once, draw twice: encode gives a logo the error correction it
/// // needs.
/// const style = BarcodeStyle.dots;
/// final symbol = await style.encode('https://pub.dev');
/// final svg = await style.toSvg(symbol);
/// final thumbnail = await style.toPng(symbol, size: 256);
/// ```
///
/// **Exports.** The PNG is drawn by the Flutter engine without the app's
/// theme: the text of [title] and [caption] uses the engine's default font
/// unless their [BarcodeCaption.style] names a `fontFamily` (a font the app
/// bundles or the platform has). An SVG only names the font; the program
/// that shows it picks the closest one it has. The [logo] is loaded first;
/// if its image fails to load, the export fails with the image's error.
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
    this.title,
    this.caption,
    this.card,
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
  /// with [copyWith]: `BarcodeStyle.soft.copyWith(logo: () => myLogo)`.
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

  /// Paints the dark modules with a gradient instead of [color]. Text drawn
  /// with the code (the digits under EAN/UPC, a [title] or [caption]
  /// without a color of its own) takes its first color.
  ///
  /// SVG has no sweep gradient: a [SweepGradient] is drawn by `BarcodeView`
  /// and [toPng], while [toSvg] throws an [UnsupportedError] for it.
  final Gradient? gradient;

  /// Shape of the data modules (2D formats).
  final ModuleShape moduleShape;

  /// Shape of the finder patterns ("eyes") of QR codes.
  final FinderShape finderShape;

  /// Keep the quiet zone (blank margin) around the symbol.
  final bool quietZone;

  /// An image in the middle of a QR code. `BarcodeView` and [encode] give
  /// the code the error correction the logo needs.
  final BarcodeLogo? logo;

  /// Text above the code, such as a network's name.
  final BarcodeCaption? title;

  /// Text under the code, such as `@handle` or "Scan to pay".
  ///
  /// ```dart
  /// BarcodeView(
  ///   'https://t.me/flutterdev',
  ///   style: BarcodeStyle(
  ///     caption: BarcodeCaption('@FLUTTERDEV'),
  ///     card: BarcodeCard(),
  ///   ),
  /// )
  /// ```
  final BarcodeCaption? caption;

  /// A card under the code, [title] and [caption]: a rounded plate, like a
  /// profile code in a messenger.
  final BarcodeCard? card;

  /// Encodes [data] with [writer] (a QR code by default) for this style:
  /// the symbol `BarcodeView` shows. Under a [logo] a QR code gets the error correction the logo
  /// needs ([BarcodeLogo.neededErrorCorrection]) unless the writer sets its
  /// own, and a symbol large enough for it unless the writer sets a
  /// version. Encode once, then draw with [toPng] and [toSvg] as often as
  /// needed.
  ///
  /// ```dart
  /// final style = BarcodeStyle(logo: BarcodeLogo(AssetImage('assets/logo.png')));
  /// final symbol = await style.encode(wifi);
  /// final png = await style.toPng(symbol, size: 1024);
  /// ```
  ///
  /// Throws `BarcodeWriteException` if [data] cannot be encoded.
  Future<BarcodeSymbol> encode(
    String data, {
    BarcodeWriter writer = const BarcodeWriter(BarcodeFormat.qrCode),
  }) => encodeUnderLogo(
    writerUnderLogo(writer, logo),
    logo?.size,
    (BarcodeWriter w) => w.encode(data),
  );

  /// Encodes binary [data] with [writer] (a QR code by default) for this
  /// style, byte for byte; see [encode] and `BarcodeWriter.encodeBytes`.
  ///
  /// Throws `BarcodeWriteException` if [data] cannot be encoded.
  Future<BarcodeSymbol> encodeBytes(
    Uint8List data, {
    BarcodeWriter writer = const BarcodeWriter(BarcodeFormat.qrCode),
  }) => encodeUnderLogo(
    writerUnderLogo(writer, logo),
    logo?.size,
    (BarcodeWriter w) => w.encodeBytes(data),
  );

  /// Renders [symbol] as an SVG document drawn with this style: the
  /// colors, gradient, module and finder shapes and logo of `BarcodeView`.
  ///
  /// The `viewBox` is in modules; `width` and `height` are pixels:
  /// [moduleSize] pixels per module (4 by default), or [size] pixels across
  /// the longer side. The logo is embedded as a PNG. Asynchronous because
  /// the logo is loaded first. See **Exports** in the class description for
  /// fonts and logos.
  ///
  /// Throws [UnsupportedError] for a [SweepGradient], which SVG cannot
  /// draw: use [toPng] for it, or a [LinearGradient] or [RadialGradient].
  /// Throws [ArgumentError] if both [size] and [moduleSize] are given, one
  /// is not positive, or [size] is smaller than the image in modules.
  ///
  /// In debug mode, asserts that a QR code under a [logo] has the error
  /// correction the logo needs (see [encode]).
  ///
  /// ```dart
  /// final symbol = await style.encode('https://pub.dev');
  /// await File('qr.svg').writeAsString(await style.toSvg(symbol, size: 512));
  /// ```
  Future<String> toSvg(BarcodeSymbol symbol, {int? size, int? moduleSize}) =>
      styledSvg(symbol, this, size: size, moduleSize: moduleSize);

  /// Renders [symbol] as a PNG drawn with this style, like `BarcodeView`.
  ///
  /// Give either [size] or [moduleSize] (pixels per module; 4 by default).
  /// With [size] the longer side is exactly [size] pixels and the shorter
  /// one in proportion: the modules are the most whole pixels that fit, and
  /// the rest is filled with the [backgroundColor] (transparent around a
  /// [card]). The [title], [caption] and [card] are part of the image;
  /// around a card the image is transparent. See **Exports** in the class
  /// description for fonts and logos.
  ///
  /// Throws [ArgumentError] if both are given, one is not positive, or
  /// [size] is smaller than the image in modules.
  ///
  /// In debug mode, asserts that a QR code under a [logo] has the error
  /// correction the logo needs (see [encode]).
  ///
  /// ```dart
  /// final png = await const BarcodeStyle(
  ///   color: Color(0xFF1B4DFF),
  ///   moduleShape: ModuleShape.circle,
  /// ).toPng(symbol, size: 1024);
  /// ```
  Future<Uint8List> toPng(BarcodeSymbol symbol, {int? size, int? moduleSize}) =>
      styledPng(symbol, this, size: size, moduleSize: moduleSize);

  /// Encodes [data] with [writer] (a QR code by default) and renders it as
  /// an SVG document drawn with this style: [encode], then [toSvg].
  ///
  /// ```dart
  /// final String svg = await BarcodeStyle.soft.encodeSvg('https://pub.dev');
  /// ```
  ///
  /// Throws `BarcodeWriteException` if [data] cannot be encoded, and the
  /// errors of [toSvg].
  Future<String> encodeSvg(
    String data, {
    BarcodeWriter writer = const BarcodeWriter(BarcodeFormat.qrCode),
    int? size,
    int? moduleSize,
  }) async => toSvg(
    await encode(data, writer: writer),
    size: size,
    moduleSize: moduleSize,
  );

  /// Encodes [data] with [writer] (a QR code by default) and renders it as
  /// a PNG drawn with this style: [encode], then [toPng].
  ///
  /// ```dart
  /// final Uint8List png = await BarcodeStyle.dots.encodePng(
  ///   'https://pub.dev',
  ///   size: 1024,
  /// );
  /// ```
  ///
  /// Throws `BarcodeWriteException` if [data] cannot be encoded, and the
  /// errors of [toPng].
  Future<Uint8List> encodePng(
    String data, {
    BarcodeWriter writer = const BarcodeWriter(BarcodeFormat.qrCode),
    int? size,
    int? moduleSize,
  }) async => toPng(
    await encode(data, writer: writer),
    size: size,
    moduleSize: moduleSize,
  );

  /// Creates a copy with the given fields replaced.
  ///
  /// The fields that may be `null` take a function, so that they can be
  /// cleared: `copyWith(logo: () => null)` removes the logo,
  /// `copyWith(logo: () => BarcodeLogo(image))` sets one, and leaving
  /// `logo` out keeps it.
  BarcodeStyle copyWith({
    Color? color,
    Color? backgroundColor,
    ValueGetter<Gradient?>? gradient,
    ModuleShape? moduleShape,
    FinderShape? finderShape,
    bool? quietZone,
    ValueGetter<BarcodeLogo?>? logo,
    ValueGetter<BarcodeCaption?>? title,
    ValueGetter<BarcodeCaption?>? caption,
    ValueGetter<BarcodeCard?>? card,
  }) => BarcodeStyle(
    color: color ?? this.color,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    gradient: gradient == null ? this.gradient : gradient(),
    moduleShape: moduleShape ?? this.moduleShape,
    finderShape: finderShape ?? this.finderShape,
    quietZone: quietZone ?? this.quietZone,
    logo: logo == null ? this.logo : logo(),
    title: title == null ? this.title : title(),
    caption: caption == null ? this.caption : caption(),
    card: card == null ? this.card : card(),
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
      other.logo == logo &&
      other.title == title &&
      other.caption == caption &&
      other.card == card;

  @override
  int get hashCode => Object.hash(
    color,
    backgroundColor,
    gradient,
    moduleShape,
    finderShape,
    quietZone,
    logo,
    title,
    caption,
    card,
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
    this.errorCorrection,
  });

  /// The image.
  final ImageProvider image;

  /// Fraction of the symbol width, 0–0.3. Larger logos may not scan.
  final double size;

  /// Clear the modules behind the logo instead of drawing over them.
  final bool clearBackground;

  /// The error correction a QR code gets under this logo when the writer
  /// sets none. `null` (the default) picks it by [size]; see
  /// [neededErrorCorrection]. A standard may fix it, such as the Swiss
  /// QR-bill's [ErrorCorrection.medium].
  final ErrorCorrection? errorCorrection;

  /// The error correction a QR code gets under this logo: [errorCorrection]
  /// if set, otherwise by [size], from reading tests: up to 0.12 of the
  /// width, [ErrorCorrection.medium]; up to 0.2 (a messenger's profile
  /// code), [ErrorCorrection.quartile]; larger (the default logo, 0.22),
  /// [ErrorCorrection.high]. At each level the code still reads at least
  /// nine times in ten with a blot a quarter of the logo's size elsewhere
  /// on it. A smaller level keeps the code sparse, so it reads from farther
  /// away.
  ErrorCorrection get neededErrorCorrection =>
      errorCorrection ??
      (size <= 0.12
          ? ErrorCorrection.medium
          : size <= 0.2
          ? ErrorCorrection.quartile
          : ErrorCorrection.high);

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

/// Text drawn with a barcode: [BarcodeStyle.title] above it,
/// [BarcodeStyle.caption] under it. On screen and in the PNG and SVG
/// exports alike.
///
/// Sizes are fractions of the code's width without its quiet zone, so a
/// 1024-pixel export looks like the screen. The text keeps out of the quiet
/// zone above and below the code: a gap smaller than it grows to it.
@immutable
final class BarcodeCaption {
  /// Creates a caption. [text] may hold line breaks; longer lines wrap to
  /// the width of the code with its quiet zone (inside a [BarcodeCard], to
  /// the card's width without its padding), up to [maxLines], and [align]
  /// aligns to that width.
  const BarcodeCaption(
    this.text, {
    this.size = 0.09,
    this.style,
    this.align = TextAlign.center,
    this.gap = 0.05,
    this.maxLines = 2,
    this.letterSpacing = 0,
  });

  /// The text.
  final String text;

  /// Font size, as a fraction of the code's width.
  final double size;

  /// Color, weight, font family and the like. [TextStyle.fontSize] and
  /// [TextStyle.letterSpacing] are ignored: the text scales with the code,
  /// so they are [size] and [letterSpacing]. Without a color, the code's:
  /// its [BarcodeStyle.color], or the first color of its gradient. Without
  /// a weight, bold.
  ///
  /// A PNG export does not know the app's font: name a `fontFamily` (one
  /// the app bundles) to get it there. In an SVG the font is named; the
  /// program that shows the file picks the closest one it has.
  final TextStyle? style;

  /// Space added between letters, as a fraction of the font size (like CSS
  /// `em`): 0.1 spreads `@HANDLE` a little. Negative values bring letters
  /// closer.
  final double letterSpacing;

  /// Alignment within the width the text wraps to (see [BarcodeCaption.new]).
  final TextAlign align;

  /// Space between the text and the code, as a fraction of the code's
  /// width; at least the code's quiet zone, if it has one.
  final double gap;

  /// Lines at most; more are cut with an ellipsis.
  final int maxLines;

  @override
  bool operator ==(Object other) =>
      other is BarcodeCaption &&
      other.text == text &&
      other.size == size &&
      other.style == style &&
      other.align == align &&
      other.gap == gap &&
      other.maxLines == maxLines &&
      other.letterSpacing == letterSpacing;

  @override
  int get hashCode =>
      Object.hash(text, size, style, align, gap, maxLines, letterSpacing);
}

/// A rounded plate under a barcode and its text: [BarcodeStyle.card].
///
/// Lengths are fractions of the code's width without its quiet zone. The
/// quiet zone is the least padding the card gets, never added on top of it.
/// The area around the card stays transparent: in `BarcodeView` and in a
/// PNG.
@immutable
final class BarcodeCard {
  /// Creates a card.
  const BarcodeCard({
    this.color,
    this.radius = 0.12,
    this.padding = 0.1,
    this.elevation = 0,
  });

  /// The card's color; `null` uses [BarcodeStyle.backgroundColor]. Another
  /// color puts the code on its own background square, like a code printed
  /// on a colored card.
  final Color? color;

  /// Corner radius.
  final double radius;

  /// Space between the card's edge and its content.
  final double padding;

  /// A soft shadow under the card, as a fraction of the code's width
  /// (0.04 is a gentle one); 0 for none. Exports grow by the shadow's reach.
  final double elevation;

  @override
  bool operator ==(Object other) =>
      other is BarcodeCard &&
      other.color == color &&
      other.radius == radius &&
      other.padding == padding &&
      other.elevation == elevation;

  @override
  int get hashCode => Object.hash(color, radius, padding, elevation);
}
