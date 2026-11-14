import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../content/barcode_content.dart';
import 'barcode_format.dart';

/// A barcode found in an image or a camera frame.
///
/// ```dart
/// final barcode = await const BarcodeReader().read(bytes);
/// if (barcode != null) print('${barcode.format.displayName}: ${barcode.text}');
/// ```
@immutable
final class Barcode {
  /// Creates a barcode. Results come from the engine; the constructor is
  /// public so tests and fakes can build them.
  const Barcode({
    required this.format,
    required this.text,
    required this.bytes,
    required this.position,
    this.contentType = BarcodeContentType.text,
    this.orientation = 0,
    this.isMirrored = false,
    this.isInverted = false,
    this.ecLevel,
    this.version,
    this.symbologyIdentifier = '',
    this.sequence,
    this.error,
  });

  /// The symbology, as specific as known (e.g. [BarcodeFormat.ean13]).
  final BarcodeFormat format;

  /// The payload as text (UTF-8, or decoded with the character set the
  /// barcode declares). For GS1 codes this is the human readable form,
  /// e.g. `(01)09501101530003(17)250101`.
  final String text;

  /// The raw payload bytes, before any character set interpretation.
  final Uint8List bytes;

  /// Where the barcode is, in pixels of the source image.
  final BarcodePosition position;

  /// How to interpret the payload.
  final BarcodeContentType contentType;

  /// The payload parsed into a typed value: a URL, a Wi-Fi network, a
  /// contact, GS1 data and so on. Falls back to [TextContent] or
  /// [BinaryContent].
  ///
  /// ```dart
  /// switch (barcode.content) {
  ///   case UrlContent(:final url): openUrl(url);
  ///   case WifiContent(:final ssid, :final password): connect(ssid, password);
  ///   default: print(barcode.text);
  /// }
  /// ```
  BarcodeContent get content => BarcodeContent.parse(this);

  /// Clockwise rotation of the symbol in degrees.
  final int orientation;

  /// Whether the symbol was found mirrored.
  final bool isMirrored;

  /// Whether the symbol was found with inverted colors (light on dark).
  final bool isInverted;

  /// Error correction level, if the symbology has one (`L`, `M`, `Q`, `H`
  /// for QR codes).
  final String? ecLevel;

  /// Symbol version, if the symbology has one (`4` for a 33×33 QR code).
  final String? version;

  /// ISO/IEC 15424 symbology identifier, e.g. `]Q1`.
  final String symbologyIdentifier;

  /// Structured append: the part of a multi-symbol message this barcode is,
  /// or `null` if it stands alone.
  final BarcodeSequence? sequence;

  /// Why the barcode could not be decoded, or `null` if it was. Only
  /// barcodes read with [ReaderOptions.returnErrors] can have an error.
  final BarcodeError? error;

  /// Whether the barcode was decoded successfully.
  bool get isValid => error == null;

  @override
  bool operator ==(Object other) =>
      other is Barcode &&
      other.format == format &&
      other.text == text &&
      listEquals(other.bytes, bytes) &&
      other.position == position &&
      other.error == error;

  @override
  int get hashCode => Object.hash(format, text, position);

  @override
  String toString() => 'Barcode(${format.name}, "$text")';
}

/// How the payload of a [Barcode] should be interpreted.
enum BarcodeContentType {
  /// Plain text.
  text,

  /// Arbitrary binary data.
  binary,

  /// Text and binary segments.
  mixed,

  /// GS1 data (Application Identifiers).
  gs1,

  /// ISO/IEC 15434 data (e.g. ANSI MH10.8.2).
  iso15434,

  /// The barcode declares a character set this version cannot decode.
  unknownEci,
}

/// The four corners of a barcode, in pixels of the source image.
///
/// Corners follow the symbol, so for a rotated barcode [topLeft] is the
/// symbol's own top-left corner, not the one closest to the image origin.
@immutable
final class BarcodePosition {
  /// Creates a position from its four corners.
  const BarcodePosition({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  /// The symbol's top-left corner.
  final Offset topLeft;

  /// The symbol's top-right corner.
  final Offset topRight;

  /// The symbol's bottom-right corner.
  final Offset bottomRight;

  /// The symbol's bottom-left corner.
  final Offset bottomLeft;

  /// The corners in order: top-left, top-right, bottom-right, bottom-left.
  List<Offset> get corners => <Offset>[
    topLeft,
    topRight,
    bottomRight,
    bottomLeft,
  ];

  /// The smallest axis-aligned rectangle containing all corners.
  Rect get bounds {
    final List<Offset> points = corners;
    final Iterable<double> xs = points.map((Offset p) => p.dx);
    final Iterable<double> ys = points.map((Offset p) => p.dy);
    return Rect.fromLTRB(
      xs.reduce(math.min),
      ys.reduce(math.min),
      xs.reduce(math.max),
      ys.reduce(math.max),
    );
  }

  /// The centre of the four corners.
  Offset get center => (topLeft + topRight + bottomRight + bottomLeft) / 4;

  @override
  bool operator ==(Object other) =>
      other is BarcodePosition &&
      other.topLeft == topLeft &&
      other.topRight == topRight &&
      other.bottomRight == bottomRight &&
      other.bottomLeft == bottomLeft;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);

  @override
  String toString() =>
      'BarcodePosition($topLeft, $topRight, $bottomRight, $bottomLeft)';
}

/// One symbol of a structured append sequence (a message split across
/// several barcodes).
@immutable
final class BarcodeSequence {
  /// Creates a sequence entry.
  const BarcodeSequence({
    required this.index,
    required this.size,
    this.id = '',
  });

  /// Zero-based position of this symbol in the sequence.
  final int index;

  /// Number of symbols in the sequence.
  final int size;

  /// Identifier shared by all symbols of the sequence, if the symbology has one.
  final String id;

  /// Whether this is the last symbol of the sequence.
  bool get isLast => index == size - 1;

  @override
  bool operator ==(Object other) =>
      other is BarcodeSequence &&
      other.index == index &&
      other.size == size &&
      other.id == id;

  @override
  int get hashCode => Object.hash(index, size, id);
}

/// Why a barcode was found but could not be decoded.
@immutable
final class BarcodeError {
  /// Creates an error.
  const BarcodeError(this.kind, [this.message = '']);

  /// The kind of failure.
  final BarcodeErrorKind kind;

  /// Details from the engine, for logs. Not localized.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is BarcodeError && other.kind == kind && other.message == message;

  @override
  int get hashCode => Object.hash(kind, message);

  @override
  String toString() =>
      'BarcodeError(${kind.name}${message.isEmpty ? '' : ': $message'})';
}

/// The kind of a [BarcodeError].
enum BarcodeErrorKind {
  /// The data is not valid for the symbology.
  format,

  /// The checksum did not match.
  checksum,

  /// The symbol uses a feature this engine does not support.
  unsupported,
}
