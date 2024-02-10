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
    rgbBytes(image),
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
    rgbBytes(image),
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
    bytes.copyToNativePointer(),
    params?.imageFormat ?? zx.ImageFormat.lum,
    params?.format ?? Format.any,
    width,
    height,
    params?.cropWidth ?? 0,
    params?.cropHeight ?? 0,
    params?.tryHarder ?? false,
    params?.tryRotate ?? true,
    params?.tryInverted ?? false,
  );

  final List<Code> codes = <Code>[];

  if (result.count == 0 || result.results == nullptr) {
    return Codes(codes: codes, duration: result.duration);
  }

  for (int i = 0; i < result.count; i++) {
    codes.add(result.results.elementAt(i).ref.toCode());
  }
  malloc.free(result.results);
  return Codes(codes: codes, duration: result.duration);
}
