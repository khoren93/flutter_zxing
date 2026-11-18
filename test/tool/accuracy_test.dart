// The accuracy bench: how far every supported code can be degraded before it
// stops reading. Each code is drawn on its own, frame by frame, over a grid of
// resolution, blur and tilt and a set of noise and lighting conditions. Every
// condition is read 8 times with a different subpixel shift and tilt direction,
// so that 8 of 8 means stable. The same frames go through zxing-cpp's own
// ZXingReader: where it reads a frame and we do not, the fault is in our layer.
// Frames without a code count the false positives.
//
// Frames are computed, not drawn by Flutter, and every random number comes from
// a seed of the frame's name: two runs give the same results.json, on any
// number of workers. Skipped unless ACCURACY names an output folder:
//
//   make accuracy                # build/accuracy/report.md and results.json
//   make accuracy ONLY=qr,ean13  # some codes only
//   make accuracy-causes         # why the failed conditions fail: causes.json
@Tags(<String>['native'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image/image.dart' as img;

final String? _out = Platform.environment['ACCURACY'];
final Set<String> _only = (Platform.environment['ACCURACY_ONLY'] ?? '')
    .split(',')
    .map((String s) => s.trim())
    .where((String s) => s.isNotEmpty)
    .toSet();
const String _referencePath = 'build/zxing_reader/ZXingReader';
const String _samples = 'third_party/zxing-cpp/test/samples';

// The axes.
const List<double> _ppms = <double>[1.5, 2, 2.5, 3, 4, 6];
const List<double> _blurs = <double>[0, 0.5, 0.8, 1, 1.5, 2];
const List<double> _tilts = <double>[0, 5, 15, 30, 45];
const List<String> _noises = <String>['clean', 'moderate', 'strong'];
const List<String> _lights = <String>[
  'even',
  'uneven',
  'low contrast',
  'glare',
];

/// Resolution of the sweeps along one axis, and of the noise and light tests.
const double _basePpm = 4;

/// Reads of one condition.
const int _shots = 8;

/// The camera's options, as the scanner reads a frame.
const ReaderOptions _options = ReaderOptions.camera();

/// The same options for the reference. EAN add-ons cannot be turned off there,
/// and no frame here has one.
const List<String> _referenceFlags = <String>['-noinvert'];

/// The most blur the hard zone asks for, in modules: more than that washes
/// the modules together whatever the reader does.
const double _hardBlur = 0.375;

enum _Zone {
  working('Working', 8),
  hard('Hard', 6),
  limit('Limit', 0),
  outside('Outside', 0);

  const _Zone(this.title, this.required);
  final String title;

  /// Reads of 8 the zone asks for in every condition; 0 only measures.
  final int required;

  static _Zone of(double ppm, double blur, double tilt) {
    if (ppm < 2) {
      return limit;
    }
    if (ppm >= 3 && blur <= 1 && tilt <= 30) {
      return working;
    }
    return blur <= _hardBlur * ppm && tilt <= 45 ? hard : outside;
  }
}

/// One condition a code is read under.
final class _Condition {
  const _Condition(this.ppm, this.blur, this.tilt, this.noise, this.light);

  final double ppm;
  final double blur;
  final double tilt;
  final int noise;
  final int light;

  String get key => '$ppm/$blur/$tilt/$noise/$light';

  bool get isGrid => noise == 0 && light == 0;
  _Zone get zone => _Zone.of(ppm, blur, tilt);

  String get label =>
      '${_num(ppm)} px, blur ${_num(blur)}, tilt ${_num(tilt)}°'
      '${noise == 0 ? '' : ', ${_noises[noise]} noise'}'
      '${light == 0 ? '' : ', ${_lights[light]} light'}';
}

List<_Condition> _conditions() => <_Condition>[
  for (final double ppm in _ppms)
    for (final double blur in _blurs)
      for (final double tilt in _tilts) _Condition(ppm, blur, tilt, 0, 0),
  for (int noise = 0; noise < _noises.length; noise++)
    for (int light = 0; light < _lights.length; light++)
      if (noise != 0 || light != 0) _Condition(_basePpm, 0, 0, noise, light),
];

/// One code to test: a grid of light and dark cells.
final class _Code {
  const _Code({
    required this.id,
    required this.title,
    required this.columns,
    required this.rows,
    required this.cells,
    required this.quiet,
    this.cellsPerModule = 1,
    this.inverted = false,
    this.expected,
  });

  final String id;
  final String title;
  final int columns;
  final int rows;

  /// One byte per cell, row by row: non-zero is dark.
  final Uint8List cells;

  /// Blank margin in modules.
  final int quiet;

  /// Cells to a module: more than 1 for a code taken from a sample image.
  final int cellsPerModule;

  /// Light on dark, the page dark as well.
  final bool inverted;

  /// The text the code holds, to check the first read; null if unknown.
  final String? expected;

  /// The same code, dark on light: what it holds is read from this one, as
  /// zxing-cpp does not look for inverted linear codes at all.
  _Code get upright => _Code(
    id: id,
    title: title,
    columns: columns,
    rows: rows,
    cells: cells,
    quiet: quiet,
    cellsPerModule: cellsPerModule,
    expected: expected,
  );

  double get modulesWide => columns / cellsPerModule;
  double get modulesHigh => rows / cellsPerModule;
}

Future<_Code> _written(
  String id,
  BarcodeFormat format, {
  String? title,
  String? data,
  String? expected,
  bool inverted = false,
}) async {
  final String text = data ?? format.input!.example;
  final BarcodeSymbol symbol = await BarcodeWriter(format).encode(text);
  // Linear symbols are one row high in the writer: bars as tall as a printed
  // code, a sixth of the width but at least 24 modules.
  final int rows = symbol.height > 1
      ? symbol.height
      : math.max(24, (symbol.width / 6).round());
  final Uint8List cells = symbol.height > 1
      ? symbol.modules
      : Uint8List(symbol.width * rows);
  if (symbol.height <= 1) {
    for (int y = 0; y < rows; y++) {
      cells.setRange(y * symbol.width, (y + 1) * symbol.width, symbol.modules);
    }
  }
  return _Code(
    id: id,
    title: title ?? format.displayName,
    columns: symbol.width,
    rows: rows,
    cells: cells,
    quiet: math.max(symbol.quietZone, 4),
    inverted: inverted,
    expected: expected ?? text,
  );
}

/// The brightness of a pixel, 0 to 1. A grey image has one channel, which
/// the luminance of the image package counts as red only.
double _brightness(img.Image image, int x, int y) {
  final img.Pixel p = image.getPixel(x, y);
  return image.hasPalette || image.numChannels >= 3
      ? p.luminanceNormalized.toDouble()
      : p.rNormalized.toDouble();
}

/// A code the writer does not make, from a zxing-cpp sample image.
_Code _sampled(
  String id,
  String title,
  String path,
  int cellsPerModule, {
  String? expected,
}) {
  final img.Image image = img.decodePng(
    File('$_samples/$path').readAsBytesSync(),
  )!;
  final Uint8List cells = Uint8List(image.width * image.height);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      cells[y * image.width + x] = _brightness(image, x, y) < 0.5 ? 1 : 0;
    }
  }
  return _Code(
    id: id,
    title: title,
    columns: image.width,
    rows: image.height,
    cells: cells,
    quiet: 4,
    cellsPerModule: cellsPerModule,
    expected: expected,
  );
}

