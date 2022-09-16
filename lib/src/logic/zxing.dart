import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imglib;

import '../../generated_bindings.dart';
import '../utils/extentions.dart';
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
String barcodeFormatName(int format) => formatNames[format] ?? 'Unknown';
