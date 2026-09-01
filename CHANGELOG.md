# Changelog

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
