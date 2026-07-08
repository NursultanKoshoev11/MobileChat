import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'main_prod.dart' as prod;

void main() {
  runApp(const MobileChatPhoneApp());
}

class MobileChatPhoneApp extends StatefulWidget {
  const MobileChatPhoneApp({super.key});

  @override
  State<MobileChatPhoneApp> createState() => _MobileChatPhoneAppState();
}

class _MobileChatPhoneAppState extends State<MobileChatPhoneApp> {
  late final prod.SecureSessionStore sessionStore;
  late final prod.ApiClient api;
  late final PhoneAuthApi phoneAuth;
  late Future<prod.AppSession?> bootFuture;

  @override
  void initState() {
    super.initState();
    sessionStore = const prod.SecureSessionStore();
    api = prod.ApiClient(prod.AppConfig.apiBaseUrl, sessionStore);
    phoneAuth = PhoneAuthApi(prod.AppConfig.apiBaseUrl);
    bootFuture = sessionStore.readSession();
  }

  Future<void> setSession(prod.AppSession session) async {
    await sessionStore.saveSession(session);
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
      theme: prod.AppTheme.light,
      home: FutureBuilder<prod.AppSession?>(
        future: bootFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const prod.SplashScreen();
          }
          final session = snapshot.data;
          if (session == null) {
            return PhoneAuthScreen(api: phoneAuth, onAuthenticated: setSession);
          }
          return prod.HomeScreen(api: api, session: session, onLogout: logout);
        },
      ),
    );
  }
}

class PhoneAuthApi {
  const PhoneAuthApi(this.baseUrl);

  final String baseUrl;

  Future<RequestCodeResult> requestCode(String mobile) async {
    final response = await _post('/api/auth/request-code', {'mobile': mobile});
    return RequestCodeResult.fromJson(response as Map<String, dynamic>);
  }

  Future<prod.AppSession> verifyCode({
    required String mobile,
    required String code,
    required String displayName,
  }) async {
    final response = await _post('/api/auth/verify-code', {
      'mobile': mobile,
      'code': code,
      'display_name': displayName,
    });
    return prod.AppSession.fromJson(response as Map<String, dynamic>);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse(baseUrl).replace(path: path);
    try {
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json; charset=utf-8', 'Accept': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(prod.AppConfig.networkTimeout);
      return _decode(response);
    } on TimeoutException {
      throw const prod.ApiException('Connection timed out. Please check the server and try again.');
    } catch (error) {
      if (error is prod.ApiException) rethrow;
      throw prod.ApiException('Network error: $error');
    }
  }

  dynamic _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes).trim();
    final decoded = body.isEmpty ? null : jsonDecode(body);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    if (decoded is Map<String, dynamic> && decoded['error'] is String) {
      throw prod.ApiException(decoded['error'] as String);
    }
    throw prod.ApiException('Server error ${response.statusCode}');
  }
}

class RequestCodeResult {
  const RequestCodeResult({required this.status, this.devCode});

  final String status;
  final String? devCode;

  factory RequestCodeResult.fromJson(Map<String, dynamic> json) {
    return RequestCodeResult(
      status: json['status'] as String? ?? 'code_sent',
      devCode: json['dev_code'] as String?,
    );
  }
}

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, required this.api, required this.onAuthenticated});

  final PhoneAuthApi api;
  final Future<void> Function(prod.AppSession session) onAuthenticated;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final mobileController = TextEditingController(text: '+996');
  final codeController = TextEditingController();
  final displayNameController = TextEditingController();

  bool codeWasSent = false;
  bool loading = false;
  String? error;
  String? devCode;

  @override
  void dispose() {
    mobileController.dispose();
    codeController.dispose();
    displayNameController.dispose();
    super.dispose();
  }

  Future<void> requestCode() async {
    setState(() {
      loading = true;
      error = null;
      devCode = null;
    });
    try {
      final result = await widget.api.requestCode(mobileController.text.trim());
      setState(() {
        codeWasSent = true;
        devCode = result.devCode;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyCode() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final session = await widget.api.verifyCode(
        mobile: mobileController.text.trim(),
        code: codeController.text.trim(),
        displayName: displayNameController.text.trim(),
      );
      await widget.onAuthenticated(session);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 16)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CircleAvatar(
                      radius: 42,
                      backgroundColor: prod.AppTheme.primary,
                      child: Icon(Icons.sms_rounded, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'MobileChat',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in with your mobile number. We will send a verification code by SMS.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: prod.AppTheme.textMuted),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: mobileController,
                      enabled: !loading && !codeWasSent,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: '+996700123456',
                        prefixIcon: Icon(Icons.phone_iphone_rounded),
                      ),
                    ),
                    if (codeWasSent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        enabled: !loading,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'SMS code',
                          prefixIcon: Icon(Icons.password_rounded),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: displayNameController,
                        enabled: !loading,
                        decoration: const InputDecoration(
                          labelText: 'Display name for new account',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                    ],
                    if (devCode != null) ...[
                      const SizedBox(height: 12),
                      prod.InfoBanner(message: 'Development SMS code: $devCode'),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      prod.ErrorBanner(message: error!),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: loading ? null : (codeWasSent ? verifyCode : requestCode),
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(codeWasSent ? Icons.verified_rounded : Icons.sms_rounded),
                      label: Text(
                        loading
                            ? 'Please wait...'
                            : codeWasSent
                                ? 'Verify and continue'
                                : 'Send SMS code',
                      ),
                    ),
                    if (codeWasSent)
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => setState(() {
                                  codeWasSent = false;
                                  codeController.clear();
                                  devCode = null;
                                  error = null;
                                }),
                        child: const Text('Change mobile number'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
