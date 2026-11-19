// Renders the scanner templates over a fake camera into PNG files, to
// compare them with the designs and for the README. Skipped unless SHOTS
// names an output folder:
//
//   SHOTS=/tmp/shots flutter test test/tool/scanner_shots_test.dart
//
// Text uses Roboto from the Flutter SDK when FLUTTER_ROOT is set.
@Tags(<String>['native'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/camera/camera_source.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;

import '../scanning/fake_camera.dart';

final String? _out = Platform.environment['SHOTS'];
const Size _phone = Size(390, 844);
final GlobalKey _boundary = GlobalKey();

Future<void> _loadFonts() async {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    return;
  }
  final String dir = '$root/bin/cache/artifacts/material_fonts';
  final FontLoader roboto = FontLoader('Roboto');
  for (final String weight in <String>['Regular', 'Medium', 'Bold']) {
    final File file = File('$dir/Roboto-$weight.ttf');
    if (file.existsSync()) {
      roboto.addFont(
        Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await roboto.load();
  final File menlo = File('/System/Library/Fonts/Menlo.ttc');
  if (menlo.existsSync()) {
    await (FontLoader('Menlo')..addFont(
          Future<ByteData>.value(ByteData.sublistView(menlo.readAsBytesSync())),
        ))
        .load();
  }
}

/// A camera scene: blurred light and shadow, like an out-of-focus room.
Widget _scene(List<Color> colors, List<(Alignment, Color)> lights) => Stack(
  fit: StackFit.expand,
  children: <Widget>[
    DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    ),
    for (final (Alignment at, Color color) in lights)
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: at,
            radius: 0.7,
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
  ],
);

Widget _warm(List<Widget> papers) => Stack(
  children: <Widget>[
    _scene(
      const <Color>[Color(0xFF4A4D52), Color(0xFF2C2F35), Color(0xFF1D1F24)],
      const <(Alignment, Color)>[
        (Alignment(-0.64, -0.56), Color(0x8CD6AA78)),
        (Alignment(0.7, -0.76), Color(0x73789AAA)),
        (Alignment(0.4, 0.9), Color(0xB35A463C)),
      ],
    ),
    ...papers,
  ],
);

Widget _cool(List<Widget> papers) => Stack(
  children: <Widget>[
    _scene(
      const <Color>[Color(0xFF3B4652), Color(0xFF232A33), Color(0xFF171B21)],
      const <(Alignment, Color)>[
        (Alignment(-0.6, -0.7), Color(0x8096BEDC)),
        (Alignment(0.8, 0.6), Color(0x993C5A6E)),
      ],
    ),
    ...papers,
  ],
);

Widget _shelf(List<Widget> papers) => Stack(
  children: <Widget>[
    _scene(
      const <Color>[Color(0xFF5A5650), Color(0xFF3A3631), Color(0xFF24211E)],
      const <(Alignment, Color)>[(Alignment(0, -0.6), Color(0x73E6D2AA))],
    ),
    const Positioned(
      left: 0,
      right: 0,
      top: 300,
      height: 22,
      child: ColoredBox(color: Color(0xE63A2E22)),
    ),
    ...papers,
  ],
);

Widget _paper(Rect rect, double degrees, Widget child) => Positioned.fromRect(
  rect: rect,
  child: Transform.rotate(
    angle: degrees * math.pi / 180,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F5F0),
        borderRadius: BorderRadius.all(Radius.circular(6)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Center(child: child),
    ),
  ),
);

/// The corners of a [code]-sized symbol in the middle of [paper], turned
/// like the paper.
BarcodePosition _corners(Rect paper, Size code, double degrees) {
  final Offset c = paper.center;
  final double a = degrees * math.pi / 180;
  Offset at(double x, double y) =>
      c +
      Offset(
        x * math.cos(a) - y * math.sin(a),
        x * math.sin(a) + y * math.cos(a),
      );
  final double w = code.width / 2;
  final double h = code.height / 2;
  return BarcodePosition(
    topLeft: at(-w, -h),
    topRight: at(w, -h),
    bottomRight: at(w, h),
    bottomLeft: at(-w, h),
  );
}

Barcode _code(
  BarcodeFormat format,
  String text,
  BarcodePosition position,
  String id, {
  BarcodeContentType type = BarcodeContentType.text,
}) => Barcode(
  format: format,
  text: text,
  bytes: Uint8List.fromList(utf8.encode(text)),
  position: position,
  symbologyIdentifier: id,
  contentType: type,
);

Widget _host(Widget child, {Size size = _phone}) => MediaQuery(
  data: MediaQueryData(
    size: size,
    devicePixelRatio: 2,
    padding: size.width < size.height
        ? const EdgeInsets.only(top: 47, bottom: 34)
        : const EdgeInsets.only(left: 47, right: 47, bottom: 21),
    viewPadding: size.width < size.height
        ? const EdgeInsets.only(top: 47, bottom: 34)
        : const EdgeInsets.only(left: 47, right: 47, bottom: 21),
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: DefaultTextStyle(
      style: const TextStyle(fontFamily: 'Roboto'),
      child: RepaintBoundary(
        key: _boundary,
        child: SizedBox.fromSize(size: size, child: child),
      ),
    ),
  ),
);

/// Pumps until the engine has drawn every BarcodeView.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 100; i++) {
    final bool waiting = tester
        .widgetList<BarcodeView>(find.byType(BarcodeView))
        .any(
          (BarcodeView v) => find
              .descendant(
                of: find.byWidget(v),
                matching: find.byType(CustomPaint),
              )
              .evaluate()
              .isEmpty,
        );
    if (!waiting) {
      await tester.pump();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<void> _save(WidgetTester tester, String name) async {
  final RenderRepaintBoundary boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData png = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!;
    image.dispose();
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png.buffer.asUint8List());
  });
}

