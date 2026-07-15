import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/app/appearance.dart';
import 'package:mobile_chat/app/localization.dart';
import 'package:mobile_chat/app/preferences_store.dart';

class _MemoryPreferencesStore extends AppPreferencesStore {
  _MemoryPreferencesStore({this.languageValue, this.themeValue});

  String? languageValue;
  String? themeValue;

  @override
  Future<String?> readLanguage() async => languageValue;

  @override
  Future<void> writeLanguage(String value) async {
    languageValue = value;
  }

  @override
  Future<String?> readThemeMode() async => themeValue;

  @override
  Future<void> writeThemeMode(String value) async {
    themeValue = value;
  }
}

void main() {
  test('language and theme restore from persistent storage', () async {
    final store = _MemoryPreferencesStore(
      languageValue: AppLanguage.ky.name,
      themeValue: ThemeMode.dark.name,
    );
    final language = AppLanguageController(store: store);
    final appearance = AppAppearanceController(store: store);

    await Future.wait([language.restore(), appearance.restore()]);

    expect(language.language, AppLanguage.ky);
    expect(appearance.themeMode, ThemeMode.dark);
  });

  test('language and theme changes are persisted', () async {
    final store = _MemoryPreferencesStore();
    final language = AppLanguageController(store: store);
    final appearance = AppAppearanceController(store: store);

    language.setLanguage(AppLanguage.ky);
    appearance.setThemeMode(ThemeMode.dark);
    await Future<void>.delayed(Duration.zero);

    expect(store.languageValue, AppLanguage.ky.name);
    expect(store.themeValue, ThemeMode.dark.name);
  });

  test('invalid stored values keep safe defaults', () async {
    final store = _MemoryPreferencesStore(
      languageValue: 'unknown',
      themeValue: 'unknown',
    );
    final language = AppLanguageController(store: store);
    final appearance = AppAppearanceController(store: store);

    await Future.wait([language.restore(), appearance.restore()]);

    expect(language.language, AppLanguage.ru);
    expect(appearance.themeMode, ThemeMode.light);
  });
}
