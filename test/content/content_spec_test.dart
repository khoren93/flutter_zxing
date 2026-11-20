// What the parsers accept and the builders write, held to the specification
// of each format. Every case that a parser accepts must build again.
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
      expect(
        BarcodeContent.parseText('tel:1-800-FLOWERS'),
        isA<TextContent>(),
      );
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
}
