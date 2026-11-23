// `style.encodeContent(content)` and `BarcodeContentView`. The content and
// rendering layers do not know each other, so the bridge between them lives
// in the layer above both (see test/architecture_test.dart).
import 'package:flutter/widgets.dart';

import '../barcode/barcode_format.dart';
import '../content/barcode_content.dart';
import '../content/content_writer.dart';
import '../errors.dart';
import '../rendering/barcode_style.dart';
import '../rendering/barcode_view.dart';
import '../rendering/logo_symbol.dart';
import '../writing/barcode_writer.dart';

/// `style.encodeContent(content)`: a [BarcodeContent] encoded for a
/// [BarcodeStyle].
extension BarcodeStyleContent on BarcodeStyle {
  /// Encodes [content] with [writer] (a QR code by default) for this
  /// style, with what its standard requires: [BinaryContent] as bytes,
  /// [Gs1Content] as GS1, an [EpcPaymentContent] or [SwissQrBillContent]
  /// as a QR code with error correction M (a logo may raise it), the rest
  /// as its payload. Under a [BarcodeStyle.logo] a QR code gets the error
  /// correction and size the logo needs, as [BarcodeStyle.encode] gives
  /// them. Draw the result with [BarcodeStyle.toPng] or
  /// [BarcodeStyle.toSvg].
  ///
  /// ```dart
  /// final style = BarcodeStyle(logo: BarcodeLogo(AssetImage('assets/logo.png')));
  /// final symbol = await style.encodeContent(
  ///   const WifiContent(ssid: 'Cafe', password: 'espresso'),
  /// );
  /// final png = await style.toPng(symbol, size: 1024);
  /// ```
  ///
  /// Throws an [ArgumentError] if [BarcodeContent.validate] finds a
  /// problem, and a `BarcodeWriteException` if the format cannot hold the
  /// payload.
  Future<BarcodeSymbol> encodeContent(
    BarcodeContent content, {
    BarcodeWriter writer = const BarcodeWriter(BarcodeFormat.qrCode),
  }) => encodeUnderLogo(
    writerUnderLogo(_writerFor(content, writer, logo), logo),
    logo?.size,
    (BarcodeWriter w) => w.encodeContent(content),
  );
}

/// Shows a [BarcodeContent] as a barcode drawn with what its standard
/// requires: a `BarcodeView` of its payload.
///
/// * A [SwissQrBillContent] gets [BarcodeStyle.swissQrBill] (the Swiss
///   cross) unless a [style] is given.
/// * An [EpcPaymentContent] or [SwissQrBillContent] is a QR code with
///   error correction M, as the EPC and the Swiss Payment Standards ask.
/// * A [Gs1Content] is encoded as GS1, a [BinaryContent] byte for byte.
/// * A content whose [BarcodeContent.validate] finds problems shows
///   [errorBuilder] instead of a code.
///
/// ```dart
/// BarcodeContentView(
///   const EpcPaymentContent(
///     name: 'Kaffeehaus Lumen GmbH',
///     iban: 'DE89370400440532013000',
///     amount: '19.50',
///   ),
///   width: 220,
///   errorBuilder: (context, error) => Text(error.message),
/// )
/// ```
class BarcodeContentView extends StatelessWidget {
  /// Creates a view of [content], encoded with [writer] (a QR code by
  /// default).
  const BarcodeContentView(
    this.content, {
    super.key,
    this.writer = const BarcodeWriter(BarcodeFormat.qrCode),
    this.style,
    this.width,
    this.height,
    this.semanticLabel,
    this.errorBuilder,
  });

  /// What the code holds.
  final BarcodeContent content;

  /// Encodes the payload: the format, error correction, version and the
  /// text under linear barcodes. A payment standard that needs a QR code
  /// with error correction M gets it, whatever this says.
  final BarcodeWriter writer;

  /// Colors, shapes, logo, title, caption and quiet zone;
  /// [BarcodeStyle.swissQrBill] for a [SwissQrBillContent] and
  /// [BarcodeStyle.classic] for the rest when `null`.
  final BarcodeStyle? style;

  /// Width in logical pixels.
  final double? width;

  /// Height in logical pixels.
  final double? height;

  /// Accessibility label; see `BarcodeView.semanticLabel`.
  final String? semanticLabel;

  /// Shown instead of the barcode if [content] has problems
  /// ([BarcodeContent.validate]; the error's message lists them, one per
  /// line) or cannot be encoded. Without it, an empty box is shown.
  final Widget Function(BuildContext context, BarcodeWriteException error)?
  errorBuilder;

  @override
  Widget build(BuildContext context) {
    final List<ContentIssue> issues = content.validate();
    if (issues.isNotEmpty) {
      final BarcodeWriteException error = BarcodeWriteException(
        issues.map((ContentIssue i) => i.message).join('\n'),
      );
      return errorBuilder?.call(context, error) ??
          SizedBox(width: width, height: height);
    }
    final BarcodeStyle shown =
        style ??
        (content is SwissQrBillContent
            ? BarcodeStyle.swissQrBill
            : BarcodeStyle.classic);
    final BarcodeWriter w = _writerFor(content, writer, shown.logo);
    final BarcodeContent c = content;
    return c is BinaryContent
        ? BarcodeView.bytes(
            c.bytes,
            writer: w,
            style: shown,
            width: width,
            height: height,
            semanticLabel: semanticLabel,
            errorBuilder: errorBuilder,
          )
        : BarcodeView(
            c.toPayload(),
            writer: w,
            style: shown,
            width: width,
            height: height,
            semanticLabel: semanticLabel,
            errorBuilder: errorBuilder,
          );
  }
}

/// [writer] with what [content]'s standard requires: GS1 for GS1 data; a
/// QR code with error correction M for the EPC and the Swiss QR-bill (a
/// [logo] that needs more raises it).
BarcodeWriter _writerFor(
  BarcodeContent content,
  BarcodeWriter writer,
  BarcodeLogo? logo,
) => switch (content) {
  Gs1Content() => writer.gs1 ? writer : writer.copyWith(gs1: true),
  EpcPaymentContent() || SwissQrBillContent() => BarcodeWriter(
    BarcodeFormat.qrCode,
    errorCorrection: logo == null ? ErrorCorrection.medium : null,
    version: writer.version,
  ),
  _ => writer,
};
