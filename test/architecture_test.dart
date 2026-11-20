// The layers of the package (see CONTRIBUTING.md): the core is zxing-cpp
// for Flutter and knows nothing of the layers on top; dependencies only go
// down. This test reads the imports and exports of every file in lib/.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layer of each folder (or file) under `lib/src/`.
const Map<String, String> _layerOf = <String, String>{
  'barcode': 'core',
  'engine': 'core',
  'reading': 'core',
  'writing': 'core',
  'errors.dart': 'core',
  'content': 'content',
  'rendering': 'rendering',
  'scanning': 'scanner',
  'legacy': 'legacy',
};

/// What each layer may import, itself included.
const Map<String, Set<String>> _allowed = <String, Set<String>>{
  'core': <String>{'core'},
  'content': <String>{'core', 'content'},
  'rendering': <String>{'core', 'rendering'},
  'scanner': <String>{'core', 'content', 'rendering', 'scanner'},
  'legacy': <String>{'core', 'legacy'},
};

/// Packages each layer may use besides Dart and its own package. The core
/// uses Flutter only for `dart:ui` types, never for widgets.
const Map<String, Set<String>> _packages = <String, Set<String>>{
  'core': <String>{
    'package:flutter/foundation.dart',
    'package:flutter/painting.dart',
    'package:ffi/',
    'package:web/',
  },
  'content': <String>{'package:flutter/foundation.dart'},
  'rendering': <String>{
    'package:flutter/foundation.dart',
    'package:flutter/painting.dart',
    'package:flutter/rendering.dart',
    'package:flutter/widgets.dart',
  },
};

/// What each entry point may export: the files of its own layer and the
/// entry points below it.
const Map<String, (String, Set<String>)> _entryPoints =
    <String, (String, Set<String>)>{
      'core.dart': ('core', <String>{}),
      'content.dart': ('content', <String>{'core.dart'}),
      'rendering.dart': ('rendering', <String>{'core.dart'}),
      'scanner.dart': ('scanner', <String>{'content.dart', 'rendering.dart'}),
    };

final RegExp _directive = RegExp(
  r'''^(?:import|export)\s+'([^']+)'(?:\s+if\s*\([^)]*\)\s*'([^']+)')*''',
  multiLine: true,
);

/// The URIs a file imports and exports, conditional ones included.
List<String> _uris(File file) {
  final String source = file.readAsStringSync();
  final List<String> uris = <String>[];
  for (final RegExpMatch m in _directive.allMatches(source)) {
    uris.add(m.group(1)!);
    // Conditional imports: `import 'a.dart' if (dart.library.io) 'b.dart'`.
    final String whole = m.group(0)!;
    uris.addAll(
      RegExp(
        r"if\s*\([^)]*\)\s*'([^']+)'",
      ).allMatches(whole).map((RegExpMatch c) => c.group(1)!),
    );
  }
  return uris;
}

/// The layer of a path relative to `lib/src/`, or `null` outside it. The
/// path may use `\` (Windows) or `/`.
String? _layer(String relative) {
  final String first = relative.split(RegExp(r'[/\\]')).first;
  return _layerOf[first];
}

/// [uri] from [file] as a path relative to `lib/src/`, or `null` if it
/// is not a file of this package under `lib/src/`.
String? _target(File file, String uri) {
  if (uri.startsWith('dart:') || uri.startsWith('package:')) {
    if (uri.startsWith('package:flutter_zxing/src/')) {
      return uri.substring('package:flutter_zxing/src/'.length);
    }
    return null;
  }
  final String resolved = file.parent.uri.resolve(uri).toFilePath();
  final String src = Directory('lib/src').absolute.uri.toFilePath();
  return resolved.startsWith(src) ? resolved.substring(src.length) : null;
}

void main() {
  final List<File> files = Directory('lib/src')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .map((File f) => f.absolute)
      .toList();
  final String src = Directory('lib/src').absolute.uri.toFilePath();

  test('a path with Windows separators finds its layer', () {
    expect(_layer(r'engine\engine.dart'), isNotNull);
    expect(_layer(r'engine\engine.dart'), _layer('engine/engine.dart'));
  });

  test('every file in lib/src belongs to a layer', () {
    final List<String> orphans = <String>[
      for (final File f in files)
        if (_layer(f.path.substring(src.length)) == null)
          f.path.substring(src.length),
    ];
    expect(orphans, isEmpty, reason: 'add the folder to _layerOf');
  });

  test('layers only depend on the layers below them', () {
    final List<String> problems = <String>[];
    for (final File f in files) {
      final String path = f.path.substring(src.length);
      final String layer = _layer(path)!;
      for (final String uri in _uris(f)) {
        final String? target = _target(f, uri);
        if (target != null) {
          final String? to = _layer(target);
          if (to != null && !_allowed[layer]!.contains(to)) {
            problems.add('$path ($layer) → $target ($to)');
          }
        } else if (uri.startsWith('package:') &&
            !uri.startsWith('package:flutter_zxing/') &&
            _packages.containsKey(layer) &&
            !_packages[layer]!.any(uri.startsWith)) {
          problems.add('$path ($layer) → $uri');
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('each entry point exports its layer and the ones below it', () {
    final List<String> problems = <String>[];
    _entryPoints.forEach((String name, (String, Set<String>) rule) {
      final (String layer, Set<String> below) = rule;
      final File file = File('lib/$name').absolute;
      for (final String uri in _uris(file)) {
        if (below.contains(uri)) {
          continue;
        }
        final String? target = _target(file, uri);
        if (target == null || _layer(target) != layer) {
          problems.add('$name → $uri');
        }
      }
    });
    expect(problems, isEmpty);
  });

  test('flutter_zxing.dart exports every layer', () {
    final List<String> uris = _uris(File('lib/flutter_zxing.dart'));
    expect(uris, contains('scanner.dart'));
    expect(uris, contains('src/legacy/legacy.dart'));
  });
}
