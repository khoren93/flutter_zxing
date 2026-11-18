// The field test of the diagnostics page: which code is being tried under
// which conditions, how long it took and what the round came to.
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'field_codes.dart';

/// A code read later than this does not pass.
const int fieldLimitMs = 2000;

/// How an attempt ended.
enum FieldOutcome {
  /// Read in time.
  pass,

  /// Read, but later than [fieldLimitMs].
  slow,

  /// Given up on.
  fail,
}

/// What the code is shown on and how.
@immutable
final class FieldConditions {
  /// Creates the conditions.
  const FieldConditions({
    this.medium = 'Screen',
    this.distanceCm = 20,
    this.angle = 0,
    this.light = 'Daylight',
  });

  /// A set read back from storage.
  factory FieldConditions.fromJson(Map<String, dynamic> json) =>
      FieldConditions(
        medium: json['medium'] as String,
        distanceCm: json['distanceCm'] as int,
        angle: json['angle'] as int,
        light: json['light'] as String,
      );

  static const List<String> media = <String>['Screen', 'Paper'];
  static const List<int> distances = <int>[10, 20, 30, 50];
  static const List<int> angles = <int>[0, 15, 30, 45];
  static const List<String> lights = <String>['Daylight', 'Dim', 'Glare'];

  final String medium;
  final int distanceCm;
  final int angle;
  final String light;

  /// A copy with the given values replaced.
  FieldConditions copyWith({
    String? medium,
    int? distanceCm,
    int? angle,
    String? light,
  }) => FieldConditions(
    medium: medium ?? this.medium,
    distanceCm: distanceCm ?? this.distanceCm,
    angle: angle ?? this.angle,
    light: light ?? this.light,
  );

  /// The set in one line.
  String get label => '$medium · $distanceCm cm · $angle° · $light';

  /// The set as stored.
  Map<String, Object?> toJson() => <String, Object?>{
    'medium': medium,
    'distanceCm': distanceCm,
    'angle': angle,
    'light': light,
  };

  @override
  bool operator ==(Object other) =>
      other is FieldConditions &&
      other.medium == medium &&
      other.distanceCm == distanceCm &&
      other.angle == angle &&
      other.light == light;

  @override
  int get hashCode => Object.hash(medium, distanceCm, angle, light);
}

/// The conditions of a round: the first one, then one value changed at a time.
const List<FieldConditions> fieldPlan = <FieldConditions>[
  FieldConditions(),
  FieldConditions(medium: 'Paper'),
  FieldConditions(distanceCm: 10),
  FieldConditions(distanceCm: 30),
  FieldConditions(distanceCm: 50),
  FieldConditions(angle: 15),
  FieldConditions(angle: 30),
  FieldConditions(angle: 45),
  FieldConditions(light: 'Dim'),
  FieldConditions(light: 'Glare'),
];

/// One finished attempt.
@immutable
final class FieldResult {
  /// Creates a result.
  const FieldResult({
    required this.codeId,
    required this.title,
    required this.device,
    required this.build,
    required this.conditions,
    required this.outcome,
    this.ms,
    this.systemCamera,
    this.recording,
    this.settings = const <String, Object?>{},
  });

  /// A result read back from storage.
  factory FieldResult.fromJson(Map<String, dynamic> json) => FieldResult(
    codeId: json['codeId'] as String,
    title: json['title'] as String,
    device: json['device'] as String,
    build: json['build'] as String,
    conditions: FieldConditions.fromJson(
      json['conditions'] as Map<String, dynamic>,
    ),
    outcome: FieldOutcome.values.byName(json['outcome'] as String),
    ms: json['ms'] as int?,
    systemCamera: json['systemCamera'] as bool?,
    recording: json['recording'] as String?,
    settings: json['settings'] as Map<String, dynamic>? ?? <String, Object?>{},
  );

  final String codeId;
  final String title;
  final String device;
  final String build;
  final FieldConditions conditions;
  final FieldOutcome outcome;

  /// Time to the read; `null` when it was given up on.
  final int? ms;

  /// Whether the phone's own camera reads it; `null` when not checked.
  final bool? systemCamera;

  /// The recording of the last frames before giving up.
  final String? recording;

  /// The engine settings of the attempt.
  final Map<String, Object?> settings;

  /// The result as stored.
  Map<String, Object?> toJson() => <String, Object?>{
    'codeId': codeId,
    'title': title,
    'device': device,
    'build': build,
    'conditions': conditions.toJson(),
    'outcome': outcome.name,
    'ms': ms,
    'systemCamera': systemCamera,
    'recording': recording,
    'settings': settings,
  };
}

/// The round: the attempt under way and the results so far.
final class FieldSession extends ChangeNotifier {
  /// Creates a session on [device]. [nowMs] replaces the clock in tests;
  /// [onChanged] gets the results to keep whenever they change.
  FieldSession({
    required this.device,
    required this.build,
    int Function()? nowMs,
    this.onChanged,
  }) : _nowMs = nowMs ?? _stopwatchMs;

  static final Stopwatch _stopwatch = Stopwatch()..start();
  static int _stopwatchMs() => _stopwatch.elapsedMilliseconds;

  final String device;
  final String build;
  final int Function() _nowMs;

