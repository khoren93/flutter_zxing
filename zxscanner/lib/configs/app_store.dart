import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:zxscanner/utils/shared_pref.dart';

part 'app_store.g.dart';

AppStore appStore = AppStore();

class AppStore = AppStoreBase with _$AppStore;

const themeModePref = 'themeModePref';
const colorSchemeIndexPref = 'colorSchemeIndexPref';
const isSoundOnPref = 'isSoundOnPref';
const isVibrationOnPref = 'isVibrationOnPref';
const languagePref = 'languagePref';

abstract class AppStoreBase with Store {
  @observable
  ThemeMode themeMode = ThemeMode.system;

  @observable
  int colorSchemeIndex = 4;

  @observable
  bool isSoundOn = true;

  @observable
  bool isVibrationOn = true;

  @observable
  String selectedLanguage = 'en_US';

  @action
  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    setPrefValue(themeModePref, themeMode.toString());
  }

  @action
  Future<void> setColorSchemeIndex(int value) async {
    colorSchemeIndex = value;
    await setPrefValue(colorSchemeIndexPref, colorSchemeIndex);
  }

  @action
  Future<void> toggleSoundMode({bool? value}) async {
    isSoundOn = value ?? !isSoundOn;
    setPrefValue(isSoundOnPref, isSoundOn);
  }

  @action
  Future<void> toggleVibrationMode({bool? value}) async {
    isVibrationOn = value ?? !isVibrationOn;
    setPrefValue(isVibrationOnPref, isVibrationOn);
  }

  @action
  Future<void> setLanguage(String aLanguage) async {
    selectedLanguage = aLanguage;
    await setPrefValue(languagePref, aLanguage);
  }
}
