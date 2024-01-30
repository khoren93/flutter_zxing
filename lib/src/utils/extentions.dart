import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../zxing_mobile.dart';

/// From an owned pointer allocated in native code, copy the data into the Dart
/// VM Heap as a [Uint32List] and then immediately `free` the owned ffi pointer.
Uint32List? copyUint32ListFromOwnedFfiPtr(
  Pointer<SignedChar> data,
  int length,
) {
  if (data == nullptr || length == 0) {
    return null;
  }

  final Uint32List out =
      Uint32List.fromList(data.cast<Int8>().asTypedList(length));
  malloc.free(data);
  return out;
}

/// From an owned pointer allocated in native code, copy the data into the Dart
/// VM Heap as a [Uint8List] and then immediately `free` the owned ffi pointer.
Uint8List? copyUint8ListFromOwnedFfiPtr(
    Pointer<UnsignedChar> data, int length) {
  if (data == nullptr || length == 0) {
    return null;
  }

  final Uint8List out =
      Uint8List.fromList(data.cast<Int8>().asTypedList(length));
  malloc.free(data);
  return out;
}

/// From an owned, UTF-8 encoded C-string (null-byte terminated) allocated in
/// native code, copy the string into the Dart VM Heap as a [String]a and then
/// immediately `free` the owned pointer.
String? copyStringFromOwnedFfiPtr(Pointer<Char> text) {
  if (text == nullptr) {
    return null;
  }

  final String out = text.cast<Utf8>().toDartString();
  malloc.free(text);
  return out;
}

extension CodeExt on CodeResult {
  Code toCode() {
    return Code(
      text: copyStringFromOwnedFfiPtr(text),
      isValid: isValid == 1,
      error: copyStringFromOwnedFfiPtr(error),
      rawBytes: copyUint8ListFromOwnedFfiPtr(bytes, length),
      format: format,
      position: pos.toPosition(),
      isInverted: isInverted == 1,
      isMirrored: isMirrored == 1,
      duration: duration,
    );
  }
}

extension EncodeExt on EncodeResult {
  Encode toEncode() => Encode(
        isValid == 1,
        format,
        copyStringFromOwnedFfiPtr(text),
        copyUint32ListFromOwnedFfiPtr(data, length),
        length,
        copyStringFromOwnedFfiPtr(error),
      );
}

extension PosExt on Pos {
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
