# Scan benchmarks

Camera scan timing, one row per run, to compare camera pipelines: the
prototype of 4.0 (`camera plugin 0.12 ...`), flutter_zxing 4.0, and later a
custom zero-copy camera.

How a run works: `cd example && flutter run --release -t lib/scanner_dev.dart
--dart-define=DEVICE="<device name>"`, tap the speed button and hold the
phone on a QR code until 1000 frames *with a found code* are decoded (the
first 20 frames are warm-up and ignored). The result is printed in the log
in numbered pieces, `[scanbench 1/3] ...` (joined, the JSON), and saved in the app's temporary directory; put the
JSON into `benchmark/scan/` and run `dart run scanbench_report.dart` in
`tool/`.

- **Scan latency**: the camera frame reaches Dart → its barcodes are back on
  the UI isolate (copying the scan window, the hop to the engine isolate,
  decoding, the hop back). Excludes the camera's own exposure and processing
  delay: the `camera` plugin gives no capture time.
- **Engine**: decoding time inside the engine isolate.
- **Camera**: frames the camera delivered per second, and how many were
  skipped because the engine was still busy.
- **UI frames**: Flutter frame build time avg / max while scanning, and how
  many frames took over 16 ms (build + raster).
- Times are **avg / min / max / p95** in ms. Scan window: 60% x 80% in the
  centre, release build, portrait.

| Date | Device | Pipeline | Frame | Found frames | Hit rate | Decodes/s | Camera | Scan latency, ms | Engine, ms | UI frames (build ms avg / max) | Raw |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2026-11-14 18:27 | iPhone 17 Pro Max (iPhone18,2), iOS 27.2 | camera plugin 0.12 (startImageStream) -> Y crop copy -> fzx isolate | 720x1280 | 1000 | 100.0% | 30.0 | — | 1.7 / 1.1 / 2.8 / 2.4 | 1.5 / 0.9 / 2.5 / 2.0 | — | `2026-11-14T18-27-41.json` |
| 2026-11-14 18:30 | iPhone 17 Pro Max (iPhone18,2), iOS 27.2 | camera plugin 0.12 (startImageStream) -> Y crop copy -> fzx isolate | 720x1280 | 1000 | 100.0% | 30.0 | — | 1.8 / 1.1 / 3.1 / 2.5 | 1.5 / 0.9 / 2.6 / 2.1 | 0.5 / 6.9, 0 of 1094 over 16 ms | `2026-11-14T18-30-58.json` |
| 2026-11-14 18:34 | Google Pixel 4a, Android 13 (SDK 33) | camera plugin 0.12 (startImageStream) -> Y crop copy -> fzx isolate | 720x1280 | 1000 | 100.0% | 24.9 | — | 4.0 / 2.2 / 17.6 / 11.7 | 2.4 / 1.8 / 12.7 / 3.4 | 1.0 / 10.2, 1 of 1342 over 16 ms | `2026-11-14T18-34-01.json` |
| 2026-11-14 18:39 | Google Pixel 4a, Android 13 (SDK 33) | camera plugin 0.12 (startImageStream) -> Y crop copy -> fzx isolate | 720x1280 | 1000 | 100.0% | 24.9 | 24.9 fps, skipped 0 | 3.9 / 2.3 / 22.7 / 10.4 | 2.4 / 1.9 / 13.6 / 2.5 | 1.0 / 10.3, 0 of 1332 over 16 ms | `2026-11-14T18-39-32.json` |
| 2026-11-14 19:54 | Mac (FaceTime HD camera), Safari 27.2 | getUserMedia <video> -> createImageBitmap(crop) -> fzx wasm worker | 1280x720 | 1000 | 71.5% | 30.0 | — | 9.6 / 7.0 / 25.0 / 12.0 | 4.4 / 3.0 / 6.0 / 5.0 | 1.2 / 4.0, 0 of 1140 over 16 ms | `2026-11-14T19-54-32.json` |
| 2026-11-14 19:59 | iPhone 17 Pro Max, Safari 27.2 (iOS 27.2) | getUserMedia <video> -> createImageBitmap(crop) -> fzx wasm worker | 720x1280 | 1000 | 75.5% | 30.0 | — | 9.0 / 7.0 / 15.0 / 12.0 | 4.3 / 3.0 / 6.0 / 5.0 | 1.5 / 4.0, 0 of 1129 over 16 ms | `2026-11-14T19-59-00.json` |
| 2026-11-15 03:12 | iPhone 17 Pro Max (iPhone18,2), iOS 27.2 | flutter_zxing 4.0: camera plugin (startImageStream) -> window rows into native memory -> fzx isolate | 720x1280 | 1000 | 100.0% | 30.0 | 30.0 fps, skipped 0 | 2.6 / 1.4 / 4.9 / 3.6 | 1.9 / 1.0 / 4.2 / 2.7 | 1.6 / 2.9, 0 of 1073 over 16 ms | `2026-11-15T03-12-47.json` |
| 2026-11-15 03:13 | Google Pixel 4a, Android 13 (SDK 33) | flutter_zxing 4.0: camera plugin (startImageStream) -> window rows into native memory -> fzx isolate | 1280x720 | 1000 | 100.0% | 24.9 | 24.9 fps, skipped 0 | 3.0 / 1.6 / 20.2 / 9.5 | 1.6 / 1.2 / 11.3 / 1.7 | 2.2 / 12.2, 0 of 1246 over 16 ms | `2026-11-15T03-13-45.json` |
