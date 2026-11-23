// The field test of the diagnostics page: what counts as a read, how long it
// took, and the table it gives.
import 'package:flutter_test/flutter_test.dart';

// The field test lives in the example app.
// ignore: avoid_relative_lib_imports
import '../../example/lib/diagnostics/field_codes.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/diagnostics/field_session.dart';

void main() {
  late int now;
  late FieldSession session;
  final FieldCode qr = fieldCodes.first;

  setUp(() {
    now = 1000;
    session = FieldSession(device: 'phone', build: 'profile', nowMs: () => now);
  });

  tearDown(() => session.dispose());

  test('every code of the sheet can be told from the others', () {
    // DataBar Expanded and its stacked form hold the same text and count
    // as one format (zxing-cpp often names the stacked one plain): the field
    // test waits for one code at a time, so a read of either is that code.
    const Set<String> sameText = <String>{'W25', 'W26'};
    for (final FieldCode a in fieldCodes) {
      final List<String> same = <String>[
        for (final FieldCode b in fieldCodes)
          if (b.matches(a.format, a.text)) b.id,
      ];
      expect(
        same,
        sameText.contains(a.id) ? sameText.toList() : <String>[a.id],
      );
    }
  });

  test('an add-on counts with and without its digits', () {
    final FieldCode ean = fieldCodes.firstWhere((FieldCode c) => c.id == 'R4');
    expect(ean.matches(ean.format, ean.text), isTrue);
    expect(ean.matches(ean.format, ean.addOn!), isTrue);
    expect(ean.matches('qrCode', ean.text), isFalse);
  });

  test('a read in time passes and is timed from the start', () {
    session.start(qr, const <String, Object?>{'tryInvert': false});
    now += fieldLimitMs;
    session.onReads(<(String, String)>[(qr.format, qr.text)]);
    final FieldResult r = session.resultOf(qr)!;
    expect(r.outcome, FieldOutcome.pass);
    expect(r.ms, fieldLimitMs);
    expect(r.settings, <String, Object?>{'tryInvert': false});
    expect(session.running, isNull);
  });

  test('a late read is slow', () {
    session.start(qr, const <String, Object?>{});
    now += fieldLimitMs + 1;
    session.onReads(<(String, String)>[(qr.format, qr.text)]);
    expect(session.resultOf(qr)!.outcome, FieldOutcome.slow);
  });

  test('other codes and frames without an attempt change nothing', () {
    session.onReads(<(String, String)>[(qr.format, qr.text)]);
    expect(session.results, isEmpty);
    session.start(qr, const <String, Object?>{});
    session.onReads(<(String, String)>[('ean13', '9501101530003')]);
    expect(session.results, isEmpty);
    expect(session.running, qr);
  });

  test('giving up keeps what the phone camera did and the frames', () {
    session.start(qr, const <String, Object?>{});
    session.giveUp(systemCamera: true, recording: 'rec-1');
    final FieldResult r = session.resultOf(qr)!;
    expect(r.outcome, FieldOutcome.fail);
    expect(r.ms, isNull);
    expect(r.systemCamera, isTrue);
    expect(r.recording, 'rec-1');
  });

  test('results belong to their conditions', () {
    session.start(qr, const <String, Object?>{});
    session.onReads(<(String, String)>[(qr.format, qr.text)]);
    expect(session.next, fieldCodes[1]);
    session.conditions = session.conditions.copyWith(angle: 45);
    expect(session.resultOf(qr), isNull);
    expect(session.next, qr);
  });

  test('the plan changes one value at a time from the first conditions', () {
    const FieldConditions base = FieldConditions();
    expect(fieldPlan, hasLength(10));
    expect(fieldPlan.first, base);
    expect(fieldPlan.toSet(), hasLength(10));
    for (final FieldConditions c in fieldPlan.skip(1)) {
      final int changed = <bool>[
        c.medium != base.medium,
        c.distanceCm != base.distanceCm,
        c.angle != base.angle,
        c.light != base.light,
      ].where((bool b) => b).length;
      expect(changed, 1, reason: c.label);
    }
  });

  test('the plan moves on once every code has a result', () {
    expect(session.nextConditions, fieldPlan.first);
    for (final FieldConditions c in fieldPlan) {
      session.conditions = c;
      for (final FieldCode code in fieldCodes) {
        session
          ..start(code, const <String, Object?>{})
          ..giveUp();
      }
      expect(session.triedUnder(c), fieldCodes.length);
      expect(
        session.nextConditions,
        c == fieldPlan.last ? isNull : fieldPlan[fieldPlan.indexOf(c) + 1],
      );
    }
  });

  test('results survive being stored', () {
    session.start(qr, const <String, Object?>{'minLineCount': 2});
    session.giveUp(systemCamera: false, recording: 'rec-2');
    final FieldSession back = FieldSession(device: 'x', build: 'y')
      ..restore(session.encode());
    addTearDown(back.dispose);
    expect(back.results.single.toJson(), session.results.single.toJson());
  });

  test('the table has a row per attempt', () {
    session.start(qr, const <String, Object?>{});
    now += 640;
    session.onReads(<(String, String)>[(qr.format, qr.text)]);
    session.start(fieldCodes[1], const <String, Object?>{});
    session.giveUp(systemCamera: false, recording: 'rec-3');
    final List<String> lines = session.table().trim().split('\n');
    expect(lines, hasLength(4));
    expect(
      lines[2],
      '| phone | Screen | 20 | 0 | Daylight | W1 QR Code | pass | 640 |  |  |',
    );
    expect(lines[3], contains('fail |  | does not read | rec-3 |'));
  });
}
