// What the parsers accept and the builders write, held to the specification
// of each format. Every case that a parser accepts must build again.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

List<String> _messages(BarcodeContent c) =>
    c.validate().map((ContentIssue i) => i.message).toList();

void main() {
  group('contact web addresses', () {
    test('a contact keeps http and https addresses only', () {
      for (final String text in <String>[
        'BEGIN:VCARD\nVERSION:3.0\nFN:A\nURL:javascript:alert(1)\nEND:VCARD',
        'MECARD:N:A;URL:file:///etc/passwd;;',
        r'MECARD:N:A;URL:intent://scan/#Intent\;end;;',
      ]) {
        final BarcodeContent c = BarcodeContent.parseText(text);
        expect(c, isA<ContactContent>(), reason: text);
        expect((c as ContactContent).urls, isEmpty, reason: text);
      }
      final ContactContent c =
          BarcodeContent.parseText(
                'BEGIN:VCARD\nVERSION:3.0\nFN:A\nURL:example.com/a\nEND:VCARD',
              )
              as ContactContent;
      expect(c.urls, <Uri>[Uri.parse('https://example.com/a')]);
    });

    test('validate reports an address that is no web address', () {
      final ContactContent c = ContactContent(
        name: 'A',
        urls: <Uri>[Uri.parse('javascript:alert(1)')],
      );
      expect(
        _messages(c),
        contains('Only http and https addresses are web links'),
      );
      expect(() => c.toPayload(), throwsArgumentError);
    });
  });

  group('addresses that are no address even with https://', () {
    test('validate reports them instead of throwing', () {
      for (final String text in <String>['a@b@c.com', 'john@@example.com']) {
        final UrlContent url = UrlContent(Uri.parse(text));
        expect(url.validate(), hasLength(1), reason: text);
        expect(url.uri, isNull, reason: text);
        expect(() => url.toPayload(), throwsArgumentError, reason: text);

        final ContactContent contact = ContactContent(
          name: 'A',
          urls: <Uri>[Uri.parse(text)],
        );
        expect(contact.validate(), hasLength(1), reason: text);
        expect(() => contact.toPayload(), throwsArgumentError, reason: text);
      }
    });
  });

  group('numbers and addresses parse only when they build', () {
    test('tel: with pauses and an extension (RFC 3966 §5.1.5) has a link', () {
      for (final String text in <String>[
        'tel:+12125551234,,123',
        'tel:+1-212-555-1234;ext=12',
        'tel:+12125551234;123',
      ]) {
        final BarcodeContent c = BarcodeContent.parseText(text);
        expect(c, isA<PhoneContent>(), reason: text);
        expect(c.validate(), isEmpty, reason: text);
        expect(c.uri, isNotNull, reason: text);
        final String payload = c.toPayload();
        expect(
          BarcodeContent.parseText(payload).toPayload(),
          payload,
          reason: text,
        );
      }
    });

    test('letters are not in RFC 3966: tel:1-800-FLOWERS is text', () {
      expect(BarcodeContent.parseText('tel:1-800-FLOWERS'), isA<TextContent>());
    });

    test('an extension is for calls, not for SMS', () {
      expect(
        const SmsContent(number: '+12125551234;ext=1').validate(),
        isNotEmpty,
      );
    });

    test('SMSTO: holds the numbers sms: does', () {
      expect(BarcodeContent.parseText('SMSTO:hello world'), isA<TextContent>());
      expect(
        BarcodeContent.parseText('SMSTO:+1555,+1666:Hi'),
        const SmsContent(number: '+1555,+1666', message: 'Hi'),
      );
    });

    test('MATMSG: holds the address mailto: does (RFC 6068)', () {
      expect(
        BarcodeContent.parseText('MATMSG:TO:not an email;;'),
        isA<TextContent>(),
      );
      expect(
        BarcodeContent.parseText('MATMSG:TO:;SUB:Hi;;'),
        const EmailContent(address: '', subject: 'Hi'),
      );
    });

    test('otpauth: digits are 6 to 8 (Key Uri Format: 6 or 8)', () {
      const String uri = 'otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&digits=';
      expect(BarcodeContent.parseText('${uri}10'), isA<TextContent>());
      expect(BarcodeContent.parseText('${uri}4'), isA<TextContent>());
      final BarcodeContent eight = BarcodeContent.parseText('${uri}8');
      expect(eight, isA<OtpContent>());
      expect(eight.uri, isNotNull);
    });
  });

  group('payment checksums: a wrong one is text', () {
    const String iban = 'DE89370400440532013000';

    test('EPC: line 10 is an ISO 11649 reference (EPC069-12)', () {
      const String head = 'BCD\n002\n1\nSCT\n\nName\n$iban\nEUR1\n\n';
      expect(BarcodeContent.parseText('${head}RF00123'), isA<TextContent>());
      final BarcodeContent ok = BarcodeContent.parseText(
        '${head}RF18539007547034',
      );
      expect(ok, isA<EpcPaymentContent>());
      expect(BarcodeContent.parseText(ok.toPayload()), ok);
    });

    test('SPAYD: CRC32 of the canonical form, when present (SPAYD 1.0)', () {
      const String fields =
          'ACC:CZ6508000000192000145399*AM:450.00*CC:CZK*MSG:PLATBA';
      expect(
        BarcodeContent.parseText('SPD*1.0*$fields*CRC32:C0E0909C'),
        isA<SpaydPaymentContent>(),
      );
      expect(
        BarcodeContent.parseText(
          'SPD*1.0*CRC32:C0E0909C*MSG:PLATBA*CC:CZK*'
          'AM:450.00*ACC:CZ6508000000192000145399',
        ),
        isA<SpaydPaymentContent>(),
      );
      expect(
        BarcodeContent.parseText('SPD*1.0*$fields*CRC32:00000000'),
        isA<TextContent>(),
      );
      expect(
        BarcodeContent.parseText('SPD*1.0*$fields'),
        isA<SpaydPaymentContent>(),
      );
    });
  });

  group('EMVCo merchant-presented QR', () {
    Map<String, String> fields(String amount) => <String, String>{
      '00': '01',
      '26': '0011example.kw',
      '52': '0000',
      '53': '414',
      '54': amount,
      '58': 'KW',
      '59': 'Shop',
      '60': 'Kuwait',
    };

    test('amount (54) has the places of its currency (EMV QRCPS MPM)', () {
      for (final String amount in <String>['1.500', '1.', '12', '0.25']) {
        final EmvPaymentContent c = EmvPaymentContent(fields(amount));
        expect(c.validate(), isEmpty, reason: amount);
        expect(BarcodeContent.parseText(c.toPayload()), c, reason: amount);
      }
      for (final String amount in <String>['.', '1,5', '1.2.3', '-1']) {
        expect(
          EmvPaymentContent(fields(amount)).validate(),
          isNotEmpty,
          reason: amount,
        );
      }
    });

    test('merchant name (59) and city (60) are ASCII (ans)', () {
      final EmvPaymentContent accents = EmvPaymentContent.pix(
        key: 'a@b.com',
        name: 'Fulânô',
        city: 'São Paulo',
      );
      expect(accents.validate(), hasLength(2));
      expect(
        EmvPaymentContent.pix(
          key: 'a@b.com',
          name: 'Fulano',
          city: 'Sao Paulo',
        ).validate(),
        isEmpty,
      );
    });
  });

  group('charsets the data names', () {
    Barcode barcode(String text, List<int> bytes) => Barcode(
      format: BarcodeFormat.qrCode,
      text: text,
      bytes: Uint8List.fromList(bytes),
      position: const BarcodePosition(
        topLeft: Offset.zero,
        topRight: Offset.zero,
        bottomRight: Offset.zero,
        bottomLeft: Offset.zero,
      ),
    );

    test('EPC line 3: 1 is UTF-8 (EPC069-12)', () {
      const String text =
          'BCD\n002\n1\nSCT\n\nZoë Müller\nDE89370400440532013000\nEUR1';
      final List<int> bytes = utf8.encode(text);
      // A reader without an ECI that guessed Latin-1.
      final EpcPaymentContent epc =
          barcode(latin1.decode(bytes), bytes).content as EpcPaymentContent;
      expect(epc.name, 'Zoë Müller');
    });

    test('EPC line 3: 2 is ISO 8859-1 (EPC069-12)', () {
      const String text =
          'BCD\n002\n2\nSCT\n\nZoë Müller\nDE89370400440532013000\nEUR1';
      final List<int> bytes = latin1.encode(text);
      // A reader that guessed UTF-8 and replaced the bytes it could not read.
      final EpcPaymentContent epc =
          barcode(utf8.decode(bytes, allowMalformed: true), bytes).content
              as EpcPaymentContent;
      expect(epc.name, 'Zoë Müller');
    });

    test('vCard 2.1 quoted-printable in CHARSET=WINDOWS-1251 (2.1.5)', () {
      final ContactContent c =
          BarcodeContent.parseText(
                'BEGIN:VCARD\nVERSION:2.1\n'
                'N;CHARSET=WINDOWS-1251;ENCODING=QUOTED-PRINTABLE:=C8=E2=E0=ED\n'
                'END:VCARD',
              )
              as ContactContent;
      expect(c.name, 'Иван');
    });
  });

  test('sms: with &body= (iOS form, not RFC 5724) is an SMS', () {
    expect(
      BarcodeContent.parseText('sms:+15105550101&body=hello%20there'),
      const SmsContent(number: '+15105550101', message: 'hello there'),
    );
    expect(
      BarcodeContent.parseText('sms:+15105550101?body=hello'),
      const SmsContent(number: '+15105550101', message: 'hello'),
    );
  });
}
