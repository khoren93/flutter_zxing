import '../barcode/barcode_format.dart';
import '../writing/barcode_writer.dart';

/// The smallest QR version that still reads under a logo of [size], from
/// reading tests: in a small symbol a logo covers too many codewords.
int minimumLogoVersion(double size) => size <= 0.18
    ? 1
    : size <= 0.22
    ? 2
    : size <= 0.25
    ? 3
    : 4;

/// Encodes with [encode], in a larger symbol if a QR code would be too small
/// for a logo of [logoSize]. A version set on [writer] stays.
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
