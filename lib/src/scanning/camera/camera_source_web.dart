// The camera on the web: getUserMedia into a <video> element shown through a
// platform view. Each frame is grabbed with createImageBitmap, cropped to the
// scan window by the browser (off the Dart heap), and transferred to the
// engine's worker.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../../barcode/barcode.dart';
import '../../engine/engine.dart';
import '../../engine/engine_protocol.dart';
import '../../engine/engine_web.dart';
import '../../errors.dart';
import '../../reading/pixel_buffer.dart';
import '../frame_geometry.dart';
import '../scanner_controller.dart';
import 'camera_source.dart';

/// The camera of this platform.
CameraSource createCameraSource() => WebCameraSource();

/// A camera through getUserMedia.
final class WebCameraSource implements CameraSource {
  /// Creates the source and its `<video>` element.
  WebCameraSource() {
    _video = web.document.createElement('video') as web.HTMLVideoElement
      ..autoplay = true
      ..muted = true
      ..playsInline = true;
    _video.style
      ..width = '100%'
      ..height = '100%'
      // The widget lays the element out at the video's own aspect ratio.
      ..objectFit = 'fill'
      ..pointerEvents = 'none';
    _viewType = 'flutter-zxing-camera-${_nextView++}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _video,
    );
    _video.addEventListener('resize', ((web.Event _) => _updatePreview()).toJS);
  }

  static int _nextView = 0;

  late final web.HTMLVideoElement _video;
  late final String _viewType;
  web.MediaStream? _stream;
  bool _front = false;
  Orientation _uiShape = Orientation.portrait;
  final ValueNotifier<FrameTransform?> _preview =
      ValueNotifier<FrameTransform?>(null);

  web.MediaStreamTrack? get _track =>
      _stream?.getVideoTracks().toDart.firstOrNull;

  @override
  ValueListenable<FrameTransform?> get previewTransform => _preview;

  @override
  Orientation get uiShape => _uiShape;

  // The browser turns the video with the device itself.
  @override
  set uiShape(Orientation value) => _uiShape = value;

  @override
  Future<CameraCapabilities> open(
    CameraFacing facing,
    CameraResolution resolution,
  ) async {
    final (int width, int height) = switch (resolution) {
      CameraResolution.sd => (640, 480),
      CameraResolution.hd => (1280, 720),
      CameraResolution.fullHd => (1920, 1080),
    };
    final web.MediaDevices? devices = web.window.navigator.has('mediaDevices')
        ? web.window.navigator.mediaDevices
        : null;
    if (devices == null) {
      // Plain http (not localhost) has no camera access at all.
      throw const CameraNotFoundException(
        'The browser offers no camera here (the page must be served over '
        'https or from localhost)',
      );
    }
    final web.MediaStream stream;
    try {
      stream = await devices
          .getUserMedia(
            web.MediaStreamConstraints(
              audio: false.toJS,
              video: <String, Object>{
                'facingMode': facing == CameraFacing.back
                    ? 'environment'
                    : 'user',
                'width': <String, int>{'ideal': width},
                'height': <String, int>{'ideal': height},
              }.jsify()!,
            ),
          )
          .toDart;
    } on Object catch (e) {
      throw cameraError(_errorName(e), '$e');
    }
    _stream = stream;
    _front = facing == CameraFacing.front;
    _video.style.transform = _front ? 'scaleX(-1)' : '';
    _video.srcObject = stream;
    try {
      await _video.play().toDart;
    } on Object catch (e) {
      await close();
      throw cameraError(_errorName(e), '$e');
    }
    while (_video.videoWidth == 0 && _stream != null) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    _updatePreview();
    return _capabilities();
  }

  /// The DOMException name of a camera failure (NotAllowedError,
  /// NotFoundError, NotReadableError...): what a DOMException prints,
  /// "name: message", in both dart2js and dart2wasm.
  static String _errorName(Object error) {
    final String text = '$error';
    return RegExp(r'([A-Za-z]+Error)').firstMatch(text)?.group(1) ?? text;
  }

  CameraCapabilities _capabilities() {
    final web.MediaStreamTrack? track = _track;
    if (track == null || !track.has('getCapabilities')) {
      return const CameraCapabilities();
    }
    final JSObject caps = track.getCapabilities();
    double minZoom = 1;
    double maxZoom = 1;
    final JSAny? zoom = caps.getProperty('zoom'.toJS);
    if (zoom != null && zoom.isA<JSObject>()) {
      final JSAny? min = (zoom as JSObject).getProperty('min'.toJS);
      final JSAny? max = zoom.getProperty('max'.toJS);
      if (min != null && min.isA<JSNumber>()) {
        minZoom = (min as JSNumber).toDartDouble;
      }
      if (max != null && max.isA<JSNumber>()) {
        maxZoom = (max as JSNumber).toDartDouble;
      }
    }
    return CameraCapabilities(
      hasTorch: caps.has('torch'),
      minZoom: minZoom,
      maxZoom: maxZoom < minZoom ? minZoom : maxZoom,
    );
  }

  void _updatePreview() {
    _preview.value = _stream == null || _video.videoWidth == 0
        ? null
        : FrameTransform(
            Size(_video.videoWidth.toDouble(), _video.videoHeight.toDouble()),
            mirrored: _front,
          );
  }

  @override
  Future<void> close() async {
    for (final web.MediaStreamTrack track
        in _stream?.getTracks().toDart ?? const <web.MediaStreamTrack>[]) {
      track.stop();
    }
    _stream = null;
    _video.srcObject = null;
    _preview.value = null;
  }

  /// Resolves on the next frame the video presents:
  /// requestVideoFrameCallback where the browser has it (never the same
  /// frame twice), animation frames otherwise.
  Future<void> _nextVideoFrame() {
    final Completer<void> presented = Completer<void>();
    if (_video.has('requestVideoFrameCallback')) {
      _video.callMethod(
        'requestVideoFrameCallback'.toJS,
        ((JSAny? _, JSAny? _) => presented.complete()).toJS,
      );
    } else {
      web.window.requestAnimationFrame(
        ((JSNumber _) => presented.complete()).toJS,
      );
    }
    return presented.future;
  }

  @override
  Future<CameraFrame?> nextFrame() async {
    if (_stream == null) {
      return null;
    }
    await _nextVideoFrame();
    final int arrivalMicros = cameraClock.elapsedMicroseconds;
    final FrameTransform? transform = _preview.value;
    if (_stream == null || transform == null) {
      return null;
    }
    return _WebFrame(_video, transform, arrivalMicros);
  }

  @override
  Widget buildPreview() => HtmlElementView(viewType: _viewType);

  Future<void> _constrain(String name, JSAny value) async {
    final web.MediaStreamTrack? track = _track;
    if (track == null) {
      return;
    }
    final JSObject constraint = JSObject()..setProperty(name.toJS, value);
    await track
        .applyConstraints(
          web.MediaTrackConstraints()
            ..setProperty('advanced'.toJS, <JSObject>[constraint].toJS),
        )
        .toDart;
  }

  @override
  Future<void> setTorch(bool on) async {
    try {
      await _constrain('torch', on.toJS);
    } on Object catch (e) {
      throw cameraError(_errorName(e), '$e');
    }
  }

  @override
  Future<void> setZoom(double zoom) async {
    try {
      await _constrain('zoom', zoom.toJS);
    } on Object {
      // The camera rejected the value: keep the current zoom.
    }
  }

  // Browsers barely support points of interest; the camera keeps focusing
  // continuously on its own.
  @override
  Future<void> setFocusPoint(Offset point) async {}
}

