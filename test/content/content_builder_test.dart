// BarcodeContent.toPayload and validate: the payloads built, and that
// parsing reads them back as equal values (round-trip).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/content.dart';

const String _iban = 'DE89370400440532013000';

/// [content] survives toPayload → parseText unchanged.
void _roundTrips(BarcodeContent content, [ContactFormat? format]) {
  final String payload = content is ContactContent && format != null
      ? content.toPayload(format: format)
      : content.toPayload();
  expect(BarcodeContent.parseText(payload), content, reason: payload);
}

/// [content] is not in normal form: it becomes [normal], which then stays.
void _normalises(BarcodeContent content, BarcodeContent normal) {
  final BarcodeContent parsed = BarcodeContent.parseText(content.toPayload());
  expect(parsed, normal);
  expect(parsed.toPayload(), content.toPayload());
}

Matcher _issue(String field) => contains(
  isA<ContentIssue>().having((ContentIssue i) => i.field, 'field', field),
);

void main() {
  group('text', () {
    test('as it is', () {
      expect(const TextContent('hello\nworld').toPayload(), 'hello\nworld');
      _roundTrips(const TextContent('  Ünïcødé 😀 text  '));
    });

    test('empty text is an issue', () {
      expect(const TextContent('').validate(), _issue('text'));
      expect(() => const TextContent('').toPayload(), throwsArgumentError);
    });
  });

  group('binary', () {
    test('has no text payload', () {
      expect(
        () => BinaryContent(Uint8List.fromList(<int>[1, 2])).toPayload(),
        throwsUnsupportedError,
      );
      expect(BinaryContent(Uint8List(0)).validate(), _issue('bytes'));
    });
  });

  group('URL', () {
    test('address as it is', () {
      final UrlContent url = UrlContent(Uri.parse('https://example.com/a?b=c'));
      expect(url.toPayload(), 'https://example.com/a?b=c');
      _roundTrips(url);
      _roundTrips(UrlContent(Uri.parse('http://example.com:8080/x#y')));
    });

    test('an address without a scheme gets https', () {
      expect(
        UrlContent(Uri.parse('example.com/path')).toPayload(),
        'https://example.com/path',
      );
      _normalises(
        UrlContent(Uri.parse('example.com')),
        UrlContent(Uri.parse('https://example.com')),
      );
    });

    test('with a title: MEBKM', () {
      final UrlContent url = UrlContent(
        Uri.parse('https://example.com/a;b'),
        title: 'Shop: 50% off; today',
      );
      expect(
        url.toPayload(),
        r'MEBKM:TITLE:Shop\: 50% off\; today;URL:https://example.com/a\;b;;',
      );
      _roundTrips(url);
    });

    test('other schemes are not web links', () {
      expect(UrlContent(Uri.parse('ftp://x.org')).validate(), _issue('url'));
      expect(UrlContent(Uri.parse('https:/x')).validate(), _issue('url'));
    });
  });

  group('Wi-Fi', () {
    test('WPA', () {
      const WifiContent wifi = WifiContent(ssid: 'Home', password: 'secret12');
      expect(wifi.toPayload(), 'WIFI:T:WPA;S:Home;P:secret12;;');
      _roundTrips(wifi);
    });

    test('special characters are escaped', () {
      const WifiContent wifi = WifiContent(
        ssid: r'"My;Net,1:\"',
        password: r'p"a;s,s:w\o',
        hidden: true,
      );
      expect(
        wifi.toPayload(),
        r'WIFI:T:WPA;S:\"My\;Net\,1\:\\\";P:p\"a\;s\,s\:w\\o;H:true;;',
      );
      _roundTrips(wifi);
    });

    test('open and WEP networks', () {
      const WifiContent open = WifiContent(
        ssid: 'Café ☕',
        security: WifiSecurity.none,
      );
      expect(open.toPayload(), 'WIFI:T:nopass;S:Café ☕;;');
      _roundTrips(open);
      _roundTrips(
        const WifiContent(
          ssid: 'Old',
          password: '12345',
          security: WifiSecurity.wep,
        ),
      );
    });

    test('WPA3 is T:WPA with transition disabled', () {
      const WifiContent wifi = WifiContent(
        ssid: 'Home',
        password: 'secret12',
        security: WifiSecurity.wpa3,
      );
      expect(wifi.toPayload(), 'WIFI:T:WPA;R:1;S:Home;P:secret12;;');
      _roundTrips(wifi);
      expect(
        const WifiContent(ssid: 'x', security: WifiSecurity.wpa3).validate(),
        _issue('password'),
      );
    });

    test('without a security type: open without a password, WPA with', () {
      const WifiContent open = WifiContent(ssid: 'Cafe');
      expect(open.security, WifiSecurity.none);
      expect(open.validate(), isEmpty);
      expect(open.toPayload(), 'WIFI:T:nopass;S:Cafe;;');
      expect(
        const WifiContent(ssid: 'Cafe', password: '').security,
        WifiSecurity.none,
      );
      expect(
        const WifiContent(ssid: 'Home', password: 'secret12').security,
        WifiSecurity.wpa,
      );
    });

    test('a password of an open network is dropped', () {
      _normalises(
        const WifiContent(
          ssid: 'x',
          password: 'unused',
          security: WifiSecurity.none,
        ),
        const WifiContent(ssid: 'x', security: WifiSecurity.none),
      );
    });

    test('issues', () {
      expect(const WifiContent(ssid: '').validate(), _issue('ssid'));
      expect(WifiContent(ssid: 'a' * 33).validate(), _issue('ssid'));
      expect(
        const WifiContent(ssid: 'x', security: WifiSecurity.wpa).validate(),
        _issue('password'),
      );
      expect(
        const WifiContent(
          ssid: 'x',
          password: 'p',
          security: WifiSecurity.enterprise,
        ).validate(),
        _issue('security'),
      );
      expect(
        () => const WifiContent(ssid: '').toPayload(),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'message',
            contains('Network name is empty'),
          ),
        ),
      );
    });
  });

  group('e-mail', () {
    test('mailto with subject and body', () {
      const EmailContent email = EmailContent(
        address: 'a@example.com',
        subject: 'Hi & bye?',
        body: 'Line 1\nLine 2 = 100%',
      );
      expect(
        email.toPayload(),
        'mailto:a@example.com?subject=Hi%20%26%20bye%3F'
        '&body=Line%201%0ALine%202%20%3D%20100%25',
      );
      _roundTrips(email);
    });

    test('several recipients, or none', () {
      _roundTrips(const EmailContent(address: 'a@x.org,b+tag@y.org'));
      _roundTrips(const EmailContent(address: '', subject: 'Feedback'));
      _normalises(
        const EmailContent(address: ' a@x.org , b@y.org ', subject: ''),
        const EmailContent(address: 'a@x.org,b@y.org'),
      );
    });

    test('issues', () {
      expect(const EmailContent(address: 'nope').validate(), _issue('address'));
      expect(const EmailContent(address: '').validate(), _issue('address'));
    });
  });

  group('phone', () {
    test('tel: without separators', () {
      expect(
        const PhoneContent('+1 (212) 555-1234').toPayload(),
        'tel:+12125551234',
      );
      _roundTrips(const PhoneContent('+12125551234'));
      _normalises(
        const PhoneContent('+1 (212) 555-1234'),
        const PhoneContent('+12125551234'),
      );
    });

    test('service codes keep * and #', () {
      expect(const PhoneContent('*100#').toPayload(), 'tel:*100%23');
      _roundTrips(const PhoneContent('*100#'));
    });

    test('issues', () {
      expect(const PhoneContent(' ').validate(), _issue('number'));
      expect(const PhoneContent('call me').validate(), _issue('number'));
      expect(const PhoneContent('1+2').validate(), _issue('number'));
    });
  });

  group('SMS', () {
    test('SMSTO', () {
      const SmsContent sms = SmsContent(
        number: '+12125551234',
        message: 'Hi: see you at 5',
      );
      expect(sms.toPayload(), 'SMSTO:+12125551234:Hi: see you at 5');
      _roundTrips(sms);
      _roundTrips(const SmsContent(number: '+1555,+1666'));
    });

    test('normal form', () {
      _normalises(
        const SmsContent(number: '+1 555', message: '  hi  '),
        const SmsContent(number: '+1555', message: 'hi'),
      );
    });

    test('issues', () {
      expect(const SmsContent(number: '').validate(), _issue('number'));
      expect(const SmsContent(number: '1,abc').validate(), _issue('number'));
    });
  });

  group('geo', () {
    test('coordinates, altitude, query', () {
      const GeoContent geo = GeoContent(
        latitude: 40.689247,
        longitude: -74.044502,
        altitude: 93,
        query: 'Statue of Liberty & more',
      );
      expect(
        geo.toPayload(),
        'geo:40.689247,-74.044502,93?q=Statue+of+Liberty+%26+more',
      );
      _roundTrips(geo);
      _roundTrips(const GeoContent(latitude: -90, longitude: 180));
    });

    test('never in exponent form', () {
      expect(
        const GeoContent(latitude: 1e-7, longitude: 0).toPayload(),
        'geo:0.0000001,0',
      );
    });

    test('issues', () {
      expect(
        const GeoContent(latitude: 91, longitude: 0).validate(),
        _issue('latitude'),
      );
      expect(
        const GeoContent(latitude: 0, longitude: -180.5).validate(),
        _issue('longitude'),
      );
      expect(
        const GeoContent(
          latitude: double.nan,
          longitude: 0,
          altitude: double.infinity,
        ).validate(),
        allOf(_issue('latitude'), _issue('altitude')),
      );
    });
  });

  group('contact', () {
    final ContactContent full = ContactContent(
      name: 'Mary Ann Smith',
      organization: r'Acme; Inc, \Labs',
      title: 'CTO',
      phones: const <String>['+1 555 0100', '+44 20 7946 0000'],
      emails: const <String>['mary@acme.example'],
      urls: <Uri>[Uri.parse('https://acme.example/mary')],
      addresses: const <String>['1 Main St, Springfield, 12345, US'],
      note: 'Met at the fair: line 1\nline 2',
      birthday: DateTime(1990, 5, 17),
    );

    test('vCard 3.0', () {
      expect(
        full.toPayload(),
        'BEGIN:VCARD\n'
        'VERSION:3.0\n'
        'N:Smith;Mary Ann;;;\n'
        'FN:Mary Ann Smith\n'
        r'ORG:Acme\; Inc\, \\Labs'
        '\n'
        'TITLE:CTO\n'
        'TEL:+1 555 0100\n'
        'TEL:+44 20 7946 0000\n'
        'EMAIL:mary@acme.example\n'
        'URL:https://acme.example/mary\n'
        r'ADR:;;1 Main St\, Springfield\, 12345\, US;;;;'
        '\n'
        r'NOTE:Met at the fair: line 1\nline 2'
        '\n'
        'BDAY:1990-05-17\n'
        'END:VCARD',
      );
      _roundTrips(full);
    });

    test('MeCard', () {
      expect(
        full.toPayload(format: ContactFormat.meCard),
        <String>[
          r'MECARD:N:Smith,Mary Ann;ORG:Acme\; Inc\, \\Labs;TITLE:CTO;',
          'TEL:+1 555 0100;TEL:+44 20 7946 0000;EMAIL:mary@acme.example;',
          'URL:https://acme.example/mary;',
          r'ADR:1 Main St\, Springfield\, 12345\, US;',
          'NOTE:Met at the fair\\: line 1\nline 2;BDAY:19900517;;',
        ].join(),
      );
      _roundTrips(full, ContactFormat.meCard);
    });

    test('only some fields', () {
      for (final ContactFormat format in ContactFormat.values) {
        _roundTrips(const ContactContent(name: 'Madonna'), format);
        _roundTrips(
          const ContactContent(organization: 'Acme', phones: <String>['1']),
          format,
        );
        _roundTrips(ContactContent(birthday: DateTime(2000, 2, 29)), format);
      }
    });

    test('normal form', () {
      _normalises(
        const ContactContent(
          name: '  Sean Owen ',
          phones: <String>['', ' 1 '],
          note: '',
        ),
        const ContactContent(name: 'Sean Owen', phones: <String>['1']),
      );
    });

    test('issues', () {
      expect(const ContactContent().validate(), _issue('name'));
      expect(const ContactContent(name: ' ').validate(), _issue('name'));
      expect(
        const ContactContent(name: 'x', emails: <String>['nope']).validate(),
        _issue('emails'),
      );
    });

    test('birthday is parsed from vCard 4.0 and MeCard forms', () {
      expect(
        (BarcodeContent.parseText(
                  'BEGIN:VCARD\nFN:A\nBDAY:19611105T0000\n'
                  'END:VCARD',
                )
                as ContactContent)
            .birthday,
        DateTime(1961, 11, 5),
      );
      expect(
        (BarcodeContent.parseText('BEGIN:VCARD\nFN:A\nBDAY:--0517\nEND:VCARD')
                as ContactContent)
            .birthday,
        isNull,
      );
      expect(
        (BarcodeContent.parseText('MECARD:N:A;BDAY:19900231;;')
                as ContactContent)
            .birthday,
        isNull,
      );
    });
  });

  group('event', () {
    test('UTC times', () {
      final EventContent event = EventContent(
        summary: 'Launch; v4, final',
        start: DateTime.utc(2026, 11, 17, 9, 30),
        end: DateTime.utc(2026, 11, 17, 11),
        location: 'Room 1',
        description: 'Agenda:\n1. Demo',
      );
      expect(
        event.toPayload(),
        'BEGIN:VCALENDAR\n'
        'VERSION:2.0\n'
        'BEGIN:VEVENT\n'
        r'SUMMARY:Launch\; v4\, final'
        '\n'
        'DTSTART:20261117T093000Z\n'
        'DTEND:20261117T110000Z\n'
        'LOCATION:Room 1\n'
        r'DESCRIPTION:Agenda:\n1. Demo'
        '\n'
        'END:VEVENT\n'
        'END:VCALENDAR',
      );
      _roundTrips(event);
    });

    test('local times', () {
      _roundTrips(
        EventContent(summary: 'Lunch', start: DateTime(2026, 11, 18, 12, 1, 5)),
      );
    });

    test('all day', () {
      final EventContent event = EventContent(
        summary: 'Holiday',
        start: DateTime(2026, 12, 25),
        end: DateTime(2026, 12, 27),
        allDay: true,
      );
      expect(
        event.toPayload(),
        contains('DTSTART;VALUE=DATE:20261225\nDTEND;VALUE=DATE:20261227\n'),
      );
      _roundTrips(event);
      _roundTrips(
        EventContent(summary: '', start: DateTime(2026, 1, 2), allDay: true),
      );
    });

    test('issues', () {
      expect(
        EventContent(
          summary: 'x',
          start: DateTime(2026, 2),
          end: DateTime(2026),
        ).validate(),
        _issue('end'),
      );
      expect(
        EventContent(summary: 'x', start: DateTime(10000)).validate(),
        _issue('start'),
      );
    });
  });

  group('GS1', () {
    test('elements in parentheses', () {
      expect(
        const Gs1Content(<String, String>{
          '01': '09501101530003',
          '17': '270101',
          '10': 'ABC123',
          '3103': '000750',
        }).toPayload(),
        '(01)09501101530003(17)270101(10)ABC123(3103)000750',
      );
    });

    test('issues', () {
      expect(
        const Gs1Content(<String, String>{}).validate(),
        _issue('elements'),
      );
      for (final Map<String, String> elements in <Map<String, String>>[
        <String, String>{'01': '123'},
        <String, String>{'10': 'A' * 21},
        <String, String>{'5': 'x'},
        <String, String>{'310': '000750'},
        <String, String>{'10': ''},
        <String, String>{'10': 'A(B'},
      ]) {
        expect(
          Gs1Content(elements).validate(),
          _issue('elements'),
          reason: '$elements',
        );
      }
    });
  });

  group('issue kinds', () {
    /// The kind and limit of the issue about [field].
    (ContentIssueKind, int?) kindOf(BarcodeContent c, String field) {
      final ContentIssue issue = c.validate().firstWhere(
        (ContentIssue i) => i.field == field,
      );
      return (issue.kind, issue.limit);
    }

    test('empty, too long with its limit, invalid', () {
      expect(kindOf(const WifiContent(ssid: ''), 'ssid'), (
        ContentIssueKind.empty,
        null,
      ));
      expect(kindOf(WifiContent(ssid: 'a' * 33), 'ssid'), (
        ContentIssueKind.tooLong,
        32,
      ));
      expect(kindOf(const EmailContent(address: 'nope'), 'address'), (
        ContentIssueKind.invalid,
        null,
      ));
      expect(kindOf(EpcPaymentContent(name: 'a' * 71, iban: _iban), 'name'), (
        ContentIssueKind.tooLong,
        70,
      ));
      expect(kindOf(Gs1Content(<String, String>{'10': 'A' * 21}), 'elements'), (
        ContentIssueKind.tooLong,
        20,
      ));
    });

    test('checksum, out of range, conflict, unsupported', () {
      expect(
        kindOf(
          const EpcPaymentContent(name: 'x', iban: 'DE89370400440532013001'),
          'iban',
        ),
        (ContentIssueKind.checksum, null),
      );
      expect(kindOf(const EpcPaymentContent(name: 'x', iban: 'DE89'), 'iban'), (
        ContentIssueKind.invalid,
        null,
      ));
      expect(kindOf(const GeoContent(latitude: 91, longitude: 0), 'latitude'), (
        ContentIssueKind.outOfRange,
        null,
      ));
      expect(
        kindOf(
          EventContent(
            summary: 'x',
            start: DateTime(2026, 2),
            end: DateTime(2026),
          ),
          'end',
        ),
        (ContentIssueKind.conflict, null),
      );
      expect(
        kindOf(
          const WifiContent(
            ssid: 'x',
            password: 'p',
            security: WifiSecurity.enterprise,
          ),
          'security',
        ),
        (ContentIssueKind.unsupported, null),
      );
      expect(kindOf(const Gs1Content(<String, String>{'5': 'x'}), 'elements'), (
        ContentIssueKind.unsupported,
        null,
      ));
    });

    test('equality takes the kind and the limit', () {
      expect(const ContentIssue('a', 'b').kind, ContentIssueKind.invalid);
      expect(
        const ContentIssue('a', 'b'),
        isNot(const ContentIssue('a', 'b', kind: ContentIssueKind.empty)),
      );
      expect(
        const ContentIssue('a', 'b', kind: ContentIssueKind.tooLong, limit: 1),
        isNot(
          const ContentIssue(
            'a',
            'b',
            kind: ContentIssueKind.tooLong,
            limit: 2,
          ),
        ),
      );
    });
  });
}
