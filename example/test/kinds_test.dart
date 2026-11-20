// The generator's kinds: every example builds, reads back as its kind, and
// prints as Dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing_example/demo/content.dart';
import 'package:flutter_zxing_example/demo/kinds.dart';

Map<String, String> _examples(List<KindField> fields) => <String, String>{
  for (final KindField f in fields) f.key: f.example,
};

void main() {
  for (final CreateKind kind in CreateKind.values) {
    if (kind == CreateKind.service) {
      continue;
    }
    test('${kind.name}: the example builds and reads back', () {
      final BarcodeContent content = kind.content(
        _examples(kind.fields),
        const <String, String>{},
      );
      expect(content.validate(), isEmpty);
      final String payload = content.toPayload();
      expect(payload, isNotEmpty);
      // GS1 data is only GS1 in a code written as GS1: as text, it is text.
      if (kind != CreateKind.gs1) {
        expect(
          BarcodeContent.parseText(payload).runtimeType,
          content.runtimeType,
        );
      }
      expect(
        kind.dart(_examples(kind.fields)) ?? contentDart(content),
        isNot(contains('parseText')),
      );
    });
  }

  for (final LinkService service in LinkService.values) {
    test('service ${service.name}: the example builds', () {
      final BarcodeContent content = CreateKind.service.content(
        <String, String>{
          'value': serviceField(service).example,
          if (service == LinkService.whatsApp) 'message': 'Hi!',
        },
        const <String, String>{},
        linkService: service,
      );
      expect(content.validate(), isEmpty);
      expect((content as UrlContent).service, service);
    });
  }

  test('a problem points at its field', () {
    final BarcodeContent content = CreateKind.epc.content(<String, String>{
      ..._examples(CreateKind.epc.fields),
      'iban': 'DE89 3704 0044 0532 0130 01',
    }, const <String, String>{});
    expect(content.validate().single.field, 'iban');
    expect(
      () => CreateKind.event.content(<String, String>{
        ..._examples(CreateKind.event.fields),
        'start': 'soon',
      }, const <String, String>{}),
      throwsA(isA<FieldProblem>()),
    );
  });

  test('Dart of a payment', () {
    final BarcodeContent content = CreateKind.otp.content(
      _examples(CreateKind.otp.fields),
      const <String, String>{},
    );
    expect(contentDart(content), '''
OtpContent(
  issuer: 'Acme',
  account: 'anna@example.com',
  secret: 'JBSWY3DPEHPK3PXP',
)''');
  });

  test('Dart of a value with a dollar sign', () {
    expect(dartString("AB\$12 'x'\\\r\n"), r"'AB\$12 \'x\'\\\r\n'");
    expect(
      dartCode(r'AB$12', BarcodeFormat.code128, BarcodeStyle.classic),
      contains(r"'AB\$12'"),
    );
  });
}
