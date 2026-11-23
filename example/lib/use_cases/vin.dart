// A vehicle's VIN into a record: scan the code on the windshield or the
// door pillar and the form fills with the VIN, maker code, region and
// model year. Try it with a Code 39 of 1HGCM82633A004352.
// Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class VinPage extends StatefulWidget {
  const VinPage({super.key});

  @override
  State<VinPage> createState() => _VinPageState();
}

class _VinPageState extends State<VinPage> {
  final TextEditingController _vin = TextEditingController();
  final TextEditingController _maker = TextEditingController();
  final TextEditingController _region = TextEditingController();
  final TextEditingController _year = TextEditingController();
  bool? _checkDigitOk;

  Future<void> _scan() async {
    final VinContent? vin = await scanContent<VinContent>(
      context,
      template: const ScannerTemplate.vin(),
      reject: const ScanVerdict.reject(title: 'Not a VIN'),
    );
    if (vin != null && mounted) {
      setState(() {
        _vin.text = vin.vin;
        _maker.text = vin.wmi; // Your code: the maker's name for the WMI
        // In the language of the scanner's texts (ScannerLocalizations).
        _region.text = ScannerLocalizations.of(context).vinRegionOf(vin.region);
        _year.text = vin.modelYear?.toString() ?? '';
        _checkDigitOk = vin.hasValidCheckDigit;
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_vin, _maker, _region, _year]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New vehicle')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _vin,
          decoration: InputDecoration(
            labelText: 'VIN',
            // Only North American VINs must carry the check digit.
            helperText: _checkDigitOk == false
                ? 'The check digit does not match: compare with the plate'
                : null,
            suffixIcon: IconButton(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan the VIN',
            ),
          ),
        ),
        TextField(
          controller: _maker,
          decoration: const InputDecoration(labelText: 'Maker code (WMI)'),
        ),
        TextField(
          controller: _region,
          decoration: const InputDecoration(labelText: 'Made in'),
        ),
        TextField(
          controller: _year,
          decoration: const InputDecoration(labelText: 'Model year'),
        ),
        const SizedBox(height: 24),
        FilledButton(
          // Your code: save the vehicle record.
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
