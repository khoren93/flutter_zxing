import 'package:flutter/material.dart';
import 'package:flutter_zxing_example/pages/creator_page.dart';
import 'package:flutter_zxing_example/pages/history_page.dart';
import 'package:flutter_zxing_example/pages/home_page.dart';
import 'package:flutter_zxing_example/pages/scanner_page.dart';
import 'package:flutter_zxing_example/pages/settings_page.dart';

abstract class AppRoutes {
  static const creator = '/creator';
  static const history = '/history';
  static const home = '/';
  static const scanner = '/scanner';
  static const settings = '/settings';
}

class AppRouter {
  Route onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.creator:
        return MaterialPageRoute(
          builder: (_) => const CreatorPage(),
        );
      case AppRoutes.history:
        return MaterialPageRoute(
          builder: (_) => const HistoryPage(),
        );
      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => const HomePage(),
        );
      case AppRoutes.scanner:
        return MaterialPageRoute(
          builder: (_) => const ScannerPage(),
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsPage(),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Container(),
        );
    }
  }
}
