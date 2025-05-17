import 'dart:core';

import 'format.dart';
import 'image_format.dart';

// Represents the parameters for decoding a barcode
class DecodeParams {
  DecodeParams({
    this.imageFormat = ImageFormat.lum,
    this.format = Format.any,
    this.width = 0,
    this.height = 0,
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropWidth = 0,
    this.cropHeight = 0,
    this.tryHarder = false,
    this.tryRotate = true,
    this.tryInverted = false,
    this.tryDownscale = false,
    this.maxNumberOfSymbols = 10,
    this.maxSize = 768,
    this.isMultiScan = false,
  });

  int imageFormat; // The image format of the image. The default is lum.
  int format; // Specify a set of BarcodeFormats that should be searched for, the default is all supported formats.
  int width; // The width of the image to scan, in pixels.
  int height; // The height of the image to scan, in pixels.
  int cropLeft; // The left of the area of the image to scan, in pixels.
  int cropTop; // The top of the area of the image to scan, in pixels.
  int cropWidth; // The width of the area of the image to scan, in pixels. If 0, the entire image width is used.
  int cropHeight; // The height of the area of the image to scan, in pixels. If 0, the entire image height is used.
  bool tryHarder; // Spend more time to try to find a barcode
  bool tryRotate; // Try to detect rotated code
  bool tryInverted; // Try to detect inverted code
  bool tryDownscale; // try detecting code in downscaled images.
  int maxNumberOfSymbols; // The maximum number of symbols (barcodes) to detect / look for in the image with ReadBarcodes
  int maxSize; // Resize the image to a smaller size before scanning to improve performance. Default is 768.
  bool isMultiScan; // Whether to scan multiple barcodes
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

  int format; // The barcode format to be generated. The default is QRCode.
  int width; // The width of the barcode image, in pixels.
  int height; // The height of the barcode image, in pixels.
  int margin; // Used for all formats, sets the minimum number of quiet zone pixels
  EccLevel
      eccLevel; // The error correction level determines how much damage the QR code can withstand while still being readable. Used for Aztec, PDF417, and QRCode only
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
