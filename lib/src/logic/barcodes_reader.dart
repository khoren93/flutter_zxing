part of 'zxing.dart';

/// Reads barcodes from String image path
Future<Codes> zxingReadBarcodesImagePathString(
        String path, DecodeParams params) =>
    zxingReadBarcodesImagePath(XFile(path), params);

/// Reads barcodes from XFile image path
Future<Codes> zxingReadBarcodesImagePath(
    XFile path, DecodeParams params) async {
  final Uint8List imageBytes = await path.readAsBytes();
  imglib.Image? image = imglib.decodeImage(imageBytes);
  if (image == null) {
    return Codes();
  }
  image = resizeToMaxSize(image, params.maxSize);
  params.width = image.width;
  params.height = image.height;
  return zxingReadBarcodes(rgbBytes(image), params);
}

/// Reads barcodes from image url
Future<Codes> zxingReadBarcodesImageUrl(String url, DecodeParams params) async {
  final Uint8List imageBytes =
      (await NetworkAssetBundle(Uri.parse(url)).load(url)).buffer.asUint8List();
  imglib.Image? image = imglib.decodeImage(imageBytes);
  if (image == null) {
    return Codes();
  }
  image = resizeToMaxSize(image, params.maxSize);
  params.width = image.width;
  params.height = image.height;
  return zxingReadBarcodes(rgbBytes(image), params);
}

/// Reads barcodes from Uint8List image bytes
Codes zxingReadBarcodes(Uint8List bytes, DecodeParams params) =>
    _readBarcodes(bytes, params);

Codes _readBarcodes(Uint8List bytes, DecodeParams params) {
  final CodeResults result =
      bindings.readBarcodes(params.toDecodeBarcodeParams(bytes));
  final List<Code> codes = <Code>[];

  if (result.count == 0 || result.results == nullptr) {
    return Codes(codes: codes, duration: result.duration);
  }

  for (int i = 0; i < result.count; i++) {
    codes.add(result.results[i].toCode());
  }
  malloc.free(result.results);
  return Codes(codes: codes, duration: result.duration);
}
