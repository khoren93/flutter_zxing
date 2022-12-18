import 'dart:core';

import 'format.dart';

// Represents the parameters for decoding a barcode
class Params {
  Params({
    this.format = Format.any,
    this.cropWidth = 0,
    this.cropHeight = 0,
    this.tryHarder = false,
    this.tryRotate = true,
    this.tryInverted = false,
  });

  int format;
  int cropWidth;
  int cropHeight;
  bool tryHarder;
  bool tryRotate;
  bool tryInverted;
}
