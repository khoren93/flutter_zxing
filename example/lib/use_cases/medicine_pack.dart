// A medicine pack before it is dispensed: the GS1 Data Matrix gives the
// GTIN, batch, serial number and expiry date; expired packs and recalled
// batches are refused. Try it with a GS1 Data Matrix of
// (01)09506000134352(17)271231(10)A1B2C3(21)12345678901.
// Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class MedicinePackPage extends StatelessWidget {
  const MedicinePackPage({super.key});

  // Your code: the batches your verification system has recalled.
  static const Set<String> _recalled = {'RECALL1'};

  ScanVerdict? _check(Barcode barcode, ScannerStrings strings) {
    final BarcodeContent content = barcode.content;
    if (content is! Gs1Content || content.gtin == null) {
      return const ScanVerdict.reject(
        title: 'Not a medicine pack',
        message: 'Scan the square code on the pack',
      );
    }
    if (content.isExpired()) {
      return ScanVerdict.reject(
        title: 'Expired',
        message:
            'Expired on ${strings.fullDate(content.expiryDate!)}. '
            'Do not dispense.',
      );
    }
    if (_recalled.contains(content.batch)) {
      return ScanVerdict.reject(
        title: 'Recalled batch',
        message: 'Batch ${content.batch}. Do not dispense.',
      );
    }
    return null; // accepted: the sheet shows the pack
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BarcodeScanner(
      template: ScannerTemplate.pharma(
        title: 'Dispense',
        // The dates in the language of the scanner's texts.
        check: (barcode) => _check(barcode, ScannerStrings.of(context)),
        actionsBuilder: (context, result) => [
          ScannerAction(
            label: 'Dispense',
            primary: true,
            onPressed: () {
              // Your code: decommission the serial number in your national
              // verification system (FMD, DSCSA), then record the sale.
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Pack dispensed')));
              result.scanAgain();
            },
          ),
          ...result.defaultActions,
        ],
      ),
    ),
  );
}
