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


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseInitialization = _initializeFirebase();
  runApp(KoomApp(firebaseInitialization: firebaseInitialization));
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (error) {
    debugPrint(
      'Firebase initialization skipped; starting Koom without push notifications: $error',
    );
  }
}
