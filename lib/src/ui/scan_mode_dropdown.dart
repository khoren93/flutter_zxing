// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; this package still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

class ScanModeDropdown extends StatelessWidget {
  const ScanModeDropdown({
    super.key,
    this.isMultiScan = false,
    this.onChanged,
    this.alignment = Alignment.bottomRight,
    this.padding = const EdgeInsets.all(10),
  });

  final bool isMultiScan;
  final Function(bool value)? onChanged;

  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
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
