// A ticket in the app: an event ticket card with the code the door scans,
// as a QR code, Aztec (airlines, railways), PDF417 or a Code 128 barcode
// for older laser scanners. Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class TicketCardPage extends StatefulWidget {
  const TicketCardPage({super.key});

  @override
  State<TicketCardPage> createState() => _TicketCardPageState();
}

class _TicketCardPageState extends State<TicketCardPage> {
  // Your code: the ticket from your server.
  static const String _event = 'Spring Jazz Night';
  static const String _date = 'Sat, 14 March · 19:30';
  static const String _seat = 'Row F · Seat 12';
  static const String _ticket = 'TICKET-1002';

  BarcodeFormat _format = BarcodeFormat.qrCode;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    // Tip: a door scanner reads a phone screen best at full brightness;
    // raise it while the ticket is open (for example with the
    // screen_brightness package) and restore it when the page closes.
    final bool linear = _format == BarcodeFormat.code128;
    return Scaffold(
      appBar: AppBar(title: const Text('My ticket')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_event, style: text.headlineSmall),
                      const SizedBox(height: 4),
                      const Text(_date),
                      const Text(_seat),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  // The code stays black on white: a door scanner reads
                  // contrast, not colours.
                  child: BarcodeView(
                    _ticket,
                    writer: BarcodeWriter(_format),
                    width: linear ? 280 : 220,
                    height: linear ? 110 : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(_ticket, style: text.labelLarge),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SegmentedButton<BarcodeFormat>(
            segments: const [
              ButtonSegment(value: BarcodeFormat.qrCode, label: Text('QR')),
              ButtonSegment(value: BarcodeFormat.aztec, label: Text('Aztec')),
              ButtonSegment(value: BarcodeFormat.pdf417, label: Text('PDF417')),
              ButtonSegment(value: BarcodeFormat.code128, label: Text('128')),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
        ],
      ),
    );
  }
}
