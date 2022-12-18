import 'dart:typed_data';

import 'position.dart';

// Represents a barcode code
class Code {
  Code(
    this.isValid,
    this.text,
    this.rawBytes,
    this.format,
    this.position,
  );

  bool isValid; // Whether the code is valid
  String? text; // The text of the code
  Uint8List? rawBytes; // The raw bytes of the code
  int? format; // The format of the code
  Position? position; // The position of the code
}
