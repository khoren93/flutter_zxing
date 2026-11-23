// Encoding for a style on the real engine: the error correction and size a
// logo needs, on every path from data to picture.
@Tags(<String>['native'])
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/rendering/frame_layout.dart';
import 'package:flutter_zxing/src/rendering/logo_symbol.dart';
import 'package:flutter_zxing/src/writing/symbol_layout.dart';

/// A [size] × [size] PNG: a dark square, like an app icon.
Future<Uint8List> _logoPng([int size = 64]) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = const Color(0xFF0B3D91),
  );
  final ui.Image image = await recorder.endRecording().toImage(size, size);
  final ByteData png = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!;
  image.dispose();
  return png.buffer.asUint8List();
}

/// An image with resolution variants, like an asset with `2.0x/` and
/// `3.0x/`: 16 logical pixels wide, in the variant the configuration asks
/// for. Remembers the ratios asked for.
final class _Variants extends ImageProvider<double> {
  _Variants();

  final List<double> asked = <double>[];

  @override
  Future<double> obtainKey(ImageConfiguration configuration) {
    final double ratio = configuration.devicePixelRatio ?? 1;
    asked.add(ratio);
    // The variants an app would ship.
    final double variant = ratio <= 1
        ? 1
        : ratio <= 2
        ? 2
        : ratio <= 3
        ? 3
        : 4;
    return SynchronousFuture<double>(variant);
  }

