import 'package:flutter/foundation.dart';

import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import 'pixel_buffer.dart';
import 'reader_options.dart';

/// Reads barcodes from images: photos, files, screenshots, raw pixels.
///
/// Decoding runs in the background (an isolate on native platforms, a Web
/// Worker on the web) and never blocks the UI. There is nothing to create
/// or dispose: a reader is a constant configuration, the engine starts on
/// first use.
///
/// ```dart
/// const reader = BarcodeReader();
/// final barcode = await reader.read(await file.readAsBytes());
///
/// const qr = BarcodeReader(formats: {BarcodeFormat.qrCode});
/// final all = await qr.readAll(bytes);
/// ```
@immutable
final class BarcodeReader {
  /// Creates a reader.
  const BarcodeReader({this.formats, this.options = const ReaderOptions()});

  /// Formats to look for; `null` means all. Fewer formats read faster.
  /// A base symbology includes its variants, see [BarcodeFormat].
  final Set<BarcodeFormat>? formats;

  /// Search strategies.
  final ReaderOptions options;

  /// Finds the first barcode in an encoded image (JPEG, PNG, GIF, BMP; on
  /// the web also anything the browser decodes, such as WebP and AVIF).
  ///
  /// Stops searching at the first barcode, which on large photos is often
  /// ten times faster than [readAll]. Returns `null` if there is none.
  ///
  /// Throws [ImageDecodeException] if [encodedImage] is not a readable image.
  Future<Barcode?> read(Uint8List encodedImage) =>
      throw UnimplementedError('Stage 3');

  /// Finds every barcode in an encoded image, up to [limit] if given.
  ///
  /// Throws [ImageDecodeException] if [encodedImage] is not a readable image.
  Future<List<Barcode>> readAll(Uint8List encodedImage, {int? limit}) =>
      throw UnimplementedError('Stage 3');

  /// Finds the first barcode in raw pixels. Returns `null` if there is none.
  Future<Barcode?> readPixels(PixelBuffer image) =>
      throw UnimplementedError('Stage 3');

  /// Finds every barcode in raw pixels, up to [limit] if given.
  Future<List<Barcode>> readAllPixels(PixelBuffer image, {int? limit}) =>
      throw UnimplementedError('Stage 3');

  /// Creates a copy with the given fields replaced.
  BarcodeReader copyWith({
    Set<BarcodeFormat>? formats,
    ReaderOptions? options,
  }) => BarcodeReader(
    formats: formats ?? this.formats,
    options: options ?? this.options,
  );

  @override
  bool operator ==(Object other) =>
      other is BarcodeReader &&
      setEquals(other.formats, formats) &&
      other.options == options;

  @override
  int get hashCode => Object.hash(
    formats == null ? null : Object.hashAllUnordered(formats!),
    options,
  );
}
