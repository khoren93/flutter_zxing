import 'engine.dart';

/// The zxing-cpp version inside the engine.
const String zxingCppVersion = '3.2.0-rc1';

/// Starts the barcode engine ahead of time, e.g. in `main()`, so that the
/// first scan or read does not wait for it.
///
/// Optional: the engine starts by itself on first use. On the web this also
/// downloads and compiles the WebAssembly module.
///
/// Two engines start: one for `BarcodeReader` and `BarcodeWriter`, one for
/// the camera scanner. An app that never scans (it only reads files or
/// creates barcodes) passes `scanner: false` and does not start the second.
///
/// Never fails: if the engine cannot start, the first real call starts it
/// again and throws the reason (`EngineException`). So there is no need to
/// wait for it or to catch anything.
///
/// ```dart
/// void main() {
///   runApp(const MyApp());
///   warmUpBarcodeEngine(); // no need to wait for it
/// }
/// ```
Future<void> warmUpBarcodeEngine({bool scanner = true}) async {
  await Future.wait(<Future<void>>[
    BarcodeEngine.shared.tryWarmUp(),
    if (scanner) BarcodeEngine.scanner.tryWarmUp(),
  ]);
}
