import 'dart:typed_data';

import 'position.dart';

// Represents a barcode code
class Code {
  Code({
    this.text,
    this.isValid = false,
    this.error,
    this.rawBytes,
    this.format,
    this.position,
    this.isInverted = false,
    this.isMirrored = false,
    this.duration = 0,
    this.imageBytes,
    this.imageWidth,
    this.imageHeight,
  });

  String? text; // The text of the code
  bool isValid; // Whether the code is valid
  String? error; // The error of the code
  Uint8List? rawBytes; // The raw bytes of the code
  int? format; // The format of the code
  Position? position; // The position of the code
  bool isInverted; // Whether the code is inverted
  bool isMirrored; // Whether the code is mirrored
  int duration; // The duration of the decoding in milliseconds
  Uint8List? imageBytes; // The processed image bytes of the code
  int? imageWidth; // The width of the processed image
  int? imageHeight; // The height of the processed image
}

// Represents a list of barcode codes
class Codes {
  Codes({
    this.codes = const <Code>[],
    this.duration = 0,
  });

  List<Code> codes; // The list of codes
  int duration; // The duration of the decoding in milliseconds

  // Returns the first code error if any
  String? get error {
    for (final Code code in codes) {
      if (code.error != null) {
        return code.error;
      }
    }
    return null;
  }
}
