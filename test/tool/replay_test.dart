// Reads recordings of the diagnostics page again on this computer and compares
// the result with what the phone read. Skipped unless REPLAY names a recording
// or a folder of them:
//
//   make diag-pull DEVICE=<phone>
//   make replay                                  # as recorded: must be the same
//   make replay OPTIONS=tryInvert=true,minLineCount=1   # what would change
@Tags(<String>['native'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The recording format lives in the example app, see its header.
// ignore: avoid_relative_lib_imports
import '../../example/lib/diagnostics/diag_settings.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/diagnostics/recording.dart';

final String _path = Platform.environment['REPLAY'] ?? '';
final String _options = Platform.environment['REPLAY_OPTIONS'] ?? '';

/// `tryInvert=true,minLineCount=1` as settings values.
Map<String, Object?> _overrides() => <String, Object?>{
  for (final String pair in _options.split(','))
    if (pair.contains('='))
      pair.substring(0, pair.indexOf('=')).trim(): switch (pair
          .substring(pair.indexOf('=') + 1)
          .trim()) {
        'true' => true,
        'false' => false,
        final String v => int.tryParse(v) ?? v,
      },
};

void main() {
  final List<File> files = FileSystemEntity.isDirectorySync(_path)
      ? Directory(_path)
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.endsWith('.fzxrec'))
            .toList()
      : <File>[if (_path.isNotEmpty && File(_path).existsSync()) File(_path)];

  test('recordings read as on the phone', () async {
    expect(files, isNotEmpty, reason: 'no recordings in $_path');
    int different = 0;
    for (final File file in files) {
      final Recording recording = Recording.decode(file.readAsBytesSync());
      final ReplayReport r = await replayRecording(
        recording,
        DiagSettings.fromJson(<String, Object?>{
          ...recording.settings,
          ..._overrides(),
        }).engineOptions,
      );
      different += r.gained + r.lost + r.changed;
      // ignore: avoid_print
      print(
        '${recording.name} (${recording.device}, zxing-cpp '
        '${recording.engine}): ${r.frames.length} frames, with a code '
        '${r.recordedWithCode} on the phone, ${r.withCode} here; same '
        '${r.same}, gained ${r.gained}, lost ${r.lost}, changed ${r.changed}; '
        'decode ${r.decodeMs(0.5).toStringAsFixed(1)} ms, p95 '
        '${r.decodeMs(0.95).toStringAsFixed(1)} ms',
      );
      for (final (int i, ReplayFrame f) in r.frames.indexed) {
        if (f.outcome != ReplayOutcome.same) {
          // ignore: avoid_print
          print(
            '  frame $i ${f.outcome.name}: '
            '${f.frame.reads.map((RecordedRead x) => x.key).toList()} -> '
            '${f.reads.map((RecordedRead x) => x.key).toList()}',
          );
        }
      }
    }
    if (_options.isEmpty) {
      expect(different, 0, reason: 'frames read differently than on the phone');
    }
  }, skip: _path.isEmpty ? 'REPLAY names no recording' : false);
}
