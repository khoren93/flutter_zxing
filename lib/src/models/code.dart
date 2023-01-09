import 'dart:typed_data';

import 'position.dart';

// Represents a barcode code
class Code {
  Code(
    this.text,
    this.isValid,
    this.error,
    this.rawBytes,
    this.format,
    this.position,
    this.isInverted,
    this.isMirrored,
    this.duration,
  );

  String? text; // The text of the code
  bool isValid; // Whether the code is valid
  String? error; // The error of the code
  Uint8List? rawBytes; // The raw bytes of the code
  int? format; // The format of the code
  Position? position; // The position of the code
  bool isInverted; // Whether the code is inverted
  bool isMirrored; // Whether the code is mirrored
  int duration; // The duration of the decoding in milliseconds
}
