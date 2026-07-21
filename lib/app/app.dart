import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../data/session_store.dart';
import '../features/auth/phone_auth_screen.dart';
import '../features/groups/groups_screen.dart';
import '../services/push_notification_service.dart';
import '../shared/koom_ui.dart';
import 'appearance.dart';
import 'localization.dart';
import 'preferences_store.dart';
import 'theme.dart';

class MobileChatApp extends StatefulWidget {
  const MobileChatApp({super.key});

  @override
  State<MobileChatApp> createState() => _MobileChatAppState();
}

class _MobileChatAppState extends State<MobileChatApp>
    with WidgetsBindingObserver {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://koommy.duckdns.org',
  );

  final SessionStore sessionStore = const SessionStore();
  final AppPreferencesStore preferencesStore = const AppPreferencesStore();
  late final AppLanguageController languageController =
      AppLanguageController(store: preferencesStore);
  late final AppAppearanceController appearanceController =
      AppAppearanceController(store: preferencesStore);
  late final ApiClient api =
      ApiClient(baseUrl: apiBaseUrl, sessionStore: sessionStore);
  late final PushNotificationService pushNotifications =
      PushNotificationService(api: api);
  late Future<AppSession?> bootFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    bootFuture = _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    languageController.dispose();
    appearanceController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreAfterResume());
    }
  }

  Future<AppSession?> _boot() async {
    await Future.wait([
      languageController.restore(),
      appearanceController.restore(),
    ]);
    await api.handleAppResumed(forceRefresh: true);
    var session = await sessionStore.read();
    if (session != null) {
      try {
        session = session.copyWith(user: await api.fetchMe());
        await sessionStore.save(session);
      } catch (_) {}
      await pushNotifications.registerDevice();
    }
    return session;
  }

  Future<void> _restoreAfterResume() async {
    await api.handleAppResumed();
    final session = await sessionStore.read();
    if (!mounted || session != null) return;
    setState(() {
      bootFuture = Future.value(null);
    });
  }

  Future<void> setSession(AppSession session) async {
    await sessionStore.save(session);
    var effectiveSession = session;
    try {
      effectiveSession = session.copyWith(user: await api.fetchMe());
      await sessionStore.save(effectiveSession);
    } catch (_) {}
    await pushNotifications.registerDevice();
    if (!mounted) return;
    setState(() {
      bootFuture = Future.value(effectiveSession);
    });
  }

  Future<void> updateSessionLocally(AppSession session) async {
    await sessionStore.save(session);
    if (!mounted) return;
    setState(() {
      bootFuture = Future.value(session);
    });
  }

  Future<void> logout() async {
    await pushNotifications.unregisterDevice();
    await api.logout();
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
          animation:
              Listenable.merge([languageController, appearanceController]),
          builder: (context, _) {
            final text = languageController.text;
            final scale = appearanceController.displayScale.factor;
            final densityAdjustment = (scale - 1) * 4;
            final visualDensity = VisualDensity(
              horizontal: densityAdjustment,
              vertical: densityAdjustment,
            );
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: text.appTitle,
              theme: MobileChatTheme.light.copyWith(
                visualDensity: visualDensity,
              ),
              darkTheme: MobileChatTheme.dark.copyWith(
                visualDensity: visualDensity,
              ),
              themeMode: appearanceController.themeMode,
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: FutureBuilder<AppSession?>(
                future: bootFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _KoomSplashScreen();
                  }
                  final session = snapshot.data;
                  if (session == null) {
                    return PhoneAuthScreen(
                      api: api,
                      onAuthenticated: setSession,
                    );
                  }
                  return GroupsScreen(
                    api: api,
                    session: session,
                    onSessionChanged: updateSessionLocally,
                    onLogout: logout,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KoomSplashScreen extends StatelessWidget {
  const _KoomSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: KoomPageBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KoomLogoMark(size: 84),
              SizedBox(height: 22),
              Text(
                'Koom',
                style: TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              SizedBox(height: 22),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
