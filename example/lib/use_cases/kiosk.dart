// A self-service kiosk for order pickup: the customer holds the QR code
// from their order e-mail up to the front camera, and a large verdict says
// which locker opens. Try it with a QR code of ORDER-1001; a long press in
// the top-left corner leaves.
// Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class KioskPage extends StatefulWidget {
  const KioskPage({super.key});

  @override
  State<KioskPage> createState() => _KioskPageState();
}

class _KioskPageState extends State<KioskPage> {
  // Your code: the orders ready for pickup, from your server.
  final Map<String, ({String name, int locker})> _ready = {
    'ORDER-1001': (name: 'Anna', locker: 4),
    'ORDER-1002': (name: 'Lucas', locker: 7),
    'ORDER-1003': (name: 'Mei', locker: 12),
  };
  final Set<String> _collected = {};

  Future<ScanVerdict?> _check(Barcode barcode) async {
    final String order = barcode.text;
    final ready = _ready[order];
    if (ready == null) {
      return const ScanVerdict.reject(
        title: 'Order not found',
        message: 'Please ask at the counter',
      );
    }
    if (_collected.contains(order)) {
      return ScanVerdict.warn(
        title: 'Already collected',
        message: 'Locker ${ready.locker} was opened before',
      );
    }
    // Your code: open the locker.
    _collected.add(order);
    return ScanVerdict.accept(
      title: 'Hello, ${ready.name}!',
      message: 'Your order is in locker ${ready.locker}',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BarcodeScanner(
      template: ScannerTemplate.kiosk(
        title: 'Pick up your order',
        hint: 'Hold the QR code from your e-mail up to the camera',
        check: _check,
        // Long enough to read the locker number from a step away.
        resumeAfter: const Duration(seconds: 5),
        // No buttons: staff leave with a long press in the top-left corner.
        hiddenExit: true,
      ),
    ),
  );
}
