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
// Each image is copied with its expectations (.txt, .bin, .result.txt) as
// `<sample directory>__<name>.<ext>`, with only [A-Za-z0-9._-] in names:
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
    for (final File image in images) {
      full.add(name, image, converted[image]!);
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
      subset.add(name, image, converted[image]!);
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

  void add(String sampleDirectory, File image, Uint8List data) {
    final String stem = _stem(image.path);
    final String target =
        '${_dir.path}/${sampleDirectory}__'
        '${_basename(stem).replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}';
    final String ext = _extension(image.path) == '.webp'
        ? '.png'
        : _extension(image.path);
    File('$target$ext').writeAsBytesSync(data);
    for (final String expected in <String>['.txt', '.bin', '.result.txt']) {
      final File f = File('$stem$expected');
      if (f.existsSync()) {
        f.copySync('$target$expected');
      }
    }
    _images++;
    _bytes += data.length;
  }

  @override
  String toString() =>
      '$_images images, ${(_bytes / 1024 / 1024).toStringAsFixed(1)} MB '
      'in ${_dir.path}';
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
