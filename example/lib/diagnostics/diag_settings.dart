// Everything the diagnostics page can change, as one value: it is applied to
// the scanner, compared in A/B runs and saved with every run.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
// Engine settings outside the public API.
// ignore: implementation_imports
import 'package:flutter_zxing/src/engine/engine_protocol.dart'
    show EngineReadOptions, fzxDownscaleFlags;
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;

/// The formats to look for.
enum DiagFormats {
  all('All', null),
  qr('QR', <BarcodeFormat>{BarcodeFormat.qrCode}),
  matrix('2D', BarcodeFormat.matrix),
  linear('Linear', BarcodeFormat.linear),
  retail('Retail', BarcodeFormat.retail),
  industrial('Industrial', BarcodeFormat.industrial);

  const DiagFormats(this.label, this.formats);

  final String label;
  final Set<BarcodeFormat>? formats;
}

/// The part of the preview that is decoded.
enum DiagWindow {
  square('Square 70%', ScanWindow.centered()),
  wide('Wide 90%', ScanWindow.centered(width: 0.9, aspectRatio: 3)),
  full('Full frame', ScanWindow.full());

  const DiagWindow(this.label, this.window);

  final String label;
  final ScanWindow window;
}

/// The settings of one run.
@immutable
final class DiagSettings {
  /// The scanner's defaults.
  const DiagSettings({
    this.tryHarder = true,
    this.tryRotate = true,
    this.tryInvert = false,
    this.tryDownscale = true,
    this.tryDenoise = false,
    this.isPure = false,
    this.returnErrors = false,
    this.validateChecksum = false,
    this.binarizer = Binarizer.localAverage,
    this.minLineCount = 2,
    this.eanAddOn = EanAddOn.ignore,
    this.characterSet = '',
    this.downscaleFactor = 0,
    this.downscaleThreshold = 0,
    this.formats = DiagFormats.all,
    this.resolution = CameraResolution.hd,
    this.autoZoom = true,
    this.window = DiagWindow.square,
    this.maxBarcodes = 1,
    this.readIntervalMs = 0,
    this.detection = DetectionMode.distinct,
    this.blur = true,
  });

  final bool tryHarder;
  final bool tryRotate;
  final bool tryInvert;
  final bool tryDownscale;
  final bool tryDenoise;
  final bool isPure;
  final bool returnErrors;
  final bool validateChecksum;
  final Binarizer binarizer;
  final int minLineCount;
  final EanAddOn eanAddOn;

  /// A [CharacterSet] name; '' lets the engine guess.
  final String characterSet;

  /// 2, 3 or 4; 0 is zxing-cpp's default.
  final int downscaleFactor;

  /// In pixels; 0 is zxing-cpp's default.
  final int downscaleThreshold;
  final DiagFormats formats;
  final CameraResolution resolution;
  final bool autoZoom;
  final DiagWindow window;

  /// 0 looks for all barcodes in the frame.
  final int maxBarcodes;

  /// The shortest time between two reads; 0 reads every frame.
  final int readIntervalMs;
  final DetectionMode detection;

  /// Whether the scanner's glass blurs the camera.
  final bool blur;

  /// The reader settings of these settings.
  ReaderOptions get readerOptions => ReaderOptions(
    tryHarder: tryHarder,
    tryRotate: tryRotate,
    tryInvert: tryInvert,
    tryDownscale: tryDownscale,
    tryDenoise: tryDenoise,
    isPure: isPure,
    returnErrors: returnErrors,
    validateOptionalChecksum: validateChecksum,
    binarizer: binarizer,
    minLineCount: minLineCount,
    eanAddOn: eanAddOn,
    characterSet: CharacterSet.values
        .where((CharacterSet c) => c.name == characterSet)
        .firstOrNull,
  );

  /// The engine flags outside [ReaderOptions].
  int get engineFlags => fzxDownscaleFlags(
    factor: downscaleFactor == 0 ? null : downscaleFactor,
    threshold: downscaleThreshold == 0 ? null : downscaleThreshold,
  );

  /// The options the scanner reads a frame with.
  EngineReadOptions get engineOptions => EngineReadOptions.from(
    formats.formats,
    readerOptions,
    maxSymbols: maxBarcodes,
  ).withFlags(engineFlags);

  /// Applies everything but [resolution], which needs a new camera.
  void applyTo(ScannerController controller) {
    controller
      ..options = readerOptions
      ..engineFlags = engineFlags
      ..formats = formats.formats
      ..scanWindow = window.window
      ..maxBarcodes = maxBarcodes == 0 ? null : maxBarcodes
      ..detection = detection
      ..readInterval = readIntervalMs == 0
          ? null
          : Duration(milliseconds: readIntervalMs);
    unawaited(controller.setAutoZoom(autoZoom));
  }

