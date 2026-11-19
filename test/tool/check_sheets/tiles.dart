// Part of check_sheets_test.dart: every code on the sheets.
part of '../check_sheets_test.dart';

/// How a tile's code is shown, beyond its style.
enum _Look { plain, rotated, mirrored, tiny }

/// One code on a sheet.
final class _Tile {
  const _Tile(
    this.title,
    this.data, {
    this.format = BarcodeFormat.qrCode,
    this.kind,
    this.note,
    this.gs1 = false,
    this.ecc,
    this.style = BarcodeStyle.classic,
    this.span = 1,
    this.look = _Look.plain,
    this.sample,
    this.bytes,
    this.codes,
    this.exact = true,
    this.warning = false,
    this.expect,
  });

  final String title;

  /// What the code holds: the payload drawn, or the text a sample holds.
  final String data;
  final BarcodeFormat format;

  /// The content kind the scanner should report, or null to not check.
  final Type? kind;

  /// What to look at when scanning: a template, a chip, a caveat.
  final String? note;
  final bool gs1;
  final ErrorCorrection? ecc;
  final BarcodeStyle style;

  /// Columns the tile takes: long linear and stacked codes take two.
  final int span;
  final _Look look;

  /// An image file to show instead of drawing (formats the writer lacks).
  final String? sample;

  /// Binary data to draw instead of [data].
  final Uint8List? bytes;

  /// Several QR codes in one tile (the pick template).
  final List<String>? codes;

  /// Whether the text read must equal [data] (not for GS1, where the
  /// reader puts separators in its own way).
  final bool exact;

  /// Highlights the note: the tile is expected to need something special.
  final bool warning;

  /// The text the reader gives when it differs from [data] by design
  /// (GS1 in parentheses, a Code 32 'A', a PZN '-').
  final String? expect;

  String get expectedText => expect ?? data;
}

/// A tile for [content]: its payload and its kind.
_Tile _content(
  String title,
  BarcodeContent content, {
  BarcodeFormat format = BarcodeFormat.qrCode,
  String? note,
  ErrorCorrection? ecc,
  BarcodeStyle style = BarcodeStyle.classic,
  int span = 1,
}) => _Tile(
  title,
  content.toPayload(),
  format: format,
  kind: content.runtimeType,
  note: note,
  ecc: ecc,
  style: style,
  span: span,
);

/// A GS1 tile: [content] written with FNC1 first.
_Tile _gs1(
  String title,
  Gs1Content content, {
  BarcodeFormat format = BarcodeFormat.dataMatrix,
  String? note,
  int span = 1,
}) => _Tile(
  title,
  content.toPayload(),
  format: format,
  gs1: true,
  kind: Gs1Content,
  note: note,
  span: span,
  exact: false,
);

/// A tile for a format the writer creates, with its documented example.
_Tile _format(
  BarcodeFormat format, {
  int span = 1,
  String? data,
  String? expect,
  String? note,
}) => _Tile(
  format.displayName,
  data ?? format.input!.example,
  format: format,
  span: span,
  expect: expect,
  note: note,
);

/// A tile from a zxing-cpp test image; the text is from its .txt file.
_Tile _sample(
  String title,
  BarcodeFormat format,
  String path, {
  int span = 1,
  bool exact = true,
}) {
  final File text = File(
    '$_samples/${path.substring(0, path.lastIndexOf('.'))}.txt',
  );
  return _Tile(
    title,
    text.existsSync() ? text.readAsStringSync() : '',
    format: format,
    sample: '$_samples/$path',
    span: span,
    exact: exact && text.existsSync(),
    note: 'Sample image from zxing-cpp: the writer does not make it',
  );
}

/// The check digit of a GTIN or SSCC without one (GS1 mod 10).
String _withCheck(String digits) {
  int sum = 0;
  for (int i = 0; i < digits.length; i++) {
    final int d = digits.codeUnitAt(digits.length - 1 - i) - 48;
    sum += i.isEven ? d * 3 : d;
  }
  return '$digits${(10 - sum % 10) % 10}';
}

/// An EMV tag-length-value list.
String _tlv(Map<String, String> fields) => fields.entries
    .map(
      (MapEntry<String, String> e) =>
          '${e.key}${e.value.length.toString().padLeft(2, '0')}${e.value}',
    )
    .join();

