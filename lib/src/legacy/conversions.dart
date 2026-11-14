// Mapping between the 3.x API and the 4.0 engine: formats, pixel formats,
// error correction, results, and the 3.x bitmap of a created barcode.
// Platform independent; not exported from the package.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import '../engine/engine_protocol.dart';
import '../errors.dart';
import '../reading/pixel_buffer.dart';
import '../writing/barcode_writer.dart';
import '../writing/creator_options.dart';
import 'models/models.dart';

/// What each 3.x [Format] bit searches for. Where zxing-cpp 3 groups several
/// variants under one symbology, the variants 3.x meant are listed: `Code39`
/// would also find Code 32 and PZN, which read as different text, and
/// `DataBar` would also find Expanded and Limited, which have bits of their
/// own.
const Map<int, List<BarcodeFormat>> _readFormats = <int, List<BarcodeFormat>>{
  Format.aztec: <BarcodeFormat>[BarcodeFormat.aztec],
  Format.codabar: <BarcodeFormat>[BarcodeFormat.codabar],
  Format.code39: <BarcodeFormat>[
    BarcodeFormat.code39Standard,
    BarcodeFormat.code39Extended,
  ],
  Format.code93: <BarcodeFormat>[BarcodeFormat.code93],
  Format.code128: <BarcodeFormat>[BarcodeFormat.code128],
  Format.dataBar: <BarcodeFormat>[
    BarcodeFormat.dataBarOmni,
    BarcodeFormat.dataBarStacked,
    BarcodeFormat.dataBarStackedOmni,
  ],
  Format.dataBarExpanded: <BarcodeFormat>[
    BarcodeFormat.dataBarExpanded,
    BarcodeFormat.dataBarExpandedStacked,
  ],
  Format.dataMatrix: <BarcodeFormat>[BarcodeFormat.dataMatrix],
  Format.ean8: <BarcodeFormat>[BarcodeFormat.ean8],
  Format.ean13: <BarcodeFormat>[BarcodeFormat.ean13],
  Format.itf: <BarcodeFormat>[BarcodeFormat.itf],
  Format.maxiCode: <BarcodeFormat>[BarcodeFormat.maxiCode],
  Format.pdf417: <BarcodeFormat>[
    BarcodeFormat.pdf417,
    BarcodeFormat.compactPdf417,
  ],
  Format.qrCode: <BarcodeFormat>[BarcodeFormat.qrCode],
  Format.upca: <BarcodeFormat>[BarcodeFormat.upcA],
  Format.upce: <BarcodeFormat>[BarcodeFormat.upcE],
  Format.microQRCode: <BarcodeFormat>[BarcodeFormat.microQrCode],
  Format.rmqrCode: <BarcodeFormat>[BarcodeFormat.rmqrCode],
  Format.dxFilmEdge: <BarcodeFormat>[BarcodeFormat.dxFilmEdge],
  Format.dataBarLimited: <BarcodeFormat>[BarcodeFormat.dataBarLimited],
  Format.telepen: <BarcodeFormat>[BarcodeFormat.telepen],
  Format.microPdf417: <BarcodeFormat>[BarcodeFormat.microPdf417],
};

/// The format filter for a 3.x [Format] mask; `null` (all formats) when no
/// known bit is set, as in 3.x.
Set<BarcodeFormat>? formatsOfMask(int mask) {
  final Set<BarcodeFormat> formats = <BarcodeFormat>{
    for (final MapEntry<int, List<BarcodeFormat>> e in _readFormats.entries)
      if ((mask & e.key) != 0) ...e.value,
  };
  return formats.isEmpty ? null : formats;
}

