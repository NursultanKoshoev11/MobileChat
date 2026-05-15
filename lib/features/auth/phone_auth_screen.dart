import 'package:flutter/material.dart';

import '../../app/localization.dart';
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
  bool accountExists = false;
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
      accountExists = false;
    });
    try {
      final result = await widget.api.requestPhoneCode(mobileController.text.trim());
      if (!mounted) return;
      setState(() {
        codeWasSent = true;
        accountExists = result.accountExists;
        devCode = result.devCode;
        if (result.accountExists) {
          displayNameController.clear();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyCode() async {
    final text = AppLanguageScope.textOf(context);
    if (codeController.text.trim().isEmpty) {
      setState(() => error = text.codeRequired);
      return;
    }
    if (!accountExists && displayNameController.text.trim().length < 2) {
      setState(() => error = text.displayNameRequiredForNewAccount);
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
        displayName: accountExists ? '' : displayNameController.text.trim(),
      );
      await widget.onAuthenticated(session);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
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
                    const Align(alignment: Alignment.centerRight, child: LanguageMenuButton()),
                    const SizedBox(height: 10),
                    const CircleAvatar(
                      radius: 42,
                      backgroundColor: MobileChatTheme.primary,
                      child: Icon(Icons.sms_rounded, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      text.appTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text.enterMobileNumber,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: MobileChatTheme.textMuted),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: mobileController,
                      enabled: !loading && !codeWasSent,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: text.mobileNumber,
                        hintText: '+996700123456',
                        prefixIcon: const Icon(Icons.phone_iphone_rounded),
                      ),
                    ),
                    if (codeWasSent) ...[
                      const SizedBox(height: 12),
                      InfoBanner(message: accountExists ? text.existingAccountHint : text.newAccountHint),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        enabled: !loading,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: text.code,
                          hintText: text.localTestCode,
                          prefixIcon: const Icon(Icons.password_rounded),
                        ),
                      ),
                      if (!accountExists) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: displayNameController,
                          enabled: !loading,
                          decoration: InputDecoration(
                            labelText: text.displayNameNewOnly,
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                          ),
                        ),
                      ],
                    ],
                    if (devCode != null) ...[
                      const SizedBox(height: 12),
                      InfoBanner(message: devCode == 'any_non_empty_code' ? text.devSmsAnyCode : text.devSmsCode(devCode!)),
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
                      label: Text(loading ? text.pleaseWait : (codeWasSent ? text.verifyAndContinue : text.continueText)),
                    ),
                    if (codeWasSent)
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => setState(() {
                                  codeWasSent = false;
                                  accountExists = false;
                                  codeController.clear();
                                  devCode = null;
                                  error = null;
                                }),
                        child: Text(text.changeMobileNumber),
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
