// The pages of a BarcodeLabelSheet as PNG images: the geometry of the SVG
// and PDF pages, drawn on a canvas. Not exported from the package.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../writing/barcode_writer.dart';
import '../writing/symbol_layout.dart';
import 'barcode_painter.dart';
import 'barcode_style.dart';
import 'frame_layout.dart';
import 'label_sheet.dart';
import 'label_sheet_output.dart';
import 'styled_export.dart';
import 'symbol_shapes.dart';

/// The logo of [sheet]'s style for its PNG pages (`null` without one),
/// sharp at [dpi] on the largest code the labels hold.
///
/// Throws [ArgumentError] naming the image's error if it cannot be loaded.
Future<ImageInfo?> loadSheetLogoImage(BarcodeLabelSheet sheet, int dpi) async {
  final BarcodeLogo? logo = sheet.style.logo;
  if (logo == null || !hasFinderPatterns(sheet.writer.format)) {
    return null;
  }
  final Rect label = sheet.labelRect(0).deflate(sheet.padding);
  final double below = sheet.caption ? sheet.captionSize * (1 + captionGap) : 0;
  double side = math.min(label.width, label.height - below);
  if (sheet.codeSize case final double size) {
    side = math.min(side, size);
  }
  try {
    return await loadLogo(
      logo,
      math.max(32, side * logo.size.clamp(0.0, 0.3) / 25.4 * dpi),
    );
  } on Object catch (e) {
    throw ArgumentError('The logo of the style cannot be loaded: $e');
  }
}

/// The size in pixels of a page of [sheet] at [dpi].
(int, int) pngPageSize(BarcodeLabelSheet sheet, int dpi) => (
  (sheet.paper.width / 25.4 * dpi).round(),
  (sheet.paper.height / 25.4 * dpi).round(),
);

/// One page of [sheet] as a PNG at [dpi], white paper: [symbols] on the
/// labels [slots] name, [captions] under them, as [svgPage] places them.
/// [logo] is the style's logo, loaded once for the whole sheet. The PNG
/// says its [dpi], so it prints at the paper's size.
Future<Uint8List> pngPage(
  BarcodeLabelSheet sheet,
  List<BarcodeSymbol> symbols,
  List<String?> captions, {
  required int dpi,
  List<int>? slots,
  ui.Image? logo,
}) async {
  final double px = dpi / 25.4;
  final (int width, int height) = pngPageSize(sheet, dpi);
  final BarcodeStyle style = codeStyleOf(sheet);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder)
    ..drawColor(const Color(0xFFFFFFFF), ui.BlendMode.src);
  for (int i = 0; i < symbols.length; i++) {
    final BarcodeSymbol shown = styledSymbol(symbols[i], style);
    final SymbolLayout layout = SymbolLayout(shown);
    final String? caption = captions[i];
    final LabelPlacement at = placeLabel(
      sheet,
      sheet.labelRect(slots?[i] ?? i),
      layout,
      caption,
    );
    canvas
      ..save()
      ..translate(at.code.left * px, at.code.top * px);
    BarcodePainter(
      symbol: shown,
      layout: layout,
      frame: FrameLayout(layout, style),
      style: style,
      devicePixelRatio: 1,
      textStyle: const TextStyle(),
      logo: logo,
    ).paint(canvas, Size(at.code.width * px, at.code.height * px));
    canvas.restore();
    final Rect? box = at.captionBox;
    if (box != null && caption != null && caption.isNotEmpty) {
      final TextPainter text = TextPainter(
        text: TextSpan(
          text: caption,
          style: TextStyle(
            color: const Color(0xFF000000),
            fontSize: at.captionFontSize * px,
            fontFamily: 'Courier',
            fontFamilyFallback: const <String>[
              'Courier New',
              'Menlo',
              'monospace',
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final double baseline = text.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      text
        ..paint(
          canvas,
          Offset(
            box.center.dx * px - text.width / 2,
            at.baseline * px - baseline,
          ),
        )
        ..dispose();
    }
  }
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width, height);
  picture.dispose();
  try {
    final ByteData png = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!;
    return pngWithDpi(
      png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      dpi,
    );
  } finally {
    image.dispose();
  }
}

/// [png] with its resolution written in a `pHYs` chunk right after the
/// header (any `pHYs` it had is dropped): printed at [dpi], each pixel is
/// 1/[dpi] inch.
Uint8List pngWithDpi(Uint8List png, int dpi) {
  final ByteData data = ByteData.sublistView(png);
  final int perMetre = (dpi / 0.0254).round();
  final BytesBuilder out = BytesBuilder(copy: false)
    ..add(Uint8List.sublistView(png, 0, 8));
  int at = 8;
  while (at + 12 <= png.length) {
    final int length = data.getUint32(at);
    final String type = String.fromCharCodes(png, at + 4, at + 8);
    final int end = at + 12 + length;
    if (type != 'pHYs') {
      out.add(Uint8List.sublistView(png, at, end));
    }
    if (type == 'IHDR') {
      final ByteData chunk = ByteData(21)
        ..setUint32(0, 9)
        ..setUint32(8, perMetre)
        ..setUint32(12, perMetre)
        ..setUint8(16, 1); // the unit: the metre
      final Uint8List bytes = chunk.buffer.asUint8List();
      bytes.setRange(4, 8, 'pHYs'.codeUnits);
      chunk.setUint32(17, _crc32(Uint8List.sublistView(bytes, 4, 17)));
      out.add(bytes);
    }
    at = end;
  }
  return out.takeBytes();
}

/// The CRC-32 of a PNG chunk.
int _crc32(Uint8List bytes) {
  int crc = 0xFFFFFFFF;
  for (final int b in bytes) {
    crc ^= b;
    for (int k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? 0xEDB88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
