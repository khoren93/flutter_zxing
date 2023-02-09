import 'package:flutter/material.dart';

class ScanModeDropdown extends StatelessWidget {
  const ScanModeDropdown({
    super.key,
    this.isMultiScan = false,
    this.onChanged,
  });

  final bool isMultiScan;
  final Function(bool value)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<bool>(
              value: isMultiScan,
              dropdownColor: Colors.black87,
              items: const <DropdownMenuItem<bool>>[
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(
                    'Single Code',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(
                    'Multi Code',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
              onChanged: (bool? value) => onChanged?.call(value ?? false),
            ),
          ),
        ),
      ),
    );
  }
}
