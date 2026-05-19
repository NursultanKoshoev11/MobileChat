import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/api_client.dart';

class PushNotificationService {
  PushNotificationService({required this.api});

  final ApiClient api;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _tokenRefreshListenerStarted = false;
  bool _foregroundListenerStarted = false;
  bool _localNotificationsInitialized = false;

  Future<void> registerDevice() async {
    try {
      final messaging = _messagingOrNull();
      if (messaging == null) return;

      await _initLocalNotifications();
      await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        _debugLog('FCM token is empty.');
        return;
      }
      _debugLog('FCM token received: ${token.substring(0, min(24, token.length))}...');
      await api.registerPushToken(token: token, platform: _platformName());

      if (!_tokenRefreshListenerStarted) {
        _tokenRefreshListenerStarted = true;
        messaging.onTokenRefresh.listen((newToken) async {
          if (newToken.isEmpty) return;
          try {
            await api.registerPushToken(token: newToken, platform: _platformName());
          } catch (error) {
            _debugLog('FCM token refresh registration failed: $error');
          }
        });
      }

      if (!_foregroundListenerStarted) {
        _foregroundListenerStarted = true;
        FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      }
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

  Future<void> _initLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initializationSettings);

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'koom_default',
        'Koom notifications',
        description: 'Notifications about new posts and comments in Koom.',
        importance: Importance.high,
      );
      await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
      await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }

    _localNotificationsInitialized = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'] ?? 'Коом';
    final body = message.notification?.body ?? message.data['body'] ?? 'Откройте приложение, чтобы посмотреть обновление.';
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'koom_default',
        'Koom notifications',
        channelDescription: 'Notifications about new posts and comments in Koom.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _localNotifications.show(message.hashCode, title, body, details, payload: message.data.toString());
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
