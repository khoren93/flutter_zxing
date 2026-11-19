// BarcodeContent on barcodes the real engine read: zxing-cpp's sample images
// and barcodes written by BarcodeWriter.
@Tags(<String>['native'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// A QR code sequence in one image. WebP in the samples, which the engine
/// does not read: `make fixtures` converts it.
const String _qrSequence = 'build/fixtures/corpus/qrcode-2__StructApp.png';

/// zxing-cpp's samples, from the submodule the engine is built from.
Uint8List _sample(String name) => Uint8List.fromList(
  File('third_party/zxing-cpp/test/samples/$name').readAsBytesSync(),
);

Future<Barcode?> _roundTrip(BarcodeWriter writer, String data) async {
  final BarcodeSymbol symbol = await writer.encode(data);
  final BarcodeImage image = await symbol.toImage(moduleSize: 4);
  return const BarcodeReader().readPixels(
    PixelBuffer(image.pixels, width: image.width, height: image.height),
  );
}

void main() {
  const BarcodeReader reader = BarcodeReader();

  group('samples', () {
    test('vCard QR code', () async {
      final Barcode? barcode = await reader.read(_sample('qrcode-1/11.png'));
      final ContactContent contact = barcode!.content as ContactContent;
      expect(contact.name, 'Steve Kennedy');
      expect(contact.organization, 'NetTek Ltd');
      expect(contact.phones, <String>['+44 (0)7775 755503']);
      expect(contact.urls, <Uri>[Uri.parse('https://www.nettek.co.uk')]);
    });

    test('GS1 Data Matrix', () async {
      final Barcode? barcode = await reader.read(
        _sample('datamatrix-1/gs1-figure-4.15.1-2-32x32.png'),
      );
      expect(barcode!.contentType, BarcodeContentType.gs1);
      final Gs1Content gs1 = barcode.content as Gs1Content;
      expect(gs1.elements, <String, String>{
        '01': '09504000059101',
        '21': '12345678p901',
        '10': '1234567p',
        '17': '141120',
        '8200': 'http://www.gs1.org/demo/',
      });
      // Same split as the engine's human readable text.
      expect(
        gs1.elements.entries
            .map((MapEntry<String, String> e) => '(${e.key})${e.value}')
            .join(),
        barcode.text,
      );
    });

    test('GS1 DataBar Expanded and Expanded Stacked', () async {
      for (final String name in <String>[
        'databarExp-1/10.png',
        'databarExpStk-1/71.png',
      ]) {
        final Barcode? barcode = await reader.read(_sample(name));
        final Gs1Content gs1 = barcode!.content as Gs1Content;
        expect(
          gs1.elements.entries
              .map((MapEntry<String, String> e) => '(${e.key})${e.value}')
              .join(),
          barcode.text,
          reason: name,
        );
      }
    });

    test('GS1 Code 128 that is not valid GS1 is text', () async {
      final Barcode? barcode = await reader.read(_sample('code128-1/1.png'));
      expect(barcode!.contentType, BarcodeContentType.gs1);
      expect(barcode.content, TextContent(barcode.text));
    });

    test('structured append: three symbols, one message', () async {
      final List<Barcode> parts = await reader.readAll(
        _sample('pdf417-2/StructApp1.png'),
      );
      expect(parts, hasLength(3));
      expect(parts.map((Barcode b) => b.sequence?.size), everyElement(3));
      expect(await reader.merge(parts.take(2)), isNull);
      final Barcode? merged = await reader.merge(parts.reversed);
      final List<Barcode> ordered = parts.toList()
        ..sort(
          (Barcode a, Barcode b) =>
              a.sequence!.index.compareTo(b.sequence!.index),
        );
      expect(merged?.bytes, <int>[
        for (final Barcode part in ordered) ...part.bytes,
      ]);
      // A character set declared in one part carries over to the next.
      expect(merged?.text, contains('CN:￥'));
      expect(merged?.text, contains('DE:444,90 €'));
      expect(merged?.text, isNot(contains('¤')));
    });

    test(
      'QR structured append: four symbols, one message',
      () async {
        final List<Barcode> parts = await reader.readAll(
          Uint8List.fromList(File(_qrSequence).readAsBytesSync()),
        );
        expect(parts, hasLength(4));
        expect(parts.map((Barcode b) => b.sequence?.size), everyElement(4));
        expect(await reader.merge(parts.take(3)), isNull);
        final List<Barcode> ordered = parts.toList()
          ..sort(
            (Barcode a, Barcode b) =>
                a.sequence!.index.compareTo(b.sequence!.index),
          );
        expect(
          (await reader.merge(parts.reversed))?.text,
          ordered.map((Barcode b) => b.text).join(),
        );
      },
      skip: File(_qrSequence).existsSync()
          ? false
          : 'run `make fixtures` first',
    );
  });

  group('written and read back', () {
    test('Wi-Fi QR code', () async {
      final Barcode? barcode = await _roundTrip(
        const BarcodeWriter(BarcodeFormat.qrCode),
        r'WIFI:T:WPA;S:Lumen Guest;P:espresso\;2026;;',
      );
      expect(
        barcode!.content,
        const WifiContent(ssid: 'Lumen Guest', password: 'espresso;2026'),
      );
    });

    test(
      'GS1 Data Matrix with a variable length field in the middle',
      () async {
        final Barcode? barcode = await _roundTrip(
          const BarcodeWriter(BarcodeFormat.dataMatrix, gs1: true),
          '(01)09501101530003(10)ABC123(17)250101',
        );
        expect(barcode!.contentType, BarcodeContentType.gs1);
        expect(
          barcode.content,
          const Gs1Content(<String, String>{
            '01': '09501101530003',
            '10': 'ABC123',
            '17': '250101',
          }),
        );
      },
    );

    test('binary QR code', () async {
      final Uint8List data = Uint8List.fromList(<int>[0, 1, 2, 0xFE, 0xFF]);
      final BarcodeSymbol symbol = await const BarcodeWriter(
        BarcodeFormat.qrCode,
      ).encodeBytes(data);
      final BarcodeImage image = await symbol.toImage(moduleSize: 4);
      final Barcode? barcode = await reader.readPixels(
        PixelBuffer(image.pixels, width: image.width, height: image.height),
      );
      expect(barcode!.content, BinaryContent(data));
    });
  });

  group('built, written and read back', () {
    Future<BarcodeContent> readBack(
      BarcodeContent content, [
      BarcodeFormat format = BarcodeFormat.qrCode,
    ]) async {
      final BarcodeSymbol symbol = await BarcodeWriter(
        format,
      ).encodeContent(content);
      final BarcodeImage image = await symbol.toImage(moduleSize: 4);
      final Barcode? barcode = await reader.readPixels(
        PixelBuffer(image.pixels, width: image.width, height: image.height),
      );
      return barcode!.content;
    }

    final List<BarcodeContent> contents = <BarcodeContent>[
      const TextContent('Ünïcødé text 😀'),
      UrlContent(Uri.parse('https://example.com/a?b=c'), title: 'Shop: 50%'),
      const WifiContent(ssid: r'"My;Net,1:\"', password: r'p"a;s:w\o'),
      const EmailContent(address: 'a@x.org', subject: 'Hi & bye', body: 'é'),
      const PhoneContent('*100#'),
      const SmsContent(number: '+12125551234', message: 'Hi: 5pm'),
      const GeoContent(latitude: 40.689247, longitude: -74.044502, query: 'Q'),
      ContactContent(
        name: 'Mary Ann Smith',
        organization: 'Acme; Inc',
        phones: const <String>['+1 555 0100'],
        emails: const <String>['mary@acme.example'],
        urls: <Uri>[Uri.parse('https://acme.example')],
        addresses: const <String>['1 Main St, Springfield'],
        note: 'line 1\nline 2',
        birthDate: DateTime(1990, 5, 17),
      ),
      EventContent(
        summary: 'Launch, v4',
        start: DateTime.utc(2026, 11, 17, 9, 30),
        end: DateTime.utc(2026, 11, 17, 11),
        location: 'Room 1',
      ),
      EventContent(
        summary: 'Holiday',
        start: DateTime(2026, 12, 25),
        allDay: true,
      ),
      const OtpContent(
        secret: 'JBSWY3DPEHPK3PXP',
        account: 'alice@example.com',
        issuer: 'Big Corp',
      ),
      const EsimContent(smdpAddress: 'rsp.example.com', matchingId: 'ABC-123'),
      const CryptoContent(
        currency: CryptoCurrency.bitcoin,
        address: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
        amount: '0.0015',
        label: 'Café',
      ),
      const PhoneContent('user@icloud.com', type: CallType.faceTime),
      LinkService.whatsApp.link('+374 91 234567', message: 'Hi'),
      const EpcPaymentContent(
        name: 'Kaffeehaus Lumen',
        iban: 'DE89370400440532013000',
        amount: '12.50',
        message: 'Invoice 42',
      ),
      const GostPaymentContent(
        name: 'ООО «Три кита»',
        personalAccount: '40702810138250123017',
        bankName: 'ОАО "БАНК"',
        bic: '044525225',
        correspondentAccount: '30101810400000000225',
        amount: '1250.50',
        purpose: 'Оплата по счёту № 7',
      ),
      const UpiPaymentContent(
        address: 'shop@okbank',
        name: 'Lumen Café',
        amount: '99.50',
      ),
      EmvPaymentContent.pix(
        key: 'fulano@example.com',
        name: 'Fulano de Tal',
        city: 'SAO PAULO',
        amount: '10.50',
      ),
      const SpaydPaymentContent(
        iban: 'CZ5855000000001265098001',
        amount: '480.50',
      ),
    ];
    for (final BarcodeContent content in contents) {
      test('$content', () async {
        expect(await readBack(content), content);
      });
    }

    test('contact as MeCard', () async {
      const ContactContent contact = ContactContent(
        name: 'Sean Owen',
        phones: <String>['+12125658770'],
      );
      final Barcode? barcode = await _roundTrip(
        const BarcodeWriter(BarcodeFormat.qrCode),
        contact.toPayload(format: ContactFormat.meCard),
      );
      expect(barcode!.content, contact);
    });

    test('GS1 Data Matrix and Code 128', () async {
      const Gs1Content gs1 = Gs1Content(<String, String>{
        '01': '09501101530003',
        '10': 'ABC123',
        '17': '270101',
      });
      expect(await readBack(gs1, BarcodeFormat.dataMatrix), gs1);
      expect(await readBack(gs1, BarcodeFormat.code128), gs1);
    });

    test('EAN-13 is a product, Code 39 VIN a vehicle', () async {
      final BarcodeContent book = await readBack(
        const TextContent('9780306406157'),
        BarcodeFormat.ean13,
      );
      expect((book as ProductContent).isbn10, '0306406152');
      final BarcodeContent vin = await readBack(
        const TextContent('WVWZZZ1JZXW000001'),
        BarcodeFormat.code39,
      );
      expect((vin as VinContent).region, VinRegion.europe);
    });

    test('binary', () async {
      final BinaryContent binary = BinaryContent(
        Uint8List.fromList(<int>[0, 1, 2, 0xFE, 0xFF]),
      );
      expect(await readBack(binary), binary);
    });
  });
}