/// A section of the sheets: tiles under one heading, split into pages of
/// [_rows] rows.
typedef _Section = (String letter, String title, String about, List<_Tile>);

List<_Section> _sections(Uint8List logo) {
  final MemoryImage logoImage = MemoryImage(logo);
  const String gtin = '09501101530003';
  final String sscc = _withCheck('03761234500000001');
  final String homeKit =
      'X-HM://${(51808582 + 5 * 2147483648).toRadixString(36).toUpperCase().padLeft(9, '0')}7G2K';
  return <_Section>[
    (
      'A',
      'Formats · 2D',
      'Every matrix format. MaxiCode and QR Model 1 are read-only samples.',
      <_Tile>[
        _format(BarcodeFormat.qrCode),
        _format(BarcodeFormat.microQrCode),
        _format(BarcodeFormat.rmqrCode, span: 2),
        _format(BarcodeFormat.dataMatrix),
        _format(BarcodeFormat.aztec),
        _format(
          BarcodeFormat.aztecRune,
          expect: '025',
          note: 'Reads as three digits',
        ),
        _sample(
          'QR Code Model 1',
          BarcodeFormat.qrCode,
          'qrcode-1/qr-model-1.png',
        ),
        const _Tile(
          'MaxiCode',
          '',
          format: BarcodeFormat.maxiCode,
          sample: '$_samples/maxicode-1/MODE2.png',
          exact: false,
          warning: true,
          note:
              'zxing-cpp reads MaxiCode only from clean images, not from a camera',
        ),
      ],
    ),
    (
      'B',
      'Formats · stacked',
      'PDF417 family and the stacked DataBar variants.',
      <_Tile>[
        _format(BarcodeFormat.pdf417, span: 2),
        _format(BarcodeFormat.compactPdf417, span: 2),
        _format(BarcodeFormat.microPdf417, span: 2),
        _format(
          BarcodeFormat.dataBarStacked,
          expect: '(01)09501101530003',
          note: 'Reads as GS1: (01) GTIN',
        ),
        _format(
          BarcodeFormat.dataBarStackedOmni,
          expect: '(01)09501101530003',
          note: 'Reads as GS1: (01) GTIN',
        ),
        _format(
          BarcodeFormat.dataBarExpandedStacked,
          span: 2,
          expect: '(01)09501101530003(17)250101',
        ),
      ],
    ),
    (
      'C',
      'Formats · retail',
      'EAN/UPC as printed: UPC-A reads as 12 digits, UPC-E as 8.',
      <_Tile>[
        _format(BarcodeFormat.ean13),
        _format(BarcodeFormat.ean8),
        _format(BarcodeFormat.upcA),
        _format(BarcodeFormat.upcE),
        _format(BarcodeFormat.isbn, data: '9781234567897'),
        _sample(
          'EAN-13 + EAN-5 add-on',
          BarcodeFormat.ean13,
          'ean13-ext-1/1.png',
          exact: false,
        ),
        _format(
          BarcodeFormat.dataBar,
          expect: '(01)09501101530003',
          note: 'Reads as GS1: (01) GTIN',
        ),
        _format(
          BarcodeFormat.dataBarLimited,
          expect: '(01)09501101530003',
          note: 'Reads as GS1: (01) GTIN',
        ),
        _format(
          BarcodeFormat.dataBarExpanded,
          span: 2,
          expect: '(01)09501101530003(17)250101',
        ),
      ],
    ),
    (
      'D',
      'Formats · industrial',
      'Linear codes of logistics, pharmacy and film.',
      <_Tile>[
        _format(BarcodeFormat.code128),
        _format(BarcodeFormat.code39),
        _format(
          BarcodeFormat.code39Extended,
          span: 2,
          note: 'Lower case and punctuation as pairs of Code 39 characters',
        ),
        _format(BarcodeFormat.code93),
        _format(BarcodeFormat.codabar),
        _format(BarcodeFormat.itf),
        _format(
          BarcodeFormat.code32,
          expect: 'A123456788',
          note: 'Italian pharmacode, reads with an A',
        ),
        _format(
          BarcodeFormat.pzn,
          expect: '-12345678',
          note: 'German pharmacode, reads with a -',
        ),
        _format(BarcodeFormat.telepen, span: 2),
        _format(BarcodeFormat.dxFilmEdge),
      ],
    ),
    (
      'E',
      'Content · basics',
      'What the system camera of a phone also understands.',
      <_Tile>[
        _content(
          'Text, Unicode',
          const TextContent('Привет, 世界! 👋 flutter_zxing 4.0'),
        ),
        _content(
          'Link',
          UrlContent(Uri.parse('https://pub.dev/packages/flutter_zxing')),
        ),
        _content(
          'Wi‑Fi, WPA',
          const WifiContent(ssid: 'Lumen Guest', password: 'coffee-2026'),
          note: 'Phone camera: offers to join',
        ),
        _content(
          'Wi‑Fi, open and hidden',
          const WifiContent(
            ssid: 'Lumen Lab',
            security: WifiSecurity.none,
            hidden: true,
          ),
        ),
        _content(
          'Contact, vCard',
          ContactContent(
            name: 'Anna Petrosyan',
            organization: 'Lumen Café',
            title: 'Barista',
            phones: const <String>['+37491234567'],
            emails: const <String>['anna@example.com'],
            urls: <Uri>[Uri.parse('https://example.com')],
          ),
        ),
        const _Tile(
          'Contact, MECARD',
          'MECARD:N:Petrosyan,Anna;TEL:+37491234567;EMAIL:anna@example.com;;',
          kind: ContactContent,
        ),
        _content(
          'Email',
          const EmailContent(
            address: 'hello@example.com',
            subject: 'Hi',
            body: 'From the check sheet',
          ),
        ),
        _content('Phone', const PhoneContent('+37491234567')),
        _content(
          'SMS',
          const SmsContent(number: '+37491234567', message: 'See you at 7'),
        ),
        _content(
          'Location',
          const GeoContent(
            latitude: 40.1776,
            longitude: 44.5126,
            query: 'Republic Square',
          ),
        ),
        _content(
          'Event',
          EventContent(
            summary: 'flutter_zxing 4.0 launch',
            start: DateTime(2026, 12, 1, 18),
            end: DateTime(2026, 12, 1, 20),
            location: 'Yerevan',
          ),
          note: 'VCALENDAR without PRODID: check the phone camera adds it',
        ),
        _content(
          'FaceTime',
          const PhoneContent('+37491234567', type: CallType.faceTime),
        ),
      ],
    ),
    (
      'F',
      'Content · apps, security, smart home',
      'Kinds the content() template shows with their own sheet.',
      <_Tile>[
        _content(
          '2FA, TOTP',
          const OtpContent(
            issuer: 'Acme',
            account: 'anna@example.com',
            secret: 'JBSWY3DPEHPK3PXP',
          ),
          note: 'Secret hidden behind “Show”',
        ),
        _content(
          '2FA, HOTP · SHA-256 · 8 digits',
          const OtpContent(
            issuer: 'Acme',
            account: 'anna',
            secret: 'GEZDGNBVGY3TQOJQ',
            type: OtpType.hotp,
            algorithm: OtpAlgorithm.sha256,
            digits: 8,
            counter: 7,
          ),
        ),
        _content(
          'eSIM',
          const EsimContent(
            smdpAddress: 'rsp.example.com',
            matchingId: 'QRF-BETTERROAMING-PMRDGIR2EARDEIT5',
          ),
          note: 'Phone camera: offers to add the plan (do not confirm)',
        ),
        const _Tile(
          'Wi‑Fi Easy Connect (DPP)',
          'DPP:C:81/1,115/36;M:5254005828e5;I:SN4321;'
              'K:MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgADM2206avxHJaHXgLMkq/24e0rsrfMP9K1Tm8gx+ovP0I=;;',
          kind: WifiDppContent,
        ),
        const _Tile(
          'Matter',
          'MT:Y.K9042C00KA0648G00',
          kind: SmartHomeContent,
          note: 'Setup code 2020-2021',
        ),
        _Tile(
          'HomeKit',
          homeKit,
          kind: SmartHomeContent,
          note: 'Setup code 518-08-582, a light',
        ),
        _content(
          'Bitcoin',
          const CryptoContent(
            currency: CryptoCurrency.bitcoin,
            address: '175tWpb8K1S7NmH4Zx6rewF9WQrcZv245W',
            amount: '0.005',
            label: 'Lumen Café',
          ),
        ),
        const _Tile(
          'Ethereum, EIP-681',
          'ethereum:0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359?value=2.014e18',
          kind: CryptoContent,
        ),
        const _Tile(
          'Lightning invoice',
          'lightning:lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4jsxqzpuaztrnwngzn3kdzw5hydlzf03qdgm2hdq27cqv3agm2awhz5se903vruatfhq77w3ls4evs3ch9zw97j25emudupq63nyw24cg27h2rspfj9srp',
          kind: CryptoContent,
        ),
        _content(
          'WhatsApp chat',
          LinkService.whatsApp.link('+37491234567', message: 'Hi!'),
        ),
        _content('Telegram', LinkService.telegram.link('@flutterdev')),
        _content('App Store', LinkService.appStore.link('284882215')),
      ],
    ),
    (
      'G',
      'Content · industry',
      'Product numbers, travel documents and vehicles.',
      <_Tile>[
        _Tile(
          'Product, EAN-13',
          gtin.substring(1),
          format: BarcodeFormat.ean13,
          kind: ProductContent,
        ),
        const _Tile(
          'Book, ISBN',
          '9783161484100',
          format: BarcodeFormat.ean13,
          kind: ProductContent,
          note: 'Chip “ISBN”, ISBN-10 3-16-148410-X',
        ),
        _Tile(
          'Periodical, ISSN',
          _withCheck('977031784700'),
          format: BarcodeFormat.ean13,
          kind: ProductContent,
          note: 'ISSN 0317-8471',
        ),
        const _Tile(
          'VIN, North American, QR',
          '1M8GDM9AXKP042788',
          kind: VinContent,
          note: 'Model year 1989, check digit valid',
        ),
        _Tile(
          'Boarding pass, one leg',
          'M1${'ZXING/FLUTTER'.padRight(20)}EE7QK3TPZRHAMSLX 0423 318Y012C0034 100',
          format: BarcodeFormat.pdf417,
          kind: BoardingPassContent,
          span: 2,
          note: 'ZRH → AMS, LX 423, seat 12C',
        ),
        const _Tile(
          "Driver's license, AAMVA",
          '@\n\x1e\rANSI 636014080102DL00410288ZC03290015DLDAQD1234562\n'
              'DCSPUBLIC\nDDEN\nDACJOHN\nDDFN\nDADQUINCY\nDDGN\nDCAC\nDCBNONE\n'
              'DCDNONE\nDBD08312013\nDBB08311977\nDBA08312020\nDBC1\nDAU069 IN\n'
              'DAG123 MAIN STREET\nDAIANYTOWN\nDAJCA\nDAK902230000  \nDCGUSA\r',
          format: BarcodeFormat.pdf417,
          kind: DriverLicenseContent,
          span: 2,
          exact: false,
          note: 'JOHN QUINCY PUBLIC, expired 2020',
        ),
        _Tile(
          'Boarding pass, two legs',
          <String>[
            'M2${'DESMARAIS/LUC'.padRight(20)}',
            'EABC123 YULFRAAC 0834 326J001A0025 106',
            'XYZ789',
            'DEF456 FRAGVALH 3664 327C012C0026 100',
          ].join(),
          format: BarcodeFormat.aztec,
          kind: BoardingPassContent,
          note: 'Chips “Flight 1 of 2”',
        ),
        const _Tile(
          'VIN, European, Code 39',
          'WVWZZZ1JZXW000001',
          format: BarcodeFormat.code39,
          kind: VinContent,
          span: 2,
          note: 'vin() template; no check digit: a VIN only from Code 39',
        ),
      ],
    ),
    (
      'H',
      'Content · payments',
      'Examples from the specifications. Scan in a banking app, do not pay.',
      <_Tile>[
        const _Tile(
          'SEPA · EPC (GiroCode)',
          'BCD\n002\n1\nSCT\nBHBLDEHHXXX\nFranz Mustermänn\n'
              'DE71110220330123456789\nEUR12.3\nGDDS\nRF18539007547034',
          kind: EpcPaymentContent,
          ecc: ErrorCorrection.medium,
          note: '12.30 EUR · payment() template; banking app: EU',
        ),
        _Tile(
          'Swiss QR-bill',
          <String>[
            'SPC', '0200', '1', 'CH4431999123000889012', //
            'S',
            'Robert Schneider AG',
            'Rue du Lac',
            '1268',
            '2501',
            'Biel',
            'CH',
            '', '', '', '', '', '', '', //
            '1949.75', 'CHF', //
            'S',
            'Pia-Maria Rutschmann-Schnyder',
            'Grosse Marktgasse',
            '28',
            '9400',
            'Rorschach', 'CH', //
            'QRR',
            '210000000003139471430009017',
            'Order of 15 June 2020',
            'EPD',
          ].join('\n'),
          kind: SwissQrBillContent,
          style: BarcodeStyle.swissQrBill,
          ecc: ErrorCorrection.medium,
          note: '1 949.75 CHF, QR reference grouped as on the bill',
        ),
        _Tile(
          'ГОСТ Р 56042',
          <String>[
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
          ].join('|'),
          kind: GostPaymentContent,
          note: '1 250.50 RUB · banking app: Russia',
        ),
        const _Tile(
          'UPI',
          'upi://pay?pa=lumen@okaxis&pn=Lumen%20Cafe&am=120.00&cu=INR&tn=Coffee',
          kind: UpiPaymentContent,
        ),
        const _Tile(
          'PIX (Brazil)',
          '00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-426655440000'
              '5204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D',
          kind: EmvPaymentContent,
          note: 'Example from the BCB manual',
        ),
        _content(
          'PromptPay (Thailand), EMVCo',
          EmvPaymentContent(<String, String>{
            '00': '01',
            '01': '11',
            '29': _tlv(<String, String>{
              '00': 'A000000677010111',
              '01': '0066812345678',
            }),
            '52': '0000',
            '53': '764',
            '58': 'TH',
            '59': 'LUMEN CAFE',
            '60': 'BANGKOK',
          }),
        ),
        const _Tile(
          'SPAYD (Czechia)',
          'SPD*1.0*ACC:CZ5855000000001265098001*AM:480.50*CC:CZK*'
              'MSG:PLATBA ZA ZBOZI*X-VS:1234567890',
          kind: SpaydPaymentContent,
        ),
        const _Tile(
          'SEPA with a wrong IBAN',
          'BCD\n002\n1\nSCT\nBHBLDEHHXXX\nFranz Mustermänn\n'
              'DE72110220330123456789\nEUR12.3\nGDDS\nRF18539007547034',
          kind: TextContent,
          ecc: ErrorCorrection.medium,
          warning: true,
          note: 'Must NOT show a payment: the IBAN check digits are wrong',
        ),
      ],
    ),
    (
      'I',
      'Scanner templates',
      'Codes each new template is made for. Pick the template in the demo first.',
      <_Tile>[
        _gs1(
          'Medicine, GS1 Data Matrix',
          const Gs1Content(<String, String>{
            '01': gtin,
            '17': '281231',
            '10': 'AB1234',
            '21': 'SN000123',
          }),
          note: 'pharma(): GTIN, batch, expiry 31.12.2028, serial',
        ),
        _gs1(
          'Medicine, expired',
          const Gs1Content(<String, String>{
            '01': gtin,
            '17': '250600',
            '10': 'OLD42',
            '21': 'SN000999',
          }),
          note: 'pharma(): chip “Expired” (day 00 = 30.06.2025)',
        ),
        _gs1(
          'Pallet, GS1-128 SSCC',
          Gs1Content(<String, String>{'00': sscc, '02': gtin, '37': '24'}),
          format: BarcodeFormat.code128,
          span: 2,
          note: 'logistics(): SSCC, contents GTIN, 24 pieces',
        ),
        const _Tile(
          'Loyalty card, Code 128',
          '4006381333931',
          format: BarcodeFormat.code128,
          kind: TextContent,
          span: 2,
          style: BarcodeStyle(
            title: BarcodeCaption('Lumen Café · Friends', size: 0.07),
            caption: BarcodeCaption('4006 3813 3393 1', size: 0.06),
            card: BarcodeCard(color: Color(0xFFF4EFE4)),
          ),
          note: 'loyalty(): number large, in groups of 4',
        ),
        const _Tile(
          'Sign in',
          'https://example.com/device?code=WDJB-MJHT',
          kind: UrlContent,
          note: 'signIn(): QR only, closes on the first code',
        ),
        const _Tile(
          'Small Data Matrix',
          'SN 0042',
          format: BarcodeFormat.dataMatrix,
          kind: TextContent,
          look: _Look.tiny,
          note: 'small(): starts at 2× zoom',
        ),
        const _Tile(
          'Small Micro QR',
          'HELLO 42',
          format: BarcodeFormat.microQrCode,
          kind: TextContent,
          look: _Look.tiny,
          note: 'small()',
        ),
        _Tile(
          'Product for a form field',
          gtin.substring(1),
          format: BarcodeFormat.ean13,
          kind: ProductContent,
          note: '“Scan into a form”: the GTIN field takes it',
        ),
      ],
    ),
    (
      'J',
      'Check-in, kiosk and pick',
      'checkIn() / kiosk(): scan J1 → J4 in order. pick(): aim at J5, tap one code.',
      <_Tile>[
        const _Tile(
          'Ticket 001',
          'LUMEN CONF / TICKET 001 / ROW 5 SEAT 12',
          kind: TextContent,
          note: 'Accepted · “Welcome in”, counter 1',
        ),
        const _Tile(
          'Ticket 002',
          'LUMEN CONF / TICKET 002 / ROW 5 SEAT 13',
          kind: TextContent,
          note: 'Accepted, counter 2',
        ),
        const _Tile(
          'Ticket 001 again',
          'LUMEN CONF / TICKET 001 / ROW 5 SEAT 12',
          kind: TextContent,
          warning: true,
          note: 'Warning · “Already checked in”, counter stays 2',
        ),
        _content(
          'Not a ticket',
          const WifiContent(ssid: 'Lumen Guest', password: 'coffee-2026'),
          note: 'Rejected · red flash, “Not a ticket”',
        ),
        const _Tile(
          'Six codes in one view',
          '',
          span: 2,
          codes: <String>[
            'A Espresso',
            'B Latte',
            'C Cappuccino',
            'D Mocha',
            'E Tea',
            'F Water',
          ],
          kind: TextContent,
          exact: false,
          note: 'pick(): six labels, a tap returns that code',
        ),
        const _Tile(
          'Ticket 003, link',
          'https://example.com/t/003',
          kind: UrlContent,
          note: 'Accepted, counter 3',
        ),
      ],
    ),
    (
      'K',
      'Styles',
      'BarcodeView styles, logos, captions and cards. All must read.',
      <_Tile>[
        for (final MapEntry<String, BarcodeStyle> p
            in BarcodeStyle.presets.entries)
          _Tile(
            'Preset “${p.key}”',
            'https://pub.dev/packages/flutter_zxing',
            kind: UrlContent,
            style: p.value,
          ),
        _Tile(
          'Logo 0.2 → ECC Q',
          'https://t.me/flutterdev',
          kind: UrlContent,
          style: BarcodeStyle(logo: BarcodeLogo(logoImage, size: 0.2)),
          note: 'Auto error correction by logo size',
        ),
        _Tile(
          'Logo 0.22 (default) → ECC H',
          'https://t.me/flutterdev',
          kind: UrlContent,
          style: BarcodeStyle(
            logo: BarcodeLogo(logoImage),
            moduleShape: ModuleShape.rounded,
          ),
        ),
        _Tile(
          'Card with caption',
          'https://t.me/flutterdev',
          kind: UrlContent,
          style: BarcodeStyle(
            color: const Color(0xFF229ED9),
            moduleShape: ModuleShape.rounded,
            finderShape: FinderShape.rounded,
            logo: BarcodeLogo(logoImage, size: 0.2),
            caption: const BarcodeCaption('@flutterdev'),
            card: const BarcodeCard(elevation: 0.03),
          ),
        ),
        const _Tile(
          'Dark card, title and caption',
          'https://pub.dev/packages/flutter_zxing',
          kind: UrlContent,
          style: BarcodeStyle(
            color: Color(0xFFFFFFFF),
            backgroundColor: Color(0xFF0E1218),
            title: BarcodeCaption('flutter_zxing'),
            caption: BarcodeCaption(
              'Scan, create and style barcodes in Flutter',
              size: 0.06,
            ),
            card: BarcodeCard(color: Color(0xFF0E1218)),
          ),
          warning: true,
          note: 'Light on dark: a camera needs tryInvert',
        ),
        const _Tile(
          'EAN-13, title and caption',
          '5901234123457',
          format: BarcodeFormat.ean13,
          kind: ProductContent,
          style: BarcodeStyle(
            title: BarcodeCaption('Lumen Café · Coffee beans', size: 0.07),
            caption: BarcodeCaption('250 g · 9.90 €', size: 0.07),
          ),
        ),
      ],
    ),
    (
      'L',
      'Hard cases',
      'Limits of the reader. Orange notes say what to expect.',
      <_Tile>[
        _Tile(
          'Dense QR, 1 200 characters',
          List<String>.generate(
            40,
            (int i) => 'flutter_zxing line ${i.toString().padLeft(2, '0')} ·',
          ).join(' '),
          kind: TextContent,
          warning: true,
          note: 'Version ~27: hold steady, fill the window',
        ),
        const _Tile(
          'Inverted QR',
          'INVERTED · light on dark',
          kind: TextContent,
          style: BarcodeStyle(
            color: Color(0xFFFFFFFF),
            backgroundColor: Color(0xFF000000),
          ),
          warning: true,
          note:
              'ReaderOptions.camera() skips inverted codes: not read live unless tryInvert',
        ),
        const _Tile(
          'Low contrast',
          'LOW CONTRAST',
          kind: TextContent,
          style: BarcodeStyle(
            color: Color(0xFF7A7A7A),
            backgroundColor: Color(0xFFDADADA),
          ),
        ),
        const _Tile(
          'Rotated 30°',
          'ROTATED 30',
          kind: TextContent,
          look: _Look.rotated,
        ),
        const _Tile(
          'Mirrored QR',
          'MIRRORED',
          kind: TextContent,
          look: _Look.mirrored,
          note: 'Result says isMirrored',
        ),
        const _Tile(
          'Tiny QR',
          'TINY',
          kind: TextContent,
          look: _Look.tiny,
          warning: true,
          note: 'About 6 mm on a laptop screen: needs zoom or closeness',
        ),
        const _Tile(
          'Inverted Data Matrix',
          'INVERTED DM',
          format: BarcodeFormat.dataMatrix,
          kind: TextContent,
          style: BarcodeStyle(
            color: Color(0xFFFFFFFF),
            backgroundColor: Color(0xFF000000),
          ),
          warning: true,
          note: 'Same as the inverted QR',
        ),
        const _Tile(
          'Long Code 128',
          'FLUTTER-ZXING-4.0-LONG-CODE-128-0123456789',
          format: BarcodeFormat.code128,
          kind: TextContent,
          span: 2,
          note: 'Hold the phone parallel to the bars',
        ),
        _Tile(
          'Binary data',
          '',
          bytes: Uint8List.fromList(<int>[
            0,
            1,
            2,
            3,
            0xFE,
            0xFF,
            0x80,
            0x7F,
            0x1B,
            0x00,
          ]),
          kind: BinaryContent,
          exact: false,
          note: '10 bytes 00 01 02 03 FE FF 80 7F 1B 00: no text',
        ),
        const _Tile(
          'Latin-1 without ECI',
          'ROW 5 \u00b7 SEAT 12',
          kind: TextContent,
          warning: true,
          note:
              'Known issue: \u00b7 \u00b7 may read as half-width katakana (Shift_JIS guess). What does the phone camera show?',
        ),
      ],
    ),
  ];
}

