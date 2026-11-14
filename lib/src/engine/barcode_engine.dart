import 'engine.dart';

/// The zxing-cpp version inside the engine.
const String zxingCppVersion = '3.1.1';

/// Starts the barcode engine ahead of time, e.g. in `main()`, so that the
/// first scan or read does not wait for it.
///
/// Optional: the engine starts by itself on first use. On the web this also
/// downloads and compiles the WebAssembly module.
Future<void> warmUpBarcodeEngine() async {
  await Future.wait(<Future<void>>[
    BarcodeEngine.shared.warmUp(),
    BarcodeEngine.scanner.warmUp(),
  ]);
}
