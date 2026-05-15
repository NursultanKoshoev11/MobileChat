import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../shared/ui_helpers.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, required this.api, required this.onAuthenticated});

  final ApiClient api;
  final Future<void> Function(AppSession session) onAuthenticated;

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
      final result = await widget.api.requestPhoneCode(mobileController.text.trim());
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
    if (codeController.text.trim().isEmpty) {
      setState(() => error = 'Code is required');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final session = await widget.api.verifyPhoneCode(
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
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 16))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CircleAvatar(
                      radius: 42,
                      backgroundColor: MobileChatTheme.primary,
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
                      'Enter your mobile number. For local testing, use test code 123 after continuing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MobileChatTheme.textMuted),
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
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: 'Code',
                          hintText: 'For local test enter 123',
                          prefixIcon: Icon(Icons.password_rounded),
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
                      InfoBanner(message: devCode == 'any_non_empty_code' ? 'Local test mode: enter 123 in the code field.' : 'Development SMS code: $devCode'),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      ErrorBanner(message: error!),
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
                      label: Text(loading ? 'Please wait...' : (codeWasSent ? 'Verify and continue' : 'Continue')),
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
