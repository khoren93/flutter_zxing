// What the result sheet says about a code: who a link to a service leads
// to, texts from ScannerLocalizations, GS1 titles.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

Barcode _barcode(
  String text, {
  BarcodeFormat format = BarcodeFormat.qrCode,
  String id = ']Q1',
  BarcodeContentType type = BarcodeContentType.text,
}) => Barcode(
  format: format,
  text: text,
  bytes: Uint8List.fromList(utf8.encode(text)),
  position: const BarcodePosition(
    topLeft: Offset(150, 330),
    topRight: Offset(240, 330),
    bottomRight: Offset(240, 420),
    bottomLeft: Offset(150, 420),
  ),
  symbologyIdentifier: id,
  contentType: type,
);

Future<void> _show(
  WidgetTester tester,
  Barcode barcode, {
  ScannerLocalizations? texts,
}) => tester.pumpWidget(
  MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ScannerScope(
        texts: texts,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SingleChildScrollView(
            child: BarcodeResultSheet(barcode, onScanAgain: () {}),
          ),
        ),
      ),
    ),
  ),
);

/// The title of the sheet: the text under the kind.
String _title(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).elementAt(1).data!;

void main() {
  group('a link to a service', () {
    Future<void> expectLink(
      WidgetTester tester,
      String link,
      String title, {
      String? payload,
    }) async {
      await _show(tester, _barcode(link));
      expect(_title(tester), title, reason: link);
      if (payload != null) {
        expect(find.text(payload), findsOneWidget, reason: link);
      }
    }

    testWidgets('is named after a profile only for a profile', (
      WidgetTester tester,
    ) async {
      await expectLink(
        tester,
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'youtube.com',
        payload: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      await expectLink(tester, 'https://youtu.be/dQw4w9WgXcQ', 'youtu.be');
      await expectLink(
        tester,
        'https://www.youtube.com/@flutterdev',
        '@flutterdev',
      );
      await expectLink(
        tester,
        'https://www.instagram.com/p/C0abc/',
        'instagram.com',
      );
      await expectLink(
        tester,
        'https://www.instagram.com/reel/C0abc/',
        'instagram.com',
      );
      await expectLink(
        tester,
        'https://www.instagram.com/flutter.dev',
        '@flutter.dev',
      );
      await expectLink(tester, 'https://t.me/+AbCdEf123', 't.me');
      await expectLink(tester, 'https://t.me/joinchat/AbCdEf', 't.me');
      await expectLink(tester, 'https://t.me/flutterdev', '@flutterdev');
      await expectLink(
        tester,
        'https://www.facebook.com/profile.php?id=100001',
        'facebook.com',
        payload: 'https://www.facebook.com/profile.php?id=100001',
      );
      await expectLink(
        tester,
        'https://x.com/flutterdev/status/1',
        '@flutterdev',
      );
      await expectLink(
        tester,
        'https://discord.com/channels/1/2',
        'discord.com',
      );
      await expectLink(tester, 'https://discord.gg/abcDEF', 'abcDEF');
      await expectLink(
        tester,
        'https://www.reddit.com/r/FlutterDev',
        'r/FlutterDev',
      );
      await expectLink(
        tester,
        'https://www.reddit.com/comments/abc',
        'reddit.com',
      );
    });

    testWidgets('WhatsApp: a number, never a path', (
      WidgetTester tester,
    ) async {
      await expectLink(
        tester,
        'https://wa.me/37491234567?text=Hi',
        '+37491234567',
        payload: 'wa.me/37491234567',
      );
      expect(find.text('Hi'), findsOneWidget);
      await expectLink(
        tester,
        'https://api.whatsapp.com/send?phone=37491234567&text=Hi',
        '+37491234567',
        payload: 'api.whatsapp.com/send',
      );
      await expectLink(
        tester,
        'https://chat.whatsapp.com/InviteCode123',
        'chat.whatsapp.com',
      );
    });

    testWidgets('a link that leads on shows where', (
      WidgetTester tester,
    ) async {
      const String redirect =
          'https://www.youtube.com/redirect?q=https://evil.example/login';
      await expectLink(tester, redirect, 'youtube.com', payload: redirect);
      const String facebook =
          'https://l.facebook.com/l.php?u=https%3A%2F%2Fevil.example';
      await expectLink(tester, facebook, 'l.facebook.com', payload: facebook);
    });
  });
  group('texts come from ScannerLocalizations', () {
    final ScannerLocalizations de = _German();

    testWidgets('the security of a Wi‑Fi network', (WidgetTester tester) async {
      await _show(
        tester,
        _barcode('WIFI:S:Corp;T:WPA2-EAP;P:secret12;;'),
        texts: de,
      );
      expect(find.text('Unternehmen · Passwort im Code'), findsOneWidget);
      expect(find.textContaining('ENTERPRISE'), findsNothing);
      await _show(tester, _barcode('WIFI:S:Lab;T:XYZ;P:secret12;;'), texts: de);
      expect(find.text('Passwort im Code'), findsOneWidget);
      expect(find.textContaining('UNKNOWN'), findsNothing);
      await _show(tester, _barcode('WIFI:S:Lab;T:XYZ;;'), texts: de);
      expect(find.textContaining('UNKNOWN'), findsNothing);
    });

    testWidgets('the date of an event', (WidgetTester tester) async {
      await _show(
        tester,
        _barcode(
          'BEGIN:VEVENT\nSUMMARY:Launch\nDTSTART:20261114T093000\n'
          'DTEND:20261115T110000\nEND:VEVENT',
        ),
        texts: de,
      );
      expect(find.text('14.11.2026 09:30 – 15.11.2026 11:00'), findsOneWidget);
    });
  });
  group('GS1 without a GTIN or SSCC', () {
    Barcode gs1(String text) => _barcode(
      text,
      format: BarcodeFormat.dataMatrix,
      id: ']d2',
      type: BarcodeContentType.gs1,
    );

    testWidgets('the batch is the title, once', (WidgetTester tester) async {
      await _show(tester, gs1('(10)ABC(21)123'));
      expect(_title(tester), 'ABC');
      expect(find.text('ABC'), findsOneWidget);
      expect(find.text('GS1 · BATCH'), findsOneWidget);
      expect(find.text('123'), findsOneWidget);
    });

    testWidgets('a date is not the title', (WidgetTester tester) async {
      await _show(tester, gs1('(17)261231(10)X'));
      expect(_title(tester), 'X');
      expect(find.text('261231'), findsNothing);
      expect(find.text('Dec 31, 2026'), findsOneWidget);
    });

    testWidgets('an element without a name comes first', (
      WidgetTester tester,
    ) async {
      await _show(tester, gs1('(10)AB(240)X-1'));
      expect(_title(tester), 'X-1');
      expect(find.text('GS1 · (240)'), findsOneWidget);
      expect(find.text('X-1'), findsOneWidget);
      expect(find.text('AB'), findsOneWidget);
    });
  });
  testWidgets('screen readers announce the result', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _show(tester, _barcode('https://www.example.com/a'));
    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel('Link: example.com'),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });
}

class _German extends ScannerLocalizationsEn {
  _German() : super('de');

  @override
  String get wifiPassword => 'Passwort im Code';

  @override
  String wifiSecurity(String security) => switch (security) {
    'none' => 'Offenes Netz',
    'enterprise' => 'Unternehmen',
    _ => security.toUpperCase(),
  };

  // Dates as 14.11.2026: the month as its number.
  @override
  String monthShort(String month) => '${_months.indexOf(month) + 1}';

  @override
  String dayMonthYear(int day, String month, int year) => '$day.$month.$year';
}

const List<String> _months = <String>[
  'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];
