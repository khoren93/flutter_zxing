// Checks that the Dart code on the documentation site compiles against the
// package: every ```dart block of website/**/*.md and every
// website/.vitepress/theme/samples/*.snippet (the home page's code).
//
//   cd tool && dart run check_site_snippets.dart      (or: make site-check)
//
// A sample is usually a fragment: a few statements, one widget, a few
// members of a State class. Each is tried in several wrappers (as a file, as
// the body of an async function with a `context`, as an expression, as the
// members of a State) in one generated package under build/site_snippets/,
// analyzed once; a sample passes when one of its wrappers has no error.
// Warnings and lints do not count: a sample may leave a variable unused.
//
// A block that is not meant to compile (a 3.x API shown for comparison, a
// sketch with `...`) is skipped with `<!-- snippet: skip -->` on the line
// above its fence.
import 'dart:io';

/// Imports every wrapper gets, before the sample's own.
const List<String> _prelude = <String>[
  "import 'dart:async';",
  "import 'dart:io';",
  "import 'dart:typed_data';",
  "import 'dart:ui' as ui;",
  "import 'package:flutter/material.dart';",
  "import 'package:flutter_zxing/scanner.dart';",
  // Samples open links the way apps do.
  "import 'package:url_launcher/url_launcher.dart';",
];

final class Sample {
  Sample(this.file, this.line, this.code);

  /// Path relative to the repository, and the line of the fence (1-based).
  final String file;
  final int line;
  final String code;

  @override
  String toString() => '$file:$line';
}

Future<void> main(List<String> args) async {
  final Directory root = Directory.fromUri(Platform.script.resolve('..'));
  final Directory site = Directory('${root.path}website');
  final List<Sample> samples = <Sample>[
    for (final File f in _files(site, '.md')) ..._fromMarkdown(root, f),
    for (final File f in _files(
      Directory('${site.path}/.vitepress/theme/samples'),
      '.snippet',
    ))
      Sample(_relative(root, f), 1, f.readAsStringSync()),
  ];
  if (samples.isEmpty) {
    stderr.writeln('No Dart samples found under ${site.path}.');
    exit(1);
  }

  final Directory pkg = Directory('${root.path}build/site_snippets');
  if (pkg.existsSync()) {
    pkg.deleteSync(recursive: true);
  }
  Directory('${pkg.path}/lib').createSync(recursive: true);
  File('${pkg.path}/pubspec.yaml').writeAsStringSync('''
name: site_snippets
publish_to: none
environment:
  sdk: ">=3.11.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  flutter_zxing:
    path: ../..
  url_launcher: ^6.3.0
''');
  // No lints: only errors decide.
  File('${pkg.path}/analysis_options.yaml').writeAsStringSync('''
analyzer:
  language:
    strict-raw-types: false
''');

  // file name -> sample index
  final Map<String, int> owner = <String, int>{};
  for (int i = 0; i < samples.length; i++) {
    final Map<String, String> variants = _wrap(samples[i].code, i);
    variants.forEach((String name, String text) {
      final String fileName = 's${i}_$name.dart';
      owner[fileName] = i;
      File('${pkg.path}/lib/$fileName').writeAsStringSync(text);
    });
  }

  final ProcessResult get = await Process.run(
    'flutter',
    <String>['pub', 'get'],
    workingDirectory: pkg.path,
    runInShell: true,
  );
  if (get.exitCode != 0) {
    stderr
      ..writeln('flutter pub get failed in ${pkg.path}:')
      ..writeln(get.stdout)
      ..writeln(get.stderr);
    exit(1);
  }
  final ProcessResult analyzed = await Process.run(
    'dart',
    <String>['analyze', '--format=machine', 'lib'],
    workingDirectory: pkg.path,
    runInShell: true,
  );

  // sample index -> file name -> errors
  final Map<int, Map<String, List<String>>> errors =
      <int, Map<String, List<String>>>{
        for (int i = 0; i < samples.length; i++)
          i: <String, List<String>>{
            for (final MapEntry<String, int> e in owner.entries)
              if (e.value == i) e.key: <String>[],
          },
      };
  final String output = '${analyzed.stdout}\n${analyzed.stderr}';
  for (final String line in output.split('\n')) {
    final List<String> parts = line.split('|');
    if (parts.length < 8 || parts[0] != 'ERROR') {
      continue;
    }
    final String fileName = parts[3].split(RegExp(r'[/\\]')).last;
    final int? i = owner[fileName];
    if (i == null) {
      continue;
    }
    errors[i]![fileName]!.add(
      'line ${parts[4]}: ${parts.sublist(7).join('|')}',
    );
  }

  int failed = 0;
  for (int i = 0; i < samples.length; i++) {
    final Map<String, List<String>> byVariant = errors[i]!;
    if (byVariant.values.any((List<String> e) => e.isEmpty)) {
      continue;
    }
    failed++;
    final MapEntry<String, List<String>> best = byVariant.entries.reduce(
      (MapEntry<String, List<String>> a, MapEntry<String, List<String>> b) =>
          b.value.length < a.value.length ? b : a,
    );
    stderr.writeln(
      '✗ ${samples[i]} (closest: ${best.key}, '
      'build/site_snippets/lib/${best.key})',
    );
    for (final String e in best.value) {
      stderr.writeln('    $e');
    }
  }
  final int passed = samples.length - failed;
  stdout.writeln('$passed of ${samples.length} samples compile.');
  if (failed > 0) {
    exit(1);
  }
}

