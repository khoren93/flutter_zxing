// Prepares the engine's test corpus from zxing-cpp's blackbox samples
// (third_party/zxing-cpp/test/samples, part of the submodule). Nothing it
// writes is committed:
//
//   build/fixtures/corpus/            every sample: the host test
//                                     (test/engine/corpus_test.dart)
//   example/assets/fixtures/corpus/   a few per sample directory: bundled into
//                                     the example app for the device and web
//                                     runs (they cannot read the repository)
//
// Each image is copied as `<sample directory>__<name>.<ext>` (a second sample
// of the same name as `<name>_<its ext>`, e.g. rune-68_webp.png), with what
// zxing-cpp expects from it next to it (.txt, .bin, .result.txt, resolved from
// the samples' .txt and .toml files by [_expectedOf]), with only [A-Za-z0-9._-]
// in names:
// Flutter asset directories are not recursive, and a `#` would end the asset
// URL on the web. WebP samples become grayscale PNG: stb_image, which decodes
// files on every platform, has no WebP decoder, and the engine reads
// luminance only. The conversion is the one zxing-cpp's blackbox tests use:
// libwebp's RGB output (`dwebp -ppm`, i.e. WebPDecodeRGB) and zxing-cpp's
// RGBToLum. package:image is not used for decoding: its WebP
// decoder fails on some samples and returns inexact pixels for others,
// which made zxing-cpp miss barcodes it reads from the real pixels.
//
// Needs dwebp (libwebp) on PATH: `brew install webp` / `apt install webp`.
//
// The expected results of all samples are committed in
// example/assets/fixtures/corpus_expected.json; regenerate them after a
// deliberate change (zxing-cpp update) with
//   UPDATE_CORPUS=1 flutter test test/engine/corpus_test.dart
//
// usage (from the repository root): make fixtures
//   or: cd tool && dart run make_fixtures.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Images per sample directory in the example app's subset.
const int _perDirectory = 3;

/// Larger converted images are left out of the subset.
const int _maxSubsetBytes = 300 * 1024;

const Set<String> _imageExtensions = <String>{'.png', '.jpg', '.gif', '.webp'};

/// Always in the subset: GS1 Data Matrix and inverted (light on dark)
/// symbols.
const Set<String> _required = <String>{
  'datamatrix-1/gs1-figure-4.15.1-2-32x32',
  'qrcode-2/qr-inv-1',
  'rmqrcode-1/R7x43-H_inverted',
};

void main() {
  final String root = Directory.fromUri(
    Platform.script.resolve('..'),
  ).absolute.uri.toFilePath().replaceAll(RegExp(r'[/\\]$'), '');
  final Directory samples = Directory(
    '$root/third_party/zxing-cpp/test/samples',
  );
  if (!samples.existsSync()) {
    stderr.writeln(
      '${samples.path} is missing. Run: git submodule update --init',
    );
    exit(1);
  }
  try {
    Process.runSync('dwebp', <String>['-version']);
  } on ProcessException {
    stderr.writeln(
      'dwebp (libwebp) is needed: brew install webp / apt install webp',
    );
    exit(1);
  }
  final _Output full = _Output('$root/build/fixtures/corpus');
  final _Output subset = _Output('$root/example/assets/fixtures/corpus');

  final List<Directory> directories =
      samples.listSync().whereType<Directory>().toList()
        ..sort((Directory a, Directory b) => a.path.compareTo(b.path));
  for (final Directory dir in directories) {
    final String name = _basename(dir.path);
    final List<File> images =
        dir
            .listSync()
            .whereType<File>()
            .where((File f) => _imageExtensions.contains(_extension(f.path)))
            .toList()
          ..sort((File a, File b) => _natural(a.path, b.path));

    final Map<File, Uint8List> converted = <File, Uint8List>{
      for (final File image in images) image: _fixtureBytes(image),
    };
    final File defaultsFile = File('${dir.path}/!defaults.toml');
    final Map<String, String> defaults = defaultsFile.existsSync()
        ? _readToml(defaultsFile, const <String, String>{}).first
        : const <String, String>{};
    final Map<File, _Expected?> expected = <File, _Expected?>{
      for (final File image in images) image: _expectedOf(image, defaults),
    };
    for (final File image in images) {
      full.add(name, image, converted[image]!, expected[image]);
    }

    // The subset: the required ones, then picks spread over the directory
    // (its images get harder further in); all of multi-1.
    final List<File> required = images
        .where(
          (File f) => _required.contains('$name/${_basename(_stem(f.path))}'),
        )
        .toList();
    final int wanted =
        (name == 'multi-1' ? images.length : _perDirectory) + required.length;
    final List<File> candidates = <File>[
      ...required,
      for (int i = 0; i < wanted && i < images.length; i++)
        images[i * images.length ~/ wanted],
      ...images,
    ];
    final Set<File> taken = <File>{};
    for (final File image in candidates) {
      if (taken.length >= wanted) {
        break;
      }
      if (taken.contains(image) || converted[image]!.length > _maxSubsetBytes) {
        continue;
      }
      taken.add(image);
      subset.add(name, image, converted[image]!, expected[image]);
    }
  }
  stdout
    ..writeln(full)
    ..writeln(subset);
}

