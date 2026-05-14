import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (error) {
    if (kDebugMode) {
      debugPrint('Firebase initialization skipped: $error');
    }
  }
  runApp(const MobileChatApp());
}