/// Files with [extension] under [dir], skipping dependencies and output.
List<File> _files(Directory dir, String extension) {
  if (!dir.existsSync()) {
    return <File>[];
  }
  final List<File> files = <File>[
    for (final FileSystemEntity e in dir.listSync(recursive: true))
      if (e is File &&
          e.path.endsWith(extension) &&
          !RegExp(r'[/\\](node_modules|cache|dist)[/\\]').hasMatch(e.path))
        e,
  ]..sort((File a, File b) => a.path.compareTo(b.path));
  return files;
}

String _relative(Directory root, File f) =>
    f.path.startsWith(root.path) ? f.path.substring(root.path.length) : f.path;

/// The ```dart blocks of [file], unless marked `<!-- snippet: skip -->`.
List<Sample> _fromMarkdown(Directory root, File file) {
  final List<String> lines = file.readAsLinesSync();
  final List<Sample> found = <Sample>[];
  for (int i = 0; i < lines.length; i++) {
    final RegExpMatch? open = RegExp(
      r'^(\s*)(```+)\s*dart\b',
    ).firstMatch(lines[i]);
    if (open == null) {
      continue;
    }
    final String fence = open.group(2)!;
    final int start = i;
    final List<String> body = <String>[];
    for (i++; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith(fence)) {
        break;
      }
      body.add(lines[i]);
    }
    int prev = start - 1;
    while (prev >= 0 && lines[prev].trim().isEmpty) {
      prev--;
    }
    if (prev >= 0 && lines[prev].trim() == '<!-- snippet: skip -->') {
      continue;
    }
    found.add(Sample(_relative(root, file), start + 1, body.join('\n')));
  }
  return found;
}

/// The `build` a State of members gets when the sample has none.
const String _build =
    '  @override\n'
    '  Widget build(BuildContext context) => const SizedBox();\n';

/// The wrappers [code] is tried in.
Map<String, String> _wrap(String code, int i) {
  final List<String> imports = <String>[];
  final List<String> rest = <String>[];
  for (final String line in code.split('\n')) {
    (line.trimLeft().startsWith('import ') ? imports : rest).add(line);
  }
  final String head = <String>[..._prelude, ...imports].join('\n');
  final String body = rest.join('\n');
  final String expression = body.trim().replaceFirst(RegExp(r'[;,]\s*$'), '');
  final bool hasBuild = body.contains(RegExp(r'Widget\s+build\s*\('));
  return <String, String>{
    'file': '$head\n\n$body\n',
    'statements':
        '$head\n\nFuture<void> snippet$i(BuildContext context) async {\n'
        '${_terminate(body)}\n}\n',
    'expression':
        '$head\n\nObject? snippet$i(BuildContext context) => (\n'
        '$expression\n);\n',
    'members':
        '$head\n\nclass Snippet$i extends StatefulWidget {\n'
        '  const Snippet$i({super.key});\n'
        '  @override\n'
        '  State<Snippet$i> createState() => _Snippet${i}State();\n'
        '}\n\n'
        'class _Snippet${i}State extends State<Snippet$i> {\n$body\n'
        '${hasBuild ? '' : _build}}\n',
  };
}

/// [body] with a `;` after each top-level expression that has none, such
/// as a widget written on its own: `BarcodeView('x')`.
String _terminate(String body) {
  final List<String> lines = body.split('\n');
  final List<String> out = <String>[];
  int depth = 0;
  for (int n = 0; n < lines.length; n++) {
    final String line = lines[n];
    depth += _depthChange(line);
    String done = line;
    final String trimmed = _withoutComment(line).trimRight();
    if (depth == 0 &&
        trimmed.isNotEmpty &&
        !RegExp(r'[;{},]$').hasMatch(trimmed) &&
        !_continues(lines, n)) {
      done = '$trimmed;';
    }
    out.add(done);
  }
  return out.join('\n');
}

/// Whether the statement on line [n] goes on on the next code line.
bool _continues(List<String> lines, int n) {
  for (int m = n + 1; m < lines.length; m++) {
    final String next = _withoutComment(lines[m]).trim();
    if (next.isEmpty) {
      continue;
    }
    return RegExp(
      r'^(\.|\?\.|\?\?|\?|:|&&|\|\||\+|-|\*|/|=>|as\b)',
    ).hasMatch(next);
  }
  return false;
}

/// [line] without a `//` comment; a `//` inside a string, as in
/// `'https://pub.dev'`, stays.
String _withoutComment(String line) {
  String? quote;
  for (int k = 0; k < line.length; k++) {
    final String c = line[k];
    if (quote != null) {
      if (c == r'\') {
        k++;
      } else if (c == quote) {
        quote = null;
      }
    } else if (c == "'" || c == '"') {
      quote = c;
    } else if (c == '/' && k + 1 < line.length && line[k + 1] == '/') {
      return line.substring(0, k);
    }
  }
  return line;
}

/// Brackets opened minus brackets closed on [line], outside strings and
/// comments.
int _depthChange(String line) {
  int change = 0;
  String? quote;
  for (int k = 0; k < line.length; k++) {
    final String c = line[k];
    if (quote != null) {
      if (c == r'\') {
        k++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == '/' && k + 1 < line.length && line[k + 1] == '/') {
      break;
    }
    if (c == "'" || c == '"') {
      quote = c;
    } else if ('([{'.contains(c)) {
      change++;
    } else if (')]}'.contains(c)) {
      change--;
    }
  }
  return change;
}
