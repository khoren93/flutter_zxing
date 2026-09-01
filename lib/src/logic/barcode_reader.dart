part of 'zxing.dart';

/// Reads barcode from String image path
Future<Code> zxingReadBarcodeImagePathString(
  String path,
  DecodeParams params,
) => zxingReadBarcodeImagePath(XFile(path), params);

/// Reads barcode from XFile image path
///
/// Returns a [Code] carrying an `error` instead of throwing when the file
/// cannot be read or decoded.
Future<Code> zxingReadBarcodeImagePath(XFile path, DecodeParams params) async {
  final _DecodedImage decoded = await _decodeImageFile(path, params);
  if (decoded.error != null) {
    return Code(error: decoded.error, source: CodeSource.localImageFile);
  }
  return _readBarcode(
    decoded.bytes!,
    decoded.params!,
    CodeSource.localImageFile,
  );
}

/// Reads barcode from image url
///
/// Returns a [Code] carrying an `error` instead of throwing when the image
/// cannot be fetched or decoded.
Future<Code> zxingReadBarcodeImageUrl(String url, DecodeParams params) async {
  final _DecodedImage decoded = await _decodeImageUrl(url, params);
  if (decoded.error != null) {
    return Code(error: decoded.error, source: CodeSource.remoteImageFile);
  }
  return _readBarcode(
    decoded.bytes!,
    decoded.params!,
    CodeSource.remoteImageFile,
  );
}

/// Reads barcode from Uint8List image bytes
Code zxingReadBarcode(Uint8List bytes, DecodeParams params) =>
    _readBarcode(bytes, params, CodeSource.byteStream);

Code _readBarcode(Uint8List bytes, DecodeParams params, CodeSource source) {
  final Code code = bindings
      .readBarcode(params.toDecodeBarcodeParams(bytes))
      .toCode();
  code.source = source;
  return code;
}
