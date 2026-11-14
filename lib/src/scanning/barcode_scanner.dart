// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; this package still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import '../errors.dart';
import 'scan_window.dart';
import 'scanner_controller.dart';

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
  @override
  Widget build(BuildContext context) => throw UnimplementedError('Stage 5');
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
  Widget build(BuildContext context) => throw UnimplementedError('Stage 5');
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
  Widget build(BuildContext context) => throw UnimplementedError('Stage 5');
}

/// A button that toggles the torch; hidden when there is no torch.
class TorchButton extends StatelessWidget {
  /// Creates the button.
  const TorchButton(this.controller, {super.key});

  /// The controller whose torch to toggle.
  final ScannerController controller;

  @override
  Widget build(BuildContext context) => throw UnimplementedError('Stage 5');
}

/// A button that switches between the back and front camera.
class SwitchCameraButton extends StatelessWidget {
  /// Creates the button.
  const SwitchCameraButton(this.controller, {super.key});

  /// The controller whose camera to switch.
  final ScannerController controller;

  @override
  Widget build(BuildContext context) => throw UnimplementedError('Stage 5');
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
}) => throw UnimplementedError('Stage 5');
