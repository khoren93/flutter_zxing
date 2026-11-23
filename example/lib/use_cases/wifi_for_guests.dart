// A Wi-Fi card for guests: the network and its password as a QR code that
// phones join from the camera, shared as PNG or SVG to print and put on
// the wall. Android, iOS, macOS, the web. Also needs share_plus.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:share_plus/share_plus.dart';

class WifiForGuestsPage extends StatefulWidget {
  const WifiForGuestsPage({super.key});

  @override
  State<WifiForGuestsPage> createState() => _WifiForGuestsPageState();
}

class _WifiForGuestsPageState extends State<WifiForGuestsPage> {
  final _ssid = TextEditingController(text: 'Cafe Lumen Guests');
  final _password = TextEditingController(text: 'espresso2027');
  WifiSecurity _security = WifiSecurity.wpa;

  WifiContent get _wifi => WifiContent(
    ssid: _ssid.text,
    password: _security == WifiSecurity.none ? null : _password.text,
    security: _security,
  );

  BarcodeStyle get _style => BarcodeStyle.soft.copyWith(
    title: () => const BarcodeCaption('Free Wi‑Fi'),
    caption: () => BarcodeCaption('${_ssid.text}\nScan to join'),
    card: () => const BarcodeCard(color: Colors.white),
  );

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _share(BuildContext context, {required bool svg}) async {
    final box = context.findRenderObject() as RenderBox?;
    final String data = _wifi.toPayload();
    // The same card as on screen; SVG prints sharp at any size.
    final XFile file = svg
        ? XFile.fromData(
            utf8.encode(await _style.encodeSvg(data)),
            mimeType: 'image/svg+xml',
          )
        : XFile.fromData(
            await _style.encodePng(data, size: 2048),
            mimeType: 'image/png',
          );
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: [svg ? 'wifi.svg' : 'wifi.png'],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // What keeps the network from being built: an empty name, a short
    // WPA password…
    final bool valid = _wifi.validate().isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Wi‑Fi for guests')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _ssid,
            decoration: const InputDecoration(labelText: 'Network name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SegmentedButton<WifiSecurity>(
            segments: const [
              ButtonSegment(value: WifiSecurity.wpa, label: Text('WPA/WPA2')),
              ButtonSegment(value: WifiSecurity.wpa3, label: Text('WPA3')),
              ButtonSegment(value: WifiSecurity.none, label: Text('Open')),
            ],
            selected: {_security},
            onSelectionChanged: (s) => setState(() => _security = s.first),
          ),
          if (_security != WifiSecurity.none)
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: 24),
          Center(
            // Shows what is wrong instead of a code that cannot join.
            child: BarcodeContentView(
              _wifi,
              style: _style,
              width: 260,
              errorBuilder: (context, error) => Text(error.message),
            ),
          ),
          if (valid) ...[
            const SizedBox(height: 24),
            Builder(
              builder: (context) => Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => _share(context, svg: false),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share PNG'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _share(context, svg: true),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Share SVG to print'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