/// What the reader gives for a payload that it reports in its own way.
const Map<BarcodeFormat, String> _readsAs = <BarcodeFormat, String>{
  BarcodeFormat.aztecRune: '025',
  BarcodeFormat.dataBar: '(01)09501101530003',
  BarcodeFormat.dataBarStacked: '(01)09501101530003',
  BarcodeFormat.dataBarStackedOmni: '(01)09501101530003',
  BarcodeFormat.dataBarLimited: '(01)09501101530003',
  BarcodeFormat.dataBarExpanded: '(01)09501101530003(17)250101',
  BarcodeFormat.dataBarExpandedStacked: '(01)09501101530003(17)250101',
  BarcodeFormat.code32: 'A123456788',
  BarcodeFormat.pzn: '-12345678',
};

Future<List<_Code>> _catalogue() async {
  String text(int length) => List<String>.filled(
    length ~/ 28 + 1,
    'flutter_zxing accuracy bench',
  ).join().substring(0, length);
  return <_Code>[
    for (final BarcodeFormat format in BarcodeFormat.writable)
      await _written(
        format.name,
        format,
        data: format == BarcodeFormat.isbn ? '9781234567897' : null,
        expected: _readsAs[format],
      ),
    await _written(
      'qr500',
      BarcodeFormat.qrCode,
      title: 'QR Code, 500 characters',
      data: text(500),
    ),
    await _written(
      'qr1200',
      BarcodeFormat.qrCode,
      title: 'QR Code, 1200 characters',
      data: text(1200),
    ),
    await _written(
      'qrInverted',
      BarcodeFormat.qrCode,
      title: 'QR Code, inverted',
      inverted: true,
    ),
    await _written(
      'code128Inverted',
      BarcodeFormat.code128,
      title: 'Code 128, inverted',
      inverted: true,
    ),
    await _written(
      'ean13Inverted',
      BarcodeFormat.ean13,
      title: 'EAN-13, inverted',
      inverted: true,
    ),
    await _written(
      'itf14',
      BarcodeFormat.itf,
      title: 'ITF-14',
      data: '00012345600012',
    ),
    _sampled('maxiCode', 'MaxiCode', 'maxicode-1/MODE2.png', 9),
    _sampled('qrModel1', 'QR Code Model 1', 'qrcode-1/qr-model-1.png', 2),
  ].where((_Code c) => _only.isEmpty || _only.contains(c.id)).toList();
}

// --- Frames ------------------------------------------------------------------

/// A grey image.
final class _Frame {
  const _Frame(this.width, this.height, this.pixels);
  final int width;
  final int height;
  final Uint8List pixels;

  Uint8List get pgm {
    final List<int> header = ascii.encode('P5\n$width $height\n255\n');
    return Uint8List(header.length + pixels.length)
      ..setAll(0, header)
      ..setAll(header.length, pixels);
  }

  Uint8List get png => img.encodePng(
    img.Image.fromBytes(
      width: width,
      height: height,
      bytes: pixels.buffer,
      numChannels: 1,
    ),
  );
}

/// A small random generator, the same on every platform and run.
final class _Random {
  _Random(String name) {
    int h = 0x811c9dc5;
    for (final int c in utf8.encode(name)) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    _s = h == 0 ? 1 : h;
  }

  late int _s;

  int next() {
    _s ^= (_s << 13) & 0xffffffff;
    _s ^= _s >> 17;
    _s ^= (_s << 5) & 0xffffffff;
    return _s;
  }

  double uniform() => next() / 4294967296;

  int below(int n) => next() % n;

  double gaussian() =>
      math.sqrt(-2 * math.log(1 - uniform())) *
      math.cos(2 * math.pi * uniform());
}

double _halton(int index, int base) {
  double f = 1;
  double r = 0;
  for (int i = index; i > 0; i ~/= base) {
    f /= base;
    r += f * (i % base);
  }
  return r;
}

/// The code of [c] under [k], read for the [shot]th time.
_Frame _render(_Code c, _Condition k, int shot) {
  // The code's plane turned by the tilt around an axis in the plane, each
  // shot around another one, seen through a pinhole from close by.
  final double w = c.modulesWide + 2 * c.quiet;
  final double h = c.modulesHigh + 2 * c.quiet;
  final double distance = 2 * math.max(w, h);
  final double azimuth = shot * math.pi / 4;
  final double ax = math.cos(azimuth);
  final double ay = math.sin(azimuth);
  final double theta = k.tilt * math.pi / 180;
  final double cs = math.cos(theta);
  final double sn = math.sin(theta);
  List<double> turned(double x, double y, double z) {
    final double dot = ax * x + ay * y;
    return <double>[
      x * cs + ay * z * sn + ax * dot * (1 - cs),
      y * cs - ax * z * sn + ay * dot * (1 - cs),
      z * cs + (ax * y - ay * x) * sn,
    ];
  }

  final List<double> e1 = turned(1, 0, 0);
  final List<double> e2 = turned(0, 1, 0);
  final List<double> n = turned(0, 0, 1);

  // The frame holds the whole code with a margin, the blur included.
  double reachX = 0;
  double reachY = 0;
  for (final (double x, double y) in <(double, double)>[
    (-w / 2, -h / 2),
    (w / 2, -h / 2),
    (w / 2, h / 2),
    (-w / 2, h / 2),
  ]) {
    final double px = x * e1[0] + y * e2[0];
    final double py = x * e1[1] + y * e2[1];
    final double pz = x * e1[2] + y * e2[2] + distance;
    reachX = math.max(reachX, (distance * px / pz).abs());
    reachY = math.max(reachY, (distance * py / pz).abs());
  }
  final double margin = 12 + 3 * k.blur;
  final int fw = (2 * (reachX * k.ppm + margin)).ceil();
  final int fh = (2 * (reachY * k.ppm + margin)).ceil();
  final double cx = fw / 2 + _halton(shot, 2);
  final double cy = fh / 2 + _halton(shot, 3);

  // 3 x 3 samples per pixel, as a sensor integrates the light on it.
  final Float32List light = Float32List(fw * fh);
  final double cpm = c.cellsPerModule.toDouble();
  final double halfW = c.modulesWide / 2;
  final double halfH = c.modulesHigh / 2;
  final double nz = distance * n[2];
  for (int y = 0; y < fh; y++) {
    for (int x = 0; x < fw; x++) {
      int lit = 0;
      for (int j = 0; j < 3; j++) {
        final double v = (y + (j + 0.5) / 3 - cy) / k.ppm;
        for (int i = 0; i < 3; i++) {
          final double u = (x + (i + 0.5) / 3 - cx) / k.ppm;
          final double t = nz / (u * n[0] + v * n[1] + nz);
          final double px = t * u;
          final double py = t * v;
          final double pz = t * distance - distance;
          final double mx = px * e1[0] + py * e1[1] + pz * e1[2] + halfW;
          final double my = px * e2[0] + py * e2[1] + pz * e2[2] + halfH;
          bool dark = false;
          if (mx >= 0 && my >= 0) {
            final int col = (mx * cpm).floor();
            final int row = (my * cpm).floor();
            dark =
                col < c.columns &&
                row < c.rows &&
                c.cells[row * c.columns + col] != 0;
          }
          if (dark == c.inverted) {
            lit++;
          }
        }
      }
      light[y * fw + x] = lit / 9;
    }
  }

  _applyLight(light, fw, fh, k.light);
  final Float32List sharp = k.blur > 0
      ? _blurred(light, fw, fh, k.blur)
      : light;
  return _Frame(
    fw,
    fh,
    _sensor(sharp, fw, fh, k.noise, '${c.id}/${k.key}/$shot'),
  );
}