/// The 3.x [Format] bit of a result: the bit of its family, [Format.none]
/// for formats 3.x did not know (EAN-2/5 add-ons).
int formatBitOf(BarcodeFormat format) => switch (format) {
  BarcodeFormat.aztec ||
  BarcodeFormat.aztecCode ||
  BarcodeFormat.aztecRune => Format.aztec,
  BarcodeFormat.codabar => Format.codabar,
  BarcodeFormat.code39 ||
  BarcodeFormat.code39Standard ||
  BarcodeFormat.code39Extended ||
  BarcodeFormat.code32 ||
  BarcodeFormat.pzn => Format.code39,
  BarcodeFormat.code93 => Format.code93,
  BarcodeFormat.code128 => Format.code128,
  BarcodeFormat.dataBar ||
  BarcodeFormat.dataBarOmni ||
  BarcodeFormat.dataBarStacked ||
  BarcodeFormat.dataBarStackedOmni => Format.dataBar,
  BarcodeFormat.dataBarExpanded ||
  BarcodeFormat.dataBarExpandedStacked => Format.dataBarExpanded,
  BarcodeFormat.dataBarLimited => Format.dataBarLimited,
  BarcodeFormat.dataMatrix => Format.dataMatrix,
  BarcodeFormat.ean8 => Format.ean8,
  BarcodeFormat.ean13 ||
  BarcodeFormat.eanUpc ||
  BarcodeFormat.isbn => Format.ean13,
  BarcodeFormat.itf || BarcodeFormat.itf14 => Format.itf,
  BarcodeFormat.maxiCode => Format.maxiCode,
  BarcodeFormat.pdf417 || BarcodeFormat.compactPdf417 => Format.pdf417,
  BarcodeFormat.microPdf417 => Format.microPdf417,
  BarcodeFormat.qrCode ||
  BarcodeFormat.qrCodeModel1 ||
  BarcodeFormat.qrCodeModel2 => Format.qrCode,
  BarcodeFormat.microQrCode => Format.microQRCode,
  BarcodeFormat.rmqrCode => Format.rmqrCode,
  BarcodeFormat.upcA => Format.upca,
  BarcodeFormat.upcE => Format.upce,
  BarcodeFormat.dxFilmEdge => Format.dxFilmEdge,
  BarcodeFormat.telepen => Format.telepen,
  BarcodeFormat.ean5 ||
  BarcodeFormat.ean2 ||
  BarcodeFormat.unknown => Format.none,
};

/// The format a 3.x [Format] bit creates, `null` if 3.x could not create it.
BarcodeFormat? writeFormatOf(int format) => switch (format) {
  Format.aztec => BarcodeFormat.aztec,
  Format.codabar => BarcodeFormat.codabar,
  Format.code39 => BarcodeFormat.code39,
  Format.code93 => BarcodeFormat.code93,
  Format.code128 => BarcodeFormat.code128,
  Format.dataMatrix => BarcodeFormat.dataMatrix,
  Format.ean8 => BarcodeFormat.ean8,
  Format.ean13 => BarcodeFormat.ean13,
  Format.itf => BarcodeFormat.itf,
  Format.pdf417 => BarcodeFormat.pdf417,
  Format.qrCode => BarcodeFormat.qrCode,
  Format.upca => BarcodeFormat.upcA,
  Format.upce => BarcodeFormat.upcE,
  _ => null,
};

/// [EccLevel] in 4.0 terms.
ErrorCorrection errorCorrectionOf(EccLevel level) => switch (level) {
  EccLevel.low => ErrorCorrection.low,
  EccLevel.medium => ErrorCorrection.medium,
  EccLevel.quartile => ErrorCorrection.quartile,
  EccLevel.high => ErrorCorrection.high,
};

/// The [PixelLayout] of a 3.x [ImageFormat] the engine reads directly,
/// `null` for the ones that are converted first (see [pixelBufferOf]).
PixelLayout? pixelLayoutOf(int imageFormat) => switch (imageFormat) {
  ImageFormat.lum => PixelLayout.luminance,
  ImageFormat.rgb => PixelLayout.rgb,
  ImageFormat.rgba => PixelLayout.rgba,
  ImageFormat.bgra => PixelLayout.bgra,
  _ => null,
};

