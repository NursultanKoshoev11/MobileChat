import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

class SessionStore {
  const SessionStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'koom_session_v2';
  static const _androidOptions =
      AndroidOptions(encryptedSharedPreferences: true);
  // Tokens stay readable for background push handling after the first unlock,
  // but are never migrated to another device via backups.
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  static const _installMarkerName = '.koom_install_marker';

  static Future<void>? _installCheck;

  Future<AppSession?> read() async {
    final raw = await _readRaw();
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(AppSession session) async {
    await _ensureInstallChecked();
    final value = jsonEncode(session.toJson());
    await _storage.write(
      key: _key,
      value: value,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  Future<void> clear() async {
    await _storage.delete(
      key: _key,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  Future<String?> _readRaw() async {
    await _ensureInstallChecked();
    final secure = await _storage.read(
      key: _key,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    if (secure != null && secure.isNotEmpty) return secure;

    return null;
  }

  /// iOS keeps keychain items after the app is deleted, so a reinstall would
  /// silently sign the previous user back in. The app-container marker file is
  /// removed on uninstall; when it is missing we wipe the stale session once.
  /// Android removes secure storage with the app, so its behavior is unchanged.
  static Future<void> _ensureInstallChecked() {
    if (kIsWeb || !Platform.isIOS) return Future.value();
    return _installCheck ??= _wipeStaleSessionOnFreshInstall();
  }

  static Future<void> _wipeStaleSessionOnFreshInstall() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final marker = File('${dir.path}/$_installMarkerName');
      if (await marker.exists()) return;
      // Deletes the item regardless of the accessibility it was stored with.
      await _storage.delete(key: _key, iOptions: _iosOptions);
      await dir.create(recursive: true);
      await marker.writeAsString(DateTime.now().toUtc().toIso8601String());
    } catch (error) {
      if (kDebugMode) debugPrint('Install marker check failed: $error');
    }
  }
}
