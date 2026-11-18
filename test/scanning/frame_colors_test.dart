// A camera frame in color, turned the way the preview shows it.
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/camera/frame_colors.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';

/// The red channel of [rgba], row by row.
List<List<int>> _rows((Uint8List, int, int) rgba) {
  final (Uint8List bytes, int width, int height) = rgba;
  return <List<int>>[
    for (int y = 0; y < height; y++)
      <int>[for (int x = 0; x < width; x++) bytes[(y * width + x) * 4]],
  ];
}

void main() {
  // 1 2 3
  // 4 5 6
  final FrameColors gray = FrameColors.of(
    PixelBuffer(
      Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6]),
      width: 3,
      height: 2,
    ),
  );
  const Size size = Size(3, 2);

  test('turns and mirrors like the preview', () {
    List<List<int>> shown(FrameTransform t) => _rows(frameToRgba((gray, t)));
    expect(shown(const FrameTransform(size)), <List<int>>[
      <int>[1, 2, 3],
      <int>[4, 5, 6],
    ]);
    expect(shown(const FrameTransform(size, rotation: 90)), <List<int>>[
      <int>[4, 1],
      <int>[5, 2],
      <int>[6, 3],
    ]);
    expect(shown(const FrameTransform(size, rotation: 180)), <List<int>>[
      <int>[6, 5, 4],
      <int>[3, 2, 1],
    ]);
    expect(shown(const FrameTransform(size, rotation: 270)), <List<int>>[
      <int>[3, 6],
      <int>[2, 5],
      <int>[1, 4],
    ]);
    expect(shown(const FrameTransform(size, mirrored: true)), <List<int>>[
      <int>[3, 2, 1],
      <int>[6, 5, 4],
    ]);
  });

  test('a pixel lands where FrameTransform says', () {
    for (final int rotation in <int>[0, 90, 180, 270]) {
      for (final bool mirrored in <bool>[false, true]) {
        final FrameTransform t = FrameTransform(
          size,
          rotation: rotation,
          mirrored: mirrored,
        );
        final List<List<int>> rows = _rows(frameToRgba((gray, t)));
        for (int y = 0; y < 2; y++) {
          for (int x = 0; x < 3; x++) {
            // Through the middle of the pixel.
            final Offset d = t.toDisplay(Offset(x + 0.5, y + 0.5));
            expect(rows[d.dy.floor()][d.dx.floor()], y * 3 + x + 1);
          }
        }
      }
    }
  });

  test('reads the color of every layout', () {
    (int, int, int) first(FrameColors colors) {
      final (Uint8List b, _, _) = frameToRgba((
        colors,
        const FrameTransform(Size(2, 2)),
      ));
      expect(b[3], 255);
      return (b[0], b[1], b[2]);
    }

    FrameColors flat(List<int> pixel, PixelLayout layout) => FrameColors.of(
      PixelBuffer(
        Uint8List.fromList(<int>[for (int i = 0; i < 4; i++) ...pixel]),
        width: 2,
        height: 2,
        layout: layout,
      ),
    );
    expect(first(flat(<int>[10, 20, 30, 255], PixelLayout.rgba)), (10, 20, 30));
    expect(first(flat(<int>[30, 20, 10, 255], PixelLayout.bgra)), (10, 20, 30));
    expect(first(flat(<int>[10, 20, 30], PixelLayout.rgb)), (10, 20, 30));

    // Pure red in YUV: Android's three planes, full range.
    final Uint8List y = Uint8List(4)..fillRange(0, 4, 76);
    final (int, int, int) android = first(
      FrameColors(
        y,
        width: 2,
        height: 2,
        stride: 2,
        u: Uint8List.fromList(<int>[85]),
        v: Uint8List.fromList(<int>[255]),
        chromaStride: 1,
      ),
    );
    expect(android.$1, greaterThan(245));
    expect(android.$2, lessThan(10));
    expect(android.$3, lessThan(10));

    // iOS: colors alternating, video range.
    final Uint8List luma = Uint8List(4)..fillRange(0, 4, 81);
    final Uint8List uv = Uint8List.fromList(<int>[90, 240]);
    final (int, int, int) ios = first(
      FrameColors(
        luma,
        width: 2,
        height: 2,
        stride: 2,
        u: uv,
        v: uv,
        vOffset: 1,
        chromaStride: 2,
        chromaPixelStride: 2,
        limitedRange: true,
      ),
    );
    expect(ios.$1, greaterThan(245));
    expect(ios.$2, lessThan(10));
    expect(ios.$3, lessThan(10));
  });

  test('a large frame comes out smaller, in shape', () {
    final FrameColors large = FrameColors.of(
      PixelBuffer(Uint8List(1920 * 1080), width: 1920, height: 1080),
    );
    final (Uint8List bytes, int width, int height) = frameToRgba((
      large,
      const FrameTransform(Size(1920, 1080), rotation: 90),
    ));
    expect((width, height), (540, 960));
    expect(bytes.length, 540 * 960 * 4);
  });

  test('a frame shorter than it says does not throw', () {
    final FrameColors cut = FrameColors.of(
      PixelBuffer(Uint8List(3), width: 2, height: 2),
    );
    expect(frameToRgba((cut, const FrameTransform(Size(2, 2)))).$2, 2);
  });
}
