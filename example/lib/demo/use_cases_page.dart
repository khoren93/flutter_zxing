// The Use cases tab: how apps use flutter_zxing, each case runnable and
// shown as the code to copy.
import 'dart:async';

import 'package:flutter/services.dart';
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tokens.dart';
import 'use_cases.dart';

/// Where the cases' files are on GitHub.
const String _repoFiles =
    'https://github.com/khoren93/flutter_zxing/blob/main/example/';

/// Opens a use case over the whole app, tab bar included.
Future<void> openUseCase(BuildContext context, UseCase useCase) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: useCase.builder));

Future<void> _openCode(BuildContext context, UseCase useCase) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => UseCaseCodePage(useCase),
      ),
    );

class UseCasesPage extends StatelessWidget {
  const UseCasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    return CustomScrollView(
      slivers: <Widget>[
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Use cases',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'How apps use flutter_zxing. Open a case to try it, '
                    'or see its code: one file to copy into your app.',
                    style: TextStyle(color: fz.inkMuted, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ),
        for (final UseCaseGroup group in UseCaseGroup.values) ...<Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: FzLabel(group.label),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.list(
              children: <Widget>[
                for (final UseCase c in useCases)
                  if (c.group == group) _Row(c),
              ],
            ),
          ),
        ],
        // Clears the floating tab bar.
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.useCase);

  final UseCase useCase;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: fz.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: fz.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(openUseCase(context, useCase)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: useCase.group == UseCaseGroup.scan
                        ? fz.lockSoft
                        : fz.made.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    useCase.icon,
                    color: useCase.group == UseCaseGroup.scan
                        ? fz.lockInk
                        : fz.madeInk,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        useCase.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: fz.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        useCase.summary,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: fz.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Show the code',
                  icon: const Icon(Icons.code_rounded),
                  onPressed: () => unawaited(_openCode(context, useCase)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A case's file as it is, to read and copy.
class UseCaseCodePage extends StatefulWidget {
  const UseCaseCodePage(this.useCase, {super.key});

  final UseCase useCase;

  @override
  State<UseCaseCodePage> createState() => _UseCaseCodePageState();
}

class _UseCaseCodePageState extends State<UseCaseCodePage> {
  late final Future<String> _source = rootBundle.loadString(
    widget.useCase.file,
  );

  Future<void> _copy(String source) async {
    await Clipboard.setData(ClipboardData(text: source));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code copied')));
  }

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final UseCase c = widget.useCase;
    return FutureBuilder<String>(
      future: _source,
      builder: (BuildContext context, AsyncSnapshot<String> snap) {
        final String? source = snap.data;
        return Scaffold(
          backgroundColor: fz.surface,
          appBar: AppBar(
            title: Text(c.title),
            actions: <Widget>[
              IconButton(
                tooltip: 'Copy the code',
                icon: const Icon(Icons.copy_rounded),
                onPressed: source == null ? null : () => _copy(source),
              ),
              IconButton(
                tooltip: 'Open on GitHub',
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: () =>
                    unawaited(launchUrl(Uri.parse('$_repoFiles${c.file}'))),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => unawaited(openUseCase(context, c)),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Try it'),
          ),
          body: switch (snap) {
            AsyncSnapshot<String>(hasError: true) => Center(
              child: Text('${c.file} is not in the app'),
            ),
            _ when source == null => const Center(
              child: CircularProgressIndicator(),
            ),
            _ => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _Chip(c.file.substring('lib/'.length), mono: true),
                    for (final String p in c.needs) _Chip('needs $p'),
                  ],
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: fz.raised,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: fz.line),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(14),
                    child: SelectableText.rich(
                      highlightDart(
                        source,
                        Theme.of(context).brightness == Brightness.dark,
                      ),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontFamilyFallback: const <String>[
                          'Menlo',
                          'Consolas',
                          'Roboto Mono',
                        ],
                        fontSize: 12.5,
                        height: 1.45,
                        color: fz.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          },
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.mono = false});

  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fz.raised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fz.line),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null,
          color: fz.inkMuted,
        ),
      ),
    );
  }
}

const Set<String> _keywords = <String>{
  'abstract', 'as', 'async', 'await', 'break', 'case', 'catch', 'class', //
  'const', 'continue', 'default', 'else', 'enum', 'extends', 'false', //
  'final', 'finally', 'for', 'if', 'implements', 'import', 'in', 'is', //
  'late', 'library', 'mixin', 'new', 'null', 'on', 'override', 'part', //
  'required', 'return', 'sealed', 'show', 'static', 'super', 'switch', //
  'this', 'throw', 'true', 'try', 'var', 'void', 'when', 'while', 'with', //
  'yield', 'get', 'set', 'typedef', 'extension', 'base', 'interface',
};

final RegExp _token = RegExp(
  r"(//[^\n]*)" // 1 comment
  r"|('''[\s\S]*?'''|"
  r'"""[\s\S]*?"""|'
  r"'(?:[^'\\\n]|\\.)*'|"
  r'"(?:[^"\\\n]|\\.)*")' // 2 string
  r'|(@\w+)' // 3 annotation
  r'|(\b\d[\d_]*(?:\.\d+)?\b|\b0x[0-9A-Fa-f]+\b)' // 4 number
  r'|(\b[A-Za-z_]\w*\b)', // 5 word
);

/// Dart source with comments, strings, keywords, types and numbers coloured.
TextSpan highlightDart(String source, bool dark) {
  final Color comment = dark
      ? const Color(0xFF7D8590)
      : const Color(0xFF6E7781);
  final Color string = dark ? const Color(0xFF7EE0B5) : const Color(0xFF0A7A55);
  final Color keyword = dark
      ? const Color(0xFFFF8FA3)
      : const Color(0xFFC0245C);
  final Color type = dark ? const Color(0xFF8CC8FF) : const Color(0xFF0B5CAD);
  final Color number = dark ? const Color(0xFFFFC857) : const Color(0xFF9A5B00);
  final List<TextSpan> spans = <TextSpan>[];
  int at = 0;
  for (final RegExpMatch m in _token.allMatches(source)) {
    if (m.start > at) spans.add(TextSpan(text: source.substring(at, m.start)));
    final String t = m[0]!;
    final Color? color = switch (m) {
      _ when m[1] != null => comment,
      _ when m[2] != null => string,
      _ when m[3] != null => keyword,
      _ when m[4] != null => number,
      _ when _keywords.contains(t) => keyword,
      _ when t.startsWith(RegExp('_?[A-Z]')) => type,
      _ => null,
    };
    spans.add(
      TextSpan(
        text: t,
        style: color == null
            ? null
            : TextStyle(
                color: color,
                fontStyle: m[1] != null ? FontStyle.italic : null,
              ),
      ),
    );
    at = m.end;
  }
  if (at < source.length) spans.add(TextSpan(text: source.substring(at)));
  return TextSpan(children: spans);
}
