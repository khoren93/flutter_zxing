// A QR code on an invoice: the customer's banking app scans it and fills
// in the transfer. A SEPA credit transfer (EPC, "GiroCode") in the euro
// area, or a Swiss QR-bill. Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class InvoiceQrPage extends StatefulWidget {
  const InvoiceQrPage({super.key});

  @override
  State<InvoiceQrPage> createState() => _InvoiceQrPageState();
}

enum _Standard { sepa, swiss }

class _InvoiceQrPageState extends State<InvoiceQrPage> {
  // Your code: the invoice from your billing system.
  static const String _number = 'Invoice 2027-0042';
  static const String _amount = '1949.75'; // main unit, two decimals

  static const EpcPaymentContent _sepa = EpcPaymentContent(
    name: 'Kaffeehaus Lumen GmbH',
    iban: 'DE89370400440532013000',
    amount: _amount,
    creditorReference: 'RF18539007547034', // ISO 11649, checked
  );

  static const SwissQrBillContent _swiss = SwissQrBillContent(
    iban: 'CH4431999123000889012', // a QR-IBAN takes a QR reference
    creditor: SwissAddress(
      name: 'Robert Schneider AG',
      street: 'Rue du Lac',
      buildingNumber: '1268',
      postalCode: '2501',
      town: 'Biel',
      country: 'CH',
    ),
    amount: _amount,
    creditorReference: '210000000003139471430009017',
    message: _number,
  );

  _Standard _standard = _Standard.sepa;

  @override
  Widget build(BuildContext context) {
    final PaymentContent payment = switch (_standard) {
      _Standard.sepa => _sepa,
      _Standard.swiss => _swiss,
    };
    final ScannerLocalizations texts = ScannerLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(_number)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SegmentedButton<_Standard>(
            segments: const [
              ButtonSegment(value: _Standard.sepa, label: Text('SEPA')),
              ButtonSegment(value: _Standard.swiss, label: Text('QR-bill')),
            ],
            selected: {_standard},
            onSelectionChanged: (s) => setState(() => _standard = s.first),
          ),
          const SizedBox(height: 24),
          Center(
            // What each standard asks for: a QR-bill carries the Swiss
            // cross (on paper the code is 46 × 46 mm), both use error
            // correction M.
            child: BarcodeContentView(payment, width: 220),
          ),
          const SizedBox(height: 24),
          // The same five fields whatever the standard.
          ListTile(
            title: const Text('Pay to'),
            subtitle: Text(payment.payee ?? '—'),
          ),
          ListTile(
            title: const Text('Account'),
            subtitle: Text(payment.account ?? '—'),
          ),
          ListTile(
            title: const Text('Amount'),
            // "1949.75 EUR" in the scanner's language, "Any amount" without one.
            subtitle: Text(texts.amountOf(payment.amount, payment.currency)),
          ),
          ListTile(
            title: const Text('Reference'),
            subtitle: Text(payment.reference ?? '—'),
          ),
        ],
      ),
    );
  }
}
