// The Use cases tab: every case is registered, copyable as it is (only the
// package, Flutter and the packages it lists), and opens on a fake camera.
import 'dart:io';

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;
import 'package:flutter_zxing_example/demo/tokens.dart';
import 'package:flutter_zxing_example/demo/use_cases.dart';
import 'package:flutter_zxing_example/demo/use_cases_page.dart';

// The package's own fake camera.
// ignore: avoid_relative_lib_imports
import '../../test/scanning/fake_camera.dart';

const Size _phone = Size(390, 844);

const Set<String> _allowed = <String>{
  'dart:async',
  'dart:convert',
  'dart:math',
  'dart:typed_data',
  'package:flutter/material.dart',
  'package:flutter/services.dart',
  'package:flutter_zxing/flutter_zxing.dart',
};

const Map<String, String> _packages = <String, String>{
  'package:url_launcher/url_launcher.dart': 'url_launcher',
  'package:share_plus/share_plus.dart': 'share_plus',
  'package:image_picker/image_picker.dart': 'image_picker',
};

void main() {
  group('the files', () {
    test('every file in lib/use_cases is a registered case, and back', () {
      final Set<String> files = <String>{
        for (final FileSystemEntity f in Directory('lib/use_cases').listSync())
          if (f.path.endsWith('.dart')) f.uri.pathSegments.last,
      };
      expect(files, <String>{for (final UseCase c in useCases) '${c.id}.dart'});
      expect(
        useCases.map((UseCase c) => c.id).toSet(),
        hasLength(useCases.length),
      );
    });

    for (final UseCase c in useCases) {
      test('${c.id} copies as it is', () {
        final String source = File(c.file).readAsStringSync();
        final Set<String> imports = <String>{
          for (final RegExpMatch m in RegExp(
            r"^import '([^']+)'",
            multiLine: true,
          ).allMatches(source))
            m[1]!,
        };
        for (final String i in imports) {
          final String? package = _packages[i];
          expect(
            _allowed.contains(i) ||
                (package != null && c.needs.contains(package)),
            isTrue,
            reason: '${c.id} imports $i',
          );
        }
        for (final String p in c.needs) {
          expect(
            imports.any((String i) => _packages[i] == p),
            isTrue,
            reason: '${c.id} lists $p but does not import it',
          );
        }
        expect(source, isNot(contains('ignore:')), reason: c.id);
        expect(source, startsWith('// '), reason: '${c.id} says what it is');
      });
    }
  });

  group('the pages', () {
    late FakeCamera camera;

    setUp(() {
      camera = FakeCamera(transform: const FrameTransform(_phone));
      ScannerControllerDebug.cameraFactory = () => camera;
    });

    tearDown(() => ScannerControllerDebug.cameraFactory = null);

    Future<void> show(WidgetTester tester, Widget home) async {
      tester.view
        ..physicalSize = _phone
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: demoTheme(Brightness.light), home: home),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    for (final UseCase c in useCases) {
      testWidgets('${c.id} opens', (WidgetTester tester) async {
        await show(tester, Builder(builder: c.builder));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 4));
      });
    }

    testWidgets('the tab lists every case and shows its code', (
      WidgetTester tester,
    ) async {
      await show(tester, const Scaffold(body: UseCasesPage()));
      expect(find.text('A scan button'), findsOneWidget);
      await tester.tap(find.byTooltip('Show the code').first);
      await tester.pumpAndSettle();
      expect(find.text('use_cases/scan_button.dart'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is SelectableText &&
              (w.textSpan?.toPlainText() ?? '').contains('scanBarcode('),
        ),
        findsOneWidget,
      );
    });
  });
}