final class _WebFrame implements CameraFrame {
  _WebFrame(this._video, this.transform, this.arrivalMicros);

  @override
  final int arrivalMicros;

  // The video element shows the newest frame; skipped ones are not counted.
  @override
  int get dropped => 0;

  final web.HTMLVideoElement _video;

  @override
  final FrameTransform transform;

  @override
  PixelBuffer? get pixels => null;

  @override
  Future<EngineReadResult> read(
    BarcodeEngine engine,
    Rect? crop,
    EngineReadOptions options,
  ) async {
    final Size size = transform.frameSize;
    final Rect area = crop ?? Offset.zero & size;
    final web.ImageBitmap bitmap = await web.window
        .createImageBitmap(
          _video,
          area.left.toInt().toJS,
          area.top.toInt(),
          area.width.toInt(),
          area.height.toInt(),
        )
        .toDart;
    final EngineBackend backend = await engine.backend;
    final EngineReadResult result = await (backend as WebBackend).readBitmap(
      bitmap,
      options,
    );
    return EngineReadResult(
      barcodes: <Barcode>[
        for (final Barcode b in result.barcodes)
          mapBarcodePosition(b, (Offset p) => p + area.topLeft),
      ],
      imageWidth: size.width.round(),
      imageHeight: size.height.round(),
      engineMicros: result.engineMicros,
    );
  }
}