/// Turns light (0 to 1) into grey levels under the lighting [kind].
void _applyLight(Float32List a, int w, int h, int kind) {
  final double black = kind == 2 ? 95 : 25;
  final double white = kind == 2 ? 165 : 230;
  final double spotX = 0.62 * w;
  final double spotY = 0.4 * h;
  final double spot = 0.3 * math.min(w, h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int i = y * w + x;
      double v = black + (white - black) * a[i];
      if (kind == 1) {
        v *= 1 - 0.55 * (x / w + y / h) / 2;
      } else if (kind == 3) {
        final double dx = x - spotX;
        final double dy = y - spotY;
        v += 150 * math.exp(-(dx * dx + dy * dy) / (2 * spot * spot));
      }
      a[i] = v;
    }
  }
}

Float32List _blurred(Float32List a, int w, int h, double sigma) {
  final int r = (3 * sigma).ceil();
  final Float32List kernel = Float32List(2 * r + 1);
  double sum = 0;
  for (int i = -r; i <= r; i++) {
    sum += kernel[i + r] = math.exp(-i * i / (2 * sigma * sigma));
  }
  for (int i = 0; i < kernel.length; i++) {
    kernel[i] /= sum;
  }
  final Float32List across = Float32List(w * h);
  final Float32List down = Float32List(w * h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      double v = 0;
      for (int i = -r; i <= r; i++) {
        v += kernel[i + r] * a[y * w + (x + i).clamp(0, w - 1)];
      }
      across[y * w + x] = v;
    }
  }
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      double v = 0;
      for (int i = -r; i <= r; i++) {
        v += kernel[i + r] * across[(y + i).clamp(0, h - 1) * w + x];
      }
      down[y * w + x] = v;
    }
  }
  return down;
}

/// Sensor noise and JPEG compression, then 8 bits.
Uint8List _sensor(Float32List a, int w, int h, int noise, String seed) {
  final Uint8List out = Uint8List(w * h);
  final double sigma = const <double>[0, 6, 14][noise];
  final _Random random = _Random(seed);
  for (int i = 0; i < out.length; i++) {
    final double v = noise == 0 ? a[i] : a[i] + sigma * random.gaussian();
    out[i] = v.round().clamp(0, 255);
  }
  if (noise == 0) {
    return out;
  }
  final img.Image? back = img.decodeJpg(
    img.encodeJpg(
      img.Image.fromBytes(
        width: w,
        height: h,
        bytes: out.buffer,
        numChannels: 1,
      ),
      quality: const <int>[100, 70, 40][noise],
    ),
  );
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      out[y * w + x] = back!.getPixel(x, y).r.toInt();
    }
  }
  return out;
}

// --- Frames without a code ---------------------------------------------------

const int _syntheticPerKind = 24;
const List<String> _syntheticKinds = <String>[
  'noise',
  'grating',
  'bars',
  'blocks',
  'text',
];

/// Names of the frames without a code: drawn ones and zxing-cpp's samples.
List<String> _negativeNames() => <String>[
  for (final String kind in _syntheticKinds)
    for (int i = 0; i < _syntheticPerKind; i++) '$kind-$i',
  for (final String folder in <String>['none-1', 'none-2'])
    ...(Directory('$_samples/$folder')
        .listSync()
        .whereType<File>()
        .map((File f) => '$folder/${f.uri.pathSegments.last}')
        .where(
          (String p) =>
              p.endsWith('.png') ||
              p.endsWith('.jpg') ||
              p.endsWith('.jpeg') ||
              p.endsWith('.webp'),
        )
        .toList()
      ..sort()),
];

_Frame _negative(String name) {
  if (name.contains('/')) {
    final img.Image image = img.decodeImage(
      File('$_samples/$name').readAsBytesSync(),
    )!;
    final int longest = math.max(image.width, image.height);
    final img.Image small = longest > 1280
        ? img.copyResize(
            image,
            width: image.width * 1280 ~/ longest,
            height: image.height * 1280 ~/ longest,
            interpolation: img.Interpolation.average,
          )
        : image;
    final Uint8List grey = Uint8List(small.width * small.height);
    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        grey[y * small.width + x] = (_brightness(small, x, y) * 255).round();
      }
    }
    return _Frame(small.width, small.height, grey);
  }
  const int w = 640;
  const int h = 480;
  final _Random random = _Random(name);
  final String kind = name.substring(0, name.indexOf('-'));
  final Float32List a = Float32List(w * h);
  switch (kind) {
    case 'noise':
      for (int i = 0; i < a.length; i++) {
        a[i] = random.uniform() * 255;
      }
    case 'grating':
      final double period = 2 + random.uniform() * 12;
      final double angle = random.uniform() * math.pi;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final double d = x * math.cos(angle) + y * math.sin(angle);
          a[y * w + x] = (d / period).floor().isEven ? 30 : 225;
        }
      }
    case 'bars':
      // Random bars, the closest thing to a linear code that is none.
      final Float32List row = Float32List(w);
      bool dark = true;
      for (int x = 0; x < w;) {
        final int run = 1 + random.below(8);
        row.fillRange(x, math.min(w, x + run), dark ? 30 : 225);
        x += run;
        dark = !dark;
      }
      for (int y = 0; y < h; y++) {
        a.setRange(y * w, (y + 1) * w, row);
      }
    case 'blocks':
      // Random modules, the closest thing to a matrix code that is none.
      final int size = 3 + random.below(6);
      final Uint8List cells = Uint8List((w ~/ size + 1) * (h ~/ size + 1));
      for (int i = 0; i < cells.length; i++) {
        cells[i] = random.below(2);
      }
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final int cell = (y ~/ size) * (w ~/ size + 1) + x ~/ size;
          a[y * w + x] = cells[cell] == 1 ? 30 : 225;
        }
      }
    default:
      // Lines of word-like marks, as on a printed page.
      a.fillRange(0, a.length, 225);
      for (int line = 12; line + 12 < h; line += 22) {
        for (int x = 8; x < w - 8;) {
          final int mark = 1 + random.below(4);
          if (random.below(5) != 0) {
            for (int y = line; y < line + 12; y++) {
              a.fillRange(y * w + x, y * w + x + mark, 30);
            }
          }
          x += mark + 1 + random.below(4);
        }
      }
  }
  final double blur = 0.4 + random.uniform();
  return _Frame(w, h, _sensor(_blurred(a, w, h, blur), w, h, 0, name));
}

