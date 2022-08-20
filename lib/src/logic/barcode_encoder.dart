part of 'zxing.dart';

// Encode a string into a barcode
EncodeResult encodeBarcode(
  String contents, {
  int format = Format.QRCode,
  int width = 300,
  int height = 300,
  int margin = 0,
  int eccLevel = 0,
}) {
  return bindings.encodeBarcode(
    contents.toNativeUtf8().cast<Char>(),
    width,
    height,
    format,
    margin,
    eccLevel,
  );
}
