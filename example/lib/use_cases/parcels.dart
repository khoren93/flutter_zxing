// Receive parcels: scan the GS1-128 labels of incoming parcels and pallets;
// the SSCC, GTIN, quantity and batch of each go into a received list.
// Try it with a GS1-128 of (00)106141411234567897(02)09501101530003(37)12(10)LOT42.
// Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class ParcelsPage extends StatefulWidget {
  const ParcelsPage({super.key});

  @override
  State<ParcelsPage> createState() => _ParcelsPageState();
}

class _ParcelsPageState extends State<ParcelsPage> {
  /// The labels once "Done" is tapped; `null` while scanning.
  List<Gs1Content>? _received;

  // Only GS1 labels go into the list.
  ScanVerdict? _check(Barcode barcode) => barcode.content is Gs1Content
      ? null
      : const ScanVerdict.reject(
          title: 'Not a GS1 label',
          message: 'Scan the barcode with (00) under it',
        );

  void _done(List<CollectedBarcode> items) {
    final List<Gs1Content> labels = [
      for (final item in items)
        if (item.barcode.content case final Gs1Content label) label,
    ];
    // Your code: book the parcels into your warehouse system.
    setState(() => _received = labels);
  }

  @override
  Widget build(BuildContext context) {
    final List<Gs1Content>? received = _received;
    if (received == null) {
      return Scaffold(
        body: BarcodeScanner(
          template: ScannerTemplate.logistics(
            title: 'Goods in: dock 2',
            check: _check,
            onDone: _done,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('${received.length} parcels received')),
      body: ListView(
        children: [
          for (final label in received)
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text('SSCC ${label.sscc ?? '–'}'),
              subtitle: Text(
                [
                  // A pallet names its goods with AI 02, a trade item with 01.
                  if (label.gtin ?? label.elements['02'] case final gtin?)
                    'GTIN $gtin',
                  if (label.batch case final batch?) 'Batch $batch',
                ].join(' · '),
              ),
              trailing: label.count == null ? null : Text('× ${label.count}'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _received = null),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan more'),
      ),
    );
  }
}
