// The web has no diagnostics page: the demo shows no button for it there.
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// Nothing to show.
class DiagnosticsPage extends StatelessWidget {
  /// Creates the page.
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
