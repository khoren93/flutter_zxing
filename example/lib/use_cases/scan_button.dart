// A scan button: the app needs one code, opens the scanner, gets the code
// and goes on. scanBarcode returns null when the user closes the scanner.
// Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class ScanButtonPage extends StatefulWidget {
  const ScanButtonPage({super.key});

  @override
  State<ScanButtonPage> createState() => _ScanButtonPageState();
}

class _ScanButtonPageState extends State<ScanButtonPage> {
  Barcode? _barcode;

  Future<void> _scan() async {
    final Barcode? barcode = await scanBarcode(
      context,
      formats: {BarcodeFormat.qrCode}, // fewer formats read faster
      hint: 'Point the camera at a QR code',
    );
    if (barcode == null || !mounted) return; // closed
    setState(() => _barcode = barcode);
  }

  @override
  Widget build(BuildContext context) {
    final Barcode? barcode = _barcode;
    return Scaffold(
      appBar: AppBar(title: const Text('A scan button')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (barcode != null) ...[
                Text(barcode.format.displayName),
                const SizedBox(height: 8),
                SelectableText(
                  barcode.text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
              ],
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(barcode == null ? 'Scan a QR code' : 'Scan again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
