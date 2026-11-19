// zxing-cpp creator options, shared by BarcodeWriter and the 3.x encoder.
// Not exported from the package.
import '../barcode/barcode_format.dart';
import 'barcode_writer.dart';

/// The zxing-cpp creator options of [writer]: its typed fields, then its
/// `zxingOptions`.
String writerCreatorOptions(BarcodeWriter writer) => creatorOptions(
  writer.format,
  // M rather than zxing-cpp's L: often no larger, and it survives print,
  // glare and scratches far better.
  errorCorrection:
      writer.errorCorrection ??
      (writer.format == BarcodeFormat.qrCode ||
              writer.format == BarcodeFormat.qrCodeModel2
          ? ErrorCorrection.medium
          : null),
  version: writer.version,
  gs1: writer.gs1,
  options: writer.zxingOptions,
);

/// The zxing-cpp creator options string: the typed settings, then the raw
/// [options] last so that they win.
String creatorOptions(
  BarcodeFormat format, {
  ErrorCorrection? errorCorrection,
  int? version,
  bool gs1 = false,
  String? options,
}) => <String>[
  if (errorCorrection != null)
    if (_ecLevel(format, errorCorrection) case final String level)
      'ecLevel=$level',
  if (version != null) 'version=$version',
  if (gs1) 'gs1',
  if (options != null && options.trim().isNotEmpty) options.trim(),
].join(',');

/// The zxing-cpp ecLevel for [level] in [format]'s terms, `null` where error
/// correction is fixed ([BarcodeFormat.hasErrorCorrection]).
String? _ecLevel(BarcodeFormat format, ErrorCorrection level) {
  if (!format.hasErrorCorrection) {
    return null;
  }
  return switch (format) {
    // Micro QR has no H and rMQR only M and H: the nearest level.
    BarcodeFormat.microQrCode => const <String>['L', 'M', 'Q', 'Q'],
    BarcodeFormat.rmqrCode => const <String>['M', 'M', 'H', 'H'],
    // Percentages zxing-cpp maps to Aztec's levels.
    BarcodeFormat.aztec ||
    BarcodeFormat.aztecCode => const <String>['10%', '23%', '36%', '50%'],
    // PDF417 security levels (0-8): more error correction codewords.
    BarcodeFormat.pdf417 ||
    BarcodeFormat.compactPdf417 => const <String>['2', '3', '4', '5'],
    _ => const <String>['L', 'M', 'Q', 'H'],
  }[level.index];
}
