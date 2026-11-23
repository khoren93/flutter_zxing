// Add a 2FA account: an authenticator app scans the otpauth:// QR code a
// service shows when two-factor sign-in is turned on, and keeps the
// account. Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class AddTwoFactorPage extends StatefulWidget {
  const AddTwoFactorPage({super.key});

  @override
  State<AddTwoFactorPage> createState() => _AddTwoFactorPageState();
}

class _AddTwoFactorPageState extends State<AddTwoFactorPage> {
  OtpContent? _account;

  Future<void> _scan() async {
    final Barcode? barcode = await scanBarcode(
      context,
      formats: {BarcodeFormat.qrCode},
      hint: 'Scan the QR code from the service’s 2FA settings',
      // Any other code keeps the scanner open with this message.
      check: (barcode) => barcode.content is OtpContent
          ? null
          : const ScanVerdict.reject(
              title: 'Not a 2FA code',
              message: 'Look for the code that starts two-factor sign-in.',
            ),
    );
    if (barcode == null || !mounted) return; // closed
    final OtpContent otp = barcode.content as OtpContent;
    // Your code: keep otp.secret in secure storage, such as the Keychain.
    setState(() => _account = otp);
  }

  @override
  Widget build(BuildContext context) {
    final OtpContent? account = _account;
    return Scaffold(
      appBar: AppBar(title: const Text('Add a 2FA account')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (account != null) ...[
                _AccountCard(account),
                const SizedBox(height: 24),
              ],
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(account == null ? 'Add an account' : 'Add another'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard(this.otp);

  final OtpContent otp;

  @override
  Widget build(BuildContext context) {
    // The secret signs the user in: show only its end, to tell accounts
    // apart.
    final String secret = otp.secret;
    final String hint = secret.length > 4
        ? '•••• ${secret.substring(secret.length - 4)}'
        : '••••';
    final String timing = otp.type == OtpType.totp
        ? 'every ${otp.period} s'
        : 'counter ${otp.counter}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user_outlined, size: 40),
            const SizedBox(height: 8),
            Text(
              'Account added',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(otp.issuer ?? 'Unknown service'),
            Text(otp.account),
            const SizedBox(height: 8),
            Text(
              '${otp.digits} digits $timing, '
              '${otp.algorithm.name.toUpperCase()} · secret $hint',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
