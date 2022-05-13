import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:zxscanner/pages/barcodes_page.dart';
import 'package:zxscanner/pages/help_page.dart';
import 'package:zxscanner/pages/history_page.dart';
import 'package:zxscanner/pages/scanner_page.dart';
import 'package:zxscanner/pages/settings_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var selectedIndex = 2;

  final barcodesPage = const BarcodesPage();
  final historyPage = const HistoryPage();
  final scannerPage = const ScannerPage();
  final helpPage = const HelpPage();
  final settingsPage = const SettingsPage();

  dynamic pages() => [
        barcodesPage,
        historyPage,
        scannerPage,
        helpPage,
        settingsPage,
      ];

  dynamic tabItems() => [
        const TabItem(icon: FontAwesomeIcons.barcode),
        const TabItem(icon: FontAwesomeIcons.clockRotateLeft),
        const TabItem(icon: Icons.qr_code_scanner),
        const TabItem(icon: FontAwesomeIcons.circleQuestion),
        const TabItem(icon: FontAwesomeIcons.gear),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages()[selectedIndex],
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.fixedCircle,
        backgroundColor: Theme.of(context).bottomAppBarColor,
        color: Theme.of(context).unselectedWidgetColor,
        activeColor: Theme.of(context).colorScheme.primary,
        items: tabItems(),
        initialActiveIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
    );
  }
}
