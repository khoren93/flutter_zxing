// zxing-cpp creator options, shared by BarcodeWriter and the 3.x encoder.
// Not exported from the package.
import '../barcode/barcode_format.dart';
import 'barcode_writer.dart';

/// The zxing-cpp creator options of [writer]: its `zxingOptions`, then its
/// typed fields.
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

/// The zxing-cpp creator options string: the raw [options], then the
/// typed settings. zxing-cpp takes the first value of a key, so the raw
/// options win.
String creatorOptions(
  BarcodeFormat format, {
  ErrorCorrection? errorCorrection,
  int? version,
  bool gs1 = false,
  String? options,
}) => <String>[
  if (options != null && options.trim().isNotEmpty) options.trim(),
  if (errorCorrection != null)
    if (_ecLevel(format, errorCorrection) case final String level)
      'ecLevel=$level',
  if (version != null) 'version=$version',
  if (gs1) 'gs1',
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

/// The `version` values zint takes for [format], `null` if it has none.
(int, int)? versionRange(BarcodeFormat format) => switch (format) {
  BarcodeFormat.qrCode || BarcodeFormat.qrCodeModel2 => (1, 40),
  BarcodeFormat.microQrCode => (1, 4),
  BarcodeFormat.rmqrCode => (1, 38),
  BarcodeFormat.dataMatrix => (1, 48),
  BarcodeFormat.aztec || BarcodeFormat.aztecCode => (1, 36),
  BarcodeFormat.pdf417 || BarcodeFormat.compactPdf417 => (1, 30),
  BarcodeFormat.microPdf417 => (1, 4),
  _ => null,
};

/// The creator option keys zxing-cpp knows (`CreatorOptions` in
/// CreateBarcode.cpp), by their name without case and underscores, as
/// zxing-cpp compares them.
const Map<String, String> _keys = <String, String>{
  'eclevel': 'ecLevel',
  'eci': 'eci',
  'gs1': 'gs1',
  'readerinit': 'readerInit',
  'forcesquare': 'forceSquare',
  'extraescapemode': 'extraEscapeMode',
  'columns': 'columns',
  'rows': 'rows',
  'version': 'version',
  'datamask': 'dataMask',
};

const Set<String> _intKeys = <String>{'version', 'columns', 'rows', 'dataMask'};

const Set<String> _boolKeys = <String>{
  'gs1',
  'readerInit',
  'forceSquare',
  'extraEscapeMode',
};

const Set<String> _boolValues = <String>{'', 'true', 'false', '1', '0'};

/// Throws [ArgumentError] if [writer]'s version is outside its format's
/// range, or its `zxingOptions` hold a key zxing-cpp does not know or a
/// value it cannot take.
void checkWriter(BarcodeWriter writer) {
  if (writer.version case final int version) {
    _checkVersion(writer.format, version, 'version');
  }
  final String? options = writer.zxingOptions;
  if (options == null) {
    return;
  }
  Never fail(String message) =>
      throw ArgumentError.value(options, 'zxingOptions', message);
  // As zxing-cpp's JsonFind reads them: `key`, `key=value` or `key:value`,
  // separated by commas, with quotes and braces trimmed.
  for (final String part in options.split(',')) {
    final String pair = _trim(part);
    if (pair.isEmpty) {
      continue;
    }
    final int sep = pair.indexOf(RegExp('[:=]'));
    final String name = _trim(sep < 0 ? pair : pair.substring(0, sep));
    final String? value = sep < 0 ? null : _trim(pair.substring(sep + 1));
    final String? key = _keys[name.toLowerCase().replaceAll('_', '')];
    if (key == null) {
      fail('Unknown option "$name"; known: ${_keys.values.join(', ')}');
    }
    if (_intKeys.contains(key)) {
      final int? n = value == null ? null : int.tryParse(value);
      if (n == null) {
        fail('$key takes a whole number: "$pair"');
      }
      if (key == 'version') {
        _checkVersion(writer.format, n, 'zxingOptions');
      }
    } else if (_boolKeys.contains(key)) {
      if (value != null && !_boolValues.contains(value.toLowerCase())) {
        fail('$key is true or false: "$pair"');
      }
    } else if (key == 'ecLevel') {
      if (value == null || !RegExp(r'^(?:[LMQH]|\d+%?)$').hasMatch(value)) {
        fail('ecLevel is L, M, Q, H, a number or a percentage: "$pair"');
      }
    } else if (value == null || value.isEmpty) {
      fail('$key takes a value: "$pair"');
    }
  }
}

void _checkVersion(BarcodeFormat format, int version, String name) {
  final (int, int)? range = versionRange(format);
  if (range == null) {
    throw ArgumentError.value(
      version,
      name,
      'BarcodeFormat.${format.name} has no versions',
    );
  }
  final (int min, int max) = range;
  if (version < min || version > max) {
    throw RangeError.range(
      version,
      min,
      max,
      name,
      'Not a version of BarcodeFormat.${format.name}',
    );
  }
}

/// [s] without whitespace, quotes and braces at its ends, like `Trim` in
/// zxing-cpp's JSON.cpp.
String _trim(String s) {
  const String chars = ' \t\n\r"\'{}';
  int start = 0;
  int end = s.length;
  while (start < end && chars.contains(s[start])) {
    start++;
  }
  while (end > start && chars.contains(s[end - 1])) {
    end--;
  }
  return s.substring(start, end);
}

/// The [ErrorCorrection] of a QR code, Micro QR code or rMQR code from the
/// engine's [ecLevel] (`L`, `M`, `Q`, `H`); `null` for other formats.
ErrorCorrection? errorCorrectionOf(BarcodeFormat format, String? ecLevel) {
  // Micro QR and rMQR are of the QR symbology.
  if (format.symbology != BarcodeFormat.qrCode) {
    return null;
  }
  return switch (ecLevel) {
    'L' => ErrorCorrection.low,
    'M' => ErrorCorrection.medium,
    'Q' => ErrorCorrection.quartile,
    'H' => ErrorCorrection.high,
    _ => null,
  };
}
