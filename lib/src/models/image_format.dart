/// Pixel formats accepted by the decoder, mirroring `ZXing::ImageFormat`.
///
/// The value encodes the pixel stride in the high byte and the byte offset of
/// the red, green and blue channels in the remaining three.
abstract class ImageFormat {
  static const int none = 0;

  /// 8-bit grayscale, one byte per pixel.
  static const int lum = 0x01000000;

  /// 8-bit grayscale with an alpha byte, two bytes per pixel.
  static const int lumA = 0x02000000;

  static const int rgb = 0x03000102;
  static const int bgr = 0x03020100;
  static const int rgba = 0x04000102;
  static const int argb = 0x04010203;
  static const int bgra = 0x04020100;
  static const int abgr = 0x04030201;

  @Deprecated('Use rgba instead')
  static const int rgbx = rgba;
  @Deprecated('Use argb instead')
  static const int xrgb = argb;
  @Deprecated('Use bgra instead')
  static const int bgrx = bgra;
  @Deprecated('Use abgr instead')
  static const int xbgr = abgr;
}
