import 'package:flutter/material.dart';

class DebugInfoWidget extends StatelessWidget {
  const DebugInfoWidget({
    Key? key,
    required this.successScans,
    required this.failedScans,
    this.error,
    this.duration = 0,
    this.onReset,
  }) : super(key: key);

  final int successScans;
  final int failedScans;
  final String? error;
  final int duration;

  final Function()? onReset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: Colors.white.withOpacity(0.7),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Success: $successScans\nFailed: $failedScans\nDuration: $duration ms',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton(
                  onPressed: onReset,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
