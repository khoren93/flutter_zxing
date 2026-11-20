// What the result sheet says about a code: who a link to a service leads
// to, texts from ScannerStrings, GS1 titles.
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  ScannerStrings strings = const ScannerStrings(),
}) => tester.pumpWidget(
  MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ScannerScope(
        strings: strings,
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
}
