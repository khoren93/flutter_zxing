# Coming from mobile_scanner

flutter_zxing 4.0's scanner is shaped like mobile_scanner's on purpose: a
widget, a controller and a capture with a list of barcodes. Most code moves
over by renaming. What you get in exchange:

- **No ML Kit and no Google Play services.** The engine is zxing-cpp, built
  into your app: it works on Huawei and HarmonyOS devices, de-Googled phones
  and F-Droid builds, offline, and nothing leaves the device.
- **Formats ML Kit does not read:** Micro QR, rMQR, DataBar, MaxiCode,
  MicroPDF417, DX Film Edge and Telepen.
- **Generation in the same package:** `BarcodeWriter` and `BarcodeView`.
- **The same engine everywhere**, the web included (WebAssembly in a Web
  Worker).

Both packages define `BarcodeFormat`, `BarcodeCapture`, `CameraFacing` and
other names, so import one or the other in a file, not both.

## The widget and the controller

```dart
// mobile_scanner
MobileScanner(
  controller: MobileScannerController(formats: [BarcodeFormat.qrCode]),
  onDetect: (BarcodeCapture capture) => print(capture.barcodes.first.rawValue),
)

// flutter_zxing
BarcodeScanner(
  controller: ScannerController(formats: {BarcodeFormat.qrCode}),
  onDetect: (BarcodeCapture capture) => print(capture.barcode.text),
)
```

Without a controller, `BarcodeScanner` creates one and disposes it. A
controller you create is yours to `dispose()`.

| mobile_scanner | flutter_zxing |
|---|---|
| `MobileScanner(controller:, onDetect:)` | `BarcodeScanner(controller:, onDetect:)` |
| `MobileScannerController(formats: [...])` | `ScannerController(formats: {...})` (a `Set`; `null` reads every format) |
| `detectionSpeed: DetectionSpeed.noDuplicates` | `detection: DetectionMode.distinct` (the default: each code once, again after it has left the frame) |
| `DetectionSpeed.normal` / `.unrestricted`, `detectionTimeoutMs` | `DetectionMode.continuous`: every frame, paced by the camera |
| — | `DetectionMode.once`: stop after the first capture until `resume()` |
| `facing: CameraFacing.back` | `facing: CameraFacing.back` |
| `toggleTorch()`, `switchCamera()` | `toggleTorch()`, `setTorch(bool)`, `switchCamera()` |
| `setZoomScale(0…1)` | `setZoom(1…maxZoom)`, in zoom factors; `state.maxZoom` says how far |
| `scanWindow: Rect` (widget pixels) | `ScannerController(scanWindow: ScanWindow.centered())`, or `ScanWindow.fromRect(...)` in fractions of the preview, so it does not depend on the widget's size |
| `overlayBuilder(context, constraints)` | `overlayBuilder(context, ScannerLayout layout)`: the scan window and each barcode's corners already in widget coordinates |
| `errorBuilder(context, MobileScannerException)` | `errorBuilder(context, ScannerException)`: a sealed type, `CameraPermissionException`, `CameraNotFoundException` or `CameraFailureException` |
| `controller.analyzeImage(path)` | `controller.readImage(bytes)`: reported to `onDetect` like a frame; or `BarcodeReader().readAll(bytes)` without a controller |

The controller is a `ValueNotifier<ScannerState>`: listen to it for the
status, torch, zoom and errors. `formats`, `options`, `scanWindow`,
`detection` and `maxBarcodes` can be changed while the camera runs.

`ScannerController(maxBarcodes:)` limits how many codes are looked for in a
frame: 1 by default, which is several times faster on frames with a code;
`null` finds them all.

## A whole scanner screen

mobile_scanner leaves the screen around the camera to you. Here a template
draws it: glass buttons (close, torch, photo, zoom, camera switch), a hint,
brackets that lock onto the code and a sheet with what is in it.

```dart
BarcodeScanner(
  template: ScannerTemplate.minimal(),
  theme: ScannerTheme(accent: Color(0xFFFF6A1A)),
)
```

The templates are `minimal`, `payment`, `retail` (a list of scanned codes
with counts), `ticket` and `content`; `ScannerTheme` sets the accent, the
shapes and light or dark glass, and `ScannerStrings` translates the texts.
The pieces (`ScannerButton`, `TorchButton`, `ScannerSheet`,
`BarcodeResultSheet`, ...) are public, for your own `overlayBuilder`.

## The barcode

| mobile_scanner `Barcode` | flutter_zxing `Barcode` |
|---|---|
| `rawValue` | `text` |
| `rawBytes` | `bytes` |
| `format` | `format` (`BarcodeFormat`, with `displayName`) |
| `corners` | `position.corners` (also `position.bounds`, `position.center`) |
| `type` with `url`, `wifi`, `contactInfo`, ... | `content`: a sealed type to `switch` on |

```dart
switch (barcode.content) {
  case UrlContent(:final url):
    launchUrl(url);
  case WifiContent(:final ssid, :final password):
    connect(ssid, password);
  case ContactContent contact:
    saveContact(contact);
  default:
    print(barcode.text);
}
```

`barcode.position` is in pixels of the camera frame or image. In a scanner
overlay, use the corners `ScannerLayout` gives you: they are already mapped
to the screen.

## Reading images

```dart
// mobile_scanner
final BarcodeCapture? capture = await controller.analyzeImage(path);

// flutter_zxing
final List<Barcode> barcodes = await const BarcodeReader().readAll(
  await File(path).readAsBytes(),
);
```

`BarcodeReader` needs no camera and no controller: it reads image files
(`read`, `readAll`) and raw pixel buffers (`readPixels`, `readAllPixels`)
on every platform.

## Generating barcodes

mobile_scanner only scans. Here the same package draws codes:

```dart
const BarcodeView('https://pub.dev', width: 200)
```

and exports them: `BarcodeWriter(BarcodeFormat.qrCode).toImage(text)` (then
`toPng()`) or `.toSvg(text)`.
