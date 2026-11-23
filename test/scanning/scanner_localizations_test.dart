// The scanner's texts: the built-in translations follow the app's locale
// with no setup, English otherwise; a ScannerScope's texts and a registered
// delegate win; plurals and dates follow the language; every ARB file has
// every text.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;

import 'fake_camera.dart';

const Size _phone = Size(390, 844);

final Barcode _hello = Barcode(
  format: BarcodeFormat.qrCode,
  text: 'Hello',
  bytes: Uint8List.fromList(utf8.encode('Hello')),
  position: const BarcodePosition(
    topLeft: Offset(150, 330),
    topRight: Offset(240, 330),
    bottomRight: Offset(240, 420),
    bottomLeft: Offset(150, 420),
  ),
  symbologyIdentifier: ']Q1',
);

/// [home] in an app whose locale is [locale], without the scanner's
/// delegate unless [delegates] lists it.
Widget _app(
  Locale locale,
  Widget home, {
  List<LocalizationsDelegate<Object>> delegates =
      const <LocalizationsDelegate<Object>>[],
}) => MediaQuery(
  data: const MediaQueryData(size: _phone),
  child: WidgetsApp(
    color: const Color(0xFF000000),
    locale: locale,
    supportedLocales: <Locale>[locale],
    localizationsDelegates: delegates,
    builder: (BuildContext context, Widget? _) => home,
  ),
);