void main() {
  late FakeCamera camera;

  setUpAll(() async {
    await _loadFonts();
    await warmUpBarcodeEngine();
  });

  tearDown(() => ScannerControllerDebug.cameraFactory = null);

  Future<void> shot(
    WidgetTester tester,
    String name, {
    required Widget preview,
    required ScannerTemplate template,
    ScannerTheme? theme,
    List<Barcode> barcodes = const <Barcode>[],
    bool torch = false,
    Size size = _phone,
    ScannerException? openError,
    bool start = true,
    Duration wait = const Duration(milliseconds: 100),
  }) async {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    camera = FakeCamera(
      transform: FrameTransform(size),
      capabilities: const CameraCapabilities(
        hasTorch: true,
        maxZoom: 6,
        hasOtherFacing: true,
      ),
      preview: SizedBox.fromSize(size: size, child: preview),
    )..openError = openError;
    ScannerControllerDebug.cameraFactory = () => camera;
    final ScannerController controller = ScannerController.fromTemplate(
      template,
      autoStart: start,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        BarcodeScanner(
          key: ValueKey<String>(name),
          controller: controller,
          template: template,
          theme: theme,
        ),
        size: size,
      ),
    );
    await tester.pump();
    await _settle(tester);
    if (torch) {
      await controller.setTorch(true);
    }
    if (barcodes.isNotEmpty) {
      camera.push(barcodes);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
    } else {
      await tester.pump(wait);
      await tester.pump(wait);
    }
    await _save(tester, name);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  // Scenes and codes, as on the boards in Claude Design.
  const String url = 'https://pub.dev/packages/flutter_zxing';
  const Rect minimalPaper = Rect.fromLTWH(159, 413, 174, 174);
  const Rect lockedPaper = Rect.fromLTWH(108, 321, 174, 174);
  Widget qr(String text, double size) =>
      BarcodeView(text, width: size, height: size);
  final Widget searching = _warm(<Widget>[
    _paper(minimalPaper, -9, qr(url, 150)),
  ]);
  final Widget locked = _cool(<Widget>[_paper(lockedPaper, 6, qr(url, 150))]);
  final Barcode lockedCode = _code(
    BarcodeFormat.qrCode,
    url,
    _corners(lockedPaper, const Size(117, 117), 6),
    ']Q1',
  );
  ScannerTemplate closable(ScannerTemplate t) => t.copyWith(onClose: () {});

  testWidgets('minimal', (WidgetTester tester) async {
    await shot(
      tester,
      'minimal-searching',
      preview: searching,
      template: closable(const ScannerTemplate.minimal()),
    );
    await shot(
      tester,
      'minimal-locked',
      preview: locked,
      template: closable(const ScannerTemplate.minimal()),
      barcodes: <Barcode>[lockedCode],
    );
    await shot(
      tester,
      'minimal-locked-dark',
      preview: locked,
      template: closable(const ScannerTemplate.minimal()),
      theme: const ScannerTheme(brightness: Brightness.dark),
      barcodes: <Barcode>[lockedCode],
    );
    await shot(
      tester,
      'minimal-landscape',
      preview: _cool(<Widget>[
        _paper(const Rect.fromLTWH(335, 108, 174, 174), 6, qr(url, 150)),
      ]),
      template: closable(const ScannerTemplate.minimal()),
      size: const Size(844, 390),
      barcodes: <Barcode>[
        _code(
          BarcodeFormat.qrCode,
          url,
          _corners(
            const Rect.fromLTWH(335, 108, 174, 174),
            const Size(117, 117),
            6,
          ),
          ']Q1',
        ),
      ],
    );
  }, skip: _out == null);

  testWidgets('themes', (WidgetTester tester) async {
    await shot(
      tester,
      'theme-brand',
      preview: _warm(<Widget>[_paper(lockedPaper, 6, qr(url, 150))]),
      template: closable(const ScannerTemplate.minimal()),
      theme: const ScannerTheme(
        accent: Color(0xFFFF6A1A),
        windowRadius: 6,
        buttonShape: ScannerButtonShape.roundedSquare,
      ),
      barcodes: <Barcode>[lockedCode],
    );
    await shot(
      tester,
      'theme-dark-glass',
      preview: locked,
      template: closable(const ScannerTemplate.minimal()),
      theme: const ScannerTheme(
        accent: Color(0xFF4D8DFF),
        brightness: Brightness.dark,
      ),
      barcodes: <Barcode>[lockedCode],
    );
  }, skip: _out == null);

  testWidgets('payment', (WidgetTester tester) async {
    const String epc =
        'BCD\n002\n1\nSCT\n\nKaffeehaus Lumen\nDE89370400440532013000\n'
        'EUR4.80\n\n\nA7F3-21';
    const Rect paper = Rect.fromLTWH(103, 175, 184, 184);
    await shot(
      tester,
      'payment',
      preview: _warm(<Widget>[_paper(paper, -4, qr(epc, 160))]),
      template: closable(
        ScannerTemplate.payment(
          resultBuilder:
              (BuildContext context, Barcode barcode, VoidCallback again) {
                final ScannerTheme theme = ScannerTheme.of(context);
                return ScannerSheet(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('PAYMENT REQUEST', style: theme.overlineStyle),
                      const SizedBox(height: 4),
                      Text('Kaffeehaus Lumen', style: theme.titleStyle),
                      const SizedBox(height: 16),
                      Text('€4.80', style: theme.displayStyle),
                      Text('Reference A7F3-21', style: theme.mutedStyle),
                      const SizedBox(height: 16),
                      const ScannerChip('QR Code'),
                      const SizedBox(height: 16),
                      ScannerActions(<ScannerAction>[
                        ScannerAction(
                          label: 'Pay €4.80',
                          primary: true,
                          onPressed: () {},
                        ),
                        ScannerAction(label: 'Cancel', onPressed: again),
                      ]),
                    ],
                  ),
                );
              },
        ),
      ),
      barcodes: <Barcode>[
        _code(
          BarcodeFormat.qrCode,
          epc,
          _corners(paper, const Size(128, 128), -4),
          ']Q1',
        ),
      ],
    );
  }, skip: _out == null);

  testWidgets('retail', (WidgetTester tester) async {
    const Rect left = Rect.fromLTWH(42, 140, 166, 129);
    const Rect right = Rect.fromLTWH(199, 143, 166, 129);
    Widget ean(String digits) => BarcodeView(
      digits,
      writer: const BarcodeWriter(BarcodeFormat.ean13, showText: true),
      width: 150,
      height: 113,
    );
    await shot(
      tester,
      'retail',
      preview: _shelf(<Widget>[
        _paper(left, -2, ean('5901234123457')),
        _paper(right, 3, ean('4006381333931')),
      ]),
      template: closable(
        ScannerTemplate.retail(title: 'Shelf B-12', onDone: (_) {}),
      ),
      torch: true,
      barcodes: <Barcode>[
        _code(
          BarcodeFormat.ean13,
          '5901234123457',
          _corners(left.translate(0, -9), const Size(126, 78), -2),
          ']E0',
        ),
        _code(
          BarcodeFormat.ean13,
          '4006381333931',
          _corners(right.translate(0, -9), const Size(126, 78), 3),
          ']E0',
        ),
      ],
    );
  }, skip: _out == null);

  testWidgets('ticket', (WidgetTester tester) async {
    const String pass =
        'M1ZXING/FLUTTER       E7QK3TP ZRHAMSLX 0423 318Y012C0034 100';
    const Rect paper = Rect.fromLTWH(45, 232, 300, 136);
    await shot(
      tester,
      'ticket',
      preview: _cool(<Widget>[
        _paper(
          paper,
          -3,
          const BarcodeView(
            pass,
            writer: BarcodeWriter(BarcodeFormat.pdf417),
            width: 220,
            height: 62,
          ),
        ),
      ]),
      template: closable(
        ScannerTemplate.ticket(
          title: 'Scan your boarding pass',
          resultBuilder:
              (BuildContext context, Barcode barcode, VoidCallback again) {
                final ScannerTheme theme = ScannerTheme.of(context);
                return ScannerSheet(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'BOARDING PASS · LX 423',
                        style: theme.overlineStyle,
                      ),
                      const SizedBox(height: 4),
                      Text('Zurich – Amsterdam', style: theme.titleStyle),
                      const SizedBox(height: 16),
                      const ScannerFields(<String, String>{
                        'Passenger': 'ZXING/FLUTTER',
                        'Date': '14 Nov',
                        'Seat': '12C',
                        'Class': 'Y',
                        'Booking': 'E7QK3TP',
                        'Sequence': '34',
                      }),
                      const SizedBox(height: 16),
                      const ScannerChip('PDF417'),
                      const SizedBox(height: 16),
                      ScannerActions(<ScannerAction>[
                        ScannerAction(
                          label: 'Save pass',
                          primary: true,
                          onPressed: () {},
                        ),
                        ScannerAction(label: 'Scan again', onPressed: again),
                      ]),
                    ],
                  ),
                );
              },
        ),
      ),
      barcodes: <Barcode>[
        _code(
          BarcodeFormat.pdf417,
          pass,
          _corners(paper, const Size(214, 56), -3),
          ']L2',
        ),
      ],
    );
  }, skip: _out == null);

  testWidgets('content', (WidgetTester tester) async {
    const String wifi = 'WIFI:S:Lumen Guest;T:WPA;P:espresso-2026;;';
    const Rect paper = Rect.fromLTWH(108, 143, 174, 174);
    await shot(
      tester,
      'content',
      preview: _warm(<Widget>[_paper(paper, 4, qr(wifi, 150))]),
      template: closable(
        ScannerTemplate.content(
          actionsBuilder:
              (BuildContext context, Barcode barcode, VoidCallback again) =>
                  <ScannerAction>[
                    ScannerAction(
                      label: 'Connect',
                      icon: ScannerIcons.wifi,
                      primary: true,
                      onPressed: () {},
                    ),
                    ScannerAction.copy(barcode.text),
                  ],
        ),
      ),
      barcodes: <Barcode>[
        _code(
          BarcodeFormat.qrCode,
          wifi,
          _corners(paper, const Size(117, 117), 4),
          ']Q1',
        ),
      ],
    );
  }, skip: _out == null);

  testWidgets('content kinds', (WidgetTester tester) async {
    // The result sheets of the kinds added in 4.0 rc.2, as in the designs:
    // dark glass, the kind's icon next to the title.
    final Map<String, (String, BarcodeFormat)>
    kinds = <String, (String, BarcodeFormat)>{
      'pay-sepa': (
        <String>[
          'BCD', '002', '1', 'SCT', 'COBADEFFXXX', 'Kaffeehaus Lumen', //
          'DE89370400440532013000', 'EUR12.50', '', '', 'Invoice 42',
        ].join('\n'),
        BarcodeFormat.qrCode,
      ),
      'pay-swiss': (
        <String>[
          'SPC', '0200', '1', 'CH4431999123000889012', //
          'S', 'Robert Schneider AG', 'Rue du Lac', '1268', '2501', 'Biel',
          'CH', '', '', '', '', '', '', '', '1949.75', 'CHF', //
          'S', 'Pia-Maria Rutschmann-Schnyder', 'Grosse Marktgasse', '28',
          '9400', 'Rorschach', 'CH', //
          'QRR', '210000000003139471430009017', 'Order of 15 June 2020', 'EPD',
        ].join('\n'),
        BarcodeFormat.qrCode,
      ),
      'pay-gost': (
        <String>[
          'ST00012',
          'Name=ООО «Три кита»',
          'PersonalAcc=40702810138250123017',
          'BankName=ОАО «Банк»',
          'BIC=044525225',
          'CorrespAcc=30101810400000000225',
          'Sum=125050',
          'Purpose=Оплата по счёту № 7',
          'PayeeINN=7700000000',
        ].join('|'),
        BarcodeFormat.qrCode,
      ),
      'otp': (
        'otpauth://totp/GitHub:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
        BarcodeFormat.qrCode,
      ),
      'esim': (
        r'LPA:1$rsp.lumen-mobile.example$QRF-8H2K-PMRD$$1',
        BarcodeFormat.qrCode,
      ),
      'crypto': (
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.0015&label=Caf%C3%A9%20Lumen&message=Order%20%2312',
        BarcodeFormat.qrCode,
      ),
      'service': (
        'https://wa.me/37491234567?text=Hi%2C%20is%20the%20table%20for%20two%20free%20tonight%3F',
        BarcodeFormat.qrCode,
      ),
      'smart-home': ('MT:Y.K9042C00KA0648G00', BarcodeFormat.qrCode),
      'product': ('9780306406157', BarcodeFormat.ean13),
      'boarding': (
        <String>[
          'M2ZXING/FLUTTER       EE7QK3TPZRHAMSLX 0423 318Y012C0034 100',
          'E7QK3TPAMSGVALX 0731 318Y004A0035 100',
        ].join(),
        BarcodeFormat.pdf417,
      ),
      'license': (
        '@\n\x1e\rANSI 636014080102DL00410288ZC03290015DLDAQD1234562\n'
            'DCSPUBLIC\nDACJOHN\nDADQUINCY\nDBB08311977\nDBA08312020\n'
            'DAIANYTOWN\nDAJCA\nDCGUSA\r',
        BarcodeFormat.pdf417,
      ),
      'vin': ('1M8GDM9AXKP042788', BarcodeFormat.code39),
      'wifi-device': (
        'DPP:C:81/1,115/36;M:5254005828e5;I:SN4321;K:MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgADM2206avxHJaHXgLMkq/24e0rsrfMP9K1Tm8gx+ovP0I=;;',
        BarcodeFormat.qrCode,
      ),
    };
    tester.view
      ..physicalSize = _phone * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    for (final MapEntry<String, (String, BarcodeFormat)> kind
        in kinds.entries) {
      final Barcode barcode = _code(
        kind.value.$2,
        kind.value.$1,
        const BarcodePosition(
          topLeft: Offset(100, 100),
          topRight: Offset(200, 100),
          bottomRight: Offset(200, 200),
          bottomLeft: Offset(100, 200),
        ),
        '',
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: _boundary,
          child: MediaQuery(
            data: const MediaQueryData(
              size: _phone,
              padding: EdgeInsets.only(top: 47, bottom: 34),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: ScannerScope(
                theme: const ScannerTheme(brightness: Brightness.dark),
                child: ColoredBox(
                  color: const Color(0xFF232A33),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: BarcodeResultSheet(
                      barcode,
                      showIcon: true,
                      onScanAgain: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await _save(tester, 'kind-${kind.key}');
    }
  }, skip: _out == null);

  // The templates added in 4.0 rc.2 (page "New templates" of the designs).
  testWidgets('new templates', (WidgetTester tester) async {
    const Rect book = Rect.fromLTWH(112, 178, 166, 118);
    await shot(
      tester,
      'product',
      preview: _shelf(<Widget>[
        _paper(
          book,
          -2,
          const BarcodeView(
            '9780306406157',
            writer: BarcodeWriter(BarcodeFormat.ean13, showText: true),
            width: 150,
            height: 99,
          ),
        ),
      ]),
      template: closable(const ScannerTemplate.product()),
      barcodes: <Barcode>[
        _code(
          BarcodeFormat.ean13,
          '9780306406157',
          _corners(book.translate(0, -8), const Size(126, 70), -2),
          ']E0',
        ),
      ],
    );

    const Rect board = Rect.fromLTWH(117, 357, 156, 60);
    await shot(
      tester,
      'small',
      preview: _cool(<Widget>[
        _paper(
          board,
          -4,
          const BarcodeView(
            'SN 4F2A-9X17',
            writer: BarcodeWriter(BarcodeFormat.dataMatrix),
            width: 40,
            height: 40,
          ),
        ),
      ]),
      template: closable(const ScannerTemplate.small()),
    );

    const Rect screen = Rect.fromLTWH(100, 279, 190, 190);
    await shot(
      tester,
      'sign-in',
      preview: _warm(<Widget>[
        _paper(screen, -2, qr('https://example.com/device?code=8F3K-2QZ', 170)),
      ]),
      template: closable(const ScannerTemplate.signIn()),
    );

    const Rect pack = Rect.fromLTWH(140, 170, 112, 112);
    const String pharma = '(01)09501101530003(17)250131(10)AB12C(21)7C4K9M2';
    await shot(
      tester,
      'pharma',
      preview: _cool(<Widget>[
        _paper(
          pack,
          3,
          const BarcodeView(
            pharma,
            writer: BarcodeWriter(BarcodeFormat.dataMatrix, gs1: true),
            width: 100,
            height: 100,
          ),
        ),
      ]),
      template: closable(const ScannerTemplate.pharma()),
      barcodes: <Barcode>[
        _code(
          BarcodeFormat.dataMatrix,
          pharma,
          _corners(pack, const Size(100, 100), 3),
          ']d2',
          type: BarcodeContentType.gs1,
        ),
      ],
    );

    await shot(
      tester,
      'vin',
      preview: _cool(<Widget>[
        _paper(
          const Rect.fromLTWH(27, 258, 336, 96),
          -1,
          const BarcodeView(
            '1HGCM82633A004352',
            writer: BarcodeWriter(BarcodeFormat.code39),
            width: 320,
            height: 84,
          ),
        ),
      ]),
      template: closable(const ScannerTemplate.vin()),
      torch: true,
    );

    const Rect card = Rect.fromLTWH(75, 236, 240, 108);
    await shot(
      tester,
      'loyalty',
      preview: _warm(<Widget>[
        _paper(
          card,
          -3,
          const BarcodeView(
            '6034992144770815',
            writer: BarcodeWriter(BarcodeFormat.code128),
            width: 220,
            height: 98,
          ),
        ),
      ]),
      template: closable(const ScannerTemplate.loyalty()),
      barcodes: <Barcode>[
        _code(
          BarcodeFormat.code128,
          '6034992144770815',
          _corners(card, const Size(220, 98), -3),
          ']C0',
        ),
      ],
    );

    const Rect ticket = Rect.fromLTWH(124, 228, 144, 144);
    final Barcode ticketCode = _code(
      BarcodeFormat.qrCode,
      'TKT-2026-0042-7F3A',
      _corners(ticket, const Size(130, 130), 5),
      ']Q1',
    );
    for (final (String name, ScanVerdict verdict) in <(String, ScanVerdict)>[
      (
        'check-in-ok',
        const ScanVerdict.accept(
          title: 'Anna Petrova',
          message: 'VIP · Row 4, seat 12',
        ),
      ),
      (
        'check-in-warn',
        const ScanVerdict.warn(
          title: 'Anna Petrova',
          message: 'Already checked in at 19:42, gate 2',
        ),
      ),
      (
        'check-in-bad',
        const ScanVerdict.reject(
          title: 'Invalid ticket',
          message: 'Not for Concert Hall · 21 Nov',
        ),
      ),
    ]) {
      await shot(
        tester,
        name,
        preview: _warm(<Widget>[
          _paper(ticket, 5, qr('TKT-2026-0042-7F3A', 130)),
        ]),
        template: closable(ScannerTemplate.checkIn(check: (_) => verdict)),
        barcodes: <Barcode>[ticketCode],
      );
    }

    const Rect a = Rect.fromLTWH(40, 210, 132, 132);
    const Rect b = Rect.fromLTWH(214, 260, 132, 132);
    const Rect c = Rect.fromLTWH(118, 470, 120, 120);
    await shot(
      tester,
      'pick',
      preview: _shelf(<Widget>[
        _paper(a, -6, qr('https://flutter.dev', 116)),
        _paper(b, 4, qr('WIFI:T:WPA;S:Office;P:secret;;', 116)),
        _paper(
          c,
          -2,
          const BarcodeView(
            'TKT-2026-0117-B21C',
            writer: BarcodeWriter(BarcodeFormat.aztec),
            width: 104,
            height: 104,
          ),
        ),
      ]),
      template: closable(const ScannerTemplate.pick()),
      barcodes: <Barcode>[
        _code(
          BarcodeFormat.qrCode,
          'https://flutter.dev',
          _corners(a, const Size(116, 116), -6),
          ']Q1',
        ),
        _code(
          BarcodeFormat.qrCode,
          'WIFI:T:WPA;S:Office;P:secret;;',
          _corners(b, const Size(116, 116), 4),
          ']Q1',
        ),
        _code(
          BarcodeFormat.aztec,
          'TKT-2026-0117-B21C',
          _corners(c, const Size(104, 104), -2),
          ']z0',
        ),
      ],
    );

    const Rect label = Rect.fromLTWH(47, 150, 296, 104);
    await shot(
      tester,
      'logistics',
      preview: _shelf(<Widget>[
        _paper(
          label,
          0,
          const BarcodeView(
            '(00)106141412345678908',
            writer: BarcodeWriter(BarcodeFormat.code128, gs1: true),
            width: 280,
            height: 88,
          ),
        ),
      ]),
      template: closable(
        ScannerTemplate.logistics(title: 'Pallet 3', onDone: (_) {}),
      ),
      torch: true,
      barcodes: <Barcode>[
        _code(
          BarcodeFormat.code128,
          '(00)106141412345678908',
          _corners(label, const Size(280, 88), 0),
          ']C1',
          type: BarcodeContentType.gs1,
        ),
        _code(
          BarcodeFormat.code128,
          '(02)09501101530003(37)24(10)LOT-0423',
          _corners(label.translate(0, 400), const Size(280, 60), 0),
          ']C1',
          type: BarcodeContentType.gs1,
        ),
      ],
    );

    const Rect loose = Rect.fromLTWH(196, 438, 150, 150);
    await shot(
      tester,
      'fullscreen',
      preview: _warm(<Widget>[
        _paper(loose, 8, qr('https://flutter.dev', 132)),
      ]),
      template: closable(const ScannerTemplate.fullscreen()),
    );
    await shot(
      tester,
      'fullscreen-locked',
      preview: _warm(<Widget>[
        _paper(loose, 8, qr('https://flutter.dev', 132)),
      ]),
      template: closable(const ScannerTemplate.fullscreen()),
      barcodes: <Barcode>[
        _code(
          BarcodeFormat.qrCode,
          'https://flutter.dev',
          _corners(loose, const Size(132, 132), 8),
          ']Q1',
        ),
      ],
    );

    await shot(
      tester,
      'kiosk',
      preview: _warm(<Widget>[
        _paper(
          const Rect.fromLTWH(275, 320, 180, 180),
          -6,
          qr('TKT-2026-0042-7F3A', 160),
        ),
      ]),
      template: const ScannerTemplate.kiosk(),
      size: const Size(1180, 820),
      wait: const Duration(milliseconds: 400),
    );
  }, skip: _out == null);

  testWidgets('states', (WidgetTester tester) async {
    await shot(
      tester,
      'state-starting',
      preview: searching,
      template: closable(const ScannerTemplate.minimal()),
      start: false,
    );
    await shot(
      tester,
      'state-permission',
      preview: searching,
      template: closable(const ScannerTemplate.minimal()),
      theme: const ScannerTheme(brightness: Brightness.dark),
      openError: const CameraPermissionException(),
    );
    await shot(
      tester,
      'state-unavailable',
      preview: searching,
      template: closable(const ScannerTemplate.minimal()),
      openError: const CameraNotFoundException(),
    );
  }, skip: _out == null);
}
