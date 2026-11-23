// The demo app's shell: Scan, Create, Use cases and History; a glass tab bar on
// phones, a side menu on wide windows.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'built_with.dart';
import 'create_page.dart';
import 'history.dart';
import 'history_page.dart';
import 'scan_page.dart';
import 'tokens.dart';
import 'use_cases.dart';
import 'use_cases_page.dart';

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'flutter_zxing',
    theme: demoTheme(Brightness.light),
    darkTheme: demoTheme(Brightness.dark),
    home: const DemoShell(),
  );
}

enum _Tab { scan, create, cases, history }

class DemoShell extends StatefulWidget {
  const DemoShell({super.key});

  @override
  State<DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<DemoShell> {
  final GlobalKey _pagesKey = GlobalKey();
  // --dart-define=TAB=create (or ?tab=create on the web) opens a tab
  // directly, for screenshots.
  _Tab _tab = _Tab.values.firstWhere(
    (_Tab t) =>
        t.name == const String.fromEnvironment('TAB') ||
        t.name == Uri.base.queryParameters['tab'],
    orElse: () => _Tab.scan,
  );

  @override
  void initState() {
    super.initState();
    unawaited(HistoryStore.instance.load());
    // --dart-define=CASE=door_check_in (or ?case=door_check_in on the web)
    // opens a use case directly.
    final String id = const String.fromEnvironment('CASE') == ''
        ? Uri.base.queryParameters['case'] ?? ''
        : const String.fromEnvironment('CASE');
    for (final UseCase c in useCases) {
      if (c.id != id) continue;
      _tab = _Tab.cases;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(openUseCase(context, c));
      });
    }
  }

  void _open(HistoryItem item) => openResult(
    context,
    item,
    onMakeStyled: (String text) {
      Navigator.of(context).pop();
      createWithText.value = text;
      setState(() => _tab = _Tab.create);
    },
  );

  Widget _page(_Tab tab, {required bool wide}) => switch (tab) {
    _Tab.scan => ScanPage(bottomInset: wide ? 0 : 12),
    _Tab.create => CreatePage(wide: wide),
    _Tab.cases => const UseCasesPage(),
    _Tab.history => HistoryPage(onOpen: _open, builtWith: !wide),
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints c) {
      // Desktops keep the side menu down to small windows; phones and
      // browsers switch at tablet width.
      // A phone in landscape is under 900 wide (a Pixel 4a is 851) but has
      // no height for a bottom bar: it gets the side rail too.
      final bool wide =
          c.maxWidth >= (_desktop ? 640 : 900) ||
          (c.maxWidth > c.maxHeight && c.maxHeight < 500);
      // The pages stay alive: the generator keeps its form. The scanner of
      // a tab not shown (its tickers off) pauses and lets its camera go.
      final Widget pages = IndexedStack(
        // Kept when the layout changes (a phone turned): the scanner is moved,
        // not rebuilt, and keeps its camera.
        key: _pagesKey,
        index: _tab.index,
        children: <Widget>[
          for (final _Tab t in _Tab.values)
            TickerMode(
              enabled: t == _tab,
              child: _page(t, wide: wide),
            ),
        ],
      );
      if (wide) {
        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SideNav(
                compact: c.maxWidth < 1000,
                tab: _tab,
                onTab: (_Tab t) => setState(() => _tab = t),
              ),
              // The side menu takes the left inset (the Dynamic Island on a
              // phone in landscape).
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeLeft: true,
                  child: pages,
                ),
              ),
            ],
          ),
        );
      }
      return Scaffold(
        extendBody: true,
        body: pages,
        bottomNavigationBar: _TabBar(
          tab: _tab,
          overCamera: _tab == _Tab.scan,
          onTab: (_Tab t) => setState(() => _tab = t),
        ),
      );
    },
  );
}

const List<(_Tab, String, IconData)> _tabs = <(_Tab, String, IconData)>[
  (_Tab.scan, 'Scan', Icons.qr_code_scanner_rounded),
  (_Tab.create, 'Create', Icons.qr_code_2_rounded),
  (_Tab.cases, 'Use cases', Icons.apps_rounded),
  (_Tab.history, 'History', Icons.history_rounded),
];

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tab,
    required this.overCamera,
    required this.onTab,
  });

  final _Tab tab;
  final bool overCamera;
  final ValueChanged<_Tab> onTab;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final Widget bar = Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: <Widget>[
          for (final (_Tab t, String label, IconData icon) in _tabs)
            Expanded(
              child: Semantics(
                selected: t == tab,
                button: true,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onTab(t),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: t == tab ? fz.lockSoft : null,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: SizedBox(
                        height: 56,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              icon,
                              size: 24,
                              color: t == tab
                                  ? fz.lockInk
                                  : overCamera
                                  ? ScannerTheme.of(context).inkColor
                                  : fz.inkMuted,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: t == tab
                                    ? fz.lockInk
                                    : overCamera
                                    ? ScannerTheme.of(context).inkColor
                                    : fz.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        height: 68,
        child: overCamera
            ? ScannerGlass(strong: true, padding: EdgeInsets.zero, child: bar)
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: fz.raised,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: fz.line),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x1A0E1218),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: bar,
              ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.tab,
    required this.onTab,
    this.compact = false,
  });

  /// Icons only, for narrow windows.
  final bool compact;
  final _Tab tab;
  final ValueChanged<_Tab> onTab;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    Widget item(
      String label,
      IconData icon,
      bool selected,
      VoidCallback onTap,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: compact
          ? Tooltip(
              message: label,
              child: Semantics(
                label: label,
                selected: selected,
                button: true,
                excludeSemantics: true,
                child: Material(
                  color: selected ? fz.lockSoft : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onTap,
                    child: SizedBox(
                      height: 48,
                      child: Icon(
                        icon,
                        size: 24,
                        color: selected ? fz.lockInk : fz.ink,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Material(
              color: selected ? fz.lockSoft : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 14),
                      Icon(
                        icon,
                        size: 22,
                        color: selected ? fz.lockInk : fz.ink,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: selected ? fz.lockInk : fz.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
    final EdgeInsets safe = MediaQuery.viewPaddingOf(context);
    return Container(
      width: (compact ? 76 : 240) + safe.left,
      padding: EdgeInsets.fromLTRB(
        (compact ? 12 : 16) + safe.left,
        math.max(28, safe.top + 12),
        compact ? 12 : 16,
        math.max(20, safe.bottom + 8),
      ),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: fz.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // The icon-only rail (a phone in landscape) keeps its buttons in the
        // middle, under the thumb.
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: <Widget>[
          if (!compact) ...<Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'flutter_zxing',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 28),
          ],
          // Reading a photo is the scanner's own button.
          for (final (_Tab t, String label, IconData icon) in _tabs)
            item(label, icon, t == tab, () => onTab(t)),
          if (!compact) ...<Widget>[
            const Spacer(),
            const BuiltWithCard(),
            const SizedBox(height: 10),
            FzCard(
              radius: 18,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    kIsWeb ? 'Running in the browser' : 'Runs on this device',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kIsWeb
                        ? 'zxing-cpp as WebAssembly, in a worker. Nothing leaves this page.'
                        : 'zxing-cpp $zxingCppVersion, off the UI thread. Nothing leaves the device.',
                    style: TextStyle(fontSize: 12, color: fz.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Whether the app runs as a desktop app (not in a browser).
bool get _desktop =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
