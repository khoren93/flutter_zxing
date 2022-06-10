part of 'zxing.dart';

/// Reads barcodes from String image path
Future<List<CodeResult>> readBarcodesImagePathString(
  String path, {
  int format = Format.Any,
  int cropWidth = 0,
  int cropHeight = 0,
}) =>
    readBarcodesImagePath(
      XFile(path),
      format: format,
      cropWidth: cropWidth,
      cropHeight: cropHeight,
    );

/// Reads barcodes from XFile image path
Future<List<CodeResult>> readBarcodesImagePath(
  XFile path, {
  int format = Format.Any,
  int cropWidth = 0,
  int cropHeight = 0,
}) async {
  final Uint8List imageBytes = await path.readAsBytes();
  final imglib.Image? image = imglib.decodeImage(imageBytes);
  if (image == null) {
    return <CodeResult>[];
  }
  return readBarcodes(
    image.getBytes(format: imglib.Format.luminance),
    width: image.width,
    height: image.height,
    format: format,
    cropWidth: cropWidth,
    cropHeight: cropHeight,
  );
}

/// Reads barcodes from image url
Future<List<CodeResult>> readBarcodesImageUrl(
  String url, {
  int format = Format.Any,
  int cropWidth = 0,
  int cropHeight = 0,
}) async {
  final Uint8List imageBytes =
      (await NetworkAssetBundle(Uri.parse(url)).load(url)).buffer.asUint8List();
  final imglib.Image? image = imglib.decodeImage(imageBytes);
  if (image == null) {
    return <CodeResult>[];
  }
  return readBarcodes(
    image.getBytes(format: imglib.Format.luminance),
    width: image.width,
    height: image.height,
    format: format,
    cropWidth: cropWidth,
    cropHeight: cropHeight,
  );
}

/// Reads barcodes from Uint8List image bytes
List<CodeResult> readBarcodes(
  Uint8List bytes, {
  required int width,
  required int height,
  int format = Format.Any,
  int cropWidth = 0,
  int cropHeight = 0,
}) {
  final CodeResults result = bindings.readBarcodes(
      bytes.allocatePointer(), format, width, height, cropWidth, cropHeight);
  final List<CodeResult> results = <CodeResult>[];
  for (int i = 0; i < result.count; i++) {
    results.add(result.results.elementAt(i).ref);
  }
  return results;
}
