// The corpus check, shared by three runners:
//   - test/engine/corpus_test.dart        host (`flutter test`), all ~950
//                                         samples from build/fixtures/corpus/;
//                                         also regenerates the expected results
//   - example/integration_test/corpus_test.dart   every native platform
//   - example/lib/corpus_web.dart         the web build in a headless browser
// The last two read the subset in example/assets/fixtures/corpus/. Both sets
// are generated from the zxing-cpp submodule by tool/make_fixtures.dart
// (`make fixtures`) and not committed.
//
// It lives in the example app because web builds cannot import files from
// outside the app's package; the host test imports it by relative path.
//
// Every image is compared
//   1. with zxing-cpp's own expectations (.txt, .bin, .result.txt), the way
//      its blackbox tests do: text in TextMode::Plain, .result.txt keys one by
//      one;
//   2. with example/assets/fixtures/corpus_expected.json, the results recorded
//      on one platform: every platform has to find exactly the same barcodes.
// On top of the files: a synthetic 12 MP photo with a small dense QR code
// (#74), and a symbol of every writable format, created and read back.
//
// No dependency on flutter_test, so that the web runner can use it in an app.
// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/barcode/barcode_format.dart';
import 'package:flutter_zxing/src/engine/engine.dart';
import 'package:flutter_zxing/src/engine/engine_protocol.dart';

/// Image extensions of the fixtures.
const List<String> corpusImageExtensions = <String>['.png', '.jpg', '.gif'];

/// Pixels a corner may differ between platforms (floating point in the
/// detectors). Text, format and the other fields must match exactly.
const int corpusPositionTolerance = 2;

/// Fixtures whose zxing-cpp expectation does not apply: by name prefix, or
/// by exact name when the key ends with a dot.
const Map<String, String> corpusExpectationExceptions = <String, String>{
  // zxing-cpp reads these with eanAddOnSymbol=Read; ReaderOptions has no
  // such option, so the add-on is not part of the text.
  'ean13-extension-1__': 'EAN-2/5 add-on symbols are not read',
  'upca-extension-1__': 'EAN-2/5 add-on symbols are not read',
  // With all formats enabled, zxing-cpp 3.1.1 reads a wrong EAN-13 (valid
  // checksum, a leading digit no UPC-A can have) from these UPC-A photos.
  // zxing-cpp's own tests read these directories as UPC-A only, which rules
  // that out. corpus_expected.json still pins what is read.
  'upca-2__48.': 'zxing-cpp misread with all formats',
  'upca-4__1.': 'zxing-cpp misread with all formats',
  'upca-4__2.': 'zxing-cpp misread with all formats',
};

/// One image and what zxing-cpp expects from it.
class CorpusFixture {
  /// Creates a fixture.
  const CorpusFixture(
    this.name,
    this.image, {
    this.text,
    this.bytes,
    this.properties = const <String, String>{},
  });

  /// File name without extension, e.g. `qrcode-2__19`.
  final String name;

  /// The encoded image.
  final Uint8List image;

  /// Expected text (.txt), if any.
  final String? text;

  /// Expected bytes (.bin), if any.
  final Uint8List? bytes;

  /// Expected properties (.result.txt `key=value` lines).
  final Map<String, String> properties;

  /// Whether zxing-cpp states an expectation for this image that applies.
  bool get hasExpectation =>
      (text != null || bytes != null || properties.isNotEmpty) &&
      !corpusExpectationExceptions.keys.any(
        (String k) => k.endsWith('.')
            ? name == k.substring(0, k.length - 1)
            : name.startsWith(k),
      );
}

/// Loads fixtures. [files] lists the available file names (with
/// extension), [load] returns a file's content.
Future<List<CorpusFixture>> loadCorpus(
  Iterable<String> files,
  Future<Uint8List> Function(String file) load,
) async {
  final Set<String> available = files.toSet();
  final List<String> images =
      available
          .where(
            (String f) =>
                corpusImageExtensions.any((String e) => f.endsWith(e)),
          )
          .toList()
        ..sort();
  final List<CorpusFixture> fixtures = <CorpusFixture>[];
  for (final String file in images) {
    final String stem = file.substring(0, file.lastIndexOf('.'));
    Future<Uint8List?> sibling(String ext) async =>
        available.contains('$stem$ext') ? load('$stem$ext') : null;
    final Uint8List? text = await sibling('.txt');
    final Uint8List? result = await sibling('.result.txt');
    fixtures.add(
      CorpusFixture(
        stem.split('/').last,
        await load(file),
        text: text == null ? null : _normalizeText(utf8.decode(text)),
        bytes: await sibling('.bin'),
        properties: result == null
            ? const <String, String>{}
            : _parseProperties(utf8.decode(result)),
      ),
    );
  }
  return fixtures;
}

