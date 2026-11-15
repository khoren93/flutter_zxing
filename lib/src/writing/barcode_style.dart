import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// How a barcode is drawn: by `BarcodeView`, and by
/// `BarcodeSymbol.toPng` and `BarcodeSymbol.toSvg` when exported.
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
  });

  /// The image.
  final ImageProvider image;

  /// Fraction of the symbol width, 0–0.3. Larger logos may not scan.
  final double size;

  /// Clear the modules behind the logo instead of drawing over them.
  final bool clearBackground;

  @override
  bool operator ==(Object other) =>
      other is BarcodeLogo &&
      other.image == image &&
      other.size == size &&
      other.clearBackground == clearBackground;

  @override
  int get hashCode => Object.hash(image, size, clearBackground);
}
