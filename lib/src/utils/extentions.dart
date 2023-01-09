import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../zxing_mobile.dart';

extension CodeExt on CodeResult {
  Code toCode() {
    return Code(
      text == nullptr ? null : text.cast<Utf8>().toDartString(),
      isValid == 1,
      error == nullptr ? null : error.cast<Utf8>().toDartString(),
      bytes == nullptr
          ? null
          : Uint8List.fromList(bytes.cast<Int8>().asTypedList(length)),
      format,
      pos == nullptr ? null : pos.ref.toPosition(),
      isInverted == 1,
      isMirrored == 1,
      duration,
    );
  }
}

extension EncodeExt on EncodeResult {
  Encode toEncode() => Encode(
        isValid == 1,
        format,
        text == nullptr ? null : text.cast<Utf8>().toDartString(),
        data == nullptr
            ? null
            : Uint32List.fromList(data.cast<Int8>().asTypedList(length)),
        length,
        error == nullptr ? null : error.cast<Utf8>().toDartString(),
      );
}

extension PoeExt on Pos {
  Position toPosition() => Position(
        imageWidth,
        imageHeight,
        topLeftX,
        topLeftY,
        topRightX,
        topRightY,
        bottomLeftX,
        bottomLeftY,
        bottomRightX,
        bottomRightY,
      );
}
