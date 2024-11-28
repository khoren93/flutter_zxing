import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'app_store.dart';

class AppTheme {
  AppTheme._();

  static ThemeData flexLightTheme() => FlexThemeData.light(
        colors: FlexColor.schemesList[appStore.colorSchemeIndex].light,
        surfaceMode: FlexSurfaceMode.highScaffoldLevelSurface,
        blendLevel: 12,
        useMaterial3ErrorColors: true,
      );

  static ThemeData flexDarkTheme() => FlexThemeData.dark(
        colors: FlexColor.schemesList[appStore.colorSchemeIndex].dark,
        surfaceMode: FlexSurfaceMode.highScaffoldLevelSurface,
        blendLevel: 6,
        useMaterial3ErrorColors: true,
      );
}
