# Upgrading from 3.x

4.0 replaces the engine and adds a new API next to the old one. **Nothing
has to change on the day you upgrade:** the 3.x API (`zx`, `Code`,
`DecodeParams`, `ReaderWidget`, `WriterWidget`…) still works, on the new
engine, and is deprecated until its removal in 5.0. Each deprecated
declaration names its replacement, so the analyzer's hints are a to-do list.

This page shows the replacements side by side. Coming from an earlier 4.0
release candidate: see [From 4.0.0-rc.2](#from-4-0-0-rc-2).

## Upgrading

1. Raise the constraint in `pubspec.yaml`. 4.0 needs Flutter 3.41 and
   Dart 3.11 or newer.

   ```yaml
   dependencies:
     flutter_zxing: ^%VERSION%
   ```

2. Run `flutter clean` once. The CMake, CocoaPods, Swift Package Manager
   and Gradle builds of 3.x are gone: the package's build hook compiles
   zxing-cpp for Android, iOS, macOS, Linux and Windows, so the first build
   takes longer than the next ones.

3. Build and run. Your 3.x code keeps working; the
   [CHANGELOG](https://github.com/khoren93/flutter_zxing/blob/main/CHANGELOG.md)
   lists the few behaviour changes: image files are read on a background
   isolate and at full resolution, and barcodes are created with
   zxing-cpp's newer creator.

The 3.x API is not available on the web. The new API is, with the same
engine compiled to WebAssembly. New code imports
`package:flutter_zxing/scanner.dart`; `flutter_zxing.dart` adds the 3.x API
to it.

## At a glance

| 3.x | 4.0 |
|---|---|
| `ReaderWidget(onScan: ...)` | `BarcodeScanner(onDetect: ...)` |
| `ReaderWidget(isMultiScan: true, onMultiScan: ...)` | `BarcodeScanner` with `ScannerController(maxBarcodes: null, detection: DetectionMode.continuous)`, then `capture.barcodes` |
| `WriterWidget` | `BarcodeView` |
| `zx.readBarcodeImagePath(file, params)` | `BarcodeReader().read(await file.readAsBytes())` |
| `zx.readBarcodesImagePath(file, params)` | `BarcodeReader().readAll(...)` |
| `zx.readBarcode(pixels, params)` | `BarcodeReader().readPixels(PixelBuffer(...))` |
| `zx.processCameraImage(image, params)` | `ScannerController`, or `readPixels` |
| `zx.encodeBarcode(contents: ..., params: ...)` | `BarcodeWriter(format).toPng(...)`, `.toSvg(...)`, `.toImage(...)` or `.encode(...)`; with a style, `style.encodePng(data, writer: ...)` |
| `Code` / `Codes` | `Barcode` / `List<Barcode>` |
| `Format.qrCode \| Format.ean13` (an `int` bit mask) | `{BarcodeFormat.qrCode, BarcodeFormat.ean13}` |
| `DecodeParams` | `ReaderOptions` and `formats` |
| `EncodeParams`, `EccLevel` | `BarcodeWriter` parameters, `ErrorCorrection` |
| `Position` | `BarcodePosition` |
| `zx.version()` | `zxingCppVersion` |

Everything in the new API that touches the engine returns a `Future` and
runs off the UI thread; there is no `init()` or `dispose()` except on the
camera controller.

## Scanning with the camera

<!-- snippet: skip -->
```dart
// 3.x
ReaderWidget(
  codeFormat: Format.qrCode | Format.ean13,
  tryHarder: true,
  onScan: (Code code) => print(code.text),
)
```

```dart
// 4.0: the controller is a field of your State, disposed with it
final ScannerController controller = ScannerController(
  formats: {BarcodeFormat.qrCode, BarcodeFormat.ean13},
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

Create the controller once, not in `build`: a new controller on every
rebuild restarts the camera. A controller you create is yours to
`dispose()`. It lets you change `formats`, `options`, `scanWindow` and
`detection` while the camera runs, and controls the torch, zoom, focus and
camera (`setTorch`, `setZoom`, `setFocusPoint`, `switchCamera`).

Without a controller, `BarcodeScanner` creates and disposes its own. With a
template, it takes the template's formats:
`BarcodeScanner(template: const ScannerTemplate.minimal(formats: {BarcodeFormat.qrCode}))`.
A template is a whole screen, not only settings: most templates read one
code, pause and show a sheet with it. For `ReaderWidget`'s behaviour, where
scanning goes on and `onScan` gets each code, pass a controller and no
template.

As with `ReaderWidget`, the camera stops while the app is in the background
and starts again when it returns (`ScannerController(stopInBackground:)`).

The camera preset, `ReaderOptions.camera()`, already turns on `tryHarder`
and `tryRotate`, so most 3.x scanner settings have no counterpart to set.

| `ReaderWidget` | 4.0 |
|---|---|
| `codeFormat` | `ScannerController(formats:)` |
| `tryHarder`, `tryInverted`, `tryRotate`, `tryDownscale` | `ScannerController(options: ReaderOptions.camera().copyWith(...))`: plain `ReaderOptions()` is the preset for files, with `tryInvert` on |
| `cropPercent`, `horizontalCropOffset`, `verticalCropOffset` | `ScannerController(scanWindow: ScanWindow.centered(...))` or `ScanWindow.fromRect(...)` |
| `scanDelay`, `scanDelaySuccess` | `ScannerController(detection: DetectionMode.distinct)` (each code once, again after it has left the frame), `.continuous` or `.once` |
| `maxNumberOfSymbols`, `isMultiScan` | `ScannerController(maxBarcodes:)`: 1 by default, `null` for all |
| `resolution` | `ScannerController(resolution: CameraResolution.hd)` |
| `lensDirection` | `ScannerController(facing: CameraFacing.back)` |
| Torch on at the start | `ScannerController(torch: true)` |
| Zoom at the start | `ScannerController(initialZoom: 2)` |
| `allowPinchZoom` | `BarcodeScanner(pinchToZoom:)` |
| `onScanFailure` | Not needed: frames without a code report nothing |
| `onControllerCreated` | Pass your own `ScannerController` |
| `scannerOverlay`, `showScannerOverlay` | `BarcodeScanner(template:, theme:)`, or your own `overlayBuilder:` |
| `showFlashlight`, `showToggleCamera`, `showGallery` | Buttons of the template (`torchButton`, `switchCameraButton`, `photoButton`) |
| `loading` | `BarcodeScanner(placeholderBuilder:)`; `ScannerPlaceholder` by default |
| Camera errors in the log | `BarcodeScanner(errorBuilder:)` with a typed `ScannerException` |

### A ready-made screen

`ReaderWidget` drew its own buttons and overlay. In 4.0 a template draws a
whole scanner screen, in your colours:

```dart
BarcodeScanner(
  template: const ScannerTemplate.minimal(),
  theme: const ScannerTheme(
    accent: Color(0xFFFF6A1A),
    buttonShape: ScannerButtonShape.roundedSquare,
  ),
)
```

See [A ready-made screen](../scanning/templates) for the 16 templates, their
modes, checks and result sheets.

### Several codes at once

<!-- snippet: skip -->
```dart
// 3.x
ReaderWidget(
  isMultiScan: true,
  onMultiScan: (Codes codes) => print(codes.codes.length),
)
```

```dart
// 4.0, the controller a field of your State: every code in each frame
final controller = ScannerController(
  maxBarcodes: null,
  detection: DetectionMode.continuous,
);

Widget scanner() => BarcodeScanner(
  controller: controller,
  onDetect: (BarcodeCapture capture) {
    for (final Barcode barcode in capture.barcodes) {
      print(barcode.text);
    }
  },
);
```

As with `onMultiScan`, `DetectionMode.continuous` reports all the codes in
view on every frame. With the default `DetectionMode.distinct`,
`capture.barcodes` holds only the codes that are new in the frame: each
code once, again after it has left the frame.

### One code, then back

New in 4.0, for the common "scan and return" flow:

```dart
final Barcode? barcode = await scanBarcode(
  context,
  formats: {BarcodeFormat.qrCode},
);
```

## Reading image files

<!-- snippet: skip -->
```dart
// 3.x
final Code code = await zx.readBarcodeImagePath(file, DecodeParams());
final Codes codes = await zx.readBarcodesImagePath(file, DecodeParams());
```

```dart
// 4.0
Future<void> read(File file) async {
  final Uint8List bytes = await file.readAsBytes();
  final Barcode? barcode = await const BarcodeReader().read(bytes);
  final List<Barcode> barcodes = await const BarcodeReader().readAll(bytes);
  print('${barcode?.text}, ${barcodes.length}');
}
```

JPEG, PNG, GIF and BMP files are decoded by the engine, and WebP and the
other formats Flutter decodes are read too. "Not found" is `null` (or an
empty list), not a `Code` with `isValid == false`; a file that is not an
image throws `ImageDecodeException`. TIFF, TGA, PSD, PNM, EXR and the other
formats 3.x read through package:image are not decoded: decode them
yourself (for example with package:image) and pass the pixels to
`readPixels`. 3.x applied `cropLeft`, `cropTop`, `cropWidth` and
`cropHeight` to image files too; 4.0 (and the 3.x API in it) reads files
whole, so crop the pixels with `PixelBuffer(crop:)` instead.

`readBarcodeImageUrl` has no counterpart: download the bytes with your HTTP
client and pass them to `read`.

## Reading raw pixels

<!-- snippet: skip -->
```dart
// 3.x
final Code code = zx.readBarcode(
  gray,
  DecodeParams(width: width, height: height, imageFormat: ImageFormat.lum),
);
```

```dart
// 4.0
Future<Barcode?> read(Uint8List gray, int width, int height) =>
    const BarcodeReader().readPixels(
      PixelBuffer(
        gray,
        width: width,
        height: height,
        crop: const Rect.fromLTWH(100, 100, 400, 300), // 3.x: cropLeft…
      ),
    );
```

`PixelBuffer` takes `layout` (`PixelLayout.luminance`, `rgb`, `rgba`,
`bgra`), `rowStride` for padded rows, and `crop` for the part of the image
to read.

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
| `tryHarder`, `tryRotate`, `tryDownscale` | `ReaderOptions` fields of the same name, all on by default (3.x: `tryHarder` and `tryDownscale` off) |
| `tryInverted` | `ReaderOptions(tryInvert:)`, on by default (3.x: off) |
| `maxNumberOfSymbols` | `readAll(maxBarcodes:)`; `read` returns the first |
| `maxSize` | Not needed: images are read at full resolution, `tryDownscale` handles large ones |
| `imageFormat`, `width`, `height`, `crop...` | `PixelBuffer` |
| `isMultiScan` | `read` versus `readAll` |

See [Reader options](../reading/options) for the rest.

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

New in `Barcode`: `content` ([What is in a code](../content/overview)),
`rotation`, `ecLevel`, `version`, `symbologyIdentifier`, `contentType` and
`sequence` (structured append; join the parts with
`await reader.merge(parts)`).

## Generating barcodes

<!-- snippet: skip -->
```dart
// 3.x
final Encode result = zx.encodeBarcode(
  contents: 'https://pub.dev',
  params: EncodeParams(format: Format.qrCode, width: 300, height: 300),
);
```

```dart
// 4.0
Future<void> generate() async {
  const BarcodeWriter writer = BarcodeWriter(BarcodeFormat.qrCode);
  final Uint8List png = await writer.toPng('https://pub.dev', size: 300);
  final String svg = await writer.toSvg('https://pub.dev');

  // With the look of the code on screen:
  const BarcodeStyle style = BarcodeStyle(moduleShape: ModuleShape.rounded);
  final Uint8List styled = await style.encodePng('https://pub.dev', size: 300);
  print('${png.length} ${svg.length} ${styled.length}');
}
```

`writer.toImage(...)` gives the plain grayscale pixels. `writer.encode(text)`
and `writer.encodeBytes(bytes)` return a `BarcodeSymbol`: the module
matrix, its quiet zone and the human readable text, for your own rendering.
Data that cannot be encoded, such as letters in an EAN-13, throws
`BarcodeWriteException`.

| `EncodeParams` | 4.0 |
|---|---|
| `format` | `BarcodeWriter(format)` |
| `width`, `height` | `toPng(size:)` or `toPng(moduleSize:)`; `BarcodeView(width:, height:)` |
| `margin` | The quiet zone the symbology requires, or none: `BarcodeStyle(quietZone:)`, or `toPng(quietZone: false)` |
| `eccLevel` | `BarcodeWriter(errorCorrection: ErrorCorrection.high)`; without it, QR codes get M (3.x wrote zxing-cpp's L) |

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

See [Barcodes as widgets](../creating/barcode-view) and
[Styles and logos](../creating/styles).

## Formats

`Format` was a set of `int` bit flags combined with `|`. `BarcodeFormat` is
an enum; pass a `Set` where several are allowed. A base symbology includes
its variants: `{BarcodeFormat.qrCode}` also finds Micro QR and rMQR codes.

UPC-A and UPC-E are reported as printed: a UPC-A as `BarcodeFormat.upcA`
with 12 digits (3.x gave an EAN-13 starting with 0), a UPC-E with its 8
digits (3.x gave 13). Asking for EAN-13 alone still gives EAN-13.

| 3.x | 4.0 |
|---|---|
| `Format.any` | `null` (all formats) |
| `Format.qrCode \| Format.ean13` | `{BarcodeFormat.qrCode, BarcodeFormat.ean13}` |
| `Format.linearCodes` | `BarcodeFormat.linear` |
| `Format.matrixCodes` | `BarcodeFormat.matrix` |
| `zx.barcodeFormatName(format)` | `format.displayName` |

## From 4.0.0-rc.2

The API changed in a few places between the release candidates and the
release. The analyzer finds each of them; this table gives
the new form. The rows from `ScannerStrings` on are new in rc.5.

| rc.x | Now |
|---|---|
| `BarcodeView(data, format:, errorCorrection:, gs1:, showText:)` | `BarcodeView(data, writer: BarcodeWriter(format, errorCorrection:, gs1:, showText:))` |
| `BarcodeWriter(quietZone: false)` | `BarcodeStyle(quietZone: false)`, or `symbol.toPng(quietZone: false)` |
| `BarcodeWriter(options: 'ecLevel=H')` | `BarcodeWriter(zxingOptions: 'ecLevel=H')`; it wins over `errorCorrection` and `version` |
| `symbol.toSvg()`: one unit per module | `toSvg(size:, moduleSize:)` in pixels, 4 per module by default; `toPng(size:)` is the exact long side |
| `showText: false` by default | `null`: on for EAN, UPC and ISBN |
| `reader.readAll(bytes, limit: 5)` | `reader.readAll(bytes, maxBarcodes: 5)`, also `readAllPixels` |
| `Barcode.merge(parts)` | `await reader.merge(parts)` |
| `barcode.orientation` | `barcode.rotation` |
| `format.input.digits` | `format.input.digitsOnly` |
| `formats: {}` read every format | throws `ArgumentError`; `null` reads every format |
| `formats: {BarcodeFormat.isbn}`, `ean2`, `ean5` | `ean13`; add-ons with `ReaderOptions(eanAddOn:)` |
| `style.copyWith(logo: null)` kept the logo | `style.copyWith(logo: () => null)` removes it |
| `template.copyWith(title: 'Pay')` | `template.copyWith(title: () => 'Pay')` |
| `template.copyWith(onClose: () {})` | `template.copyWith(onClose: () => () {})`; `() {}` alone does not compile, and `onClose` and `onOpenSettings` cannot be cleared |
| `ScannerController(pauseInBackground:)` | `ScannerController(stopInBackground:)` |
| `resultBuilder: (context, barcode, scanAgain) => ...` | `resultBuilder: (context, result) => ...`, with `result.barcode`, `result.scanAgain` |
| `actionsBuilder: (context, barcode, scanAgain) => [...]` | `actionsBuilder: (context, result) => [...result.defaultActions, ...]` |
| `BarcodeResultSheet(showIcon:, showPicture:, asCard:)` | `BarcodeResultSheet(header: ResultHeader.icon)`, `.picture`, `.card` or `.none` |
| `ScannerTemplate(showResultIcon:, resultAsCard:)` | `ScannerTemplate(resultHeader:)` |
| `ScannerChip(danger: true)`, `ScannerBadge(warning: true)` | `ScannerChip(tone: ScannerTone.danger)`, `ScannerBadge(tone: ScannerTone.warning)` |
| `ScanStatus.accepted`, `warning`, `rejected`; `verdict.status` | `ScanVerdictKind.accept`, `warn`, `reject`; `verdict.kind` |
| `BarcodeContent.parse(barcode)` | `barcode.content` |
| `expiry`, `bestBefore`, `birthday`, `dateOfBirth` | `expiryDate`, `bestBeforeDate`, `birthDate` |
| `EpcPaymentContent(text:)` | `EpcPaymentContent(message:)` |
| `SwissQrBillContent(referenceType:, qrReference:)` | `SwissQrBillContent(creditorReference:)`; the type follows from it |
| `ProductContent.gtin` as printed | `ProductContent.number`; `gtin` is a GTIN-14 |
| `CryptoContent.amount` in wei (Ethereum) | `amount` in ether; wei in `value` |
| An exhaustive `switch` on `BarcodeContent` | add a `default`: new kinds come in minor versions |
| `ScannerStrings(close: ...)`, `strings.copyWith(...)` | A subclass of `ScannerLocalizationsEn` (or `ScannerLocalizationsRu`) that overrides the texts; see [Change a text](/scanning/theming#change-a-text) |
| `strings:` on `ScannerScope`, `BarcodeScanner`, `scanBarcode`, `openScanner`, `scanContent`, `ScanFieldButton` | `texts:`, a `ScannerLocalizations` |
| `ScannerStrings.of(context)` | `ScannerLocalizations.of(context)` |
| `strings.wifiSecurity(security)`, `strings.vinRegion(region)`, `strings.amount(amount, currency)` | `texts.wifiSecurityOf(security)`, `texts.vinRegionOf(region)`, `texts.amountOf(amount, currency)` |
| `ScannerTheme.of(context).glassStrongColor` | `.sheetColor`, set with `ScannerTheme(sheet:)` |
| `result.close` in `actionsBuilder` and `resultBuilder` | `result.backToCodes`: back to the codes of `ScannerTemplate.pick()`; it does not close the scanner, `result.finish()` does |
| `ScannerAction.copy(text, icon: ...)` | `ScannerAction.copy(text)`; its icons come from `ScannerTheme(icons: ScannerIconSet(copy: ..., copied: ...))` |
| `style.encodePng(writer, data, size: 1024)`, also `encode`, `encodeBytes`, `encodeSvg` | `style.encodePng(data, writer: writer, size: 1024)`; without `writer`, a QR code |
| `leg.dateIn(DateTime.now().year)` | `leg.date()`, which picks the year: a pass for 2 January scanned on 30 December is for next year |

Behaviour that changed without a compile error:

- The default result sheet shows the title and message of a check's
  accepted or flagged verdict under the code. A sheet with your primary
  button and the default buttons fills only the first primary button with
  the accent.
- The scanner's texts follow the app's locale: an app whose locale is
  Russian shows them in Russian («31 авг. 1977»). English dates read
  "Aug 31, 1977" and "Nov 14" instead of "31 Aug 1977" and "14 Nov".
- `barcode.rotation` of camera captures is in screen orientation, like the
  corners.
- Images over 128 megapixels or 65535 pixels a side throw
  `ImageDecodeException`; a `PixelBuffer.crop` outside the image finds
  nothing.
- `zxingOptions` that zxing-cpp cannot parse throw `ArgumentError`.
- Phone numbers with letters, EPC codes with a wrong RF reference and SPAYD
  codes with a wrong `CRC32` are `TextContent`; contacts keep only http and
  https web addresses.
