part of 'zxing.dart';

// Reads barcodes from Uint8List image bytes
List<CodeResult> readBarcodes(Uint8List bytes, int format, int width,
    int height, int cropWidth, int cropHeight) {
  final CodeResults result = bindings.readBarcodes(
      bytes.allocatePointer(), format, width, height, cropWidth, cropHeight);
  final List<CodeResult> results = <CodeResult>[];
  for (int i = 0; i < result.count; i++) {
    results.add(result.results.elementAt(i).ref);
  }
  return results;
}
