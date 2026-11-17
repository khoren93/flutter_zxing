# flutter_zxing

Scan and create QR codes and barcodes in Flutter, on Android, iOS, macOS,
Linux, Windows and the web, with [zxing-cpp](https://github.com/zxing-cpp/zxing-cpp)
built into your app.

- **A complete scanner screen in one line**, or just the camera and your own UI.
- **42 formats to read, 30 to create**, the same on every platform.
- **Barcodes as widgets:** sharp at any size, styled, exported to PNG and SVG.
- **Knows what is inside:** URLs, Wi-Fi, contacts, events, GS1 data, as Dart types.
- **No ML Kit, no Google Play services, no network.**

**[Try it in your browser](https://khoren93.github.io/flutter_zxing/)** — the
demo app of this repository, running on the web build of the package.

---

- [Why flutter_zxing](#why-flutter_zxing)
- [Quick start](#quick-start)
- [Installation](#installation)
- [Scanning](#scanning)
- [Reading images](#reading-images)
- [Creating barcodes](#creating-barcodes)
- [What is in the barcode](#what-is-in-the-barcode)
- [Formats](#formats)
- [Platforms](#platforms)
- [Benchmarks](#benchmarks)
- [Compared with mobile_scanner](#compared-with-mobile_scanner)
- [Upgrading from 3.x](#upgrading-from-3x)
- [Contributing](#contributing)

## Why flutter_zxing

- **Works without Google.** The engine is zxing-cpp, compiled into your app.
  It runs on Huawei devices without Google services, on de-Googled phones and
  in F-Droid builds, offline. Images and camera frames never leave the device.
- **Formats ML Kit does not read:** Micro QR, rMQR, DataBar (Expanded,
  Limited), MaxiCode, MicroPDF417, DX Film Edge and Telepen.
- **Scanning and generation in one package**, with one format list for both.
- **One engine everywhere.** The same C++ code reads on a phone, a desktop and
  in the browser (WebAssembly in a Web Worker), so a code that reads on one
  platform reads on the others.
- **Never blocks the UI.** Every call that touches the engine runs on a
  background isolate or worker and returns a `Future`. A 12-megapixel photo is
  read without a single dropped frame.

## Quick start

```dart
import 'package:flutter_zxing/flutter_zxing.dart';

// A full scanner screen: camera, buttons, hints and a result sheet.
BarcodeScanner(
  template: const ScannerTemplate.minimal(),
  onDetect: (capture) => print(capture.barcode.text),
)

// A QR code.
const BarcodeView('https://pub.dev/packages/flutter_zxing', width: 200)
```

## Installation

```bash
flutter pub add flutter_zxing:^4.0.0-rc.1
```

The package compiles zxing-cpp with a build hook: no CMake, CocoaPods or
Gradle setup. The first build takes a minute longer; later builds use the
cache. On the web, the WebAssembly engine ships inside the package as an
asset and is only added to web builds.

Requires Flutter 3.41 or newer.

**Camera permission.** Android needs nothing (the `camera` plugin declares
the permission). iOS needs `NSCameraUsageDescription` in `ios/Runner/Info.plist`,
and `NSPhotoLibraryUsageDescription` if users pick photos to scan:

```xml
<key>NSCameraUsageDescription</key>
<string>Scans barcodes</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Reads barcodes from your photos</string>
```

On the web the camera works on pages served over HTTPS (or `localhost`).
For the camera on macOS, Linux and Windows, see [Camera on desktop](#camera-on-desktop).

## Scanning

### A ready-made screen

`BarcodeScanner(template: ...)` puts a whole screen around the camera: glass
buttons (close, torch, photo, zoom, camera switch), a hint, brackets that lock
onto the code, and a sheet with what the code holds and what to do with it.

| Template | For |
|---|---|
| `ScannerTemplate.minimal()` | Any code, with a sheet that shows what is in it; the default |
| `ScannerTemplate.payment()` | Paying with a QR code: the window high up, your payment sheet below |
| `ScannerTemplate.retail()` | Product and shipping barcodes in a row: dark glass, the torch, a list with counts |
| `ScannerTemplate.ticket()` | Boarding passes, tickets and IDs (PDF417, Aztec, QR, Data Matrix), your sheet with the fields |
| `ScannerTemplate.content()` | Everyday QR codes (links, Wi-Fi, contacts, events): dark glass, your actions such as "Open" or "Connect" |

`ScannerTheme` sets your accent color, the shape of the scan window and
buttons, and light or dark glass. `ScannerStrings` translates every text.

```dart
BarcodeScanner(
  template: const ScannerTemplate.minimal(),
  theme: const ScannerTheme(
    accent: Color(0xFFFF6A1A),
    windowRadius: 6,
    buttonShape: ScannerButtonShape.roundedSquare,
  ),
  onDetect: (capture) => print(capture.barcode.content),
)
```

To scan one code and come back with it:

```dart
final Barcode? barcode = await scanBarcode(
  context,
  formats: {BarcodeFormat.qrCode},
  hint: 'Point the camera at a QR code',
);
```

### Your own UI

Without a template, `BarcodeScanner` shows the camera with a scan window, and
`overlayBuilder` draws the rest. `ScannerLayout` gives the scan window and
each barcode's corners already in widget coordinates. The pieces of the
templates (`ScannerOverlay`, `TorchButton`, `SwitchCameraButton`,
`ZoomButtons`, `ScannerSheet`, `BarcodeResultSheet`, ...) are public.

```dart
final controller = ScannerController(
  formats: {BarcodeFormat.qrCode, BarcodeFormat.ean13},
  scanWindow: const ScanWindow.centered(width: 0.8, aspectRatio: 1.6),
);

BarcodeScanner(
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
)
```

`ScannerController` is a `ValueNotifier<ScannerState>`: listen to it for the
camera status, torch, zoom and errors. It controls the torch, zoom, focus and
camera, and its `formats`, `options`, `scanWindow`, `detection` and
`maxBarcodes` can change while the camera runs. A controller you create is
yours to `dispose()`; without one, `BarcodeScanner` makes its own.

- `detection`: `DetectionMode.distinct` (the default) reports each code once,
  and again after it has left the frame; `continuous` reports every frame;
  `once` pauses after the first capture.
- `maxBarcodes`: 1 by default, which is several times faster on a frame with
  a code; `null` finds every code in the frame.
- `await capture.snapshot()` gives the barcode cut out of the frame and
  straightened, as an image (Android and iOS).

### Small or dense codes

Only the scan window of each frame is read. The default camera resolution,
`CameraResolution.hd` (1280×720), is plenty for QR codes on screens and
labels. For a dense Data Matrix or a long GS1 DataBar, give the decoder more
pixels:

```dart
ScannerController(
  resolution: CameraResolution.fullHd,
  scanWindow: const ScanWindow.centered(width: 0.9),
)
```

### Automatic zoom (iPhone)

On iPhones the scanner picks the camera by itself from where the lens is
focused: the ultra-wide camera (0.5×, `ScannerState.minZoom`) when a code is
too close for the main camera to focus, 2× and then the telephoto camera
(`ScannerState.telephotoZoom`) when it is far. It never switches while codes
are being read. Zooming by hand turns it off, and the "Auto" button of
`ZoomButtons` turns it back on:

```dart
controller.setAutoZoom(false); // or ScannerController(autoZoom: false)
```

Android, the desktop and the web keep the zoom where it is set: their cameras
do not report their focus.

### Camera on desktop

The `camera` package has no desktop implementations. Add
[`camera_desktop`](https://pub.dev/packages/camera_desktop) to your app and
`BarcodeScanner` works on macOS and Linux unchanged:

```yaml
dependencies:
  camera_desktop: ^2.0.0
```

- **macOS:** add `NSCameraUsageDescription` to `macos/Runner/Info.plist`, and,
  for a sandboxed app, `com.apple.security.device.camera` to both entitlements
  files (see `example/macos/Runner`).
- **Linux:** install the GStreamer development packages
  (`libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-good`).
- **Windows:** not verified yet.

Reading images and creating barcodes need nothing extra on desktop.

## Reading images

`BarcodeReader` reads image files (PNG, JPEG, GIF, BMP; on the web, anything
the browser decodes) and raw pixel buffers, on every platform, without a
camera:

```dart
const reader = BarcodeReader();
final Barcode? first = await reader.read(bytes);     // stops at the first code
final List<Barcode> all = await reader.readAll(bytes);

const qrOnly = BarcodeReader(formats: {BarcodeFormat.qrCode});
```

`readPixels` and `readAllPixels` read frames from anywhere else (video, a
network stream, another camera plugin):

```dart
const reader = BarcodeReader(options: ReaderOptions.camera());
final Barcode? barcode = await reader.readPixels(
  PixelBuffer(yPlane, width: width, height: height, rowStride: stride),
);
```

"Not found" is `null` or an empty list. Exceptions are for errors only (a
broken image, no camera access), all subclasses of the sealed
`ZxingException`.

## Creating barcodes

`BarcodeView` draws a barcode as vectors, sharp at any size:

```dart
const BarcodeView('https://pub.dev', width: 200)

const BarcodeView(
  '4006381333931',
  format: BarcodeFormat.ean13,
  showText: true,
  width: 240,
)
```

`BarcodeStyle` sets colors or a gradient, square, rounded or dot modules,
square, rounded or round QR finder patterns, and a logo in the middle of a QR
code (error correction goes up to H by itself). Every style is checked to read
back with this package's reader. Ready-made styles: `BarcodeStyle.soft`,
`dots`, `lagoon`, `ink`, `night`.

```dart
BarcodeView(
  'https://flutter.dev',
  width: 200,
  style: const BarcodeStyle(
    moduleShape: ModuleShape.rounded,
    finderShape: FinderShape.rounded,
    logo: BarcodeLogo(AssetImage('assets/logo.png')),
  ),
)
```

`BarcodeStyle` exports PNG and SVG with the same look. `BarcodeWriter` on
its own exports them black on white (`writer.toPng(data)`,
`writer.toSvg(data)`), or gives the module matrix to draw yourself:

```dart
const writer = BarcodeWriter(BarcodeFormat.qrCode);
const style = BarcodeStyle.lagoon;
final Uint8List png = await style.encodePng(writer, 'https://pub.dev', size: 1024);
final String svg = await style.encodeSvg(writer, 'https://pub.dev');

final BarcodeSymbol symbol = await const BarcodeWriter(BarcodeFormat.dataMatrix)
    .encodeBytes(Uint8List.fromList([0x00, 0x01, 0xFE, 0xFF]));
```

Data a format cannot hold throws a `BarcodeWriteException` that says why
(`Invalid check digit '4', expecting '3'`). `format.input` describes what
each format holds, with an example, for forms and hints.

## What is in the barcode

`barcode.content` parses the text into a sealed type to `switch` on. Parsing
never throws: anything unrecognised is `TextContent` or `BinaryContent`.

```dart
switch (barcode.content) {
  case UrlContent(:final url):
    launchUrl(url);
  case WifiContent(:final ssid, :final password):
    connect(ssid, password);
  case ContactContent contact:
    save(contact);
  case Gs1Content(:final gtin):
    lookUp(gtin);
  default:
    print(barcode.text);
}
```

Also payments (SEPA/EPC, Swiss QR-bill, ГОСТ Р 56042, UPI, PIX and other
EMVCo codes, SPAYD, all as `PaymentContent`), e-mail, phone and FaceTime,
SMS, locations, events, one-time passwords (`otpauth://`), eSIM activation codes, cryptocurrency payments,
Wi‑Fi Easy Connect, Matter and HomeKit setup codes, boarding passes, US
driver's licenses, VINs and products (EAN/UPC with ISBN and ISSN). The full
list, with what each kind holds: [doc/content-types.md](doc/content-types.md).

The other way round, every kind builds the text for a code, escaped as its
format needs, and parsing reads it back as an equal value:

```dart
const wifi = WifiContent(ssid: 'Home', password: 'secret;12');
BarcodeView(wifi.toPayload()); // WIFI:T:WPA;S:Home;P:secret\;12;;

final issues = wifi.validate(); // for forms: field and message, no throw

BarcodeView(LinkService.whatsApp.link('+374 91 234567').toPayload());
```

## Formats

| Linear product | Linear industrial | Matrix |
|---|---|---|
| EAN-13, EAN-8 | Code 128 | QR Code |
| UPC-A, UPC-E | Code 39 (Standard, Extended) | Micro QR Code |
| EAN-2, EAN-5 add-ons ᴿ | Code 32, PZN | rMQR Code |
| ISBN | Code 93 | Data Matrix |
| DataBar, DataBar Limited | Codabar | Aztec, Aztec Rune |
| DataBar Expanded | ITF, ITF-14 ᴿ | PDF417, MicroPDF417 |
| | Telepen | MaxiCode ᴿ |
| | DX Film Edge | |

ᴿ read only. `BarcodeFormat.writable` lists the formats to create, for a
format picker. Engine: zxing-cpp 3.1.1 (`zxingCppVersion`).

MaxiCode is read from clean images only (a code without background, not
skewed), not from the camera: a limit of zxing-cpp.

## Platforms

| Platform | Read and create | Camera scanner |
|---|---|---|
| Android | ✅ | ✅ |
| iOS | ✅ | ✅ |
| Web | ✅ | ✅ Chrome, Safari, Firefox |
| macOS | ✅ | ✅ with [`camera_desktop`](#camera-on-desktop) |
| Linux | ✅ | ✅ with [`camera_desktop`](#camera-on-desktop) |
| Windows | ✅ | not verified |

## Benchmarks

Release builds. The full tables, the raw data and how to repeat each run are
in [benchmark/BENCHMARKS.md](benchmark/BENCHMARKS.md).

**Images.** 32 images from zxing-cpp's test corpus, mean time per image; and
a 12-megapixel photo with a small, dense QR code
([#74](https://github.com/khoren93/flutter_zxing/issues/74)), default
settings.

| | 3.1.1 | 4.0 |
|---|---|---|
| 32 images, MacBook | 4.8 ms | **0.6 ms** |
| 32 images, Pixel 4a | 15.8 ms | **1.6 ms** |
| 12 MP photo, MacBook | not found; UI frozen 374 ms | **found in 103 ms**, UI not blocked |
| 12 MP photo, Pixel 4a | not found; UI frozen 1.0 s | **found in 219 ms**, UI not blocked |
| 12 MP photo, Chrome (WebAssembly) | not supported | found in 204 ms |

**Camera.** The phone held on a QR code until 1000 frames with the code were
decoded (after 20 warm-up frames). Scan window 60% × 80% of the frame,
1280×720 frames. *Scan latency* is from the frame arriving in Dart to its
barcodes being back on the UI isolate: copying the scan window, decoding,
both isolate hops. It excludes the camera's own exposure and processing,
which the `camera` plugin does not report.

| Device | Decoded per second | Frames skipped | Scan latency avg / p95 | UI frames over 16 ms |
|---|---|---|---|---|
| iPhone 17 Pro Max | 30 | 0 | 2.6 / 3.6 ms | 0 of 1073 |
| Pixel 4a (2020) | 24.9 | 0 | 3.0 / 9.5 ms | 0 of 1246 |
| Safari, MacBook camera | 30 | — | 9.6 / 12 ms | 0 of 1140 |
| Safari, iPhone 17 Pro Max | 30 | — | 9.0 / 12 ms | 0 of 1129 |

Every frame the camera delivered was decoded: the decoder takes 2–4 ms of the
33–40 ms between frames. The camera's frame rate is the limit, which is why a
camera of the package's own is planned for 4.1.

**App size** added to an empty app (scanner, reading and creating used):

| | 3.1.1 | 4.0 |
|---|---|---|
| Android APK, per ABI (arm64 / armv7 / x86_64) | +6.1 / 6.0 / 6.3 MB | **+2.7 / 2.6 / 2.9 MB** |
| iOS `.app`, compressed | +2.2 MB | **+1.0 MB** |
| Web, brotli | — | 312 KB to read; the 507 KB full module loads when a code is first created |

The image numbers and the app size were measured on the 4.0 engine before it
moved into this repository; the released engine was measured again on the
same MacBook within 5%.

## Compared with mobile_scanner

[mobile_scanner](https://pub.dev/packages/mobile_scanner) is the most used
scanner package for Flutter. Both are good choices; they make different
trade-offs.

| | flutter_zxing 4.0 | mobile_scanner 7 |
|---|---|---|
| Decoder | zxing-cpp on every platform | ML Kit (Android), Apple Vision (iOS, macOS), the browser's `BarcodeDetector` or zxing-wasm (web) |
| Google Play services | Never | Not by default (bundled ML Kit); the smaller "unbundled" option needs them |
| Network | Never | The web build loads zxing-wasm from a CDN when the browser has no `BarcodeDetector` |
| Android size | +2.7 MB per ABI | +3–10 MB bundled, ~0.6 MB unbundled |
| Platforms | Android, iOS, macOS, Linux, Windows, web | Android, iOS, macOS, web |
| Creates barcodes | Yes: widget, PNG, SVG, styles | No |
| Formats | 42 to read, the same on every platform | Depends on the platform's decoder; ML Kit on Android reads 13 (no Micro QR, rMQR, DataBar, MaxiCode, MicroPDF417) |
| Parsed content | Sealed Dart types, the same on every platform | From the platform's decoder |
| Scanner UI | Five templates and themable pieces, or your own | Your own (`overlayBuilder`) |
| Camera | The `camera` plugin: frames pass through Dart (only the scan window is copied); up to 30 fps | Native camera, frames stay native |

Where mobile_scanner is ahead:

- **Hard codes.** ML Kit and Apple Vision are machine-learning decoders. They
  tend to read damaged, blurred, curved and low-contrast codes that a classic
  decoder like zxing-cpp misses, and find codes from further away.
- **The camera.** Frames never reach Dart, so the frame rate is the camera's;
  ours is limited by how fast the `camera` plugin delivers frames (25 fps on a
  Pixel 4a). Our own native camera is planned for 4.1.
- **Maturity.** It has more users and more years on more devices.

Choose flutter_zxing when Google services, offline use or privacy matter,
when you need formats ML Kit does not read, Linux or Windows, the same results
on every platform, or barcode generation in the same package.

Coming from mobile_scanner: [the API, side by side](doc/migrating-from-mobile_scanner.md).

## Upgrading from 3.x

The 3.x API (`zx`, `ReaderWidget`, `WriterWidget`, `Code`, `DecodeParams`, ...)
keeps working in 4.x, on the new engine, and is deprecated until its removal
in 5.0. Each deprecated declaration names its replacement. After upgrading,
run `flutter clean` once.

[Migrating to 4.0](doc/migrating-to-4.0.md) shows the replacements side by
side; the [CHANGELOG](CHANGELOG.md) lists the few behaviour changes.

## Layers

The package is zxing-cpp for Flutter first. Everything else is a layer on
top of that core, and each layer can be imported on its own:

| Import | What it has |
|---|---|
| `package:flutter_zxing/core.dart` | zxing-cpp: `BarcodeReader`, `BarcodeWriter`, `Barcode`, `BarcodeFormat`, `ReaderOptions`, `BarcodeSymbol` with plain SVG and PNG |
| `package:flutter_zxing/content.dart` | `barcode.content`: parsed URLs, Wi-Fi, contacts, events, GS1…; `toPayload()` builds them |
| `package:flutter_zxing/rendering.dart` | `BarcodeView`, `BarcodeStyle` and styled export |
| `package:flutter_zxing/scanner.dart` | `BarcodeScanner`, `ScannerController`, templates, themes, widgets |
| `package:flutter_zxing/flutter_zxing.dart` | all of the above and the deprecated 3.x API |

Each layer exports the ones it builds on. The core never depends on the
layers above it.

## Contributing

Bug reports, ideas and pull requests are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md) for how to build the package, run the
demo and the tests.

## License

MIT. See [LICENSE](LICENSE). zxing-cpp is licensed under Apache 2.0
([third_party/zxing-cpp/LICENSE](third_party/zxing-cpp/LICENSE)).
