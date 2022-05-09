import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_zxing_example/utils/db_service.dart';
import 'package:flutter_zxing_example/utils/extensions.dart';
import 'package:nb_utils/nb_utils.dart';

import 'configs/app_store.dart';
import 'configs/app_theme.dart';
import 'generated/l10n.dart' as loc;
import 'utils/router.dart';
import 'utils/scroll_behavior.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeAppStore();
  await DbService.instance.initializeApp();
  runApp(const MyApp());
}

_initializeAppStore() async {
  await initialize();
  final themeModeString = getStringAsync(
    themeModePref,
    defaultValue: appStore.themeMode.toString(),
  );
  await appStore.setThemeMode(
    ThemeMode.values
        .firstWhere((element) => element.toString() == themeModeString),
  );
  await appStore.setColorSchemeIndex(
    getIntAsync(colorSchemeIndexPref, defaultValue: appStore.colorSchemeIndex),
  );
  await appStore.toggleSoundMode(
    value: getBoolAsync(isSoundOnPref, defaultValue: appStore.isSoundOn),
  );
  await appStore.toggleVibrationMode(
    value:
        getBoolAsync(isVibrationOnPref, defaultValue: appStore.isVibrationOn),
  );
  await appStore.setLanguage(
    getStringAsync(languagePref, defaultValue: appStore.selectedLanguage),
  );
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
        title: 'ZxScanner',
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
