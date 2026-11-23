# Your own interface

Without a template, `BarcodeScanner` shows the camera with a scan window, and
`overlayBuilder` draws the rest. `ScannerLayout` gives the scan window and
each barcode's corners already in widget coordinates.

```dart
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // Created once, not in build; disposed with the page.
  final controller = ScannerController(
    formats: {BarcodeFormat.qrCode, BarcodeFormat.ean13},
    scanWindow: const ScanWindow.centered(width: 0.8, aspectRatio: 1.6),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BarcodeScanner(
    controller: controller,
    onDetect: (capture) async {
      await controller.pause();
      // Show the result, then: await controller.resume();
    },
    overlayBuilder: (context, layout) => Stack(
      children: [
        ScannerOverlay(layout),
        Align(
          alignment: Alignment.bottomCenter,
          child: TorchButton(controller),
        ),
      ],
    ),
  );
}
```

## The layout

| `ScannerLayout` | What it is |
|---|---|
| `size` | The size of the scanner widget |
| `scanWindow` | The scan window, a `Rect` in the widget |
| `barcodes` | The codes in view, each a `VisibleBarcode` with its `corners` and `bounds` in the widget, and an `id` that stays while it stays in view |
| `previewRect` | Where the whole camera preview lies; with `BoxFit.cover` it reaches past the widget |
| `state` | The camera state: status, torch, zoom |
| `controller` | The controller, for buttons |

```dart
Widget labels(BuildContext context, ScannerLayout layout) => Stack(
  children: [
    for (final VisibleBarcode code in layout.barcodes)
      Positioned.fromRect(
        rect: code.bounds,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.greenAccent, width: 3),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
  ],
);
```

## The pieces of the templates

The widgets the templates are built from are public, and take the
scanner's theme:

| Widget | What it is |
|---|---|
| `ScannerOverlay` | The scan window, the dimmed camera around it and the outlines of the codes |
| `ScanWindowOverlay`, `BarcodeOutlines` | The window alone, the outlines alone |
| `TorchButton`, `SwitchCameraButton`, `ZoomButtons`, `PickImageButton`, `ScannerCloseButton` | The buttons |
| `ScannerButton`, `ScannerHint`, `ScannerChip`, `ScannerGlass` | Glass buttons, hints, chips and panels of your own |
| `ScannerSheet`, `BarcodeResultSheet`, `BarcodeListSheet` | Sheets for a result or a list of codes |
| `ScannerPlaceholder`, `ScannerErrorView` | What shows while the camera starts, and when it cannot be used |
| `BarcodeThumbnail` | The picture of a code cut out of the frame |

`ScannerOverlay` draws the window as the theme says: its colours, shape,
brackets and scan line ([Colours and texts](./theming#the-window-and-the-scrim)).
`searching: false` holds the brackets' breathing and the scan line, such
as while your own result shows:

```dart
Widget overlay(ScannerLayout layout, bool showingResult) =>
    ScannerOverlay(layout, searching: !showingResult);
```

The theme's `icons` and texts reach these widgets too: a `ScannerScope`
around your page gives them your icons and the app's language.

## Over a template

`foregroundBuilder` adds a layer of your own over the template's, in every
state of the camera, with the scanner's theme: a button beside the
template's buttons. Leave the rest of the layer free of taps, so they reach
the overlay and the camera.

```dart
BarcodeScanner(
  template: const ScannerTemplate.minimal(),
  foregroundBuilder: (context, layout) => Positioned(
    left: 16,
    top: layout.scanWindow.bottom + 72,
    child: ScannerButton(
      icon: ScannerIcons.binary,
      label: 'Help',
      onPressed: () => print('help'),
    ),
  ),
)
```

## Starting, errors and settings

| `BarcodeScanner` | What it does |
|---|---|
| `placeholderBuilder` | Shown while the camera is starting or stopped; `ScannerPlaceholder` by default |
| `errorBuilder` | Shown instead of the preview when the camera cannot be used, with the `ScannerException`; `ScannerErrorView` by default |
| `onOpenSettings` | Opens the app's settings, where the user allows the camera. Opening them needs a plugin such as `app_settings`. |
| `fit` | How the preview fills the widget; `BoxFit.cover` by default |
| `tapToFocus`, `pinchToZoom` | Focus where the user taps, zoom with a pinch; both on |
| `pauseWhenHidden` | Stop the camera while the scanner is not shown, such as on another tab; on |

The camera errors are subclasses of `ScannerException`:
`CameraPermissionException` when access is off, `CameraNotFoundException`,
`CameraInUseException`, `CameraUnsupportedException` (the web over plain
HTTP, for one) and `CameraFailureException`.
