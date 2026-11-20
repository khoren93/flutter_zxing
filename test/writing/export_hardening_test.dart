// Exports at their edges: logos on small codes, add-ons, captions, odd text.
@Tags(<String>['native'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/writing/symbol_layout.dart';

Future<Uint8List> _logoPng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 64, 64),
    Paint()..color = const Color(0xFF1B4DFF),
  );
  final ui.Image image = await recorder.endRecording().toImage(64, 64);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('QR codes read under every logo size, short payloads too', () async {
    final Uint8List png = await _logoPng();
    final List<String> unread = <String>[];
    for (final double size in <double>[0.12, 0.18, 0.2, 0.22, 0.25, 0.3]) {
      final BarcodeStyle style = BarcodeStyle(
        logo: BarcodeLogo(MemoryImage(png), size: size),
      );
      for (int length = 1; length <= 40; length += length < 10 ? 1 : 5) {
        for (final String seed in <String>['a', 'K', '7']) {
          final String text = String.fromCharCodes(<int>[
            for (int i = 0; i < length; i++) seed.codeUnitAt(0) + (i * 7) % 20,
          ]);
          final Uint8List image = await style.encodePng(
            const BarcodeWriter(BarcodeFormat.qrCode),
            text,
            size: 512,
          );
          final Barcode? read = await const BarcodeReader().read(image);
          if (read?.text != text) {
            unread.add('$size "$text"');
          }
        }
      }
    }
    expect(unread, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));

  group('digits with an add-on', () {
    Future<String?> printed(BarcodeFormat format, String data) async =>
        (await BarcodeWriter(format, showText: true).encode(data)).text;

    test('as the reader returns them', () async {
      expect(
        await printed(BarcodeFormat.upcA, '697929110035+12'),
        '69792911003512',
      );
      expect(await printed(BarcodeFormat.upcE, '01234565+12'), '0123456512');
      expect(await printed(BarcodeFormat.ean8, '96385074+12'), '9638507412');
    });
  });

  test('eanUpc gets the digits of an EAN-13', () async {
    final BarcodeSymbol symbol = await const BarcodeWriter(
      BarcodeFormat.eanUpc,
      showText: true,
    ).encode('4006381333931');
    expect(SymbolLayout(symbol).textRuns, hasLength(13));
  });

  test('a card shadow keeps modules on whole pixels', () async {
    final BarcodeSymbol symbol = await const BarcodeWriter(
      BarcodeFormat.qrCode,
    ).encode('HELLO');
    final Uint8List png = await const BarcodeStyle(
      card: BarcodeCard(elevation: 0.05),
    ).toPng(symbol, moduleSize: 3);
    expect((await const BarcodeReader().read(png))?.text, 'HELLO');
  });

  group('SVG captions', () {
    Future<List<String>> lines(BarcodeCaption caption) async {
      final BarcodeSymbol symbol = await const BarcodeWriter(
        BarcodeFormat.qrCode,
      ).encode('HELLO');
      final String svg = await BarcodeStyle(caption: caption).toSvg(symbol);
      return <String>[
        for (final RegExpMatch m in RegExp(
          r'<tspan[^>]*>([^<]*)</tspan>',
        ).allMatches(svg))
          m.group(1)!,
      ];
    }

    test('a blank line stays blank', () async {
      final List<String> shown = await lines(
        const BarcodeCaption('a\n\nb', maxLines: 3),
      );
      expect(shown.where((String l) => l.isNotEmpty), <String>['a', 'b']);
    });

    test('no ellipsis after a line break', () async {
      expect(await lines(const BarcodeCaption('a\nb\nc')), <String>['a', 'b']);
    });

    test('control characters are left out', () async {
      expect(await lines(const BarcodeCaption('A\u0007B')), <String>['AB']);
    });
  });

  test('a PNG with a caption has no translucent last row', () async {
    final BarcodeSymbol symbol = await const BarcodeWriter(
      BarcodeFormat.qrCode,
    ).encode('HELLO');
    final Uint8List png = await const BarcodeStyle(
      caption: BarcodeCaption('@x'),
    ).toPng(symbol);
    final ui.Codec codec = await ui.instantiateImageCodec(png);
    final ui.Image image = (await codec.getNextFrame()).image;
    codec.dispose();
    final ByteData rgba = (await image.toByteData())!;
    final int width = image.width;
    final int height = image.height;
    image.dispose();
    final List<int> alpha = <int>[
      for (int x = 0; x < width; x++)
        rgba.getUint8(((height - 1) * width + x) * 4 + 3),
    ];
    expect(alpha.toSet(), <int>{255});
  });

  group('SVG of an EAN-13 with a gradient and no quiet zone', () {
    const LinearGradient gradient = LinearGradient(
      colors: <Color>[Color(0xFFFF0000), Color(0xFF0000FF)],
    );
    Future<String> svg() async {
      final BarcodeSymbol symbol = await const BarcodeWriter(
        BarcodeFormat.ean13,
        showText: true,
      ).encode('4006381333931');
      return const BarcodeStyle(
        gradient: gradient,
        quietZone: false,
      ).toSvg(symbol);
    }

    test('the gradient spans the bars', () async {
      // The bars start 7 modules in, after the room for the first digit.
      expect(await svg(), contains(RegExp(r'<linearGradient [^>]*x1="7" ')));
    });

    test('the digits take the first color of the gradient', () async {
      final List<String> fills = <String>[
        for (final RegExpMatch m in RegExp(
          r'<text [^>]*fill="([^"]*)"',
        ).allMatches(await svg()))
          m.group(1)!,
      ];
      expect(fills, hasLength(13));
      expect(fills.toSet(), <String>{'#f00'});
    });
  });

  test('SVG text keeps runs of spaces', () async {
    final BarcodeSymbol symbol = await const BarcodeWriter(
      BarcodeFormat.code128,
      showText: true,
    ).encode('A  B');
    final String svg = await const BarcodeStyle(
      caption: BarcodeCaption('Wi-Fi   guest'),
    ).toSvg(symbol);
    final List<String> texts = <String>[
      for (final RegExpMatch m in RegExp(r'<text [^>]*>').allMatches(svg))
        m.group(0)!,
    ];
    expect(texts, hasLength(2));
    for (final String t in texts) {
      expect(t, contains('white-space:pre'));
    }
    expect(svg, contains('A  B'));
    expect(svg, contains('Wi-Fi   guest'));
  });

  test('SVG ids differ between gradients and shadows', () async {
    final BarcodeSymbol symbol = await const BarcodeWriter(
      BarcodeFormat.qrCode,
    ).encode('HELLO');
    Future<Set<String>> ids(BarcodeStyle style) async {
      final String svg = await style.toSvg(symbol);
      final Set<String> defined = <String>{
        for (final RegExpMatch m in RegExp(r' id="([^"]*)"').allMatches(svg))
          m.group(1)!,
      };
      final Set<String> used = <String>{
        for (final RegExpMatch m in RegExp(r'url\(#([^)]*)\)').allMatches(svg))
          m.group(1)!,
      };
      expect(used, defined);
      return defined;
    }

    final Set<String> a = await ids(
      const BarcodeStyle(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFFFF0000), Color(0xFF0000FF)],
        ),
        card: BarcodeCard(elevation: 0.04),
      ),
    );
    final Set<String> b = await ids(
      const BarcodeStyle(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF00FF00), Color(0xFF0000FF)],
        ),
        card: BarcodeCard(elevation: 0.08),
      ),
    );
    expect(a, hasLength(2));
    expect(b, hasLength(2));
    expect(a.intersection(b), isEmpty);
  });

  test('SVG numbers do not end in a dot', () async {
    final BarcodeSymbol symbol = await const BarcodeWriter(
      BarcodeFormat.qrCode,
    ).encode('HELLO');
    final String svg = await const BarcodeStyle(
      card: BarcodeCard(padding: 0.23809),
    ).toSvg(symbol);
    expect(svg, isNot(contains(RegExp(r'\d\.[" ]'))));
  });

  test('long text shrinks to the width of its code', () {
    const TextRun run = TextRun('(01)09501101530003', 26, 0, 9, fit: true);
    expect(run.fittedSize(52) * 18 * 0.6, lessThanOrEqualTo(52));
    expect(const TextRun('123', 26, 0, 9, fit: true).fittedSize(52), 9);
  });
}
