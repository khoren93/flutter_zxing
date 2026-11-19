// `style.encodeContent(writer, content)`. The content and rendering layers
// do not know each other, so the bridge between them lives in the layer
// above both (see test/architecture_test.dart).
import '../content/barcode_content.dart';
import '../content/content_writer.dart';
import '../rendering/barcode_style.dart';
import '../rendering/logo_symbol.dart';
import '../writing/barcode_writer.dart';

/// `style.encodeContent(writer, content)`: a [BarcodeContent] encoded for a
/// [BarcodeStyle].
extension BarcodeStyleContent on BarcodeStyle {
  /// Encodes [content] with [writer] for this style: as
  /// `writer.encodeContent(content)` does ([BinaryContent] as bytes,
  /// [Gs1Content] as GS1, the rest as its payload), with the error
  /// correction and size a [BarcodeStyle.logo] needs, as
  /// [BarcodeStyle.encode] gives them.
  ///
  /// ```dart
  /// final style = BarcodeStyle(logo: BarcodeLogo(AssetImage('assets/logo.png')));
  /// final symbol = await style.encodeContent(
  ///   const BarcodeWriter(BarcodeFormat.qrCode),
  ///   const WifiContent(ssid: 'Cafe', password: 'espresso'),
  /// );
  /// final png = await style.toPng(symbol, size: 1024);
  /// ```
  ///
  /// Throws an [ArgumentError] if [BarcodeContent.validate] finds a
  /// problem, and a `BarcodeWriteException` if the format cannot hold the
  /// payload.
  Future<BarcodeSymbol> encodeContent(
    BarcodeWriter writer,
    BarcodeContent content,
  ) => encodeUnderLogo(
    writerUnderLogo(writer, logo),
    logo?.size,
    (BarcodeWriter w) => w.encodeContent(content),
  );
}
