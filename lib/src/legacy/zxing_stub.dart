import 'zxing.dart';

/// Platforms with neither dart:ffi nor JS interop.
Zxing getZxing() => throw UnsupportedError(
  'Cannot create an instance of FlutterZxing on the current platform.',
);
