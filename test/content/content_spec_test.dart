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
}
