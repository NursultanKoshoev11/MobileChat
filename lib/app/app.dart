import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/api_client.dart';
import '../data/blocked_users.dart';
import '../data/models.dart';
import '../data/session_store.dart';
import '../features/auth/phone_auth_screen.dart';
import '../services/push_notification_service.dart';
import '../shared/koom_ui.dart';
import 'api_config.dart';
import 'appearance.dart';
import 'home_shell.dart';
import 'localization.dart';
import 'preferences_store.dart';
import 'theme.dart';

class KoomApp extends StatefulWidget {
  const KoomApp({super.key});

  @override
  State<KoomApp> createState() => _KoomAppState();
}

class _KoomAppState extends State<KoomApp>
    with WidgetsBindingObserver {
  static const apiBaseUrl = kApiBaseUrl;

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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    validateApiBaseUrl(apiBaseUrl);
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
      unawaited(BlockedUsersController.instance.load(api));
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
    unawaited(BlockedUsersController.instance.load(api));
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

  /// Signs out on this device. Every step is best effort and bounded, so a
  /// missing network or a failing server can never leave the UI stuck on the
  /// signed-in screens.
  Future<void> logout() async {
    await runLogoutSteps([
      pushNotifications.unregisterDevice,
      pushNotifications.forgetDeviceToken,
      () async => BlockedUsersController.instance.clear(),
      api.logout,
    ]);
    // ApiClient.logout already clears the session; clear again in case a
    // step above threw before reaching it.
    await api.clearLocalSession();
    _resetToSignIn();
  }

  /// Revokes all sessions on the server, then signs out locally. Throws (and
  /// keeps the user signed in) when the server call fails.
  Future<void> logoutAllDevices() async {
    // Deleting this device's push token needs a valid access token, so do it
    // before the server revokes every session.
    await runLogoutSteps([pushNotifications.unregisterDevice]);
    try {
      await api.logoutAllDevices();
    } catch (_) {
      unawaited(pushNotifications.registerDevice());
      rethrow;
    }
    await runLogoutSteps([
      pushNotifications.forgetDeviceToken,
      () async => BlockedUsersController.instance.clear(),
    ]);
    _resetToSignIn();
  }

  Future<void> accountDeleted() async {
    // The server removes the account's push tokens with the account; also
    // invalidate the token on the device.
    await runLogoutSteps([
      pushNotifications.forgetDeviceToken,
      () async => BlockedUsersController.instance.clear(),
    ]);
    _resetToSignIn();
  }

  void _resetToSignIn() {
    if (!mounted) return;
    // Close any screens pushed above the home shell (group, sheets).
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
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
              navigatorKey: _navigatorKey,
              debugShowCheckedModeBanner: false,
              locale: materialLocaleFor(languageController.language),
              supportedLocales: kSupportedLocales,
              localizationsDelegates: kLocalizationsDelegates,
              title: text.appTitle,
              theme: KoomTheme.light.copyWith(
                visualDensity: visualDensity,
              ),
              darkTheme: KoomTheme.dark.copyWith(
                visualDensity: visualDensity,
              ),
              themeMode: appearanceController.themeMode,
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: combineTextScalers(
                      mediaQuery.textScaler,
                      scale,
                    ),
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
                  return KoomHomeShell(
                    api: api,
                    session: session,
                    onSessionChanged: updateSessionLocally,
                    onLogout: logout,
                    onLogoutAllDevices: logoutAllDevices,
                    onAccountDeleted: accountDeleted,
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

/// Locales the app ships UI strings for. Material/Cupertino widgets use the
/// matching Flutter localizations (date pickers, tooltips, text selection).
const kSupportedLocales = <Locale>[Locale('ru'), Locale('ky')];

const kLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Locale materialLocaleFor(AppLanguage language) =>
    language == AppLanguage.ky ? const Locale('ky') : const Locale('ru');

/// Upper bound for the combined text scale so layouts stay usable.
const kMaxTextScale = 2.0;

/// Applies the in-app display scale on top of the system (accessibility) text
/// scale instead of replacing it, clamped to [kMaxTextScale].
TextScaler combineTextScalers(TextScaler system, double appScale) {
  final systemFactor = system.scale(100) / 100;
  final combined = (systemFactor * appScale).clamp(0.5, kMaxTextScale);
  return TextScaler.linear(combined.toDouble());
}

/// Runs each logout step, bounding its duration and ignoring its failure, so
/// one failing step (e.g. no network) cannot block the rest.
Future<void> runLogoutSteps(
  List<Future<void> Function()> steps, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  for (final step in steps) {
    try {
      await step().timeout(timeout);
    } catch (_) {}
  }
}
