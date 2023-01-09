import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imglib;

import '../../generated_bindings.dart';
import '../models/models.dart';
import '../utils/extentions.dart';
// import '../utils/image_converter.dart';
import '../utils/image_converter.dart';
import '../utils/isolate_utils.dart';

part 'barcode_encoder.dart';
part 'barcode_reader.dart';
part 'barcodes_reader.dart';
part 'bindings.dart';
part 'camera_stream.dart';

/// Returns a version of the zxing library
String zxingVersion() => bindings.version().cast<Utf8>().toDartString();

/// Enables or disables the logging of the library
void setZxingLogEnabled(bool enabled) =>
    bindings.setLogEnabled(enabled ? 1 : 0);

/// Returns a readable barcode format name
String zxingBarcodeFormatName(int format) => barcodeNames[format] ?? 'Unknown';

extension Uint8ListBlobConversion on Uint8List {
  /// Allocates a pointer filled with the Uint8List data.
  Pointer<Char> allocatePointer() {
    final Pointer<Int8> blob = calloc<Int8>(length);
    final Int8List blobBytes = blob.asTypedList(length);
    blobBytes.setAll(0, this);
    return blob.cast<Char>();
  }
}
