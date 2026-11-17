// Check sheets: pages with every code flutter_zxing reads, makes and
// understands, to show on a screen and scan with a phone. Every tile has an
// id (A1, B4…), the format, the content kind the scanner should report and
// the data. After drawing, each tile is read back by the engine, and the
// result goes into report.md next to the pages. Skipped unless SHEETS names
// an output folder (build/ is ignored by git):
//
//   SHEETS=build/check_sheets flutter test test/tool/check_sheets_test.dart
//
// Open index.html there to scroll through all pages, or the PNGs one by one.
// Text uses Roboto from the Flutter SDK when FLUTTER_ROOT is set.
@Tags(<String>['native'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

final String? _out = Platform.environment['SHEETS'];
const String _samples = 'third_party/zxing-cpp/test/samples';

// Page geometry, in logical pixels; the PNGs are twice as large.
const double _pixelRatio = 2;
const Size _page = Size(1600, 1000);
const double _margin = 28;
const double _header = 64;
const double _gap = 14;
const int _columns = 4;
const int _rows = 3;

// Colours.
const Color _ink = Color(0xFF0E1218);
const Color _muted = Color(0xFF5B6472);
const Color _paper = Color(0xFFEEF0F3);
const Color _accent = Color(0xFF00735D);
const Color _warn = Color(0xFFB45309);

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
          'qrcode-2/qr-model-1.png',
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
          'ean13-extension-1/1.png',
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

/// [text] with control characters made visible.
String _visible(String text) => text
    .replaceAll('\r', '‹CR›')
    .replaceAll('\n', '⏎')
    .replaceAll('\x1d', '‹GS›')
    .replaceAll('\x1e', '‹RS›');

String _kindName(Type? kind) => kind?.toString() ?? '—';

Future<void> _loadFonts() async {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final FontLoader roboto = FontLoader('Roboto');
    for (final String weight in <String>['Regular', 'Medium', 'Bold']) {
      final File file = File(
        '$root/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
      );
      if (file.existsSync()) {
        roboto.addFont(
          Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    await roboto.load();
  }
  final File menlo = File('/System/Library/Fonts/Menlo.ttc');
  if (menlo.existsSync()) {
    await (FontLoader('Menlo')..addFont(
          Future<ByteData>.value(ByteData.sublistView(menlo.readAsBytesSync())),
        ))
        .load();
  }
}

/// A 96 × 96 logo: a rounded square with a white Z, like an app icon.
Future<Uint8List> _logoPng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 96, 96),
      const Radius.circular(22),
    ),
    Paint()..color = const Color(0xFF0B3D91),
  );
  canvas.drawPath(
    Path()
      ..moveTo(26, 26)
      ..lineTo(70, 26)
      ..lineTo(26, 70)
      ..lineTo(70, 70),
    Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round,
  );
  final ui.Image image = await recorder.endRecording().toImage(96, 96);
  final ByteData png = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!;
  image.dispose();
  return png.buffer.asUint8List();
}

// Menlo has the arrows and symbols Roboto from the SDK lacks.
const TextStyle _text = TextStyle(
  fontFamily: 'Roboto',
  fontFamilyFallback: <String>['Menlo'],
  color: _ink,
);
const TextStyle _mono = TextStyle(
  fontFamily: 'Menlo',
  fontSize: 11,
  height: 1.35,
  color: _muted,
);