// --- Reading -----------------------------------------------------------------

/// The formats and texts one reader found in a frame.
typedef _Reads = List<String>;

Future<_Reads> _readOurs(_Frame f, ReaderOptions options) async {
  final List<Barcode> found = await BarcodeReader(
    options: options,
  ).readAllPixels(PixelBuffer(f.pixels, width: f.width, height: f.height));
  return <String>[for (final Barcode b in found) '${b.format.name}|${b.text}'];
}

/// Reads [frames] with ZXingReader, through files in [dir].
List<_Reads> _readReference(
  List<_Frame> frames,
  Directory dir,
  List<String> flags,
) {
  final List<String> paths = <String>[
    for (int i = 0; i < frames.length; i++) '${dir.path}/f$i.pgm',
  ];
  for (int i = 0; i < frames.length; i++) {
    File(paths[i]).writeAsBytesSync(frames[i].pgm);
  }
  final ProcessResult run = Process.runSync(
    File(_referencePath).absolute.path,
    <String>[...flags, '-1', ...paths],
    stdoutEncoding: null,
    stderrEncoding: null,
  );
  final String output = utf8.decode(
    run.stdout as List<int>,
    allowMalformed: true,
  );
  final List<_Reads> reads = <_Reads>[
    for (int i = 0; i < frames.length; i++) <String>[],
  ];
  for (final String line in const LineSplitter().convert(output)) {
    final int i = paths.indexWhere((String p) => line.startsWith('$p '));
    if (i >= 0 && line.substring(paths[i].length + 1) != 'None') {
      reads[i].add(line.substring(paths[i].length + 1));
    }
  }
  return reads;
}

/// What each reader finds in a clean frame of a code: the right answer.
final class _Truth {
  const _Truth(this.ours, this.reference, this.oursText);
  final String? ours;
  final String? reference;
  final String? oursText;
}

/// How one condition of one code went.
final class _Result {
  const _Result(
    this.code,
    this.condition,
    this.ours,
    this.reference,
    this.oursWrong,
    this.referenceWrong,
    this.onlyReference,
    this.onlyOurs,
    this.wrongTexts,
  );

  final String code;
  final String condition;

  /// Frames read right, of [_shots].
  final int ours;
  final int reference;

  /// Frames with a read that is not the code.
  final int oursWrong;
  final int referenceWrong;

  /// The shots only the reference read, and only we read.
  final List<int> onlyReference;
  final List<int> onlyOurs;

  /// What we read that is not the code, one entry per read.
  final List<String> wrongTexts;
}

/// A frame without a code that something was read in.
final class _FalseRead {
  const _FalseRead(this.frame, this.ours, this.reference);
  final String frame;
  final List<String> ours;
  final List<String> reference;
}

// --- Workers -----------------------------------------------------------------

final class _CodeJob {
  const _CodeJob(this.code, this.condition, this.truth);
  final _Code code;
  final _Condition condition;
  final _Truth truth;
}

final class _TruthJob {
  const _TruthJob(this.code);
  final _Code code;
}

final class _NegativeJob {
  const _NegativeJob(this.name);
  final String name;
}

final class _Worker {
  _Worker(this.index, this.host, this.tmp);
  final int index;
  final SendPort host;
  final String tmp;
}

Future<void> _workerMain(_Worker w) async {
  final Directory dir = Directory('${w.tmp}/w${w.index}')
    ..createSync(recursive: true);
  final ReceivePort jobs = ReceivePort();
  w.host.send(jobs.sendPort);
  await for (final Object? job in jobs) {
    switch (job) {
      case _TruthJob(:final _Code code):
        w.host.send(await _truth(code, dir));
      case _CodeJob():
        w.host.send(await _run(job, dir));
      case _ProbeJob():
        w.host.send(await _probe(job, dir));
      case _NegativeJob(:final String name):
        final _Frame f = _negative(name);
        w.host.send(
          _FalseRead(
            name,
            await _readOurs(f, _options),
            _readReference(<_Frame>[f], dir, _referenceFlags).single,
          ),
        );
      default:
        jobs.close();
    }
  }
  Isolate.exit();
}

Future<(String, _Truth)> _truth(_Code code, Directory dir) async {
  // A code from a sample image at its own scale: pixel for pixel the sample.
  final double ppm = math.max(6, code.cellsPerModule.toDouble());
  final _Frame clean = _render(code.upright, _Condition(ppm, 0, 0, 0, 0), 0);
  final _Reads ours = await _readOurs(
    clean,
    _options.copyWith(tryInvert: true),
  );
  final _Reads reference = _readReference(
    <_Frame>[clean],
    dir,
    <String>[],
  ).single;
  final String? first = ours.isEmpty ? null : ours.first;
  return (
    code.id,
    _Truth(
      first,
      reference.isEmpty ? null : reference.first,
      first?.substring(first.indexOf('|') + 1),
    ),
  );
}

