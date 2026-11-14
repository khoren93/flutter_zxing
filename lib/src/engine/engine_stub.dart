import '../errors.dart';
import 'engine.dart';

/// Platforms with neither dart:ffi nor JS interop have no engine.
Future<EngineBackend> spawnBackend(String name) => Future<EngineBackend>.error(
  const EngineException('No barcode engine on this platform'),
);
