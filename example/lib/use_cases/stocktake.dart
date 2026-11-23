// Stocktake: scan the products on a shelf one after another, each barcode
// goes into a list with its count, and "Done" hands the list to the app to
// send. Try it with any product barcodes. Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class StocktakePage extends StatefulWidget {
  const StocktakePage({super.key});

  @override
  State<StocktakePage> createState() => _StocktakePageState();
}

class _StocktakePageState extends State<StocktakePage> {
  /// The counted products once "Done" is tapped; `null` while scanning.
  List<CollectedBarcode>? _counted;
  bool _sending = false;

  Future<void> _send(List<CollectedBarcode> counted) async {
    setState(() => _sending = true);
    // Your code: send the count to your inventory system.
    final Map<String, int> count = {
      for (final item in counted) item.barcode.text: item.count,
    };
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Sent ${count.length} products')));
  }

  @override
  Widget build(BuildContext context) {
    final List<CollectedBarcode>? counted = _counted;
    if (counted == null) {
      return Scaffold(
        body: BarcodeScanner(
          template: ScannerTemplate.retail(
            title: 'Aisle 4',
            sound: true, // a click for each scan, eyes stay on the shelf
            onDone: (items) => setState(() => _counted = items),
          ),
        ),
      );
    }
    final int total = counted.fold(0, (sum, item) => sum + item.count);
    return Scaffold(
      appBar: AppBar(title: Text('Aisle 4: $total items')),
      body: ListView(
        children: [
          for (final item in counted)
            ListTile(
              title: Text(item.barcode.text),
              subtitle: Text(item.barcode.format.displayName),
              trailing: Text(
                '× ${item.count}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _counted = null),
                  child: const Text('Count again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _sending || counted.isEmpty
                      ? null
                      : () => _send(counted),
                  child: Text(_sending ? 'Sending…' : 'Send'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
