// Pick one of many: a shipping label or a box carries several barcodes;
// every code in view gets a label and a tap picks the one the app needs.
// Try it on any parcel label. Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class PickOnePage extends StatefulWidget {
  const PickOnePage({super.key});

  @override
  State<PickOnePage> createState() => _PickOnePageState();
}

class _PickOnePageState extends State<PickOnePage> {
  Barcode? _picked;

  Future<void> _pick() async {
    // The picked code comes back as the result; null when closed.
    final Barcode? barcode = await scanBarcode(
      context,
      template: const ScannerTemplate.pick(
        title: 'Tap the tracking number',
        // Linear codes only: the QR code of the carrier's app stays out.
        formats: BarcodeFormat.linear,
      ),
    );
    if (barcode == null || !mounted) return;
    // Your code: look the parcel up by its tracking number.
    setState(() => _picked = barcode);
  }

  @override
  Widget build(BuildContext context) {
    final Barcode? picked = _picked;
    return Scaffold(
      appBar: AppBar(title: const Text('Track a parcel')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (picked != null) ...[
                Text(picked.format.displayName),
                const SizedBox(height: 8),
                SelectableText(
                  picked.text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
              ],
              FilledButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.touch_app_outlined),
                label: Text(picked == null ? 'Scan the label' : 'Pick another'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
