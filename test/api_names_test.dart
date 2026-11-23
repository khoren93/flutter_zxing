// Every public type of the flutter_zxing 4 API, imported together with the
// libraries apps typically import next to it. An ambiguous name is a compile
// error, so this test failing to build means a naming conflict. A second
// test reads the exports of lib/scanner.dart, so a new public type cannot
// skip this list.
// ignore_for_file: unused_import, always_specify_types
@TestOn('vm')
library;

import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
// cupertino.dart and material.dart are deprecated since Flutter 3.47 in favour
// of package:cupertino_ui and package:material_ui, which need Flutter 3.47;
// this package still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/cupertino.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image/image.dart' hide Color, Image;

const List<Type> _types = <Type>[
  // Results
  Barcode, BarcodePosition, BarcodeSequence, BarcodeError, BarcodeErrorKind,
  BarcodeContentType, BarcodeFormat, BarcodeInput,
  // Content
  BarcodeContent, TextContent, BinaryContent, UrlContent, WifiContent,
  WifiSecurity, EmailContent, PhoneContent, SmsContent, GeoContent,
  ContactContent, ContactFormat, EventContent, Gs1Content, ContentIssue,
  ContentIssueKind,
  CallType, OtpContent, OtpType, OtpAlgorithm, EsimContent, CryptoContent,
  CryptoCurrency, WifiDppContent, LinkService, LinkServiceInput,
  ProductContent, BoardingPassContent, BoardingPassLeg, DriverLicenseContent,
  VinContent, VinRegion, SmartHomeContent, SmartHomePlatform,
  PaymentContent, EpcPaymentContent, SwissQrBillContent, SwissAddress,
  SwissReferenceType, GostPaymentContent, UpiPaymentContent,
  EmvPaymentContent, EmvScheme, SpaydPaymentContent,
  // Reading
  BarcodeReader, ReaderOptions, Binarizer, EanAddOn, CharacterSet, PixelBuffer,
  PixelLayout,
  // Writing
  BarcodeWriter, ErrorCorrection, BarcodeImage, BarcodeSymbol, BarcodeView,
  BarcodeContentView,
  BarcodeStyle, ModuleShape, FinderShape, BarcodeLogo, BarcodeCaption,
  BarcodeCard, BarcodeLabelSheet, BarcodeLabelSheetView, PaperSize,
  // Scanning
  BarcodeScanner, ScannerController, ScannerState, ScannerStatus, TorchState,
  CameraFacing, CameraResolution, DetectionMode, BarcodeCapture, ScanWindow,
  ScannerLayout, VisibleBarcode, ScannerOverlay, ScanWindowOverlay,
  BarcodeOutlines, TorchButton, SwitchCameraButton, ScannerOverlayBuilder,
  CaptureSource, AutoZoomState,
  // Scanner screens
  ScannerTemplate, ScannerMode, ScannerPickCallback, ScannerPresentation,
  ScanFieldButton, ScannerResultBuilder, ScannerActionsBuilder, ScannerTheme,
  ScannerButtonShape, ScannerScope, ScannerStrings, ScannerIcon,
  ScannerIconData, ScannerIcons, ScannerGlass, ScannerButton, ScannerHint,
  ScannerSheet, ScannerActionButton, ScannerChip, ScannerCloseButton,
  PickImageButton, ZoomButtons, ScannerAction, ScannerActions, ScannerBadge,
  ScannerFields, BarcodeResultSheet, BarcodeListSheet, CollectedBarcode,
  ScannerPlaceholder, ScannerErrorView, BarcodeThumbnail, ScannerResult,
  ResultHeader, ScannerTone, ScanVerdict, ScanVerdictKind, ScannerCheck,
  // Errors
  ZxingException, ImageDecodeException, BarcodeWriteException,
  EngineException, ScannerException, CameraPermissionException,
  CameraNotFoundException, CameraFailureException, CameraInUseException,
  CameraUnsupportedException,
];

void main() {
  test('the 4.0 API names resolve next to dart:ui, dart:io, material, camera '
      'and image', () {
    expect(_types.toSet(), hasLength(_types.length)); // no duplicates
    expect(zxingCppVersion, isNotEmpty);
    expect(warmUpBarcodeEngine, isA<Function>());
    expect(scanBarcode, isA<Function>());
  });

  test('the list above has every type the 4.0 libraries export', () {
    final Set<String> listed = _listedNames();
    final Set<String> exported = _exportedTypes('lib/scanner.dart');
    expect(
      exported.difference(listed),
      isEmpty,
      reason: 'exported but not in _types',
    );
    expect(
      listed.difference(exported),
      isEmpty,
      reason: 'in _types but not exported',
    );
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

/// The names in [_types], read from this file: a typedef's `Type` prints
/// its function type, not its name.
Set<String> _listedNames() {
  final String source = File('test/api_names_test.dart').readAsStringSync();
  final int start = source.indexOf('_types = <Type>[');
  final String list = source
      .substring(start, source.indexOf('];', start))
      .replaceAll(RegExp(r'//[^\n]*'), '');
  return RegExp(r'\b[A-Z]\w*').allMatches(list).map((Match m) => m[0]!).toSet()
    ..remove('Type');
}

final RegExp _declaration = RegExp(
  r'^(?:(?:abstract|sealed|final|base|interface|mixin)\s+)*'
  r'(?:class|enum|typedef|mixin|extension type)\s+([A-Z]\w*)',
  multiLine: true,
);
final RegExp _part = RegExp(r"^part '([^']+)';", multiLine: true);
final RegExp _export = RegExp(r"^export '([^']+)'([^;]*);", multiLine: true);

/// The public types a library declares and exports, following its
/// `export` directives with their `show` and `hide`, and its parts.
Set<String> _exportedTypes(String path) {
  final String source = File(path).readAsStringSync();
  final String dir = File(path).parent.path;
  Set<String> declared(String text) =>
      _declaration.allMatches(text).map((Match m) => m[1]!).toSet();
  final Set<String> names = declared(source);
  for (final Match part in _part.allMatches(source)) {
    names.addAll(declared(File('$dir/${part[1]}').readAsStringSync()));
  }
  for (final Match export in _export.allMatches(source)) {
    if (export[1]!.startsWith('package:')) {
      continue;
    }
    Set<String> sub = _exportedTypes('$dir/${export[1]}');
    final String combinators = export[2]!;
    Set<String> words(String text) =>
        RegExp(r'\w+').allMatches(text).map((Match m) => m[0]!).toSet();
    final Match? show = RegExp(
      r'\bshow\b(.*?)(?:\bhide\b|$)',
      dotAll: true,
    ).firstMatch(combinators);
    final Match? hide = RegExp(
      r'\bhide\b(.*)',
      dotAll: true,
    ).firstMatch(combinators);
    if (show != null) {
      sub = sub.intersection(words(show[1]!));
    }
    if (hide != null) {
      sub = sub.difference(words(hide[1]!));
    }
    names.addAll(sub);
  }
  return names;
}
