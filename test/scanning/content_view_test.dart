// BarcodeContentView: a content drawn with what its standard requires, and
// a content with problems shown as an error.
@Tags(<String>['native'])
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

const EpcPaymentContent _epc = EpcPaymentContent(
  name: 'Kaffeehaus Lumen GmbH',
  iban: 'DE89370400440532013000',
  amount: '19.50',
);

const SwissQrBillContent _bill = SwissQrBillContent(
  iban: 'CH4431999123000889012',
  creditor: SwissAddress(
    name: 'Robert Schneider AG',
    street: 'Rue du Lac',
    buildingNumber: '1268',
    postalCode: '2501',
    town: 'Biel',
    country: 'CH',
  ),
  amount: '1949.75',
  creditorReference: '210000000003139471430009017',
);

void main() {
  group('BarcodeContentView', () {
    testWidgets('a Swiss QR-bill gets the Swiss cross and a QR code', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BarcodeContentView(
            _bill,
            writer: BarcodeWriter(BarcodeFormat.dataMatrix),
            width: 200,
          ),
        ),
      );
      final BarcodeView view = tester.widget(find.byType(BarcodeView));
      expect(view.data, _bill.toPayload());
      expect(view.style, BarcodeStyle.swissQrBill);
      expect(view.writer?.format, BarcodeFormat.qrCode);
    });

    testWidgets('a style given wins', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const BarcodeContentView(_bill, style: BarcodeStyle.dots)),
      );
      final BarcodeView view = tester.widget(find.byType(BarcodeView));
      expect(view.style, BarcodeStyle.dots);
    });

    testWidgets('an EPC payment is a QR code with error correction M', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BarcodeContentView(
            _epc,
            writer: BarcodeWriter(
              BarcodeFormat.qrCode,
              errorCorrection: ErrorCorrection.low,
            ),
          ),
        ),
      );
      final BarcodeView view = tester.widget(find.byType(BarcodeView));
      expect(view.writer?.errorCorrection, ErrorCorrection.medium);
      expect(view.style, BarcodeStyle.classic);
    });

    testWidgets('GS1 data is encoded as GS1, binary data as bytes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BarcodeContentView(
            Gs1Content(<String, String>{'01': '09501101530003'}),
            writer: BarcodeWriter(BarcodeFormat.dataMatrix),
          ),
        ),
      );
      expect(
        tester.widget<BarcodeView>(find.byType(BarcodeView)).writer?.gs1,
        isTrue,
      );

      final Uint8List bytes = Uint8List.fromList(<int>[0, 1, 0xFE, 0xFF]);
      await tester.pumpWidget(_host(BarcodeContentView(BinaryContent(bytes))));
      expect(tester.widget<BarcodeView>(find.byType(BarcodeView)).bytes, bytes);
    });

    testWidgets('a content with problems shows the errorBuilder', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BarcodeContentView(
            const WifiContent(ssid: ''),
            errorBuilder: (BuildContext context, BarcodeWriteException error) =>
                Text(error.message),
          ),
        ),
      );
      expect(find.byType(BarcodeView), findsNothing);
      expect(
        find.text(
          const WifiContent(
            ssid: '',
          ).validate().map((ContentIssue i) => i.message).join('\n'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('without an errorBuilder, an empty box', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const BarcodeContentView(WifiContent(ssid: ''), width: 120)),
      );
      expect(find.byType(BarcodeView), findsNothing);
      expect(tester.getSize(find.byType(SizedBox)).width, 120);
    });
  });
}
