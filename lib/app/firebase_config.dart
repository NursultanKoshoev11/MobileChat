import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// iOS Firebase options supplied at build time with `--dart-define`, so the
/// generated iOS project does not need a GoogleService-Info.plist resource.
/// Android keeps using android/app/google-services.json.
const String _iosApiKey = String.fromEnvironment('IOS_FIREBASE_API_KEY');
const String _iosAppId = String.fromEnvironment('IOS_FIREBASE_APP_ID');
const String _senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
const String _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const String _iosBundleId = String.fromEnvironment('IOS_BUNDLE_ID');

/// Returns explicit options when running on iOS with a complete build-time
/// configuration, otherwise null (use the platform's native config file).
FirebaseOptions? firebaseOptionsForCurrentPlatform({
  TargetPlatform? platform,
  Map<String, String>? values,
}) {
  final target = platform ?? defaultTargetPlatform;
  if (kIsWeb || target != TargetPlatform.iOS) {
    return null;
  }
  final v = values ??
      const {
        'apiKey': _iosApiKey,
        'appId': _iosAppId,
        'senderId': _senderId,
        'projectId': _projectId,
        'bundleId': _iosBundleId,
      };
  final apiKey = v['apiKey'] ?? '';
  final appId = v['appId'] ?? '';
  final senderId = v['senderId'] ?? '';
  final projectId = v['projectId'] ?? '';
  if (apiKey.isEmpty || appId.isEmpty || senderId.isEmpty || projectId.isEmpty) {
    return null;
  }
  final bundleId = v['bundleId'] ?? '';
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    iosBundleId: bundleId.isEmpty ? null : bundleId,
  );
}

Future<void> initializeFirebaseApp() async {
  final options = firebaseOptionsForCurrentPlatform();
  if (options != null) {
    await Firebase.initializeApp(options: options);
  } else {
    await Firebase.initializeApp();
  }
}
