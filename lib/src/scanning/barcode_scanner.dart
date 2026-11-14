part of 'scanner_controller.dart';

/// Builds what is drawn over the camera preview.
typedef ScannerOverlayBuilder =
    Widget Function(BuildContext context, ScannerLayout layout);

/// A camera preview that scans barcodes.
///
/// ```dart
/// BarcodeScanner(onDetect: (capture) => print(capture.barcode.text))
/// ```
///
/// Without a [controller] it creates one with default settings and disposes
/// it with the widget. Pass your own to configure formats, the scan window
/// or detection, and to control the camera.
///
/// By default it draws a dimmed scan window and outlines found barcodes;
/// replace that with [overlayBuilder]. Tap to focus and pinch to zoom are on.
class BarcodeScanner extends StatefulWidget {
  /// Creates a scanner.
  const BarcodeScanner({
    super.key,
    this.controller,
    this.onDetect,
    this.overlayBuilder,
    this.errorBuilder,
    this.placeholderBuilder,
    this.fit = BoxFit.cover,
    this.tapToFocus = true,
    this.pinchToZoom = true,
  });

  /// The controller; one with default settings is created if `null`.
  final ScannerController? controller;

  /// Called for every capture the controller reports.
  final ValueChanged<BarcodeCapture>? onDetect;

  /// Builds the overlay. `null` uses [ScannerOverlay]; return
  /// `const SizedBox.shrink()` for none.
  final ScannerOverlayBuilder? overlayBuilder;

  /// Shown instead of the preview when the camera cannot be used. The
  /// default shows a short message.
  final Widget Function(BuildContext context, ScannerException error)?
  errorBuilder;

  /// Shown while the camera is starting. The default is an empty box with
  /// the background color.
  final WidgetBuilder? placeholderBuilder;

  /// How the preview fills the widget. With [BoxFit.cover] (the default)
  /// the edges of the camera image may be cut off; the scan window and
  /// barcode outlines always match what is visible.
  final BoxFit fit;

  /// Focus where the user taps.
  final bool tapToFocus;

  /// Zoom with a pinch gesture.
  final bool pinchToZoom;

  @override
  State<BarcodeScanner> createState() => _BarcodeScannerState();
}

class _BarcodeScannerState extends State<BarcodeScanner> {
  ScannerController? _own;
  StreamSubscription<BarcodeCapture>? _detections;
  double _zoomAtPinchStart = 1;

  ScannerController get _controller =>
      widget.controller ?? (_own ??= ScannerController());

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(BarcodeScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ScannerController? old = oldWidget.controller ?? _own;
    if (widget.controller != oldWidget.controller) {
      _disconnect(old!);
      if (oldWidget.controller == null) {
        _own?.dispose();
        _own = null;
      }
      _connect();
    }
  }

  @override
  void dispose() {
    _disconnect(_controller);
    _own?.dispose();
    super.dispose();
  }

  void _connect() {
    final ScannerController controller = _controller;
    _detections = controller.barcodes.listen(
      (BarcodeCapture capture) => widget.onDetect?.call(capture),
    );
    controller._attach();
  }

  void _disconnect(ScannerController controller) {
    unawaited(_detections?.cancel());
    _detections = null;
    controller._detach();
  }

  @override
  Widget build(BuildContext context) {
    final ScannerController controller = _controller;
    final Orientation shape = MediaQuery.orientationOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        controller._layout(size, widget.fit);
        // Telling the camera about the UI's shape can turn the preview,
        // which rebuilds this widget: not while it is being built.
        if (controller._source?.uiShape != shape) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => controller._source?.uiShape = shape,
          );
        }
        return ValueListenableBuilder<ScannerState>(
          valueListenable: controller,
          builder: (BuildContext context, ScannerState state, Widget? _) =>
              _buildState(context, controller, state, size),
        );
      },
    );
  }

  Widget _buildState(
    BuildContext context,
    ScannerController controller,
    ScannerState state,
    Size size,
  ) {
    final ScannerException? error = state.error;
    if (state.status == ScannerStatus.error && error != null) {
      return widget.errorBuilder?.call(context, error) ?? _ScannerError(error);
    }
    final CameraSource? source = controller._source;
    final FrameTransform? preview = source?.previewTransform.value;
    if (source == null || preview == null || !state.status.hasCamera) {
      return widget.placeholderBuilder?.call(context) ??
          const SizedBox.expand();
    }
    final PreviewFit fit = PreviewFit(preview.displaySize, size, widget.fit);
    Widget scanner = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox.fromSize(
            size: preview.displaySize,
            child: source.buildPreview(),
          ),
        ),
        ValueListenableBuilder<_Visible?>(
          valueListenable: controller._visible,
          builder: (BuildContext context, _Visible? visible, Widget? _) {
            final ScannerLayout layout = _layoutOf(
              controller,
              state,
              size,
              fit,
              preview,
              visible,
            );
            return widget.overlayBuilder?.call(context, layout) ??
                ScannerOverlay(layout);
          },
        ),
      ],
    );
    if (widget.tapToFocus || widget.pinchToZoom) {
      scanner = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: widget.tapToFocus
            ? (TapUpDetails details) {
                final Offset p = fit.toFrame(details.localPosition);
                unawaited(
                  controller.setFocusPoint(
                    Offset(
                      p.dx / preview.displaySize.width,
                      p.dy / preview.displaySize.height,
                    ),
                  ),
                );
              }
            : null,
        onScaleStart: widget.pinchToZoom
            ? (ScaleStartDetails _) => _zoomAtPinchStart = state.zoom
            : null,
        onScaleUpdate: widget.pinchToZoom
            ? (ScaleUpdateDetails details) {
                if (details.pointerCount > 1) {
                  unawaited(
                    controller.setZoom(_zoomAtPinchStart * details.scale),
                  );
                }
              }
            : null,
        child: scanner,
      );
    }
    return scanner;
  }

  /// The overlay's view of the controller: everything in widget pixels.
  static ScannerLayout _layoutOf(
    ScannerController controller,
    ScannerState state,
    Size size,
    PreviewFit fit,
    FrameTransform preview,
    _Visible? visible,
  ) {
    final List<VisibleBarcode> barcodes = <VisibleBarcode>[];
    if (visible != null) {
      // Frames may come in another size than the preview: scale first.
      final double sx = preview.displaySize.width / visible.frameSize.width;
      final double sy = preview.displaySize.height / visible.frameSize.height;
      for (final Barcode barcode in visible.barcodes) {
        barcodes.add(
          VisibleBarcode(barcode, <Offset>[
            for (final Offset c in barcode.position.corners)
              fit.toView(Offset(c.dx * sx, c.dy * sy)),
          ]),
        );
      }
    }
    return ScannerLayout(
      size: size,
      scanWindow: controller.scanWindow.resolve(size),
      barcodes: barcodes,
      state: state,
      controller: controller,
    );
  }
}

