import 'dart:typed_data';

import 'format.dart';
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
    this.source,
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
  /// The image the decoder actually scanned, as one byte per pixel.
  ///
  /// This is a debugging aid, not a copy of the source image: it is the
  /// luminance the decoder worked on, already cropped to the scan rect, whatever
  /// pixel format the input had. Use it to see what the decoder saw when a scan
  /// is failing — [pngFromBytes] renders it directly.
  ///
  /// Only populated while logging is on (`zx.setLogEnabled(true)`); it is null
  /// otherwise, so that scanning does not copy a full frame per result.
  Uint8List? imageBytes;

  /// Width of [imageBytes], which is the scanned (cropped) region, not
  /// necessarily the width of the image that was passed in.
  int? imageWidth;

  /// Height of [imageBytes]. See [imageWidth].
  int? imageHeight;
  CodeSource? source; // Where did the code come from

  @override
  String toString() =>
      'Code(text: $text, isValid: $isValid, format: ${format?.name}, '
      'source: $source, duration: ${duration}ms, error: $error)';
}

// Represents a list of barcode codes
class Codes {
  Codes({this.codes = const <Code>[], this.duration = 0, String? error})
    : _error = error;

  List<Code> codes; // The list of codes
  int duration; // The duration of the decoding in milliseconds

  /// A failure that prevented scanning altogether (an unreadable file, a failed
  /// download). Kept separate from [codes] so that "nothing was found" stays
  /// distinguishable from "nothing could be scanned".
  final String? _error;

  // Returns the failure that stopped the scan, or the first code error if any
  String? get error {
    if (_error != null) {
      return _error;
    }
    for (final Code code in codes) {
      if (code.error != null) {
        return code.error;
      }
    }
    return null;
  }

  @override
  String toString() =>
      'Codes(count: ${codes.length}, duration: ${duration}ms, error: $error)';
}

enum CodeSource { camera, localImageFile, remoteImageFile, byteStream }
