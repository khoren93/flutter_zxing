// Payment codes: the examples of each specification (EPC069-12, Swiss
// Payment Standards, ГОСТ Р 56042-2014, NPCI UPI, EMVCo and the Banco
// Central do Brasil PIX manual, SPAYD), wrong checksums, and round-trips.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

BarcodeContent _parse(String text) => BarcodeContent.parseText(text);

void _roundTrips(BarcodeContent content) {
  final String payload = content.toPayload();
  expect(_parse(payload), content, reason: payload);
}

Matcher _issue(String field) => contains(
  isA<ContentIssue>().having((ContentIssue i) => i.field, 'field', field),
);

const String _pixSample =
    '00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-426655440000'
    '5204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D';

void main() {
  group('EPC / SEPA', () {
    const String sample =
        'BCD\n002\n1\nSCT\nBHBLDEHHXXX\nFranz Mustermänn\n'
        'DE71110220330123456789\nEUR12.3\nGDDS\nRF18539007547034';

    test('the EPC069-12 example', () {
      final EpcPaymentContent epc = _parse(sample) as EpcPaymentContent;
      expect(epc.name, 'Franz Mustermänn');
      expect(epc.iban, 'DE71110220330123456789');
      expect(epc.bic, 'BHBLDEHHXXX');
      expect(epc.amount, '12.3');
      expect(epc.currency, 'EUR');
      expect(epc.purposeCode, 'GDDS');
      expect(epc.creditorReference, 'RF18539007547034');
      expect(epc.payee, 'Franz Mustermänn');
      expect(epc.reference, 'RF18539007547034');
    });

    test('a wrong IBAN check digit is not a payment', () {
      expect(_parse(sample.replaceFirst('DE71', 'DE72')), isA<TextContent>());
    });

    test('builds what it reads', () {
      const EpcPaymentContent epc = EpcPaymentContent(
        name: 'Kaffeehaus Lumen',
        iban: 'DE89370400440532013000',
        amount: '12.50',
        text: 'Invoice 42',
      );
      expect(
        epc.toPayload(),
        'BCD\n002\n1\nSCT\n\nKaffeehaus Lumen\nDE89370400440532013000\n'
        'EUR12.50\n\n\nInvoice 42',
      );
      _roundTrips(epc);
      _roundTrips(_parse(sample));
    });

    test('issues', () {
      expect(
        const EpcPaymentContent(
          name: '',
          iban: 'DE89370400440532013000',
        ).validate(),
        _issue('name'),
      );
      expect(
        const EpcPaymentContent(
          name: 'x',
          iban: 'DE00370400440532013000',
        ).validate(),
        _issue('iban'),
      );
      expect(
        const EpcPaymentContent(
          name: 'x',
          iban: 'DE89370400440532013000',
          amount: '1000000000',
        ).validate(),
        _issue('amount'),
      );
      expect(
        const EpcPaymentContent(
          name: 'x',
          iban: 'DE89370400440532013000',
          creditorReference: 'RF19539007547034',
        ).validate(),
        _issue('creditorReference'),
      );
      expect(
        const EpcPaymentContent(
          name: 'x',
          iban: 'DE89370400440532013000',
          creditorReference: 'RF18539007547034',
          text: 'both',
        ).validate(),
        _issue('text'),
      );
    });
  });

  group('Swiss QR-bill', () {
    final String sample = <String>[
      'SPC', '0200', '1', 'CH4431999123000889012', //
      'S', 'Robert Schneider AG', 'Rue du Lac', '1268', '2501', 'Biel', 'CH',
      '', '', '', '', '', '', '', //
      '1949.75', 'CHF', //
      'S', 'Pia-Maria Rutschmann-Schnyder', 'Grosse Marktgasse', '28', '9400',
      'Rorschach', 'CH', //
      'QRR', '210000000003139471430009017', 'Order of 15 June 2020', 'EPD',
      '//S1/10/10201409/11/200701/20/140.000-53/30/102673831/31/200615/32/7.7/33/7.7:0/40/0:30',
    ].join('\n');

    test('the Swiss Payment Standards example', () {
      final SwissQrBillContent bill = _parse(sample) as SwissQrBillContent;
      expect(bill.iban, 'CH4431999123000889012');
      expect(
        bill.creditor,
        const SwissAddress(
          name: 'Robert Schneider AG',
          street: 'Rue du Lac',
          buildingNumber: '1268',
          postalCode: '2501',
          town: 'Biel',
          country: 'CH',
        ),
      );
      expect(bill.amount, '1949.75');
      expect(bill.currency, 'CHF');
      expect(bill.debtor?.town, 'Rorschach');
      expect(bill.referenceType, SwissReferenceType.qrr);
      expect(bill.qrReference, '210000000003139471430009017');
      expect(bill.message, 'Order of 15 June 2020');
      expect(bill.billInformation, startsWith('//S1/10/'));
      expect(bill.validate(), isEmpty);
      expect(bill.toPayload(), sample);
    });

    test('a wrong QR reference check digit is not a payment', () {
      expect(
        _parse(sample.replaceFirst('430009017', '430009018')),
        isA<TextContent>(),
      );
    });

    test('combined addresses (type K) are read', () {
      final SwissQrBillContent bill =
          _parse(
                sample.replaceFirst(
                  'S\nRobert Schneider AG\nRue du Lac\n1268\n2501\nBiel\n',
                  'K\nRobert Schneider AG\nRue du Lac 1268\n2501 Biel\n\n\n',
                ),
              )
              as SwissQrBillContent;
      expect(bill.creditor.street, 'Rue du Lac 1268');
      expect(bill.creditor.postalCode, '2501');
      expect(bill.creditor.town, 'Biel');
    });

    test('builds with a creditor reference, without an amount', () {
      const SwissQrBillContent bill = SwissQrBillContent(
        iban: 'CH9300762011623852957',
        creditor: SwissAddress(
          name: 'Lumen Café',
          street: 'Bahnhofstrasse',
          buildingNumber: '1',
          postalCode: '8001',
          town: 'Zürich',
          country: 'CH',
        ),
        referenceType: SwissReferenceType.scor,
        qrReference: 'RF18539007547034',
      );
      expect(bill.validate(), isEmpty);
      _roundTrips(bill);
    });

    test('issues', () {
      const SwissAddress creditor = SwissAddress(
        name: 'x',
        postalCode: '8001',
        town: 'Zürich',
        country: 'CH',
      );
      // A QR-IBAN needs a QR reference, a QR reference a QR-IBAN.
      expect(
        const SwissQrBillContent(
          iban: 'CH4431999123000889012',
          creditor: creditor,
        ).validate(),
        _issue('iban'),
      );
      expect(
        const SwissQrBillContent(
          iban: 'CH9300762011623852957',
          creditor: creditor,
          referenceType: SwissReferenceType.qrr,
          qrReference: '210000000003139471430009017',
        ).validate(),
        _issue('iban'),
      );
      expect(
        const SwissQrBillContent(
          iban: 'DE89370400440532013000',
          creditor: creditor,
        ).validate(),
        _issue('iban'),
      );
      expect(
        const SwissQrBillContent(
          iban: 'CH9300762011623852957',
          creditor: creditor,
          amount: '12.5',
        ).validate(),
        _issue('amount'),
      );
      expect(
        const SwissQrBillContent(
          iban: 'CH9300762011623852957',
          creditor: creditor,
          currency: 'USD',
        ).validate(),
        _issue('currency'),
      );
    });
  });

  group('ГОСТ Р 56042-2014', () {
    final String sample = <String>[
      'ST00012',
      'Name=ООО «Три кита»',
      'PersonalAcc=40702810138250123017',
      'BankName=ОАО "БАНК"',
      'BIC=044525225',
      'CorrespAcc=30101810400000000225',
      'Sum=125050',
      'Purpose=Оплата по счёту № 7',
      'PayeeINN=7700000000',
      'KPP=770001001',
      'PersAcc=12345',
    ].join('|');

    test('the mandatory and the common fields', () {
      final GostPaymentContent gost = _parse(sample) as GostPaymentContent;
      expect(gost.name, 'ООО «Три кита»');
      expect(gost.personalAccount, '40702810138250123017');
      expect(gost.bankName, 'ОАО "БАНК"');
      expect(gost.bic, '044525225');
      expect(gost.correspondentAccount, '30101810400000000225');
      expect(gost.amount, '1250.50');
      expect(gost.currency, 'RUB');
      expect(gost.purpose, 'Оплата по счёту № 7');
      expect(gost.payeeInn, '7700000000');
      expect(gost.kpp, '770001001');
      expect(gost.extra, <String, String>{'PersAcc': '12345'});
      expect(gost.toPayload(), sample);
    });

    test('Windows-1251 and KOI8-R from the bytes', () {
      for (final (String flag, Encoding encoding) in <(String, Encoding)>[
        ('1', const _Cp1251()),
        ('3', const _Koi8r()),
      ]) {
        // KOI8-R has no « » or №: text both encodings can hold.
        final String text = sample
            .replaceFirst('ST00012', 'ST0001$flag')
            .replaceAll(RegExp('[«»№] ?'), '');
        final Barcode barcode = Barcode(
          format: BarcodeFormat.qrCode,
          // What a reader that guessed Latin-1 would make of the bytes.
          text: latin1.decode(encoding.encode(text), allowInvalid: true),
          bytes: Uint8List.fromList(encoding.encode(text)),
          position: const BarcodePosition(
            topLeft: Offset.zero,
            topRight: Offset.zero,
            bottomRight: Offset.zero,
            bottomLeft: Offset.zero,
          ),
        );
        final GostPaymentContent gost = barcode.content as GostPaymentContent;
        expect(gost.name, 'ООО Три кита', reason: flag);
        expect(gost.purpose, 'Оплата по счёту 7', reason: flag);
      }
    });

    test('another separator, keys in any case', () {
      final GostPaymentContent gost =
          _parse(
                'ST00012#name=Ромашка#personalacc=40702810138250123017#'
                'bankname=Банк#bic=044525225#correspacc=0#sum=100',
              )
              as GostPaymentContent;
      expect(gost.name, 'Ромашка');
      expect(gost.correspondentAccount, '0');
      expect(gost.amount, '1.00');
    });

    test('sums past 2^53 kopecks stay exact, on the web too', () {
      const GostPaymentContent big = GostPaymentContent(
        name: 'x',
        personalAccount: '40702810138250123017',
        bankName: 'b',
        bic: '044525225',
        correspondentAccount: '0',
        amount: '12345678901234.56',
      );
      expect(big.toPayload(), contains('|Sum=1234567890123456'));
      _roundTrips(big);
      expect(
        (_parse(
                  'ST00012|Name=x|PersonalAcc=40702810138250123017|BankName=b|'
                  'BIC=044525225|CorrespAcc=0|Sum=5',
                )
                as GostPaymentContent)
            .amount,
        '0.05',
      );
    });

    test('missing mandatory fields: not a payment', () {
      expect(_parse('ST00012|Name=X|BIC=044525225'), isA<TextContent>());
    });

    test('issues', () {
      const GostPaymentContent ok = GostPaymentContent(
        name: 'x',
        personalAccount: '40702810138250123017',
        bankName: 'b',
        bic: '044525225',
        correspondentAccount: '30101810400000000225',
      );
      expect(ok.validate(), isEmpty);
      _roundTrips(ok);
      expect(
        const GostPaymentContent(
          name: 'x|y',
          personalAccount: '123',
          bankName: 'b',
          bic: '1',
          correspondentAccount: '30101810400000000225',
        ).validate(),
        allOf(_issue('name'), _issue('personalAccount'), _issue('bic')),
      );
    });
  });

  group('UPI', () {
    test('a payment request', () {
      final UpiPaymentContent upi =
          _parse(
                'upi://pay?pa=shop@okbank&pn=Lumen+Cafe&am=150.00&cu=INR'
                '&tn=Order%2012&mode=02',
              )
              as UpiPaymentContent;
      expect(upi.address, 'shop@okbank');
      expect(upi.name, 'Lumen Cafe');
      expect(upi.amount, '150.00');
      expect(upi.currency, 'INR');
      expect(upi.note, 'Order 12');
      expect(upi.extra, <String, String>{'mode': '02'});
    });

    test('builds what it reads', () {
      const UpiPaymentContent upi = UpiPaymentContent(
        address: 'shop@okbank',
        name: 'Lumen Café',
        amount: '99.5',
        note: 'Table 4 & 5',
      );
      expect(
        upi.toPayload(),
        'upi://pay?pa=shop@okbank&pn=Lumen%20Caf%C3%A9&am=99.5&cu=INR'
        '&tn=Table%204%20%26%205',
      );
      _roundTrips(upi);
    });

    test('other currencies and bad addresses are not UPI', () {
      expect(_parse('upi://pay?pa=a@b&cu=USD'), isA<TextContent>());
      expect(_parse('upi://pay?pa=nobody'), isA<TextContent>());
    });
  });

  group('EMVCo', () {
    test('the PIX manual example', () {
      final EmvPaymentContent pix = _parse(_pixSample) as EmvPaymentContent;
      expect(pix.scheme, EmvScheme.pix);
      expect(pix.pixKey, '123e4567-e12b-12d1-a456-426655440000');
      expect(pix.merchantName, 'Fulano de Tal');
      expect(pix.merchantCity, 'BRASILIA');
      expect(pix.currency, 'BRL');
      expect(pix.countryCode, 'BR');
      expect(pix.amount, isNull);
      expect(pix.reference, isNull);
      expect(pix.toPayload(), _pixSample);
    });

    test('EmvPaymentContent.pix builds the example', () {
      expect(
        EmvPaymentContent.pix(
          key: '123e4567-e12b-12d1-a456-426655440000',
          name: 'Fulano de Tal',
          city: 'BRASILIA',
        ).toPayload(),
        _pixSample,
      );
      final EmvPaymentContent paid = EmvPaymentContent.pix(
        key: 'fulano@example.com',
        name: 'Fulano de Tal',
        city: 'SAO PAULO',
        amount: '10.50',
        txid: 'PEDIDO42',
      );
      _roundTrips(paid);
      expect(paid.reference, 'PEDIDO42');
      expect(paid.amount, '10.50');
    });

    test('a wrong checksum is not a payment', () {
      expect(
        _parse(_pixSample.replaceFirst('1D3D', '1D3E')),
        isA<TextContent>(),
      );
    });

    test('schemes from the merchant account', () {
      EmvScheme scheme(String id, String gui) =>
          EmvPaymentContent(<String, String>{
            '00': '01',
            id: emvTemplateForTest(gui),
            '52': '0000',
            '53': '702',
            '58': 'SG',
            '59': 'Shop',
            '60': 'City',
          }).scheme;
      expect(scheme('26', 'SG.PAYNOW'), EmvScheme.payNow);
      expect(scheme('29', 'A000000677010111'), EmvScheme.promptPay);
      expect(scheme('51', 'ID.CO.QRIS.WWW'), EmvScheme.qris);
      expect(scheme('38', 'A000000727'), EmvScheme.vietQr);
      expect(scheme('26', 'MY.COM.PAYNET'), EmvScheme.duitNow);
      expect(scheme('26', 'COM.EXAMPLE'), EmvScheme.unknown);
    });

    test('issues', () {
      expect(
        EmvPaymentContent.pix(
          key: 'k',
          name: 'A name longer than twenty-five',
          city: 'X',
        ).validate(),
        _issue('fields'),
      );
      expect(
        const EmvPaymentContent(<String, String>{'00': '01'}).validate(),
        _issue('fields'),
      );
    });
  });

  group('SPAYD', () {
    const String sample =
        'SPD*1.0*ACC:CZ5855000000001265098001*AM:480.50*CC:CZK*'
        'MSG:PLATBA ZA ZBOZI*X-VS:1234567890';

    test('the specification example', () {
      final SpaydPaymentContent spayd = _parse(sample) as SpaydPaymentContent;
      expect(spayd.iban, 'CZ5855000000001265098001');
      expect(spayd.amount, '480.50');
      expect(spayd.currency, 'CZK');
      expect(spayd.message, 'PLATBA ZA ZBOZI');
      expect(spayd.variableSymbol, '1234567890');
      expect(spayd.toPayload(), sample);
    });

    test('a BIC, a due date, a star in a value, an unknown key', () {
      final SpaydPaymentContent spayd = SpaydPaymentContent(
        iban: 'CZ5855000000001265098001',
        bic: 'RZBCCZPP',
        amount: '10',
        message: 'A * B',
        dueDate: DateTime(2026, 12, 31),
        extra: const <String, String>{'X-PER': '7'},
      );
      expect(
        spayd.toPayload(),
        <String>[
          'SPD', '1.0', 'ACC:CZ5855000000001265098001+RZBCCZPP', 'AM:10', //
          'MSG:A %2A B', 'DT:20261231', 'X-PER:7',
        ].join('*'),
      );
      _roundTrips(spayd);
    });

    test('issues', () {
      expect(
        const SpaydPaymentContent(
          iban: 'CZ5855000000001265098001',
          variableSymbol: '12345678901',
        ).validate(),
        _issue('variableSymbol'),
      );
    });
  });

  test('every payment answers the common questions', () {
    for (final String payload in <String>[_pixSample]) {
      final PaymentContent p = _parse(payload) as PaymentContent;
      expect(p.payee, isNotNull);
      expect(p.currency, isNotNull);
    }
  });
}