  @override
  ImageStreamCompleter loadImage(double key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(() async {
        final ui.Codec codec = await ui.instantiateImageCodec(
          await _logoPng((16 * key).round()),
        );
        final ui.Image image = (await codec.getNextFrame()).image;
        codec.dispose();
        return ImageInfo(image: image, scale: key);
      }());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(warmUpBarcodeEngine);

  const BarcodeWriter qr = BarcodeWriter(BarcodeFormat.qrCode);
  const String wifi = 'WIFI:T:WPA;S:Cafe Central;P:espresso-doppio-42;;';
  late Uint8List logoPng;
  late BarcodeStyle withLogo;
  setUpAll(() async {
    logoPng = await _logoPng();
    withLogo = BarcodeStyle(logo: BarcodeLogo(MemoryImage(logoPng)));
  });

  group('BarcodeSymbol.errorCorrection', () {
    test('is the level the writer used', () async {
      for (final ErrorCorrection level in ErrorCorrection.values) {
        final BarcodeSymbol symbol = await BarcodeWriter(
          BarcodeFormat.qrCode,
          errorCorrection: level,
        ).encode('x');
        expect(symbol.errorCorrection, level);
      }
      expect((await qr.encode('x')).errorCorrection, ErrorCorrection.medium);
      expect(
        (await const BarcodeWriter(
          BarcodeFormat.dataMatrix,
        ).encode('x')).errorCorrection,
        isNull,
      );
    });

    test('is the level a reader found', () async {
      final Uint8List png = await const BarcodeWriter(
        BarcodeFormat.qrCode,
        errorCorrection: ErrorCorrection.quartile,
      ).toPng('read back');
      final Barcode? read = await const BarcodeReader().read(png);
      expect(read?.symbol?.errorCorrection, ErrorCorrection.quartile);
    });
  });

  group('style.encode', () {
    test('a logo gets its error correction, and a Wi-Fi code with a logo '
        'exported through the symbol reads', () async {
      final BarcodeSymbol symbol = await withLogo.encode(wifi);
      expect(symbol.errorCorrection, ErrorCorrection.high);
      final Uint8List png = await withLogo.toPng(symbol, size: 512);
      expect((await const BarcodeReader().read(png))?.text, wifi);
      final String svg = await withLogo.toSvg(symbol);
      expect(svg, contains('<image '));
    });

    test("the writer's own error correction stays", () async {
      final BarcodeSymbol symbol = await withLogo.encode(
        wifi,
        writer: const BarcodeWriter(
          BarcodeFormat.qrCode,
          errorCorrection: ErrorCorrection.quartile,
        ),
      );
      expect(symbol.errorCorrection, ErrorCorrection.quartile);
    });

    test('zxingOptions set the level and version as the typed fields do', () {
      final BarcodeLogo logo = withLogo.logo!;
      expect(
        writerUnderLogo(
          const BarcodeWriter(BarcodeFormat.qrCode, zxingOptions: 'ecLevel=L'),
          logo,
        ).errorCorrection,
        isNull,
      );
      expect(
        writerUnderLogo(qr, logo).errorCorrection,
        logo.neededErrorCorrection,
      );
    });

    test('a version in zxingOptions stays: encoded once', () async {
      int calls = 0;
      final BarcodeSymbol small = await qr.encode('a');
      await encodeUnderLogo(
        const BarcodeWriter(BarcodeFormat.qrCode, zxingOptions: 'Version:1'),
        0.25,
        (BarcodeWriter w) async {
          calls++;
          return small;
        },
      );
      expect(calls, 1);
    });

    test('a short text gets a symbol large enough for the logo', () async {
      final BarcodeSymbol plain = await qr.encode('a');
      final BarcodeSymbol styled = await withLogo.encode('a');
      expect(plain.width, 21);
      expect(styled.width, greaterThan(21));
    });

    test('encodeBytes: the same for binary data', () async {
      final BarcodeSymbol symbol = await withLogo.encodeBytes(
        Uint8List.fromList(<int>[0, 1, 0xFE, 0xFF]),
      );
      expect(symbol.errorCorrection, ErrorCorrection.high);
    });

    test("encodeContent: the content's kind, the logo's level", () async {
      final BarcodeSymbol symbol = await withLogo.encodeContent(
        const WifiContent(ssid: 'Cafe Central', password: 'espresso-42'),
      );
      expect(symbol.errorCorrection, ErrorCorrection.high);
      final Uint8List png = await withLogo.toPng(symbol, size: 512);
      final Barcode? read = await const BarcodeReader().read(png);
      expect(read?.content, isA<WifiContent>());
      // GS1 content is encoded as GS1.
      final BarcodeSymbol gs1 = await BarcodeStyle.classic.encodeContent(
        const Gs1Content(<String, String>{'01': '09501101530003'}),
        writer: const BarcodeWriter(BarcodeFormat.dataMatrix),
      );
      final Barcode? gs1Read = await const BarcodeReader().read(
        await gs1.toPng(),
      );
      expect(gs1Read?.contentType, BarcodeContentType.gs1);
    });
  });

  group('too little error correction for the logo', () {
    test('a ready symbol exported with a logo asserts', () async {
      final BarcodeSymbol low = await const BarcodeWriter(
        BarcodeFormat.qrCode,
        errorCorrection: ErrorCorrection.low,
      ).encode(wifi);
      await expectLater(withLogo.toPng(low), throwsA(isA<AssertionError>()));
      await expectLater(withLogo.toSvg(low), throwsA(isA<AssertionError>()));
      await expectLater(
        withLogo.encodePng(
          wifi,
          writer: const BarcodeWriter(
            BarcodeFormat.qrCode,
            errorCorrection: ErrorCorrection.low,
          ),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('unless the logo asks for less, or the level is unknown', () async {
      final BarcodeSymbol medium = await qr.encode(wifi);
      final BarcodeStyle swiss = BarcodeStyle.swissQrBill;
      expect(await swiss.toPng(medium), isNotEmpty);
      final BarcodeSymbol unknown = BarcodeSymbol(
        format: medium.format,
        width: medium.width,
        height: medium.height,
        modules: medium.modules,
        quietZone: medium.quietZone,
      );
      expect(await withLogo.toPng(unknown), isNotEmpty);
    });

    testWidgets('BarcodeView.symbol asserts', (WidgetTester tester) async {
      final BarcodeSymbol low = (await tester.runAsync(
        () => const BarcodeWriter(
          BarcodeFormat.qrCode,
          errorCorrection: ErrorCorrection.low,
        ).encode(wifi),
      ))!;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: BarcodeView.symbol(low, style: withLogo, width: 200),
        ),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });
  });

  group('export sizes', () {
    test('a PNG with a card is exactly the size, transparent around', () async {
      final BarcodeSymbol symbol = await qr.encode('card');
      const BarcodeStyle style = BarcodeStyle(
        caption: BarcodeCaption('@flutterdev'),
        card: BarcodeCard(),
      );
      final Uint8List png = await style.toPng(symbol, size: 1000);
      final ui.Image image = await decodeImageFromList(png);
      // Taller than wide: the height is the size.
      expect(image.height, 1000);
      expect(image.width, lessThan(1000));
      final ByteData rgba = (await image.toByteData())!;
      expect(rgba.getUint8(3), 0, reason: 'the corner is transparent');
      image.dispose();
    });

    test('a PNG without a card fills the margin with the background', () async {
      final BarcodeSymbol symbol = await qr.encode('ground');
      final Uint8List png = await BarcodeStyle.ink.toPng(symbol, size: 1000);
      final ui.Image image = await decodeImageFromList(png);
      expect((image.width, image.height), (1000, 1000));
      final ByteData rgba = (await image.toByteData())!;
      expect(rgba.getUint32(0), 0xF4EFE4FF);
      image.dispose();
    });

    test('an SVG is sized in pixels, its viewBox in modules', () async {
      final BarcodeSymbol symbol = await qr.encode('svg');
      final int side = symbol.width + 2 * symbol.quietZone;
      final String byModule = await BarcodeStyle.classic.toSvg(symbol);
      expect(byModule, contains('viewBox="0 0 $side $side"'));
      expect(byModule, contains('width="${side * 4}" height="${side * 4}"'));
      final String bySize = await BarcodeStyle.classic.toSvg(symbol, size: 512);
      expect(bySize, contains('width="512" height="512"'));
      await expectLater(
        BarcodeStyle.classic.toSvg(symbol, size: side - 1),
        throwsArgumentError,
      );
      expect(
        await qr.toSvg('svg', moduleSize: 10),
        contains('width="${side * 10}"'),
      );
    });
  });

  group('the logo in an export', () {
    test('is loaded in the resolution variant for its size', () async {
      final _Variants image = _Variants();
      final BarcodeStyle style = BarcodeStyle(logo: BarcodeLogo(image));
      final BarcodeSymbol symbol = await style.encode(wifi);
      // 1x is 16 pixels wide; at 1024 the logo is about 225.
      await style.toPng(symbol, size: 1024);
      expect(image.asked.last, greaterThan(3));
      image.asked.clear();
      // 4 pixels per module: the 1x variant is wide enough.
      await style.toPng(symbol, moduleSize: 1);
      expect(image.asked, <double>[1]);
    });

    test('a logo that fails to load fails the export', () async {
      final BarcodeStyle style = BarcodeStyle(
        logo: BarcodeLogo(MemoryImage(Uint8List.fromList(<int>[1, 2, 3]))),
      );
      final BarcodeSymbol symbol = await style.encode('x');
      await expectLater(style.toPng(symbol), throwsA(anything));
    });
  });

  group('showText', () {
    test('null follows the format: digits under retail codes only', () async {
      for (final (BarcodeFormat format, String data)
          in <(BarcodeFormat, String)>[
            (BarcodeFormat.ean13, '4006381333931'),
            (BarcodeFormat.ean8, '96385074'),
            (BarcodeFormat.upcA, '036000291452'),
            (BarcodeFormat.upcE, '01234565'),
            (BarcodeFormat.isbn, '9780306406157'),
          ]) {
        expect(
          (await BarcodeWriter(format).encode(data)).text,
          isNotNull,
          reason: format.name,
        );
      }
      expect(
        (await const BarcodeWriter(BarcodeFormat.code128).encode('A1')).text,
        isNull,
      );
      expect(
        (await const BarcodeWriter(
          BarcodeFormat.ean13,
          showText: false,
        ).encode('4006381333931')).text,
        isNull,
      );
      expect(
        (await const BarcodeWriter(
          BarcodeFormat.code128,
          showText: true,
        ).encode('A1')).text,
        'A1',
      );
    });
  });

  group('BarcodeStyle.copyWith', () {
    test('clears the fields that may be null, keeps the others', () {
      final BarcodeStyle full = BarcodeStyle(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF000000), Color(0xFF0000FF)],
        ),
        logo: BarcodeLogo(MemoryImage(logoPng)),
        title: const BarcodeCaption('T'),
        caption: const BarcodeCaption('C'),
        card: const BarcodeCard(),
      );
      expect(full.copyWith(color: const Color(0xFF00735D)).logo, full.logo);
      final BarcodeStyle cleared = full.copyWith(
        gradient: () => null,
        logo: () => null,
        title: () => null,
        caption: () => null,
        card: () => null,
      );
      expect(cleared, BarcodeStyle.classic);
      expect(
        cleared.copyWith(card: () => const BarcodeCard(radius: 0.2)).card,
        const BarcodeCard(radius: 0.2),
      );
    });
  });

  group('BarcodeCaption.letterSpacing', () {
    test("is in em; the TextStyle's is ignored, like its size", () async {
      final SymbolLayout code = SymbolLayout(await qr.encode('spacing'));
      FrameText caption(BarcodeCaption c) =>
          FrameLayout(code, BarcodeStyle(caption: c)).caption!;
      expect(
        caption(
          const BarcodeCaption('@a', style: TextStyle(letterSpacing: 40)),
        ).style.letterSpacing,
        0,
      );
      final TextPainter spaced = caption(
        const BarcodeCaption('@abc', letterSpacing: 0.5),
      ).painter(10, TextDirection.ltr);
      final TextPainter tight = caption(
        const BarcodeCaption('@abc'),
      ).painter(10, TextDirection.ltr);
      expect(
        spaced.computeLineMetrics().single.width,
        greaterThan(tight.computeLineMetrics().single.width),
      );
      spaced.dispose();
      tight.dispose();
      expect(
        const BarcodeCaption('a', letterSpacing: 0.1),
        isNot(const BarcodeCaption('a')),
      );
      final String svg = await const BarcodeStyle(
        caption: BarcodeCaption('@a', letterSpacing: 0.1),
      ).toSvg(await qr.encode('spacing'));
      expect(svg, contains('letter-spacing="'));
    });
  });

  group('style.encodeContent: what the standard requires', () {
    test('a Swiss QR-bill: error correction M under the cross', () async {
      final BarcodeSymbol symbol = await BarcodeStyle.swissQrBill.encodeContent(
        _bill,
      );
      expect(symbol.format, BarcodeFormat.qrCode);
      expect(symbol.errorCorrection, ErrorCorrection.medium);
    });

    test('an EPC payment: M whatever the writer says', () async {
      final BarcodeSymbol symbol = await BarcodeStyle.classic.encodeContent(
        _epc,
        writer: const BarcodeWriter(
          BarcodeFormat.qrCode,
          errorCorrection: ErrorCorrection.high,
        ),
      );
      expect(symbol.errorCorrection, ErrorCorrection.medium);
      final Barcode? read = await const BarcodeReader().read(
        await BarcodeStyle.classic.toPng(symbol),
      );
      expect(read?.content, _epc);
    });
  });

  test('encodePng and encodeSvg make a QR code without a writer', () async {
    final Uint8List png = await BarcodeStyle.soft.encodePng(
      'https://pub.dev',
      size: 256,
    );
    final Barcode? read = await const BarcodeReader().read(png);
    expect(read?.format, BarcodeFormat.qrCode);
    expect(read?.text, 'https://pub.dev');
    expect(
      await BarcodeStyle.classic.encodeSvg('https://pub.dev'),
      startsWith('<svg'),
    );
  });
}

const EpcPaymentContent _epc = EpcPaymentContent(
  name: 'Kaffeehaus Lumen GmbH',
  iban: 'DE89370400440532013000',
  amount: '19.50',
);

const SwissQrBillContent _bill = SwissQrBillContent(
  iban: 'CH4431999123000889012',
  creditor: SwissAddress(
    name: 'Robert Schneider AG',
    street: 'Rue du Lac',
    buildingNumber: '1268',
    postalCode: '2501',
    town: 'Biel',
    country: 'CH',
  ),
  amount: '1949.75',
  creditorReference: '210000000003139471430009017',
);