/// The section's tiles, cut into pages of [_rows] rows of [_columns].
List<(int, List<_Tile>, List<Rect>)> _paginate(List<_Tile> tiles) {
  final Size cell = Size(
    (_page.width - 2 * _margin - (_columns - 1) * _gap) / _columns,
    (_page.height - _header - 2 * _margin - (_rows - 1) * _gap) / _rows,
  );
  final List<(int, List<_Tile>, List<Rect>)> pages =
      <(int, List<_Tile>, List<Rect>)>[];
  List<_Tile> page = <_Tile>[];
  List<Rect> rects = <Rect>[];
  int first = 0;
  int column = 0;
  int row = 0;
  for (int i = 0; i < tiles.length; i++) {
    final _Tile tile = tiles[i];
    if (column + tile.span > _columns) {
      column = 0;
      row++;
    }
    if (row == _rows) {
      pages.add((first, page, rects));
      page = <_Tile>[];
      rects = <Rect>[];
      first = i;
      row = 0;
    }
    page.add(tile);
    rects.add(
      Rect.fromLTWH(
        _margin + column * (cell.width + _gap),
        _header + _margin + row * (cell.height + _gap),
        tile.span * cell.width + (tile.span - 1) * _gap,
        cell.height,
      ),
    );
    column += tile.span;
  }
  pages.add((first, page, rects));
  return pages;
}

