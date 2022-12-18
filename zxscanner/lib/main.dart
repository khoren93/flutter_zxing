import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'configs/app_store.dart';
import 'configs/app_theme.dart';
import 'configs/constants.dart';
import 'generated/l10n.dart' as loc;
import 'utils/db_service.dart';
import 'utils/extensions.dart';
import 'utils/router.dart';
import 'utils/scroll_behavior.dart';
import 'utils/shared_pref.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializePrefs();
  await DbService.instance.initializeApp();
  zx.setLogEnabled(kDebugMode);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppRouter _appRouter = AppRouter();

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => MaterialApp(
        title: appName,
        theme: AppTheme.flexLightTheme(),
        darkTheme: AppTheme.flexDarkTheme(),
        themeMode: appStore.themeMode,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          loc.S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: loc.S.delegate.supportedLocales,
        locale: appStore.selectedLanguage.parseLocale(),
        onGenerateRoute: _appRouter.onGenerateRoute,
        scrollBehavior: MyCustomScrollBehavior(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
