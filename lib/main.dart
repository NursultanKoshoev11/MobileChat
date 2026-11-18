import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/push_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  await PushNotificationService.handleBackgroundMessage(message);
}

/// Initializes Firebase without ever crashing the app. When the platform has no
/// Firebase configuration (e.g. iOS without GoogleService-Info.plist) the app
/// runs with push notifications disabled; PushNotificationService no-ops when
/// `Firebase.apps` is empty.
Future<bool> initializeFirebaseSafely({
  Future<void> Function()? initialize,
}) async {
  try {
    if (initialize != null) {
      await initialize();
    } else {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
    return true;
  } catch (error) {
    if (kDebugMode) {
      debugPrint('Firebase unavailable, push disabled: $error');
    }
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebaseSafely();
  runApp(const KoomApp());
}
