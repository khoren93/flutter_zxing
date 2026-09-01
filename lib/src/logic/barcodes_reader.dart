part of 'zxing.dart';

/// Reads barcodes from String image path
Future<Codes> zxingReadBarcodesImagePathString(
  String path,
  DecodeParams params,
) => zxingReadBarcodesImagePath(XFile(path), params);

/// Reads barcodes from XFile image path
///
/// Returns [Codes] carrying an `error` instead of throwing when the file cannot
/// be read or decoded.
Future<Codes> zxingReadBarcodesImagePath(
  XFile path,
  DecodeParams params,
) async {
  final _DecodedImage decoded = await _decodeImageFile(path, params);
  if (decoded.error != null) {
    return _errorCodes(decoded.error!);
  }
  return _readBarcodes(
    decoded.bytes!,
    decoded.params!,
    CodeSource.localImageFile,
  );
}

/// Reads barcodes from image url
///
/// Returns [Codes] carrying an `error` instead of throwing when the image
/// cannot be fetched or decoded.
Future<Codes> zxingReadBarcodesImageUrl(String url, DecodeParams params) async {
  final _DecodedImage decoded = await _decodeImageUrl(url, params);
  if (decoded.error != null) {
    return _errorCodes(decoded.error!);
  }
  return _readBarcodes(
    decoded.bytes!,
    decoded.params!,
    CodeSource.remoteImageFile,
  );
}

/// Reads barcodes from Uint8List image bytes
Codes zxingReadBarcodes(Uint8List bytes, DecodeParams params) =>
    _readBarcodes(bytes, params, CodeSource.byteStream);

Codes _readBarcodes(Uint8List bytes, DecodeParams params, CodeSource source) {
  final CodeResults result = bindings.readBarcodes(
    params.toDecodeBarcodeParams(bytes),
  );
  final List<Code> codes = <Code>[];

  if (result.count == 0 || result.results == nullptr) {
    return Codes(codes: codes, duration: result.duration);
  }

  for (int i = 0; i < result.count; i++) {
    codes.add(result.results[i].toCode()..source = source);
  }
  malloc.free(result.results);
  return Codes(codes: codes, duration: result.duration);
}

/// A failed scan: no codes, but the reason is carried on [Codes.error].
///
/// The list stays empty on purpose -- callers treat a non-empty list as "codes
/// were found", so a synthetic failure entry there would read as a success.
Codes _errorCodes(String error) => Codes(error: error);
