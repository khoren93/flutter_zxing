# Changelog

## Unreleased

### Breaking changes

* The scanner's texts are translated: `ScannerStrings` is now
  `ScannerLocalizations`, and `strings:` is `texts:` on `ScannerScope`,
  `BarcodeScanner`, `scanBarcode`, `openScanner`, `scanContent` and
  `ScanFieldButton`. To change a text, subclass a translation:
  `class MyTexts extends ScannerLocalizationsEn { … }`.
* `ScannerResult.close` is now `backToCodes`: it goes back to the codes of
  `ScannerTemplate.pick()`, it does not close the scanner.
* `ScannerAction.copy(...)` has no `icon` of its own: its copy and copied
  icons come from the theme (`ScannerTheme(icons: ScannerIconSet(copy:,
  copied:))`).
* `BarcodeStyle.encode`, `encodeBytes`, `encodePng` and `encodeSvg` take the
  writer as a named parameter, QR by default:
  `style.encodePng('https://pub.dev', size: 1024)`.
* `BoardingPassLeg.dateIn(year)` is now `date()`, which picks the year: a
  pass for 2 January scanned on 30 December is for next year.
* `ScannerTheme.glassStrongColor` is now `sheetColor`, the color of the
  sheets that `ScannerTheme(sheet:)` sets.

### New

* The scanner speaks English, Russian, German, Spanish, French and Chinese
  and follows the app's language without any setup. Other languages are one
  translation file away.
* Sheets of labels to print: `BarcodeLabelSheet` lays a list of data out on
  A4, Letter or your own paper in columns and rows, as a PDF or SVG pages,
  with a preview widget. 10 000 codes take about 1.5 seconds.
* `openScanner<T>` opens a template with its result sheet and returns what
  the sheet passes to `result.finish(value)`, such as the customer a loyalty
  card belongs to.
* `scanContent<T>` and `acceptOnly<T>`: accept one kind of content, such as
  a 2FA code or a Wi‑Fi network, and get it typed.
* A check can hand what it found to the result sheet: `ScanVerdict(data:)`,
  read as `result.verdict?.data`, also on collected codes. The default
  sheet shows an accepted or flagged verdict's title and message.
* A `resultBuilder` returns `null` for the default sheet.
* `ScannerAction.scanAgain(result.scanAgain)`, with the text of
  `ScannerLocalizations`.
* Every template takes a title, a hint and its buttons. `hiddenExit`: a
  long press in the corner closes a kiosk without buttons.
* `BarcodeContentView` draws a content with what its standard requires,
  such as the Swiss cross on a QR-bill, and shows why it cannot when the
  data is wrong.
* `BarcodeSymbol.toSvgElement` places a code in an SVG of your own.
* `Gs1Content.contentsGtin`: the GTIN of the goods on a pallet (AI 02).
* Your icons on the scanner: `ScannerTheme(icons: ScannerIconSet(...))`
  replaces any icon of the buttons and sheets, and
  `ScannerIconData.fromIconData(Icons.flash_on)` takes an icon of
  Material, Cupertino or any icon font wherever the scanner takes an icon.
* The scan window in your colours: `ScannerTheme` takes the brackets'
  colour (`window`), their width and length, and the colour of the dimmed
  camera around the window (`scrim`).
* A scan line, like a till's laser, runs across the window while the
  scanner searches: `ScannerTheme(scanLine: ScanLine(color: ...))`, sweeping
  down or bouncing.
* `breathing: false` keeps the window's brackets still.
* The window can be round, `windowShape: ScannerWindowShape.circle`, or
  only its brackets without the dimmed camera around it (`bracketsOnly`).
* Your brand's colors on the buttons, hints and sheets: `glass`, `sheet`
  and `sheetRadius`. An opaque color skips the blur behind it.
* Change the scanner's text styles one by one, such as a bolder title or a
  larger hint: `textStyles: ScannerTextStyles(...)`.
* The outlines of the codes in view take your color and width: `outline`,
  `outlineWidth`.
* `ScannerTemplate.onFeedback` plays your own sound or haptic when a code is
  found, accepted, flagged or refused, instead of the built-in ones.
* Templates move their buttons: `controlsLayout` puts them in a row at the
  bottom, a column beside the window or a row at the top, and
  `torchPosition` puts the torch with them. They keep clear of the window
  in portrait and landscape.
* The demo has a Use cases tab: 26 ways apps use the package, each one file
  to try and copy. Also on the documentation site.

### Fixed

* Automatic zoom keeps a close code big on iPhones: the ultra-wide camera
  at 0.9× instead of 0.5×.
* A result sheet with a primary button of yours and the default buttons
  filled two buttons with the accent; now only the first.

## 4.0.0-rc.4

* A documentation site with a guide to every feature and the demo built in:
  <https://khoren93.github.io/flutter_zxing/>. The demo moved to
  <https://khoren93.github.io/flutter_zxing/demo/>.
* The scanner uses far less energy: on an iPhone 17 Pro Max the demo's
  template takes 70–80 % less, both while searching and with a code in view.
* The scan window and its brackets no longer redraw the screen while a code
  is held still, and the window breathes at 30 frames a second instead of
  the display's full rate.
* A paused scanner, such as under a result sheet, stops taking camera frames
  and keeps only the preview.
* Blur left unset in `ScannerTheme` turns itself off within three seconds on
  a device without room for it: on a Pixel 4a the demo's template went from
  12.6 % of frames late to under 1 %. `blur: true` and `scrimBlur: true` keep
  it on.

## 4.0.0-rc.3

