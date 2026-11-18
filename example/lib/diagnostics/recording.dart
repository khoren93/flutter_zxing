// Camera frames kept in a file, to read them again later, with other settings
// or on another device: what the camera saw stops being a matter of luck.
//
// A recording is one file: `FZXREC1\n`, the length of the JSON header as a
// little-endian u32, the header, then the luminance of every frame.
//
// No dart:io here: the package's test/tool/replay_test.dart reads recordings
// on a computer with the same code.
// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/engine/engine.dart';
import 'package:flutter_zxing/src/engine/engine_protocol.dart';

/// The luminance of the [crop] of [image] (all of it for `null`), one byte
/// per pixel, tightly packed.
Uint8List lumaOf(PixelBuffer image, Rect? crop) {
  final Rect area =
      crop ??
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  final int left = area.left.toInt();
  final int top = area.top.toInt();
  final int w = area.width.toInt();
  final int h = area.height.toInt();
  final int bpp = image.layout.bytesPerPixel;
  final int stride = image.rowStride ?? image.width * bpp;
  final Uint8List b = image.bytes;
  final Uint8List out = Uint8List(w * h);
  for (int y = 0; y < h; y++) {
    final int row = (top + y) * stride + left * bpp;
    if (image.layout == PixelLayout.luminance) {
      out.setRange(y * w, (y + 1) * w, b, row);
      continue;
    }
    final bool bgra = image.layout == PixelLayout.bgra;
    for (int x = 0; x < w; x++) {
      final int i = row + x * bpp;
      final int red = b[bgra ? i + 2 : i];
      final int blue = b[bgra ? i : i + 2];
      // zxing-cpp's RGBToLum.
      out[y * w + x] = (306 * red + 601 * b[i + 1] + 117 * blue + 0x200) >> 10;
    }
  }
  return out;
}

/// A barcode read from a frame.
@immutable
final class RecordedRead {
  /// Creates a read.
  const RecordedRead(this.format, this.text);

  /// A read of a recording's header.
  RecordedRead.fromJson(Map<String, dynamic> json)
    : format = json['f'] as String,
      text = json['t'] as String;

  /// The read of [barcode].
  RecordedRead.of(Barcode barcode)
    : format = barcode.format.name,
      text = barcode.text;

  final String format;
  final String text;

  /// Tells two reads apart.
  String get key => '$format:$text';
}

/// One recorded frame.
@immutable
final class RecordedFrame {
  /// Creates a frame.
  const RecordedFrame({
    required this.width,
    required this.height,
    required this.pixels,
    required this.atMicros,
    required this.engineMicros,
    required this.reads,
    this.mirrored = false,
  });

  final int width;
  final int height;

  /// Luminance, [width] × [height] bytes.
  final Uint8List pixels;

  /// When it was read, from the start of the recorder.
  final int atMicros;

  /// How long the engine took on the device.
  final int engineMicros;

  /// What the device read from it.
  final List<RecordedRead> reads;

  /// Whether the camera delivered it mirrored.
  final bool mirrored;
}

/// Frames with the settings they were read with.
@immutable
final class Recording {
  /// Creates a recording.
  const Recording({
    required this.name,
    required this.device,
    required this.build,
    required this.engine,
    required this.settings,
    required this.frames,
  });

  /// A recording read back from [bytes].
  factory Recording.decode(Uint8List bytes) {
    final int length = headerLength(bytes);
    final Map<String, dynamic> h = decodeHeader(
      Uint8List.sublistView(bytes, _prefix, _prefix + length),
    );
    int offset = _prefix + length;
    final List<RecordedFrame> frames = <RecordedFrame>[];
    for (final Object? raw in h['frames'] as List<Object?>) {
      final Map<String, dynamic> f = raw! as Map<String, dynamic>;
      final int width = f['w'] as int;
      final int height = f['h'] as int;
      frames.add(
        RecordedFrame(
          width: width,
          height: height,
          pixels: Uint8List.sublistView(bytes, offset, offset + width * height),
          atMicros: f['t'] as int,
          engineMicros: f['e'] as int,
          mirrored: f['m'] as bool? ?? false,
          reads: <RecordedRead>[
            for (final Object? r in f['r'] as List<Object?>)
              RecordedRead.fromJson(r! as Map<String, dynamic>),
          ],
        ),
      );
      offset += width * height;
    }
    return Recording(
      name: h['name'] as String,
      device: h['device'] as String,
      build: h['build'] as String,
      engine: h['engine'] as String,
      settings: h['settings'] as Map<String, dynamic>,
      frames: frames,
    );
  }

  static const String _magic = 'FZXREC1\n';

  /// The bytes before the JSON header.
  static const int _prefix = 12;

  /// How many bytes of a file [headerLength] needs.
  static const int prefixLength = _prefix;

