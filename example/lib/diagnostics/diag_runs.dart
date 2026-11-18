// The saved runs of the diagnostics page: their settings and numbers, kept on
// the device, compared side by side and copied out as JSON.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diag_metrics.dart';
import 'diag_settings.dart';

/// The system this runs on.
String get diagDevice =>
    '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';

/// The kind of build this is.
String get diagBuild =>
    kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug');

/// One saved run.
@immutable
final class DiagRun {
  /// Creates a run.
  const DiagRun({
    required this.time,
    required this.label,
    required this.device,
    required this.build,
    required this.engine,
    required this.settings,
    required this.numbers,
  });

  /// The run the page shows now.
  factory DiagRun.now(String label, DiagSettings settings, DiagSnapshot s) =>
      DiagRun(
        time: DateTime.now(),
        label: label,
        device: diagDevice,
        build: diagBuild,
        engine: zxingCppVersion,
        settings: settings.toJson(),
        numbers: s.toJson(),
      );

  /// A run read back from storage.
  factory DiagRun.fromJson(Map<String, dynamic> json) => DiagRun(
    time: DateTime.parse(json['time'] as String),
    label: json['label'] as String,
    device: json['device'] as String,
    build: json['build'] as String,
    engine: json['engine'] as String,
    settings: json['settings'] as Map<String, dynamic>,
    numbers: json['numbers'] as Map<String, dynamic>,
  );

  final DateTime time;
  final String label;
  final String device;
  final String build;
  final String engine;
  final Map<String, Object?> settings;
  final Map<String, Object?> numbers;

  /// The run as stored and copied.
  Map<String, Object?> toJson() => <String, Object?>{
    'time': time.toIso8601String(),
    'label': label,
    'device': device,
    'build': build,
    'engine': engine,
    'settings': settings,
    'numbers': numbers,
  };
}

/// The runs on this device, newest first.
final class DiagRunStore extends ChangeNotifier {
  static const String _key = 'diagnostics.runs';
  static const int _max = 50;

  /// The runs.
  List<DiagRun> runs = <DiagRun>[];

  /// Reads the saved runs.
  Future<void> load() async {
    final String? saved = (await SharedPreferences.getInstance()).getString(
      _key,
    );
    if (saved != null) {
      runs = <DiagRun>[
        for (final Object? r in jsonDecode(saved) as List<Object?>)
          DiagRun.fromJson(r! as Map<String, dynamic>),
      ];
      notifyListeners();
    }
  }

  /// Saves [run].
  Future<void> add(DiagRun run) async {
    runs = <DiagRun>[run, ...runs.take(_max - 1)];
    await _save();
  }

  /// Deletes [run].
  Future<void> remove(DiagRun run) async {
    runs = <DiagRun>[
      for (final DiagRun r in runs)
        if (!identical(r, run)) r,
    ];
    await _save();
  }

  /// All runs as JSON.
  String export() => const JsonEncoder.withIndent(
    '  ',
  ).convert(<Object?>[for (final DiagRun r in runs) r.toJson()]);

  Future<void> _save() async {
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(<Object?>[for (final DiagRun r in runs) r.toJson()]),
    );
  }
}

/// The rows that differ between two maps of values, each with both values.
List<(String, String, String)> differences(
  Map<String, Object?> a,
  Map<String, Object?> b,
) => <(String, String, String)>[
  for (final String key in <String>{...a.keys, ...b.keys})
    if ('${a[key]}' != '${b[key]}')
      (key, '${a[key] ?? '—'}', '${b[key] ?? '—'}'),
];

/// The list of saved runs; two selected ones are compared.
class DiagRunsTab extends StatefulWidget {
  /// Creates the tab.
  const DiagRunsTab({super.key, required this.store});

  /// The runs.
  final DiagRunStore store;

  @override
  State<DiagRunsTab> createState() => _DiagRunsTabState();
}

class _DiagRunsTabState extends State<DiagRunsTab> {
  final List<DiagRun> _selected = <DiagRun>[];

  void _toggle(DiagRun run) => setState(() {
    if (!_selected.remove(run)) {
      _selected.add(run);
      if (_selected.length > 2) {
        _selected.removeAt(0);
      }
    }
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (BuildContext context, _) {
      final List<DiagRun> runs = widget.store.runs;
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          ListTile(
            dense: true,
            title: Text('${runs.length} saved · select two to compare'),
            trailing: IconButton(
              tooltip: 'Copy all as JSON',
              icon: const Icon(Icons.copy_all),
              onPressed: runs.isEmpty
                  ? null
                  : () => Clipboard.setData(
                      ClipboardData(text: widget.store.export()),
                    ),
            ),
          ),
          if (_selected.length == 2) _Comparison(_selected[0], _selected[1]),
          for (final DiagRun run in runs)
            CheckboxListTile(
              dense: true,
              value: _selected.contains(run),
              onChanged: (_) => _toggle(run),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                '${run.label} · ${run.numbers['decodeP50Ms']} ms · '
                'CPU ${run.numbers['cpuPercent'] ?? '—'}%',
              ),
              subtitle: Text(
                '${run.time.toLocal().toString().substring(0, 19)} · '
                '${run.build} · zxing-cpp ${run.engine}',
              ),
              secondary: IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  setState(() => _selected.remove(run));
                  widget.store.remove(run);
                },
              ),
            ),
        ],
      );
    },
  );
}

class _Comparison extends StatelessWidget {
  const _Comparison(this.a, this.b);

  final DiagRun a;
  final DiagRun b;

  @override
  Widget build(BuildContext context) {
    TableRow row(String k, String x, String y, {bool head = false}) => TableRow(
      children: <Widget>[
        for (final String cell in <String>[k, x, y])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              cell,
              style: TextStyle(
                fontSize: 12,
                fontWeight: head ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
      ],
    );
    return Card(
      margin: const EdgeInsets.all(8),
      child: Table(
        columnWidths: const <int, TableColumnWidth>{0: FlexColumnWidth(2)},
        children: <TableRow>[
          row('', a.label, b.label, head: true),
          for (final (String k, String x, String y) in differences(
            a.settings,
            b.settings,
          ))
            row(k, x, y),
          for (final (String k, String x, String y) in differences(
            a.numbers,
            b.numbers,
          ))
            row(k, x, y),
        ],
      ),
    );
  }
}
