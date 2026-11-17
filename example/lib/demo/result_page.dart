// A code from the history: its picture, what it holds, what to do with it.
import 'dart:async';

import 'package:flutter/services.dart';
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:share_plus/share_plus.dart';

import 'aim.dart';
import 'content.dart';
import 'history.dart';
import 'tokens.dart';

class ResultPage extends StatefulWidget {
  const ResultPage(this.item, {super.key, this.onMakeStyled});

  final HistoryItem item;

  /// Opens the generator with this code's text.
  final ValueChanged<String>? onMakeStyled;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _showSecret = true;

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$what copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final HistoryItem item = widget.item;
    final Barcode barcode = item.barcode;
    final Described d = describe(barcode);
    final String? secret = d.secret;
    final Uri? open = d.open;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: fz.surface,
        surfaceTintColor: Colors.transparent,
        actions: <Widget>[
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => unawaited(
              SharePlus.instance.share(ShareParams(text: barcode.text)),
            ),
          ),
          IconButton(
            tooltip: 'Delete from history',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () {
              HistoryStore.instance.remove(item);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: <Widget>[
              Row(
                children: <Widget>[
                  HistoryPicture(item, size: 112),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(d.icon, size: 16, color: fz.inkMuted),
                            const SizedBox(width: 6),
                            FzLabel(d.kind),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          d.title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontSize: 26, height: 32 / 26),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            _Chip(
                              barcode.contentType == BarcodeContentType.gs1
                                  ? '${barcode.format.displayName} · GS1'
                                  : barcode.format.displayName,
                            ),
                            _Tag(
                              item.origin == HistoryOrigin.created
                                  ? 'Created'
                                  : 'Scanned',
                              made: item.origin == HistoryOrigin.created,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  if (open != null)
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Fz.lock,
                          foregroundColor: Fz.onLock,
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: () => unawaited(openUri(context, open)),
                        icon: Icon(d.openIcon),
                        label: Text(d.openLabel ?? 'Open'),
                      ),
                    ),
                  if (open != null) const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      onPressed: () => unawaited(
                        secret != null
                            ? _copy(secret, 'Password')
                            : _copy(barcode.text, 'Text'),
                      ),
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(secret != null ? 'Copy password' : 'Copy'),
                    ),
                  ),
                ],
              ),
              if (d.fields.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                FzCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      for (final (int i, (String k, String v))
                          in d.fields.indexed) ...<Widget>[
                        if (i > 0) const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Row(
                            children: <Widget>[
                              SizedBox(
                                width: 104,
                                child: Text(
                                  k,
                                  style: TextStyle(color: fz.inkMuted),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    v == secret && !_showSecret
                                        ? '•' * v.length
                                        : v,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontFamily: v == secret
                                          ? 'monospace'
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              if (v == secret)
                                IconButton(
                                  tooltip: _showSecret
                                      ? 'Hide the password'
                                      : 'Show the password',
                                  icon: Icon(
                                    _showSecret
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _showSecret = !_showSecret,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _TechCard(barcode: barcode, kind: d.kind),
              const SizedBox(height: 16),
              const FzLabel('As read'),
              const SizedBox(height: 8),
              FzCard(
                child: SelectableText(
                  barcode.text,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    height: 22 / 15,
                  ),
                ),
              ),
              if (widget.onMakeStyled != null &&
                  !barcode.format.isLinear) ...<Widget>[
                const SizedBox(height: 16),
                FzCard(
                  padding: const EdgeInsets.all(4),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    leading: const Icon(Icons.qr_code_2_rounded),
                    title: const Text(
                      'Make a styled code from this',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => widget.onMakeStyled!(barcode.text),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _when(item),
                textAlign: TextAlign.center,
                style: TextStyle(color: fz.inkMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _when(HistoryItem item) {
    final DateTime t = item.time;
    final DateTime now = DateTime.now();
    final String hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final bool today =
        t.year == now.year && t.month == now.month && t.day == now.day;
    final String day = today ? 'Today' : '${t.day}.${t.month}.${t.year}';
    final String how = item.origin == HistoryOrigin.created
        ? 'created'
        : item.source;
    return '$day, $hm · $how';
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fz.lockSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: fz.lockInk,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.made = false});

  final String text;
  final bool made;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: made ? fz.made : fz.surface,
        borderRadius: BorderRadius.circular(8),
        border: made ? null : Border.all(color: fz.line),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
          color: made ? fz.madeInk : fz.inkMuted,
        ),
      ),
    );
  }
}

/// A history tag, for lists.
class HistoryTag extends StatelessWidget {
  const HistoryTag({super.key});

  @override
  Widget build(BuildContext context) => const _Tag('Created', made: true);
}

/// What a developer wants to know about a read: the format, the kind of
/// content, the symbol's numbers, and the AIM ID in words.
class _TechCard extends StatelessWidget {
  const _TechCard({required this.barcode, required this.kind});

  final Barcode barcode;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final BarcodeSequence? sequence = barcode.sequence;
    final String ec = barcode.ecLevel ?? '';
    final String version = barcode.version ?? '';
    final AimParts? aim = describeAim(barcode.symbologyIdentifier);
    final List<(String, String, bool)> rows = <(String, String, bool)>[
      ('Format', barcode.format.displayName, true),
      ('Content', '$kind · ${contentClassName(barcode.content)}', true),
      if (version.isNotEmpty || ec.isNotEmpty)
        (
          'Version · EC',
          <String>[
            if (version.isNotEmpty) version,
            if (ec.isNotEmpty) 'EC $ec',
          ].join(' · '),
          true,
        ),
      (
        'Orientation',
        barcode.orientation == 0 ? 'Upright' : 'Turned ${barcode.orientation}°',
        barcode.orientation != 0,
      ),
      (
        'Mirrored',
        '${barcode.isMirrored ? 'Yes' : 'No'} · '
            '${barcode.isInverted ? 'inverted' : 'not inverted'}',
        barcode.isMirrored || barcode.isInverted,
      ),
      (
        'Sequence',
        sequence == null
            ? 'Not part of a structured append'
            : 'Part ${sequence.index + 1} of ${sequence.size}'
                  '${sequence.id.isEmpty ? '' : ' · id ${sequence.id}'}',
        sequence != null,
      ),
    ];
    Widget line(String k, Widget v) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 116,
            child: Text(k, style: TextStyle(color: fz.inkMuted)),
          ),
          Expanded(child: v),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const FzLabel('Technical'),
        const SizedBox(height: 8),
        FzCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final (int i, (String k, String v, bool on))
                  in rows.indexed) ...<Widget>[
                if (i > 0) const Divider(),
                line(
                  k,
                  Text(
                    v,
                    style: TextStyle(
                      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                      color: on ? fz.ink : fz.inkMuted,
                    ),
                  ),
                ),
              ],
              if (aim != null) ...<Widget>[
                const Divider(),
                line(
                  'AIM ID',
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: fz.ink,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        barcode.symbologyIdentifier,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: fz.raised,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: fz.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: <Widget>[
                      for (final (String c, String meaning)
                          in <(String, String)>[
                            (']', 'Symbology identifier follows'),
                            (barcode.symbologyIdentifier[1], aim.symbology),
                            (
                              barcode.symbologyIdentifier.substring(2),
                              aim.modifier,
                            ),
                          ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              SizedBox(
                                width: 40,
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: fz.lockInk,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  meaning,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    'Read by scanners and PLCs to tell formats apart · '
                    'ISO/IEC 15424',
                    style: TextStyle(fontSize: 12, color: fz.inkMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
