import '../../errors.dart';
import 'camera_source.dart';

/// Platforms with neither dart:ffi nor JS interop have no camera.
CameraSource createCameraSource() =>
    throw const CameraNotFoundException('No camera on this platform');
