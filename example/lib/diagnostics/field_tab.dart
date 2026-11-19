// The Field tab of the diagnostics page: the codes of the sheet
// 1-formats/all-grid, tried one by one under the conditions set here.
import 'dart:async';
import 'dart:io';

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'diag_settings.dart';
import 'field_codes.dart';
import 'field_session.dart';
import 'frame_recorder.dart';
import 'recording.dart';

Future<File> _resultsFile() async {
  final Directory docs = await getApplicationDocumentsDirectory();
  final Directory dir = await Directory(
    '${docs.path}/field',
  ).create(recursive: true);
  return File('${dir.path}/results.json');
}

/// Takes back the results of earlier rounds and keeps the new ones.
Future<void> loadFieldResults(FieldSession session) async {
  final File file = await _resultsFile();
  if (file.existsSync()) {
    session.restore(await file.readAsString());
  }
  session.onChanged = (String json) => unawaited(file.writeAsString(json));
}

/// The tab.
class DiagFieldTab extends StatefulWidget {
  /// Creates the tab.
  const DiagFieldTab({
    super.key,
    required this.session,
    required this.recorder,
    required this.store,
    required this.settings,
  });

  final FieldSession session;

  /// Keeps the last frames, saved when a code is given up on.
  final FrameRecorder recorder;
  final RecordingStore store;

  /// The settings the codes are read with.
  final DiagSettings settings;

  @override
  State<DiagFieldTab> createState() => _DiagFieldTabState();
}

class _DiagFieldTabState extends State<DiagFieldTab> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // The time on screen, while a code is being tried.
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && widget.session.running != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start(FieldCode code) {
    widget.recorder.armed = true;
    widget.session.start(code, widget.settings.toJson());
  }

  Future<void> _giveUp() async {
    final Recording? recording = widget.recorder.take(widget.settings);
    final bool? phone = await showDialog<bool?>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text("Does the phone's own camera read it?"),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not checked'),
          ),
        ],
      ),
    );
    if (recording != null) {
      await widget.store.save(recording);
    }
    widget.session.giveUp(systemCamera: phone, recording: recording?.name);
  }

  Future<void> _share(BuildContext context) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: widget.session.table(),
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.session.table()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Table copied')));
    }
  }

  Future<void> _clear() async {
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete all field results?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure ?? false) {
      widget.session.clear();
    }
  }

  Widget _idleButton(FieldSession s) {
    final FieldCode? next = s.next;
    if (next != null) {
      return FilledButton.icon(
        icon: const Icon(Icons.play_arrow),
        label: Text('Aim at ${next.id} ${next.title}, then start'),
        onPressed: () => _start(next),
      );
    }
    final FieldConditions? conditions = s.nextConditions;
    if (conditions != null) {
      return FilledButton.icon(
        icon: const Icon(Icons.arrow_forward),
        label: Text('Go on to ${conditions.label}'),
        onPressed: () => s.conditions = conditions,
      );
    }
    return const FilledButton(
      onPressed: null,
      child: Text('All conditions tried'),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (BuildContext context, _) {
      final FieldSession s = widget.session;
      final FieldCode? running = s.running;
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: DropdownButton<FieldConditions>(
              value: s.conditions,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: <DropdownMenuItem<FieldConditions>>[
                for (final (int i, FieldConditions c) in fieldPlan.indexed)
                  DropdownMenuItem<FieldConditions>(
                    value: c,
                    child: Text(
                      '${i + 1}. ${c.label}  '
                      '(${s.triedUnder(c)}/${fieldCodes.length})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: running != null
                  ? null
                  : (FieldConditions? c) => s.conditions = c!,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: running != null
                ? Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${running.id} ${running.title}\n'
                          '${(s.elapsedMs / 1000).toStringAsFixed(1)} s',
                        ),
                      ),
                      TextButton(
                        onPressed: s.cancel,
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _giveUp,
                        child: const Text("Can't read"),
                      ),
                    ],
                  )
                : _idleButton(s),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Pass ${s.count(FieldOutcome.pass)} · '
                    'slow ${s.count(FieldOutcome.slow)} · '
                    'fail ${s.count(FieldOutcome.fail)} · '
                    'of ${fieldCodes.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy the table',
                  icon: const Icon(Icons.copy),
                  onPressed: s.results.isEmpty ? null : _copy,
                ),
                Builder(
                  builder: (BuildContext context) => IconButton(
                    tooltip: 'Share the table',
                    icon: const Icon(Icons.ios_share),
                    onPressed: s.results.isEmpty
                        ? null
                        : () => unawaited(_share(context)),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete all results',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: s.results.isEmpty ? null : _clear,
                ),
              ],
            ),
          ),
          for (final FieldCode code in fieldCodes)
            _CodeRow(
              code: code,
              result: s.resultOf(code),
              running: running?.id == code.id,
              onTap: running == null ? () => _start(code) : null,
            ),
        ],
      );
    },
  );
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({
    required this.code,
    required this.result,
    required this.running,
    required this.onTap,
  });

  final FieldCode code;
  final FieldResult? result;
  final bool running;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final FieldResult? r = result;
    final (IconData icon, Color color) = switch (r?.outcome) {
      FieldOutcome.pass => (Icons.check_circle, Colors.green),
      FieldOutcome.slow => (Icons.timelapse, Colors.orange),
      FieldOutcome.fail => (Icons.cancel, Colors.red),
      null => (Icons.radio_button_unchecked, Theme.of(context).hintColor),
    };
    return ListTile(
      dense: true,
      selected: running,
      leading: Icon(icon, color: color, size: 20),
      title: Text('${code.id}  ${code.title}'),
      trailing: Text(r?.ms == null ? '' : '${r!.ms} ms'),
      onTap: onTap,
    );
  }
}
