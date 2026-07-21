import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/api_client.dart';

class PushNotificationService {
  PushNotificationService({required this.api});

  static final StreamController<Map<String, String>>
      _foregroundDataController =
      StreamController<Map<String, String>>.broadcast();
  static final StreamController<Map<String, String>> _openedDataController =
      StreamController<Map<String, String>>.broadcast();
  static Map<String, String>? _pendingOpenedData;

  static Stream<Map<String, String>> get foregroundDataStream =>
      _foregroundDataController.stream;
  static Stream<Map<String, String>> get openedDataStream =>
      _openedDataController.stream;

  static Map<String, String>? takePendingOpenedData() {
    final pending = _pendingOpenedData;
    _pendingOpenedData = null;
    return pending;
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    // Android/iOS already display notification messages in the background.
    // Only data-only messages need an additional local notification.
    if (message.notification != null) return;
    await _showLocalNotificationFromMessage(message);
  }

  final ApiClient api;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _tokenRefreshListenerStarted = false;
  bool _foregroundListenerStarted = false;
  bool _localNotificationsInitialized = false;

  Future<void> registerDevice() async {
    try {
      final messaging = _messagingOrNull();
      if (messaging == null) return;

      await _initLocalNotifications();
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        _debugLog('FCM token is empty.');
        return;
      }
      _debugLog('FCM token received.');
      await api.registerPushToken(token: token, platform: _platformName());

      if (!_tokenRefreshListenerStarted) {
        _tokenRefreshListenerStarted = true;
        messaging.onTokenRefresh.listen((newToken) async {
          if (newToken.isEmpty) return;
          try {
            await api.registerPushToken(
              token: newToken,
              platform: _platformName(),
            );
          } catch (error) {
            _debugLog('FCM token refresh registration failed: $error');
          }
        });
      }

      if (!_foregroundListenerStarted) {
        _foregroundListenerStarted = true;
        FirebaseMessaging.onMessage.listen(_showForegroundNotification);
        FirebaseMessaging.onMessageOpenedApp.listen(_emitOpenedMessage);
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) _emitOpenedMessage(initialMessage);
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

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings =
        InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'koom_default',
        'Koom notifications',
        description: 'Notifications about new posts and comments in Koom.',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _localNotificationsInitialized = true;

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails?.notificationResponse;
      if (response != null) _handleLocalNotificationResponse(response);
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (message.data.isNotEmpty && !_foregroundDataController.isClosed) {
      _foregroundDataController.add(Map<String, String>.from(message.data));
    }
    if (Platform.isIOS && message.notification != null) return;
    await _showLocalNotificationFromMessage(message);
  }

  static void _emitOpenedMessage(RemoteMessage message) {
    if (message.data.isEmpty || _openedDataController.isClosed) return;
    _emitOpenedData(Map<String, String>.from(message.data));
  }

  static void _emitOpenedData(Map<String, String> rawData) {
    final data = _normalizeOpenedData(rawData);
    if (_openedDataController.hasListener) {
      _openedDataController.add(data);
    } else {
      _pendingOpenedData = data;
    }
  }

  static Map<String, String> _normalizeOpenedData(
    Map<String, String> rawData,
  ) {
    final data = Map<String, String>.from(rawData);
    final type = data['type']?.trim() ?? '';

    final requestId = _firstNonEmpty([
      data['request_id'],
      data['public_request_id'],
      data['post_id'],
      data['publication_id'],
    ]);
    if (requestId != null) data['request_id'] = requestId;

    final isCommentNotification =
        type == 'public_request.comment_created' ||
        type == 'comment.created' ||
        type == 'public_request.comment' ||
        type.contains('comment_created');

    if (isCommentNotification && requestId != null) {
      // GroupsScreen already knows how to open a specific publication for this
      // event type. Reuse that route so a comment notification opens the
      // comments of the correct publication, not a different item.
      data['type'] = 'public_request.created';
      data['opened_from_comment_notification'] = 'true';
    } else if (type == 'public_request.created') {
      // A new-publication notification should open the publication list. It
      // must not automatically enter a publication that has no comments.
      data['type'] = 'public_request.open_list';
      data.remove('request_id');
    }

    return data;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) return normalized;
    }
    return null;
  }

  static void _handleLocalNotificationResponse(
    NotificationResponse response,
  ) {
    final payload = response.payload?.trim() ?? '';
    if (payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final data = <String, String>{};
      for (final entry in decoded.entries) {
        data[entry.key.toString()] = entry.value.toString();
      }
      _emitOpenedData(data);
    } catch (_) {}
  }

  static Future<void> _showLocalNotificationFromMessage(
    RemoteMessage message,
  ) async {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings =
        InitializationSettings(android: androidSettings);
    await plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'koom_default',
        'Koom notifications',
        description: 'Notifications about new posts and comments in Koom.',
        importance: Importance.high,
      );
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    final title =
        message.notification?.title ?? message.data['title'] ?? 'Коом';
    final body = message.notification?.body ??
        message.data['body'] ??
        'Откройте приложение, чтобы посмотреть обновление.';
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'koom_default',
        'Koom notifications',
        channelDescription:
            'Notifications about new posts and comments in Koom.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await plugin.show(
      message.hashCode,
      title,
      body,
      details,
      payload: jsonEncode(message.data),
    );
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
