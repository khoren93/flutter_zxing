import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../zxing_mobile.dart';

/// From an owned pointer allocated in native code, copy the data into the Dart
/// VM Heap as a [Uint8List] and then immediately `free` the owned ffi pointer.
Uint8List? copyUint8ListFromOwnedFfiPtr(Pointer<Uint8> data, int length) {
  if (data == nullptr || length == 0) {
    return null;
  }

  final Uint8List out = Uint8List.fromList(data.asTypedList(length));
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
      isValid: isValid,
      error: copyStringFromOwnedFfiPtr(error),
      rawBytes: copyUint8ListFromOwnedFfiPtr(bytes, length),
      format: format,
      position: pos.toPosition(),
      isInverted: isInverted,
      isMirrored: isMirrored,
      duration: duration,
      imageBytes: copyUint8ListFromOwnedFfiPtr(imageBytes, imageLength),
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }
}

extension EncodeExt on EncodeResult {
  Encode toEncode(final String text) => Encode(
        isValid,
        format,
        text,
        copyUint8ListFromOwnedFfiPtr(data, length),
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

extension EncodeParamsExt on EncodeParams {
  Pointer<EncodeBarcodeParams> toEncodeBarcodeParams(String contents) {
    final Pointer<EncodeBarcodeParams> p = calloc<EncodeBarcodeParams>();
    p.ref.contents = contents.toNativeUtf8().cast<Char>();
    p.ref.width = width;
    p.ref.height = height;
    p.ref.format = format;
    p.ref.margin = margin;
    p.ref.eccLevel = eccLevel.value;
    return p;
  }
}

extension DecodeParamsExt on DecodeParams {
  Pointer<DecodeBarcodeParams> toDecodeBarcodeParams(Uint8List bytes) {
    final Pointer<DecodeBarcodeParams> p = calloc<DecodeBarcodeParams>();
    p.ref.bytes = bytes.copyToNativePointer();
    p.ref.imageFormat = imageFormat;
    p.ref.format = format;
    p.ref.width = width;
    p.ref.height = height;
    p.ref.cropLeft = cropLeft;
    p.ref.cropTop = cropTop;
    p.ref.cropWidth = cropWidth;
    p.ref.cropHeight = cropHeight;
    p.ref.tryHarder = tryHarder;
    p.ref.tryRotate = tryRotate;
    p.ref.tryInvert = tryInverted;
    p.ref.tryDownscale = tryDownscale;
    p.ref.maxNumberOfSymbols = maxNumberOfSymbols;
    return p;
  }
}
