// Scan into a form: ScanFieldButton in three text fields, each showing one
// of its options (formats, valueOf, check), with the code of one of them.
import 'dart:async';

import 'package:flutter/services.dart';
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'tokens.dart';

/// The code of the batch field, for the card and its copy button.
const String _batchCode = '''TextField(
  controller: batch,
  decoration: InputDecoration(
    suffixIcon: ScanFieldButton(
      controller: batch,
      formats: {BarcodeFormat.dataMatrix},
      check: (b) => switch (b.content) {
        Gs1Content(batch: _?) => null,
        _ => const ScanVerdict.reject(title: 'No batch (10) in this code'),
      },
      valueOf: (b) => (b.content as Gs1Content).batch!,
    ),
  ),
)''';

class FieldDemoPage extends StatefulWidget {
  const FieldDemoPage({super.key});

  @override
  State<FieldDemoPage> createState() => _FieldDemoPageState();
}

class _FieldDemoPageState extends State<FieldDemoPage> {
  final TextEditingController _tracking = TextEditingController();
  final TextEditingController _batch = TextEditingController();
  final TextEditingController _gtin = TextEditingController();

  /// What filled each field last, for the line under it.
  final Map<TextEditingController, String> _from =
      <TextEditingController, String>{};

  @override
  void dispose() {
    _tracking.dispose();
    _batch.dispose();
    _gtin.dispose();
    super.dispose();
  }

  void _scanned(TextEditingController c, Barcode b) =>
      setState(() => _from[c] = '${b.format.displayName} · just scanned');

  Widget _field({
    required String label,
    required TextEditingController controller,
    required Widget button,
    required String note,
    required String option,
  }) {
    final Fz fz = Fz.of(context);
    final String? from = _from[controller];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: controller,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Type or scan',
            suffixIcon: button,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                from ?? note,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: from == null ? FontWeight.w500 : FontWeight.w600,
                  color: from == null ? fz.inkMuted : fz.lockInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: fz.raised,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: fz.line),
              ),
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: fz.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'ScanFieldButton',
        style: TextStyle(fontFamily: 'monospace', fontSize: 14),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              Text(
                'Scan into a form',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'The scan button sits in a text field. A scanner opens in a '
                'sheet over the form and fills the field.',
                style: TextStyle(fontSize: 15, color: Fz.of(context).inkMuted),
              ),
              const SizedBox(height: 24),
              _field(
                label: 'Tracking number',
                controller: _tracking,
                button: ScanFieldButton(
                  controller: _tracking,
                  title: 'Tracking number',
                  formats: BarcodeFormat.linear,
                  onScanned: (Barcode b) => _scanned(_tracking, b),
                ),
                note: 'Any linear barcode',
                option: 'formats',
              ),
              const SizedBox(height: 20),
              _field(
                label: 'Batch of a medicine pack',
                controller: _batch,
                button: ScanFieldButton(
                  controller: _batch,
                  title: 'Batch',
                  formats: const <BarcodeFormat>{BarcodeFormat.dataMatrix},
                  check: (Barcode b) => switch (b.content) {
                    Gs1Content(batch: _?) => null,
                    _ => const ScanVerdict.reject(
                      title: 'No batch (10) in this code',
                    ),
                  },
                  valueOf: (Barcode b) => (b.content as Gs1Content).batch!,
                  onScanned: (Barcode b) => _scanned(_batch, b),
                ),
                note:
                    'GS1 (10) from a Data Matrix; other codes are turned down',
                option: 'valueOf, check',
              ),
              const SizedBox(height: 20),
              _field(
                label: 'Product GTIN',
                controller: _gtin,
                button: ScanFieldButton(
                  controller: _gtin,
                  title: 'Product barcode',
                  formats: BarcodeFormat.retail,
                  valueOf: (Barcode b) => switch (b.content) {
                    ProductContent(:final String gtin) => gtin,
                    _ => b.text,
                  },
                  onScanned: (Barcode b) => _scanned(_gtin, b),
                ),
                note: 'EAN and UPC, as a 14-digit GTIN',
                option: 'formats, valueOf',
              ),
              const SizedBox(height: 28),
              Row(
                children: <Widget>[
                  const Expanded(child: FzLabel('The batch field')),
                  TextButton(
                    onPressed: () => unawaited(_copy()),
                    child: const Text('Copy'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1218),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Fz.of(context).line),
                ),
                // Lines as written: scrolled sideways, never wrapped.
                child: const SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    _batchCode,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.5,
                      color: Color(0xFFE6EBF2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _copy() async {
    await Clipboard.setData(const ClipboardData(text: _batchCode));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dart code copied')));
    }
  }
}
