// Every scanned and created code, newest first, grouped by day.
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'built_with.dart';
import 'content.dart';
import 'history.dart';
import 'result_page.dart';
import 'tokens.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.onOpen, this.builtWith = true});

  /// Opens an item's result page.
  final ValueChanged<HistoryItem> onOpen;

  /// The ZXScanner card under the list; the wide layout has it in the side
  /// menu.
  final bool builtWith;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

enum _Filter { all, scanned, created }

class _HistoryPageState extends State<HistoryPage> {
  _Filter _filter = _Filter.all;
  String _query = '';
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    return ListenableBuilder(
      listenable: HistoryStore.instance,
      builder: (BuildContext context, Widget? _) {
        final List<HistoryItem> items = HistoryStore.instance.items.where((
          HistoryItem i,
        ) {
          final bool kind = switch (_filter) {
            _Filter.all => true,
            _Filter.scanned => i.origin == HistoryOrigin.scanned,
            _Filter.created => i.origin == HistoryOrigin.created,
          };
          return kind &&
              (_query.isEmpty ||
                  i.barcode.text.toLowerCase().contains(_query.toLowerCase()));
        }).toList();
        final List<Widget> rows = <Widget>[];
        String? day;
        for (final HistoryItem item in items) {
          final String d = _day(item.time);
          if (d != day) {
            day = d;
            rows.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: FzLabel(d),
              ),
            );
          }
          rows.add(_Row(item, onTap: () => widget.onOpen(item)));
        }
        return CustomScrollView(
          slivers: <Widget>[
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _searching
                            ? TextField(
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'Search',
                                  prefixIcon: Icon(Icons.search_rounded),
                                ),
                                onChanged: (String q) =>
                                    setState(() => _query = q),
                              )
                            : Text(
                                'History',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: _searching ? 'Close search' : 'Search',
                        icon: Icon(
                          _searching
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                        ),
                        onPressed: () => setState(() {
                          _searching = !_searching;
                          _query = '';
                        }),
                      ),
                      if (!_searching)
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          icon: const Icon(Icons.more_horiz_rounded),
                          itemBuilder: (BuildContext context) =>
                              const <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'clear',
                                  child: Text('Clear history'),
                                ),
                              ],
                          onSelected: (_) => HistoryStore.instance.clear(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<_Filter>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<_Filter>>[
                    ButtonSegment<_Filter>(
                      value: _Filter.all,
                      label: Text('All'),
                    ),
                    ButtonSegment<_Filter>(
                      value: _Filter.scanned,
                      label: Text('Scanned'),
                    ),
                    ButtonSegment<_Filter>(
                      value: _Filter.created,
                      label: Text('Created'),
                    ),
                  ],
                  selected: <_Filter>{_filter},
                  onSelectionChanged: (Set<_Filter> s) =>
                      setState(() => _filter = s.first),
                ),
              ),
            ),
            if (rows.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _query.isNotEmpty
                          ? 'Nothing matches "$_query".'
                          : 'Codes you scan or create show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fz.inkMuted, fontSize: 16),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 120),
                sliver: SliverList.list(
                  children: <Widget>[
                    ...rows,
                    if (widget.builtWith)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 24, 8, 0),
                        child: BuiltWithCard(),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static String _day(DateTime t) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime d = DateTime(t.year, t.month, t.day);
    final int ago = today.difference(d).inDays;
    return switch (ago) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => '${t.day}.${t.month.toString().padLeft(2, '0')}.${t.year}',
    };
  }
}

class _Row extends StatelessWidget {
  const _Row(this.item, {required this.onTap});

  final HistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final Described d = describe(item.barcode);
    final DateTime t = item.time;
    final String suffix =
        item.origin == HistoryOrigin.created && item.preset != null
        ? ' · ${item.preset![0].toUpperCase()}${item.preset!.substring(1)}'
        : '';
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            HistoryPicture(item),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          d.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.origin == HistoryOrigin.created) ...<Widget>[
                        const SizedBox(width: 8),
                        const HistoryTag(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.kind} · ${item.barcode.format.displayName}$suffix',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: fz.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: fz.inkMuted,
                fontSize: 13,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens [item] on its own page.
void openResult(
  BuildContext context,
  HistoryItem item, {
  ValueChanged<String>? onMakeStyled,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          ResultPage(item, onMakeStyled: onMakeStyled),
    ),
  );
}
