part of 'zxing.dart';

/// Reads barcode from String image path
Future<CodeResult?> readBarcodeImagePathString(
  String path, {
  int format = Format.Any,
  int cropWidth = 0,
  int cropHeight = 0,
}) =>
    readBarcodeImagePath(
      XFile(path),
      format: format,
      cropWidth: cropWidth,
      cropHeight: cropHeight,
    );

/// Reads barcode from XFile image path
Future<CodeResult?> readBarcodeImagePath(
  XFile path, {
  int format = Format.Any,
  int cropWidth = 0,
  int cropHeight = 0,
}) async {
  final Uint8List imageBytes = await path.readAsBytes();
  final imglib.Image? image = imglib.decodeImage(imageBytes);
  if (image == null) {
    return null;
  }
  return readBarcode(
    image.getBytes(format: imglib.Format.luminance),
    width: image.width,
    height: image.height,
    format: format,
    cropWidth: cropWidth,
    cropHeight: cropHeight,
  );
}

/// Reads barcode from image url
Future<CodeResult?> readBarcodeImageUrl(
  String url, {
  int format = Format.Any,
  int cropWidth = 0,
  int cropHeight = 0,
}) async {
  final Uint8List imageBytes =
      (await NetworkAssetBundle(Uri.parse(url)).load(url)).buffer.asUint8List();
  final imglib.Image? image = imglib.decodeImage(imageBytes);
  if (image == null) {
    return null;
  }
  return readBarcode(
    image.getBytes(format: imglib.Format.luminance),
    width: image.width,
    height: image.height,
    format: format,
    cropWidth: cropWidth,
    cropHeight: cropHeight,
  );
}

// Reads barcode from Uint8List image bytes
CodeResult readBarcode(
  Uint8List bytes, {
  required int width,
  required int height,
  int format = Format.Any,
  int cropWidth = 0,
  int cropHeight = 0,
}) =>
    bindings.readBarcode(
      bytes.allocatePointer(),
      format,
      width,
      height,
      cropWidth,
      cropHeight,
    );
