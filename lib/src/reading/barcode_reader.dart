import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import '../engine/engine.dart';
import '../engine/engine_protocol.dart';
import '../engine/result_codec.dart';
import 'pixel_buffer.dart';
import 'reader_options.dart';

/// Reads barcodes from images: photos, files, screenshots, raw pixels.
///
/// Decoding runs in the background (an isolate on native platforms, a Web
/// Worker on the web) and never blocks the UI. There is nothing to create
/// or dispose: a reader is a constant configuration, the engine starts on
/// first use. If it cannot start, every call throws [EngineException]
/// (and the next call tries again).
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
  ///
  /// Every read throws [ArgumentError] if the set is empty (pass `null` to
  /// read every format) or holds a format that cannot be read
  /// ([BarcodeFormat.canRead]: not [BarcodeFormat.isbn], which is read as
  /// [BarcodeFormat.ean13], nor the EAN-2/EAN-5 add-ons, which come with
  /// their EAN-13 or UPC-A, see [ReaderOptions.eanAddOn]). The message
  /// names the formats as they are written in code (`BarcodeFormat.isbn`).
  final Set<BarcodeFormat>? formats;

  /// Search strategies.
  final ReaderOptions options;

  /// Finds the first barcode in an encoded image: any image Flutter
  /// decodes (`ui.instantiateImageCodec`). That is JPEG, PNG, GIF, BMP,
  /// WebP and WBMP everywhere, plus what the platform decodes for Flutter:
  /// HEIF/HEIC on Android 9+, for one, and on the web whatever the browser
  /// decodes. JPEG, PNG, GIF and BMP are decoded in the background by the
  /// engine; other formats by Flutter, which takes longer and more memory.
  /// A format Flutter cannot decode throws [ImageDecodeException]: convert
  /// it first (e.g. `image_picker` gives HEIC photos as JPEG by default).
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

  /// Finds every barcode in an encoded image, at most [maxBarcodes] if
  /// given (the same limit as `ScannerController.maxBarcodes`). Takes the
  /// same images as [read].
  ///
  /// ```dart
  /// const reader = BarcodeReader(formats: {BarcodeFormat.qrCode});
  /// for (final barcode in await reader.readAll(bytes)) {
  ///   print('${barcode.text} at ${barcode.position.center}');
  /// }
  /// ```
  ///
  /// Throws [ImageDecodeException] if [encodedImage] is not a readable
  /// image, and [RangeError] if [maxBarcodes] is less than 1.
  Future<List<Barcode>> readAll(
    Uint8List encodedImage, {
    int? maxBarcodes,
  }) async => (await BarcodeEngine.shared.readImage(
    encodedImage,
    _options(_limit(maxBarcodes)),
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

  /// Finds every barcode in raw pixels, at most [maxBarcodes] if given.
  ///
  /// ```dart
  /// // The Y plane of a camera frame, only the middle third.
  /// final List<Barcode> all = await const BarcodeReader().readAllPixels(
  ///   PixelBuffer(y.bytes, width: w, height: h, rowStride: y.bytesPerRow,
  ///       crop: Rect.fromLTWH(0, h / 3, w.toDouble(), h / 3)),
  /// );
  /// ```
  ///
  /// Throws [ArgumentError] if [image] holds fewer bytes than its size
  /// says, and [RangeError] if [maxBarcodes] is less than 1.
  Future<List<Barcode>> readAllPixels(
    PixelBuffer image, {
    int? maxBarcodes,
  }) async => (await BarcodeEngine.shared.readPixels(
    image,
    _options(_limit(maxBarcodes)),
  )).barcodes;

  /// Joins the parts of a structured append sequence (one message split
  /// across several barcodes, see [Barcode.sequence]) into one barcode that
  /// holds the whole message. Returns `null` until every part is there.
  ///
  /// Pass the barcodes in any order: as one image read them, or collected
  /// over several camera frames. Barcodes that are not part of a sequence,
  /// that could not be decoded or that repeat a part are skipped; if [parts]
  /// holds several sequences, the first complete one is returned.
  ///
  /// ```dart
  /// const reader = BarcodeReader();
  /// final Barcode? message = await reader.merge(await reader.readAll(bytes));
  /// ```
  ///
  /// The engine decodes the joined text: a character set one part declares
  /// carries over to the next, and [ReaderOptions.characterSet] applies
  /// where none is declared. The result has the bytes of all parts in
  /// sequence order, the format and symbol details of the first part, no
  /// [Barcode.sequence], and a [Barcode.position] that covers every part
  /// (meaningful when the parts come from one image).
  Future<Barcode?> merge(Iterable<Barcode> parts) async {
    final List<Barcode>? ordered = _sequence(parts);
    if (ordered == null) {
      return null;
    }
    final Barcode first = ordered.first;
    final Uint8List? input = mergeInput(ordered);
    final Set<BarcodeContentType> types = ordered
        .map((Barcode b) => b.contentType)
        .toSet();
    final EngineMerged merged = input != null
        ? await BarcodeEngine.shared.merge(
            input,
            options.characterSet?.engineId ?? 0,
          )
        : _joined(ordered, types);
    final Rect bounds = ordered
        .map((Barcode b) => b.position.bounds)
        .reduce((Rect a, Rect b) => a.expandToInclude(b));
    return Barcode(
      format: first.format,
      text: merged.text,
      bytes: merged.bytes,
      position: BarcodePosition(
        topLeft: bounds.topLeft,
        topRight: bounds.topRight,
        bottomRight: bounds.bottomRight,
        bottomLeft: bounds.bottomLeft,
      ),
      contentType: merged.contentType,
      rotation: first.rotation,
      isMirrored: first.isMirrored,
      isInverted: first.isInverted,
      ecLevel: first.ecLevel,
      version: first.version,
      symbologyIdentifier: first.symbologyIdentifier,
    );
  }

  /// The first complete sequence in [parts], in order.
  static List<Barcode>? _sequence(Iterable<Barcode> parts) {
    final Map<String, Map<int, Barcode>> sequences =
        <String, Map<int, Barcode>>{};
    for (final Barcode part in parts) {
      final BarcodeSequence? s = part.sequence;
      if (s == null || !part.isValid || s.index < 0) {
        continue;
      }
      (sequences[s.id] ??= <int, Barcode>{}).putIfAbsent(s.index, () => part);
    }
    for (final Map<int, Barcode> found in sequences.values) {
      // Some symbologies only know the size in the last part; 0 = unknown.
      final int size = found.values
          .map((Barcode b) => b.sequence!.size)
          .reduce(math.max);
      if (size > 0 &&
          found.length == size &&
          List<int>.generate(size, (int i) => i).every(found.containsKey)) {
        return List<Barcode>.generate(size, (int i) => found[i]!);
      }
    }
    return null;
  }

  /// Parts that did not come from the engine (built by hand): their texts
  /// joined, or their bytes decoded as a whole if they are UTF-8 text split
  /// between two parts.
  static EngineMerged _joined(
    List<Barcode> parts,
    Set<BarcodeContentType> types,
  ) {
    final Uint8List bytes = Uint8List.fromList(<int>[
      for (final Barcode b in parts) ...b.bytes,
    ]);
    final BarcodeContentType type = types.length == 1
        ? types.single
        : BarcodeContentType.mixed;
    String text = parts.map((Barcode b) => b.text).join();
    if (type == BarcodeContentType.text && bytes.any((int b) => b >= 0x80)) {
      try {
        text = utf8.decode(bytes);
      } on FormatException {
        // Another character set: keep the parts' texts.
      }
    }
    return EngineMerged(contentType: type, text: text, bytes: bytes);
  }

  EngineReadOptions _options(int maxSymbols) =>
      EngineReadOptions.from(formats, options, maxSymbols: maxSymbols);

  static Barcode? _first(EngineReadResult result) =>
      result.barcodes.isEmpty ? null : result.barcodes.first;

  /// The engine's maxSymbols for [maxBarcodes]: 0 means no limit.
  static int _limit(int? maxBarcodes) {
    if (maxBarcodes == null) {
      return 0;
    }
    if (maxBarcodes < 1) {
      throw RangeError.range(maxBarcodes, 1, null, 'maxBarcodes');
    }
    return maxBarcodes;
  }

  /// Creates a copy with the given fields replaced.
  ///
  /// A `null` argument keeps the field, so `copyWith` cannot set [formats]
  /// back to `null` (all formats). Create a new reader for that:
  /// `BarcodeReader(options: reader.options)`.
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

  /// The fields that differ from the defaults, e.g.
  /// `BarcodeReader(formats: {qrCode}, options: ReaderOptions(isPure: true))`.
  @override
  String toString() =>
      'BarcodeReader(${<String>[if (formats case final Set<BarcodeFormat> f) 'formats: {${f.map((BarcodeFormat f) => f.name).join(', ')}}', if (options != const ReaderOptions()) 'options: $options'].join(', ')})';
}
