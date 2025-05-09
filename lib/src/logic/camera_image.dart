part of 'zxing.dart';

extension CameraImageExt on CameraImage {

  bool hasMultiBytePixelPlane() {
    return planes.any((Plane plane) => (plane.bytesPerPixel ?? 0) > 1);
  }

  /// Returns true if the CameraImage is a format
  /// that is directly supported by zxing_cpp
  /// (e.g. tightly packed YUV420 or BGRA8888).
  bool isZxingProcessableCameraImage() {
    return format.group == ImageFormatGroup.yuv420 ||
        planes[0].bytesPerRow == width;
  }

  /// Converts the Y plane of a YUV420 image to a
  /// tightly packed (no padding) grayscale list of bytes.
  Uint8List getTightlyPackedYPlane() {
    final Plane yPlane = planes[0];
    final int bytesPerRow = yPlane.bytesPerRow;

    // If row stride matches the image width, copy directly.
    if (bytesPerRow == width) {
      return yPlane.bytes;
    }

    final Uint8List packed = Uint8List(width * height);

    for (int row = 0; row < height; row++) {
      final int srcOffset = row * bytesPerRow;
      final int dstOffset = row * width;
      packed.setRange(dstOffset, dstOffset + width, yPlane.bytes, srcOffset);
    }
    return packed;
  }
}
