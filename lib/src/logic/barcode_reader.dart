part of 'zxing.dart';

/// Reads barcode from String image path
Future<CodeResult?> readImagePathString(
  String path, {
  int format = Format.Any,
  int cropWidth = 0,
  int cropHeight = 0,
}) =>
    readImagePath(XFile(path),
        format: format, cropWidth: cropWidth, cropHeight: cropHeight);

/// Reads barcode from XFile image path
Future<CodeResult?> readImagePath(
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
    format,
    image.width,
    image.height,
    cropWidth,
    cropHeight,
  );
}

/// Reads barcode from image url
Future<CodeResult?> readImageUrl(
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
    format,
    image.width,
    image.height,
    cropWidth,
    cropHeight,
  );
}

// Reads barcode from Uint8List image bytes
CodeResult readBarcode(
  Uint8List bytes,
  int format,
  int width,
  int height,
  int cropWidth,
  int cropHeight,
) =>
    bindings.readBarcode(
      bytes.allocatePointer(),
      format,
      width,
      height,
      cropWidth,
      cropHeight,
    );
