<div align="center">

# flutter_zxing

**Scan and create QR codes and barcodes in Flutter.**<br>
32 formats on Android, iOS, macOS, Linux, Windows and the web, a ready-made
scanner you can brand, and styled codes to show, export and print.<br>
Powered by [zxing-cpp](https://github.com/zxing-cpp/zxing-cpp): no ML Kit, no Google Play services, no network.

[![pub version](https://img.shields.io/pub/v/flutter_zxing.svg?label=pub&color=0175C2)](https://pub.dev/packages/flutter_zxing)
[![pub likes](https://img.shields.io/pub/likes/flutter_zxing?color=0175C2)](https://pub.dev/packages/flutter_zxing/score)
[![pub points](https://img.shields.io/pub/points/flutter_zxing?color=0175C2)](https://pub.dev/packages/flutter_zxing/score)
[![CI](https://github.com/khoren93/flutter_zxing/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/khoren93/flutter_zxing/actions/workflows/main.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/khoren93/flutter_zxing/blob/main/LICENSE)

[![Documentation](https://img.shields.io/badge/Documentation-1FB98A?style=for-the-badge&logo=readthedocs&logoColor=white)](https://khoren93.github.io/flutter_zxing/)
[![Live demo](https://img.shields.io/badge/Live_demo-0B1220?style=for-the-badge&logo=flutter&logoColor=white)](https://khoren93.github.io/flutter_zxing/demo/)
[![Templates](https://img.shields.io/badge/16_templates-0B1220?style=for-the-badge)](https://khoren93.github.io/flutter_zxing/templates)
[![API reference](https://img.shields.io/badge/API_reference-0B1220?style=for-the-badge&logo=dart&logoColor=white)](https://pub.dev/documentation/flutter_zxing/latest/)

<img src="https://khoren93.github.io/flutter_zxing/shots/laser.png" width="130" alt="Scanning with a scan line">
<img src="https://khoren93.github.io/flutter_zxing/shots/pick.png" width="130" alt="Several codes labelled in view">
<img src="https://khoren93.github.io/flutter_zxing/shots/check-in-ok.png" width="130" alt="Check-in template with an accepted ticket">
<img src="https://khoren93.github.io/flutter_zxing/shots/ticket.png" width="130" alt="Boarding pass read and shown">
<img src="https://khoren93.github.io/flutter_zxing/shots/create.png" width="130" alt="A styled Wi‑Fi QR code made in the app">
<img src="https://khoren93.github.io/flutter_zxing/shots/label-sheet.png" width="130" alt="A sheet of numbered labels to print">

</div>

## Features

- **A complete scanner in one line.** 16 ready-made templates (payments,
  tickets, check-in, retail, pharma, logistics, kiosk…) with a result sheet,
  or just the camera and your own UI.
- **Your brand's look.** Accent, scan window, scan line, glass, buttons,
  icons and text styles; texts in English, Russian, German, Spanish, French
  and Chinese, following the app's language.
- **32 formats to read, 30 to create**, the same on every platform, including
  Micro QR, rMQR, DataBar, MaxiCode and MicroPDF417, which ML Kit does not read.
- **Knows what is inside.** URLs, Wi‑Fi, contacts, events, payments (SEPA,
  Swiss QR-bill, UPI, PIX…), GS1, boarding passes, driver's licenses and more,
  as Dart types; and builds them back into codes.
- **Barcodes as widgets.** Sharp at any size, with colors, gradients,
  rounded or dot modules and a logo; exported to PNG and SVG, or laid out on
  label sheets as PDF.
- **Private and fast.** Everything runs on the device, off the UI thread,
  in WebAssembly on the web. Every camera frame is decoded in 2–4 ms.

<p align="center">
  <img src="https://khoren93.github.io/flutter_zxing/codes/style-soft.png" width="110" alt="Soft style">
  <img src="https://khoren93.github.io/flutter_zxing/codes/style-dots.png" width="110" alt="Dots style">
  <img src="https://khoren93.github.io/flutter_zxing/codes/style-lagoon.png" width="110" alt="Lagoon style">
  <img src="https://khoren93.github.io/flutter_zxing/codes/style-night.png" width="110" alt="Night style">
  <img src="https://khoren93.github.io/flutter_zxing/codes/logo.png" width="110" alt="QR code with a logo">
  <img src="https://khoren93.github.io/flutter_zxing/codes/caption-card.png" width="96" alt="QR code on a card with a caption">
</p>

## Quick start

```bash
flutter pub add flutter_zxing
```

```dart
import 'package:flutter_zxing/scanner.dart';

// Scan one code and come back with it (null if the user closes the scanner).
final Barcode? barcode = await scanBarcode(context);

// A scanner screen in your own page: camera, buttons, hints and a result sheet.
BarcodeScanner(
  template: const ScannerTemplate.minimal(),
  onDetect: (capture) => print(capture.barcode.text),
)

// A QR code.
const BarcodeView('https://pub.dev/packages/flutter_zxing', width: 200)
```

`scanner.dart` is the whole 4.0 API; `flutter_zxing.dart` adds the
deprecated 3.x API. No CMake, CocoaPods or Gradle setup: a build hook
compiles the engine.
Requires Flutter 3.41 or newer. Add the camera permission on
[iOS and Android](https://khoren93.github.io/flutter_zxing/guide/installation),
and see [Platforms](https://khoren93.github.io/flutter_zxing/guide/platforms)
for the web and desktop.

## Documentation

| | |
|---|---|
| **Scanning** | [Scan one code](https://khoren93.github.io/flutter_zxing/scanning/scan-one-code) · [Templates](https://khoren93.github.io/flutter_zxing/scanning/templates) · [Colours and texts](https://khoren93.github.io/flutter_zxing/scanning/theming) · [Your own UI](https://khoren93.github.io/flutter_zxing/scanning/custom-ui) · [The controller](https://khoren93.github.io/flutter_zxing/scanning/controller) |
| **Images** | [Read an image](https://khoren93.github.io/flutter_zxing/reading/images) · [Reader options](https://khoren93.github.io/flutter_zxing/reading/options) |
| **Creating** | [Barcodes as widgets](https://khoren93.github.io/flutter_zxing/creating/barcode-view) · [Styles and logos](https://khoren93.github.io/flutter_zxing/creating/styles) · [PNG and SVG](https://khoren93.github.io/flutter_zxing/creating/export) · [Label sheets](https://khoren93.github.io/flutter_zxing/creating/label-sheets) · [Many codes](https://khoren93.github.io/flutter_zxing/creating/batches) |
| **Content** | [What is in a code](https://khoren93.github.io/flutter_zxing/content/overview) · [Payments](https://khoren93.github.io/flutter_zxing/content/payments) · [Building content](https://khoren93.github.io/flutter_zxing/content/building) |
| **Recipes** | [Use cases](https://khoren93.github.io/flutter_zxing/use-cases): 26 screens to copy, from tickets at the door to a Wi‑Fi card for guests |
| **Reference** | [Formats](https://khoren93.github.io/flutter_zxing/formats) · [Accuracy and speed](https://khoren93.github.io/flutter_zxing/more/accuracy-and-speed) · [API reference](https://pub.dev/documentation/flutter_zxing/latest/) |

## Platforms

| | Android | iOS | Web | macOS | Linux | Windows |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Read images and create codes | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Camera scanner | ✅ | ✅ | ✅ | ✅ ᶜ | ✅ ᶜ | ✅ ᶜ |

ᶜ with [`camera_desktop`](https://pub.dev/packages/camera_desktop).
The web runs the same engine as WebAssembly in a Web Worker, in Chrome,
Safari and Firefox.

## Performance

- **Every camera frame decoded:** 30 per second on an iPhone 17 Pro Max,
  25 on a Pixel 4a (2020), no frame skipped and no UI frame late.
- **A 12-megapixel photo** with a small QR code is read in about 0.1 s on a
  MacBook and 0.2 s on a Pixel 4a, without blocking the UI.
- **Small:** +2.7 MB per Android ABI, +1.0 MB on iOS, 312 KB on the web.

All numbers and how they were measured: [Accuracy and speed](https://khoren93.github.io/flutter_zxing/more/accuracy-and-speed#measured).

## Why flutter_zxing

Choose it when Google services, offline use or privacy matter, when you need
formats ML Kit does not read, Linux or Windows, the same results on every
platform, or scanning and generation in one package. Machine-learning
scanners such as mobile_scanner read damaged and far-away codes better; the
[honest comparison](https://khoren93.github.io/flutter_zxing/more/from-mobile-scanner)
covers both sides and maps its API to ours.

## Upgrading from 3.x

The 3.x API keeps working in 4.x on the new engine, deprecated until 5.0;
each deprecated name points to its replacement. See
[Upgrading from 3.x](https://khoren93.github.io/flutter_zxing/more/upgrading-from-3x)
and the [CHANGELOG](https://github.com/khoren93/flutter_zxing/blob/main/CHANGELOG.md).

## Contributing

Bug reports, ideas and pull requests are welcome. See
[CONTRIBUTING.md](https://github.com/khoren93/flutter_zxing/blob/main/CONTRIBUTING.md)
to build the package and run the demo and the tests.

## License

MIT, see [LICENSE](https://github.com/khoren93/flutter_zxing/blob/main/LICENSE).
zxing-cpp is licensed under Apache 2.0.
