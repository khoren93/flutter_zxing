import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../barcode/barcode.dart';
import '../../barcode/barcode_format.dart';
import '../../rendering/barcode_style.dart';
import '../../rendering/barcode_view.dart';
import '../../writing/barcode_writer.dart';
import 'scanner_icons.dart';
import 'scanner_theme.dart';

/// How a [BarcodeThumbnail] pictures a barcode.
enum BarcodeThumbnailKind {
  /// The modules the reader sampled, drawn as vectors: matrix codes.
  exact,

  /// Drawn again from the text, which these codes encode in exactly one
  /// way: EAN-13, EAN-8, UPC-A, UPC-E, ITF.
  regenerated,

  /// The camera's cut-out (`BarcodeCapture.snapshot`): codes that could
  /// look different when drawn again.
  cutOut,
}

/// The picture of a scanned barcode, for result sheets and lists of scans:
/// the sharpest picture that is still exactly the code scanned.
///
/// * A matrix code (QR, Micro QR, rMQR, Data Matrix, Aztec) is drawn from
///   the modules the reader sampled ([Barcode.symbol]), sharp at any size.
/// * EAN-13, EAN-8, UPC-A, UPC-E and ITF have exactly one way to draw their
///   digits: they are drawn again.
/// * Anything else (Code 128 can encode one text in several ways, PDF417
///   and DataBar too, an add-on is not in the text) shows [cutOut], the
///   camera's straightened cut-out, or an icon without it.
///
/// ```dart
/// BarcodeThumbnail(capture.barcode, cutOut: await capture.snapshot())
/// ```
///
/// In a history, keep a cut-out only where [needsCutOut] says so.
class BarcodeThumbnail extends StatelessWidget {
  /// Creates a thumbnail of [barcode].
  const BarcodeThumbnail(
    this.barcode, {
    super.key,
    this.cutOut,
    this.size = 56,
  });

  /// The barcode.
  final Barcode barcode;

  /// The camera's cut-out of the barcode, shown when it cannot be drawn
  /// exactly. Not disposed by the thumbnail.
  final ui.Image? cutOut;

  /// Width and height in logical pixels.
  final double size;

  /// Whether [barcode] is pictured from a cut-out: keep the cut-out of
  /// these, the others are drawn.
  static bool needsCutOut(Barcode barcode) =>
      barcodeThumbnailKindOf(barcode) == BarcodeThumbnailKind.cutOut;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final BarcodeThumbnailKind kind = barcodeThumbnailKindOf(barcode);
    final ui.Image? image = cutOut;
    final Widget picture =
        exactBarcodePicture(barcode, showText: size >= 96) ??
        (image != null
            ? RawImage(image: image, fit: BoxFit.cover)
            : Center(
                child: ScannerIcon(
                  barcode.format.isLinear
                      ? ScannerIcons.barcode
                      : ScannerIcons.qrCode,
                  size: size * 0.45,
                  color: const Color(0xFF6B7280),
                ),
              ));
    final bool photo = kind == BarcodeThumbnailKind.cutOut && image != null;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.21),
            border: Border.all(color: theme.lineColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.21),
            child: ColoredBox(
              color: photo ? const Color(0xFFECEBE7) : const Color(0xFFFFFFFF),
              child: Padding(
                padding: EdgeInsets.all(photo ? 0 : size * 0.11),
                child: Center(child: picture),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How [barcode] is pictured by a [BarcodeThumbnail].
BarcodeThumbnailKind barcodeThumbnailKindOf(Barcode barcode) {
  if (barcode.symbol != null && barcode.format != BarcodeFormat.maxiCode) {
    return BarcodeThumbnailKind.exact;
  }
  return _regenerated(barcode) == null
      ? BarcodeThumbnailKind.cutOut
      : BarcodeThumbnailKind.regenerated;
}

/// [barcode] drawn exactly, as a [BarcodeThumbnail] and the scan window
/// show it: dark modules on white, without a quiet zone, filling the space
/// it is given at the code's own proportions. [showText]: the digits under
/// a code drawn again. `null` for a code pictured by its cut-out
/// ([BarcodeThumbnailKind.cutOut]).
Widget? exactBarcodePicture(Barcode barcode, {bool showText = false}) =>
    switch (barcodeThumbnailKindOf(barcode)) {
      BarcodeThumbnailKind.exact => BarcodeView.symbol(
        barcode.symbol!,
        style: const BarcodeStyle(quietZone: false),
        semanticLabel: '',
      ),
      BarcodeThumbnailKind.regenerated => BarcodeView(
        barcode.text,
        writer: BarcodeWriter(_regenerated(barcode)!, showText: showText),
        style: const BarcodeStyle(quietZone: false),
        semanticLabel: '',
      ),
      BarcodeThumbnailKind.cutOut => null,
    };

/// The writable format that draws [barcode]'s text exactly as it was
/// printed, or `null` if there is none.
BarcodeFormat? _regenerated(Barcode barcode) {
  final String text = barcode.text;
  if (!RegExp(r'^\d+$').hasMatch(text)) {
    return null;
  }
  // Lengths without an add-on: with one, its digits follow in the text.
  return switch (barcode.format) {
    BarcodeFormat.ean13 ||
    BarcodeFormat.isbn when text.length == 13 => BarcodeFormat.ean13,
    BarcodeFormat.ean8 when text.length == 8 => BarcodeFormat.ean8,
    BarcodeFormat.upcA when text.length == 12 => BarcodeFormat.upcA,
    BarcodeFormat.upcE when text.length == 8 => BarcodeFormat.upcE,
    BarcodeFormat.itf ||
    BarcodeFormat.itf14 when text.length.isEven => BarcodeFormat.itf,
    _ => null,
  };
}
