import 'dart:core';

import 'format.dart';

// Represents the parameters for decoding a barcode
class DecodeParams {
  DecodeParams({
    this.format = Format.any,
    this.cropWidth = 0,
    this.cropHeight = 0,
    this.tryHarder = false,
    this.tryRotate = true,
    this.tryInverted = false,
  });

  // Specify a set of BarcodeFormats that should be searched for, the default is all supported formats.
  int format;

  // The width of the area of the image to scan, in pixels. If 0, the entire image width is used.
  int cropWidth;

  // The height of the area of the image to scan, in pixels. If 0, the entire image height is used.
  int cropHeight;

  // Spend more time to try to find a barcode; optimize for accuracy, not speed.
  bool tryHarder;

  // Try to detect rotated code
  bool tryRotate;

  // Try to detect inverted code
  bool tryInverted;
}

// Represents the parameters for encoding a barcode
class EncodeParams {
  EncodeParams({
    this.format = Format.qrCode,
    this.width = 120,
    this.height = 120,
    this.margin = 0,
    this.eccLevel = 0,
  });

  // The barcode format to be generated. The default is QRCode.
  int format;

  // The width of the barcode image, in pixels.
  int width;

  // The height of the barcode image, in pixels.
  int height;

  // Used for all formats, sets the minimum number of quiet zone pixels
  int margin;

  // Used for Aztec, PDF417, and QRCode only, [0-8]
  int eccLevel;
}
