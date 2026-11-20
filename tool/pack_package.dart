// Copies the files `pub publish` would upload into a folder, so that the
// package can be tried as users get it: the example built from it shows a
// file that .pubignore leaves out but the package needs.
//
// usage (from the repository root):
//   cd tool && dart run pack_package.dart ../build/package
//
// The list is the file tree of `flutter pub publish --dry-run`, which also
// validates the package: errors fail this tool, warnings do not.
import 'dart:io';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run pack_package.dart <output folder>');
    exit(2);
  }
  final Directory root = Directory.fromUri(Platform.script.resolve('..'));
  final ProcessResult dryRun = Process.runSync(
    'flutter',
    <String>['pub', 'publish', '--dry-run', '--ignore-warnings'],
    workingDirectory: root.path,
    runInShell: true,
  );
  final String output = '${dryRun.stdout}${dryRun.stderr}';
  if (dryRun.exitCode != 0) {
    stderr
      ..write(output)
      ..writeln('pub publish --dry-run failed (exit ${dryRun.exitCode})');
    exit(1);
  }
  final List<String> files = packageFiles(output);
  if (files.isEmpty) {
    stderr
      ..write(output)
      ..writeln('No file tree in the output of pub publish --dry-run');
    exit(1);
  }
  final Directory out = Directory(args.single);
  if (out.existsSync()) {
    out.deleteSync(recursive: true);
  }
  for (final String path in files) {
    final File target = File('${out.path}/$path')
      ..parent.createSync(recursive: true);
    File('${root.path}/$path').copySync(target.path);
  }
  stdout.writeln('${files.length} files in ${out.path}');
}

/// The file paths of the tree that `pub publish --dry-run` prints:
///
/// ```text
/// ├── CHANGELOG.md (35 KB)
/// ├── assets
/// │   └── web
/// │       └── fzx_worker.js (6 KB)
/// ```
///
/// Folders have no size; every level is indented by four characters.
List<String> packageFiles(String output) {
  final RegExp line = RegExp(r'^((?:[│ ]   )*)[├└]── (.+?)(?: \(([^()]+)\))?$');
  final List<String> folders = <String>[];
  final List<String> files = <String>[];
  for (final String text in output.split('\n')) {
    final RegExpMatch? m = line.firstMatch(text.trimRight());
    if (m == null) {
      continue;
    }
    final int depth = m.group(1)!.length ~/ 4;
    final String name = m.group(2)!;
    folders.length = depth;
    if (m.group(3) == null) {
      folders.add(name);
    } else {
      files.add(<String>[...folders, name].join('/'));
    }
  }
  return files;
}