Upgrading from rc.2: see
[From 4.0.0-rc.2](https://khoren93.github.io/flutter_zxing/more/upgrading-from-3x#from-4-0-0-rc-2).

### Breaking changes

* `Barcode.orientation` is now `Barcode.rotation`, as in zxing-cpp 3.2.
* `BarcodeFormat.ean2`, `ean5` and `isbn` report `canRead` false: add-ons are
  read with their EAN-13 or UPC-A, and ISBN is read as EAN-13.
* `Barcode.merge(parts)` is now `await reader.merge(parts)` on a
  `BarcodeReader`.
* An empty format set, `isbn`, `ean2` or `ean5` in `BarcodeReader(formats:)`
  or `ScannerController(formats:)` throws `ArgumentError`. `null` reads every
  format.
* `readAll(limit:)` and `readAllPixels(limit:)` are now `maxBarcodes:`.
  `BarcodeInput.digits` is now `digitsOnly`.
* `BarcodeView` takes a writer: `BarcodeView(data, writer: BarcodeWriter(...))`
  replaces `format`, `errorCorrection`, `gs1` and `showText`.
* `BarcodeWriter.options` is now `zxingOptions`. `BarcodeWriter.quietZone` is
  gone: the quiet zone is `BarcodeStyle(quietZone:)`, or `quietZone:` of
  `toPng`, `toSvg` and `toImage`.
* `BarcodeWriter.showText` follows the format by default: on for EAN, UPC and
  ISBN. SVG exports have their size in pixels, and a PNG's `size` is its long
  side.
* `copyWith` of `BarcodeStyle` and `ScannerTemplate` takes a function for
  fields that can be empty: `copyWith(logo: () => null)` removes the logo. A
  callback needs two: `copyWith(onClose: () => () {})`; `onClose: () {}` no
  longer compiles instead of clearing it.
* `Barcode.rotation` of camera captures is in screen orientation, like the
  corners.
* Images over 128 megapixels or 65535 pixels a side throw
  `ImageDecodeException`. A `PixelBuffer.crop` outside the image finds
  nothing instead of reading the whole image.
* `zxingOptions` that zxing-cpp cannot parse, unknown `eci` names and an
  `ecLevel` of another format throw `ArgumentError`.
* Content is stricter: phone numbers with letters, EPC codes with a wrong RF
  reference and SPAYD codes with a wrong `CRC32` read as text; contacts keep
  only http and https web addresses.
* `ScannerFrameSample.dropped` counts only frames the decoder could not keep
  up with.
* `ScannerController(pauseInBackground:)` is now `stopInBackground`.
* `ScannerResultBuilder` and `ScannerActionsBuilder` get a `ScannerResult`
  instead of the barcode and `scanAgain`.
* `BarcodeResultSheet(showIcon:, showPicture:, asCard:)` and the template's
  `showResultIcon` and `resultAsCard` are now `ResultHeader`. The `warning`
  and `danger` flags of `ScannerChip` and `ScannerBadge` are now `ScannerTone`.
  `ScanStatus` is now `ScanVerdictKind`, and `verdict.status` is `verdict.kind`.
* `BarcodeContent` and `PaymentContent` can get new kinds in minor versions:
  a `switch` over them needs a `default`.
* One name for each idea in content: `expiryDate`, `bestBeforeDate` and
  `birthDate`; `EpcPaymentContent.message`; `SwissQrBillContent.creditorReference`
  (the reference type follows from it). `BarcodeContent.parse` is gone: use
  `barcode.content`.
* `ProductContent.gtin` is always a GTIN-14; the number as printed is
  `ProductContent.number`. `SpaydPaymentContent.currency` is `CZK` when the
  code gives none.

### New

* zxing-cpp 3.2.0-rc1 instead of 3.1.1.
* `ReaderOptions.characterSet`: the character set of codes that do not
  declare one, for example `CharacterSet.cp1251` or `CharacterSet.shiftJis`.
* Images in WebP and every other format Flutter decodes are read.
* `BarcodeContent.uri`: a link to open the content with `url_launcher`.
* `ContentIssue.kind` and `limit`, to show form errors in your own language.
  Wi-Fi networks with WPA3 (`WifiSecurity.wpa3`).
* `BarcodeStyle.encode`, `encodeBytes` and `encodeContent` give a QR code
  under a logo the error correction it needs. `BarcodeCaption.letterSpacing`.
* `ScannerController`: `initialZoom`, `torch`, `fromTemplate` and
  `lastFrameImage()`. `ScannerState.canSwitchCamera` hides the camera switch
  when there is no other camera.
* `CameraInUseException` and `CameraUnsupportedException`, for example on the
  web over plain HTTP.
* `BarcodeScanner(foregroundBuilder:, onOpenSettings:)`. A scanner that is
  hidden, such as on another tab, pauses and releases the camera.
* A `ScannerScope` around the app gives every scanner, `scanBarcode` and
  `ScanFieldButton` its theme and texts. `ScannerStrings.copyWith`, and the
  titles and hints of the presets are in `ScannerStrings`.
* `warmUpBarcodeEngine(scanner: false)` starts only the engine, and never
  fails.
* Readable `toString()` on the reader, writer, options and symbols.

### Fixes

* Joining a structured append sequence keeps a character set that one part
  declares for the next, so text such as `￥` or `€` is no longer garbled.
* `BarcodeView` lines up its modules with the screen's pixels. Codes drawn at
  a fractional pixel ratio or between two pixels are sharp and read again.
* The `BarcodeFormat` documentation says which variants are reported as their
  base format, such as ITF-14 as ITF and Compact PDF417 as PDF417.
* `zxingOptions` win over `errorCorrection` and `version`: `ecLevel=H` was
  lost. A version the format does not have throws instead of being ignored.
* Ethereum amounts are in ether, not wei. A Wi-Fi network without a password
  is open.
* `scanBarcode` keeps the whole template, its buttons and theme included. A
  `check` also works while collecting codes.
* The camera switch does nothing without another camera. After camera access
  was turned on in the settings, the scanner starts when the app returns.
* Scanner buttons are at least 48 pixels to tap, titles grow with the text
  size, and right-to-left layouts are mirrored.
* Stopping and starting the scanner quickly, leaving the page while the
  camera opens or changes lens, or opening it twice on the web no longer
  leaves the camera on or the preview black. A hidden scanner no longer opens
  the camera when the app returns, and a pause made in the background is kept.
* The torch follows a lens change, shows as unavailable on Android phones
  without a flash, and tap to focus on iOS focuses where tapped.
* A barcode on a transparent background reads, including a PNG exported
  without a background. Very wide images no longer throw `ArgumentError`.
* Structured append sequences with Kanji or other segments without ECI join
  correctly. A mirrored QR symbol no longer has a wrong format module.
* `BarcodeView` works inside an `AlertDialog`, `IntrinsicWidth` or `Table`
  and stays sharp after scrolling. PNG and SVG exports draw gradients, EAN
  digits and spaces in text as on screen; several inline SVGs no longer share
  gradients.
* The result sheet names a profile only for profile links, shows dates and
  Wi-Fi Enterprise through `ScannerStrings` (new `wifiEnterprise`), and
  screen readers announce it (`ScannerSheet(liveRegion:)`).
* `ScanVerdict.warn` in single and pick mode shows as a warning.
  `closeOnResult` keeps scanning where the screen cannot close, and
  `resume()` with `showResult: false` is no longer lost.
* Content: EPC codes and vCard 2.1 fields are read in the character set they
  name, EMVCo amounts take three decimals, `sms:` in the iOS form and Matter
  codes with several payloads are read, and `Gs1Content.validate()` checks
  check digits and dates.
* 3.x API: synchronous `zx` calls no longer leak memory on short-lived
  isolates; Aztec and PDF417 get the error correction they had in 3.x.
* The example from pub.dev builds again.
* pub.dev lists macOS, Linux and Windows among the supported platforms.

## 4.0.0-rc.2

### Breaking changes since rc.1

* `ScannerTemplate.collect` is now `ScannerTemplate.mode`: `ScannerMode.single`,
  `collect`, `continuous` or `pick`.
* Styled export moved to `BarcodeStyle`: `style.toSvg`, `toPng`, `encodeSvg` and
  `encodePng`. `BarcodeSymbol` and `BarcodeWriter` now export black on white.
* EAN and UPC codes are `ProductContent` instead of `TextContent`.
  `BarcodeContent` has new kinds, so an exhaustive `switch` needs their cases
  or a `default`.
* UPC-A and UPC-E read as printed: UPC-A is `BarcodeFormat.upcA` with 12 digits,
  UPC-E has 8.
* QR codes use error correction M by default instead of L. Under a logo, the
  level now follows the size of the logo.

### New

* **11 scanner templates:** `product`, `small`, `signIn`, `checkIn`, `pharma`,
  `pick`, `logistics`, `kiosk`, `fullscreen`, `vin` and `loyalty`.
* **Check codes while scanning:** `ScannerCheck` accepts, warns about or rejects
  each code.
* **Scan into a form:** `ScanFieldButton` fills a text field from a barcode.
* **Create codes from content:** `toPayload()` and `writer.encodeContent()` build
  the right text for each kind, and `validate()` reports problems for forms.
* **Payment codes**, read and created: SEPA, Swiss QR-bill, ГОСТ, UPI, SPAYD and
  EMVCo (PIX, PayNow, PromptPay and others).
* **New content kinds:** one-time passwords, eSIM, crypto, Wi‑Fi Easy Connect,
  smart home setup, boarding passes, driver licenses, VIN and products with
  ISBN and ISSN. See [doc/content-types.md](doc/content-types.md).
* **Links to 24 services** with `LinkService`, recognised when scanned.
* **Text and a card around a code:** `BarcodeStyle.title`, `caption` and `card`,
  on screen and in PNG and SVG exports.
* **Automatic zoom on iPhones**, across the ultra-wide, main and telephoto
  cameras.
* **Separate imports:** `core.dart`, `content.dart`, `rendering.dart` and
  `scanner.dart`. `flutter_zxing.dart` still exports everything.

### Improved

* The `pick` template also works on photos, and you can go back to pick another
  code.
* Outlines stay steady, no longer flicker or swap places, and cover the full
  height of linear codes, also in `Code.position` of the 3.x API.
* Result sheets show the details of every new kind, including payments and GS1
  data such as expiry dates.
* The digits under EAN and UPC codes are laid out as printed on real products.

### Fixed

* The cut-out of a code follows the EXIF orientation of a photo.
* Scanner glass outside a scanner follows the platform's brightness.
* QR codes with a logo stay readable when the content is very short.
* Text that only starts like a phone number, SMS or e-mail stays text, and
  bookmarks accept web addresses only.
* The scanner no longer stays paused after returning from the background.

## 4.0.0-rc.1

A new engine and a new API. The 3.x API keeps working on top of the new engine.
After upgrading, run `flutter clean` once.

### New

* **One engine on every platform:** zxing-cpp 3.1.1 on Android, iOS, macOS, Linux
  and Windows, and WebAssembly on the web.
* **New API:** `BarcodeReader` and `BarcodeWriter`, always off the UI thread.
* **30 formats to create**, with clear errors for invalid data.
* **Camera scanning:** `ScannerController` and `BarcodeScanner` on Android, iOS
  and the web, and on macOS and Linux with `camera_desktop`.
* **Ready-made scanner screens:** five templates, a `ScannerTheme` and
  translatable texts.
* **Parsed content:** `barcode.content` turns a payload into URLs, Wi‑Fi, contacts,
  events, GS1 data and more.
* **`BarcodeView`:** sharp barcodes with colors, gradients, module shapes and a
  logo, also exported as PNG and SVG.
* **Pictures of scans:** `capture.snapshot()` and `BarcodeThumbnail` show the code
  that was scanned.
* **Structured append:** `Barcode.merge` joins a message split across several
  codes.

### Deprecated

* The 3.x API (`zx`, `Code`, `DecodeParams`, `ReaderWidget`, `WriterWidget` and
  others) keeps working until 5.0. See
  [Migrating to 4.0](doc/migrating-to-4.0.md) and
  [Coming from mobile_scanner](doc/migrating-from-mobile_scanner.md).

### Behaviour changes of the 3.x API

* Reading image files no longer blocks the UI (#74).
* Image files are read at full resolution, so `Code.position` is in pixels of the
  original image.
* Created barcodes read the same, but their bitmaps can differ in size.
* `Code.imageBytes` is filled for raw pixels and camera frames only.
* `zx.readBarcodes` and `zx.processCameraImageMulti` report failures in
  `Codes.error`.
* The internal libraries `zxing_mobile.dart`, `zxing_web.dart`, `zxing_cross.dart`
  and `generated_bindings.dart` are removed.
* Linux: C++ exceptions no longer crash apps built with Flutter 3.50 or newer.

## 3.1.1

* The cut-out of `ReaderWidget`'s scanner overlay is now centred on the camera
  preview wherever the widget sits on screen. It was placed as if the reader
  started at the top-left corner of the screen, so inside a `Padding`, below an
  app bar or further down a `Column` it was shifted up and to the left by that
  distance, partly outside the darkened area (#257).
* The cut-out of `ReaderWidget`'s scanner overlay now marks the area that is
  actually scanned. `cropPercent` is a fraction of the camera frame, and the
  frame is drawn covering the widget, but the cut-out was sized and moved within
  the widget. Whenever the camera and the widget were shaped differently, which
  on a phone is the usual case, the scanned area was larger than the cut-out,
  and the crop offsets moved the two apart. On such screens the cut-out is now
  larger than before. Thanks to [@frankmer](https://github.com/frankmer) for
  the report (#151).
* `ReaderWidget` no longer leaves the camera open when it is disposed while the
  camera is still starting, for example when the user leaves the scanner right
  after opening it.
* `ReaderWidget` restarts scanning when the app comes back to the foreground
  even if the camera reported an event, such as an orientation change, while
  the app was in the background. Before, the preview came back but nothing was
  scanned until the widget was rebuilt.
* A change of `lensDirection` or `resolution`, or a tap on the camera toggle,
  made while the camera is still starting is applied once it has started,
  instead of being dropped.
* `cropPercent` must now be between 0 and 1. A larger value used to make every
  frame fail to decode without telling anyone; release builds now clamp it.
* Multi-scan outlines are drawn the right way up on Android devices held upside
  down (`portraitDown`).
* A decoded code with an empty payload no longer leaks a small native buffer on
  every frame.
* The Android build of the plugin uses Android Gradle Plugin 9.1 and Java 17,
  matching the current Flutter templates.

## 3.1.0

* **The camera now works on macOS and Linux.** The `camera` package ships
  implementations for Android, iOS and the web only; adding
  [`camera_desktop`](https://pub.dev/packages/camera_desktop) to your app makes
  `ReaderWidget` and `zx.processCameraImage` work on the desktop too. See
  [Camera on desktop](README.md#camera-on-desktop) for what each platform needs.
  Thanks to [@bart-iconica](https://github.com/bart-iconica) (#250), who also
  asked for it (#249).
* New `cameraImageFormat(CameraImage)`, which returns the `DecodeParams.imageFormat`
  a camera frame should be decoded with. Frames that say `bgra8888` but carry
  RGBA — what `camera_desktop` delivers on Linux and Windows — used to be read
  as BGRA, swapping red and blue in the luminance the decoder works from.
* `ReaderWidget` no longer tears the camera down when a desktop window merely
  loses focus, and hides its flash button on desktop, where there is no torch to
  drive.
* Single-scan mode no longer gives up on a code because of a symbol it could not
  decode. `readBarcode` asks zxing for errors too, so that `onScanFailure` can
  report a symbol that was found but not read, and zxing stopped at the first
  symbol it found — even when that was an error. A code that failed its checksum
  in the full-size pass was then reported as a failure, and the downscaled and
  inverted passes that would have read it never ran; a dense GS1 DataMatrix
  almost never scanned. When the first symbol is an error, the frame is now
  searched again for a code that decodes. Frames whose first symbol decodes
  cost no more than before. Thanks to
  [@walkerkz-netizen](https://github.com/walkerkz-netizen) for the detailed
  report (#251).
* With `zx.setLogEnabled(true)`, the native log now says why a symbol could not
  be decoded, e.g. `Barcode error: ChecksumError @ DMDecoder.cpp:410`. `Code.error`
  is unchanged, and stays empty for most such failures.
* Multi-scan mode no longer asks zxing for errors. They were dropped before
  reaching `onMultiScan` anyway, but each one still used up a place in
  `maxNumberOfSymbols`, so symbols that could not be decoded could crowd out
  codes that could.
* The outline and text `ReaderWidget` draws over a scanned code now disappear
  once the code leaves the frame. They used to stay on screen until something
  else rebuilt the widget, pointing at whatever the camera had turned to.
  Thanks to [@walkerkz-netizen](https://github.com/walkerkz-netizen) (#252).
* `ReaderWidget` keeps the zoom level when switching cameras, clamped to what the
  new camera supports, instead of resetting it. Thanks to
  [@FrankenApps](https://github.com/FrankenApps) (#248).

## 3.0.1

* Fixed `pod install` failing with "undefined method `pod_target_xcconfig' for an
  instance of Pod::Specification" while loading the iOS and macOS podspecs.
  `Pod::Specification` only defines a writer for `pod_target_xcconfig`, so reading
  the value back to merge the `NDEBUG` settings into it raised a `NoMethodError`.
  All the settings are now assigned in a single hash. This affected 2.4.0 and
  3.0.0; apps that build through Swift Package Manager were never affected.
* Android builds no longer write a `NT_GNU_BUILD_ID` note into
  `libflutter_zxing.so`. The note is derived from the build environment, which
  kept the resulting APK from being byte-for-byte reproducible — something
  F-Droid now requires. Note that Firebase Crashlytics for NDK relies on that
  note to symbolicate native crashes, so a crash inside this library will now be
  reported without symbols. Thanks to [@quandangv](https://github.com/quandangv)
  (#247).

## 3.0.0

Updates the bundled [zxing-cpp](https://github.com/zxing-cpp/zxing-cpp) from
v2.3.0 to **v3.1.1** — 633 upstream commits, including a major release that
reworked the format API. `Format`, `DecodeParams`, `EncodeParams` and `Code` are
unchanged on the Dart side; the two behaviour changes below are the only ones
that can affect existing code.

### Breaking

* **UPC-A and UPC-E now decode to 13 digits.** ISO/IEC 15420 requires the `]E0`
  content to be a 13-digit number, so a UPC-A that used to read as
  `"725272730706"` now reads as `"0725272730706"`, and a UPC-E that used to read
  as its 8-digit form is expanded to the equivalent EAN-13. `Code.format` still
  reports `Format.upca` / `Format.upce`. Strip the leading zero if you need the
  old form.
* **Asking for a symbology now also matches its variants.** zxing-cpp 3.x splits
  formats into symbologies and variants, and a request for the symbology covers
  all of them. In practice: `Format.qrCode` also detects Micro QR and rMQR
  symbols (reported as `Format.microQRCode` / `Format.rmqrCode`), and
  `Format.pdf417` also detects MicroPDF417 (reported as `Format.microPdf417`).
  Filter on `Code.format` if you need to accept only one of them.

### Added

* Four formats that zxing-cpp can detect but the plugin never exposed:
  `Format.dxFilmEdge`, `Format.dataBarLimited`, `Format.telepen` and
  `Format.microPdf417`. All four are read-only, so they are absent from
  `CodeFormat.supportedEncodeFormats`, and all four are part of
  `Format.any`.
* `ImageFormat.lumA`, for 8-bit grayscale with an alpha byte.

### Changed

* `ImageFormat.rgbx`, `.xrgb`, `.bgrx` and `.xbgr` follow the upstream rename to
  `.rgba`, `.argb`, `.bgra` and `.abgr`. The old names still work and keep their
  values, but are deprecated.
* Detection quality and speed from upstream: better Aztec and DataMatrix
  detectors, improved QR Code detection (notably Version 1 and multiple small
  symbols in one frame), and 10–40% faster scanning on ARM.
* The Android NDK is no longer pinned to 27.0.12077973. That pin existed because
  zxing-cpp v2.3.0 could not compile against the libc++ in NDK 28+; v3.1.1 can,
  and the plugin now builds with NDK 27, 28 and 29.
* Windows builds as C++20, which zxing-cpp 3.x requires.

### Fixed

* `DecodeParams.maxNumberOfSymbols` is clamped to 1–255. zxing takes a
  `uint8_t`, so a larger value silently wrapped — 256 asked for no symbols at
  all.
* Upstream fix for an out-of-bounds read in the MicroPDF417 decoder.

## 2.4.0

Bug-fix and correctness release. Every fix below is covered by the unit tests in
`test/` or the FFI integration tests in `example/integration_test/`.

### Fixed

* **Reading some image files crashed the app (#213).** `rgbBytes` handed the
  decoder the image's own storage, which for a palette, 1/2/4-bit or 16-bit
  image is not 8-bit RGB and is a fraction of `width * height * 3` — a 1-bit PNG
  packs eight pixels per byte. The decoder then read far past the end of the
  allocation (`EXCEPTION_ACCESS_VIOLATION_READ` on Windows). Such images are now
  converted first, so they scan instead of crashing.
* **A corrupt or truncated image file threw instead of reporting an error.**
  `decodeImage` probes each format in turn and a malformed file can make one of
  those probes throw rather than decline.
* **iOS/macOS release builds could abort inside zxing (#237).** The Swift
  Package Manager build never defined `NDEBUG`, so zxing's internal
  `assert`s stayed live in shipped apps — `Assertion failed: (l1.isValid() &&
  l2.isValid()), function intersect, file RegressionLine.h`. Release and profile
  builds now compile them out, matching the CMake build used elsewhere. Debug
  builds keep the asserts.
* **Scanning silently never succeeded on some Android devices (#197).** CameraX
  reports the device's actual frame layout, and on some devices that is NV21;
  `ReaderWidget` mapped NV21 to `ImageFormat.rgb`, so the luminance plane was
  decoded as RGB and nothing ever matched — with no error to show for it. A
  frame layout that cannot be scanned at all is now reported through
  `onScanFailure` and logged, instead of failing silently forever.
* **`CameraPreview` could be rebuilt against a disposed controller (#238, #212,
  #204).** `CameraPreview` renders through a `ValueListenableBuilder` bound to
  the controller, and nothing marked the widget dirty when the controller was
  swapped, so the preview stayed subscribed to a controller that was about to be
  disposed and the pending rebuild called `buildPreview()` on it.
* **A wedged camera teardown left the widget with no camera at all.** Stopping
  the image stream and disposing the controller are now bounded by a timeout;
  previously an unresponsive platform call blocked the next camera from opening,
  with no way to recover.
* **A device without a torch aborted camera setup (#219).** Verified by a new
  widget test: `setFlashMode` failing now hides the flash button and leaves the
  camera running.
* **A failure to start the decoding isolate left the preview black forever.**
  Camera setup no longer waits on the isolate, and errors from either are
  reported through `onControllerCreated` instead of being swallowed.
* **Reopening the scanner could leave it with no camera (#160, #179, #163,
  #153).** After `initialize()`, `getMaxZoomLevel()` was the one unguarded
  platform call, and several awaits ran before it. If the controller was
  disposed or replaced in that window it threw `Uninitialized CameraController`,
  which aborted the rest of setup. Every step now re-checks that the controller
  is still current, and a failing zoom query falls back to no zoom instead of
  taking camera setup down with it.
* **The crop overlay was drawn against the screen, not the widget (#196).**
  `ReaderWidget` sized its preview and cut-out from `MediaQuery.size`, so any
  instance that is not full screen — inside a `SizedBox`, or a `Scaffold` body
  under an app bar — drew the indicator at the wrong size and off-centre. It now
  lays out from its own constraints.
* **A gallery image could crash the app on Android (#187).** Same out-of-bounds
  read as #213: a picked image whose pixel layout is not 8-bit RGB produced a
  buffer smaller than the decoder was told to read (`SIGSEGV / SEGV_ACCERR`).
* **Android frame layout is now requested explicitly (#197).** `ReaderWidget`
  asks for `ImageFormatGroup.yuv420` on Android and `bgra8888` on iOS instead of
  letting the platform choose, so the buffer layout no longer varies by device.
* **`type 'ArgumentError' is not a subtype of type 'Code'` (#221).** Errors
  raised inside the decoding isolate — including the missing-native-library
  error behind that report — were sent back raw and then cast to `Code`. The
  real error is now rethrown with its own message.
* **Generated barcodes could come out scrambled.** zxing enlarges a symbol that
  does not fit the requested box (a long Code128 asked for 240x120 is emitted at
  915x120), but the encoder only returned the pixel buffer, so it was rendered
  with the requested size and produced an unreadable image. `EncodeResult` now
  reports the bitmap it actually produced and `Encode` exposes it as
  `width`/`height`; `WriterWidget` and `pngFromBytes` use those values.
* **NV21 camera frames were decoded as RGB.** `ReaderWidget` mapped
  `ImageFormatGroup.nv21` to `ImageFormat.rgb`, so the luminance plane was read
  as RGB pixels and nothing scanned. NV21 and YUV420 now both map to
  `ImageFormat.lum`, and JPEG frames report `ImageFormat.none` instead of being
  scanned as raw pixels.
* **Reading an image file with default params produced garbage.** The file and
  URL readers always decode to RGB but left `DecodeParams.imageFormat` at its
  `lum` default, so `readBarcodeImagePath(file, DecodeParams())` handed the
  decoder mismatched pixels. The pixel format is now set to match the data.
* **A too-small image buffer was read out of bounds.** `readBarcode`/
  `readBarcodes` trusted the caller's `width`/`height` and read past the end of
  a buffer that was smaller than `width * height * pixStride`. The buffer length
  is now passed to the native side, which reports an error instead.
* **Barcode positions were wrong when a crop rect was used.** Positions are
  reported by zxing relative to the cropped view; they are now translated back
  into full-image coordinates so overlays line up.
* **`processCameraImage` hung forever** when called before
  `startCameraProcessing()`, or when the decoding isolate was stopped while a
  frame was in flight. Both now complete with a `StateError`.
* **Errors raised inside the decoding isolate surfaced as an unrelated
  `TypeError`.** The raw error object was sent back and then cast to `Code`.
  Errors are now wrapped and rethrown with their original message.
* **`processCameraImage`/`processCameraImageMulti` threw a cast error** when
  `DecodeParams.isMultiScan` did not match the method that was called. The flag
  is now forced to match, and `processCameraImageMulti` sets `Code.source`.
* **Disposing one `ReaderWidget` broke every other one on screen.** The decoding
  isolate is shared, and `stopCameraProcessing()` tore it down unconditionally.
  It is now reference counted.
* **The result overlay never appeared in multi-scan mode** with the default
  `cropPercent`, and the crop cut-out was still drawn even though multi-scan
  scans the whole frame. Both overlays now follow the crop actually applied.
* **The built-in scan-mode dropdown did not change how frames were scanned.**
  `ReaderWidget` read `widget.isMultiScan` while the dropdown updated internal
  state. It now uses the effective mode and syncs it in `didUpdateWidget`, which
  also makes changes to `lensDirection` and `resolution` take effect.
* **Camera rows with padding were misread.** Only the YUV420 luminance plane had
  its row stride handled; BGRA8888 frames with `bytesPerRow > width * 4` were
  passed through shifted.
* **`pngFromBytes` produced a wrong image for a `Uint8List` view** into a larger
  buffer, and read past the end of a buffer that was too small. It now honours
  the view's offset and rejects inconsistent input with an `ArgumentError`.
* **The debug image on a `Code` was garbage for non-luminance input.** It was
  copied assuming one byte per pixel regardless of the source format; it is now
  converted to luminance, matching what `pngFromBytes` expects.
* **A memory leak in `readBarcodes`** when zxing found candidates but all of
  them failed validation: the native result array was allocated and never freed.
* **`WriterWidget` accepted invalid input.** A null text passed validation, and
  zero or negative width/height and negative margins reached the encoder.
* **Tapping a code in `MultiResultOverlay` fired on any pointer event**, because
  the callback was invoked from `CustomPainter.hitTest`. It now uses a real tap
  gesture.
* **The web stub threw from `stopCameraProcessing`**, so disposing a widget on
  web raised; teardown calls are now no-ops and the rest report a descriptive
  `UnsupportedError`.
* **Web/WasmGC resolution.** The conditional import used the legacy
  `dart.library.html`, which is absent when compiling to WasmGC, so the
  unsupported-platform stub was selected. It now uses `dart.library.js_interop`.

### Changed

* `XFile` and `CameraImage` are re-exported: they appear in this package's own
  signatures, and importing `package:camera` for them collided with this
  package's `ImageFormat`.
* `DecodeParams` gained `copyWith`, and the file/URL readers no longer mutate
  the `DecodeParams` instance passed to them.
* The file and URL readers report failures as a `Code`/`Codes` carrying an
  `error` instead of throwing.
* `Code`, `Codes`, `Position` and `Encode` implement `toString()`.
* `MultiScanPainter` no longer takes `context` or `onCodeTap`; tap handling
  moved to `MultiResultOverlay`, and `shouldRepaint` no longer returns `true`
  unconditionally.
* The `camera` dependency floor is raised to `>=0.11.0`, the release where
  Android moved to CameraX. The camera2 implementation it replaced crashed
  inside `io.flutter.plugins.camera.Camera` on several devices (#205, #206),
  which nothing in this plugin could work around.
* `Code.imageBytes` is documented: it is the luminance the decoder scanned,
  cropped to the scan rect, and only populated while logging is enabled (#207).
* `cropPercent` is documented as the fraction of the frame that is *kept*, not
  the fraction cropped away (#151).
* The zoom level is reset when switching cameras, instead of carrying the
  previous camera's factor over to one that may not support it.
* ZXScanner's README no longer links to App Store and Google Play pages that
  return 404; it explains how to build the app from source instead (#180).
* Android `compileSdk` raised to 36 and Java compatibility to 11, matching the
  current Flutter defaults. The NDK stays pinned to 27.0.12077973, which is
  required: zxing-cpp v2.3.0 does not build against the libc++ in NDK 28+.
* iOS podspec deployment target aligned with `Package.swift` (13.0), and the
  placeholder metadata in both podspecs replaced.
* README: every code sample was corrected -- none of them compiled against the
  real API -- and the platform minimums now match the build files.
* Replaced the empty unit-test file with real coverage, and extended the FFI
  integration tests to cover the fixes above, including reading a barcode from
  PNG (8-bit, grayscale, 1-bit, 16-bit), GIF, JPEG and BMP files.
* Added widget tests for the camera lifecycle — start-up, switching cameras,
  disposal and devices without a torch — driven by a fake camera platform.

## 2.3.1

* Fixed iOS/macOS barcode detection failing in stripped archives after the SPM migration.

## 2.3.0

* Migrated iOS and macOS projects from CocoaPods to Swift Package Manager (SPM).
* Improved camera handling: fixed `CameraController` disposal issues and `stopImageStream()` errors.
* Enhanced flash/torch UI: hidden toggle button when flash is unavailable and improved state management.
* Added a second action button capability for better UI flexibility.
* Improved multiple concurrent isolates handling.
* Updated iOS deployment target to 13.0.

## 2.2.1

* Draw scan result rectangle in single scan mode when cropRect = 0

## 2.2.0

* Support 16KB page size on android
* minSdkVersion had to be bumped to API Level 23 (Android 6.0)

## 2.1.0

Enhance barcode scanning features and improve overlay customization

* Added vertical and horizontal crop offsets, downscaling option, and max symbol count to barcode decoding parameters.
* Refactored scanner overlay to use a new universal border with customizable cut-out size and offsets.
* Updated ReaderWidget to support new overlay features and adjusted padding in debug info widget.
* Removed deprecated dynamic and fixed scanner overlays.

## 2.0.2

* Added parameters `tryDownscale` and `maxNumberOfSymbols` to the `ReaderWidget` for better performance and flexibility.

## 2.0.1

* Fixed windows compatibility issues

## 2.0.0

* Updated zxing-cpp to v2.3.0

## 1.9.1

* Increased minimum versions of `camera` and `image` packages to support newer APIs.

## 1.9.0

* Improved FFI interoperability: changed image data type from `Uint32List` to `Uint8List` for correct handling of binary (black & white) matrices between C++ (zxing-cpp) and Flutter.
* Fixed issues when creating images from binary data in Flutter, ensuring proper grayscale and RGB handling.
* Updated integration tests to work with the new data format.
* Minor code cleanup and refactoring.

## 1.8.2

* Minor improvements

## 1.8.1

* Minor improvements

## 1.8.0

* Fixed Windows compatibility issues (thanks to [@liff](https://github.com/liff))
* Updated dependencies to the latest version

## 1.7.0

* Added support for Linux (thanks to [@phlip9](https://github.com/phlip9))
* Fixed memory leak in iOS

## 1.6.1

* Fixed iOS and macOS compatibility issues

## 1.6.0

* Updated camera to v0.11.0

## 1.5.2

* Fixed issue with recognizing the barcodes from the image

## 1.5.1

* Updated zxing-cpp to v2.2.1

## 1.5.0

* Updated zxing-cpp to v2.2.0

## 1.4.1

* Replaced 'hidden' with 'default' for improved compatibility with older Flutter versions

## 1.4.0

* Updated Image to v4

## 1.3.2

* Conditionally add namespace for AGP 8 support
* Set minimum Flutter version to 3.7.0

## 1.3.1

* Utilized Flutter version 3.1.0 or higher

## 1.3.0

* Updated zxing-cpp to v2.1.0

## 1.2.1

* Moved `melos` to dev dependencies (thanks to [@phlip9](https://github.com/phlip9))
* Updated dependencies to the latest version

## 1.2.0

* Downgraded image version from v3.4.0 to v3.3.0 to resolve iOS detection issue.
* Downgraded zxing-cpp from v3.0.0 to v2.0.0 to fix QR code decoding issues.
* Resolved multiple code scan issue that occurred when using image path by implementing a fix.

## 1.1.2

* Fixed issue with onControllerCreated callback is sometimes not called

## 1.1.1

* Allow to set camera lens direction

## 1.1.0

* Updated Image to v4

## 1.0.2

* Updated zxing cpp

## 1.0.1

* Added support for changing the camera
* Fixed issue with iPad

## 1.0.0

* Updated zxing-cpp to v2.0.0
* Added support for macOS, Linux, and Windows
* Added support for micro QR codes
* Added the following properties to Code:
  * isInverted
  * isMirrored
  * duration
* Implemented image resizing before decoding
* Implemented multi result drawing

## 1.0.0-beta.9

* Corrected code position in Android when in portrait mode.

## 1.0.0-beta.8

* Implemented multi result drawing
* `readBarcodes` now returns a `Codes` object instead of a `List<Code>` object

## 1.0.0-beta.7

* Resolved an issue with detecting and handling large images

## 1.0.0-beta.6

* Fixed compilation issue on Android

## 1.0.0-beta.5

* Fixed compilation issue on Android

## 1.0.0-beta.4

* Fixed compilation issue on Android

## 1.0.0-beta.3

* Added the following properties to Code:
  * isInverted
  * isMirrored
  * duration
* Implemented image resizing before decoding

## 1.0.0-beta.2

* Minor improvements

## 1.0.0-beta.1

* Updated zxing-cpp to v2.0.0
* Added support for macOS, Linux, and Windows
* Added support for micro QR codes
* Zxing-cpp is now included as a submodule instead of a deep copy

## 0.10.0

* added `EncodeParams`
* replaced `int` type with `EccLevel` enum for error correction level
* added `ratio`, `maxTextLength`, and `isSupportedEccLevel` to Format for encoding barcodes
* renamed `Params` to `DecodeParams`
* fixed issue where images were being inverted when using `zx` methods

## 0.9.1

* fixed memory leaks

## 0.9.0

Breaking changes

* fixed compilation errors on web
* added 'Params' class for using one parameters instead of many
* use 'zx' prefix for all functions

## 0.8.5

* added 'tryInverted' and 'tryHarder' parameters to the `ReaderWidget`

## 0.8.4

* added 'bytes' parameter content without any modifications to the scan result

## 0.8.3

* bug fixes

## 0.8.2

* bug fixes

## 0.8.1

* bug fixes
  
## 0.8.0

* added ability to set localization messages for `writer_widget`
* fixed bug where iOS crashes when creating a new barcode

## 0.7.4

* updated readme

## 0.7.3

* encodeBarcode method now uses the named parameters instead of positional parameters

## 0.7.2

* fixed case sensitive folder name issue in CMakeLists.txt (thanks to [@softkot](https://github.com/softkot))

## 0.7.1

* updated dependencies to the latest version

## 0.7.0

* added barcode result point detection
* added tryHarder and tryRotate arguments to the readers

## 0.6.0

* updated zxing-cpp to v1.4.0

## 0.5.0

* fixed Chinese support for iOS (thanks to [@aqiu202](https://github.com/aqiu202))

## 0.4.0

Breaking changes

* removed `FlutterZxing` class, call all methods directly
* added read multiple barcodes methods

## 0.3.2

* fixed enabling/disabling of the logger

## 0.3.1

* fixed Chinese support

## 0.3.0

* added processCameraImage function
* added pinch to zoom sopport
* added flash sopport
* added custom scanner overlay support

## 0.2.0

* added 'readImagePath' function
* added 'readImagePathString' function
* added 'readImageUrl' function

## 0.1.3

* minor improvements

## 0.1.2

* minor fixes for analyzer options

## 0.1.1

* renamed 'ZxingReaderWidget' to 'ReaderWidget'
* renamed 'ZxingWriterWidget' to 'WriterWidget'

## 0.1.0

* renamed 'zxingRead' to 'readBarcode'
* renamed 'zxingEncode' to 'encodeBarcode'
* updated example project

## 0.0.2

* added ability to set the code format for reader

## 0.0.1

* Initial barcode scanner release.
