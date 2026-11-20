// Runs the engine's fixture corpus in the browser and prints the outcome to
// the console, for tool/web_corpus_test.mjs (headless Chrome):
//   flutter build web -t lib/corpus_web.dart [--wasm]
// The integration tests do the same on native platforms
// (integration_test/corpus_test.dart).
import 'dart:convert';

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; this package still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'corpus/corpus_harness.dart';

/// The errors the engine reports in the browser: each must arrive as the
/// exception the API documents. Returns what did not.
Future<List<String>> _errorChecks() async {
  final List<String> failed = <String>[];
  Future<void> expectThrows<T extends Object>(
    String what,
    Future<Object?> Function() call,
  ) async {
    try {
      await call();
      failed.add('$what: no $T');
    } on T {
      // As documented.
    } on Object catch (e) {
      failed.add('$what: $e instead of $T');
    }
  }

  const BarcodeReader reader = BarcodeReader();
  await expectThrows<ImageDecodeException>(
    'reading a file that is not an image',
    () => reader.read(Uint8List.fromList(utf8.encode('no image'))),
  );
  // A PNG header that declares 20000 x 20000 pixels.
  await expectThrows<ImageDecodeException>(
    'reading an image too large',
    () => reader.read(
      Uint8List.fromList(<int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, //
        0x49, 0x48, 0x44, 0x52, 0, 0, 0x4E, 0x20, 0, 0, 0x4E, 0x20, //
        8, 0, 0, 0, 0, 0xC6, 0x1B, 0x19, 0xE5, 0, 0, 0, 0, //
        0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]),
    ),
  );
  await expectThrows<BarcodeWriteException>(
    'encoding letters as EAN-13',
    () => const BarcodeWriter(BarcodeFormat.ean13).encode('letters'),
  );
  await expectThrows<BarcodeWriteException>(
    'encoding nothing',
    () => const BarcodeWriter(BarcodeFormat.qrCode).encode(''),
  );
  // A code on a transparent background reads.
  final BarcodeSymbol symbol = await const BarcodeWriter(
    BarcodeFormat.qrCode,
  ).encode('alpha');
  final Uint8List png = await const BarcodeStyle(
    backgroundColor: Color(0x00000000),
  ).toPng(symbol, moduleSize: 4);
  final String? text = (await reader.read(png))?.text;
  if (text != 'alpha') {
    failed.add('a code on a transparent background: $text');
  }
  return failed;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('corpus'))),
    ),
  );
  String outcome;
  try {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
      rootBundle,
    );
    final List<CorpusFixture> fixtures = await loadCorpus(
      manifest.listAssets().where((String a) => a.contains('assets/fixtures/')),
      (String a) async => (await rootBundle.load(a)).buffer.asUint8List(),
    );
    if (fixtures.isEmpty) {
      throw StateError('no fixtures: run `make fixtures` before the build');
    }
    final Stopwatch stopwatch = Stopwatch()..start();
    final CorpusReport report = await runCorpus(fixtures);
    final List<String> diffs = compareCorpus(
      report,
      await rootBundle.loadString('assets/fixtures/corpus_expected.json'),
    );
    final List<String> errors = await _errorChecks();
    outcome = jsonEncode(<String, Object>{
      'ok': report.problems.isEmpty && diffs.isEmpty && errors.isEmpty,
      'summary': '${report.summary}, ${stopwatch.elapsedMilliseconds} ms',
      'problems': <String>[...report.problems, ...errors],
      'diffs': diffs,
    });
  } on Object catch (e, stack) {
    outcome = jsonEncode(<String, Object>{
      'ok': false,
      'summary': 'crashed: $e',
      'problems': <String>['$stack'],
      'diffs': <String>[],
    });
  }
  // ignore: avoid_print
  print('FZX_CORPUS $outcome');
}
