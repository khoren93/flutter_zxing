// The recordings of the diagnostics page: the file format, and frames read
// again by the real engine.
@Tags(<String>['native'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

// The recording format lives in the example app.
// ignore: avoid_relative_lib_imports
import '../../example/lib/diagnostics/diag_settings.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/diagnostics/recording.dart';

Uint8List _join(Iterable<Uint8List> parts) {
  final BytesBuilder b = BytesBuilder(copy: false);
  parts.forEach(b.add);
  return b.takeBytes();
}

Recording _recording(List<RecordedFrame> frames, {DiagSettings? settings}) =>
    Recording(
      name: 'test',
      device: 'test device',
      build: 'debug',
      engine: zxingCppVersion,
      settings: (settings ?? const DiagSettings()).toJson(),
      frames: frames,
    );

/// A frame with a QR code holding [text], 6 pixels per module.
Future<RecordedFrame> _qrFrame(
  String text, {
  List<RecordedRead>? reads,
  bool inverted = false,
}) async {
  final BarcodeSymbol s = await const BarcodeWriter(
    BarcodeFormat.qrCode,
  ).encode(text);
  const int scale = 6, quiet = 4;
  final int size = (s.width + 2 * quiet) * scale;
  final Uint8List p = Uint8List(size * size);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final int mx = x ~/ scale - quiet, my = y ~/ scale - quiet;
      final bool dark =
          mx >= 0 &&
          my >= 0 &&
          mx < s.width &&
          my < s.height &&
          s.modules[my * s.width + mx] != 0;
      p[y * size + x] = dark != inverted ? 0 : 255;
    }
  }
  return RecordedFrame(
    width: size,
    height: size,
    pixels: p,
    atMicros: 1000,
    engineMicros: 900,
    reads:
        reads ?? <RecordedRead>[RecordedRead(BarcodeFormat.qrCode.name, text)],
  );
}

void main() {
  group('the file', () {
    test('keeps everything', () {
      final Recording r = Recording.decode(
        _join(
          _recording(<RecordedFrame>[
            RecordedFrame(
              width: 2,
              height: 2,
              pixels: Uint8List.fromList(<int>[1, 2, 3, 4]),
              atMicros: 10,
              engineMicros: 5,
              mirrored: true,
              reads: const <RecordedRead>[RecordedRead('qrCode', 'Привет')],
            ),
            RecordedFrame(
              width: 3,
              height: 1,
              pixels: Uint8List.fromList(<int>[7, 8, 9]),
              atMicros: 20,
              engineMicros: 6,
              reads: const <RecordedRead>[],
            ),
          ], settings: const DiagSettings(tryInvert: true)).encode(),
        ),
      );
      expect(r.device, 'test device');
      expect(DiagSettings.fromJson(r.settings).tryInvert, isTrue);
      expect(r.frames.first.pixels, <int>[1, 2, 3, 4]);
      expect(r.frames.first.mirrored, isTrue);
      expect(r.frames.first.reads.single.text, 'Привет');
      expect(r.frames.last.pixels, <int>[7, 8, 9]);
      expect(r.frames.last.mirrored, isFalse);
    });

    test('anything else is refused', () {
      expect(
        () => Recording.decode(Uint8List.fromList(utf8.encode('not a file!!'))),
        throwsFormatException,
      );
      expect(() => Recording.decode(Uint8List(3)), throwsFormatException);
    });
  });

  group('lumaOf', () {
    test('cuts the window out of a plane with padding', () {
      final Uint8List plane = Uint8List.fromList(<int>[
        1, 2, 3, 0, //
        4, 5, 6, 0, //
        7, 8, 9, 0, //
      ]);
      expect(
        lumaOf(
          PixelBuffer(plane, width: 3, height: 3, rowStride: 4),
          const Rect.fromLTWH(1, 1, 2, 2),
        ),
        <int>[5, 6, 8, 9],
      );
    });

    test('turns colours into luminance', () {
      final Uint8List red = Uint8List.fromList(<int>[255, 0, 0, 255]);
      final Uint8List blue = Uint8List.fromList(<int>[255, 0, 0, 255]);
      expect(
        lumaOf(
          PixelBuffer(red, width: 1, height: 1, layout: PixelLayout.rgba),
          null,
        ),
        <int>[(306 * 255 + 0x200) >> 10],
      );
      expect(
        lumaOf(
          PixelBuffer(blue, width: 1, height: 1, layout: PixelLayout.bgra),
          null,
        ),
        <int>[(117 * 255 + 0x200) >> 10],
      );
    });
  });

  group('reading again', () {
    test('finds what the device found', () async {
      final ReplayReport r = await replayRecording(
        _recording(<RecordedFrame>[await _qrFrame('same')]),
        const DiagSettings().engineOptions,
      );
      expect(r.same, 1);
      expect(r.withCode, 1);
    });

    test('other settings show what they change', () async {
      final Recording recording = _recording(<RecordedFrame>[
        await _qrFrame('night', inverted: true, reads: const <RecordedRead>[]),
      ]);
      final ReplayReport off = await replayRecording(
        recording,
        const DiagSettings().engineOptions,
      );
      expect(off.same, 1);
      final ReplayReport on = await replayRecording(
        recording,
        const DiagSettings(tryInvert: true).engineOptions,
      );
      expect(on.gained, 1);
      expect(on.frames.single.reads.single.text, 'night');
    });

    test('a frame no longer read counts as lost', () async {
      final ReplayReport r = await replayRecording(
        _recording(<RecordedFrame>[await _qrFrame('gone')]),
        const DiagSettings(formats: DiagFormats.linear).engineOptions,
      );
      expect(r.lost, 1);
    });

    test('another code counts as changed', () async {
      final ReplayReport r = await replayRecording(
        _recording(<RecordedFrame>[
          await _qrFrame(
            'now',
            reads: const <RecordedRead>[RecordedRead('qrCode', 'before')],
          ),
        ]),
        const DiagSettings().engineOptions,
      );
      expect(r.changed, 1);
    });
  });
}
