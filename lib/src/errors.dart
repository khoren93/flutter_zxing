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

/// The camera failed: it is used by another app, or the platform reported
/// an error.
final class CameraFailureException extends ScannerException {
  /// Creates the exception.
  const CameraFailureException(super.message);

  @override
  String get _name => 'CameraFailureException';
}
