import 'dart:typed_data';

// Encapsulates the result of encoding a barcode.
class Encode {
  Encode(
    this.isValid,
    this.format,
    this.text,
    this.data,
    this.length,
    this.error, {
    this.width,
    this.height,
  });

  bool isValid; // Whether the code is valid
  int? format; // The format of the code
  String? text; // The text of the code
  Uint8List? data; // The raw bytes of the code, one byte per pixel
  int? length; // The length of the raw bytes, equal to `width * height`
  String? error; // The error message

  /// The width of the generated bitmap, in pixels.
  ///
  /// zxing enlarges the symbol when the requested size is too small to hold it,
  /// so this may differ from the width passed in [EncodeParams]. Always use this
  /// value (not the requested one) when turning [data] into an image.
  int? width;

  /// The height of the generated bitmap, in pixels.
  ///
  /// See [width] for why this may differ from the requested height.
  int? height;

  @override
  String toString() =>
      'Encode(isValid: $isValid, format: $format, width: $width, '
      'height: $height, length: $length, error: $error)';
}
