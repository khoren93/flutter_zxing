// Tickets at the door: the scanner never stops, each ticket is checked
// against the guest list and gets a green, amber or red verdict, and a
// counter shows how many came in, with your own sound for each verdict.
// Android, iOS, macOS, the web.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class DoorCheckInPage extends StatefulWidget {
  const DoorCheckInPage({super.key});

  @override
  State<DoorCheckInPage> createState() => _DoorCheckInPageState();
}

class _DoorCheckInPageState extends State<DoorCheckInPage> {
  // Your code: the guest list from your server, by ticket number.
  final Map<String, String> _guests = {
    'TICKET-1001': 'Anna Petrova',
    'TICKET-1002': 'Lucas Martin',
    'TICKET-1003': 'Mei Tanaka',
  };
  final Set<String> _inside = {};

  Future<ScanVerdict?> _check(Barcode barcode) async {
    final String ticket = barcode.text;
    final String? guest = _guests[ticket];
    if (guest == null) {
      return const ScanVerdict.reject(
        title: 'Not on the list',
        message: 'Send the guest to the box office.',
      );
    }
    if (!_inside.add(ticket)) {
      return ScanVerdict.warn(title: guest, message: 'Already checked in');
    }
    return ScanVerdict.accept(title: guest, message: 'Welcome!');
  }

  // Instead of the template's sounds and haptics.
  void _feedback(ScanFeedback kind) {
    // Your own sound: play your app's beep and buzz here, such as with an
    // audio package. This one only buzzes, harder for a refused ticket.
    unawaited(switch (kind) {
      ScanFeedback.rejected => HapticFeedback.vibrate(),
      ScanFeedback.warned => HapticFeedback.heavyImpact(),
      _ => HapticFeedback.lightImpact(),
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BarcodeScanner(
      template: ScannerTemplate.checkIn(
        check: _check,
        hint: 'Scan the ticket',
        onFeedback: _feedback,
      ),
    ),
  );
}