/// The outcome of a corpus run.
class CorpusReport {
  CorpusReport._(this.results, this.expected, this.correct, this.problems);

  /// Per fixture name, the barcodes found (see [barcodeToJson]) or
  /// `{'error': ...}`.
  final Map<String, Object> results;

  /// Fixtures zxing-cpp states an expectation for.
  final int expected;

  /// Of those, the ones read as expected.
  final int correct;

  /// Barcodes read with a different text or property than zxing-cpp expects.
  /// A missed barcode is not a problem here (zxing-cpp's own runs do not
  /// read every image with every setting); the expected results catch any
  /// change in what is found.
  final List<String> problems;

  /// The results as stored in example/assets/fixtures/corpus_expected.json:
  /// one line per image, so that a change shows as a readable diff.
  String toJson() {
    final List<String> names = results.keys.toList()..sort();
    final String entries = names
        .map((String n) => '    ${jsonEncode(n)}: ${jsonEncode(results[n])}')
        .join(',\n');
    return '{\n  "zxingCppVersion": ${jsonEncode(zxingCppVersion)},\n'
        '  "results": {\n$entries\n  }\n}\n';
  }

  /// One line for logs.
  String get summary {
    final int written = results.keys
        .where((String k) => k.startsWith(_writePrefix))
        .length;
    return 'corpus: ${results.length - written} images, $correct/$expected '
        'as zxing-cpp expects, $written symbols created, '
        '${problems.length} problems';
  }
}

const String _writePrefix = 'write__';

/// A barcode to create, then read back.
class _WriteCase {
  const _WriteCase(this.format, this.data, {this.options = '', this.binary});

  final BarcodeFormat format;
  final String data;
  final String options;
  final List<int>? binary;

  String get name =>
      '$_writePrefix${format.zxingName}${options.isEmpty ? '' : '_${options.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}'}${binary == null ? '' : '_bytes'}';
}

/// Every writable format, plus GS1 and binary data.
const List<_WriteCase> _writeCases = <_WriteCase>[
  _WriteCase(BarcodeFormat.qrCode, 'https://pub.dev/packages/flutter_zxing'),
  _WriteCase(BarcodeFormat.qrCode, 'ÄÖÜ äöü 日本語', options: 'ecLevel=H'),
  _WriteCase(
    BarcodeFormat.qrCode,
    '',
    binary: <int>[0, 1, 2, 127, 128, 254, 255],
  ),
  _WriteCase(BarcodeFormat.qrCodeModel2, 'Model 2', options: 'version=5'),
  _WriteCase(BarcodeFormat.dataMatrix, 'Data Matrix 0123456789'),
  _WriteCase(
    BarcodeFormat.dataMatrix,
    '(01)09501101530003(17)250101(10)ABC123',
    options: 'gs1',
  ),
  _WriteCase(BarcodeFormat.aztec, 'Aztec Code 4.0'),
  _WriteCase(BarcodeFormat.pdf417, 'PDF417 flutter_zxing'),
  _WriteCase(BarcodeFormat.code128, 'Code-128 abc'),
  _WriteCase(BarcodeFormat.code128, '(01)09501101530003', options: 'gs1'),
  _WriteCase(BarcodeFormat.code39, 'CODE39 TEST'),
  _WriteCase(BarcodeFormat.code39Standard, 'STANDARD'),
  _WriteCase(BarcodeFormat.code93, 'CODE93'),
  _WriteCase(BarcodeFormat.codabar, 'A123456B'),
  _WriteCase(BarcodeFormat.itf, '1234567890'),
  _WriteCase(BarcodeFormat.ean13, '950110153000'),
  _WriteCase(BarcodeFormat.ean8, '9638507'),
  _WriteCase(BarcodeFormat.upcA, '01234567890'),
  _WriteCase(BarcodeFormat.upcE, '0123456'),
];

