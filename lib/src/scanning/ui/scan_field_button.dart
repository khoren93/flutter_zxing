import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../barcode/barcode.dart';
import '../../barcode/barcode_format.dart';
import '../l10n/scanner_localizations.dart';
import '../scan_window.dart';
import '../scanner_controller.dart';
import 'pressable.dart';
import 'scan_verdict.dart';
import 'scanner_icons.dart';
import 'scanner_template.dart';
import 'scanner_theme.dart';

/// A button for a text field that fills it from a barcode: it opens a
/// scanner in a sheet ([scanBarcode]), puts the code into [controller] and
/// closes.
///
/// ```dart
/// TextField(
///   controller: tracking,
///   decoration: InputDecoration(
///     labelText: 'Tracking number',
///     suffixIcon: ScanFieldButton(
///       controller: tracking,
///       title: 'Tracking number',
///       formats: {BarcodeFormat.code128},
///     ),
///   ),
/// )
/// ```
///
/// A [check] refuses codes that do not fit the field, such as a wrong
/// prefix; the scanner then stays open with the verdict's text.
class ScanFieldButton extends StatelessWidget {
  /// Creates the button.
  const ScanFieldButton({
    super.key,
    required this.controller,
    this.formats,
    this.check,
    this.valueOf,
    this.title,
    this.hint,
    this.template,
    this.presentation = ScannerPresentation.sheet,
    this.theme,
    this.texts,
    this.onScanned,
  });

  /// The field's controller, which gets the code.
  final TextEditingController controller;

  /// The formats the scanner reads; `null` reads the [template]'s formats,
  /// or all without one.
  final Set<BarcodeFormat>? formats;

  /// Accepts or refuses each code.
  final ScannerCheck? check;

  /// What goes into the field; default [Barcode.text].
  final String Function(Barcode barcode)? valueOf;

  /// A title pill over the scanner, such as the field's label.
  final String? title;

  /// A hint under the scan window; default [ScannerLocalizations.hintField], or
  /// the [template]'s hint. An empty string for none.
  final String? hint;

  /// The scanner screen; default a wide window for linear and 2D codes
  /// with the torch, without photo and zoom buttons.
  final ScannerTemplate? template;

  /// A sheet over the form (the default) or a full-screen page.
  final ScannerPresentation presentation;

  /// Colors and shapes of the scanner, merged onto the template's; the
  /// button takes its accent too.
  final ScannerTheme? theme;

  /// The texts of the scanner and the button's label.
  final ScannerLocalizations? texts;

  /// Called with the code after the field was filled.
  final ValueChanged<Barcode>? onScanned;

  Future<void> _scan(BuildContext context) async {
    final ScannerTemplate base =
        template ??
        const ScannerTemplate(
          scanWindow: ScanWindow.centered(
            width: 0.84,
            aspectRatio: 1.6,
            alignment: Alignment(0, -0.1),
          ),
          hintIcon: ScannerIcons.barcode,
        );
    final Barcode? barcode = await scanBarcode(
      context,
      formats: formats,
      check: check,
      presentation: presentation,
      template: title == null ? base : base.copyWith(title: () => title),
      hint:
          hint ??
          (template == null
              ? (texts ?? ScannerLocalizations.of(context)).hintField
              : null),
      theme: theme,
      texts: texts,
    );
    if (barcode == null) {
      return;
    }
    final String value = valueOf?.call(barcode) ?? barcode.text;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    onScanned?.call(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final ScannerTheme resolved = ScannerTheme.of(context).merge(theme);
    final ScannerLocalizations texts =
        this.texts ?? ScannerLocalizations.of(context);
    const ShapeBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    return Semantics(
      button: true,
      label: title == null ? texts.scanCode : '${texts.scanCode}: $title',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Pressable(
          onPressed: () => unawaited(_scan(context)),
          shape: shape,
          // A 48 × 48 target around the 44 × 44 button.
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: resolved.lockSoftColor,
                  shape: shape,
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: ScannerIcon(
                      ScannerIcons.scan,
                      size: 24,
                      color: resolved.lockInkColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