/// Raw pixels described by 3.x [DecodeParams] as a [PixelBuffer].
///
/// [ImageFormat.lumA], [ImageFormat.bgr], [ImageFormat.argb] and
/// [ImageFormat.abgr] are converted to a layout the engine reads. Throws
/// [ArgumentError] for an unknown format or a buffer smaller than the
/// geometry says.
PixelBuffer pixelBufferOf(
  Uint8List bytes,
  DecodeParams params, {
  int? width,
  int? height,
  int? rowStride,
}) {
  final int w = width ?? params.width;
  final int h = height ?? params.height;
  final int imageFormat = params.imageFormat;
  final int bytesPerPixel = imageFormat >> 24;
  final Rect? crop = params.cropWidth > 0 && params.cropHeight > 0
      ? Rect.fromLTWH(
          params.cropLeft.toDouble(),
          params.cropTop.toDouble(),
          params.cropWidth.toDouble(),
          params.cropHeight.toDouble(),
        )
      : null;
  final PixelLayout? layout = pixelLayoutOf(imageFormat);
  if (layout != null) {
    return PixelBuffer(
      bytes,
      width: w,
      height: h,
      layout: layout,
      rowStride: rowStride,
      crop: crop,
    );
  }
  final List<int>? order = switch (imageFormat) {
    ImageFormat.lumA => const <int>[0],
    ImageFormat.bgr => const <int>[2, 1, 0],
    ImageFormat.argb => const <int>[1, 2, 3, 0],
    ImageFormat.abgr => const <int>[3, 2, 1, 0],
    _ => null,
  };
  if (order == null || w <= 0 || h <= 0) {
    throw ArgumentError(
      'Unsupported image format 0x${imageFormat.toRadixString(16)} '
          'or size $w x $h',
      'params',
    );
  }
  final int stride = rowStride ?? w * bytesPerPixel;
  final int needed = stride * (h - 1) + w * bytesPerPixel;
  if (stride < w * bytesPerPixel || bytes.length < needed) {
    throw ArgumentError(
      '${bytes.length} bytes for a $w x $h image, at least $needed expected',
      'bytes',
    );
  }
  // Repack into the layout with the same channels in the engine's order.
  final int n = order.length;
  final Uint8List out = Uint8List(w * h * n);
  int o = 0;
  for (int y = 0; y < h; y++) {
    for (
      int i = y * stride, end = i + w * bytesPerPixel;
      i < end;
      i += bytesPerPixel
    ) {
      for (int c = 0; c < n; c++) {
        out[o++] = bytes[i + order[c]];
      }
    }
  }
  return PixelBuffer(
    out,
    width: w,
    height: h,
    layout: n == 1
        ? PixelLayout.luminance
        : n == 3
        ? PixelLayout.rgb
        : PixelLayout.rgba,
    crop: crop,
  );
}

/// Engine options for a 3.x read.
///
/// [maxSymbols] 1 is `readBarcode`, which in 3.x first asks for errors too
/// ([returnErrors]). [downscale] turns on zxing-cpp's downscaling, which
/// replaces 3.x's `maxSize` resize of image files.
EngineReadOptions readOptionsOf(
  DecodeParams params, {
  required int maxSymbols,
  bool returnErrors = false,
  bool downscale = false,
}) => EngineReadOptions(
  formats: EngineReadOptions.formatsToEngine(formatsOfMask(params.format)),
  flags:
      (params.tryHarder ? FzxFlags.tryHarder : 0) |
      (params.tryRotate ? FzxFlags.tryRotate : 0) |
      (params.tryInverted ? FzxFlags.tryInvert : 0) |
      (params.tryDownscale || downscale ? FzxFlags.tryDownscale : 0) |
      (returnErrors ? FzxFlags.returnErrors : 0),
  maxSymbols: maxSymbols,
);

/// `maxNumberOfSymbols` clamped as 3.x did (zxing-cpp keeps it in a byte).
int maxSymbolsOf(DecodeParams params) =>
    params.maxNumberOfSymbols.clamp(1, 255);

