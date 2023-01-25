import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class ScanResultWidget extends StatelessWidget {
  const ScanResultWidget({
    Key? key,
    this.result,
    this.onScanAgain,
  }) : super(key: key);

  final Code? result;
  final Function()? onScanAgain;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              result?.format?.name ?? '',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Text(
              result?.text ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Text(
              'Inverted: ${result?.isInverted}\t\tMirrored: ${result?.isMirrored}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: onScanAgain,
              child: const Text('Scan Again'),
            ),
          ],
        ),
      ),
    );
  }
}
