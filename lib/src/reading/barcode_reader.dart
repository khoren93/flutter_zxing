import 'package:flutter/foundation.dart';

import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import '../engine/engine.dart';
import '../engine/engine_protocol.dart';
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
  /// ```dart
  /// final XFile? photo = await ImagePicker().pickImage(source: ImageSource.gallery);
  /// final Barcode? barcode = await const BarcodeReader().read(await photo!.readAsBytes());
  /// ```
  ///
  /// Throws [ImageDecodeException] if [encodedImage] is not a readable image.
  Future<Barcode?> read(Uint8List encodedImage) async =>
      _first(await BarcodeEngine.shared.readImage(encodedImage, _options(1)));

  /// Finds every barcode in an encoded image, up to [limit] if given.
  ///
  /// ```dart
  /// const reader = BarcodeReader(formats: {BarcodeFormat.qrCode});
  /// for (final barcode in await reader.readAll(bytes)) {
  ///   print('${barcode.text} at ${barcode.position.center}');
  /// }
  /// ```
  ///
  /// Throws [ImageDecodeException] if [encodedImage] is not a readable image.
  Future<List<Barcode>> readAll(Uint8List encodedImage, {int? limit}) async =>
      (await BarcodeEngine.shared.readImage(
        encodedImage,
        _options(_limit(limit)),
      )).barcodes;

  /// Finds the first barcode in raw pixels. Returns `null` if there is none.
  ///
  /// ```dart
  /// final ByteData? rgba = await image.toByteData(); // a dart:ui image
  /// final Barcode? barcode = await const BarcodeReader().readPixels(
  ///   PixelBuffer(rgba!.buffer.asUint8List(), width: image.width, height: image.height, layout: PixelLayout.rgba),
  /// );
  /// ```
  ///
  /// Throws [ArgumentError] if [image] holds fewer bytes than its size says.
  Future<Barcode?> readPixels(PixelBuffer image) async =>
      _first(await BarcodeEngine.shared.readPixels(image, _options(1)));

  /// Finds every barcode in raw pixels, up to [limit] if given.
  ///
  /// ```dart
  /// // The Y plane of a camera frame, only the middle third.
  /// final List<Barcode> all = await const BarcodeReader().readAllPixels(
  ///   PixelBuffer(y.bytes, width: w, height: h, rowStride: y.bytesPerRow,
  ///       crop: Rect.fromLTWH(0, h / 3, w.toDouble(), h / 3)),
  /// );
  /// ```
  ///
  /// Throws [ArgumentError] if [image] holds fewer bytes than its size says.
  Future<List<Barcode>> readAllPixels(PixelBuffer image, {int? limit}) async =>
      (await BarcodeEngine.shared.readPixels(
        image,
        _options(_limit(limit)),
      )).barcodes;

  EngineReadOptions _options(int maxSymbols) =>
      EngineReadOptions.from(formats, options, maxSymbols: maxSymbols);

  static Barcode? _first(EngineReadResult result) =>
      result.barcodes.isEmpty ? null : result.barcodes.first;

  /// The engine's maxSymbols for [limit]: 0 means no limit.
  static int _limit(int? limit) {
    if (limit == null) {
      return 0;
    }
    if (limit < 1) {
      throw RangeError.value(limit, 'limit', 'Must be at least 1');
    }
    return limit;
  }

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