/// Creates [_writeCases], records each symbol (size, quiet zones, a hash
/// of the modules) and reads it back from its rendered pixels.
Future<void> _runWriteCases(
  BarcodeEngine engine,
  Map<String, Object> results,
  List<String> problems,
) async {
  for (final _WriteCase c in _writeCases) {
    try {
      final EngineSymbol symbol = await engine.write(
        c.binary == null ? utf8.encode(c.data) : Uint8List.fromList(c.binary!),
        binary: c.binary != null,
        format: c.format.zxingName,
        options: c.options,
      );
      final List<Barcode> read = (await engine.readPixels(
        _render(symbol),
        EngineReadOptions.from(<BarcodeFormat>{
          c.format,
        }, const ReaderOptions()),
      )).barcodes;
      final bool same =
          read.isNotEmpty &&
          (c.binary == null
              ? read.first.text == symbol.text
              : _sameBytes(read.first.bytes, Uint8List.fromList(c.binary!)));
      if (!same) {
        problems.add(
          '${c.name}: read back ${read.map((Barcode b) => b.text).toList()}, '
          'created ${jsonEncode(symbol.text)}',
        );
      }
      results[c.name] = <String, Object>{
        'format': symbol.format.zxingName,
        'size': <int>[symbol.width, symbol.height],
        'quietZone': <int>[
          symbol.quietZoneLeft,
          symbol.quietZoneTop,
          symbol.quietZoneRight,
          symbol.quietZoneBottom,
        ],
        'text': symbol.text,
        if (symbol.ecLevel.isNotEmpty) 'ecLevel': symbol.ecLevel,
        'modules': _fnv1a(symbol.modules),
        'readBack': same,
      };
    } on Object catch (error) {
      results[c.name] = <String, String>{'error': '$error'};
      problems.add('${c.name}: $error');
    }
  }
}

/// The symbol as luminance pixels, 3 per module, with its quiet zones.
PixelBuffer _render(EngineSymbol s) {
  const int scale = 3;
  final int width = (s.width + s.quietZoneLeft + s.quietZoneRight) * scale;
  final int height = (s.height + s.quietZoneTop + s.quietZoneBottom) * scale;
  final Uint8List pixels = Uint8List(width * height)
    ..fillRange(0, width * height, 255);
  for (int y = 0; y < s.height; y++) {
    for (int x = 0; x < s.width; x++) {
      if (s.modules[y * s.width + x] == 0) {
        continue;
      }
      for (int dy = 0; dy < scale; dy++) {
        final int row = ((y + s.quietZoneTop) * scale + dy) * width;
        pixels.fillRange(
          row + (x + s.quietZoneLeft) * scale,
          row + (x + s.quietZoneLeft + 1) * scale,
          0,
        );
      }
    }
  }
  return PixelBuffer(pixels, width: width, height: height);
}

/// 32-bit FNV-1a, as hex: enough to tell module matrices apart.
String _fnv1a(Uint8List data) {
  int h = 0x811c9dc5;
  for (final int b in data) {
    h ^= b;
    // h * 0x01000193 mod 2^32, without products above 2^53: on the web
    // integers are doubles.
    h = ((h & 0xff) * 0x1000000 + h * 0x193) % 0x100000000;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

const String _photoName = 'synthetic__photo12mp';

/// Builds a 4000 x 3000 grey photo with noise and a small, dense QR code
/// (version 20+, 3 pixels per module) and reads it: the #74 case that 3.x
/// could not read with default settings. Generated, so it costs nothing in
/// git; deterministic, so every platform sees the same pixels.
Future<bool> _runSyntheticPhoto(
  BarcodeEngine engine,
  EngineReadOptions options,
  Map<String, Object> results,
  List<String> problems,
) async {
  final String text =
      'https://github.com/khoren93/flutter_zxing/issues/74 '
      '${List<String>.filled(40, 'dense payload').join(' ')}';
  try {
    final EngineSymbol qr = await engine.write(
      utf8.encode(text),
      binary: false,
      format: BarcodeFormat.qrCode.zxingName,
      options: 'ecLevel=M',
    );
    const int width = 4000;
    const int height = 3000;
    const int scale = 3;
    const int left = 2300;
    const int top = 1600;
    const int quiet = 4 * scale;
    final Uint8List pixels = Uint8List(width * height);
    int seed = 0x2545f491;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // xorshift32, masked so that the VM, dart2js and dart2wasm agree.
        seed ^= (seed << 13) & 0xffffffff;
        seed ^= seed >> 17;
        seed ^= (seed << 5) & 0xffffffff;
        final int noise = (seed & 0x3f) - 32;
        final int qx = x - left;
        final int qy = y - top;
        int base;
        if (qx >= -quiet &&
            qy >= -quiet &&
            qx < qr.width * scale + quiet &&
            qy < qr.height * scale + quiet) {
          final bool dark =
              qx >= 0 &&
              qy >= 0 &&
              qx < qr.width * scale &&
              qy < qr.height * scale &&
              qr.modules[(qy ~/ scale) * qr.width + qx ~/ scale] != 0;
          base = dark ? 60 : 200;
        } else {
          base = 90 + (x * 70 ~/ width) + (y * 40 ~/ height);
        }
        pixels[y * width + x] = (base + noise).clamp(0, 255);
      }
    }
    final List<Barcode> read = (await engine.readPixels(
      PixelBuffer(pixels, width: width, height: height),
      options,
    )).barcodes;
    results[_photoName] = read.map(barcodeToJson).toList();
    final bool ok = read.length == 1 && read.single.text == text;
    if (!ok) {
      problems.add(
        '$_photoName: read ${read.map((Barcode b) => b.text).toList()}',
      );
    }
    return ok;
  } on Object catch (error) {
    results[_photoName] = <String, String>{'error': '$error'};
    problems.add('$_photoName: $error');
    return false;
  }
}