  /// Called with the stored form of the results after each change.
  void Function(String json)? onChanged;

  final List<FieldResult> _results = <FieldResult>[];
  FieldConditions _conditions = const FieldConditions();
  FieldCode? _running;
  int _startedMs = 0;
  Map<String, Object?> _settings = const <String, Object?>{};

  /// All results, oldest first.
  List<FieldResult> get results => List<FieldResult>.unmodifiable(_results);

  /// The conditions of the next attempts.
  FieldConditions get conditions => _conditions;
  set conditions(FieldConditions value) {
    _conditions = value;
    notifyListeners();
  }

  /// The code being tried now.
  FieldCode? get running => _running;

  /// Time since the attempt started.
  int get elapsedMs => _running == null ? 0 : _nowMs() - _startedMs;

  /// The last result of [code] under the current conditions.
  FieldResult? resultOf(FieldCode code) => _resultUnder(code, _conditions);

  FieldResult? _resultUnder(FieldCode code, FieldConditions conditions) {
    for (final FieldResult r in _results.reversed) {
      if (r.codeId == code.id && r.conditions == conditions) {
        return r;
      }
    }
    return null;
  }

  /// How many codes have a result under [conditions].
  int triedUnder(FieldConditions conditions) => fieldCodes
      .where((FieldCode c) => _resultUnder(c, conditions) != null)
      .length;

  /// The first conditions of the plan with codes still to try.
  FieldConditions? get nextConditions {
    for (final FieldConditions c in fieldPlan) {
      if (triedUnder(c) < fieldCodes.length) {
        return c;
      }
    }
    return null;
  }

  /// The first code without a result under the current conditions.
  FieldCode? get next {
    for (final FieldCode code in fieldCodes) {
      if (resultOf(code) == null) {
        return code;
      }
    }
    return null;
  }

  /// How many codes ended with [outcome] under the current conditions.
  int count(FieldOutcome outcome) =>
      fieldCodes.where((FieldCode c) => resultOf(c)?.outcome == outcome).length;

  /// Starts timing [code]; aim at it first.
  void start(FieldCode code, Map<String, Object?> settings) {
    _running = code;
    _settings = settings;
    _startedMs = _nowMs();
    notifyListeners();
  }

  /// Stops without a result.
  void cancel() {
    _running = null;
    notifyListeners();
  }

  /// The reads of one frame, as format name and text.
  void onReads(List<(String, String)> reads) {
    final FieldCode? code = _running;
    if (code == null ||
        !reads.any(((String, String) r) => code.matches(r.$1, r.$2))) {
      return;
    }
    final int ms = elapsedMs;
    _finish(
      code,
      ms <= fieldLimitMs ? FieldOutcome.pass : FieldOutcome.slow,
      ms: ms,
    );
  }

  /// Gives up on the code being tried.
  void giveUp({bool? systemCamera, String? recording}) {
    final FieldCode? code = _running;
    if (code != null) {
      _finish(
        code,
        FieldOutcome.fail,
        systemCamera: systemCamera,
        recording: recording,
      );
    }
  }

  void _finish(
    FieldCode code,
    FieldOutcome outcome, {
    int? ms,
    bool? systemCamera,
    String? recording,
  }) {
    _running = null;
    _results.add(
      FieldResult(
        codeId: code.id,
        title: code.title,
        device: device,
        build: build,
        conditions: _conditions,
        outcome: outcome,
        ms: ms,
        systemCamera: systemCamera,
        recording: recording,
        settings: _settings,
      ),
    );
    _changed();
  }

  /// Forgets all results.
  void clear() {
    _results.clear();
    _running = null;
    _changed();
  }

  void _changed() {
    onChanged?.call(encode());
    notifyListeners();
  }

  /// The results as stored.
  String encode() => jsonEncode(<Map<String, Object?>>[
    for (final FieldResult r in _results) r.toJson(),
  ]);

  /// Takes back results stored by [encode].
  void restore(String json) {
    _results
      ..clear()
      ..addAll(<FieldResult>[
        for (final Object? r in jsonDecode(json) as List<Object?>)
          FieldResult.fromJson(r! as Map<String, dynamic>),
      ]);
    notifyListeners();
  }

  /// The results as a Markdown table for `progress/device-rounds.md`.
  String table() {
    String cell(String text) => text.replaceAll('|', r'\|');
    final StringBuffer b = StringBuffer()
      ..writeln(
        '| Device | Medium | Distance, cm | Angle, ° | Light | Code | Result '
        '| Time, ms | Phone camera | Frames |',
      )
      ..writeln('|---|---|---|---|---|---|---|---|---|---|');
    for (final FieldResult r in _results) {
      final FieldConditions c = r.conditions;
      final String phone = switch (r.systemCamera) {
        true => 'reads',
        false => 'does not read',
        null => '',
      };
      b.writeln(
        '| ${cell(r.device)} | ${c.medium} | ${c.distanceCm} | ${c.angle} '
        '| ${c.light} | ${r.codeId} ${cell(r.title)} | ${r.outcome.name} '
        '| ${r.ms ?? ''} | $phone | ${r.recording ?? ''} |',
      );
    }
    return b.toString();
  }
}
