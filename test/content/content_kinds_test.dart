// The content kinds added for 4.0 rc.2: one-time passwords, eSIM,
// cryptocurrencies, Wi-Fi Easy Connect, service links, FaceTime, products,
// boarding passes, driver's licenses, VINs and smart home setup codes.
// Samples are the examples of the specifications named in each group.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

const BarcodePosition _nowhere = BarcodePosition(
  topLeft: Offset.zero,
  topRight: Offset.zero,
  bottomRight: Offset.zero,
  bottomLeft: Offset.zero,
);

BarcodeContent _read(
  String text, [
  BarcodeFormat format = BarcodeFormat.qrCode,
]) => Barcode(
  format: format,
  text: text,
  bytes: Uint8List.fromList(utf8.encode(text)),
  position: _nowhere,
).content;

BarcodeContent _parse(String text) => BarcodeContent.parseText(text);

void _roundTrips(BarcodeContent content) {
  final String payload = content.toPayload();
  expect(_parse(payload), content, reason: payload);
}

Matcher _issue(String field) => contains(
  isA<ContentIssue>().having((ContentIssue i) => i.field, 'field', field),
);

void main() {
  group('one-time password (Google Authenticator Key URI)', () {
    test('the specification example', () {
      expect(
        _parse(
          'otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP'
          '&issuer=Example',
        ),
        const OtpContent(
          secret: 'JBSWY3DPEHPK3PXP',
          account: 'alice@google.com',
          issuer: 'Example',
        ),
      );
    });

    test('all parameters, HOTP, an encoded label', () {
      expect(
        _parse(
          <String>[
            'otpauth://hotp/ACME%20Co:john.doe%40email.com?secret=hxdm vjec',
            '&algorithm=SHA256&digits=8&counter=7',
          ].join(),
        ),
        const OtpContent(
          secret: 'HXDMVJEC',
          account: 'john.doe@email.com',
          issuer: 'ACME Co',
          type: OtpType.hotp,
          algorithm: OtpAlgorithm.sha256,
          digits: 8,
          counter: 7,
        ),
      );
    });

    test('builds what it reads', () {
      const OtpContent otp = OtpContent(
        secret: 'JBSWY3DPEHPK3PXP',
        account: 'alice@google.com',
        issuer: 'Big Corp',
      );
      expect(
        otp.toPayload(),
        'otpauth://totp/Big%20Corp:alice@google.com?secret=JBSWY3DPEHPK3PXP'
        '&issuer=Big%20Corp',
      );
      _roundTrips(otp);
      _roundTrips(
        const OtpContent(
          secret: 'GEZDGNBV',
          account: 'me',
          algorithm: OtpAlgorithm.sha512,
          digits: 7,
          period: 60,
        ),
      );
      _roundTrips(
        const OtpContent(secret: 'GEZDGNBV', account: 'me', type: OtpType.hotp),
      );
    });

    test('the secret is not in toString', () {
      expect(
        const OtpContent(secret: 'JBSWY3DPEHPK3PXP', account: 'a').toString(),
        isNot(contains('JBSWY3DPEHPK3PXP')),
      );
    });

    test('not Base32, unknown type or algorithm: text', () {
      expect(_parse('otpauth://totp/a?secret=abc1'), isA<TextContent>());
      expect(_parse('otpauth://xotp/a?secret=ABC'), isA<TextContent>());
      expect(
        _parse('otpauth://totp/a?secret=ABC&algorithm=MD5'),
        isA<TextContent>(),
      );
    });

    test('issues', () {
      expect(
        const OtpContent(secret: '', account: 'a').validate(),
        _issue('secret'),
      );
      expect(
        const OtpContent(secret: 'ABC8', account: 'a').validate(),
        _issue('secret'),
      );
      expect(
        const OtpContent(secret: 'ABC', account: ' ').validate(),
        _issue('account'),
      );
      expect(
        const OtpContent(secret: 'ABC', account: 'a', issuer: 'x:y').validate(),
        _issue('issuer'),
      );
      expect(
        const OtpContent(secret: 'ABC', account: 'a', digits: 4).validate(),
        _issue('digits'),
      );
    });
  });

  group('eSIM (GSMA SGP.22)', () {
    test('activation codes', () {
      expect(
        _parse(r'LPA:1$rsp.example.com$QRF-BETTERROAMING-PMRDGIR2EARDEIT5'),
        const EsimContent(
          smdpAddress: 'rsp.example.com',
          matchingId: 'QRF-BETTERROAMING-PMRDGIR2EARDEIT5',
        ),
      );
      expect(
        _parse(r'LPA:1$smdp.example.com$04386-AGYFT-A74Y8-3F815$1.3.6.1.4.1$1'),
        const EsimContent(
          smdpAddress: 'smdp.example.com',
          matchingId: '04386-AGYFT-A74Y8-3F815',
          oid: '1.3.6.1.4.1',
          confirmationCodeRequired: true,
        ),
      );
      expect(_parse(r'LPA:2$x$y'), isA<TextContent>());
    });

    test('builds what it reads', () {
      const EsimContent esim = EsimContent(
        smdpAddress: 'rsp.example.com',
        matchingId: 'ABC-123',
      );
      expect(esim.toPayload(), r'LPA:1$rsp.example.com$ABC-123');
      _roundTrips(esim);
      _roundTrips(
        const EsimContent(
          smdpAddress: 'rsp.example.com',
          matchingId: 'ABC',
          confirmationCodeRequired: true,
        ),
      );
      _roundTrips(const EsimContent(smdpAddress: 'a.b', oid: '1.2.3'));
    });

    test('issues', () {
      expect(
        const EsimContent(smdpAddress: '').validate(),
        _issue('smdpAddress'),
      );
      expect(
        const EsimContent(smdpAddress: 'a', matchingId: r'x$y').validate(),
        _issue('matchingId'),
      );
    });
  });

  group('cryptocurrency (BIP 21, EIP-681)', () {
    test('the BIP 21 example', () {
      expect(
        _parse(
          'bitcoin:175tWpb8K1S7NmH4Zx6rewF9WQrcZv245W?amount=50&label=Luke-Jr'
          '&message=Donation%20for%20project%20xyz',
        ),
        const CryptoContent(
          currency: CryptoCurrency.bitcoin,
          address: '175tWpb8K1S7NmH4Zx6rewF9WQrcZv245W',
          amount: '50',
          label: 'Luke-Jr',
          message: 'Donation for project xyz',
        ),
      );
    });

    test('upper case for QR alphanumeric mode, Litecoin', () {
      expect(
        _parse('BITCOIN:BC1QAR0SRRR7XFKVY5L643LYDNW9RE59GTZZWF5MDQ'),
        const CryptoContent(
          currency: CryptoCurrency.bitcoin,
          address: 'BC1QAR0SRRR7XFKVY5L643LYDNW9RE59GTZZWF5MDQ',
        ),
      );
      expect(
        (_parse('litecoin:LQ3B36Yv2rBTxdgAdYpU2UcEZsaNwXeATk?amount=1.5')
                as CryptoContent)
            .currency,
        CryptoCurrency.litecoin,
      );
    });

    test('the EIP-681 examples', () {
      expect(
        _parse(
          'ethereum:0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359?value=2.014e18',
        ),
        const CryptoContent(
          currency: CryptoCurrency.ethereum,
          address: '0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359',
          amount: '2.014',
          value: '2.014e18',
        ),
      );
      expect(
        _parse('ethereum:pay-0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359@137'),
        const CryptoContent(
          currency: CryptoCurrency.ethereum,
          address: '0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359',
          chainId: 137,
        ),
      );
      // A token transfer pays the address in the parameters, not the
      // contract: not a payment to CryptoContent.address.
      expect(
        _parse(
          'ethereum:0x89205a3a3b2a69de6dbf7f01ed13b2108b2c43e7/transfer'
          '?address=0x8e23ee67d1332ad560396262c48ffbb01f93d052&uint256=1',
        ),
        isA<TextContent>(),
      );
    });

    test('Ethereum amounts are in ether, divided as text', () {
      String? ether(String value) =>
          (_parse('ethereum:0xab?value=$value') as CryptoContent).amount;
      expect(ether('1000000000000000000'), '1');
      expect(ether('1e18'), '1');
      expect(ether('1.5e17'), '0.15');
      expect(ether('20000000000000000'), '0.02');
      expect(ether('1'), '0.000000000000000001');
      expect(ether('1.5'), '0.0000000000000000015');
      expect(ether('0'), '0');
      expect(
        ether('123456789012345678901234567890'),
        '123456789012.34567890123456789',
      );
      // Past what 256 bits hold, or no number: text.
      expect(_parse('ethereum:0xab?value=1e100'), isA<TextContent>());
      expect(_parse('ethereum:0xab?value=1e99999999999'), isA<TextContent>());
      expect(_parse('ethereum:0xab?value=0x10'), isA<TextContent>());
    });

    test('Ethereum builds the amount in wei, or the value as written', () {
      const CryptoContent pay = CryptoContent(
        currency: CryptoCurrency.ethereum,
        address: '0xab',
        amount: '0.02',
      );
      expect(pay.toPayload(), 'ethereum:0xab?value=20000000000000000');
      expect(
        const CryptoContent(
          currency: CryptoCurrency.ethereum,
          address: '0xab',
          amount: '2.014',
          value: '2.014e18',
        ).toPayload(),
        'ethereum:0xab?value=2.014e18',
      );
      expect(
        const CryptoContent(
          currency: CryptoCurrency.ethereum,
          address: '0xab',
          amount: '2',
          value: '2.014e18',
        ).validate(),
        _issue('value'),
      );
      expect(
        const CryptoContent(
          currency: CryptoCurrency.bitcoin,
          address: 'x',
          value: '1',
        ).validate(),
        _issue('value'),
      );
      expect(
        const CryptoContent(
          currency: CryptoCurrency.ethereum,
          address: '0xab',
          amount: '0.0000000000000000001',
        ).validate(),
        _issue('amount'),
      );
    });

    test('Lightning invoices, bare and with the scheme', () {
      const String invoice =
          'lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4jsxqzpuaztrnwngzn3kdzw5hydlzf03qdgm2hdq27cqv3agm2awhz5se903vruatfhq77w3ls4evs3ch9zw97j25emudupq63nyw24cg27h2rspfj9srp';
      const CryptoContent lightning = CryptoContent(
        currency: CryptoCurrency.lightning,
        address: invoice,
      );
      expect(_parse(invoice), lightning);
      expect(_parse('lightning:$invoice'), lightning);
      expect(
        _parse('LIGHTNING:${invoice.toUpperCase()}'),
        isA<CryptoContent>(),
      );
      expect(lightning.toPayload(), 'lightning:$invoice');
    });

    test('builds what it reads', () {
      _roundTrips(
        const CryptoContent(
          currency: CryptoCurrency.bitcoin,
          address: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
          amount: '0.0015',
          label: 'Café & co',
          message: 'Order #12',
        ),
      );
      _roundTrips(
        const CryptoContent(
          currency: CryptoCurrency.ethereum,
          address: '0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359',
          amount: '1.5',
          value: '1500000000000000000',
          chainId: 1,
        ),
      );
    });

    test('issues', () {
      expect(
        const CryptoContent(
          currency: CryptoCurrency.bitcoin,
          address: 'x',
          amount: '0.123456789',
        ).validate(),
        _issue('amount'),
      );
      expect(
        const CryptoContent(
          currency: CryptoCurrency.ethereum,
          address: 'x',
          label: 'L',
        ).validate(),
        _issue('label'),
      );
      expect(
        const CryptoContent(
          currency: CryptoCurrency.lightning,
          address: 'not an invoice',
        ).validate(),
        _issue('address'),
      );
      expect(
        const CryptoContent(
          currency: CryptoCurrency.bitcoin,
          address: 'x',
          chainId: 1,
        ).validate(),
        _issue('chainId'),
      );
    });
  });

  group('Wi-Fi Easy Connect (DPP)', () {
    test('the specification example', () {
      const String dpp =
          'DPP:C:81/1,115/36;M:5254005828e5;I:SN4321;'
          'K:MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgADM2206avxHJaHXgLMkq/24e0rsrfMP9K1Tm8gx+ovP0I=;;';
      expect(
        _parse(dpp),
        const WifiDppContent(
          publicKey:
              'MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgADM2206avxHJaHXgLMkq/24e0rsrfMP9K1Tm8gx+ovP0I=',
          channels: '81/1,115/36',
          macAddress: '5254005828e5',
          information: 'SN4321',
          raw: dpp,
        ),
      );
      expect(_parse(dpp).toPayload(), dpp);
      expect(_parse('DPP:C:81/1;;'), isA<TextContent>());
    });
  });

  group('service links', () {
    String sample(LinkService s) => switch (s.input) {
      LinkServiceInput.phone => '+374 91 234567',
      LinkServiceInput.username => '@flutter.dev',
      LinkServiceInput.id => s == LinkService.appStore ? '123456789' : 'ABC123',
      LinkServiceInput.query => 'Republic Square, Yerevan',
    };

    test('every service recognises its own links', () {
      for (final LinkService service in LinkService.values) {
        final UrlContent link = service.link(sample(service));
        expect(link.service, service, reason: '${link.url}');
        expect(link.validate(), isEmpty, reason: '${link.url}');
        expect(_parse(link.toPayload()), link, reason: '${link.url}');
      }
    });

    test('links', () {
      expect(
        LinkService.whatsApp.link('+374 91 234567', message: 'Hi & bye').url,
        Uri.parse('https://wa.me/37491234567?text=Hi+%26+bye'),
      );
      expect(
        LinkService.instagram.link('@flutter.dev').url,
        Uri.parse('https://www.instagram.com/flutter.dev'),
      );
      expect(
        LinkService.reddit.link('r/FlutterDev').url,
        Uri.parse('https://www.reddit.com/r/FlutterDev'),
      );
      expect(
        LinkService.spotify.link('spotify:artist:0TnOYISbd1XYRBk9myaseg').url,
        Uri.parse('https://open.spotify.com/artist/0TnOYISbd1XYRBk9myaseg'),
      );
      expect(
        LinkService.appStore.link('id284882215').url,
        Uri.parse('https://apps.apple.com/app/id284882215'),
      );
      expect(
        LinkService.googlePlay.link('com.whatsapp').url,
        Uri.parse('https://play.google.com/store/apps/details?id=com.whatsapp'),
      );
    });

    test('a whole link to the service is taken as it is', () {
      const String url = 'https://www.instagram.com/p/C1234/';
      expect(LinkService.instagram.link(url).url, Uri.parse(url));
    });

    test('bad input throws', () {
      expect(() => LinkService.whatsApp.link('call me'), throwsArgumentError);
      expect(() => LinkService.telegram.link(' '), throwsArgumentError);
      expect(() => LinkService.x.link('a b'), throwsArgumentError);
      expect(
        () => LinkService.telegram.link('a', message: 'm'),
        throwsArgumentError,
      );
    });

    test('recognised by host', () {
      LinkService? of(String url) => UrlContent(Uri.parse(url)).service;
      expect(of('https://twitter.com/dart_lang'), LinkService.x);
      expect(of('https://youtu.be/dQw4w9WgXcQ'), LinkService.youTube);
      expect(of('https://m.facebook.com/x'), LinkService.facebook);
      expect(of('https://vm.tiktok.com/abc'), LinkService.tikTok);
      expect(of('https://maps.app.goo.gl/abc'), LinkService.googleMaps);
      expect(of('https://www.google.de/maps/place/x'), LinkService.googleMaps);
      expect(
        of('https://search.google.com/local/writereview?placeid=x'),
        LinkService.googleReview,
      );
      expect(of('https://yandex.ru/maps/?text=x'), LinkService.yandexMaps);
      expect(of('https://apps.apple.com/us/app/x/id1'), LinkService.appStore);
      expect(of('https://music.apple.com/us/album/x'), LinkService.appleMusic);
      expect(of('https://www.google.com/search?q=x'), isNull);
      expect(of('https://notinstagram.com/x'), isNull);
      expect(of('https://pub.dev'), isNull);
    });

    test('the result sheet names the service', () {
      expect(
        ScannerLocalizationsEn().kindOf(LinkService.telegram.link('dart')),
        'Telegram',
      );
    });
  });

  group('FaceTime', () {
    test('parsed into PhoneContent', () {
      expect(
        _parse('facetime:+14085551234'),
        const PhoneContent('+14085551234', type: CallType.faceTime),
      );
      expect(
        _parse('facetime-audio://user@icloud.com'),
        const PhoneContent('user@icloud.com', type: CallType.faceTimeAudio),
      );
    });

    test('builds what it reads', () {
      const PhoneContent call = PhoneContent(
        'user@icloud.com',
        type: CallType.faceTime,
      );
      expect(call.toPayload(), 'facetime:user@icloud.com');
      _roundTrips(call);
      _roundTrips(
        const PhoneContent('+14085551234', type: CallType.faceTimeAudio),
      );
      expect(
        const PhoneContent('user@icloud.com').validate(),
        _issue('number'),
      );
    });
  });

  group('products', () {
    test('EAN-13 book: ISBN-13 and ISBN-10', () {
      final ProductContent book =
          _read('9780306406157', BarcodeFormat.ean13) as ProductContent;
      expect(book.gtin, '09780306406157');
      expect(book.number, '9780306406157');
      expect(book.isbn13, '9780306406157');
      expect(book.isbn10, '0306406152');
      expect(book.issn, isNull);
      expect(book.toPayload(), '9780306406157');
    });

    test('EAN-13 periodical: ISSN, with the add-on', () {
      final ProductContent magazine =
          _read('977031784700105', BarcodeFormat.ean13) as ProductContent;
      expect(magazine.issn, '0317-8471');
      expect(magazine.addOn, '05');
      expect(magazine.isbn13, isNull);
    });

    test('UPC-A, EAN-8; digits in other formats are text', () {
      expect(
        _read('036000291452', BarcodeFormat.upcA),
        const ProductContent(
          gtin: '00036000291452',
          number: '036000291452',
          raw: '036000291452',
        ),
      );
      expect(
        (_read('96385074', BarcodeFormat.ean8) as ProductContent).gtin,
        '00000096385074',
      );
      expect(_read('9780306406157', BarcodeFormat.code128), isA<TextContent>());
      expect(_parse('9780306406157'), isA<TextContent>());
    });
  });

  group('UPC-E', () {
    test('the GTIN is the expanded UPC-A, the number as printed', () {
      final ProductContent upcE =
          _read('01234565', BarcodeFormat.upcE) as ProductContent;
      expect(upcE.number, '01234565');
      expect(upcE.gtin, '00012345000065');
    });

    test('every last digit expands by its rule', () {
      // Number system 0, digits 123450..123459, check digit left as given.
      for (final (String upcE, String upcA) in <(String, String)>[
        ('01234500', '012000003450'),
        ('01234510', '012100003450'),
        ('01234520', '012200003450'),
        ('01234530', '012300000450'),
        ('01234540', '012340000050'),
        ('01234550', '012345000050'),
        ('11234590', '112345000090'),
      ]) {
        expect(
          (_read(upcE, BarcodeFormat.upcE) as ProductContent).gtin,
          '00$upcA',
          reason: upcE,
        );
      }
    });

    test('an 8-digit UPC-E that cannot be one is text', () {
      expect(_read('21234565', BarcodeFormat.upcE), isA<TextContent>());
    });
  });

  group('boarding pass (IATA BCBP)', () {
    test('one leg', () {
      final String text =
          'M1${'ZXING/FLUTTER'.padRight(20)}EE7QK3TPZRHAMSLX 0423 318Y012C0034 100';
      expect(
        _parse(text),
        BoardingPassContent(
          passengerName: 'ZXING/FLUTTER',
          electronicTicket: true,
          legs: const <BoardingPassLeg>[
            BoardingPassLeg(
              bookingReference: 'E7QK3TP',
              from: 'ZRH',
              to: 'AMS',
              carrier: 'LX',
              flightNumber: '423',
              dayOfYear: 318,
              cabin: 'Y',
              seat: '12C',
              sequenceNumber: '34',
            ),
          ],
          raw: text,
        ),
      );
    });

    test('two legs, airline data after the first', () {
      final String text = <String>[
        'M2${'DESMARAIS/LUC'.padRight(20)}',
        'EABC123 YULFRAAC 0834 326J001A0025 106',
        'XYZ789',
        'DEF456 FRAGVALH 3664 327C012C0026 100',
      ].join();
      final BoardingPassContent pass = _parse(text) as BoardingPassContent;
      expect(pass.legs, hasLength(2));
      expect(pass.legs[1].from, 'FRA');
      expect(pass.legs[1].to, 'GVA');
      expect(pass.legs[1].carrier, 'LH');
      expect(
        pass.legs[1].date(now: DateTime(2026, 11, 20)),
        DateTime(2026, 11, 23),
      );
      expect(pass.toPayload(), text);
    });

    group('the date of a leg', () {
      BoardingPassLeg leg(int? day) => BoardingPassLeg(
        bookingReference: 'ABC123',
        from: 'EVN',
        to: 'VIE',
        carrier: 'OS',
        flightNumber: '642',
        dayOfYear: day,
        cabin: 'Y',
        seat: '',
        sequenceNumber: '1',
      );

      test('in the year of today', () {
        expect(
          leg(140).date(now: DateTime(2026, 5, 1, 23, 59)),
          DateTime(2026, 5, 20),
        );
      });

      test('2 January scanned on 30 December is next year', () {
        expect(leg(2).date(now: DateTime(2026, 12, 30)), DateTime(2027, 1, 2));
      });

      test('30 December scanned on 2 January was last year', () {
        expect(
          leg(364).date(now: DateTime(2027, 1, 2)),
          DateTime(2026, 12, 30),
        );
      });

      test('day 60 is 29 February in a leap year, 1 March otherwise', () {
        expect(leg(60).date(now: DateTime(2028, 2, 10)), DateTime(2028, 2, 29));
        expect(
          leg(60).date(now: DateTime(2027, 2, 10)),
          DateTime(2027, 3),
        ); // 1 March
      });

      test('day 366 falls only in a leap year', () {
        expect(
          leg(366).date(now: DateTime(2029, 1, 3)),
          DateTime(2028, 12, 31),
        );
        expect(
          leg(366).date(now: DateTime(2028, 12, 20)),
          DateTime(2028, 12, 31),
        );
        // None of 2025, 2026 and 2027 has a day 366.
        expect(leg(366).date(now: DateTime(2026, 6, 10)), isNull);
      });

      test('no day, no date', () {
        expect(leg(null).date(), isNull);
      });

      test('today by default', () {
        final DateTime now = DateTime.now();
        final DateTime today = DateTime(now.year, now.month, now.day);
        final int day =
            DateTime.utc(
              now.year,
              now.month,
              now.day,
            ).difference(DateTime.utc(now.year)).inDays +
            1;
        expect(leg(day).date(), today);
      });
    });

    test('other text starting with M is not a pass', () {
      expect(_parse('M1${'x' * 60}'), isA<TextContent>());
    });
  });

  group("driver's license (AAMVA)", () {
    test('a 2016 card', () {
      const String text =
          '@\n\x1e\rANSI 636014080102DL00410288ZC03290015DLDAQD1234562\n'
          'DCSPUBLIC\nDDEN\nDACJOHN\nDDFN\nDADQUINCY\nDDGN\nDCAC\nDCBNONE\n'
          'DCDNONE\nDBD08312013\nDBB08311977\nDBA08312020\nDBC1\nDAU069 IN\n'
          'DAG123 MAIN STREET\nDAIANYTOWN\nDAJCA\nDAK902230000  \nDCGUSA\r';
      final DriverLicenseContent id = _parse(text) as DriverLicenseContent;
      expect(id.licenseNumber, 'D1234562');
      expect(id.firstName, 'JOHN');
      expect(id.middleName, 'QUINCY');
      expect(id.lastName, 'PUBLIC');
      expect(id.birthDate, DateTime(1977, 8, 31));
      expect(id.issueDate, DateTime(2013, 8, 31));
      expect(id.expiryDate, DateTime(2020, 8, 31));
      expect(id.street, '123 MAIN STREET');
      expect(id.city, 'ANYTOWN');
      expect(id.state, 'CA');
      expect(id.postalCode, '90223');
      expect(id.country, 'USA');
      expect(id.toString(), isNot(contains('JOHN')));
    });

    test('Canadian dates are year first', () {
      const String text =
          '@\n\x1e\rANSI 636012080102DL00410200ZO02410023DLDAQX1234\n'
          'DCSDOE\nDACJANE\nDBB19900517\nDCGCAN\r';
      expect(
        (_parse(text) as DriverLicenseContent).birthDate,
        DateTime(1990, 5, 17),
      );
    });
  });

  group('VIN (ISO 3779)', () {
    test('a North American VIN', () {
      final VinContent vin = _parse('1M8GDM9AXKP042788') as VinContent;
      expect(vin.wmi, '1M8');
      expect(vin.region, VinRegion.northAmerica);
      expect(vin.hasValidCheckDigit, isTrue);
      expect(vin.modelYear, 1989);
      expect(vin.toPayload(), '1M8GDM9AXKP042788');
    });

    test('2010 and later model years', () {
      expect((_parse('1FTFW1ET9DFC10312') as VinContent).modelYear, 2013);
    });

    test('a European VIN only from a Code 39 label', () {
      const String vin = 'WVWZZZ1JZXW000001';
      expect(_parse(vin), isA<TextContent>());
      final VinContent fromLabel =
          _read(vin, BarcodeFormat.code39) as VinContent;
      expect(fromLabel.region, VinRegion.europe);
      expect(fromLabel.hasValidCheckDigit, isFalse);
    });

    test('an import marker before the VIN', () {
      final VinContent vin =
          _read('I1M8GDM9AXKP042788', BarcodeFormat.code39) as VinContent;
      expect(vin.vin, '1M8GDM9AXKP042788');
      expect(vin.toPayload(), 'I1M8GDM9AXKP042788');
    });

    test('I, O and Q are not in VINs', () {
      expect(_parse('1M8GDM9AXKP04278O'), isA<TextContent>());
    });
  });

  group('smart home', () {
    test('the Matter specification example', () {
      expect(
        _parse('MT:Y.K9042C00KA0648G00'),
        const SmartHomeContent(
          platform: SmartHomePlatform.matter,
          setupCode: '20202021',
          vendorId: 0xFFF1,
          productId: 0x8000,
          discriminator: 3840,
          raw: 'MT:Y.K9042C00KA0648G00',
        ),
      );
      expect(_parse('MT:Y.K9042C00KA0648G0'), isA<TextContent>());
    });

    test('HomeKit', () {
      // Category 5 (light), setup code 518-08-582, as an accessory encodes
      // it: setup code in bits 0–26, category from bit 31.
      const int value = 51808582 + 5 * 2147483648;
      final String payload =
          'X-HM://${value.toRadixString(36).toUpperCase().padLeft(9, '0')}7G2K';
      expect(
        _parse(payload),
        SmartHomeContent(
          platform: SmartHomePlatform.homeKit,
          setupCode: '518-08-582',
          category: 5,
          setupId: '7G2K',
          raw: payload,
        ),
      );
    });
  });
}
