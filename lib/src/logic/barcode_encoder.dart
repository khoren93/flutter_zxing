part of 'zxing.dart';

// Encode a string into a barcode
Encode zxingEncodeBarcode({
  required String contents,
  required EncodeParams params,
}) {
  return bindings
      .encodeBarcode(
        contents.toNativeUtf8().cast<Char>(),
        params.width,
        params.height,
        params.format,
        params.margin,
        params.eccLevel.value,
      )
      .toEncode();
}
