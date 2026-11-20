// The demo's history: what a saved code keeps across launches.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing_example/demo/history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a scan keeps what the Technical card shows', () {
    final HistoryItem item = HistoryItem(
      id: '1',
      barcode: Barcode(
        format: BarcodeFormat.qrCode,
        text: 'part',
        bytes: Uint8List.fromList(utf8.encode('part')),
        position: const BarcodePosition(
          topLeft: Offset.zero,
          topRight: Offset.zero,
          bottomRight: Offset.zero,
          bottomLeft: Offset.zero,
        ),
        rotation: 180,
        isMirrored: true,
        isInverted: true,
        ecLevel: 'H',
        version: '4',
        sequence: const BarcodeSequence(index: 1, size: 3, id: '7'),
      ),
      origin: HistoryOrigin.scanned,
      time: DateTime(2026, 11, 20),
    );
    final Barcode again = HistoryItem.fromJson(
      (jsonDecode(jsonEncode(item.toJson())) as Map<String, Object?>),
    )!.barcode;
    expect(again.rotation, 180);
    expect(again.isMirrored, isTrue);
    expect(again.isInverted, isTrue);
    expect(again.ecLevel, 'H');
    expect(again.version, '4');
    expect(again.sequence!.index, 1);
    expect(again.sequence!.size, 3);
    expect(again.sequence!.id, '7');
  });

  group('a created code', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      HistoryStore.instance.clear();
    });

    test('is drawn again with its writer settings', () {
      final HistoryItem item = HistoryStore.instance.addCreated(
        '(01)09506000134352(17)271231',
        BarcodeFormat.dataMatrix,
        'classic',
        gs1: true,
        errorCorrection: ErrorCorrection.high,
        showText: true,
      );
      final HistoryItem again = HistoryItem.fromJson(
        (jsonDecode(jsonEncode(item.toJson())) as Map<String, Object?>),
      )!;
      expect(again.barcode.contentType, BarcodeContentType.gs1);
      expect(again.writer.gs1, isTrue);
      expect(again.writer.errorCorrection, ErrorCorrection.high);
      expect(again.writer.showText, isTrue);
    });

    test('exported twice is kept once', () {
      HistoryStore.instance
        ..addCreated('hello', BarcodeFormat.qrCode, 'lagoon')
        ..addCreated('hello', BarcodeFormat.qrCode, 'lagoon');
      expect(HistoryStore.instance.items, hasLength(1));
    });
  });
}
