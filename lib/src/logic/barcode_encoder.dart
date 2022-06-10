part of 'zxing.dart';

EncodeResult encodeBarcode(String contents, int width, int height, int format,
    int margin, int eccLevel) {
  return bindings.encodeBarcode(
    contents.toNativeUtf8().cast<Char>(),
    width,
    height,
    format,
    margin,
    eccLevel,
  );
}