/// Reads every fixture with the default file settings, all formats, every
/// barcode in the image; then creates a symbol of every writable format and
/// reads it back.
Future<CorpusReport> runCorpus(
  List<CorpusFixture> fixtures, {
  BarcodeEngine? engine,
}) async {
  final BarcodeEngine e = engine ?? BarcodeEngine.shared;
  final EngineReadOptions defaults = EngineReadOptions.from(
    null,
    const ReaderOptions(),
  );
  final EngineReadOptions options = EngineReadOptions(
    flags: defaults.flags | FzxFlags.textPlain,
    minLineCount: defaults.minLineCount,
  );
  final Map<String, Object> results = <String, Object>{};
  int expected = 0;
  int correct = 0;
  final List<String> problems = <String>[];
  for (final CorpusFixture f in fixtures) {
    List<Barcode> barcodes;
    try {
      barcodes = (await e.readImage(f.image, options)).barcodes;
    } on Object catch (error) {
      results[f.name] = <String, String>{'error': '$error'};
      problems.add('${f.name}: $error');
      continue;
    }
    results[f.name] = barcodes.map(barcodeToJson).toList();
    if (!f.hasExpectation) {
      continue;
    }
    expected++;
    if (barcodes.isEmpty) {
      continue;
    }
    // zxing-cpp reads one barcode per image; this run finds all of them, in
    // its own order, so any of them may be the expected one.
    final List<String?> mismatches = barcodes
        .map((Barcode b) => _checkExpectation(f, b))
        .toList();
    final String? mismatch = mismatches.contains(null)
        ? null
        : mismatches.first;
    if (mismatch == null) {
      correct++;
    } else {
      problems.add('${f.name}: $mismatch');
    }
  }
  expected++;
  if (await _runSyntheticPhoto(e, options, results, problems)) {
    correct++;
  }
  await _runWriteCases(e, results, problems);
  return CorpusReport._(results, expected, correct, problems);
}

/// Differences between [report] and the recorded results ([expectedJson],
/// the content of corpus_expected.json). Empty if they agree.
///
/// With [complete], every recorded image must have been run (the host run
/// of all samples); otherwise a subset is fine (devices, web).
List<String> compareCorpus(
  CorpusReport report,
  String expectedJson, {
  bool complete = false,
}) {
  final Map<String, dynamic> recorded =
      (jsonDecode(expectedJson) as Map<String, dynamic>)['results']
          as Map<String, dynamic>;
  final List<String> diffs = <String>[];
  for (final String name in <String>{
    if (complete) ...recorded.keys,
    ...report.results.keys,
  }) {
    final Object? want = recorded[name];
    final Object? got = report.results[name];
    if (want == null || got == null) {
      diffs.add('$name: ${want == null ? 'not recorded' : 'not run'}');
      continue;
    }
    final String? diff = _compareResult(want, got);
    if (diff != null) {
      diffs.add('$name: $diff');
    }
  }
  return diffs..sort();
}

