// The Field tab of the diagnostics page, driven like on a phone.
//
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing_example/diagnostics/diag_settings.dart';
import 'package:flutter_zxing_example/diagnostics/field_codes.dart';
import 'package:flutter_zxing_example/diagnostics/field_session.dart';
import 'package:flutter_zxing_example/diagnostics/field_tab.dart';
import 'package:flutter_zxing_example/diagnostics/frame_recorder.dart';

void main() {
  late FieldSession session;
  late FrameRecorder recorder;
  late RecordingStore store;

  setUp(() {
    session = FieldSession(device: 'phone', build: 'profile');
    recorder = FrameRecorder();
    store = RecordingStore();
  });

  tearDown(() {
    session.dispose();
    recorder.dispose();
    store.dispose();
  });

  Future<void> pumpTab(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DiagFieldTab(
          session: session,
          recorder: recorder,
          store: store,
          settings: const DiagSettings(),
        ),
      ),
    ),
  );

  testWidgets('a code is started, read and the next one offered', (
    WidgetTester tester,
  ) async {
    await pumpTab(tester);
    final FieldCode first = fieldCodes.first;
    await tester.tap(find.textContaining('Aim at ${first.id} '));
    await tester.pump();
    expect(session.running, first);
    expect(recorder.armed, isTrue);

    session.onReads(<(String, String)>[(first.format, first.text)]);
    await tester.pump();
    expect(session.resultOf(first)!.outcome, FieldOutcome.pass);
    expect(find.textContaining('Aim at ${fieldCodes[1].id} '), findsOneWidget);
    expect(find.textContaining('Pass 1'), findsOneWidget);
  });

  testWidgets('finished conditions lead to the next ones', (
    WidgetTester tester,
  ) async {
    for (final FieldCode code in fieldCodes) {
      session
        ..start(code, const <String, Object?>{})
        ..giveUp();
    }
    await pumpTab(tester);
    await tester.tap(find.textContaining('Go on to ${fieldPlan[1].label}'));
    await tester.pump();
    expect(session.conditions, fieldPlan[1]);
    expect(
      find.textContaining('Aim at ${fieldCodes.first.id} '),
      findsOneWidget,
    );
  });

  testWidgets('giving up asks about the phone camera', (
    WidgetTester tester,
  ) async {
    await pumpTab(tester);
    await tester.tap(find.textContaining('Aim at '));
    await tester.pump();
    await tester.tap(find.text("Can't read"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    final FieldResult result = session.results.single;
    expect(result.outcome, FieldOutcome.fail);
    expect(result.systemCamera, isFalse);
  });
}
