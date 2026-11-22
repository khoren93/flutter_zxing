# The controller

`ScannerController` drives the camera of a `BarcodeScanner` and decodes its
frames: as fast as the camera delivers them, one at a time, in the
background. Without a controller of your own, `BarcodeScanner` makes one.
Create yours once, in a `State`, not in `build`, and `dispose()` it with the
`State`.

```dart
final controller = ScannerController(
  formats: {BarcodeFormat.qrCode},
  detection: DetectionMode.distinct,
  scanWindow: const ScanWindow.centered(width: 0.7),
);

Widget scanner() => BarcodeScanner(controller: controller);

void listen() {
  controller.barcodes.listen((capture) => print(capture.barcode.text));
}
```

| Setting | Default | What it does |
|---|---|---|
| `formats` | all | The formats to look for; fewer decode faster |
| `options` | `ReaderOptions.camera()` | Search strategies per frame, see [Reader options](../reading/options) |
| `detection` | `DetectionMode.distinct` | When a code is reported, below |
| `scanWindow` | `ScanWindow.centered()` | The part of the preview that is decoded |
| `maxBarcodes` | 1 | How many codes to look for per frame; `null` for all |
| `facing` | `CameraFacing.back` | The camera to open |
| `resolution` | `CameraResolution.hd` | About 1280×720; `sd` and `fullHd` too |
| `autoStart` | `true` | Open the camera when the scanner is shown |
| `stopInBackground` | `true` | Release the camera while the app is in the background |
| `autoZoom` | `true` | Automatic zoom on iPhones |
| `initialZoom` | none | A zoom to start at, such as 2 for small codes |
| `torch` | `false` | Start with the torch on |

`formats`, `options`, `detection`, `scanWindow` and `maxBarcodes` can change
while the camera runs. `ScannerController.fromTemplate(template)` takes the
camera settings of a template, for a controller of your own under a
template's screen.

## When a code is reported

| `DetectionMode` | Reports |
|---|---|
| `distinct` | Each code once. Again after it has been out of view for about a second, and after `resume()`. |
| `continuous` | Every frame with a code, about 30 times per second |
| `once` | The first code, then decoding pauses until `resume()` |

`maxBarcodes: 1` stops at the first code in a frame, which is several times
faster on a frame with a code. Raise it, or pass `null`, to read shelves or
several labels at once.

## The scan window

Only the scan window of each frame is decoded.

```dart
const ScanWindow square = ScanWindow.centered(); // 70% of the width, square
const ScanWindow label = ScanWindow.centered(width: 0.9, aspectRatio: 3);
const ScanWindow high = ScanWindow.centered(alignment: Alignment(0, -0.5));
const ScanWindow all = ScanWindow.full();
final ScanWindow mine = ScanWindow.fromRect(const Rect.fromLTWH(0.1, 0.2, 0.8, 0.3));
```

`width` is a fraction of the preview width and `aspectRatio` is width over
height. On a preview too low for it, such as a phone in landscape, the
window shrinks to take the same fraction of the height.

## State

The controller is a `ValueNotifier<ScannerState>`: listen to it, or use a
`ValueListenableBuilder`, for the camera status, the torch, the zoom and
errors.

```dart
Widget status(ScannerController controller) => ValueListenableBuilder<ScannerState>(
  valueListenable: controller,
  builder: (context, state, _) => switch (state.status) {
    ScannerStatus.starting => const Text('Starting the camera'),
    ScannerStatus.error => Text('${state.error}'),
    _ => Text('Zoom ${state.zoom}×, torch ${state.torch.name}'),
  },
);
```

| `ScannerState` | What it is |
|---|---|
| `status` | `idle`, `starting`, `running`, `paused` or `error` |
| `error` | The `ScannerException` when the status is `error` |
| `torch` | `TorchState.unavailable`, `off` or `on` |
| `zoom`, `minZoom`, `maxZoom`, `telephotoZoom` | The zoom and its range; below 1 is an iPhone's ultra-wide camera |
| `autoZoom` | `AutoZoomState.unavailable`, `off` or `on` |
| `facing`, `canSwitchCamera` | The camera in use, and whether there is another |
| `previewSize` | The size of the camera preview |

## Start, pause and stop

```dart
Future<void> handle(ScannerController controller, BarcodeCapture capture) async {
  await controller.pause(); // the preview runs, frames and decoding stop
  print(capture.barcode.text);
  await controller.resume(); // with distinct, codes in view are reported anew
}
```

`stop()` releases the camera, `start()` opens it again. The camera also
stops while the app is in the background (`stopInBackground`) and while the
scanner is hidden, such as on another tab.

## Zoom, torch and focus

```dart
Future<void> controls(ScannerController controller) async {
  await controller.toggleTorch();
  await controller.setZoom(2);
  await controller.setAutoZoom(true);
  await controller.switchCamera();
  await controller.setFocusPoint(const Offset(0.5, 0.5));
}
```

`setZoom` clamps to the camera's range and turns automatic zoom off. On
iPhones, automatic zoom picks the camera from where the lens is focused:
the ultra-wide camera (0.5×, `ScannerState.minZoom`) when a code is too
close for the main camera to focus, 2× and then the telephoto camera
(`ScannerState.telephotoZoom`) when it is far. It never switches while
codes are being read, and the Auto button of `ZoomButtons` turns it back
on. Other platforms do not report their focus and keep the zoom where it is
set.

`setFocusPoint` takes a point in the preview, from 0 to 1 on both axes.
`BarcodeScanner` calls it on a tap; it does nothing on the web.

## Photos and frames

`readImage` reads an image file, such as a photo from the gallery, with the
controller's formats, and reports it like a camera frame: `onDetect` and the
templates see it too.

```dart
Future<void> fromGallery(ScannerController controller, Uint8List photo) async {
  final BarcodeCapture? capture = await controller.readImage(photo);
  if (capture == null) print('No code in the photo');
}
```

A `BarcodeCapture` has every code of the frame (`barcodes`), the first one
(`barcode`), the frame size and time. `capture.snapshot()` cuts a code out
of the frame or photo and straightens it, as an image;
`controller.lastFrameImage()` gives the last decoded frame. Both make a new
`ui.Image` each time, which you dispose.

```dart
Future<void> keep(BarcodeCapture capture) async {
  final ui.Image? image = await capture.snapshot();
  // Show or save it, then:
  image?.dispose();
}
```
