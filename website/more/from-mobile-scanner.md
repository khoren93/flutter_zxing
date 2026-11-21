# Coming from mobile_scanner

[mobile_scanner](https://pub.dev/packages/mobile_scanner) is the most used
scanner package for Flutter. Both are good choices; they make different
trade-offs. flutter_zxing 4.0's scanner is shaped like mobile_scanner's on
purpose: a widget, a controller and a capture with a list of barcodes. Most
code moves over by renaming.

## Compared

| | flutter_zxing 4.0 | mobile_scanner 7 |
|---|---|---|
| Decoder | zxing-cpp on every platform | ML Kit (Android), Apple Vision (iOS, macOS), the browser's `BarcodeDetector` or zxing-wasm (web) |
| Google Play services | Never | Not by default (bundled ML Kit); the smaller "unbundled" option needs them |
| Network | Never | The web build loads zxing-wasm from a CDN when the browser has no `BarcodeDetector` |
| Android size | +2.7 MB per ABI | +3–10 MB bundled, ~0.6 MB unbundled |
| Platforms | Android, iOS, macOS, Linux, Windows, web | Android, iOS, macOS, web |
| Creates barcodes | Yes: widget, PNG, SVG, styles | No |
| Formats | 32 to read, the same on every platform | Depends on the platform's decoder; ML Kit on Android reads 13 (no Micro QR, rMQR, DataBar, MaxiCode, MicroPDF417) |
| Parsed content | Dart types, the same on every platform | From the platform's decoder |
| Scanner UI | 16 templates and themable pieces, or your own | Your own (`overlayBuilder`) |
| Camera | The `camera` plugin: frames pass through Dart (only the scan window is copied); up to 30 fps | Native camera, frames stay native |

Where mobile_scanner is ahead:

- **Hard codes.** ML Kit and Apple Vision are machine-learning decoders.
  They tend to read damaged, blurred, curved and low-contrast codes that a
  classic decoder like zxing-cpp misses, and find codes from further away.
- **The camera.** Frames never reach Dart, so the frame rate is the
  camera's; ours is limited by how fast the `camera` plugin delivers frames
  (25 fps on a Pixel 4a). A camera of the package's own is planned for 4.1.
- **Maturity.** It has more users and more years on more devices.

Choose flutter_zxing when Google services, offline use or privacy matter,
when you need formats ML Kit does not read, Linux or Windows, the same
results on every platform, or barcode generation in the same package.

Both packages define `BarcodeFormat`, `BarcodeCapture`, `CameraFacing` and
other names, so import one or the other in a file, not both.

## The widget and the controller

<!-- snippet: skip -->
```dart
// mobile_scanner
MobileScanner(
  controller: MobileScannerController(formats: [BarcodeFormat.qrCode]),
  onDetect: (BarcodeCapture capture) => print(capture.barcodes.first.rawValue),
)
```

```dart
// flutter_zxing: the controller is a field of your State
final ScannerController controller = ScannerController(
  formats: {BarcodeFormat.qrCode},
);

@override
void dispose() {
  controller.dispose();
  super.dispose();
}

@override
Widget build(BuildContext context) => BarcodeScanner(
  controller: controller,
  onDetect: (BarcodeCapture capture) => print(capture.barcode.text),
);
```

Create the controller once, as above, not in `build`: a new controller on
every rebuild restarts the camera. A controller you create is yours to
`dispose()`.

A template is something else: a whole scanner screen. With a template and
no controller, `BarcodeScanner` creates its own controller with the
template's formats and disposes it, but the template also decides what
happens with a code. Most templates read one code, pause and show a sheet
with it, and add close, torch and photo buttons:

```dart
BarcodeScanner(
  template: const ScannerTemplate.fullscreen(formats: {BarcodeFormat.qrCode}),
  onDetect: (BarcodeCapture capture) => print(capture.barcode.text),
)
```

For the behaviour of `MobileScanner(onDetect:)`, where scanning goes on and
your app decides what to show, pass a controller as above and no template.

| mobile_scanner | flutter_zxing |
|---|---|
| `MobileScanner(controller:, onDetect:)` | `BarcodeScanner(controller:, onDetect:)` |
| `MobileScannerController(formats: [...])` | `ScannerController(formats: {...})` (a `Set`; `null` reads every format) |
| `detectionSpeed: DetectionSpeed.noDuplicates` | `detection: DetectionMode.distinct` (the default: each code once, again after it has left the frame) |
| `DetectionSpeed.normal` / `.unrestricted`, `detectionTimeoutMs` | `DetectionMode.continuous`: every frame, paced by the camera |
| — | `DetectionMode.once`: stop after the first capture until `resume()` |
| `facing: CameraFacing.back` | `facing: CameraFacing.back`; `controller.facing` follows `switchCamera()` |
| `autoStart: false`, `start()`, `stop()` | `autoStart: false`, `start()`, `stop()`; `pause()` and `resume()` keep the camera open |
| A `WidgetsBindingObserver` that stops and starts the camera | Not needed: `stopInBackground` (on by default) stops the camera in the background and starts it again on return. Remove your observer |
| `controller.barcodes` | `controller.barcodes`: a stream of `BarcodeCapture` |
| `torchEnabled: true` | `ScannerController(torch: true)` |
| `toggleTorch()`, `switchCamera()` | `toggleTorch()`, `setTorch(bool)`, `switchCamera()` |
| `availableCameras` | `controller.value.canSwitchCamera`; `SwitchCameraButton` hides itself without another camera |
| `initialZoom`, `setZoomScale(0…1)` | `ScannerController(initialZoom: 2)`, `setZoom(1…maxZoom)`, in zoom factors; `state.maxZoom` says how far |
| `returnImage: true`, `capture.image` | `await capture.snapshot()`: the barcode cut out and straightened; `await controller.lastFrameImage()`: the whole frame |
| `scanWindow: Rect` (widget pixels) | `ScannerController(scanWindow: ScanWindow.centered())`, or `ScanWindow.fromRect(...)` in fractions of the preview, so it does not depend on the widget's size |
| `overlayBuilder(context, constraints)` | `overlayBuilder(context, ScannerLayout layout)`: the scan window and each barcode's corners already in widget coordinates |
| `errorBuilder(context, MobileScannerException)` | `errorBuilder(context, ScannerException)`: a sealed type, `CameraPermissionException`, `CameraNotFoundException`, `CameraInUseException`, `CameraUnsupportedException` or `CameraFailureException` |
| `controller.analyzeImage(path)` | `controller.readImage(bytes)`: reported to `onDetect` like a frame; or `BarcodeReader().readAll(bytes)` without a controller |

See [The controller](../scanning/controller) for the rest.

## A whole scanner screen

mobile_scanner leaves the screen around the camera to you. Here a template
draws it: glass buttons (close, torch, photo, zoom, camera switch), a hint,
brackets that lock onto the code and a sheet with what is in it.

```dart
BarcodeScanner(
  template: const ScannerTemplate.minimal(),
  theme: const ScannerTheme(accent: Color(0xFFFF6A1A)),
)
```

See the [16 templates](../templates), [Colours and texts](../scanning/theming)
and [Your own interface](../scanning/custom-ui) for the pieces.

## The barcode

| mobile_scanner `Barcode` | flutter_zxing `Barcode` |
|---|---|
| `rawValue` | `text` |
| `rawBytes` | `bytes` |
| `format` | `format` (`BarcodeFormat`, with `displayName`) |
| `corners` | `position.corners` (also `position.bounds`, `position.center`) |
| `type` with `url`, `wifi`, `contactInfo`… | `content`: a class to `switch` on, with a `default` case |

```dart
void handle(Barcode barcode) {
  switch (barcode.content) {
    case UrlContent(:final url):
      launchUrl(url);
    case WifiContent(:final ssid):
      print('Join $ssid');
    default:
      print(barcode.text);
  }
}
```

`barcode.position` is in pixels of the camera frame or image. In a scanner
overlay, use the corners `ScannerLayout` gives you: they are already mapped
to the screen.

## Reading images

<!-- snippet: skip -->
```dart
// mobile_scanner
final BarcodeCapture? capture = await controller.analyzeImage(path);
```

```dart
// flutter_zxing
Future<List<Barcode>> read(String path) async =>
    const BarcodeReader().readAll(await File(path).readAsBytes());
```

`BarcodeReader` needs no camera and no controller: it reads image files
(`read`, `readAll`) and raw pixel buffers (`readPixels`, `readAllPixels`)
on every platform.

## Generating barcodes

mobile_scanner only scans. Here the same package draws codes, and exports
them with the same style:

```dart
const BarcodeView('https://pub.dev', width: 200)
```

See [Barcodes as widgets](../creating/barcode-view).
