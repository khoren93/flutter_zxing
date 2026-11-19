// A code's title, caption and card: the layout, and the PNG and SVG exports
// on the real engine.
@Tags(<String>['native'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/rendering/frame_layout.dart';
import 'package:flutter_zxing/src/writing/symbol_layout.dart';

/// The pixel at (x, y) of [png], as ARGB.
Future<int> _pixel(Uint8List png, int x, int y) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData rgba = (await image.toByteData())!;
  final int i = (y * image.width + x) * 4;
  final int argb =
      rgba.getUint8(i + 3) << 24 |
      rgba.getUint8(i) << 16 |
      rgba.getUint8(i + 1) << 8 |
      rgba.getUint8(i + 2);
  image.dispose();
  return argb;
}

Future<(int, int)> _size(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  final (int, int) size = (image.width, image.height);
  image.dispose();
  return size;
}

void main() {
  const String url = 'https://t.me/flutterdev';
  const BarcodeWriter qr = BarcodeWriter(BarcodeFormat.qrCode);

  group('layout', () {
    late SymbolLayout code;
    setUpAll(() async => code = SymbolLayout(await qr.encode(url)));

    test('without text or card: the code alone', () {
      final FrameLayout frame = FrameLayout(code, BarcodeStyle.classic);
      expect(frame.plain, isTrue);
      expect(frame.width, code.width);
      expect(frame.height, code.height);
      expect(frame.codeOrigin, Offset.zero);
      expect(frame.outset, 0);
    });

    test('a caption goes under the code, a title above', () {
      final double q = code.quietZone.toDouble();
      final double unit = code.width - 2 * q;
      final FrameLayout frame = FrameLayout(
        code,
        const BarcodeStyle(
          title: BarcodeCaption('Studio 5G'),
          caption: BarcodeCaption('@flutterdev'),
        ),
      );
      final FrameText title = frame.title!;
      final FrameText caption = frame.caption!;
      // Sizes are fractions of the symbol, without its quiet zone.
      expect(title.fontSize, closeTo(0.09 * unit, 1e-9));
      expect(title.lines.single.$1, 'Studio 5G');
      expect(caption.lines.single.$1, '@flutterdev');
      // The gap (0.05 of the symbol) is smaller than the quiet zone: the
      // text sits at the quiet zone's edge, not past it.
      expect(0.05 * unit, lessThan(q));
      expect(frame.codeOrigin.dy, closeTo(title.rect.bottom, 1e-9));
      expect(caption.rect.top, closeTo(frame.codeRect.bottom, 1e-9));
      expect(frame.height, closeTo(caption.rect.bottom, 1e-9));
      expect(frame.width, code.width);
    });

    test('without a quiet zone, the gap is its own', () async {
      final SymbolLayout bare = SymbolLayout(
        withoutQuietZone(await qr.encode(url)),
      );
      final double unit = bare.width.toDouble();
      final FrameLayout frame = FrameLayout(
        bare,
        const BarcodeStyle(
          quietZone: false,
          caption: BarcodeCaption('@flutterdev'),
        ),
      );
      expect(
        frame.caption!.rect.top,
        closeTo(frame.codeRect.bottom + 0.05 * unit, 1e-9),
      );
    });

    test('long text wraps to the code width, up to maxLines', () {
      final FrameLayout frame = FrameLayout(
        code,
        BarcodeStyle(caption: BarcodeCaption('Scan to follow ' * 12)),
      );
      final List<(String, double)> lines = frame.caption!.lines;
      expect(lines, hasLength(2));
      expect(lines.last.$1, endsWith('…'));
      expect(lines[1].$2, greaterThan(lines[0].$2));
    });

    test('a card pads every side, the quiet zone not added on top; a '
        'shadow adds an outset', () {
      final double q = code.quietZone.toDouble();
      final double unit = code.width - 2 * q;
      final FrameLayout frame = FrameLayout(
        code,
        const BarcodeStyle(card: BarcodeCard(padding: 0.2, elevation: 0.04)),
      );
      // 0.2 of the symbol is more than its quiet zone: the padding wins, and
      // the quiet zone lies inside it.
      final double pad = 0.2 * unit;
      expect(pad, greaterThan(q));
      expect(frame.width, closeTo(unit + 2 * pad, 1e-9));
      expect(frame.height, closeTo(unit + 2 * pad, 1e-9));
      expect(frame.codeOrigin, Offset(pad - q, pad - q));
      expect(frame.cardRadius, closeTo(unit * 0.12, 1e-9));
      expect(frame.cardColor, const Color(0xFFFFFFFF));
      expect(frame.outset, greaterThan(0));
      // A padding under the quiet zone grows to it.
      final FrameLayout tight = FrameLayout(
        code,
        const BarcodeStyle(card: BarcodeCard(padding: 0.01)),
      );
      expect(tight.width, code.width);
      expect(tight.codeOrigin, Offset.zero);
    });
  });

  group('PNG', () {
    test('with a caption and a card, still reads; transparent around the '
        'card', () async {
      const BarcodeStyle style = BarcodeStyle(
        moduleShape: ModuleShape.rounded,
        caption: BarcodeCaption('@FLUTTERDEV'),
        card: BarcodeCard(),
      );
      final Uint8List png = await style.encodePng(qr, url, moduleSize: 6);
      final (int width, int height) = await _size(png);
      expect(height, greaterThan(width));
      expect((await const BarcodeReader().read(png))?.text, url);
      // The corner is outside the rounded card.
      expect((await _pixel(png, 0, 0)) >>> 24, 0);
      // The middle of the left edge is on it.
      expect(await _pixel(png, 1, height ~/ 2), 0xFFFFFFFF);
    });

    test('a caption without a card: on the background', () async {
      const BarcodeStyle style = BarcodeStyle(
        backgroundColor: Color(0xFFF4EFE4),
        caption: BarcodeCaption('@flutterdev'),
      );
      final Uint8List png = await style.encodePng(qr, url, moduleSize: 4);
      expect(await _pixel(png, 0, 0), 0xFFF4EFE4);
      expect((await const BarcodeReader().read(png))?.text, url);
    });

    test('a card of another color keeps the code on its own ground', () async {
      final Uint8List png = await BarcodeStyle.night
          .copyWith(
            caption: () => const BarcodeCaption('@flutterdev'),
            // Wider than the quiet zone, which keeps the code's ground.
            card: () =>
                const BarcodeCard(color: Color(0xFF1D4ED8), padding: 0.3),
          )
          .encodePng(qr, url, moduleSize: 4);
      final (int width, _) = await _size(png);
      // Left edge, in the card's padding: the card's color.
      expect(await _pixel(png, 2, width ~/ 2), 0xFF1D4ED8);
      expect((await const BarcodeReader().read(png))?.text, url);
    });

    test('size fits the whole frame, shadow included', () async {
      final Uint8List png = await const BarcodeStyle(
        caption: BarcodeCaption('@flutterdev'),
        card: BarcodeCard(elevation: 0.04),
      ).encodePng(qr, url, size: 512);
      final (int width, int height) = await _size(png);
      expect(width, lessThanOrEqualTo(512));
      expect(height, lessThanOrEqualTo(512));
      expect((await const BarcodeReader().read(png))?.text, url);
    });
  });

  group('SVG', () {
    test('text as lines, the code moved inside the card', () async {
      final String svg = await const BarcodeStyle(
        title: BarcodeCaption(
          'Studio 5G',
          style: TextStyle(fontFamily: 'Instrument Sans'),
          letterSpacing: 0.02,
        ),
        // Small enough for one line in the test font, where every glyph is
        // as wide as it is tall.
        caption: BarcodeCaption('Scan to join & <play>', size: 0.04),
        card: BarcodeCard(radius: 0.1, elevation: 0.04),
      ).encodeSvg(qr, url);
      expect(svg, contains('<filter id="shadow"'));
      expect(svg, contains(' rx="'));
      expect(svg, contains('<g transform="translate('));
      expect(svg, contains("font-family=\"'Instrument Sans', sans-serif\""));
      expect(svg, contains('font-weight="700"'));
      expect(svg, contains('letter-spacing="'));
      expect(svg, contains('>Studio 5G</tspan>'));
      expect(svg, contains('>Scan to join &amp; &lt;play&gt;</tspan>'));
      expect(svg, matches(RegExp(r'viewBox="-[\d.]+ -[\d.]+ ')));
    });

    test('without text or card: as before', () async {
      final String svg = await BarcodeStyle.classic.encodeSvg(qr, url);
      expect(
        svg,
        startsWith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 '),
      );
      expect(svg, isNot(contains('<text')));
      expect(svg, contains('<g shape-rendering="crispEdges">'));
    });
  });

  test('equality and copyWith carry the new fields', () {
    const BarcodeStyle a = BarcodeStyle(
      caption: BarcodeCaption('@a'),
      card: BarcodeCard(),
    );
    expect(
      a,
      const BarcodeStyle(caption: BarcodeCaption('@a'), card: BarcodeCard()),
    );
    expect(
      a,
      isNot(
        const BarcodeStyle(caption: BarcodeCaption('@b'), card: BarcodeCard()),
      ),
    );
    expect(
      a.copyWith(title: () => const BarcodeCaption('T')).title,
      const BarcodeCaption('T'),
    );
    expect(a.copyWith(color: const Color(0xFF00735D)).caption, a.caption);
  });
}