/// A template with only a globally unique identifier.
String emvTemplateForTest(String gui) =>
    '00${gui.length.toString().padLeft(2, '0')}$gui';

/// Windows-1251 for the test: Cyrillic letters, «», №, the rest ASCII.
class _Cp1251 extends Encoding {
  const _Cp1251();

  @override
  String get name => 'windows-1251';

  @override
  Converter<List<int>, String> get decoder => throw UnimplementedError();

  @override
  Converter<String, List<int>> get encoder => const _TableEncoder(
    <int, int>{
      0x00AB: 0xAB,
      0x00BB: 0xBB,
      0x2116: 0xB9,
      0x0401: 0xA8,
      0x0451: 0xB8,
    },
    0x0410,
    0xC0,
  );
}

/// KOI8-R for the test.
class _Koi8r extends Encoding {
  const _Koi8r();

  @override
  String get name => 'koi8-r';

  @override
  Converter<List<int>, String> get decoder => throw UnimplementedError();

  @override
  Converter<String, List<int>> get encoder => const _Koi8Encoder();
}

class _TableEncoder extends Converter<String, List<int>> {
  const _TableEncoder(this.extra, this.first, this.firstByte);

  final Map<int, int> extra;
  final int first;
  final int firstByte;

  @override
  List<int> convert(String input) => <int>[
    for (final int r in input.runes)
      if (r < 0x80)
        r
      else if (extra[r] case final int b)
        b
      else if (r >= first && r < first + 64)
        firstByte + r - first
      else
        0x3F,
  ];
}

class _Koi8Encoder extends Converter<String, List<int>> {
  const _Koi8Encoder();

  static const String _upper =
      'юабцдефгхийклмнопярстужвьызшэщчъЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧЪ';

  @override
  List<int> convert(String input) => <int>[
    for (final String c in input.split(''))
      if (c.codeUnitAt(0) < 0x80)
        c.codeUnitAt(0)
      else if (_upper.indexOf(c) case final int i when i >= 0)
        0xC0 + i
      else if (c == 'ё')
        0xA3
      else if (c == '«' || c == '»' || c == '№')
        0x3F
      else
        0x3F,
  ];
}