/// The code of [tile], sized to the space it has.
Widget _code(_Tile tile, Map<String, ui.Image> images) {
  Widget view(String data, {double? width}) => BarcodeView(
    data,
    format: tile.format,
    gs1: tile.gs1,
    errorCorrection: tile.ecc,
    style: tile.style,
    showText: tile.format.isLinear,
    width: width,
  );
  final Widget code;
  if (tile.sample case final String path) {
    final ui.Image image = images[path]!;
    code = RawImage(
      image: image,
      fit: BoxFit.contain,
      filterQuality: image.width < 250
          ? FilterQuality.none
          : FilterQuality.medium,
    );
  } else if (tile.codes case final List<String> codes) {
    code = Wrap(
      spacing: 22,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: <Widget>[
        for (final String c in codes)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              view(c, width: 100),
              Text(
                c.substring(0, 1),
                style: _text.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  } else if (tile.bytes case final Uint8List bytes) {
    code = BarcodeView.bytes(bytes, format: tile.format);
  } else {
    code = view(tile.data, width: tile.look == _Look.tiny ? 34 : null);
  }
  return switch (tile.look) {
    _Look.rotated => Transform.rotate(
      angle: 0.5236,
      child: SizedBox.square(dimension: 130, child: code),
    ),
    _Look.mirrored => Transform.flip(flipX: true, child: code),
    _ => code,
  };
}

Widget _tile(
  String id,
  _Tile tile,
  Map<String, ui.Image> images,
  GlobalKey key,
) {
  final String? note = tile.note;
  final String data = tile.bytes != null
      ? tile.bytes!
            .map((int b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ')
      : tile.codes?.join(' · ') ?? _visible(tile.data);
  return DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  child: Text(
                    id,
                    style: _text.copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  tile.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                tile.format.displayName,
                style: _text.copyWith(fontSize: 12, color: _muted),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: KeyedSubtree(
                key: key,
                child: Center(child: _code(tile, images)),
              ),
            ),
          ),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '→ ${_kindName(tile.kind)}',
                  style: const TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (note != null)
                  TextSpan(
                    text: '  $note',
                    style: TextStyle(color: tile.warning ? _warn : _muted),
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _text.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            data.isEmpty ? '(see sample)' : data,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _mono,
          ),
        ],
      ),
    ),
  );
}

/// What reading a tile back found.
final class _Check {
  const _Check(this.id, this.tile, this.found);

  final String id;
  final _Tile tile;
  final List<Barcode> found;

  Barcode? get first => found.isEmpty ? null : found.first;

  bool get formatOk =>
      first != null && first!.format.symbology == tile.format.symbology;

  bool get kindOk =>
      tile.kind == null || first?.content.runtimeType == tile.kind;

  bool get textOk =>
      !tile.exact || first?.text.trim() == tile.expectedText.trim();

  bool get countOk => tile.codes == null || found.length == tile.codes!.length;

  /// Not read, or read as something else: the sheet itself is wrong.
  bool get failed => first == null || !formatOk || !kindOk || !countOk;

