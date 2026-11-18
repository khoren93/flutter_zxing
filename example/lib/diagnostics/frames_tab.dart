// The Frames tab of the diagnostics page: keeps the last seconds of the
// camera, saves them and reads them again with any settings.
import 'dart:async';

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:share_plus/share_plus.dart';

import 'diag_settings.dart';
import 'frame_recorder.dart';
import 'recording.dart';

/// The tab.
class DiagFramesTab extends StatefulWidget {
  /// Creates the tab.
  const DiagFramesTab({
    super.key,
    required this.recorder,
    required this.store,
    required this.settings,
    required this.controller,
  });

  final FrameRecorder recorder;
  final RecordingStore store;

  /// The settings of the page, to read recordings with.
  final DiagSettings settings;

  /// Paused while a recording is read, for clean timing.
  final ScannerController controller;

  @override
  State<DiagFramesTab> createState() => _DiagFramesTabState();
}

class _DiagFramesTabState extends State<DiagFramesTab> {
  String? _running;
  int _done = 0;
  (String, String, ReplayReport)? _report;

  Future<void> _save() async {
    final Recording? recording = widget.recorder.take(widget.settings);
    if (recording != null) {
      await widget.store.save(recording);
    }
  }

  /// Reads [file] again with the page's settings, or with those it was
  /// recorded with.
  Future<void> _replay(RecordingFile file, {required bool asRecorded}) async {
    setState(() {
      _running = file.name;
      _done = 0;
      _report = null;
    });
    final ScannerController c = widget.controller;
    final bool wasRunning = c.value.status == ScannerStatus.running;
    if (wasRunning) {
      await c.pause();
    }
    try {
      final Recording recording = await widget.store.open(file);
      final DiagSettings settings = asRecorded
          ? DiagSettings.fromJson(recording.settings)
          : widget.settings;
      final ReplayReport report = await replayRecording(
        recording,
        settings.engineOptions,
        onProgress: (int n) {
          if (mounted) {
            setState(() => _done = n);
          }
        },
      );
      if (mounted) {
        setState(
          () => _report = (
            file.name,
            asRecorded ? 'as recorded' : 'with the settings of this page',
            report,
          ),
        );
      }
    } finally {
      if (wasRunning) {
        await c.resume();
      }
      if (mounted) {
        setState(() => _running = null);
      }
    }
  }

  Future<void> _share(RecordingFile file, BuildContext context) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.file.path)],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  static String _mb(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(bytes < 10485760 ? 1 : 0)} MB';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(<Listenable>[widget.recorder, widget.store]),
    builder: (BuildContext context, _) {
      final FrameRecorder r = widget.recorder;
      final (String, String, ReplayReport)? report = _report;
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          SwitchListTile(
            dense: true,
            title: const Text('Keep the last seconds'),
            subtitle: Text(
              r.armed
                  ? '${r.frameCount} frames · ${_mb(r.bytes)}'
                  : 'Off: copying frames costs time on every frame',
            ),
            value: r.armed,
            onChanged: (bool v) => r.armed = v,
          ),
          ListTile(
            dense: true,
            title: const Text('Seconds to keep'),
            trailing: DropdownButton<int>(
              value: r.keepSeconds,
              underline: const SizedBox.shrink(),
              items: <DropdownMenuItem<int>>[
                for (final int s in const <int>[2, 5, 10, 20])
                  DropdownMenuItem<int>(value: s, child: Text('$s s')),
              ],
              onChanged: (int? v) => r.keepSeconds = v!,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('Save these frames'),
              onPressed: r.armed && r.frameCount > 0 ? _save : null,
            ),
          ),
          if (_running != null)
            ListTile(
              dense: true,
              leading: const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Reading $_running'),
              trailing: Text('$_done'),
            ),
          if (report != null) _ReportCard(report.$1, report.$2, report.$3),
          for (final RecordingFile f in widget.store.files)
            ListTile(
              dense: true,
              title: Text(f.name),
              subtitle: Text('${f.frames} frames · ${_mb(f.size)}'),
              trailing: Builder(
                builder: (BuildContext context) => PopupMenuButton<String>(
                  onSelected: (String action) => unawaited(switch (action) {
                    'replay' => _replay(f, asRecorded: false),
                    'recorded' => _replay(f, asRecorded: true),
                    'share' => _share(f, context),
                    _ => widget.store.remove(f),
                  }),
                  itemBuilder: (_) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'replay',
                      child: Text('Read with these settings'),
                    ),
                    PopupMenuItem<String>(
                      value: 'recorded',
                      child: Text('Read as recorded'),
                    ),
                    PopupMenuItem<String>(value: 'share', child: Text('Share')),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard(this.name, this.how, this.report);

  final String name;
  final String how;
  final ReplayReport report;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$name, $how', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            'With a code: ${report.recordedWithCode} recorded → '
            '${report.withCode} now, of ${report.frames.length}\n'
            'Same ${report.same} · gained ${report.gained} · '
            'lost ${report.lost} · changed ${report.changed}\n'
            'Decode ${report.decodeMs(0.5).toStringAsFixed(1)} ms, '
            'p95 ${report.decodeMs(0.95).toStringAsFixed(1)} ms',
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 14,
            width: double.infinity,
            child: CustomPaint(painter: _Strip(report)),
          ),
        ],
      ),
    ),
  );
}

/// One bar per frame: grey without a code, green the same code, blue gained,
/// red lost, orange changed.
class _Strip extends CustomPainter {
  _Strip(this.report);

  final ReplayReport report;

  @override
  void paint(Canvas canvas, Size size) {
    final int n = report.frames.length;
    for (final (int i, ReplayFrame f) in report.frames.indexed) {
      canvas.drawRect(
        Rect.fromLTWH(i * size.width / n, 0, size.width / n, size.height),
        Paint()
          ..color = switch (f.outcome) {
            ReplayOutcome.same when f.reads.isEmpty => const Color(0xFF4B5563),
            ReplayOutcome.same => const Color(0xFF22C55E),
            ReplayOutcome.gained => const Color(0xFF3B82F6),
            ReplayOutcome.lost => const Color(0xFFEF4444),
            ReplayOutcome.changed => const Color(0xFFF59E0B),
          },
      );
    }
  }

  @override
  bool shouldRepaint(_Strip old) => old.report != report;
}
