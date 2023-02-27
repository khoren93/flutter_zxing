part of 'zxing.dart';

/// Reads barcode from String image path
Future<Code> zxingReadBarcodeImagePathString(
  String path, {
  DecodeParams? params,
}) =>
    zxingReadBarcodeImagePath(
      XFile(path),
      params: params,
    );

/// Reads barcode from XFile image path
Future<Code> zxingReadBarcodeImagePath(
  XFile path, {
  DecodeParams? params,
}) async {
  final Uint8List imageBytes = await path.readAsBytes();
  imglib.Image? image = imglib.decodeImage(imageBytes);

  if (image == null) {
    return Code();
  }
  image = resizeToMaxSize(image, params?.maxSize);
  return zxingReadBarcode(
    grayscaleBytes(image),
    width: image.width,
    height: image.height,
    params: params,
  );
}

/// Reads barcode from image url
Future<Code> zxingReadBarcodeImageUrl(
  String url, {
  DecodeParams? params,
}) async {
  final Uint8List imageBytes =
      (await NetworkAssetBundle(Uri.parse(url)).load(url)).buffer.asUint8List();
  imglib.Image? image = imglib.decodeImage(imageBytes);
  if (image == null) {
    return Code(error: 'Failed to decode image');
  }
  image = resizeToMaxSize(image, params?.maxSize);
  return zxingReadBarcode(
    grayscaleBytes(image),
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
}) =>
    _readBarcode(bytes, width, height, params);

Code _readBarcode(
  Uint8List bytes,
  int width,
  int height,
  DecodeParams? params,
) {
  return bindings
      .readBarcode(
        bytes.allocatePointer(),
        params?.format ?? Format.any,
        width,
        height,
        params?.cropWidth ?? 0,
        params?.cropHeight ?? 0,
        params?.tryHarder ?? false ? 1 : 0,
        params?.tryRotate ?? true ? 1 : 0,
        params?.tryInverted ?? false ? 1 : 0,
      )
      .toCode();
}