Future<_Result> _run(_CodeJob job, Directory dir) async {
  final List<_Frame> frames = <_Frame>[
    for (int shot = 0; shot < _shots; shot++)
      _render(job.code, job.condition, shot),
  ];
  final List<_Reads> reference = _readReference(frames, dir, _referenceFlags);
  int ours = 0;
  int refs = 0;
  int oursWrong = 0;
  int refsWrong = 0;
  final List<int> onlyReference = <int>[];
  final List<int> onlyOurs = <int>[];
  final List<String> wrongTexts = <String>[];
  for (int shot = 0; shot < _shots; shot++) {
    final _Reads mine = await _readOurs(frames[shot], _options);
    wrongTexts.addAll(mine.where((String r) => r != job.truth.ours));
    final bool hit = mine.contains(job.truth.ours);
    final bool refHit = reference[shot].contains(job.truth.reference);
    ours += hit ? 1 : 0;
    refs += refHit ? 1 : 0;
    oursWrong += mine.any((String r) => r != job.truth.ours) ? 1 : 0;
    refsWrong += reference[shot].any((String r) => r != job.truth.reference)
        ? 1
        : 0;
    if (refHit && !hit) {
      onlyReference.add(shot);
    } else if (hit && !refHit) {
      onlyOurs.add(shot);
    }
  }
  return _Result(
    job.code.id,
    job.condition.key,
    ours,
    refs,
    oursWrong,
    refsWrong,
    onlyReference,
    onlyOurs,
    wrongTexts,
  );
}

/// Runs [jobs] on all workers and gives the answers in the order of [jobs].
Future<List<T>> _dispatch<T>(
  List<Object> jobs,
  List<SendPort> workers,
  Stream<Object?> answers,
  String what,
) async {
  final List<T?> results = List<T?>.filled(jobs.length, null);
  final Stopwatch clock = Stopwatch()..start();
  final Map<SendPort, int> busy = <SendPort, int>{};
  final StreamIterator<Object?> incoming = StreamIterator<Object?>(answers);
  int next = 0;
  int done = 0;
  int shown = 0;
  final List<SendPort> idle = <SendPort>[...workers];
  while (done < jobs.length) {
    while (idle.isNotEmpty && next < jobs.length) {
      final SendPort port = idle.removeLast();
      busy[port] = next;
      port.send(jobs[next++]);
    }
    await incoming.moveNext();
    final (SendPort from, Object? answer) =
        incoming.current! as (SendPort, Object?);
    results[busy.remove(from)!] = answer as T;
    idle.add(from);
    done++;
    final int percent = done * 100 ~/ jobs.length;
    if (percent >= shown + 10) {
      shown = percent - percent % 10;
      // ignore: avoid_print
      print('$what: $shown % (${clock.elapsed.inSeconds} s)');
    }
  }
  await incoming.cancel();
  return results.cast<T>();
}

/// One long-lived isolate per worker, each with its own engine.
final class _Pool {
  _Pool._(this.workers, this.answers, this._ports, this._controller);

  static Future<_Pool> start(String tmp) async {
    final int count =
        int.tryParse(Platform.environment['ACCURACY_WORKERS'] ?? '') ??
        math.max(1, Platform.numberOfProcessors - 2);
    final StreamController<Object?> answers = StreamController<Object?>();
    final List<SendPort> workers = <SendPort>[];
    final List<ReceivePort> ports = <ReceivePort>[];
    for (int i = 0; i < count; i++) {
      final ReceivePort port = ReceivePort();
      ports.add(port);
      final Completer<SendPort> ready = Completer<SendPort>();
      port.listen((Object? message) {
        if (message is SendPort) {
          ready.complete(message);
        } else {
          ready.future.then((SendPort from) => answers.add((from, message)));
        }
      });
      await Isolate.spawn(_workerMain, _Worker(i, port.sendPort, tmp));
      workers.add(await ready.future);
    }
    return _Pool._(workers, answers.stream.asBroadcastStream(), ports, answers);
  }

  final List<SendPort> workers;
  final Stream<Object?> answers;
  final List<ReceivePort> _ports;
  final StreamController<Object?> _controller;

  Future<void> close() async {
    for (final SendPort worker in workers) {
      worker.send(null);
    }
    for (final ReceivePort port in _ports) {
      port.close();
    }
    await _controller.close();
  }
}

// --- Why a condition fails ----------------------------------------------------

final String? _causesOf = Platform.environment['ACCURACY_CAUSES'];

/// Other reader options a failed condition is tried with.
const Map<String, ReaderOptions> _optionProbes = <String, ReaderOptions>{
  'minLineCount=1': ReaderOptions(tryInvert: false, minLineCount: 1),
  'binarizer=globalHistogram': ReaderOptions(
    tryInvert: false,
    binarizer: Binarizer.globalHistogram,
  ),
  'binarizer=fixedThreshold': ReaderOptions(
    tryInvert: false,
    binarizer: Binarizer.fixedThreshold,
  ),
  'tryDownscale=false': ReaderOptions(tryInvert: false, tryDownscale: false),
};

final class _ProbeJob {
  const _ProbeJob(this.code, this.condition, this.truth);
  final _Code code;
  final _Condition condition;
  final _Truth truth;
}

/// Reads of 8 of one failed condition, as it is and changed one way at a time.
final class _Probe {
  const _Probe(this.code, this.condition, this.reads);
  final String code;
  final String condition;
  final Map<String, int> reads;
}

Future<_Probe> _probe(_ProbeJob job, Directory dir) async {
  final _Code code = job.code;
  final _Condition k = job.condition;
  List<_Frame> framesOf(_Code c, _Condition condition) => <_Frame>[
    for (int shot = 0; shot < _shots; shot++) _render(c, condition, shot),
  ];
  Future<int> count(List<_Frame> frames, ReaderOptions options) async {
    int hits = 0;
    for (final _Frame frame in frames) {
      final _Reads reads = await _readOurs(frame, options);
      hits += reads.contains(job.truth.ours) ? 1 : 0;
    }
    return hits;
  }

  final List<_Frame> frames = framesOf(code, k);
  // An inverted code is only ever read with the inversion on.
  final ReaderOptions easier = _options.copyWith(tryInvert: code.inverted);
  Future<int> changed(double ppm, double blur, double tilt) =>
      count(framesOf(code, _Condition(ppm, blur, tilt, 0, 0)), easier);

  final Map<String, int> reads = <String, int>{
    'ours': await count(frames, _options),
    'reference': _readReference(
      frames,
      dir,
      _referenceFlags,
    ).where((_Reads r) => r.contains(job.truth.reference)).length,
    'tryInvert': await count(frames, _options.copyWith(tryInvert: true)),
    for (final MapEntry<String, ReaderOptions> e in _optionProbes.entries)
      e.key: await count(frames, e.value),
    // Twice the pixels, the blur the same in modules.
    'resolution': await changed(k.ppm * 2, k.blur * 2, k.tilt),
    if (k.blur > 0) 'noBlur': await changed(k.ppm, 0, k.tilt),
    if (k.tilt > 0) 'noTilt': await changed(k.ppm, k.blur, 0),
    if (code.inverted)
      'upright': await count(framesOf(code.upright, k), _options),
  };
  // No single change is enough: which of them together are?
  if (_causeOf(reads, k.zone.required) == 'UNEXPLAINED') {
    reads['resolution+noTilt'] = await changed(k.ppm * 2, k.blur * 2, 0);
    reads['noBlur+noTilt'] = await changed(k.ppm, 0, 0);
    reads['resolution+noBlur'] = await changed(k.ppm * 2, 0, k.tilt);
    reads['resolution+noBlur+noTilt'] = await changed(k.ppm * 2, 0, 0);
  }
  return _Probe(code.id, k.key, reads);
}

