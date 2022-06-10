import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:zxscanner/configs/constants.dart';
import 'package:zxscanner/utils/db_service.dart';
import 'package:zxscanner/utils/extensions.dart';
import 'package:zxscanner/utils/shared_pref.dart';

import 'configs/app_store.dart';
import 'configs/app_theme.dart';
import 'generated/l10n.dart' as loc;
import 'utils/router.dart';
import 'utils/scroll_behavior.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializePrefs();
  await DbService.instance.initializeApp();
  setZxingLogEnabled(kDebugMode);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appRouter = AppRouter();

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => MaterialApp(
        title: appName,
        theme: AppTheme.flexLightTheme(),
        darkTheme: AppTheme.flexDarkTheme(),
        themeMode: appStore.themeMode,
        localizationsDelegates: const [
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