  /// Creates a copy with the given fields replaced.
  DiagSettings copyWith({
    bool? tryHarder,
    bool? tryRotate,
    bool? tryInvert,
    bool? tryDownscale,
    bool? tryDenoise,
    bool? isPure,
    bool? returnErrors,
    bool? validateChecksum,
    Binarizer? binarizer,
    int? minLineCount,
    EanAddOn? eanAddOn,
    String? characterSet,
    int? downscaleFactor,
    int? downscaleThreshold,
    DiagFormats? formats,
    CameraResolution? resolution,
    bool? autoZoom,
    DiagWindow? window,
    int? maxBarcodes,
    int? readIntervalMs,
    DetectionMode? detection,
    bool? blur,
  }) => DiagSettings(
    tryHarder: tryHarder ?? this.tryHarder,
    tryRotate: tryRotate ?? this.tryRotate,
    tryInvert: tryInvert ?? this.tryInvert,
    tryDownscale: tryDownscale ?? this.tryDownscale,
    tryDenoise: tryDenoise ?? this.tryDenoise,
    isPure: isPure ?? this.isPure,
    returnErrors: returnErrors ?? this.returnErrors,
    validateChecksum: validateChecksum ?? this.validateChecksum,
    binarizer: binarizer ?? this.binarizer,
    minLineCount: minLineCount ?? this.minLineCount,
    eanAddOn: eanAddOn ?? this.eanAddOn,
    characterSet: characterSet ?? this.characterSet,
    downscaleFactor: downscaleFactor ?? this.downscaleFactor,
    downscaleThreshold: downscaleThreshold ?? this.downscaleThreshold,
    formats: formats ?? this.formats,
    resolution: resolution ?? this.resolution,
    autoZoom: autoZoom ?? this.autoZoom,
    window: window ?? this.window,
    maxBarcodes: maxBarcodes ?? this.maxBarcodes,
    readIntervalMs: readIntervalMs ?? this.readIntervalMs,
    detection: detection ?? this.detection,
    blur: blur ?? this.blur,
  );

  /// Settings saved by [toJson]; what is missing keeps its default.
  factory DiagSettings.fromJson(Map<String, Object?> json) {
    const DiagSettings d = DiagSettings();
    bool flag(String key, bool or) => json[key] as bool? ?? or;
    int number(String key, int or) => json[key] as int? ?? or;
    T choice<T extends Enum>(String key, List<T> values, T or) =>
        values.where((T v) => v.name == json[key]).firstOrNull ?? or;
    return DiagSettings(
      tryHarder: flag('tryHarder', d.tryHarder),
      tryRotate: flag('tryRotate', d.tryRotate),
      tryInvert: flag('tryInvert', d.tryInvert),
      tryDownscale: flag('tryDownscale', d.tryDownscale),
      tryDenoise: flag('tryDenoise', d.tryDenoise),
      isPure: flag('isPure', d.isPure),
      returnErrors: flag('returnErrors', d.returnErrors),
      validateChecksum: flag('validateChecksum', d.validateChecksum),
      binarizer: choice('binarizer', Binarizer.values, d.binarizer),
      minLineCount: number('minLineCount', d.minLineCount),
      eanAddOn: choice('eanAddOn', EanAddOn.values, d.eanAddOn),
      characterSet: json['characterSet'] as String? ?? d.characterSet,
      downscaleFactor: number('downscaleFactor', d.downscaleFactor),
      downscaleThreshold: number('downscaleThreshold', d.downscaleThreshold),
      formats: choice('formats', DiagFormats.values, d.formats),
      resolution: choice('resolution', CameraResolution.values, d.resolution),
      autoZoom: flag('autoZoom', d.autoZoom),
      window: choice('window', DiagWindow.values, d.window),
      maxBarcodes: number('maxBarcodes', d.maxBarcodes),
      readIntervalMs: number('readIntervalMs', d.readIntervalMs),
      detection: choice('detection', DetectionMode.values, d.detection),
      blur: flag('blur', d.blur),
    );
  }

  /// The settings of a saved run.
  Map<String, Object> toJson() => <String, Object>{
    'tryHarder': tryHarder,
    'tryRotate': tryRotate,
    'tryInvert': tryInvert,
    'tryDownscale': tryDownscale,
    'tryDenoise': tryDenoise,
    'isPure': isPure,
    'returnErrors': returnErrors,
    'validateChecksum': validateChecksum,
    'binarizer': binarizer.name,
    'minLineCount': minLineCount,
    'eanAddOn': eanAddOn.name,
    'characterSet': characterSet,
    'downscaleFactor': downscaleFactor,
    'downscaleThreshold': downscaleThreshold,
    'formats': formats.name,
    'resolution': resolution.name,
    'autoZoom': autoZoom,
    'window': window.name,
    'maxBarcodes': maxBarcodes,
    'readIntervalMs': readIntervalMs,
    'detection': detection.name,
    'blur': blur,
  };
}
