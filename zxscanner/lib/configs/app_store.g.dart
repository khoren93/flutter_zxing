// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic

mixin _$AppStore on AppStoreBase, Store {
  final Atom _$themeModeAtom = Atom(name: 'AppStoreBase.themeMode');

  @override
  ThemeMode get themeMode {
    _$themeModeAtom.reportRead();
    return super.themeMode;
  }

  @override
  set themeMode(ThemeMode value) {
    _$themeModeAtom.reportWrite(value, super.themeMode, () {
      super.themeMode = value;
    });
  }

  final Atom _$colorSchemeIndexAtom =
      Atom(name: 'AppStoreBase.colorSchemeIndex');

  @override
  int get colorSchemeIndex {
    _$colorSchemeIndexAtom.reportRead();
    return super.colorSchemeIndex;
  }

  @override
  set colorSchemeIndex(int value) {
    _$colorSchemeIndexAtom.reportWrite(value, super.colorSchemeIndex, () {
      super.colorSchemeIndex = value;
    });
  }

  final Atom _$isSoundOnAtom = Atom(name: 'AppStoreBase.isSoundOn');

  @override
  bool get isSoundOn {
    _$isSoundOnAtom.reportRead();
    return super.isSoundOn;
  }

  @override
  set isSoundOn(bool value) {
    _$isSoundOnAtom.reportWrite(value, super.isSoundOn, () {
      super.isSoundOn = value;
    });
  }

  final Atom _$isVibrationOnAtom = Atom(name: 'AppStoreBase.isVibrationOn');

  @override
  bool get isVibrationOn {
    _$isVibrationOnAtom.reportRead();
    return super.isVibrationOn;
  }

  @override
  set isVibrationOn(bool value) {
    _$isVibrationOnAtom.reportWrite(value, super.isVibrationOn, () {
      super.isVibrationOn = value;
    });
  }

  final Atom _$selectedLanguageAtom =
      Atom(name: 'AppStoreBase.selectedLanguage');

  @override
  String get selectedLanguage {
    _$selectedLanguageAtom.reportRead();
    return super.selectedLanguage;
  }

  @override
  set selectedLanguage(String value) {
    _$selectedLanguageAtom.reportWrite(value, super.selectedLanguage, () {
      super.selectedLanguage = value;
    });
  }

  final AsyncAction _$setThemeModeAsyncAction =
      AsyncAction('AppStoreBase.setThemeMode');

  @override
  Future<void> setThemeMode(ThemeMode value) {
    return _$setThemeModeAsyncAction.run(() => super.setThemeMode(value));
  }

  final AsyncAction _$setColorSchemeIndexAsyncAction =
      AsyncAction('AppStoreBase.setColorSchemeIndex');

  @override
  Future<void> setColorSchemeIndex(int value) {
    return _$setColorSchemeIndexAsyncAction
        .run(() => super.setColorSchemeIndex(value));
  }

  final AsyncAction _$toggleSoundModeAsyncAction =
      AsyncAction('AppStoreBase.toggleSoundMode');

  @override
  Future<void> toggleSoundMode({bool? value}) {
    return _$toggleSoundModeAsyncAction
        .run(() => super.toggleSoundMode(value: value));
  }

  final AsyncAction _$toggleVibrationModeAsyncAction =
      AsyncAction('AppStoreBase.toggleVibrationMode');

  @override
  Future<void> toggleVibrationMode({bool? value}) {
    return _$toggleVibrationModeAsyncAction
        .run(() => super.toggleVibrationMode(value: value));
  }

  final AsyncAction _$setLanguageAsyncAction =
      AsyncAction('AppStoreBase.setLanguage');

  @override
  Future<void> setLanguage(String aLanguage) {
    return _$setLanguageAsyncAction.run(() => super.setLanguage(aLanguage));
  }

  @override
  String toString() {
    return '''
themeMode: ${themeMode},
colorSchemeIndex: ${colorSchemeIndex},
isSoundOn: ${isSoundOn},
isVibrationOn: ${isVibrationOn},
selectedLanguage: ${selectedLanguage}
    ''';
  }
}