/// The default error view: a short message on a dark background.
class _ScannerError extends StatelessWidget {
  const _ScannerError(this.error);

  final ScannerException error;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF000000),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          switch (error) {
            CameraPermissionException() => 'Camera access is needed to scan.',
            CameraNotFoundException() => 'No camera found.',
            CameraFailureException() => 'The camera is not available.',
          },
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFFFFFFF)),
        ),
      ),
    ),
  );
}

/// What an overlay needs to know, already in the coordinates of the
/// `BarcodeScanner` widget.
@immutable
final class ScannerLayout {
  /// Creates a layout.
  const ScannerLayout({
    required this.size,
    required this.scanWindow,
    required this.barcodes,
    required this.state,
    required this.controller,
  });

  /// Size of the scanner widget.
  final Size size;

  /// The scan window.
  final Rect scanWindow;

  /// Barcodes of the latest capture that are still in view.
  final List<VisibleBarcode> barcodes;

  /// Camera state (torch, zoom, status).
  final ScannerState state;

  /// The controller, for buttons in the overlay.
  final ScannerController controller;
}

/// A barcode of the latest capture, positioned in the scanner widget.
@immutable
final class VisibleBarcode {
  /// Creates a visible barcode.
  const VisibleBarcode(this.barcode, this.corners);

  /// The barcode.
  final Barcode barcode;

  /// Its corners in widget coordinates (top-left, top-right, bottom-right,
  /// bottom-left of the symbol).
  final List<Offset> corners;

  /// The smallest rectangle containing [corners].
  Rect get bounds => BarcodePosition(
    topLeft: corners[0],
    topRight: corners[1],
    bottomRight: corners[2],
    bottomLeft: corners[3],
  ).bounds;
}

/// The default overlay: a dimmed [ScanWindowOverlay] and [BarcodeOutlines].
///
/// Customise it in an [ScannerOverlayBuilder]:
/// ```dart
/// overlayBuilder: (context, layout) => ScannerOverlay(layout, borderColor: Colors.amber)
/// ```
class ScannerOverlay extends StatelessWidget {
  /// Creates the default overlay.
  const ScannerOverlay(
    this.layout, {
    super.key,
    this.dimColor = const Color(0x99000000),
    this.borderColor = const Color(0xFFFFFFFF),
    this.outlineColor = const Color(0xFF00E676),
  });

  /// The scanner layout.
  final ScannerLayout layout;

  /// Color drawn outside the scan window.
  final Color dimColor;

  /// Scan window border color.
  final Color borderColor;

  /// Barcode outline color.
  final Color outlineColor;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      ScanWindowOverlay(layout, dimColor: dimColor, borderColor: borderColor),
      BarcodeOutlines(layout, color: outlineColor),
    ],
  );
}

/// Dims the preview outside the scan window and draws its border.
class ScanWindowOverlay extends StatelessWidget {
  /// Creates the overlay.
  const ScanWindowOverlay(
    this.layout, {
    super.key,
    this.dimColor = const Color(0x99000000),
    this.borderColor = const Color(0xFFFFFFFF),
    this.borderWidth = 3,
    this.borderRadius = 16,
  });

  /// The scanner layout.
  final ScannerLayout layout;

  /// Color drawn outside the window.
  final Color dimColor;

  /// Border color.
  final Color borderColor;

  /// Border width in logical pixels.
  final double borderWidth;