  /// The length of the JSON header, from the first bytes of a recording.
  /// Throws [FormatException] if they are not those of a recording.
  static int headerLength(Uint8List start) {
    if (start.length < _prefix ||
        ascii.decode(start.sublist(0, _magic.length), allowInvalid: true) !=
            _magic) {
      throw const FormatException('Not a recording');
    }
    return ByteData.sublistView(start).getUint32(_magic.length, Endian.little);
  }

  /// The JSON header of a recording.
  static Map<String, dynamic> decodeHeader(Uint8List header) =>
      jsonDecode(utf8.decode(header)) as Map<String, dynamic>;

  final String name;
  final String device;
  final String build;

  /// The zxing-cpp version it was read with.
  final String engine;
  final Map<String, Object?> settings;
  final List<RecordedFrame> frames;

  /// The file, in pieces: the frames are not copied.
  Iterable<Uint8List> encode() sync* {
    final Uint8List header = utf8.encode(
      jsonEncode(<String, Object?>{
        'name': name,
        'device': device,
        'build': build,
        'engine': engine,
        'settings': settings,
        'frames': <Object?>[
          for (final RecordedFrame f in frames)
            <String, Object?>{
              'w': f.width,
              'h': f.height,
              't': f.atMicros,
              'e': f.engineMicros,
              if (f.mirrored) 'm': true,
              'r': <Object?>[
                for (final RecordedRead r in f.reads)
                  <String, String>{'f': r.format, 't': r.text},
              ],
            },
        ],
      }),
    );
    final Uint8List prefix = Uint8List(_prefix)
      ..setAll(0, ascii.encode(_magic));
    ByteData.sublistView(
      prefix,
    ).setUint32(_magic.length, header.length, Endian.little);
    yield prefix;
    yield header;
    for (final RecordedFrame f in frames) {
      yield f.pixels;
    }
  }
}

/// How a frame read again compares with what the device read.
enum ReplayOutcome {
  /// The same barcodes, or none both times.
  same,

  /// Barcodes only now.
  gained,

  /// Barcodes only on the device.
  lost,

  /// Other barcodes than on the device.
  changed,
}

/// One frame read again.
@immutable
final class ReplayFrame {
  /// Creates the result.
  const ReplayFrame(this.frame, this.reads, this.micros);

  final RecordedFrame frame;
  final List<RecordedRead> reads;

  /// How long the engine took now.
  final int micros;

  /// How this read compares with the device's.
  ReplayOutcome get outcome {
    final List<String> before =
        frame.reads.map((RecordedRead r) => r.key).toList()..sort();
    final List<String> now = reads.map((RecordedRead r) => r.key).toList()
      ..sort();
    if (listEquals(before, now)) {
      return ReplayOutcome.same;
    }
    return before.isEmpty
        ? ReplayOutcome.gained
        : (now.isEmpty ? ReplayOutcome.lost : ReplayOutcome.changed);
  }
}

/// A recording read again.
@immutable
final class ReplayReport {
  /// Creates the report.
  const ReplayReport(this.frames);

  final List<ReplayFrame> frames;

  int _count(ReplayOutcome outcome) =>
      frames.where((ReplayFrame f) => f.outcome == outcome).length;

  int get same => _count(ReplayOutcome.same);
  int get gained => _count(ReplayOutcome.gained);
  int get lost => _count(ReplayOutcome.lost);
  int get changed => _count(ReplayOutcome.changed);

  /// Frames the device read a barcode from.
  int get recordedWithCode =>
      frames.where((ReplayFrame f) => f.frame.reads.isNotEmpty).length;

  /// Frames a barcode was read from now.
  int get withCode =>
      frames.where((ReplayFrame f) => f.reads.isNotEmpty).length;

  /// Engine time now, in milliseconds, at [p] (0 to 1).
  double decodeMs(double p) {
    if (frames.isEmpty) {
      return 0;
    }
    final List<int> sorted = frames.map((ReplayFrame f) => f.micros).toList()
      ..sort();
    return sorted[((sorted.length - 1) * p).round()] / 1000;
  }
}

/// Reads every frame of [recording] again with [options].
Future<ReplayReport> replayRecording(
  Recording recording,
  EngineReadOptions options, {
  BarcodeEngine? engine,
  ValueChanged<int>? onProgress,
}) async {
  final BarcodeEngine e = engine ?? BarcodeEngine.shared;
  final List<ReplayFrame> frames = <ReplayFrame>[];
  for (final RecordedFrame f in recording.frames) {
    final EngineReadResult r = await e.readPixels(
      PixelBuffer(f.pixels, width: f.width, height: f.height),
      options,
      mirrored: f.mirrored,
    );
    frames.add(
      ReplayFrame(f, <RecordedRead>[
        for (final Barcode b in r.barcodes)
          if (b.isValid) RecordedRead.of(b),
      ], r.engineMicros),
    );
    onProgress?.call(frames.length);
  }
  return ReplayReport(frames);
}
