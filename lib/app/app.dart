import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../data/session_store.dart';
import '../features/auth/phone_auth_screen.dart';
import '../features/groups/groups_screen.dart';
import '../services/push_notification_service.dart';
import 'appearance.dart';
import 'localization.dart';
import 'theme.dart';

class MobileChatApp extends StatefulWidget {
  const MobileChatApp({super.key});

  @override
  State<MobileChatApp> createState() => _MobileChatAppState();
}

class _MobileChatAppState extends State<MobileChatApp> {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://16.171.199.28',
  );

  final SessionStore sessionStore = const SessionStore();
  final AppLanguageController languageController = AppLanguageController();
  final AppAppearanceController appearanceController = AppAppearanceController();
  late final ApiClient api = ApiClient(baseUrl: apiBaseUrl, sessionStore: sessionStore);
  late final PushNotificationService pushNotifications = PushNotificationService(api: api);
  late Future<AppSession?> bootFuture;

  @override
  void initState() {
    super.initState();
    bootFuture = _boot();
  }

  @override
  void dispose() {
    languageController.dispose();
    appearanceController.dispose();
    super.dispose();
  }

  Future<AppSession?> _boot() async {
    final session = await sessionStore.read();
    if (session != null) {
      await pushNotifications.registerDevice();
    }
    return session;
  }

  Future<void> setSession(AppSession session) async {
    await sessionStore.save(session);
    await pushNotifications.registerDevice();
    if (!mounted) return;
    setState(() {
      bootFuture = Future.value(session);
    });
  }

  Future<void> logout() async {
    await pushNotifications.unregisterDevice();
    await sessionStore.clear();
    if (!mounted) return;
    setState(() {
      bootFuture = Future.value(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppLanguageScope(
      controller: languageController,
      child: AppAppearanceScope(
        controller: appearanceController,
        child: AnimatedBuilder(
          animation: Listenable.merge([languageController, appearanceController]),
          builder: (context, _) {
            final text = languageController.text;
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: text.appTitle,
              theme: MobileChatTheme.light,
              darkTheme: MobileChatTheme.dark,
              themeMode: appearanceController.themeMode,
              home: FutureBuilder<AppSession?>(
                future: bootFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  final session = snapshot.data;
                  if (session == null) {
                    return PhoneAuthScreen(api: api, onAuthenticated: setSession);
                  }
                  return GroupsScreen(api: api, session: session, onLogout: logout);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
