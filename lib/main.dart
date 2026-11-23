import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/crash_reporting.dart';
import 'app/firebase_config.dart';
import 'services/push_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await initializeFirebaseApp();
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
      await initializeFirebaseApp();
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
  final firebaseReady = await initializeFirebaseSafely();
  // FlutterError.onError + PlatformDispatcher.onError cover framework and
  // uncaught async errors, so no runZonedGuarded is needed.
  try {
    await CrashReporting.install(firebaseReady: firebaseReady);
  } catch (_) {}
  runApp(const KoomApp());
}
