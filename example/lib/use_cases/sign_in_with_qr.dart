// Sign in on another screen: your TV or web app shows a QR code, the
// signed-in phone scans it and confirms. To try it, scan a QR code of
// https://example.com/login/TV-4821. Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class SignInWithQrPage extends StatefulWidget {
  const SignInWithQrPage({super.key});

  @override
  State<SignInWithQrPage> createState() => _SignInWithQrPageState();
}

class _SignInWithQrPageState extends State<SignInWithQrPage> {
  // Your code: the address your other screen puts in its QR code.
  static const String _prefix = 'https://example.com/login/';

  String? _session; // the screen signed in, once confirmed

  // Only your service's login codes; anything else keeps the scanner open.
  static ScanVerdict? _check(Barcode barcode) =>
      barcode.text.startsWith(_prefix) && barcode.text.length > _prefix.length
      ? null
      : const ScanVerdict.reject(
          title: 'Not a sign-in code',
          message: 'Scan the code on the screen you want to sign in on.',
        );

  Future<void> _scan() async {
    final Barcode? barcode = await scanBarcode(
      context,
      template: const ScannerTemplate.signIn(check: _check),
    );
    if (barcode == null || !mounted) return; // closed
    final String session = barcode.text.substring(_prefix.length);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign in on this screen?'),
        content: const Text('Only confirm if you started the sign-in there.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Your code: send the session to your server with this user's token;
    // the other screen then signs in.
    setState(() => _session = session);
  }

  @override
  Widget build(BuildContext context) {
    final String? session = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in on another screen')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                session == null ? Icons.tv_rounded : Icons.check_circle_rounded,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                session == null
                    ? 'Open the app on your TV or go to example.com, then scan '
                          'the code it shows.'
                    : 'Signed in on $session',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(session == null ? 'Scan the code' : 'Another one'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