/// The texts [ScannerLocalizations.of] gives under [app].
Future<ScannerLocalizations> _textsIn(
  WidgetTester tester,
  Widget Function(Widget child) app,
) async {
  late ScannerLocalizations texts;
  await tester.pumpWidget(
    app(
      Builder(
        builder: (BuildContext context) {
          texts = ScannerLocalizations.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return texts;
}

void main() {
  group('no setup', () {
    setUp(() {
      ScannerControllerDebug.cameraFactory = () =>
          FakeCamera(transform: const FrameTransform(_phone));
    });
    tearDown(() => ScannerControllerDebug.cameraFactory = null);

    testWidgets('a Russian app shows the scanner in Russian', (
      WidgetTester tester,
    ) async {
      tester.view
        ..physicalSize = _phone
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          const Locale('ru'),
          const BarcodeScanner(template: ScannerTemplate.payment()),
        ),
      );
      await tester.pump();
      expect(find.text('Оплата по QR'), findsOneWidget);
      expect(find.text('Pay with QR'), findsNothing);

      await tester.pumpWidget(
        _app(
          const Locale('ru', 'RU'),
          Align(
            alignment: Alignment.bottomCenter,
            child: BarcodeResultSheet(_hello, onScanAgain: () {}),
          ),
        ),
      );
      expect(find.text('Сканировать снова'), findsOneWidget);
      expect(find.text('Скопировать'), findsOneWidget);
    });

    testWidgets('another language is English', (WidgetTester tester) async {
      final ScannerLocalizations texts = await _textsIn(
        tester,
        (Widget child) => _app(const Locale('ja'), child),
      );
      expect(texts, isA<ScannerLocalizationsEn>());
      expect(texts.scanAgain, 'Scan again');
    });

    testWidgets('no Localizations at all is English', (
      WidgetTester tester,
    ) async {
      final ScannerLocalizations texts = await _textsIn(
        tester,
        (Widget child) =>
            Directionality(textDirection: TextDirection.ltr, child: child),
      );
      expect(texts.scanAgain, 'Scan again');
    });

    testWidgets('one instance per locale', (WidgetTester tester) async {
      final ScannerLocalizations first = await _textsIn(
        tester,
        (Widget child) => _app(const Locale('ru'), child),
      );
      final ScannerLocalizations second = await _textsIn(
        tester,
        (Widget child) => _app(const Locale('ru'), child),
      );
      expect(identical(first, second), isTrue);
    });
  });

  group('the language', () {
    late ScannerLocalizations ru;
    late ScannerLocalizations en;

    testWidgets('Russian plurals', (WidgetTester tester) async {
      ru = await _textsIn(tester, (Widget c) => _app(const Locale('ru'), c));
      expect(ru.itemCount(1), '1 элемент');
      expect(ru.itemCount(2), '2 элемента');
      expect(ru.itemCount(5), '5 элементов');
      expect(ru.itemCount(11), '11 элементов');
      expect(ru.itemCount(21), '21 элемент');
      expect(ru.codesInView(3), '3 кода');
      expect(ru.byteCount(120), '120 байт');
    });

    testWidgets('English plurals', (WidgetTester tester) async {
      en = await _textsIn(tester, (Widget c) => _app(const Locale('en'), c));
      expect(en.itemCount(1), '1 item');
      expect(en.itemCount(3), '3 items');
      expect(en.codesInView(1), '1 code');
      expect(en.checkedIn(12), '12 checked in');
      expect(en.flightOf(1, 2), 'Flight 1 of 2');
    });

    testWidgets('dates in the language', (WidgetTester tester) async {
      ru = await _textsIn(tester, (Widget c) => _app(const Locale('ru'), c));
      en = await _textsIn(tester, (Widget c) => _app(const Locale('en'), c));
      final DateTime born = DateTime(1977, 8, 31);
      final DateTime flight = DateTime(2026, 11, 14);
      expect(en.fullDate(born), 'Aug 31, 1977');
      expect(en.dayAndMonth(born), 'Aug 31');
      expect(en.fullDate(flight), 'Nov 14, 2026');
      expect(en.dayAndMonth(flight), 'Nov 14');
      expect(ru.fullDate(born), '31 авг. 1977');
      expect(ru.dayAndMonth(born), '31 авг.');
      expect(ru.fullDate(flight), '14 нояб. 2026');
      expect(ru.dayAndMonth(flight), '14 нояб.');
      for (int month = 1; month <= 12; month++) {
        expect(en.monthShort(_month(month)), isNotEmpty);
        expect(ru.monthShort(_month(month)), isNotEmpty);
      }
    });

    test('a language without date data has dates', () {
      final ScannerLocalizations xx = _Unknown();
      expect(xx.fullDate(DateTime(1977, 8, 31)), 'Aug 31, 1977');
      expect(xx.itemCount(2), '2 items');
    });

    testWidgets('enums and amounts', (WidgetTester tester) async {
      ru = await _textsIn(tester, (Widget c) => _app(const Locale('ru'), c));
      en = await _textsIn(tester, (Widget c) => _app(const Locale('en'), c));
      for (final WifiSecurity security in WifiSecurity.values) {
        expect(en.wifiSecurityOf(security), isNotEmpty);
      }
      expect(en.wifiSecurityOf(WifiSecurity.none), 'Open network');
      expect(en.wifiSecurityOf(WifiSecurity.unknown), 'Secured');
      expect(ru.wifiSecurityOf(WifiSecurity.none), 'Открытая сеть');
      expect(en.vinRegionOf(VinRegion.northAmerica), 'North America');
      expect(ru.vinRegionOf(VinRegion.northAmerica), 'Северная Америка');
      expect(en.amountOf('12.50', 'EUR'), '12.50 EUR');
      expect(en.amountOf('12.50', null), '12.50');
      expect(en.amountOf(null, 'EUR'), 'Any amount');
      expect(ru.amountOf(null, null), 'Любая сумма');
    });
  });

  group('the app chooses', () {
    testWidgets('a subclass in a scope changes one text and keeps the rest', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Locale('en'),
          ScannerScope(
            texts: _MyTexts(),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: BarcodeResultSheet(_hello, onScanAgain: () {}),
            ),
          ),
        ),
      );
      expect(find.text('Ещё раз'), findsOneWidget);
      expect(find.text('Сканировать снова'), findsNothing);
      expect(find.text('Скопировать'), findsOneWidget);
    });

    testWidgets('a registered delegate is used', (WidgetTester tester) async {
      final ScannerLocalizations texts = await _textsIn(
        tester,
        (Widget child) => _app(
          const Locale('ru'),
          child,
          delegates: const <LocalizationsDelegate<Object>>[_MyDelegate()],
        ),
      );
      expect(texts.scanAgain, 'Ещё раз');

      final ScannerLocalizations package = await _textsIn(
        tester,
        (Widget child) => _app(
          const Locale('ru'),
          child,
          delegates: const <LocalizationsDelegate<Object>>[
            ScannerLocalizations.delegate,
          ],
        ),
      );
      expect(package, isA<ScannerLocalizationsRu>());
      expect(package.scanAgain, 'Сканировать снова');
      expect(ScannerLocalizations.supportedLocales, <Locale>[
        const Locale('en'),
        const Locale('ru'),
      ]);
      expect(
        ScannerLocalizations.delegate.isSupported(const Locale('ru')),
        isTrue,
      );
    });
  });

  group('ARB files', () {
    Map<String, Object?> read(File file) =>
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    Set<String> messages(Map<String, Object?> arb) =>
        arb.keys.where((String k) => !k.startsWith('@')).toSet();

    final List<File> arbs =
        Directory('lib/l10n')
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.endsWith('.arb'))
            .toList()
          ..sort((File a, File b) => a.path.compareTo(b.path));
    final Map<String, Object?> template = read(File('lib/l10n/scanner_en.arb'));

    test('every language has every text of the English one', () {
      expect(arbs.length, greaterThanOrEqualTo(2));
      for (final File file in arbs) {
        final Set<String> keys = messages(read(file));
        expect(
          messages(template).difference(keys),
          isEmpty,
          reason: '${file.path} is missing these texts',
        );
        expect(
          keys.difference(messages(template)),
          isEmpty,
          reason: '${file.path} has texts the English one does not',
        );
      }
    });

    test('every text is described for translators', () {
      for (final String key in messages(template)) {
        final Object? meta = template['@$key'];
        expect(
          meta is Map && (meta['description'] as String? ?? '').isNotEmpty,
          isTrue,
          reason: '@$key needs a description',
        );
      }
    });

    test('the generated code is up to date (make l10n)', () {
      final String generated = File(
        'lib/src/scanning/l10n/scanner_localizations.dart',
      ).readAsStringSync();
      for (final String key in messages(template)) {
        expect(
          RegExp('String (get $key;|$key\\()').hasMatch(generated),
          isTrue,
          reason: '$key is not in the generated code',
        );
      }
      for (final File file in arbs) {
        final String locale = read(file)['@@locale']! as String;
        expect(generated, contains("Locale('$locale')"));
      }
    });
  });
}

class _MyTexts extends ScannerLocalizationsRu {
  @override
  String get scanAgain => 'Ещё раз';
}

class _MyDelegate extends LocalizationsDelegate<ScannerLocalizations> {
  const _MyDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<ScannerLocalizations> load(Locale locale) =>
      SynchronousFuture<ScannerLocalizations>(_MyTexts());

  @override
  bool shouldReload(_MyDelegate old) => false;
}

String _month(int month) => const <String>[
  'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
][month - 1];

class _Unknown extends ScannerLocalizationsEn {
  _Unknown() : super('xx');
}
