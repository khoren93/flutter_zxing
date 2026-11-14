// The full fixture corpus (every zxing-cpp sample, ~950 images) on the host
// (macOS, Linux, Windows): same engine build and same check as the runs on
// devices and in the browser. See example/lib/corpus/corpus_harness.dart.
//
// The fixtures are generated, not committed: run `make fixtures` first.
// Without them the test is skipped locally and fails on CI.
//
// Regenerate example/assets/fixtures/corpus_expected.json after a deliberate
// change (zxing-cpp update):
//   UPDATE_CORPUS=1 flutter test test/engine/corpus_test.dart
@Tags(<String>['native'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

// The harness lives in the example app, see its header.
// ignore: avoid_relative_lib_imports
import '../../example/lib/corpus/corpus_harness.dart';

const String _fixtures = 'build/fixtures/corpus';
const String _expected = 'example/assets/fixtures/corpus_expected.json';

void main() {
  final bool generated = Directory(_fixtures).existsSync();
  final bool onCi = Platform.environment['CI'] == 'true';

  test(
    'corpus reads as recorded and as zxing-cpp expects',
    () async {
      if (!generated) {
        fail('$_fixtures is missing: run `make fixtures` before the tests');
      }
      final List<CorpusFixture> fixtures = await loadCorpus(
        Directory(
          _fixtures,
        ).listSync().whereType<File>().map((File f) => f.path),
        (String f) async => Uint8List.fromList(File(f).readAsBytesSync()),
      );
      expect(fixtures, hasLength(greaterThan(900)));
      final CorpusReport report = await runCorpus(fixtures);
      // ignore: avoid_print
      print(report.summary);

      final File expected = File(_expected);
      if (Platform.environment['UPDATE_CORPUS'] == '1') {
        expected.writeAsStringSync(report.toJson());
      }
      expect(report.problems, isEmpty, reason: 'misreads');
      expect(
        compareCorpus(report, expected.readAsStringSync(), complete: true),
        isEmpty,
      );
    },
    skip: generated || onCi ? false : 'run `make fixtures` first',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