  String get status => failed ? '✗' : (textOk ? '✓' : '≈');
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    await warmUpBarcodeEngine();
  });

  testWidgets(
    'check sheets',
    (WidgetTester tester) async {
      final Directory dir = Directory(_out!)..createSync(recursive: true);
      tester.view
        ..physicalSize = _page
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final Uint8List logo = (await tester.runAsync(_logoPng))!;
      final List<_Section> sections = _sections(logo);

      // Every format the writer makes is on a sheet.
      final Set<BarcodeFormat> drawn = <BarcodeFormat>{
        for (final _Section s in sections)
          for (final _Tile t in s.$4)
            if (t.sample == null) t.format,
      };
      expect(
        BarcodeFormat.writable.difference(drawn),
        isEmpty,
        reason: 'a writable format has no tile',
      );

      final Map<String, ui.Image> images = <String, ui.Image>{};
      await tester.runAsync(() async {
        for (final _Section s in sections) {
          for (final _Tile t in s.$4) {
            if (t.sample case final String path) {
              images[path] = await decodeImageFromList(
                File(path).readAsBytesSync(),
              );
            }
          }
        }
      });

      final List<_Check> checks = <_Check>[];
      final List<(String, String, String)> pages = <(String, String, String)>[];
      int pageNumber = 0;
      final int pageCount = sections.fold(
        0,
        (int n, _Section s) => n + _paginate(s.$4).length,
      );
      final String date = DateTime.now().toIso8601String().substring(0, 10);

      for (final (String letter, String title, String about, List<_Tile> tiles)
          in sections) {
        final List<(int, List<_Tile>, List<Rect>)> parts = _paginate(tiles);
        for (int part = 0; part < parts.length; part++) {
          final (int first, List<_Tile> pageTiles, List<Rect> rects) =
              parts[part];
          pageNumber++;
          final String heading = parts.length > 1
              ? '$title (${part + 1}/${parts.length})'
              : title;
          final List<GlobalKey> keys = <GlobalKey>[
            for (final _Tile _ in pageTiles) GlobalKey(),
          ];
          final GlobalKey boundary = GlobalKey();
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: DefaultTextStyle(
                style: _text,
                child: RepaintBoundary(
                  key: boundary,
                  child: ColoredBox(
                    color: _paper,
                    child: Stack(
                      children: <Widget>[
                        Positioned(
                          left: _margin,
                          right: _margin,
                          top: 18,
                          height: _header,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '$letter  ',
                                style: _text.copyWith(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: _accent,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      heading,
                                      style: _text.copyWith(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      about,
                                      style: _text.copyWith(
                                        fontSize: 14,
                                        color: _muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'flutter_zxing 4.0 · check sheet · $pageNumber / $pageCount · $date',
                                style: _text.copyWith(
                                  fontSize: 13,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (int i = 0; i < pageTiles.length; i++)
                          Positioned.fromRect(
                            rect: rects[i],
                            child: _tile(
                              '$letter${first + i + 1}',
                              pageTiles[i],
                              images,
                              keys[i],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

          // BarcodeView encodes on the engine isolate and logos decode
          // asynchronously: give both real time until every view paints.
          for (int i = 0; i < 200; i++) {
            final bool waiting = find
                .byType(BarcodeView)
                .evaluate()
                .any(
                  (Element e) => find
                      .descendant(
                        of: find.byWidget(e.widget),
                        matching: find.byType(CustomPaint),
                      )
                      .evaluate()
                      .isEmpty,
                );
            if (!waiting && i > 10) {
              break;
            }
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
          }
          await tester.pump();

          final String file =
              '${pageNumber.toString().padLeft(2, '0')}-$letter-${title.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-')}'
              '${parts.length > 1 ? '-${part + 1}' : ''}.png';
          final RenderRepaintBoundary render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final ByteData? rgba = await tester.runAsync<ByteData?>(() async {
            final ui.Image image = await render.toImage(
              pixelRatio: _pixelRatio,
            );
            final ByteData png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            File(
              '${dir.path}/$file',
            ).writeAsBytesSync(png.buffer.asUint8List());
            final ByteData? pixels = await image.toByteData();
            image.dispose();
            return pixels;
          });
          pages.add((file, '$letter · $heading', about));

          for (int i = 0; i < pageTiles.length; i++) {
            final Rect area = tester.getRect(find.byKey(keys[i]));
            final List<Barcode> found = (await tester.runAsync<List<Barcode>>(
              () =>
                  const BarcodeReader(
                    options: ReaderOptions(eanAddOn: EanAddOn.read),
                  ).readAllPixels(
                    PixelBuffer(
                      rgba!.buffer.asUint8List(),
                      width: (_page.width * _pixelRatio).round(),
                      height: (_page.height * _pixelRatio).round(),
                      layout: PixelLayout.rgba,
                      crop: Rect.fromLTRB(
                        area.left * _pixelRatio,
                        area.top * _pixelRatio,
                        area.right * _pixelRatio,
                        area.bottom * _pixelRatio,
                      ),
                    ),
                  ),
            ))!;
            checks.add(_Check('$letter${first + i + 1}', pageTiles[i], found));
          }
        }
      }
      for (final ui.Image image in images.values) {
        image.dispose();
      }

      // report.md: one row per tile, what it holds and what reading it gave.
      String cell(String s) => s.replaceAll('|', r'\|');
      final StringBuffer report = StringBuffer()
        ..writeln('# flutter_zxing 4.0 · check sheets ($date)')
        ..writeln()
        ..writeln(
          '✓ read back as drawn · ≈ read, text differs (expected for some formats) · ✗ broken tile',
        )
        ..writeln()
        ..writeln('Scan each tile with the demo and tick the last column.')
        ..writeln();
      String? section;
      for (final _Check c in checks) {
        final String letter = c.id.substring(0, 1);
        if (letter != section) {
          section = letter;
          final _Section s = sections.firstWhere(
            (_Section s) => s.$1 == letter,
          );
          report
            ..writeln('## $letter · ${s.$2}')
            ..writeln()
            ..writeln('| | Tile | Format | Expect | Read back | Data | Phone |')
            ..writeln('|---|---|---|---|---|---|---|');
        }
        final Barcode? b = c.first;
        final String read = b == null
            ? 'not read'
            : '${c.status} ${b.format.displayName} · ${b.content.runtimeType}'
                  '${c.tile.codes != null ? ' · ${c.found.length} codes' : ''}'
                  '${b.ecLevel != null && b.ecLevel!.isNotEmpty ? ' · ECC ${b.ecLevel}' : ''}'
                  '${b.isMirrored ? ' · mirrored' : ''}${b.isInverted ? ' · inverted' : ''}';
        final String data = c.tile.bytes != null
            ? '(binary)'
            : _visible(c.tile.data);
        report.writeln(
          '| **${c.id}** | ${cell(c.tile.title)}${c.tile.note != null ? '<br><sub>${cell(c.tile.note!)}</sub>' : ''} '
          '| ${c.tile.format.displayName} | ${_kindName(c.tile.kind)} | ${cell(read)} '
          '| `${cell(data.length > 60 ? '${data.substring(0, 60)}…' : data)}` | ☐ |',
        );
      }
      File('${dir.path}/report.md').writeAsStringSync(report.toString());

      // index.html: all pages one under another, as one long sheet.
      const HtmlEscape esc = HtmlEscape();
      File('${dir.path}/index.html').writeAsStringSync('''
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Check sheets</title>
<style>
  body { margin: 0; background: #1b1f24; color: #e8eaed; font: 14px -apple-system, system-ui, sans-serif; }
  nav { position: sticky; top: 0; z-index: 1; display: flex; flex-wrap: wrap; gap: 6px; padding: 10px 16px; background: #1b1f24ee; }
  nav a { color: #e8eaed; text-decoration: none; padding: 4px 10px; border-radius: 6px; background: #2c323a; }
  section { padding: 12px 16px 28px; }
  h2 { margin: 0 0 8px; font-size: 16px; font-weight: 600; }
  img { display: block; width: 100%; max-width: 1600px; height: auto; border-radius: 8px; }
</style></head><body>
<nav>${pages.map(((String, String, String) p) => '<a href="#${esc.convert(p.$1)}">${esc.convert(p.$2.split(' · ').first)}</a>').join()}</nav>
${pages.map(((String, String, String) p) => '<section id="${esc.convert(p.$1)}"><h2>${esc.convert(p.$2)}</h2><img src="${esc.convert(p.$1)}" alt="${esc.convert(p.$2)}"></section>').join('\n')}
</body></html>
''');

      final List<_Check> failed = checks.where((_Check c) => c.failed).toList();
      final int differs = checks
          .where((_Check c) => !c.failed && !c.textOk)
          .length;
      // ignore: avoid_print
      print(
        '${checks.length} codes on $pageCount pages in ${dir.path}: '
        '${checks.length - failed.length - differs} ✓, $differs ≈, ${failed.length} ✗',
      );
      for (final _Check c in checks.where(
        (_Check c) => c.failed || !c.textOk,
      )) {
        // ignore: avoid_print
        print(
          '${c.status} ${c.id} ${c.tile.title}: '
          '${c.first == null ? 'not read' : '${c.first!.format.displayName} ${c.first!.content.runtimeType} '
                    '${c.found.length > 1 ? '(${c.found.length}) ' : ''}“${_visible(c.first!.text)}”'}',
        );
      }
      expect(failed.map((_Check c) => c.id), isEmpty);
    },
    skip: _out == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
