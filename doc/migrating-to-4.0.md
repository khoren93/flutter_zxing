# Migrating from flutter_zxing 3.x to 4.0

4.0 replaces the engine and adds a new API next to the old one. **Nothing has
to change on the day you upgrade:** the 3.x API (`zx`, `Code`,
`DecodeParams`, `ReaderWidget`, `WriterWidget`, ...) still works, on the new
engine, and is deprecated until its removal in 5.0. Each deprecated
declaration names its replacement, so the analyzer's hints are a to-do list.

This guide shows the replacements side by side.

## Upgrading

1. Raise the constraint in `pubspec.yaml`:

   ```yaml
   dependencies:
     flutter_zxing: ^4.0.0
   ```

   4.0 needs Flutter 3.41 and Dart 3.11 or newer.

2. Run `flutter clean` once. The CMake, CocoaPods, Swift Package Manager and
   Gradle builds of 3.x are gone: the package's build hook compiles
   zxing-cpp for Android, iOS, macOS, Linux and Windows, so the first build
   takes longer than the next ones.

3. Build and run. Your 3.x code keeps working; the
   [CHANGELOG](../CHANGELOG.md) lists the few behaviour changes (image files
   are read on a background isolate and at full resolution, barcodes are
   created with zxing-cpp's newer creator).

The 3.x API is not available on the web. The new API is, with the same
engine compiled to WebAssembly.

## At a glance

| 3.x | 4.0 |
|---|---|
| `ReaderWidget(onScan: ...)` | `BarcodeScanner(onDetect: ...)` |
| `ReaderWidget(isMultiScan: true, onMultiScan: ...)` | `BarcodeScanner` with `ScannerController(maxBarcodes: null)`, then `capture.barcodes` |
| `WriterWidget` | `BarcodeView` |
| `zx.readBarcodeImagePath(file, params)` | `BarcodeReader().read(await file.readAsBytes())` |
| `zx.readBarcodesImagePath(file, params)` | `BarcodeReader().readAll(...)` |
| `zx.readBarcode(pixels, params)` | `BarcodeReader().readPixels(PixelBuffer(...))` |
| `zx.processCameraImage(image, params)` | `ScannerController`, or `readPixels` |
| `zx.encodeBarcode(contents: ..., params: ...)` | `BarcodeWriter(format).toPng(...)`, `.toSvg(...)`, `.toImage(...)` or `.encode(...)` |
| `Code` / `Codes` | `Barcode` / `List<Barcode>` |
| `Format.qrCode \| Format.ean13` (an `int` bit mask) | `{BarcodeFormat.qrCode, BarcodeFormat.ean13}` |
| `DecodeParams` | `ReaderOptions` + `formats` |
| `EncodeParams`, `EccLevel` | `BarcodeWriter` parameters, `ErrorCorrection` |
| `Position` | `BarcodePosition` |
| `zx.version()` | `zxingCppVersion` |

Everything in the new API that touches the engine returns a `Future` and
runs off the UI thread; there is no `init()`/`dispose()` except on the
camera controller.

## Scanning with the camera

```dart
// 3.x
ReaderWidget(
  codeFormat: Format.qrCode | Format.ean13,
  tryHarder: true,
  onScan: (Code code) => print(code.text),
)

// 4.0
BarcodeScanner(
  controller: ScannerController(
    formats: {BarcodeFormat.qrCode, BarcodeFormat.ean13},
  ),
  onDetect: (BarcodeCapture capture) => print(capture.barcode.text),
)
```

`BarcodeScanner` creates and disposes a controller by itself when you do not
pass one. A controller you create is yours to `dispose()`. It also lets you
change `formats`, `options`, `scanWindow` and `detection` while the camera
runs, and controls the torch, zoom, focus and camera (`setTorch`, `setZoom`,
`setFocusPoint`, `switchCamera`).

The camera preset (`ReaderOptions.camera()`) already turns on `tryHarder`
and `tryRotate`, so most 3.x scanner settings have no counterpart to set.

| `ReaderWidget` | 4.0 |
|---|---|
| `codeFormat` | `ScannerController(formats:)` |
| `tryHarder`, `tryInverted`, `tryRotate`, `tryDownscale` | `ScannerController(options: ReaderOptions(...))` |
| `cropPercent`, `horizontalCropOffset`, `verticalCropOffset` | `ScannerController(scanWindow: ScanWindow.centered(...))` or `ScanWindow.fromRect(...)` |
| `scanDelay`, `scanDelaySuccess` | `ScannerController(detection: DetectionMode.distinct)` (each code once, again after it has left the frame), `.continuous` or `.once` |
| `maxNumberOfSymbols`, `isMultiScan` | `ScannerController(maxBarcodes:)`: 1 by default, `null` for all |
| `resolution` | `ScannerController(resolution: CameraResolution.hd)` |
| `lensDirection` | `ScannerController(facing: CameraFacing.back)` |
| `allowPinchZoom` | `BarcodeScanner(pinchToZoom:)` |
| `onScanFailure` | Not needed: frames without a code report nothing |
| `onControllerCreated` | Pass your own `ScannerController` |
| `scannerOverlay`, `showScannerOverlay` | `BarcodeScanner(template:, theme:)`, or your own `overlayBuilder:` |
| `showFlashlight`, `showToggleCamera`, `showGallery` | Buttons of the template (`torchButton`, `switchCameraButton`, `photoButton`) |
| `loading` | `BarcodeScanner(placeholderBuilder:)`; default `ScannerPlaceholder` |
| Camera errors in the log | `BarcodeScanner(errorBuilder:)` with a typed `ScannerException` |

### A ready-made screen

`ReaderWidget` drew its own buttons and overlay. In 4.0 a template draws a
whole scanner screen, in your colors:

```dart
BarcodeScanner(
  template: ScannerTemplate.minimal(),
  theme: ScannerTheme(
    accent: Color(0xFFFF6A1A),
    buttonShape: ScannerButtonShape.roundedSquare,
  ),
)
```

`ScannerTemplate.minimal` has close, torch, photo, zoom and camera buttons
and shows a sheet with the parsed content of the code found;
`ScannerTemplate.retail` collects codes in a list with counts. `payment`,
`ticket` and `content` are the other presets. `ScannerStrings` translates
every text. `sound: true` plays the system click when a code is found.

### Several codes at once

```dart
// 3.x
ReaderWidget(
  isMultiScan: true,
  onMultiScan: (Codes codes) => print(codes.codes.length),
)

// 4.0
final controller = ScannerController(maxBarcodes: null);

BarcodeScanner(
  controller: controller,
  onDetect: (BarcodeCapture capture) {
    for (final Barcode barcode in capture.barcodes) {
      print(barcode.text);
    }
  },
)
```

### One code, then back

New in 4.0, for the common "scan and return" flow:

```dart
final Barcode? barcode = await scanBarcode(
  context,
  formats: {BarcodeFormat.qrCode},
);
```

## Reading image files

```dart
// 3.x
final Code code = await zx.readBarcodeImagePath(file, DecodeParams());
final Codes codes = await zx.readBarcodesImagePath(file, DecodeParams());

// 4.0
final Uint8List bytes = await file.readAsBytes();
final Barcode? barcode = await const BarcodeReader().read(bytes);
final List<Barcode> barcodes = await const BarcodeReader().readAll(bytes);
```

JPEG, PNG, GIF and BMP files are decoded by the engine (on the web, also
anything the browser decodes, such as WebP). "Not found" is
`null` (or an empty list), not a `Code` with `isValid == false`; a file that
is not an image throws `ImageDecodeException`.

`readBarcodeImageUrl` has no counterpart: download the bytes with your HTTP
client and pass them to `read`.

## Reading raw pixels

```dart
// 3.x
final Code code = zx.readBarcode(
  gray,
  DecodeParams(width: width, height: height, imageFormat: ImageFormat.lum),
);

// 4.0
final Barcode? barcode = await const BarcodeReader().readPixels(
  PixelBuffer(gray, width: width, height: height),
);
```

`PixelBuffer` takes `layout` (`PixelLayout.luminance`, `rgb`, `rgba`,
`bgra`), `rowStride` for padded rows, and `crop` for the part of the image to
read (3.x: `cropLeft`, `cropTop`, `cropWidth`, `cropHeight`):

```dart
PixelBuffer(
  gray,
  width: width,
  height: height,
  crop: const Rect.fromLTWH(100, 100, 400, 300),
)
```

## Reader options

```dart
const BarcodeReader reader = BarcodeReader(
  formats: {BarcodeFormat.dataMatrix},
  options: ReaderOptions(tryHarder: true, tryInvert: true),
);
```

| `DecodeParams` | 4.0 |
|---|---|
| `format` | `BarcodeReader(formats:)`; `null` reads every format |
| `tryHarder`, `tryRotate`, `tryDownscale` | `ReaderOptions` fields of the same name |
| `tryInverted` | `ReaderOptions(tryInvert:)` |
| `maxNumberOfSymbols` | `readAll(limit:)`; `read` returns the first |
| `maxSize` | Not needed: images are read at full resolution, `tryDownscale` handles large ones |
| `imageFormat`, `width`, `height`, `crop...` | `PixelBuffer` |
| `isMultiScan` | `read` versus `readAll` |

`ReaderOptions` also has `isPure`, `returnErrors`, `binarizer`,
`minLineCount`, `validateOptionalChecksum` and `eanAddOn` (EAN-2/EAN-5
add-ons).

## The result: `Code` → `Barcode`

| `Code` | `Barcode` |
|---|---|
| `text` | `text` (never `null`) |
| `rawBytes` | `bytes` |
| `format` (`int`) | `format` (`BarcodeFormat`, with `displayName`) |
| `isValid`, `error` | `isValid`, `error` (`BarcodeError` with a `kind`); invalid codes appear only with `ReaderOptions(returnErrors: true)` |
| `position` | `position` (`BarcodePosition`: four corners, `bounds`, `center`) |
| `isInverted`, `isMirrored` | `isInverted`, `isMirrored` |
| `duration` | Measure it around the call if you need it |
| `imageBytes`, `imageWidth`, `imageHeight` | No counterpart |

New in `Barcode`: `content` (below), `orientation`, `ecLevel`, `version`,
`symbologyIdentifier`, `contentType` and `sequence` (structured append; join
the parts with `Barcode.merge`).

## What is in the barcode

`barcode.content` parses the payload into a sealed type for pattern
matching. Parsing never throws; anything not recognised is `TextContent`.

```dart
switch (barcode.content) {
  case UrlContent(:final url):
    print('open $url');
  case WifiContent(:final ssid, :final password):
    print('join $ssid');
  default:
    print(barcode.text);
}
```

The types are `UrlContent`, `WifiContent`, `ContactContent` (vCard, MeCard),
`EventContent`, `EmailContent`, `PhoneContent`, `SmsContent`, `GeoContent`,
`Gs1Content` (Application Identifiers), `BinaryContent` and `TextContent`.

## Generating barcodes

```dart
// 3.x
final Encode result = zx.encodeBarcode(
  contents: 'https://pub.dev',
  params: EncodeParams(format: Format.qrCode, width: 300, height: 300),
);

// 4.0
const BarcodeWriter writer = BarcodeWriter(BarcodeFormat.qrCode);
final Uint8List png = await writer.toPng('https://pub.dev', size: 300);
final String svg = await writer.toSvg('https://pub.dev');
```

Both take the `BarcodeStyle` of `BarcodeView` (`style:`), so an exported
code looks like the one on screen. `writer.toImage(...)` gives the plain
grayscale pixels instead.

`writer.encode(text)` and `writer.encodeBytes(bytes)` return a
`BarcodeSymbol`: the module matrix, its quiet zone and the human readable
text, for your own rendering. Data that cannot be encoded, such as letters
in an EAN-13, throws `BarcodeWriteException`.

| `EncodeParams` | 4.0 |
|---|---|
| `format` | `BarcodeWriter(format)` |
| `width`, `height` | `toPng(size:)` or `toPng(moduleSize:)`; `BarcodeView(width:, height:)` |
| `margin` | `BarcodeWriter(quietZone:)`: the quiet zone the symbology requires, or none |
| `eccLevel` | `BarcodeWriter(errorCorrection: ErrorCorrection.high)` |

### In a widget: `WriterWidget` → `BarcodeView`

`WriterWidget` was a form for typing text and creating a code. Its
replacement shows a code:

```dart
const BarcodeView(
  'https://pub.dev',
  width: 200,
  style: BarcodeStyle(moduleShape: ModuleShape.rounded),
)
```

`BarcodeView` draws vectors, sharp at any size. `BarcodeStyle` sets the
colors or a gradient, rounded or dot modules, rounded or round QR finder
patterns, and a logo in the middle of a QR code. `BarcodeView.bytes` shows
binary data.

## Formats

`Format` was a set of `int` bit flags combined with `|`. `BarcodeFormat` is an
enum; pass a `Set` where several are allowed. A base symbology includes its
variants: `{BarcodeFormat.qrCode}` also finds Micro QR and rMQR codes.

| 3.x | 4.0 |
|---|---|
| `Format.any` | `null` (all formats) |
| `Format.qrCode \| Format.ean13` | `{BarcodeFormat.qrCode, BarcodeFormat.ean13}` |
| `Format.linearCodes` | `BarcodeFormat.linear` |
| `Format.matrixCodes` | `BarcodeFormat.matrix` |
| `zx.barcodeFormatName(format)` | `format.displayName` |
