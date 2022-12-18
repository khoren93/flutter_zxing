import 'dart:typed_data';

// Encapsulates the result of encoding a barcode.
class Encode {
  Encode(
    this.isValid,
    this.format,
    this.text,
    this.data,
    this.length,
    this.error,
  );

  bool isValid; // Whether the code is valid
  int? format; // The format of the code
  String? text; // The text of the code
  Uint32List? data; // The raw bytes of the code
  int? length; // The length of the raw bytes
  String? error; // The error message
}
