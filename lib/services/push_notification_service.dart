import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../data/api_client.dart';

class PushNotificationService {
  PushNotificationService({required this.api});

  final ApiClient api;
  bool _tokenRefreshListenerStarted = false;

  Future<void> registerDevice() async {
    try {
      final messaging = _messagingOrNull();
      if (messaging == null) return;

      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      await api.registerPushToken(token: token, platform: _platformName());

      if (_tokenRefreshListenerStarted) return;
      _tokenRefreshListenerStarted = true;
      messaging.onTokenRefresh.listen((newToken) async {
        if (newToken.isEmpty) return;
        try {
          await api.registerPushToken(token: newToken, platform: _platformName());
        } catch (error) {
          _debugLog('FCM token refresh registration failed: $error');
        }
      });
    } catch (error) {
      _debugLog('FCM registration skipped: $error');
    }
  }

  Future<void> unregisterDevice() async {
    try {
      final messaging = _messagingOrNull();
      if (messaging == null) return;

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await api.deletePushToken(token: token, platform: _platformName());
    } catch (error) {
      _debugLog('FCM token cleanup skipped: $error');
    }
  }

  FirebaseMessaging? _messagingOrNull() {
    try {
      if (Firebase.apps.isEmpty) {
        _debugLog('FCM skipped: Firebase is not initialized.');
        return null;
      }
      return FirebaseMessaging.instance;
    } catch (error) {
      _debugLog('FCM skipped: $error');
      return null;
    }
  }

  String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  void _debugLog(String message) {
    if (kDebugMode) debugPrint(message);
  }
}
