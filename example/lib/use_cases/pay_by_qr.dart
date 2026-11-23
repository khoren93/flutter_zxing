// Pay by QR code: a payment code (SEPA GiroCode, Swiss QR-bill, UPI, PIX
// and other EMVCo codes, SPAYD, ГОСТ) into your app's confirm screen, with
// the payee, account, amount and reference filled in. To try it, scan the
// payment QR code of an invoice. Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class PayByQrPage extends StatelessWidget {
  const PayByQrPage({super.key});

  // A code with a wrong IBAN or checksum is not a payment, so it is refused
  // here too.
  static ScanVerdict? _check(Barcode barcode) =>
      barcode.content is PaymentContent
      ? null
      : const ScanVerdict.reject(title: 'Not a payment code');

  // The default sheet shows the payee and the amount; Pay goes on.
  static List<ScannerAction> _actions(
    BuildContext context,
    ScannerResult result,
  ) => [
    if (result.barcode.content case final PaymentContent payment)
      ScannerAction(
        label: 'Pay',
        primary: true,
        onPressed: () async {
          final bool? paid = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => _ConfirmPage(payment)),
          );
          if (paid ?? false) result.scanAgain();
        },
      ),
    ...result.defaultActions,
  ];

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: BarcodeScanner(
      template: ScannerTemplate.payment(
        check: _check,
        actionsBuilder: _actions,
      ),
    ),
  );
}

/// Your app's confirm screen, filled from the code.
class _ConfirmPage extends StatefulWidget {
  const _ConfirmPage(this.payment);

  final PaymentContent payment;

  @override
  State<_ConfirmPage> createState() => _ConfirmPageState();
}

class _ConfirmPageState extends State<_ConfirmPage> {
  // The amount is text such as '12.50'; null when the payer enters it.
  late final TextEditingController _amount = TextEditingController(
    text: widget.payment.amount,
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _pay() {
    // Your code: hand the payment to your bank or payment provider.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Paid ${_amount.text} to ${widget.payment.payee}'),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final PaymentContent payment = widget.payment;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm payment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('To'),
            subtitle: Text(payment.payee ?? ''),
          ),
          ListTile(
            title: const Text('Account'),
            subtitle: Text(payment.account ?? ''),
          ),
          if (payment.reference case final String reference)
            ListTile(title: const Text('Reference'), subtitle: Text(reference)),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            readOnly: payment.amount != null, // the code sets the amount
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: payment.currency,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _pay, child: const Text('Confirm and pay')),
        ],
      ),
    );
  }
}
