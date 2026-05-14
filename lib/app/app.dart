import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../data/session_store.dart';
import '../features/auth/phone_auth_screen.dart';
import '../features/groups/groups_screen.dart';
import 'theme.dart';

class MobileChatApp extends StatefulWidget {
  const MobileChatApp({super.key});

  @override
  State<MobileChatApp> createState() => _MobileChatAppState();
}

class _MobileChatAppState extends State<MobileChatApp> {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  final SessionStore sessionStore = const SessionStore();
  late final ApiClient api = ApiClient(baseUrl: apiBaseUrl, sessionStore: sessionStore);
  late Future<AppSession?> bootFuture;

  @override
  void initState() {
    super.initState();
    bootFuture = sessionStore.read();
  }

  Future<void> setSession(AppSession session) async {
    await sessionStore.save(session);
    setState(() => bootFuture = Future.value(session));
  }

  Future<void> logout() async {
    await sessionStore.clear();
    setState(() => bootFuture = Future.value(null));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MobileChat',
      theme: MobileChatTheme.light,
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
  }
}