/// A fixture directory, emptied first (README.md excepted).
class _Output {
  _Output(String path) : _dir = Directory(path) {
    if (_dir.existsSync()) {
      for (final FileSystemEntity e in _dir.listSync()) {
        if (_basename(e.path) != 'README.md') {
          e.deleteSync(recursive: true);
        }
      }
    } else {
      _dir.createSync(recursive: true);
    }
  }

  final Directory _dir;
  int _images = 0;
  int _bytes = 0;

  /// The names written so far, without extension.
  final Set<String> _targets = <String>{};

  void add(
    String sampleDirectory,
    File image,
    Uint8List data,
    _Expected? expected,
  ) {
    final String stem = _stem(image.path);
    String target =
        '${_dir.path}/${sampleDirectory}__'
        '${_basename(stem).replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}';
    // Two samples with one name (rune-68.png and rune-68.webp): the second
    // keeps its extension in the name instead of replacing the first.
    if (!_targets.add(target)) {
      target = '${target}_${_extension(image.path).substring(1)}';
      if (!_targets.add(target)) {
        throw StateError('Two samples become ${_basename(target)}');
      }
    }
    final String ext = _extension(image.path) == '.webp'
        ? '.png'
        : _extension(image.path);
    File('$target$ext').writeAsBytesSync(data);
    final Uint8List? text = expected?.text;
    if (text != null) {
      File('$target.txt').writeAsBytesSync(text);
    }
    final Uint8List? bytes = expected?.bytes;
    if (bytes != null) {
      File('$target.bin').writeAsBytesSync(bytes);
    }
    final Map<String, String> properties =
        expected?.properties ?? const <String, String>{};
    if (properties.isNotEmpty) {
      File('$target.result.txt').writeAsStringSync(
        properties.entries
            .map((MapEntry<String, String> p) => '${p.key}=${p.value}\n')
            .join(),
      );
    }
    _images++;
    _bytes += data.length;
  }

  @override
  String toString() =>
      '$_images images, ${(_bytes / 1024 / 1024).toStringAsFixed(1)} MB '
      'in ${_dir.path}';
}

/// What zxing-cpp's blackbox tests expect from one image.
final class _Expected {
  const _Expected({this.text, this.bytes, required this.properties});

  final Uint8List? text;
  final Uint8List? bytes;

  /// In the names of the corpus harness, see [_propertyNames].
  final Map<String, String> properties;
}

/// The keys of the samples' .toml files that the corpus harness checks, by
/// the name it knows them.
const Map<String, String> _propertyNames = <String, String>{
  'Format': 'format',
  'Identifier': 'symbologyIdentifier',
  'ContentType': 'contentType',
  'IsInverted': 'isInverted',
  'IsMirrored': 'isMirrored',
  'SequenceIndex': 'sequenceIndex',
  'SequenceSize': 'sequenceSize',
  'SequenceId': 'sequenceId',
  'IsLastInSequence': 'isLastInSequence',
  'IsPartOfSequence': 'isPartOfSequence',
};

/// What zxing-cpp expects from [image], found the way its blackbox tests do
/// (readTestConfig in test/blackbox/BlackboxTestRunner.cpp): `a-1-2.png` is
/// described by the first of `a-1-2`, `a-1`, `a` with a .toml or .txt file,
/// on top of the directory's `!defaults.toml`. `null` when it expects no
/// single barcode: a name ending in `!` marks an image it cannot read, and
/// the corpus harness checks one barcode per image, not several.
_Expected? _expectedOf(File image, Map<String, String> defaults) {
  final String name = _basename(_stem(image.path));
  if (name.endsWith('!')) {
    return null;
  }
  final String directory = image.parent.path;
  String data = name;
  while (!File('$directory/$data.toml').existsSync() &&
      !File('$directory/$data.txt').existsSync()) {
    final int separator = data.lastIndexOf(RegExp(r'[-_!]'));
    if (separator < 0) {
      return null;
    }
    data = data.substring(0, separator);
  }
  final File toml = File('$directory/$data.toml');
  if (!toml.existsSync()) {
    return _Expected(
      text: File('$directory/$data.txt').readAsBytesSync(),
      properties: _properties(defaults),
    );
  }
  final List<Map<String, String>> symbols = _readToml(toml, defaults);
  if (symbols.length != 1 || (symbols.single['missing'] ?? '').contains('s')) {
    return null;
  }
  final Map<String, String> symbol = symbols.single;
  final String? text = symbol['TextPlain'];
  final String? hex = symbol['TextHex'];
  return _Expected(
    text: text == null ? null : utf8.encode(text),
    bytes: hex == null
        ? null
        : Uint8List.fromList(<int>[
            for (final String b in hex.trim().split(RegExp(r'\s+')))
              int.parse(b, radix: 16),
          ]),
    properties: _properties(symbol),
  );
}