/// The formats the scanner reads and the writer has no format for, each with
/// the best picture of it there is. An add-on only exists next to an EAN-13.
List<(BarcodeFormat, _Tile)> _readOnlyTiles() => <(BarcodeFormat, _Tile)>[
  (
    BarcodeFormat.maxiCode,
    const _Tile(
      'MaxiCode',
      '',
      format: BarcodeFormat.maxiCode,
      sample: '$_samples/maxicode-1/MODE2.png',
      exact: false,
      warning: true,
      note: 'Sample. Fill the frame with it: never found on a whole page',
    ),
  ),
  (
    BarcodeFormat.qrCodeModel1,
    _sample('QR Code Model 1', BarcodeFormat.qrCode, 'qrcode-1/qr-model-1.png'),
  ),
  (
    BarcodeFormat.ean5,
    _sample(
      'EAN-5 add-on',
      BarcodeFormat.ean13,
      'ean13-ext-1/1.png',
      span: 2,
      exact: false,
    ),
  ),
  (
    BarcodeFormat.ean2,
    const _Tile(
      'EAN-2 add-on',
      '4006381333931+12',
      format: BarcodeFormat.ean13,
      expect: '400638133393112',
      span: 2,
      note: 'Drawn next to an EAN-13',
    ),
  ),
  (
    BarcodeFormat.itf14,
    _Tile(
      'ITF-14',
      _withCheck('0001234560001'),
      format: BarcodeFormat.itf,
      span: 2,
      note: 'Drawn as ITF with 14 digits',
    ),
  ),
];

