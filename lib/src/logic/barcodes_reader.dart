part of 'zxing.dart';

/// Reads barcodes from String image path
Future<Codes> zxingReadBarcodesImagePathString(
  String path, {
  DecodeParams? params,
}) =>
    zxingReadBarcodesImagePath(
      XFile(path),
      params: params,
    );

/// Reads barcodes from XFile image path
Future<Codes> zxingReadBarcodesImagePath(
  XFile path, {
  DecodeParams? params,
}) async {
  final Uint8List imageBytes = await path.readAsBytes();
  imglib.Image? image = imglib.decodeImage(imageBytes);
  if (image == null) {
    return Codes();
  }
  image = resizeToMaxSize(image, params?.maxSize);
  return zxingReadBarcodes(
    grayscaleBytes(image),
    width: image.width,
    height: image.height,
    params: params,
  );
}

/// Reads barcodes from image url
Future<Codes> zxingReadBarcodesImageUrl(
  String url, {
  DecodeParams? params,
}) async {
  final Uint8List imageBytes =
      (await NetworkAssetBundle(Uri.parse(url)).load(url)).buffer.asUint8List();
  imglib.Image? image = imglib.decodeImage(imageBytes);
  if (image == null) {
    return Codes();
  }
  image = resizeToMaxSize(image, params?.maxSize);
  return zxingReadBarcodes(
    grayscaleBytes(image),
    width: image.width,
    height: image.height,
    params: params,
  );
}

/// Reads barcodes from Uint8List image bytes
Codes zxingReadBarcodes(
  Uint8List bytes, {
  required int width,
  required int height,
  DecodeParams? params,
}) {
  return _readBarcodes(bytes, width, height, params);
}

Codes _readBarcodes(
  Uint8List bytes,
  int width,
  int height,
  DecodeParams? params,
) {
  final CodeResults result = bindings.readBarcodes(
    bytes.allocatePointer(),
    params?.format ?? Format.any,
    width,
    height,
    params?.cropWidth ?? 0,
    params?.cropHeight ?? 0,
    params?.tryHarder ?? false ? 1 : 0,
    params?.tryRotate ?? true ? 1 : 0,
    params?.tryInverted ?? false ? 1 : 0,
  );
  final List<Code> results = <Code>[];
  for (int i = 0; i < result.count; i++) {
    results.add(result.results.elementAt(i).ref.toCode());
  }
  return Codes(codes: results, duration: result.duration);
}
