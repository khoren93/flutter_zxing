// BarcodeContent parsing. Payloads marked "sample" are the texts of real
// barcodes in zxing-cpp's test samples (third_party/zxing-cpp/test/samples).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/content/gs1.dart';

const BarcodePosition _nowhere = BarcodePosition(
  topLeft: Offset.zero,
  topRight: Offset.zero,
  bottomRight: Offset.zero,
  bottomLeft: Offset.zero,
);

Barcode _barcode(
  String text, {
  BarcodeContentType type = BarcodeContentType.text,
  List<int>? bytes,
}) => Barcode(
  format: BarcodeFormat.qrCode,
  text: text,
  bytes: Uint8List.fromList(bytes ?? utf8.encode(text)),
  position: _nowhere,
  contentType: type,
);

BarcodeContent _parse(String text) => _barcode(text).content;

/// The raw GS1 element strings, with `|` for the GS separator.
Barcode _gs1(String raw, {String text = ''}) => _barcode(
  text,
  type: BarcodeContentType.gs1,
  bytes: latin1.encode(raw.replaceAll('|', '\x1D')),
);

void main() {
  group('URL', () {
    test('http and https addresses', () {
      expect(
        _parse('https://pub.dev/packages/flutter_zxing'),
        UrlContent(Uri.parse('https://pub.dev/packages/flutter_zxing')),
      );
      expect(
        _parse('http://192.168.1.1:8080/setup'),
        UrlContent(Uri.parse('http://192.168.1.1:8080/setup')),
      );
    });

    test('upper case, as QR alphanumeric mode encodes it', () {
      final UrlContent url = _parse('HTTP://EXAMPLE.COM/ABC') as UrlContent;
      expect(url.url.scheme, 'http');
      expect(url.url.host, 'example.com');
      expect(url.url.path, '/ABC');
    });

    test('www. addresses get https', () {
      expect(
        _parse('www.nettek.co.uk'),
        UrlContent(Uri.parse('https://www.nettek.co.uk')),
      );
    });

    test('surrounding whitespace is ignored', () {
      expect(
        _parse('  https://flutter.dev\r\n'),
        UrlContent(Uri.parse('https://flutter.dev')),
      );
    });

    test('text that only starts with an address stays text (sample)', () {
      const String text =
          'http://live.fdgm.jp/u/event/hype/hype_top.html \n\n'
          r'MEBKM:TITLE:hypeモバイル;URL:http\://live.fdgm.jp/u/event/hype/hype_top.html;;';
      expect(_parse(text), const TextContent(text));
    });

    test('bare domains and empty addresses stay text', () {
      expect(_parse('pub.dev'), const TextContent('pub.dev'));
      expect(_parse('file.txt'), const TextContent('file.txt'));
      expect(_parse('http://'), const TextContent('http://'));
    });

    test('MEBKM bookmarks (samples)', () {
      expect(
        _parse(r'MEBKM:URL:http\://en.wikipedia.org/wiki/Main_Page;;'),
        UrlContent(Uri.parse('http://en.wikipedia.org/wiki/Main_Page')),
      );
      expect(
        _parse(
          r'MEBKM:TITLE:hypeモバイル;URL:http\://live.fdgm.jp/u/event/hype/hype_top.html;;',
        ),
        UrlContent(
          Uri.parse('http://live.fdgm.jp/u/event/hype/hype_top.html'),
          title: 'hypeモバイル',
        ),
      );
      expect(
        _parse('MEBKM:TITLE:;URL:http://d.kaywa.com/2020400102;;'),
        UrlContent(Uri.parse('http://d.kaywa.com/2020400102')),
      );
      expect(_parse('MEBKM:TITLE:x;;'), const TextContent('MEBKM:TITLE:x;;'));
    });

    test('URLTO', () {
      expect(
        _parse('URLTO:Flutter:https://flutter.dev'),
        UrlContent(Uri.parse('https://flutter.dev'), title: 'Flutter'),
      );
      expect(
        _parse('URLTO::flutter.dev'),
        UrlContent(Uri.parse('https://flutter.dev')),
      );
    });
  });

  group('Wi-Fi', () {
    test('WPA network', () {
      expect(
        _parse('WIFI:T:WPA;S:Lumen Guest;P:espresso-2026;;'),
        const WifiContent(ssid: 'Lumen Guest', password: 'espresso-2026'),
      );
    });

    test('escaped characters and a hidden network', () {
      expect(
        _parse(r'WIFI:S:My\;Net\:work;T:WEP;P:pa\\ss\,word;H:true;;'),
        const WifiContent(
          ssid: 'My;Net:work',
          password: r'pa\ss,word',
          security: WifiSecurity.wep,
          hidden: true,
        ),
      );
    });

    test('open networks have no password', () {
      expect(
        _parse('WIFI:S:Cafe;T:nopass;P:;;'),
        const WifiContent(ssid: 'Cafe', security: WifiSecurity.none),
      );
      expect(
        _parse('WIFI:S:Cafe;;'),
        const WifiContent(ssid: 'Cafe', security: WifiSecurity.none),
      );
      expect(
        _parse('WIFI:T:nopass;S:Cafe;P:ignored;;'),
        const WifiContent(ssid: 'Cafe', security: WifiSecurity.none),
      );
    });

    test('a password without a type is WPA', () {
      expect(
        _parse('WIFI:S:Home;P:secret;;'),
        const WifiContent(ssid: 'Home', password: 'secret'),
      );
    });

    test('security types', () {
      WifiSecurity security(String type) =>
          (_parse('WIFI:T:$type;S:n;P:p;;') as WifiContent).security;
      expect(security('WPA'), WifiSecurity.wpa);
      expect(security('WPA2'), WifiSecurity.wpa);
      expect(security('wpa3'), WifiSecurity.wpa);
      expect(security('SAE'), WifiSecurity.wpa);
      expect(security('WEP'), WifiSecurity.wep);
      expect(security('WPA2-EAP'), WifiSecurity.enterprise);
      expect(security('EAP'), WifiSecurity.enterprise);
      expect(security('Kerberos'), WifiSecurity.unknown);
    });

    test('quoted values, lower case keys, any order', () {
      expect(
        _parse('wifi:p:"pass word";s:"Quoted";t:wpa;;'),
        const WifiContent(ssid: 'Quoted', password: 'pass word'),
      );
    });

    test('a network without a name is text', () {
      expect(_parse('WIFI:T:WPA;P:x;;'), const TextContent('WIFI:T:WPA;P:x;;'));
    });
  });

  group('contact', () {
    test('vCard 2.1 (sample)', () {
      const String vcard =
          'BEGIN:VCARD\n'
          'N:Kennedy;Steve\n'
          'TEL:+44 (0)7775 755503\n'
          'ADR;HOME:;;Flat 2, 43 Howitt Road, Belsize Park;London;;NW34LU;UK\n'
          'ORG:NetTek Ltd;\n'
          'TITLE:Consultant\n'
          'EMAIL:steve@nettek.co.uk\n'
          'URL:www.nettek.co.uk\n'
          'EMAIL;IM:MSN:steve@gbnet.net\n'
          'NOTE:Testing 1 2 3\n'
          'BDAY:19611105\n'
          'END:VCARD';
      expect(
        _parse(vcard),
        ContactContent(
          name: 'Steve Kennedy',
          organization: 'NetTek Ltd',
          title: 'Consultant',
          phones: const <String>['+44 (0)7775 755503'],
          emails: const <String>['steve@nettek.co.uk', 'MSN:steve@gbnet.net'],
          urls: <Uri>[Uri.parse('https://www.nettek.co.uk')],
          addresses: const <String>[
            'Flat 2, 43 Howitt Road, Belsize Park, London, NW34LU, UK',
          ],
          note: 'Testing 1 2 3',
          birthday: DateTime(1961, 11, 5),
        ),
      );
    });

    test('vCard 3.0/4.0: FN, folding, escapes, groups, URIs', () {
      const String vcard =
          'BEGIN:VCARD\r\n'
          'VERSION:4.0\r\n'
          'N:Markosyan;Khoren;;Dr.;\r\n'
          'FN:Khoren Markosyan\r\n'
          'ORG:Example\\, Inc.;Mobile\r\n'
          'item1.TEL;VALUE=uri;TYPE="voice,cell":tel:+374-10-000000\r\n'
          'EMAIL;TYPE=work:mailto:dev@example.com\r\n'
          'ADR;TYPE=work:;;1 Long Street\\, Building 2;Yerevan;;0010;\r\n'
          ' Armenia\r\n'
          'NOTE:First line\\nsecond line\r\n'
          'END:VCARD\r\n';
      expect(
        _parse(vcard),
        const ContactContent(
          name: 'Khoren Markosyan',
          organization: 'Example, Inc., Mobile',
          phones: <String>['+374-10-000000'],
          emails: <String>['dev@example.com'],
          addresses: <String>[
            '1 Long Street, Building 2, Yerevan, 0010, Armenia',
          ],
          note: 'First line\nsecond line',
        ),
      );
    });

    test('N is used when there is no FN', () {
      final ContactContent contact =
          _parse('BEGIN:VCARD\nN:Owen;Sean;R.;Mr.;Jr.\nEND:VCARD')
              as ContactContent;
      expect(contact.name, 'Mr. Sean R. Owen Jr.');
    });

    test('vCard 2.1 quoted-printable with a soft line break', () {
      final ContactContent contact =
          _parse(
                'BEGIN:VCARD\r\n'
                'VERSION:2.1\r\n'
                'FN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:Caf=C3=A9 =\r\n'
                'au lait\r\n'
                'END:VCARD',
              )
              as ContactContent;
      expect(contact.name, 'Café au lait');
    });

    test('MeCard (samples)', () {
      expect(
        _parse('MECARD:N:Sean Owen;TEL:+12125658770;EMAIL:srowen@google.com;;'),
        const ContactContent(
          name: 'Sean Owen',
          phones: <String>['+12125658770'],
          emails: <String>['srowen@google.com'],
        ),
      );
      expect(
        _parse('MECARD:N:Google 411,;TEL:18665881077;;'),
        const ContactContent(
          name: 'Google 411',
          phones: <String>['18665881077'],
        ),
      );
      expect(_parse('MECARD:N:測試;;'), const ContactContent(name: '測試'));
    });

    test('MeCard: Last,First, repeated fields, address, escapes', () {
      expect(
        _parse(
          r'MECARD:N:Owen,Sean;TEL:+1;TEL:+2;URL:zxing.org;'
          r'ADR:,,76 9th Ave,New York,NY,10011,USA;NOTE:a\;b;ORG:Google;;',
        ),
        ContactContent(
          name: 'Sean Owen',
          organization: 'Google',
          phones: const <String>['+1', '+2'],
          urls: <Uri>[Uri.parse('https://zxing.org')],
          addresses: const <String>['76 9th Ave, New York, NY, 10011, USA'],
          note: 'a;b',
        ),
      );
    });

    test('an empty card is text', () {
      expect(_parse('MECARD:;;'), const TextContent('MECARD:;;'));
      expect(
        _parse('BEGIN:VCARD\nVERSION:3.0\nEND:VCARD'),
        const TextContent('BEGIN:VCARD\nVERSION:3.0\nEND:VCARD'),
      );
    });

    test('the lists cannot be changed', () {
      final ContactContent contact =
          _parse('MECARD:N:A;TEL:1;;') as ContactContent;
      expect(() => contact.phones.add('2'), throwsUnsupportedError);
    });
  });

  group('event', () {
    test('UTC times, location, escaped description', () {
      expect(
        _parse(
          'BEGIN:VEVENT\n'
          'SUMMARY:Release party\n'
          'DTSTART:20261114T180000Z\n'
          'DTEND:20261114T210000Z\n'
          'LOCATION:Yerevan\n'
          'DESCRIPTION:flutter_zxing 4.0\\, finally\n'
          'END:VEVENT',
        ),
        EventContent(
          summary: 'Release party',
          start: DateTime.utc(2026, 11, 14, 18),
          end: DateTime.utc(2026, 11, 14, 21),
          location: 'Yerevan',
          description: 'flutter_zxing 4.0, finally',
        ),
      );
    });

    test('inside a VCALENDAR, a date and a duration', () {
      final EventContent event =
          _parse(
                'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n'
                'SUMMARY:Holiday\r\nDTSTART;VALUE=DATE:20261224\r\n'
                'DURATION:P1D\r\nEND:VEVENT\r\nEND:VCALENDAR',
              )
              as EventContent;
      expect(event.start, DateTime(2026, 12, 24));
      expect(event.end, DateTime(2026, 12, 25));
    });

    test('a time with a TZID is local time', () {
      final EventContent event =
          _parse(
                'BEGIN:VEVENT\nDTSTART;TZID=Europe/Berlin:20261114T093000\n'
                'DURATION:PT1H30M\nEND:VEVENT',
              )
              as EventContent;
      expect(event.summary, '');
      expect(event.start, DateTime(2026, 11, 14, 9, 30));
      expect(event.end, DateTime(2026, 11, 14, 11));
      expect(event.start.isUtc, isFalse);
    });

    test('no or an invalid start is text', () {
      const String noStart = 'BEGIN:VEVENT\nSUMMARY:x\nEND:VEVENT';
      expect(_parse(noStart), const TextContent(noStart));
      const String badStart =
          'BEGIN:VEVENT\nDTSTART:20261340T000000\nEND:VEVENT';
      expect(_parse(badStart), const TextContent(badStart));
      const String todo =
          'BEGIN:VCALENDAR\nBEGIN:VTODO\nDTSTART:20261114\n'
          'END:VTODO\nEND:VCALENDAR';
      expect(_parse(todo), const TextContent(todo));
    });
  });

  group('e-mail', () {
    test('mailto (sample)', () {
      expect(
        _parse('mailto:zxing@googlegroups.com'),
        const EmailContent(address: 'zxing@googlegroups.com'),
      );
    });

    test('mailto with subject and body; + is not a space', () {
      expect(
        _parse('MAILTO:a@b.com?subject=Hello%20there&body=1+1%3D2'),
        const EmailContent(
          address: 'a@b.com',
          subject: 'Hello there',
          body: '1+1=2',
        ),
      );
    });

    test('mailto with recipients in the query', () {
      expect(
        _parse('mailto:a@b.com?to=c@d.com&cc=e@f.com'),
        const EmailContent(address: 'a@b.com,c@d.com'),
      );
      expect(
        _parse('mailto:?subject=Feedback'),
        const EmailContent(address: '', subject: 'Feedback'),
      );
    });

    test('MATMSG and SMTP', () {
      expect(
        _parse(r'MATMSG:TO:a@b.com;SUB:Hi;BODY:Line\; two;;'),
        const EmailContent(
          address: 'a@b.com',
          subject: 'Hi',
          body: 'Line; two',
        ),
      );
      expect(
        _parse('SMTP:a@b.com:Subject:Body: with a colon'),
        const EmailContent(
          address: 'a@b.com',
          subject: 'Subject',
          body: 'Body: with a colon',
        ),
      );
    });
  });

  group('phone and SMS', () {
    test('tel', () {
      expect(
        _parse('tel:+1-212-555-0100'),
        const PhoneContent('+1-212-555-0100'),
      );
      expect(_parse('TEL:%2B12125550100'), const PhoneContent('+12125550100'));
      expect(_parse('tel:'), const TextContent('tel:'));
    });

    test('SMSTO', () {
      expect(
        _parse('SMSTO:+15551212:Hello: world'),
        const SmsContent(number: '+15551212', message: 'Hello: world'),
      );
      expect(_parse('smsto:+15551212'), const SmsContent(number: '+15551212'));
      expect(
        _parse('MMSTO:+15551212:pic'),
        const SmsContent(number: '+15551212', message: 'pic'),
      );
    });

    test('sms (RFC 5724) and the colon variant', () {
      expect(
        _parse('sms:+15551212?body=Hi%20there'),
        const SmsContent(number: '+15551212', message: 'Hi there'),
      );
      expect(
        _parse('sms:+15551212;via=+15550000?body=x'),
        const SmsContent(number: '+15551212', message: 'x'),
      );
      expect(
        _parse('sms:+15551212,+15553434'),
        const SmsContent(number: '+15551212,+15553434'),
      );
      expect(
        _parse('SMS:+15551212:legacy text'),
        const SmsContent(number: '+15551212', message: 'legacy text'),
      );
      expect(_parse('sms:'), const TextContent('sms:'));
    });
  });

  group('geo', () {
    test('coordinates, altitude, parameters and a query', () {
      expect(
        _parse('geo:40.71872,-73.98905,100'),
        const GeoContent(
          latitude: 40.71872,
          longitude: -73.98905,
          altitude: 100,
        ),
      );
      expect(
        _parse('geo:0,0?q=1600%20Amphitheatre+Parkway'),
        const GeoContent(
          latitude: 0,
          longitude: 0,
          query: '1600 Amphitheatre Parkway',
        ),
      );
      expect(
        _parse('GEO:40.1792,44.4991;u=35'),
        const GeoContent(latitude: 40.1792, longitude: 44.4991),
      );
    });

    test('out of range or malformed is text', () {
      for (final String text in <String>[
        'geo:91,0',
        'geo:0,181',
        'geo:abc',
        'geo:1',
        'geo:1,2,x',
        'geo:1,2,3,4',
      ]) {
        expect(_parse(text), TextContent(text), reason: text);
      }
    });
  });

  group('GS1', () {
    test('Data Matrix with variable length fields (sample)', () {
      final BarcodeContent content = _gs1(
        '010950400005910121'
        '12345678p901|101234567p|171411208200http://www.gs1.org/demo/',
      ).content;
      expect(content, isA<Gs1Content>());
      final Gs1Content gs1 = content as Gs1Content;
      expect(gs1.elements, <String, String>{
        '01': '09504000059101',
        '21': '12345678p901',
        '10': '1234567p',
        '17': '141120',
        '8200': 'http://www.gs1.org/demo/',
      });
      expect(gs1.elements.keys, <String>['01', '21', '10', '17', '8200']);
      expect(gs1.gtin, '09504000059101');
    });

    test('DataBar Expanded: four digit identifiers (samples)', () {
      expect(
        (_gs1('11100224171102243102000100').content as Gs1Content).elements,
        <String, String>{'11': '100224', '17': '110224', '3102': '000100'},
      );
      expect(
        (_gs1(
                  '01988987654321061599123131030017501012A|422123|21123456|'
                  '423012345678901',
                ).content
                as Gs1Content)
            .elements,
        <String, String>{
          '01': '98898765432106',
          '15': '991231',
          '3103': '001750',
          '10': '12A',
          '422': '123',
          '21': '123456',
          '423': '012345678901',
        },
      );
      expect(
        (_gs1('811010014141012345290110100').content as Gs1Content).elements,
        <String, String>{'8110': '10014141012345290110100'},
      );
    });

    test('data that is not valid GS1 is text (sample)', () {
      // Code 128 sample with FNC1 whose AI 16 is two digits short: zxing-cpp
      // gives no human readable form either.
      expect(
        _gs1('168901', text: '168901').content,
        const TextContent('168901'),
      );
      expect(_gs1('99', text: '99').content, const TextContent('99'));
    });

    test('the human readable text when there are no bytes', () {
      expect(
        _barcode(
          '(01)09501101530003(17)250101(10)ABC123',
          type: BarcodeContentType.gs1,
          bytes: const <int>[],
        ).content,
        const Gs1Content(<String, String>{
          '01': '09501101530003',
          '17': '250101',
          '10': 'ABC123',
        }),
      );
    });

    test('GS1-looking text in a text barcode stays text', () {
      expect(
        _parse('(01)09501101530003'),
        const TextContent('(01)09501101530003'),
      );
    });
  });

  group('GS1 fields', () {
    test('names the common identifiers', () {
      const Gs1Content gs1 = Gs1Content(<String, String>{
        '00': '106141412345678908',
        '01': '09501101530003',
        '10': 'AB12C',
        '21': '7C4K9M2',
        '37': '24',
        '17': '250100',
        '15': '261231',
      });
      expect(gs1.sscc, '106141412345678908');
      expect(gs1.gtin, '09501101530003');
      expect(gs1.batch, 'AB12C');
      expect(gs1.serial, '7C4K9M2');
      expect(gs1.count, 24);
      // Day 00: the last day of the month.
      expect(gs1.expiry, DateTime(2025, 1, 31));
      expect(gs1.bestBefore, DateTime(2026, 12, 31));
    });

    test('expired after the expiry day, not on it', () {
      const Gs1Content gs1 = Gs1Content(<String, String>{'17': '261117'});
      expect(gs1.isExpired(DateTime(2026, 11, 17, 23, 59)), isFalse);
      expect(gs1.isExpired(DateTime(2026, 11, 18)), isTrue);
      expect(const Gs1Content(<String, String>{}).isExpired(), isFalse);
    });

    test('dates: the century of GS1 7.12, invalid dates', () {
      final DateTime now = DateTime(2026, 6);
      expect(gs1Date('760101', now), DateTime(2076));
      expect(gs1Date('770101', now), DateTime(1977));
      expect(gs1Date('770101', DateTime(2027)), DateTime(2077));
      expect(gs1Date('970101', DateTime(2050)), DateTime(2097));
      expect(gs1Date('000229', now), DateTime(2000, 2, 29));
      expect(gs1Date('010229', now), isNull);
      expect(gs1Date('251301', now), isNull);
      expect(gs1Date('2501', now), isNull);
      expect(gs1Date(null, now), isNull);
      expect(const Gs1Content(<String, String>{'37': 'x'}).count, isNull);
    });
  });

  group('content type', () {
    test('binary barcodes are BinaryContent', () {
      expect(
        _barcode(
          '',
          type: BarcodeContentType.binary,
          bytes: const <int>[0xCA, 0xFE],
        ).content,
        BinaryContent(Uint8List.fromList(<int>[0xCA, 0xFE])),
      );
    });

    test('a binary AAMVA license is a license, other ASCII stays binary', () {
      const String aamva =
          '@\n\x1e\rANSI 636014080102DL00410288ZC03290015DLDAQD1234562\n'
          'DCSPUBLIC\nDACJOHN\nDBB08311977\nDCGUSA\r';
      expect(
        _barcode(
          '',
          type: BarcodeContentType.binary,
          bytes: ascii.encode(aamva),
        ).content,
        isA<DriverLicenseContent>(),
      );
      final List<int> plain = ascii.encode('just\x1etext');
      expect(
        _barcode('', type: BarcodeContentType.binary, bytes: plain).content,
        BinaryContent(Uint8List.fromList(plain)),
      );
    });

    test('ISO 15434 and unknown ECI are text, never parsed', () {
      expect(
        _barcode('https://x.org', type: BarcodeContentType.iso15434).content,
        const TextContent('https://x.org'),
      );
      expect(
        _barcode('WIFI:S:x;;', type: BarcodeContentType.unknownEci).content,
        const TextContent('WIFI:S:x;;'),
      );
    });

    test('mixed barcodes are parsed like text', () {
      expect(
        _barcode('tel:123', type: BarcodeContentType.mixed).content,
        const PhoneContent('123'),
      );
    });
  });

  test('content is parsed once per barcode', () {
    final Barcode barcode = _barcode('WIFI:S:x;;');
    expect(identical(barcode.content, barcode.content), isTrue);
  });

  test('parseText', () {
    expect(BarcodeContent.parseText('tel:+374'), const PhoneContent('+374'));
    expect(BarcodeContent.parseText('hello'), const TextContent('hello'));
  });

  test('equal values are equal and hash alike', () {
    const Gs1Content a = Gs1Content(<String, String>{'01': '1', '10': 'x'});
    const Gs1Content b = Gs1Content(<String, String>{'10': 'x', '01': '1'});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      ContactContent(urls: <Uri>[Uri.parse('https://a.b')]),
      ContactContent(urls: <Uri>[Uri.parse('https://a.b')]),
    );
    expect(const TextContent('a'), isNot(const PhoneContent('a')));
  });

  group('found in review', () {
    test('prefixes whose upper case is longer do not shift the slicing', () {
      for (final String text in <String>['SMﬆO:', 'WIﬁ:', 'ﬆEL:123', 'ßMS:1']) {
        expect(_parse(text), TextContent(text), reason: text);
      }
    });

    test('a huge DURATION gives no end instead of throwing', () {
      for (final String d in <String>['P99999999999999999999W', 'P14300000W']) {
        final EventContent event =
            _parse(
                  'BEGIN:VEVENT\nDTSTART:20261114T093000Z\nDURATION:$d\n'
                  'END:VEVENT',
                )
                as EventContent;
        expect(event.end, isNull, reason: d);
      }
    });

    test('a nested VALARM does not overwrite the event', () {
      final EventContent event =
          _parse(
                'BEGIN:VEVENT\n'
                'SUMMARY:Standup\n'
                'DTSTART:20261114T093000Z\n'
                'DURATION:PT1H\n'
                'DESCRIPTION:Agenda\n'
                'BEGIN:VALARM\n'
                'TRIGGER:-PT5M\n'
                'DURATION:PT5M\n'
                'DESCRIPTION:Reminder\n'
                'END:VALARM\n'
                'LOCATION:Room 4\n'
                'END:VEVENT',
              )
              as EventContent;
      expect(event.description, 'Agenda');
      expect(event.end, DateTime.utc(2026, 11, 14, 10, 30));
      expect(event.location, 'Room 4');
    });

    test('GS1 bytes that do not split are text, whatever the text says', () {
      // zxing-cpp's text is then the escaped raw data.
      expect(
        _gs1('10ABC|0499', text: '10ABC<GS>0499').content,
        const TextContent('10ABC<GS>0499'),
      );
      expect(
        _gs1('|0109501101530003', text: '<GS>0109501101530003').content,
        const TextContent('<GS>0109501101530003'),
      );
    });

    test('escaped quotes in a Wi-Fi value are kept', () {
      expect(
        _parse(r'WIFI:T:WPA;S:net;P:\"secret\";;'),
        const WifiContent(ssid: 'net', password: '"secret"'),
      );
      expect(
        _parse(r'WIFI:T:WPA;S:"a\"";P:x;;'),
        // Quoted, with an escaped quote inside.
        const WifiContent(ssid: 'a"', password: 'x'),
      );
    });

    test('geo coordinates must be finite', () {
      for (final String text in <String>[
        'geo:NaN,NaN',
        'geo:Infinity,0',
        'geo:1,2,NaN',
      ]) {
        expect(_parse(text), TextContent(text), reason: text);
      }
    });

    test('quoted-printable keeps literal emoji and Latin-1 text', () {
      String name(String line) =>
          (_parse('BEGIN:VCARD\n$line\nEND:VCARD') as ContactContent).name!;
      expect(
        name('FN;ENCODING=QUOTED-PRINTABLE;CHARSET=UTF-8:Caf=C3=A9 ☕🙂'),
        'Café ☕🙂',
      );
      expect(
        name('FN;ENCODING=QUOTED-PRINTABLE;CHARSET=ISO-8859-1:Caf=E9 é'),
        'Café é',
      );
      expect(name('FN;ENCODING=QUOTED-PRINTABLE:a=+1b'), 'a=+1b');
    });
  });

  test('malformed payloads never throw', () {
    for (final String text in <String>[
      '',
      ' ',
      r'\',
      'WIFI:',
      r'WIFI:S:\',
      'WIFI:;;;;',
      'MECARD:',
      r'MECARD:N:\',
      'MECARD:N:,',
      'BEGIN:VCARD',
      'BEGIN:VCARD\n:\n;\nN\nEND:VCARD',
      'BEGIN:VCARD\nFN;ENCODING=QUOTED-PRINTABLE:=\nEND:VCARD',
      'BEGIN:VCARD\nFN;ENCODING=QUOTED-PRINTABLE:=ZZ=C3\nEND:VCARD',
      'BEGIN:VEVENT',
      'BEGIN:VEVENT\nDTSTART:\nDURATION:P\nEND:VEVENT',
      'MEBKM:',
      'MEBKM:URL:;;',
      'URLTO:',
      'mailto:',
      'mailto:%',
      'mailto:a?=&&=x&subject=%ZZ',
      'MATMSG:',
      'SMTP:',
      'SMTP::',
      'tel:%E0%A4%A',
      'sms:?body=%',
      'smsto:',
      'geo:',
      'geo:,',
      'geo:1,2?q=%',
      'http://[',
      'www.',
      'www.[',
    ]) {
      expect(() => _parse(text), returnsNormally, reason: text);
    }
    for (final String raw in <String>['', '|', '01', '0112', '10|', '8200']) {
      expect(() => _gs1(raw).content, returnsNormally, reason: raw);
    }
  });
}
