import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../barcode/barcode_format.dart';
import '../errors.dart';
import 'barcode_writer.dart';

/// Shows a barcode. Drawn as vectors from the module matrix, so it is sharp
/// at any size and pixel density.
///
/// ```dart
/// BarcodeView('https://pub.dev', format: BarcodeFormat.qrCode, width: 200)
/// BarcodeView('4006381333931', format: BarcodeFormat.ean13, showText: true, width: 240)
/// BarcodeView.bytes(payload, format: BarcodeFormat.dataMatrix, width: 120)
/// ```
///
/// Without [width] and [height] it fills the incoming constraints, keeping
/// the symbol's aspect ratio.
class BarcodeView extends StatefulWidget {
  /// Creates a barcode view for the text [data].
  const BarcodeView(
    String this.data, {
    super.key,
    this.format = BarcodeFormat.qrCode,
    this.errorCorrection,
    this.showText = false,
    this.style = const BarcodeStyle(),
    this.width,
    this.height,
    this.semanticLabel,
    this.errorBuilder,
  }) : bytes = null;

  /// Creates a barcode view for binary [bytes] (formats with a byte mode:
  /// QR, Data Matrix, Aztec, PDF417).
  const BarcodeView.bytes(
    Uint8List this.bytes, {
    super.key,
    this.format = BarcodeFormat.qrCode,
    this.errorCorrection,
    this.style = const BarcodeStyle(),
    this.width,
    this.height,
    this.semanticLabel,
    this.errorBuilder,
  }) : data = null,
       showText = false;

  /// The text to encode, or `null` for [BarcodeView.bytes].
  final String? data;

  /// The binary data to encode, or `null` for text.
  final Uint8List? bytes;

  /// The symbology; must be writable ([BarcodeFormat.canWrite]).
  final BarcodeFormat format;

  /// Error correction; `null` uses the format's default, or
  /// [ErrorCorrection.high] when [BarcodeStyle.logo] is set.
  final ErrorCorrection? errorCorrection;

  /// Show the human readable text under linear barcodes.
  final bool showText;

  /// Colors and shapes.
  final BarcodeStyle style;

  /// Width in logical pixels.
  final double? width;

  /// Height in logical pixels.
  final double? height;

  /// Accessibility label; defaults to "`format` barcode: `data`".
  final String? semanticLabel;

  /// Shown instead of the barcode if [data] cannot be encoded. Without it,
  /// an empty box is shown and the error is reported to `FlutterError`.
  final Widget Function(BuildContext context, BarcodeWriteException error)?
  errorBuilder;

  @override
  State<BarcodeView> createState() => _BarcodeViewState();
}

class _BarcodeViewState extends State<BarcodeView> {
  @override
  Widget build(BuildContext context) => throw UnimplementedError('Stage 7');
}

/// How a [BarcodeView] is drawn.
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

/// Shape of the data modules of a 2D barcode.
enum ModuleShape {
  /// Classic squares.
  square,

  /// Squares with rounded corners.
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
