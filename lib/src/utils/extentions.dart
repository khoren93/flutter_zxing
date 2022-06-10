import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../flutter_zxing.dart';

extension Uint8ListBlobConversion on Uint8List {
  /// Allocates a pointer filled with the Uint8List data.
  Pointer<Char> allocatePointer() {
    final Pointer<Int8> blob = calloc<Int8>(length);
    final Int8List blobBytes = blob.asTypedList(length);
    blobBytes.setAll(0, this);
    return blob.cast<Char>();
  }
}

extension CodeExt on CodeResult {
  bool get isValidBool => isValid == 1;
  String? get textString =>
      text == nullptr ? null : text.cast<Utf8>().toDartString();
  String get formatString => barcodeFormatName(format);
}

extension EncodeExt on EncodeResult {
  bool get isValidBool => isValid == 1;
  String? get textString =>
      text == nullptr ? null : text.cast<Utf8>().toDartString();
  String get formatString => barcodeFormatName(format);
  Uint32List get bytes => data.cast<Uint32>().asTypedList(length);
  String get errorMessage => error.cast<Utf8>().toDartString();
}

extension CodeFormat on Format {
  String get name => formatNames[this] ?? 'Unknown';

  static final List<int> writerFormats = <int>[
    Format.QRCode,
    Format.DataMatrix,
    Format.Aztec,
    Format.PDF417,
    Format.Codabar,
    Format.Code39,
    Format.Code93,
    Format.Code128,
    Format.EAN8,
    Format.EAN13,
    Format.ITF,
    Format.UPCA,
    Format.UPCE,
    // Format.DataBar,
    // Format.DataBarExpanded,
    // Format.MaxiCode,
  ];
}

final Map<int, String> formatNames = <int, String>{
  Format.None: 'None',
  Format.Aztec: 'Aztec',
  Format.Codabar: 'CodaBar',
  Format.Code39: 'Code39',
  Format.Code93: 'Code93',
  Format.Code128: 'Code128',
  Format.DataBar: 'DataBar',
  Format.DataBarExpanded: 'DataBarExpanded',
  Format.DataMatrix: 'DataMatrix',
  Format.EAN8: 'EAN8',
  Format.EAN13: 'EAN13',
  Format.ITF: 'ITF',
  Format.MaxiCode: 'MaxiCode',
  Format.PDF417: 'PDF417',
  Format.QRCode: 'QR Code',
  Format.UPCA: 'UPCA',
  Format.UPCE: 'UPCE',
  Format.OneDCodes: 'OneD',
  Format.TwoDCodes: 'TwoD',
  Format.Any: 'Any',
};
