/// Base class of every exception thrown by flutter_zxing 4.
///
/// "Nothing found" is never an exception: readers return `null` or an empty
/// list. Exceptions mean the input or the environment is wrong.
sealed class ZxingException implements Exception {
  const ZxingException(this.message);

  /// What went wrong, for logs. Not localized.
  final String message;

  // Not `runtimeType`: it is minified in release web builds.
  String get _name;

  @override
  String toString() => '$_name: $message';
}

/// The input is not an image the engine can decode (corrupt file, an
/// unsupported format, or not an image at all).
final class ImageDecodeException extends ZxingException {
  /// Creates the exception.
  const ImageDecodeException(super.message);

  @override
  String get _name => 'ImageDecodeException';
}

/// The data cannot be encoded in the requested format (e.g. letters in an
/// EAN-13, or too much data for the chosen symbol version).
final class BarcodeWriteException extends ZxingException {
  /// Creates the exception.
  const BarcodeWriteException(super.message);

  @override
  String get _name => 'BarcodeWriteException';
}

/// The engine failed to start or stopped unexpectedly. The next call starts
/// it again.
final class EngineException extends ZxingException {
  /// Creates the exception.
  const EngineException(super.message);

  @override
  String get _name => 'EngineException';
}

/// A camera problem reported by the scanner in `ScannerState.error`.
sealed class ScannerException extends ZxingException {
  const ScannerException(super.message);
}

/// The user denied camera access (or it is restricted by the system).
final class CameraPermissionException extends ScannerException {
  /// Creates the exception.
  const CameraPermissionException([super.message = 'Camera access denied']);

  @override
  String get _name => 'CameraPermissionException';
}

/// The device has no camera with the requested facing.
final class CameraNotFoundException extends ScannerException {
  /// Creates the exception.
  const CameraNotFoundException([super.message = 'No camera available']);

  @override
  String get _name => 'CameraNotFoundException';
}

/// The camera is busy: another app (or another part of this app) is
/// using it. Trying again may work once it is released.
///
/// Reported on Android (the camera is in use, or too many cameras are open)
/// and on the web (`NotReadableError`). iOS and macOS do not tell a busy
/// camera apart: there it is a [CameraFailureException].
final class CameraInUseException extends ScannerException {
  /// Creates the exception.
  const CameraInUseException([
    super.message = 'The camera is used by another app',
  ]);

  @override
  String get _name => 'CameraInUseException';
}

/// Cameras cannot be used here at all: a web page that is not served over
/// https (or from localhost), a browser without camera access, a platform
/// without a camera plugin. Trying again does not help.
final class CameraUnsupportedException extends ScannerException {
  /// Creates the exception.
  const CameraUnsupportedException([
    super.message = 'No camera access on this platform',
  ]);

  @override
  String get _name => 'CameraUnsupportedException';
}

/// The camera failed: the platform reported an error not covered by the
/// other [ScannerException]s, or the barcode engine kept failing.
final class CameraFailureException extends ScannerException {
  /// Creates the exception.
  const CameraFailureException(super.message);

  @override
  String get _name => 'CameraFailureException';
}