Map<String, String> _properties(Map<String, String> values) => <String, String>{
  for (final MapEntry<String, String> name in _propertyNames.entries)
    if (values[name.key] != null) name.value: values[name.key]!,
};

/// The symbols a sample's .toml file describes: its top-level keys, on top
/// of [defaults], apply to each `[[symbol]]` table.
List<Map<String, String>> _readToml(File file, Map<String, String> defaults) {
  final List<Map<String, String>> symbols = <Map<String, String>>[];
  Map<String, String> shared = defaults;
  Map<String, String> current = Map<String, String>.of(defaults);
  bool topLevel = true;
  for (final String raw in const LineSplitter().convert(
    utf8.decode(file.readAsBytesSync()),
  )) {
    final String line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    if (line == '[[symbol]]') {
      if (topLevel) {
        topLevel = false;
        shared = current;
      } else {
        symbols.add(current);
      }
      current = Map<String, String>.of(shared);
      continue;
    }
    final int equals = line.indexOf('=');
    current[line.substring(0, equals).trim()] = _tomlValue(
      line.substring(equals + 1).trim(),
    );
  }
  return symbols..add(current);
}

/// A TOML value: a basic string without its quotes and escapes, anything
/// else as written.
String _tomlValue(String value) {
  if (value.length < 2 || !value.startsWith('"') || !value.endsWith('"')) {
    return value;
  }
  const Map<String, String> escapes = <String, String>{
    '"': '"',
    r'\': r'\',
    'b': '\b',
    't': '\t',
    'n': '\n',
    'f': '\f',
    'r': '\r',
  };
  return value
      .substring(1, value.length - 1)
      .replaceAllMapped(
        RegExp(r'\\(?:u([0-9a-fA-F]{4})|U([0-9a-fA-F]{8})|(.))'),
        (Match m) => m[3] != null
            ? escapes[m[3]]!
            : String.fromCharCode(int.parse(m[1] ?? m[2]!, radix: 16)),
      );
}

Uint8List _fixtureBytes(File image) {
  final Uint8List data = image.readAsBytesSync();
  if (_extension(image.path) != '.webp') {
    return data;
  }
  // `dwebp -ppm` is libwebp's WebPDecodeRGB, what zxing-cpp's own blackbox
  // tests decode WebP with (decoding to YUV instead fails some of them).
  final ProcessResult r = Process.runSync('dwebp', <String>[
    '-quiet',
    '-ppm',
    image.path,
    '-o',
    '-',
  ], stdoutEncoding: null);
  if (r.exitCode != 0) {
    throw StateError('dwebp failed on ${image.path}: ${r.stderr}');
  }
  // PPM: "P6\n<w> <h>\n255\n" and RGB triplets.
  final Uint8List ppm = Uint8List.fromList(r.stdout as List<int>);
  int offset = 0;
  final List<String> header = <String>[];
  while (header.length < 4) {
    while (ppm[offset] <= 32) {
      offset++;
    }
    final int start = offset;
    while (ppm[offset] > 32) {
      offset++;
    }
    header.add(String.fromCharCodes(ppm, start, offset));
  }
  offset++; // the single whitespace after maxval
  final int width = int.parse(header[1]);
  final int height = int.parse(header[2]);
  final img.Image grey = img.Image(
    width: width,
    height: height,
    numChannels: 1,
  );
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int p = offset + (y * width + x) * 3;
      // zxing-cpp's RGBToLum, as in its blackbox tests.
      grey.setPixelR(
        x,
        y,
        (306 * ppm[p] + 601 * ppm[p + 1] + 117 * ppm[p + 2] + 0x200) >> 10,
      );
    }
  }
  return img.encodePng(grey, level: 9);
}

String _extension(String path) {
  final int dot = path.lastIndexOf('.');
  return dot < 0 ? '' : path.substring(dot).toLowerCase();
}

String _stem(String path) => path.substring(0, path.lastIndexOf('.'));

String _basename(String path) =>
    path.split(RegExp(r'[/\\]')).lastWhere((String s) => s.isNotEmpty);

/// Orders `2.png` before `10.png`.
int _natural(String a, String b) {
  final RegExp number = RegExp(r'\d+');
  String pad(String s) =>
      s.replaceAllMapped(number, (Match m) => m[0]!.padLeft(8, '0'));
  return pad(a).compareTo(pad(b));
}