/// Whether 3.x `readBarcode` reads again after [first].
///
/// The first read includes symbols that were found but not decoded, so that
/// `onScanFailure` learns about them. But it stops at the first symbol, and
/// that can be such an error while a readable code is further on; so after
/// an error a second read without errors follows (#251), see [pickSingle].
bool needsRetry(Barcode? first) => first != null && !first.isValid;

/// What 3.x `readBarcode` returns from its [first] read and, after an
/// error, its [second] one.
Barcode? pickSingle(Barcode? first, Barcode? second) =>
    second != null && second.isValid ? second : first;

/// A 3.x [Code] for the result of a single read; [barcode] `null` means
/// nothing was found, which 3.x reported as an invalid code with an empty
/// error.
Code codeOf(
  Barcode? barcode, {
  required int imageWidth,
  required int imageHeight,
  required int duration,
  required CodeSource source,
  DebugImage? debugImage,
}) {
  final bool valid = barcode != null && barcode.isValid;
  return Code(
    text: valid ? barcode.text : null,
    isValid: valid,
    error: valid ? null : barcode?.error?.message ?? '',
    rawBytes: valid && barcode.bytes.isNotEmpty ? barcode.bytes : null,
    format: barcode == null ? Format.none : formatBitOf(barcode.format),
    position: _positionOf(barcode?.position, imageWidth, imageHeight),
    isInverted: barcode?.isInverted ?? false,
    isMirrored: barcode?.isMirrored ?? false,
    duration: duration,
    imageBytes: debugImage?.bytes,
    imageWidth: debugImage?.width,
    imageHeight: debugImage?.height,
    source: source,
  );
}

/// A 3.x [Code] for a read that failed with [error].
Code errorCode(Object error, CodeSource source) =>
    Code(error: errorMessage(error), format: Format.none, source: source);

/// The message of an error thrown by the engine or by [pixelBufferOf].
String errorMessage(Object error) => switch (error) {
  ZxingException(:final String message) => message,
  ArgumentError(:final Object? message) => '$message',
  _ => '$error',
};

Position _positionOf(BarcodePosition? p, int width, int height) {
  int x(Offset o) => o.dx.round();
  int y(Offset o) => o.dy.round();
  if (p == null) {
    return Position(width, height, 0, 0, 0, 0, 0, 0, 0, 0);
  }
  return Position(
    width,
    height,
    x(p.topLeft),
    y(p.topLeft),
    x(p.topRight),
    y(p.topRight),
    x(p.bottomLeft),
    y(p.bottomLeft),
    x(p.bottomRight),
    y(p.bottomRight),
  );
}

/// The luminance a read scanned, for [Code.imageBytes].
final class DebugImage {
  /// Creates a debug image.
  const DebugImage(this.bytes, this.width, this.height);

  /// The luminance of [image], cropped as the engine crops it.
  factory DebugImage.of(PixelBuffer image) {
    int left = 0;
    int top = 0;
    int w = image.width;
    int h = image.height;
    if (image.crop case final Rect crop) {
      // As zxing-cpp's ImageView::cropped.
      left = crop.left.round().clamp(0, image.width - 1);
      top = crop.top.round().clamp(0, image.height - 1);
      final int cw = crop.width.round();
      final int ch = crop.height.round();
      w = cw <= 0 ? image.width - left : math.min(image.width - left, cw);
      h = ch <= 0 ? image.height - top : math.min(image.height - top, ch);
    }
    final int bpp = image.layout.bytesPerPixel;
    final int stride = image.rowStride ?? image.width * bpp;
    final (int r, int g, int b) = switch (image.layout) {
      PixelLayout.luminance => (0, 0, 0),
      PixelLayout.rgb || PixelLayout.rgba => (0, 1, 2),
      PixelLayout.bgra => (2, 1, 0),
    };
    final Uint8List src = image.bytes;
    final Uint8List out = Uint8List(w * h);
    int o = 0;
    for (int y = 0; y < h; y++) {
      int i = (top + y) * stride + left * bpp;
      for (int x = 0; x < w; x++, i += bpp) {
        // zxing-cpp's RGBToLum: the identity for gray pixels.
        out[o++] =
            (306 * src[i + r] + 601 * src[i + g] + 117 * src[i + b] + 0x200) >>
            10;
      }
    }
    return DebugImage(out, w, h);
  }