  /// Corner radius of the window.
  final double borderRadius;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: layout.size,
      painter: _WindowPainter(
        window: layout.scanWindow,
        dimColor: dimColor,
        borderColor: borderColor,
        borderWidth: borderWidth,
        borderRadius: borderRadius,
      ),
    ),
  );
}

class _WindowPainter extends CustomPainter {
  const _WindowPainter({
    required this.window,
    required this.dimColor,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
  });

  final Rect window;
  final Color dimColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect hole = RRect.fromRectAndRadius(
      window,
      Radius.circular(borderRadius),
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(hole),
      Paint()..color = dimColor,
    );
    if (borderWidth > 0) {
      canvas.drawRRect(
        hole,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..color = borderColor,
      );
    }
  }

  @override
  bool shouldRepaint(_WindowPainter old) =>
      old.window != window ||
      old.dimColor != dimColor ||
      old.borderColor != borderColor ||
      old.borderWidth != borderWidth ||
      old.borderRadius != borderRadius;
}

/// Outlines the barcodes in [ScannerLayout.barcodes].
class BarcodeOutlines extends StatelessWidget {
  /// Creates the overlay.
  const BarcodeOutlines(
    this.layout, {
    super.key,
    this.color = const Color(0xFF00E676),
    this.strokeWidth = 4,
  });

  /// The scanner layout.
  final ScannerLayout layout;

  /// Outline color.
  final Color color;

  /// Outline width in logical pixels.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: layout.size,
      painter: _OutlinePainter(layout.barcodes, color, strokeWidth),
    ),
  );
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter(this.barcodes, this.color, this.strokeWidth);

  final List<VisibleBarcode> barcodes;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    for (final VisibleBarcode barcode in barcodes) {
      canvas.drawPath(Path()..addPolygon(barcode.corners, true), paint);
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter old) =>
      old.barcodes != barcodes ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// A button that toggles the torch; hidden when there is no torch.
class TorchButton extends StatelessWidget {
  /// Creates the button.
  const TorchButton(this.controller, {super.key});

  /// The controller whose torch to toggle.
  final ScannerController controller;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ScannerState>(
    valueListenable: controller,
    builder: (BuildContext context, ScannerState state, Widget? _) {
      if (state.torch == TorchState.unavailable) {
        return const SizedBox.shrink();
      }
      final bool on = state.torch == TorchState.on;
      return IconButton(
        tooltip: on ? 'Turn the torch off' : 'Turn the torch on',
        color: const Color(0xFFFFFFFF),
        icon: Icon(on ? Icons.flashlight_on : Icons.flashlight_off),
        onPressed: controller.toggleTorch,
      );
    },
  );
}

/// A button that switches between the back and front camera.
class SwitchCameraButton extends StatelessWidget {
  /// Creates the button.
  const SwitchCameraButton(this.controller, {super.key});

  /// The controller whose camera to switch.
  final ScannerController controller;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Switch camera',
    color: const Color(0xFFFFFFFF),
    icon: const Icon(Icons.cameraswitch),
    onPressed: controller.switchCamera,
  );
}

/// Opens a full-screen scanner, returns the first barcode found, or `null`
/// if the user closes it.
///
/// ```dart
/// final Barcode? barcode = await scanBarcode(context, formats: {BarcodeFormat.qrCode});
/// ```
///
/// [hint] is shown under the scan window, e.g. "Point the camera at a QR
/// code"; pass your own localized text.
Future<Barcode?> scanBarcode(
  BuildContext context, {
  Set<BarcodeFormat>? formats,
  ScanWindow scanWindow = const ScanWindow.centered(),
  CameraFacing facing = CameraFacing.back,
  String? hint,
}) => Navigator.of(context).push<Barcode>(
  PageRouteBuilder<Barcode>(
    pageBuilder:
        (BuildContext context, Animation<double> _, Animation<double> _) =>
            _ScanPage(
              formats: formats,
              scanWindow: scanWindow,
              facing: facing,
              hint: hint,
            ),
  ),
);

class _ScanPage extends StatefulWidget {
  const _ScanPage({
    required this.formats,
    required this.scanWindow,
    required this.facing,
    required this.hint,
  });

  final Set<BarcodeFormat>? formats;
  final ScanWindow scanWindow;
  final CameraFacing facing;
  final String? hint;

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  late final ScannerController _controller = ScannerController(
    formats: widget.formats,
    scanWindow: widget.scanWindow,
    facing: widget.facing,
    detection: DetectionMode.once,
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF000000),
    child: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        BarcodeScanner(
          controller: _controller,
          onDetect: (BarcodeCapture capture) {
            if (!_done) {
              _done = true;
              Navigator.of(context).pop(capture.barcode);
            }
          },
          overlayBuilder: (BuildContext context, ScannerLayout layout) => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ScannerOverlay(layout),
              if (widget.hint case final String hint)
                Positioned(
                  left: 24,
                  right: 24,
                  top: layout.scanWindow.bottom + 24,
                  child: Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              color: const Color(0xFFFFFFFF),
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TorchButton(_controller),
            ),
          ),
        ),
      ],
    ),
  );
}
