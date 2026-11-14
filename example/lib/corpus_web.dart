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

import 'corpus/corpus_harness.dart';

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
    outcome = jsonEncode(<String, Object>{
      'ok': report.problems.isEmpty && diffs.isEmpty,
      'summary': '${report.summary}, ${stopwatch.elapsedMilliseconds} ms',
      'problems': report.problems,
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
