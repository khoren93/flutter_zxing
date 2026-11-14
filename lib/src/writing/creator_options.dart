// zxing-cpp creator options, shared by BarcodeWriter and the 3.x encoder.
// Not exported from the package.
import '../barcode/barcode_format.dart';
import 'barcode_writer.dart';

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
/// correction is fixed (Data Matrix, linear formats).
String? _ecLevel(BarcodeFormat format, ErrorCorrection level) =>
    switch (format.symbology) {
      BarcodeFormat.qrCode => const <String>['L', 'M', 'Q', 'H'][level.index],
      // Percentages zxing-cpp maps to Aztec's levels.
      BarcodeFormat.aztec => const <String>[
        '10%',
        '23%',
        '36%',
        '50%',
      ][level.index],
      // PDF417 security levels (0-8): more error correction codewords.
      BarcodeFormat.pdf417 => const <String>['2', '3', '4', '5'][level.index],
      _ => null,
    };
