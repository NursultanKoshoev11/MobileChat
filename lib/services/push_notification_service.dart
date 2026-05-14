import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../data/api_client.dart';

class PushNotificationService {
  PushNotificationService({required this.api});

  final ApiClient api;
  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  bool _tokenRefreshListenerStarted = false;

  Future<void> registerDevice() async {
    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await api.registerPushToken(token: token, platform: _platformName());
      if (_tokenRefreshListenerStarted) return;
      _tokenRefreshListenerStarted = true;
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
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
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await api.deletePushToken(token: token, platform: _platformName());
    } catch (error) {
      _debugLog('FCM token cleanup skipped: $error');
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
