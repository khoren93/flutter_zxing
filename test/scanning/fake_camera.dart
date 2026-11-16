// A camera for tests: frames are pushed by the test, decoding returns the
// barcodes the test put in the frame.
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/engine/engine.dart';
import 'package:flutter_zxing/src/engine/engine_protocol.dart';
import 'package:flutter_zxing/src/scanning/camera/camera_source.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';

/// A QR code with [text] whose corners span [rect] of the delivered frame.
Barcode fakeBarcode(String text, Rect rect) => Barcode(
  format: BarcodeFormat.qrCode,
  text: text,
  bytes: Uint8List(0),
  position: BarcodePosition(
    topLeft: rect.topLeft,
    topRight: rect.topRight,
    bottomRight: rect.bottomRight,
    bottomLeft: rect.bottomLeft,
  ),
);

/// A frame holding [barcodes] (positions in the delivered frame).
final class FakeFrame extends CameraFrame {
  FakeFrame(
    this.transform, [
    this.barcodes = const <Barcode>[],
    this.error,
    this.hang = false,
    this.pixels,
  ]);

  @override
  final FrameTransform transform;
  final List<Barcode> barcodes;

  /// Thrown by [read] instead of decoding.
  final Exception? error;

  /// Whether [read] never completes, like a stuck engine.
  final bool hang;

  /// The crop the controller asked for.
  Rect? crop;

  /// The options the controller decoded with.
  EngineReadOptions? options;

  @override
  final int arrivalMicros = cameraClock.elapsedMicroseconds;

  @override
  int get dropped => 0;

  /// The frame's pixels, for cut-outs; none by default.
  @override
  final PixelBuffer? pixels;

  @override
  bool get mirrored => false;
  bool wasRead = false;

  @override
  Future<EngineReadResult> read(
    BarcodeEngine engine,
    Rect? crop,
    EngineReadOptions options,
  ) async {
    this.crop = crop;
    this.options = options;
    wasRead = true;
    if (hang) {
      return Completer<EngineReadResult>().future;
    }
    if (error != null) {
      throw error!;
    }
    return EngineReadResult(
      barcodes: barcodes,
      imageWidth: transform.frameSize.width.round(),
      imageHeight: transform.frameSize.height.round(),
    );
  }
}

/// A camera whose frames come from [push].
final class FakeCamera implements CameraSource {
  FakeCamera({
    this.transform = const FrameTransform(Size(640, 480), rotation: 90),
    this.capabilities = const CameraCapabilities(hasTorch: true, maxZoom: 4),
    this.preview,
  });

  /// What the preview shows; a blue box by default.
  final Widget? preview;

  /// How frames and the preview are shown.
  FrameTransform transform;
  CameraCapabilities capabilities;

  /// Thrown by the next [open].
  ScannerException? openError;

  /// Thrown by [setTorch].
  Exception? torchError;

  final List<CameraFacing> opened = <CameraFacing>[];

  /// Whether the preview is known only from the first frame, as on iOS.
  bool previewOnFirstFrame = false;

  /// For each [open]: the lens asked for.
  final List<CameraLens> lenses = <CameraLens>[];
  int closed = 0;
  bool? torch;
  double? zoom;
  Offset? focus;
  bool get isOpen => _open;

  bool _open = false;
  final Queue<FakeFrame> _frames = Queue<FakeFrame>();
  Completer<void>? _waiter;
  final ValueNotifier<FrameTransform?> _preview =
      ValueNotifier<FrameTransform?>(null);
  Orientation _shape = Orientation.portrait;

  /// Delivers a frame with [barcodes] and returns it.
  FakeFrame push([
    List<Barcode> barcodes = const <Barcode>[],
    Exception? error,
    bool hang = false,
    PixelBuffer? pixels,
  ]) {
    if (_open && _preview.value == null) {
      _preview.value = transform;
    }
    final FakeFrame frame = FakeFrame(transform, barcodes, error, hang, pixels);
    _frames.add(frame);
    final Completer<void>? waiter = _waiter;
    _waiter = null;
    waiter?.complete();
    return frame;
  }

  @override
  Future<CameraCapabilities> open(
    CameraFacing facing,
    CameraResolution resolution, {
    CameraLens lens = CameraLens.main,
  }) async {
    opened.add(facing);
    lenses.add(lens);
    final ScannerException? error = openError;
    if (error != null) {
      openError = null;
      throw error;
    }
    _open = true;
    if (!previewOnFirstFrame) {
      _preview.value = transform;
    }
    return capabilities;
  }

  @override
  Future<void> close() async {
    closed++;
    _open = false;
    _frames.clear();
    _preview.value = null;
    final Completer<void>? waiter = _waiter;
    _waiter = null;
    waiter?.complete();
  }

  @override
  Future<CameraFrame?> nextFrame() async {
    while (_open) {
      if (_frames.isNotEmpty) {
        return _frames.removeFirst();
      }
      await (_waiter ??= Completer<void>()).future;
    }
    return null;
  }

  @override
  ValueListenable<FrameTransform?> get previewTransform => _preview;

  @override
  Orientation get uiShape => _shape;

  @override
  set uiShape(Orientation value) => _shape = value;

  /// How many times the preview was built.
  int previewBuilds = 0;

  /// Changes how frames and the preview are shown, as the camera does when
  /// the device turns.
  void turn(FrameTransform value) {
    transform = value;
    if (_open) {
      _preview.value = value;
    }
  }

  @override
  Widget buildPreview() =>
      (previewBuilds++, preview).$2 ??
      const ColoredBox(
        key: ValueKey<String>('fake preview'),
        color: Color(0xFF336699),
      );

  @override
  Future<void> setTorch(bool on) async {
    if (torchError != null) {
      throw torchError!;
    }
    torch = on;
  }

  @override
  Future<void> setZoom(double zoom) async => this.zoom = zoom;

  @override
  Future<void> setFocusPoint(Offset point) async => focus = point;

  /// The lens position [lensFocus] reports; `null` like a camera that does
  /// not say.
  double? lens;

  @override
  LensFocus? lensFocus() {
    final double? position = lens;
    return position == null ? null : LensFocus(position);
  }
}
