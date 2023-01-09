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
    this.maxSize = 768,
    this.isMultiScan = false,
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

  // Resize the image to a smaller size before scanning to improve performance. Default is 768.
  int maxSize;

  // Whether to scan multiple barcodes
  bool isMultiScan;
}

// Represents the parameters for encoding a barcode
class EncodeParams {
  EncodeParams({
    this.format = Format.qrCode,
    this.width = 100,
    this.height = 100,
    this.margin = 0,
    this.eccLevel = EccLevel.low,
  });

  // The barcode format to be generated. The default is QRCode.
  int format;

  // The width of the barcode image, in pixels.
  int width;

  // The height of the barcode image, in pixels.
  int height;

  // Used for all formats, sets the minimum number of quiet zone pixels
  int margin;

  // The error correction level determines how much damage the QR code can withstand while still being readable.
  // Used for Aztec, PDF417, and QRCode only
  EccLevel eccLevel;
}

enum EccLevel {
  low, // Low error correction level. Can withstand up to 7% damage.
  medium, // Medium error correction level. Can withstand up to 15% damage.
  quartile, // Quartile error correction level. Can withstand up to 25% damage.
  high, // High error correction level. Can withstand up to 30% damage.
}

extension EccLevelExtension on EccLevel {
  static const Map<EccLevel, int> _valuesMap = <EccLevel, int>{
    EccLevel.low: 2,
    EccLevel.medium: 4,
    EccLevel.quartile: 6,
    EccLevel.high: 8,
  };

  int get value => _valuesMap[this] ?? 0;
}
