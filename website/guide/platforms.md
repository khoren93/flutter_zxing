# Platforms

The same zxing-cpp code reads on a phone, a desktop and in the browser, so a
code that reads on one platform reads on the others.

| Platform | Read and create | Camera scanner |
|---|---|---|
| Android | ✅ | ✅ |
| iOS | ✅ | ✅ |
| Web | ✅ | ✅ Chrome, Safari, Firefox |
| macOS | ✅ | ✅ with `camera_desktop` |
| Linux | ✅ | ✅ with `camera_desktop` |
| Windows | ✅ | not verified |

## Off the UI thread

Every call that touches the engine runs on a background isolate, or in a
Web Worker on the web, and returns a `Future`. A 12-megapixel photo is read
without a dropped frame. The scanner decodes only the scan window of each
camera frame.

## The web

The engine is compiled to WebAssembly and runs in a Web Worker. Reading
loads a 312 KB module (brotli); the 507 KB full module loads when the app
first creates a code. See [Installation](./installation#web) for HTTPS and
`--base-href`.

## Camera on the desktop

The `camera` package has no desktop implementations. Add
[`camera_desktop`](https://pub.dev/packages/camera_desktop) to your app and
`BarcodeScanner` works on macOS and Linux unchanged:

```yaml
dependencies:
  camera_desktop: ^2.0.0
```

- **macOS:** add `NSCameraUsageDescription` to `macos/Runner/Info.plist`,
  and for a sandboxed app `com.apple.security.device.camera` to both
  entitlements files (the example app's `macos/Runner` has them).
- **Linux:** install the GStreamer development packages:
  `libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-good`.
- **Windows:** not verified yet.

Desktop cameras do not report a zoom or a focus, so the zoom stays where it
is set.

## Automatic zoom on iPhones

On iPhones the scanner picks the camera by itself from where the lens is
focused: the ultra-wide camera when a code is too close for the main camera
to focus, 2× and then the telephoto camera when it is far. It never switches
while codes are being read. See [The controller](../scanning/controller#zoom-torch-and-focus).

Android, the desktop and the web keep the zoom where it is set: their
cameras do not report their focus.