  /// One byte per pixel.
  final Uint8List bytes;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;
}

/// zxing-cpp creator options for a 3.x encode.
///
/// Data Matrix is kept square, as the 3.x writer made it (zxing-cpp now also
/// picks rectangular DMRE sizes).
String creatorOptionsOf(BarcodeFormat format, EncodeParams params) =>
    creatorOptions(
      format,
      errorCorrection: errorCorrectionOf(params.eccLevel),
      options: format == BarcodeFormat.dataMatrix ? 'forceSquare' : null,
    );

/// The 3.x bitmap of a created [symbol]: one byte per pixel, 0 dark and 255
/// light, at least `params.width` x `params.height`.
///
/// Laid out as the 3.x writer did. Matrix symbols are scaled by a whole
/// number of pixels per module to fit the requested size with
/// `params.margin` pixels around them, and centred; a symbol that does not
/// fit grows the bitmap. Linear symbols fill the requested height, their
/// bars widened by a whole factor so that the code plus `params.margin`
/// (both sides together) fits the requested width. A negative margin means
/// the quiet zone the symbology requires.
Encode encodeOf(EngineSymbol symbol, EncodeParams params, String contents) {
  final bool linear = writeFormatOf(params.format)?.isLinear ?? false;
  final int codeWidth = symbol.width;
  final int codeHeight = symbol.height;
  final Uint8List modules = symbol.modules;
  final int width;
  final int height;
  final Uint8List data;
  if (linear) {
    final int margin = params.margin >= 0
        ? params.margin
        : symbol.quietZoneLeft + symbol.quietZoneRight;
    final int fullWidth = codeWidth + margin;
    width = math.max(params.width, fullWidth);
    height = math.max(1, params.height);
    final int scale = width ~/ fullWidth;
    final int left = (width - codeWidth * scale) ~/ 2;
    // The top row crosses every bar (EAN guard bars only reach lower).
    final Uint8List row = Uint8List(width)..fillRange(0, width, 255);
    for (int x = 0; x < codeWidth; x++) {
      if (modules[x] != 0) {
        row.fillRange(left + x * scale, left + (x + 1) * scale, 0);
      }
    }
    data = Uint8List(width * height);
    for (int y = 0; y < height; y++) {
      data.setRange(y * width, (y + 1) * width, row);
    }
  } else {
    final int margin = params.margin >= 0
        ? params.margin
        : math.max(symbol.quietZoneLeft, symbol.quietZoneTop);
    width = math.max(params.width, codeWidth + 2 * margin);
    height = math.max(params.height, codeHeight + 2 * margin);
    final int scale = math.min(
      (width - 2 * margin) ~/ codeWidth,
      (height - 2 * margin) ~/ codeHeight,
    );
    final int left = (width - codeWidth * scale) ~/ 2;
    final int top = (height - codeHeight * scale) ~/ 2;
    data = Uint8List(width * height)..fillRange(0, width * height, 255);
    for (int y = 0; y < codeHeight; y++) {
      for (int x = 0; x < codeWidth; x++) {
        if (modules[y * codeWidth + x] == 0) {
          continue;
        }
        final int px = left + x * scale;
        for (int py = top + y * scale, end = py + scale; py < end; py++) {
          data.fillRange(py * width + px, py * width + px + scale, 0);
        }
      }
    }
  }
  return Encode(
    true,
    params.format,
    contents,
    data,
    data.length,
    null,
    width: width,
    height: height,
  );
}

/// A failed 3.x encode.
Encode encodeError(EncodeParams params, String contents, Object error) =>
    Encode(false, params.format, contents, null, 0, errorMessage(error));
