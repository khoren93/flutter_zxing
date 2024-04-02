part of 'zxing.dart';

/// Reads barcode from String image path
Future<Code> zxingReadBarcodeImagePathString(
        String path, DecodeParams params) =>
    zxingReadBarcodeImagePath(XFile(path), params);

/// Reads barcode from XFile image path
Future<Code> zxingReadBarcodeImagePath(XFile path, DecodeParams params) async {
  final Uint8List imageBytes = await path.readAsBytes();
  imglib.Image? image = imglib.decodeImage(imageBytes);
  if (image == null) {
    return Code();
  }
  image = resizeToMaxSize(image, params.maxSize);
  params.width = image.width;
  params.height = image.height;
  return zxingReadBarcode(rgbBytes(image), params);
}

/// Reads barcode from image url
Future<Code> zxingReadBarcodeImageUrl(String url, DecodeParams params) async {
  final Uint8List imageBytes =
      (await NetworkAssetBundle(Uri.parse(url)).load(url)).buffer.asUint8List();
  imglib.Image? image = imglib.decodeImage(imageBytes);
  if (image == null) {
    return Code(error: 'Failed to decode image');
  }
  image = resizeToMaxSize(image, params.maxSize);
  params.width = image.width;
  params.height = image.height;
  return zxingReadBarcode(rgbBytes(image), params);
}

// Reads barcode from Uint8List image bytes
Code zxingReadBarcode(Uint8List bytes, DecodeParams params) =>
    _readBarcode(bytes, params);

Code _readBarcode(Uint8List bytes, DecodeParams params) =>
    bindings.readBarcode(params.toDecodeBarcodeParams(bytes)).toCode();
