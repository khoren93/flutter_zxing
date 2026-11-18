// The diagnostics page: every engine setting on the live camera, with the
// numbers it changes. Run it with `make diag` (a profile build; debug builds
// say nothing about speed). Android, iOS, macOS, Linux and Windows.
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'diagnostics/diagnostics_page.dart';

void main() => runApp(const DiagnosticsApp());

/// The diagnostics page as an app of its own: nothing else runs beside it.
class DiagnosticsApp extends StatelessWidget {
  /// Creates the app.
  const DiagnosticsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'flutter_zxing diagnostics',
    theme: ThemeData.dark(useMaterial3: true),
    home: const DiagnosticsPage(),
  );
}
