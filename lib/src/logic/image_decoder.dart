part of 'zxing.dart';

/// The result of turning an image file or URL into raw pixels the decoder can
/// read: either [bytes] plus the [params] describing them, or an [error].
class _DecodedImage {
  _DecodedImage.success(this.bytes, this.params) : error = null;
  _DecodedImage.failure(this.error) : bytes = null, params = null;

  final Uint8List? bytes;
  final DecodeParams? params;
  final String? error;
}

/// Decodes an image file into RGB pixels, downscaling it to `params.maxSize`.
Future<_DecodedImage> _decodeImageFile(XFile file, DecodeParams params) async {
  final Uint8List imageBytes;
  try {
    imageBytes = await file.readAsBytes();
  } catch (e) {
    return _DecodedImage.failure('Failed to read image: $e');
  }
  return _decodeImageBytes(imageBytes, params);
}

/// Fetches an image over the network and decodes it into RGB pixels.
Future<_DecodedImage> _decodeImageUrl(String url, DecodeParams params) async {
  final Uint8List imageBytes;
  try {
    final Uri uri = Uri.parse(url);
    imageBytes = (await NetworkAssetBundle(uri).load(url)).buffer.asUint8List();
  } catch (e) {
    return _DecodedImage.failure('Failed to load image from $url: $e');
  }
  return _decodeImageBytes(imageBytes, params);
}

_DecodedImage _decodeImageBytes(Uint8List imageBytes, DecodeParams params) {
  final imglib.Image image;
  final Uint8List bytes;
  try {
    // `decodeImage` sniffs the format by handing the bytes to each decoder in
    // turn, and a truncated or corrupt file can make one of them throw rather
    // than politely decline. Reading an image must not blow up the caller.
    final imglib.Image? decoded = imglib.decodeImage(imageBytes);
    if (decoded == null) {
      return _DecodedImage.failure('Failed to decode image');
    }
    image = resizeToMaxSize(decoded, params.maxSize);
    bytes = rgbBytes(image);
  } catch (e) {
    return _DecodedImage.failure('Failed to decode image: $e');
  }

  // Copy rather than mutate: `params` belongs to the caller and may be reused
  // for other images.
  return _DecodedImage.success(
    bytes,
    params.copyWith(
      imageFormat: ImageFormat.rgb,
      width: image.width,
      height: image.height,
    ),
  );
}
