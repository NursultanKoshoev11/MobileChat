import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../data/api_client.dart';

class PushNotificationService {
  PushNotificationService({required this.api});

  final ApiClient api;
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  Future<void> registerDevice() async {
    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await api.registerPushToken(token: token, platform: _platformName());
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        if (newToken.isEmpty) return;
        await api.registerPushToken(token: newToken, platform: _platformName());
      });
    } catch (_) {
      // Push notifications are best-effort. The app must keep working if FCM is not configured yet.
    }
  }

  String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }
}
