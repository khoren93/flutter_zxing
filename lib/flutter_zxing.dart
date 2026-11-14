/// Reads and creates barcodes on Android, iOS, macOS, Linux, Windows and
/// the web, with zxing-cpp.
///
/// The 4.0 API: [BarcodeReader], [BarcodeWriter], [BarcodeScanner]. The 3.x
/// API (`zx`, `ReaderWidget`, `WriterWidget`) is deprecated and keeps
/// working, on the same engine, until 5.0.
library;

import 'src/api.dart';

// `CameraImage` and `XFile` appear in the 3.x API's own signatures, so they
// are re-exported: without them callers had to import `package:camera`
// directly, whose `ImageFormat` then collided with the 3.x `ImageFormat`
// constants `DecodeParams` expects.
export 'package:camera/camera.dart'
    show
        CameraController,
        CameraImage,
        CameraLensDirection,
        ResolutionPreset,
        XFile;

export 'src/api.dart';
export 'src/legacy/legacy.dart';