/// One tile of each format the writer makes, as on the sheets that follow.
List<_Tile> _writtenTiles(List<_Section> sections) => <_Tile>[
  for (final BarcodeFormat format in BarcodeFormat.writable)
    _forOverview(
      sections
          .expand((_Section s) => s.$4)
          .firstWhere(
            (_Tile t) =>
                t.format == format &&
                t.sample == null &&
                t.bytes == null &&
                t.codes == null &&
                t.look == _Look.plain &&
                t.style == BarcodeStyle.classic,
          ),
    ),
];

/// [tile] as it has to be on a page with all the others. DataBars holding the
/// same GTIN are taken for one code when read together, so each gets its own;
/// both PDF417 kinds report one format, so their texts differ for the field
/// test to tell them apart; the longest code gets the width it needs.
_Tile _forOverview(_Tile tile) {
  _Tile dataBar(String digits) {
    final String gtin = _withCheck(digits);
    return _format(
      tile.format,
      data: gtin,
      expect: '(01)$gtin',
      note: tile.note,
    );
  }

  return switch (tile.format) {
    BarcodeFormat.dataBarStacked => dataBar('0950110153001'),
    BarcodeFormat.dataBarStackedOmni => dataBar('0950110153002'),
    BarcodeFormat.compactPdf417 => _format(
      tile.format,
      data: 'Compact PDF417',
      span: tile.span,
    ),
    BarcodeFormat.code39Extended => _format(
      tile.format,
      span: 4,
      note: tile.note,
    ),
    BarcodeFormat.code93 => _format(tile.format, span: 3, note: tile.note),
    _ => tile,
  };
}