/// The cause a probe proves, the first that reaches [required] reads.
String _causeOf(Map<String, int> reads, int required) {
  bool reaches(String probe) => (reads[probe] ?? 0) >= required;
  if (reaches('reference')) {
    return 'OUR_BUG';
  }
  if (reaches('tryInvert')) {
    return 'INVERT';
  }
  // Nothing reads it inverted, yet the same code dark on light does read.
  if ((reads['upright'] ?? 0) > 0 && reads['tryInvert'] == 0) {
    return 'INVERT_UNSUPPORTED';
  }
  for (final String option in _optionProbes.keys) {
    if (reaches(option)) {
      return 'OPTIONS $option';
    }
  }
  for (final (String probe, String cause) in const <(String, String)>[
    ('resolution', 'RESOLUTION'),
    ('noBlur', 'BLUR'),
    ('noTilt', 'TILT'),
    ('noBlur+noTilt', 'BLUR+TILT'),
    ('resolution+noTilt', 'RESOLUTION+TILT'),
    ('resolution+noBlur', 'RESOLUTION+BLUR'),
    ('resolution+noBlur+noTilt', 'RESOLUTION+BLUR+TILT'),
  ]) {
    if (reaches(probe)) {
      return cause;
    }
  }
  return 'UNEXPLAINED';
}

