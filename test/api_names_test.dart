// Every public name of the flutter_zxing 4 API, imported together with the
// libraries apps typically import next to it. An ambiguous name is a compile
// error, so this test failing to build means a naming conflict.
// ignore_for_file: unused_import, always_specify_types

import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; this package still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image/image.dart' hide Color, Image;

const List<Type> _types = <Type>[
  // Results
  Barcode, BarcodePosition, BarcodeSequence, BarcodeError, BarcodeErrorKind,
  BarcodeContentType, BarcodeFormat,
  // Content
  BarcodeContent, TextContent, BinaryContent, UrlContent, WifiContent,
  WifiSecurity, EmailContent, PhoneContent, SmsContent, GeoContent,
  ContactContent, EventContent, Gs1Content,
  // Reading
  BarcodeReader, ReaderOptions, Binarizer, PixelBuffer, PixelLayout,
  // Writing
  BarcodeWriter, ErrorCorrection, BarcodeImage, BarcodeSymbol, BarcodeView,
  BarcodeStyle, ModuleShape, FinderShape, BarcodeLogo,
  // Scanning
  BarcodeScanner, ScannerController, ScannerState, ScannerStatus, TorchState,
  CameraFacing, CameraResolution, DetectionMode, BarcodeCapture, ScanWindow,
  ScannerLayout, VisibleBarcode, ScannerOverlay, ScanWindowOverlay,
  BarcodeOutlines, TorchButton, SwitchCameraButton, ScannerOverlayBuilder,
  // Errors
  ZxingException, ImageDecodeException, BarcodeWriteException,
  EngineException, ScannerException, CameraPermissionException,
  CameraNotFoundException, CameraFailureException,
];

void main() {
  test('the 4.0 API names resolve next to dart:ui, dart:io, material, camera '
      'and image', () {
    expect(_types.toSet(), hasLength(_types.length)); // no duplicates
    expect(zxingCppVersion, isNotEmpty);
    expect(warmUpBarcodeEngine, isA<Function>());
    expect(scanBarcode, isA<Function>());
  });

  test('the 3.x API is still exported', () {
    // 3.x `Format` is left out: it clashes with `Format` from package:image,
    // a known 3.x problem that 4.0 avoids with `BarcodeFormat`.
    expect(<Type>[
      Code,
      Codes,
      DecodeParams,
      EncodeParams,
      ReaderWidget,
      WriterWidget,
    ], hasLength(6));
    expect(zx, isNotNull);
  });
}
