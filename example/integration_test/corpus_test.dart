// The engine's fixture corpus on a real device or desktop: built by the
// package's build hook for this platform, compared with the results recorded
// in example/assets/fixtures/corpus_expected.json. See example/lib/corpus/corpus_harness.dart.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_zxing_example/corpus/corpus_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('corpus reads the same as recorded and as zxing-cpp expects', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
        rootBundle,
      );
      final List<CorpusFixture> fixtures = await loadCorpus(
        manifest.listAssets().where(
          (String a) => a.contains('assets/fixtures/'),
        ),
        (String a) async => (await rootBundle.load(a)).buffer.asUint8List(),
      );
      expect(
        fixtures,
        hasLength(greaterThan(100)),
        reason: 'the corpus is generated: run `make fixtures` first',
      );
      final Stopwatch stopwatch = Stopwatch()..start();
      final CorpusReport report = await runCorpus(fixtures);
      // ignore: avoid_print
      print('${report.summary}, ${stopwatch.elapsedMilliseconds} ms');
      expect(report.problems, isEmpty, reason: 'misreads');
      expect(
        compareCorpus(
          report,
          await rootBundle.loadString('assets/fixtures/corpus_expected.json'),
        ),
        isEmpty,
      );
    });
  });
}