Future<void> _explain(String folder) async {
  final Map<String, dynamic> results =
      jsonDecode(File('$folder/results.json').readAsStringSync())
          as Map<String, dynamic>;
  final Map<String, dynamic> recorded =
      results['codes'] as Map<String, dynamic>;
  final Directory tmp = Directory('$folder/tmp')..createSync(recursive: true);
  final List<_Code> codes = await _catalogue();
  final _Pool pool = await _Pool.start(tmp.path);
  final Map<String, _Truth> truths = <String, _Truth>{
    for (final (String id, _Truth t) in await _dispatch<(String, _Truth)>(
      <Object>[for (final _Code c in codes) _TruthJob(c)],
      pool.workers,
      pool.answers,
      'first reads',
    ))
      id: t,
  };
  final Map<String, _Condition> byKey = <String, _Condition>{
    for (final _Condition k in _conditions()) k.key: k,
  };
  final List<_ProbeJob> jobs = <_ProbeJob>[
    for (final _Code c in codes)
      for (final MapEntry<String, dynamic> e
          in ((recorded[c.id] as Map<String, dynamic>)['conditions']
                  as Map<String, dynamic>)
              .entries)
        if (byKey[e.key] case final _Condition k
            when k.isGrid &&
                k.zone.required > 0 &&
                ((e.value as List<dynamic>).first as int) < k.zone.required)
          _ProbeJob(c, k, truths[c.id]!),
  ];
  final List<_Probe> probes = await _dispatch<_Probe>(
    jobs,
    pool.workers,
    pool.answers,
    'failed conditions',
  );
  await pool.close();
  tmp.deleteSync(recursive: true);

  final Map<String, Object?> out = <String, Object?>{};
  for (final _Code c in codes) {
    final Map<String, Map<String, int>> causes = <String, Map<String, int>>{};
    final List<Map<String, Object?>> cells = <Map<String, Object?>>[];
    for (final _Probe p in probes.where((_Probe p) => p.code == c.id)) {
      final _Condition k = byKey[p.condition]!;
      final String cause = _causeOf(p.reads, k.zone.required);
      final Map<String, int> zone = causes[k.zone.name] ??= <String, int>{};
      zone[cause] = (zone[cause] ?? 0) + 1;
      cells.add(<String, Object?>{
        'condition': k.label,
        'zone': k.zone.name,
        'cause': cause,
        'reads': p.reads,
      });
    }
    out[c.id] = <String, Object?>{
      'title': c.title,
      'causes': causes,
      'cells': cells,
    };
  }
  File(
    '$folder/causes.json',
  ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
}

// --- The test ----------------------------------------------------------------

void main() {
  test(
    'why conditions fail',
    () => _explain(_causesOf!),
    skip: _causesOf == null ? 'ACCURACY_CAUSES names no folder' : false,
    timeout: Timeout.none,
  );

  test(
    'accuracy bench',
    () async {
      final Directory out = Directory(_out!)..createSync(recursive: true);
      expect(
        File(_referencePath).existsSync(),
        isTrue,
        reason: 'run tool/build_zxing_reader.sh first',
      );
      final Directory tmp = Directory('${out.path}/tmp')
        ..createSync(recursive: true);

      final List<_Code> codes = await _catalogue();
      expect(codes, isNotEmpty, reason: 'ONLY matches no code');
      final List<_Condition> conditions = _conditions();

      final _Pool pool = await _Pool.start(tmp.path);
      final List<SendPort> workers = pool.workers;
      final Stream<Object?> incoming = pool.answers;

      final Map<String, _Truth> truths = Map<String, _Truth>.fromEntries(
        (await _dispatch<(String, _Truth)>(
          <Object>[for (final _Code c in codes) _TruthJob(c)],
          workers,
          incoming,
          'first reads',
        )).map(((String, _Truth) t) => MapEntry<String, _Truth>(t.$1, t.$2)),
      );

      final List<_CodeJob> jobs = <_CodeJob>[
        for (final _Code c in codes)
          if (truths[c.id]!.ours != null || truths[c.id]!.reference != null)
            for (final _Condition k in conditions)
              _CodeJob(c, k, truths[c.id]!),
      ];
      final List<_Result> results = await _dispatch<_Result>(
        jobs,
        workers,
        incoming,
        'codes',
      );

      final List<_FalseRead> negatives = _only.isNotEmpty
          ? <_FalseRead>[]
          : await _dispatch<_FalseRead>(
              <Object>[
                for (final String name in _negativeNames()) _NegativeJob(name),
              ],
              workers,
              incoming,
              'frames without a code',
            );

      await pool.close();
      tmp.deleteSync(recursive: true);

      final _Summary summary = _Summary(
        codes,
        conditions,
        truths,
        results,
        negatives,
      );
      File('${out.path}/results.json').writeAsStringSync(
        const JsonEncoder.withIndent(' ').convert(summary.toJson()),
      );
      File('${out.path}/report.md').writeAsStringSync(summary.report());
      await _saveDivergent(summary, out);
      _saveSamples(codes, out);
      // ignore: avoid_print
      print(summary.headline());
    },
    skip: _out == null ? 'ACCURACY names no output folder' : false,
    timeout: Timeout.none,
  );
}

/// A few frames of every code, to see what the bench reads.
void _saveSamples(List<_Code> codes, Directory out) {
  final Directory dir = Directory('${out.path}/samples')
    ..createSync(recursive: true);
  const List<(String, _Condition)> samples = <(String, _Condition)>[
    ('clean', _Condition(_basePpm, 0, 0, 0, 0)),
    ('working', _Condition(3, 1, 30, 0, 0)),
    ('hard', _Condition(2, 1.5, 45, 0, 0)),
    ('noise', _Condition(_basePpm, 0, 0, 2, 3)),
  ];
  for (final _Code code in codes) {
    for (final (String name, _Condition k) in samples) {
      File(
        '${dir.path}/${code.id}_$name.png',
      ).writeAsBytesSync(_render(code, k, 2).png);
    }
  }
}

/// The first frames per code that only one of the two readers read.
Future<void> _saveDivergent(_Summary s, Directory out) async {
  final Directory dir = Directory('${out.path}/diverged');
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
  for (final _Code code in s.codes) {
    int saved = 0;
    for (final _Condition k in s.conditions) {
      final _Result? r = s.result(code.id, k);
      if (r == null) {
        continue;
      }
      for (final int shot in <int>[...r.onlyReference, ...r.onlyOurs]) {
        if (saved++ < 3) {
          dir.createSync(recursive: true);
          final String who = r.onlyReference.contains(shot)
              ? 'reference'
              : 'ours';
          File(
            '${dir.path}/${code.id}_${k.key.replaceAll('/', '_')}_s${shot}_$who.png',
          ).writeAsBytesSync(_render(code, k, shot).png);
        }
      }
    }
  }
}

// --- The report --------------------------------------------------------------

String _clip(String s) => s.length > 72 ? '${s.substring(0, 72)}…' : s;

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

final class _Limits {
  const _Limits(this.ppm, this.blur, this.tilt);

  /// The fewest pixels per module, the most blur and the most tilt read 8 of 8
  /// with the other axes at their easiest; null if not even the easiest is.
  final double? ppm;
  final double? blur;
  final double? tilt;
}

final class _ZoneResult {
  _ZoneResult(this.zone);
  final _Zone zone;
  int cells = 0;
  int passed = 0;
  int worst = _shots;
  final List<(_Condition, int)> failures = <(_Condition, int)>[];
  bool get ok => passed == cells;
}

final class _Summary {
  _Summary(
    this.codes,
    this.conditions,
    this.truths,
    List<_Result> results,
    this.negatives,
  ) : _results = <String, _Result>{
        for (final _Result r in results) '${r.code}@${r.condition}': r,
      };

  final List<_Code> codes;
  final List<_Condition> conditions;
  final Map<String, _Truth> truths;
  final Map<String, _Result> _results;
  final List<_FalseRead> negatives;

  _Result? result(String code, _Condition k) => _results['$code@${k.key}'];

  int _reads(String code, double ppm, double blur, double tilt) =>
      result(code, _Condition(ppm, blur, tilt, 0, 0))?.ours ?? 0;

  _Limits limits(String code) {
    double? ppm;
    for (final double p in _ppms.reversed) {
      if (_reads(code, p, 0, 0) < _shots) {
        break;
      }
      ppm = p;
    }
    double? blur;
    for (final double b in _blurs) {
      if (_reads(code, _basePpm, b, 0) < _shots) {
        break;
      }
      blur = b;
    }
    double? tilt;
    for (final double t in _tilts) {
      if (_reads(code, _basePpm, 0, t) < _shots) {
        break;
      }
      tilt = t;
    }
    return _Limits(ppm, blur, tilt);
  }

  _ZoneResult zone(String code, _Zone zone) {
    final _ZoneResult z = _ZoneResult(zone);
    for (final _Condition k in conditions) {
      if (!k.isGrid || k.zone != zone) {
        continue;
      }
      final int reads = result(code, k)?.ours ?? 0;
      z.cells++;
      z.worst = math.min(z.worst, reads);
      if (reads >= zone.required) {
        z.passed++;
      } else {
        z.failures.add((k, reads));
      }
    }
    z.failures.sort(
      ((_Condition, int) a, (_Condition, int) b) => a.$2.compareTo(b.$2),
    );
    return z;
  }

  Iterable<_Result> get _all => _results.values;
  int get onlyReference =>
      _all.fold(0, (int n, _Result r) => n + r.onlyReference.length);
  int get onlyOurs => _all.fold(0, (int n, _Result r) => n + r.onlyOurs.length);
  int get wrongReads => _all.fold(0, (int n, _Result r) => n + r.oursWrong);
  int get referenceWrongReads =>
      _all.fold(0, (int n, _Result r) => n + r.referenceWrong);

  /// What was read instead of [code], and how many times, most frequent first.
  Map<String, int> wrongTexts(String code) {
    final Map<String, int> counts = <String, int>{};
    for (final _Result r in _all.where((_Result r) => r.code == code)) {
      for (final String text in r.wrongTexts) {
        counts[text] = (counts[text] ?? 0) + 1;
      }
    }
    final List<String> keys = counts.keys.toList()
      ..sort((String a, String b) {
        final int byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return <String, int>{for (final String k in keys) k: counts[k]!};
  }

  List<_FalseRead> get falseReads => negatives
      .where((_FalseRead f) => f.ours.isNotEmpty || f.reference.isNotEmpty)
      .toList();

  int _passing(_Zone z) => codes.where((_Code c) => zone(c.id, z).ok).length;

  String headline() =>
      '${codes.length} codes, ${conditions.length} conditions: working zone '
      '${_passing(_Zone.working)}/${codes.length}, hard zone '
      '${_passing(_Zone.hard)}/${codes.length}; only the reference read '
      '$onlyReference frames, only we read $onlyOurs; wrong reads $wrongReads; '
      'false reads in ${falseReads.length}/${negatives.length} frames '
      'without a code';

  Map<String, Object?> toJson() => <String, Object?>{
    'codes': <String, Object?>{
      for (final _Code c in codes)
        c.id: <String, Object?>{
          'title': c.title,
          'modules': <double>[c.modulesWide, c.modulesHigh],
          'truth': truths[c.id]?.ours,
          'referenceTruth': truths[c.id]?.reference,
          'wrongReads': wrongTexts(c.id),
          'limits': <String, double?>{
            'ppm': limits(c.id).ppm,
            'blur': limits(c.id).blur,
            'tilt': limits(c.id).tilt,
          },
          'conditions': <String, List<int>>{
            for (final _Condition k in conditions)
              if (result(c.id, k) case final _Result r)
                k.key: <int>[
                  r.ours,
                  r.reference,
                  r.oursWrong,
                  r.referenceWrong,
                  r.onlyReference.length,
                  r.onlyOurs.length,
                ],
          },
        },
    },
    'falseReads': <String, Object?>{
      for (final _FalseRead f in falseReads)
        f.frame: <String, List<String>>{
          'ours': f.ours,
          'reference': f.reference,
        },
    },
    'framesWithoutCode': negatives.length,
  };

  String report() {
    final StringBuffer b = StringBuffer()
      ..writeln('# Accuracy bench')
      ..writeln()
      ..writeln(headline())
      ..writeln()
      ..writeln(
        'Each condition is read $_shots times with `ReaderOptions.camera()`, '
        'with another subpixel shift and tilt direction each time. Limits: '
        'the other axes at their easiest, at ${_num(_basePpm)} px per module '
        'for blur and tilt. Noise and lighting are read at '
        '${_num(_basePpm)} px per module.',
      )
      ..writeln()
      ..writeln('| Zone | Conditions | Asked for |')
      ..writeln('|---|---|---|')
      ..writeln(
        '| Working | from 3 px per module, blur up to 1, tilt up to 30° | 8 of 8 |',
      )
      ..writeln(
        '| Hard | from 2 px per module, blur up to ${_hardBlur * 8}/8 of a module, tilt up to 45° | 6 of 8 |',
      )
      ..writeln('| Limit | under 2 px per module | measured only |')
      ..writeln()
      ..writeln('## Limits of every code')
      ..writeln()
      ..writeln(
        '| Code | Modules | Min px/module | Max blur | Max tilt | Working | '
        'Worst | Hard | Worst | Only reference |',
      )
      ..writeln('|---|---|---|---|---|---|---|---|---|---|');
    String limit(double? v, String unit) => v == null ? '—' : '${_num(v)}$unit';
    for (final _Code c in codes) {
      final _Limits l = limits(c.id);
      final _ZoneResult work = zone(c.id, _Zone.working);
      final _ZoneResult hard = zone(c.id, _Zone.hard);
      final int only = _all
          .where((_Result r) => r.code == c.id)
          .fold(0, (int n, _Result r) => n + r.onlyReference.length);
      b.writeln(
        '| ${c.title} | ${_num(c.modulesWide)} × ${_num(c.modulesHigh)} '
        '| ${limit(l.ppm, '')} | ${limit(l.blur, '')} | ${limit(l.tilt, '°')} '
        '| ${work.ok ? '✅' : '❌'} ${work.passed}/${work.cells} '
        '| ${work.worst}/$_shots '
        '| ${hard.ok ? '✅' : '❌'} ${hard.passed}/${hard.cells} '
        '| ${hard.worst}/$_shots | ${only == 0 ? '' : only} |',
      );
    }

    b
      ..writeln()
      ..writeln('## Noise and lighting')
      ..writeln()
      ..writeln(
        '| Code | ${<String>[for (final String n in _noises)
          for (final String l in _lights) '$n, $l'].join(' | ')} |',
      )
      ..writeln('|---|${List<String>.filled(12, '---').join('|')}|');
    for (final _Code c in codes) {
      b.writeln(
        '| ${c.title} | ${<String>[for (int n = 0; n < _noises.length; n++)
          for (int l = 0; l < _lights.length; l++) '${result(c.id, _Condition(_basePpm, 0, 0, n, l))?.ours ?? '—'}'].join(' | ')} |',
      );
    }

    b
      ..writeln()
      ..writeln('## Where the working zone fails')
      ..writeln();
    bool any = false;
    for (final _Code c in codes) {
      final _ZoneResult work = zone(c.id, _Zone.working);
      if (work.ok) {
        continue;
      }
      any = true;
      b.writeln(
        '- **${c.title}**: ${work.failures.length} of ${work.cells} conditions, '
        'worst: ${work.failures.take(4).map(((_Condition, int) f) => '${f.$1.label} (${f.$2}/$_shots)').join('; ')}',
      );
    }
    if (!any) {
      b.writeln('Every code reads 8 of 8 in the whole working zone.');
    }

    b
      ..writeln()
      ..writeln('## Wrong reads')
      ..writeln()
      ..writeln(
        'Frames of a code in which something else was read as well or '
        'instead: $wrongReads here, $referenceWrongReads by the reference.',
      )
      ..writeln();
    final List<String> wrong = <String>[
      for (final _Code c in codes)
        if (wrongTexts(c.id) case final Map<String, int> texts
            when texts.isNotEmpty)
          '- **${c.title}**, right: `${_clip(truths[c.id]?.ours ?? '')}`: ${texts.entries.take(6).map((MapEntry<String, int> e) => '`${_clip(e.key)}` × ${e.value}').join(', ')}',
    ];
    b.writeln(wrong.isEmpty ? 'None.' : wrong.join('\n'));

    b
      ..writeln()
      ..writeln('## First reads')
      ..writeln();
    final List<String> first = <String>[
      for (final _Code c in codes)
        if (truths[c.id]?.ours == null)
          '- **${c.title}**: not read in a clean frame by us${truths[c.id]?.reference == null ? ' or the reference' : ''}.'
        else if (c.expected != null && truths[c.id]!.oursText != c.expected)
          '- **${c.title}**: reads “${truths[c.id]!.oursText}”, expected “${c.expected}”.',
    ];
    b.writeln(
      first.isEmpty
          ? 'Every code reads as expected in a clean frame.'
          : first.join('\n'),
    );

    b
      ..writeln()
      ..writeln('## Against the reference')
      ..writeln()
      ..writeln(
        'ZXingReader of the same zxing-cpp reads the same frames with the same '
        'options. Frames only it read point to our layer; they are saved in '
        '`diverged/`.',
      )
      ..writeln()
      ..writeln('- Only the reference read: $onlyReference frames.')
      ..writeln('- Only we read: $onlyOurs frames.');

    b
      ..writeln()
      ..writeln('## Frames without a code')
      ..writeln()
      ..writeln(
        '${negatives.length} frames: ${_syntheticKinds.length * _syntheticPerKind} '
        'drawn (noise, gratings, random bars, random blocks, text) and the '
        'images of zxing-cpp without a code. Something was read in '
        '${falseReads.length}.',
      );
    for (final _FalseRead f in falseReads) {
      b.writeln(
        '- `${f.frame}`: ours ${f.ours.isEmpty ? 'nothing' : f.ours.join(', ')}; '
        'reference ${f.reference.isEmpty ? 'nothing' : f.reference.join(', ')}',
      );
    }
    return b.toString();
  }
}
