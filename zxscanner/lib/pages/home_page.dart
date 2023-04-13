import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'barcodes_page.dart';
import 'help_page.dart';
import 'history_page.dart';
import 'scanner_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 2;

  final BarcodesPage barcodesPage = const BarcodesPage();
  final HistoryPage historyPage = const HistoryPage();
  final ScannerPage scannerPage = const ScannerPage();
  final HelpPage helpPage = const HelpPage();
  final SettingsPage settingsPage = const SettingsPage();

  dynamic pages() => <dynamic>[
        barcodesPage,
        historyPage,
        scannerPage,
        helpPage,
        settingsPage,
      ];

  dynamic tabItems() => <TabItem<IconData>>[
        const TabItem<IconData>(icon: FontAwesomeIcons.barcode),
        const TabItem<IconData>(icon: FontAwesomeIcons.clockRotateLeft),
        const TabItem<IconData>(icon: Icons.qr_code_scanner),
        const TabItem<IconData>(icon: FontAwesomeIcons.circleQuestion),
        const TabItem<IconData>(icon: FontAwesomeIcons.gear),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ignore: avoid_dynamic_calls
      body: pages()[selectedIndex],
      bottomNavigationBar: ConvexAppBar(
        disableDefaultTabController: true,
        style: TabStyle.fixedCircle,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        color: Theme.of(context).unselectedWidgetColor,
        activeColor: Theme.of(context).colorScheme.primary,
        items: tabItems(),
        initialActiveIndex: selectedIndex,
        onTap: (int index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
    );
  }
}
