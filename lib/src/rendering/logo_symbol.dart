// A QR code under a logo: the error correction and size it needs. Not
// exported from the package.
import '../barcode/barcode_format.dart';
import '../writing/barcode_writer.dart';
import 'barcode_style.dart';
import 'symbol_shapes.dart';

/// The smallest QR version that still reads under a logo of [size], from
/// reading tests: in a small symbol a logo covers too many codewords.
int minimumLogoVersion(double size) => size <= 0.18
    ? 1
    : size <= 0.22
    ? 2
    : size <= 0.25
    ? 3
    : 4;

/// [writer] as a [logo] needs it: a QR code gets the error correction the
/// logo needs ([BarcodeLogo.neededErrorCorrection]) unless the writer sets
/// its own.
BarcodeWriter writerUnderLogo(BarcodeWriter writer, BarcodeLogo? logo) =>
    logo != null &&
        writer.errorCorrection == null &&
        hasFinderPatterns(writer.format)
    ? writer.copyWith(errorCorrection: logo.neededErrorCorrection)
    : writer;

/// Encodes with [encode], in a larger symbol if a QR code would be too small
/// for a logo of [logoSize]. A version set on [writer] stays. Give it the
/// writer of [writerUnderLogo].
Future<BarcodeSymbol> encodeUnderLogo(
  BarcodeWriter writer,
  double? logoSize,
  Future<BarcodeSymbol> Function(BarcodeWriter writer) encode,
) async {
  final BarcodeSymbol symbol = await encode(writer);
  if (logoSize == null ||
      writer.format != BarcodeFormat.qrCode ||
      writer.version != null) {
    return symbol;
  }
  final int version = minimumLogoVersion(logoSize);
  return symbol.width < 17 + 4 * version
      ? encode(writer.copyWith(version: version))
      : symbol;
}

/// Whether [symbol] has the error correction [logo] needs, as far as it is
/// known: for an `assert`.
bool logoFits(BarcodeSymbol symbol, BarcodeLogo? logo) {
  final ErrorCorrection? level = symbol.errorCorrection;
  return logo == null ||
      level == null ||
      !hasFinderPatterns(symbol.format) ||
      level.index >= logo.neededErrorCorrection.index;
}

/// Why [logoFits] failed.
String logoFitsMessage(BarcodeSymbol symbol, BarcodeLogo logo) =>
    'The QR code has error correction ${symbol.errorCorrection?.name}, '
    'too little for a logo of size ${logo.size}, which needs '
    '${logo.neededErrorCorrection.name}: it may not scan. Encode it with '
    'style.encode(writer, data), or BarcodeView(data, writer: ...) without '
    'errorCorrection; to keep a lower level on purpose, set '
    'BarcodeLogo.errorCorrection.';
