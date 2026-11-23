// Scan into a form: a scan button in each text field fills it from the
// barcode on the box, for a form that asks for a serial number, an IMEI or
// a tracking number. Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class ScanIntoFormPage extends StatefulWidget {
  const ScanIntoFormPage({super.key});

  @override
  State<ScanIntoFormPage> createState() => _ScanIntoFormPageState();
}

class _ScanIntoFormPageState extends State<ScanIntoFormPage> {
  final TextEditingController _serial = TextEditingController();
  final TextEditingController _imei = TextEditingController();
  final TextEditingController _tracking = TextEditingController();

  @override
  void dispose() {
    _serial.dispose();
    _imei.dispose();
    _tracking.dispose();
    super.dispose();
  }

  // An IMEI is 15 digits; the box also carries other Code 128 barcodes,
  // such as the EAN or the serial number, which the scanner refuses here.
  static ScanVerdict? _checkImei(Barcode barcode) =>
      RegExp(r'^\d{15}$').hasMatch(barcode.text)
      ? null
      : const ScanVerdict.reject(
          title: 'Not an IMEI',
          message: 'Scan the barcode next to "IMEI" on the box.',
        );

  void _register() {
    // Your code: send the device to your server.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Registered ${_serial.text}')));
  }

  Widget _field(String label, TextEditingController controller, Widget scan) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: scan,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Register a device')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _field(
          'Serial number',
          _serial,
          ScanFieldButton(
            controller: _serial,
            title: 'Serial number',
            formats: {BarcodeFormat.code128, BarcodeFormat.dataMatrix},
          ),
        ),
        _field(
          'IMEI',
          _imei,
          ScanFieldButton(
            controller: _imei,
            title: 'IMEI',
            formats: {BarcodeFormat.code128},
            check: _checkImei,
          ),
        ),
        _field(
          'Tracking number',
          _tracking,
          ScanFieldButton(
            controller: _tracking,
            title: 'Tracking number',
            formats: BarcodeFormat.linear, // the label's barcode
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _register, child: const Text('Register')),
      ],
    ),
  );
}
