part of 'zxing.dart';

// Encode a string into a barcode
Encode zxingEncodeBarcode({
  required String contents,
  required EncodeParams params,
}) =>
    bindings
        .encodeBarcode(params.toEncodeBarcodeParams(contents))
        .toEncode(contents);
