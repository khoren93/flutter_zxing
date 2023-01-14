import 'package:flutter/material.dart';

class ScanModeDropdown extends StatelessWidget {
  const ScanModeDropdown({
    Key? key,
    this.isMultiScan = false,
    this.onChanged,
  }) : super(key: key);

  final bool isMultiScan;
  final Function(bool value)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<bool>(
              value: isMultiScan,
              items: const [
                DropdownMenuItem(
                  value: false,
                  child: Text('Single Scan'),
                ),
                DropdownMenuItem(
                  value: true,
                  child: Text('Multi Scan'),
                ),
              ],
              onChanged: (value) => onChanged?.call(value ?? false),
            ),
          ),
        ),
      ),
    );
  }
}