/// A barcode as stored in the expected results.
Map<String, Object?> barcodeToJson(Barcode b) => <String, Object?>{
  'format': b.format.zxingName,
  'text': b.text,
  if (b.contentType != BarcodeContentType.text)
    'contentType': b.contentType.name,
  if (b.ecLevel != null) 'ecLevel': b.ecLevel,
  if (b.version != null) 'version': b.version,
  'symbologyIdentifier': b.symbologyIdentifier,
  if (b.orientation != 0) 'orientation': b.orientation,
  if (b.isInverted) 'inverted': true,
  if (b.isMirrored) 'mirrored': true,
  if (b.sequence != null)
    'sequence': <Object>[b.sequence!.index, b.sequence!.size, b.sequence!.id],
  if (b.error != null) 'error': b.error!.kind.name,
  'position': <int>[
    for (final Offset p in b.position.corners) ...<int>[
      p.dx.round(),
      p.dy.round(),
    ],
  ],
};

String? _compareResult(Object want, Object got) {
  if (want is! List<dynamic> || got is! List<dynamic>) {
    return jsonEncode(want) == jsonEncode(got)
        ? null
        : 'expected ${jsonEncode(want)}, got ${jsonEncode(got)}';
  }
  if (want.length != got.length) {
    return 'expected ${want.length} barcodes, got ${got.length}: '
        '${jsonEncode(got.map((dynamic b) => (b as Map<String, dynamic>)['text']).toList())}';
  }
  for (int i = 0; i < want.length; i++) {
    final Map<String, dynamic> w = Map<String, dynamic>.of(
      want[i] as Map<String, dynamic>,
    );
    final Map<String, dynamic> g = Map<String, dynamic>.of(
      got[i] as Map<String, dynamic>,
    );
    final List<int> wp = (w.remove('position') as List<dynamic>).cast<int>();
    final List<int> gp = (g.remove('position') as List<dynamic>).cast<int>();
    if (jsonEncode(w) != jsonEncode(g)) {
      return 'barcode $i: expected ${jsonEncode(w)}, got ${jsonEncode(g)}';
    }
    int deviation = 0;
    for (int j = 0; j < wp.length; j++) {
      deviation = math.max(deviation, (wp[j] - gp[j]).abs());
    }
    if (deviation > corpusPositionTolerance) {
      return 'barcode $i: position $gp, expected $wp';
    }
  }
  return null;
}

String? _checkExpectation(CorpusFixture f, Barcode b) {
  final String? format = f.properties['format'];
  if (format != null &&
      format != b.format.zxingName &&
      format != b.format.displayName) {
    return 'format ${b.format.zxingName}, expected $format';
  }
  final String? text = f.text;
  if (text != null && _normalizeText(b.text) != text) {
    return 'text ${jsonEncode(b.text)}, expected ${jsonEncode(text)}';
  }
  final Uint8List? bytes = f.bytes;
  if (bytes != null && !_sameBytes(b.bytes, bytes)) {
    return 'bytes differ from the .bin file';
  }
  for (final MapEntry<String, String> p in f.properties.entries) {
    final String? actual = _property(b, p.key);
    if (actual != null && actual != p.value) {
      return '${p.key}=$actual, expected ${p.value}';
    }
  }
  return null;
}

/// A .result.txt key of [b], `null` for keys the public API does not expose.
String? _property(Barcode b, String key) => switch (key) {
  'contentType' => _contentTypeName(b.contentType),
  'ecLevel' => b.ecLevel ?? '',
  'orientation' => '${b.orientation}',
  'symbologyIdentifier' => b.symbologyIdentifier,
  'sequenceSize' => '${b.sequence?.size ?? -1}',
  'sequenceIndex' => '${b.sequence?.index ?? -1}',
  'sequenceId' => b.sequence?.id ?? '',
  'isLastInSequence' => '${b.sequence?.isLast ?? false}',
  'isPartOfSequence' => '${b.sequence != null}',
  'isMirrored' => '${b.isMirrored}',
  'isInverted' => '${b.isInverted}',
  _ => null,
};

String _contentTypeName(BarcodeContentType t) => switch (t) {
  BarcodeContentType.text => 'Text',
  BarcodeContentType.binary => 'Binary',
  BarcodeContentType.mixed => 'Mixed',
  BarcodeContentType.gs1 => 'GS1',
  BarcodeContentType.iso15434 => 'ISO15434',
  BarcodeContentType.unknownEci => 'UnknownECI',
};

/// A checkout may have converted line endings of the expected text.
String _normalizeText(String s) => s.replaceAll('\r\n', '\n');

Map<String, String> _parseProperties(String s) => <String, String>{
  for (final String line in const LineSplitter().convert(s))
    if (line.isNotEmpty && !line.startsWith('#') && line.contains('='))
      line.substring(0, line.indexOf('=')): line.substring(
        line.indexOf('=') + 1,
      ),
};

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
