part of 'zxing.dart';

/// Reads barcode from String image path
Future<Code?> zxingReadBarcodeImagePathString(
  String path, {
  DecodeParams? params,
}) =>
    zxingReadBarcodeImagePath(
      XFile(path),
      params: params,
    );

/// Reads barcode from XFile image path
Future<Code?> zxingReadBarcodeImagePath(
  XFile path, {
  DecodeParams? params,
}) async {
  final Uint8List imageBytes = await path.readAsBytes();
  final imglib.Image? image = imglib.decodeImage(imageBytes);
  if (image == null) {
    return null;
  }
  return zxingReadBarcode(
    image.getBytes(format: imglib.Format.luminance),
    width: image.width,
    height: image.height,
    params: params,
  );
}

/// Reads barcode from image url
Future<Code?> zxingReadBarcodeImageUrl(
  String url, {
  DecodeParams? params,
}) async {
  final Uint8List imageBytes =
      (await NetworkAssetBundle(Uri.parse(url)).load(url)).buffer.asUint8List();
  final imglib.Image? image = imglib.decodeImage(imageBytes);
  if (image == null) {
    return null;
  }
  return zxingReadBarcode(
    image.getBytes(format: imglib.Format.luminance),
    width: image.width,
    height: image.height,
    params: params,
  );
}

// Reads barcode from Uint8List image bytes
Code zxingReadBarcode(
  Uint8List bytes, {
  required int width,
  required int height,
  DecodeParams? params,
}) {
  Code result = _readBarcode(bytes, width, height, params);
  if (!result.isValid && params != null && params.tryInverted == true) {
    // try to invert the image and read again
    final Uint8List invertedBytes = invertImage(bytes);
    result = _readBarcode(invertedBytes, width, height, params);
  }
  return result;
}

Code _readBarcode(
  Uint8List bytes,
  int width,
  int height,
  DecodeParams? params,
) =>
    bindings
        .readBarcode(
          bytes.allocatePointer(),
          params?.format ?? Format.any,
          width,
          height,
          params?.cropWidth ?? 0,
          params?.cropHeight ?? 0,
          params?.tryHarder ?? false ? 1 : 0,
          params?.tryRotate ?? true ? 1 : 0,
        )
        .toCode();
