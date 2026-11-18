import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppPreferencesStore {
  const AppPreferencesStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _languageKey = 'koom_preferred_language_v1';
  static const _themeKey = 'koom_preferred_theme_v1';
  static const _displayScaleKey = 'koom_display_scale_v1';
  static const _termsAcceptedKey = 'koom_terms_accepted_v1';
  static const _androidOptions =
      AndroidOptions(encryptedSharedPreferences: true);

  final FlutterSecureStorage _storage;

  Future<String?> readLanguage() =>
      _storage.read(key: _languageKey, aOptions: _androidOptions);

  Future<void> writeLanguage(String value) =>
      _storage.write(key: _languageKey, value: value, aOptions: _androidOptions);

  Future<String?> readThemeMode() =>
      _storage.read(key: _themeKey, aOptions: _androidOptions);

  Future<void> writeThemeMode(String value) =>
      _storage.write(key: _themeKey, value: value, aOptions: _androidOptions);

  Future<String?> readDisplayScale() =>
      _storage.read(key: _displayScaleKey, aOptions: _androidOptions);

  Future<void> writeDisplayScale(String value) =>
      _storage.write(
        key: _displayScaleKey,
        value: value,
        aOptions: _androidOptions,
      );

  /// ISO-8601 timestamp of when the user accepted the Terms of Use and
  /// Privacy Policy on this device, or null.
  Future<String?> readTermsAcceptedAt() =>
      _storage.read(key: _termsAcceptedKey, aOptions: _androidOptions);

  Future<void> writeTermsAcceptedAt(String value) => _storage.write(
        key: _termsAcceptedKey,
        value: value,
        aOptions: _androidOptions,
      );
}
