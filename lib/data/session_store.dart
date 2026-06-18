import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

class SessionStore {
  const SessionStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'mobilechat_session_v2';
  static const _androidOptions =
      AndroidOptions(encryptedSharedPreferences: true);

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
    final value = jsonEncode(session.toJson());
    await _storage.write(key: _key, value: value, aOptions: _androidOptions);
    await _storage.write(key: _key, value: value);
  }

  Future<void> clear() async {
    await _storage.delete(key: _key, aOptions: _androidOptions);
    await _storage.delete(key: _key);
  }

  Future<String?> _readRaw() async {
    final secure = await _storage.read(key: _key, aOptions: _androidOptions);
    if (secure != null && secure.isNotEmpty) return secure;

    final legacy = await _storage.read(key: _key);
    if (legacy != null && legacy.isNotEmpty) {
      await _storage.write(key: _key, value: legacy, aOptions: _androidOptions);
      return legacy;
    }
    return null;
  }
}
