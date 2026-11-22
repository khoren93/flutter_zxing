# Accuracy and speed

## How the scanner works

The `camera` plugin delivers frames to Dart. The scanner copies only the
scan window of each frame and decodes it on a background isolate, one frame
at a time: while a frame is decoded, newer frames replace each other, so
nothing piles up. The decoder takes 2–4 ms of the 33–40 ms between frames,
so every frame the camera delivers is decoded, and the frame rate of the
camera is the limit.

## Small or dense codes

Only the scan window of each frame is read. The default camera resolution,
`CameraResolution.hd` (about 1280×720), is plenty for QR codes on screens
and labels. For a dense Data Matrix or a long GS1 DataBar, give the decoder
more pixels:

```dart
final controller = ScannerController(
  resolution: CameraResolution.fullHd,
  scanWindow: const ScanWindow.centered(width: 0.9),
);
```

For small codes on parts and boards, start zoomed in:
`ScannerController(initialZoom: 2)`, or the `ScannerTemplate.small()`
template. On iPhones, automatic zoom moves to the ultra-wide camera for
codes too close for the main camera to focus.

## Faster frames

- **Fewer formats.** Each format is another search; `formats` with only the
  ones the app needs decodes faster and never mistakes one symbology for
  another.
- **One code per frame.** `maxBarcodes: 1`, the default, stops at the first
  code: several times faster on a frame with a code.
- **The camera preset.** `ReaderOptions.camera()` leaves out light-on-dark
  codes. Turn `tryInvert` on only if the app reads them.
- **Slow phones.** The dimmed camera around the window is blurred again for
  every frame. Left unset, the scanner turns its blur off by itself when the
  device does not draw its frames in time; `ScannerTheme(scrimBlur: false,
  blur: false)` turns it off from the start, `true` keeps it on.

## Photos and files

Image files are read at full resolution, with every search strategy of
`ReaderOptions()` on, including a smaller copy of large images
(`tryDownscale`). A 12-megapixel photo with a small, dense QR code is found
in about 100 ms on a MacBook and 220 ms on a 2020 Pixel 4a, without
blocking the UI.

## Measured

Release builds. The phone was held on a QR code until 1000 frames with the
code were decoded. Scan window 60% × 80% of the frame, 1280×720 frames.
*Scan latency* is from the frame arriving in Dart to its barcodes being
back on the UI isolate.

| Device | Decoded per second | Frames skipped | Scan latency avg / p95 | UI frames over 16 ms |
|---|---|---|---|---|
| iPhone 17 Pro Max | 30 | 0 | 2.6 / 3.6 ms | 0 of 1073 |
| Pixel 4a (2020) | 24.9 | 0 | 3.0 / 9.5 ms | 0 of 1246 |
| Safari, MacBook camera | 30 | — | 9.6 / 12 ms | 0 of 1140 |
| Safari, iPhone 17 Pro Max | 30 | — | 9.0 / 12 ms | 0 of 1129 |

| Images | 3.1.1 | 4.0 |
|---|---|---|
| 32 images, MacBook | 4.8 ms | **0.6 ms** |
| 32 images, Pixel 4a | 15.8 ms | **1.6 ms** |
| 12 MP photo, MacBook | not found; UI frozen 374 ms | **found in 103 ms**, UI not blocked |
| 12 MP photo, Pixel 4a | not found; UI frozen 1.0 s | **found in 219 ms**, UI not blocked |
| 12 MP photo, Chrome (WebAssembly) | not supported | found in 204 ms |

The raw data and how to repeat a run are in
[benchmark/BENCHMARKS.md](https://github.com/khoren93/flutter_zxing/blob/4.0/benchmark/BENCHMARKS.md).

## Limits

- MaxiCode is read from clean images only (a code without background, not
  skewed), not from the camera: a limit of zxing-cpp.
- zxing-cpp is a classic decoder. Machine-learning decoders such as ML Kit
  tend to read damaged, blurred and curved codes that it misses: see
  [Coming from mobile_scanner](./from-mobile-scanner#compared).
