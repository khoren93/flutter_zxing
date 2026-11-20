// Payloads that must not hang, throw, shift fields or pass as something else.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

const String _iban = 'DE89370400440532013000';

void main() {
  group('EMVCo lengths', () {
    test('a signed length is text, not a hang or a throw', () {
      expect(BarcodeContent.parseText('00020100-4xxxxxxx'), isA<TextContent>());
      expect(BarcodeContent.parseText('00020159-1xxxxxxx'), isA<TextContent>());
    });

    test('a merchant account is required', () {
      const EmvPaymentContent c = EmvPaymentContent(<String, String>{
        '00': '01',
        '52': '0000',
        '53': '986',
        '58': 'BR',
        '59': 'Shop',
        '60': 'Rio',
      });
      expect(
        c.validate().map((ContentIssue i) => i.message),
        contains('A merchant account (02 to 51) is missing'),
      );
    });
  });

  group('bookmarks', () {
    test('hold web addresses only', () {
      for (final String text in <String>[
        'MEBKM:TITLE:x;URL:javascript:alert(1);;',
        'URLTO:x:file:///etc/passwd',
      ]) {
        expect(
          BarcodeContent.parseText(text),
          isA<TextContent>(),
          reason: text,
        );
      }
      expect(
        BarcodeContent.parseText('MEBKM:TITLE:x;URL:https://pub.dev;;'),
        isA<UrlContent>(),
      );
    });
  });

  group('services', () {
    Uri u(String s) => Uri.parse(s);

    test('look-alike domains are no service', () {
      expect(UrlContent(u('https://google.evil.com/maps/x')).service, isNull);
      expect(UrlContent(u('https://maps.yandex.evil.com/')).service, isNull);
    });

    test('real domains stay recognised', () {
      for (final String host in <String>[
        'google.com',
        'google.de',
        'google.co.uk',
      ]) {
        expect(
          UrlContent(u('https://$host/maps/x')).service,
          LinkService.googleMaps,
          reason: host,
        );
      }
      expect(
        UrlContent(u('https://yandex.com.tr/maps/1')).service,
        LinkService.yandexMaps,
      );
    });

    test('an App Store id is a number', () {
      expect(
        () => LinkService.appStore.link('123/../../evil'),
        throwsArgumentError,
      );
      expect(
        LinkService.appStore.link('id123').url.toString(),
        'https://apps.apple.com/app/id123',
      );
    });
  });

  group('line-based payments', () {
    test('EPC fields cannot hold a line break', () {
      for (final EpcPaymentContent c in <EpcPaymentContent>[
        const EpcPaymentContent(name: 'ACME\nGmbH', iban: _iban),
        const EpcPaymentContent(name: 'A', iban: _iban, message: 'one\ntwo'),
        const EpcPaymentContent(name: 'A', iban: _iban, information: 'a\rb'),
      ]) {
        expect(c.validate(), isNotEmpty);
      }
    });

    test('an RF reference is written in capitals', () {
      const EpcPaymentContent c = EpcPaymentContent(
        name: 'A',
        iban: _iban,
        creditorReference: 'rf18539007547034',
      );
      expect(c.toPayload(), contains('RF18539007547034'));
    });

    test('a ГОСТ extra cannot add a field', () {
      const GostPaymentContent c = GostPaymentContent(
        name: 'ООО',
        personalAccount: '40702810000000000001',
        bankName: 'Банк',
        bic: '044525225',
        correspondentAccount: '30101810400000000225',
        extra: <String, String>{'UIN': 'x|Sum=999999', 'CBC': 'ok'},
      );
      expect(
        c.validate().map((ContentIssue i) => i.message),
        contains('Values cannot contain |'),
      );
    });
  });

  group('dates', () {
    test('an impossible SPAYD date is no date', () {
      final BarcodeContent c = BarcodeContent.parseText(
        'SPD*1.0*ACC:CZ5855000000001265098001*DT:20260231',
      );
      expect((c as SpaydPaymentContent).dueDate, isNull);
    });

    test('an impossible event date is no event', () {
      expect(
        BarcodeContent.parseText(
          'BEGIN:VEVENT\nSUMMARY:x\nDTSTART:20260231T100000\nEND:VEVENT',
        ),
        isA<TextContent>(),
      );
    });
  });

  test('AAMVA names and streets may hold ANSI', () {
    final BarcodeContent c = BarcodeContent.parseText(
      '@\n\x1e\rANSI 636014040002DL00410278ZC03190024DLDAQD1234567\n'
      'DCSLANSI \nDACHANSI \nDAG12 KANSI ST\n',
    );
    final DriverLicenseContent license = c as DriverLicenseContent;
    expect(license.lastName, 'LANSI');
    expect(license.firstName, 'HANSI');
    expect(license.street, '12 KANSI ST');
  });

  group('crypto', () {
    test('an unknown required parameter voids a BIP 21 URI', () {
      expect(
        BarcodeContent.parseText(
          'bitcoin:175tWpb8K1S7NmH4Zx6rewF9WQrcZv245W?req-unknown=50',
        ),
        isA<TextContent>(),
      );
    });

    test('another EIP-681 request type is no payment', () {
      expect(
        BarcodeContent.parseText('ethereum:foo-0xabc'),
        isA<TextContent>(),
      );
    });
  });

  group('sentences stay text', () {
    for (final String text in <String>[
      'Facetime: tomorrow at 5',
      'Tel: call me after 5pm',
      'SMS: your code is ready',
      'SMTP: server down',
      'mailto: nobody here',
    ]) {
      test(text, () {
        expect(BarcodeContent.parseText(text), isA<TextContent>());
      });
    }

    test('real targets still parse', () {
      expect(
        BarcodeContent.parseText('tel:+1 (201) 555-0123'),
        isA<PhoneContent>(),
      );
      expect(BarcodeContent.parseText('tel:*100#'), isA<PhoneContent>());
      expect(BarcodeContent.parseText('facetime:a@b.org'), isA<PhoneContent>());
      expect(
        BarcodeContent.parseText('sms:+12125551234?body=Hi'),
        isA<SmsContent>(),
      );
      expect(
        BarcodeContent.parseText('mailto:a@b.org,c@d.org'),
        isA<EmailContent>(),
      );
      expect(
        BarcodeContent.parseText('mailto:?subject=Hi'),
        isA<EmailContent>(),
      );
    });
  });

  test('a QR-bill holds Latin characters only', () {
    const SwissAddress address = SwissAddress(
      name: 'Иван 😀',
      postalCode: '8000',
      town: 'Zürich',
      country: 'CH',
    );
    const SwissQrBillContent c = SwissQrBillContent(
      iban: 'CH4431999123000889012',
      creditor: address,
      message: 'one\ntwo',
    );
    final List<String> fields = <String>[
      for (final ContentIssue i in c.validate()) i.field,
    ];
    expect(fields, containsAll(<String>['creditor', 'message']));
  });

  test('parsed lists and maps cannot be changed', () {
    final ContactContent contact =
        BarcodeContent.parseText('MECARD:N:Owen,Sean;TEL:+1212;;')
            as ContactContent;
    expect(() => contact.phones.add('1'), throwsUnsupportedError);
    final EmvPaymentContent pix =
        BarcodeContent.parseText(
              EmvPaymentContent.pix(
                key: 'a@example.com',
                name: 'Shop',
                city: 'Rio',
              ).toPayload(),
            )
            as EmvPaymentContent;
    expect(() => pix.fields['54'] = '1', throwsUnsupportedError);
    expect(() => pix.template('26')['01'] = 'x', throwsUnsupportedError);
    expect(
      () => EmvPaymentContent.pix(
        key: 'a@example.com',
        name: 'S',
        city: 'R',
      ).fields['54'] = '1',
      throwsUnsupportedError,
    );
  });
}
