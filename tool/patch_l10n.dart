// Finishes the code `flutter gen-l10n` writes for the scanner's texts
// (make l10n): `ScannerLocalizations.of` finds the texts without any setup
// (a ScannerScope, a registered delegate or the device's language, else
// English) instead of requiring the delegate, and the class documentation
// says so. `localizationsDelegates` goes: it lists Flutter's Material and
// Cupertino delegates, deprecated since Flutter 3.47, and with it the
// package's only use of flutter_localizations. Run from tool/ with the
// generated file as the argument.
import 'dart:io';

void main(List<String> args) {
  final File file = File(args.single);
  String source = file.readAsStringSync();

  // The class documentation: gen-l10n's tells apps to register the delegate.
  final int docStart = source.indexOf('/// Callers can lookup');
  final int classStart = source.indexOf('abstract class ScannerLocalizations');
  if (docStart < 0 || classStart < docStart) {
    _fail('the class documentation');
  }
  source = source.replaceRange(docStart, classStart, _classDoc);

  // The lookup.
  final RegExp of = RegExp(
    r'  static ScannerLocalizations of\(BuildContext context\) \{.*?\n  \}\n',
    dotAll: true,
  );
  if (!of.hasMatch(source)) {
    _fail('ScannerLocalizations.of');
  }
  source = source.replaceFirst(of, _of);

  // Documentation of the members gen-l10n leaves without.
  for (final (String member, String doc) in _memberDocs) {
    if (!source.contains(member)) {
      _fail(member.trim());
    }
    source = source.replaceFirst(member, '$doc$member');
  }

  // Flutter's delegates.
  final RegExp delegates = RegExp(
    r'  /// A list of this localizations delegate along with.*?\n      \];\n\n',
    dotAll: true,
  );
  const String material =
      "import 'package:flutter_localizations/flutter_localizations.dart';\n";
  if (!delegates.hasMatch(source) || !source.contains(material)) {
    _fail('localizationsDelegates');
  }
  source = source.replaceFirst(delegates, '').replaceFirst(material, '');

  // The lookup lives next to the generated code.
  const String anchor = "import 'scanner_localizations_en.dart';";
  if (!source.contains(anchor)) {
    _fail('the imports');
  }
  source = source.replaceFirst(
    anchor,
    "$anchor\nimport 'scanner_localizations_lookup.dart';",
  );
  file.writeAsStringSync(source);
}

Never _fail(String what) {
  stderr.writeln(
    'patch_l10n: the generated file has no $what; did gen-l10n '
    'change?',
  );
  exit(1);
}

const String _classDoc = '''
/// The texts of the scanner widgets: button labels for screen readers,
/// states, result sheets, the templates' titles and hints. Built in: English
/// and Russian, chosen by the app's locale with no setup.
///
/// Get them with [ScannerLocalizations.of]. To change a text, subclass the
/// built-in translation and give it to a `ScannerScope`:
///
/// ```dart
/// class MyTexts extends ScannerLocalizationsEn {
///   @override
///   String get scanAgain => 'Next ticket';
/// }
///
/// ScannerScope(texts: MyTexts(), child: ...)
/// ```
///
/// Generated from `lib/l10n/scanner_*.arb` by `make l10n`; do not edit.
''';

const String _of = '''
  /// The texts for [context]: those given to the nearest `ScannerScope`,
  /// else those of [delegate] if the app registered it, else the built-in
  /// translation for the app's locale, English for a language without one.
  static ScannerLocalizations of(BuildContext context) =>
      scannerLocalizationsOf(context);
''';

const List<(String, String)> _memberDocs = <(String, String)>[
  (
    '  ScannerLocalizations(String locale)',
    '  /// Texts in [locale], whose dates and plurals follow it: a subclass for\n'
        "  /// another language passes that language's code.\n",
  ),
  (
    '  final String localeName;',
    '  /// The canonical name of the locale, such as `ru` or `en_US`.\n',
  ),
  (
    '  static const LocalizationsDelegate<ScannerLocalizations> delegate =',
    '  /// The texts as a [LocalizationsDelegate], for an app that lists every\n'
        '  /// delegate; [of] finds the texts without it.\n',
  ),
];
