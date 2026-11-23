import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Sends uncaught Flutter/Dart errors to Firebase Crashlytics.
///
/// Safe to call when Firebase is not initialized (e.g. iOS builds without
/// Firebase secrets): errors are then only printed in debug builds and the
/// app keeps running. Collection is disabled in debug builds.
class CrashReporting {
  CrashReporting._();

  static FirebaseCrashlytics? _crashlytics;

  /// Whether reports are currently being sent to Crashlytics.
  static bool get isEnabled => _crashlytics != null;

  /// Installs the global error handlers. [firebaseReady] tells whether
  /// `Firebase.initializeApp` succeeded.
  static Future<void> install({required bool firebaseReady}) async {
    _crashlytics = null;
    if (firebaseReady) {
      try {
        if (Firebase.apps.isNotEmpty) {
          final crashlytics = FirebaseCrashlytics.instance;
          await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
          if (!kDebugMode) _crashlytics = crashlytics;
        }
      } catch (error) {
        if (kDebugMode) debugPrint('Crashlytics unavailable: $error');
      }
    }

    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final crashlytics = _crashlytics;
      if (crashlytics != null) {
        unawaited(
          crashlytics.recordFlutterFatalError(details).catchError((_) {}),
        );
      }
      if (previousFlutterOnError != null) {
        previousFlutterOnError(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, fatal: true);
      // Returning true marks the error as handled so the engine does not
      // additionally print/terminate; in debug keep the default behaviour.
      return !kDebugMode;
    };
  }

  /// Records an error caught by a zone or explicitly by the app.
  static void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    final crashlytics = _crashlytics;
    if (crashlytics == null) {
      if (kDebugMode) debugPrint('Uncaught error: $error\n$stack');
      return;
    }
    unawaited(
      crashlytics
          .recordError(error, stack, fatal: fatal)
          .catchError((_) {}),
    );
  }
}
