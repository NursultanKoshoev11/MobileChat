import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../shared/ui_helpers.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen(
      {super.key, required this.api, required this.onAuthenticated});

  final ApiClient api;
  final Future<void> Function(AppSession session) onAuthenticated;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  static const _kgPhonePrefix = '+996';

  final mobileController = TextEditingController();
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

  String get _mobileDigits => mobileController.text.replaceAll(RegExp(r'[^0-9]'), '');
  String get _fullMobileNumber => '$_kgPhonePrefix$_mobileDigits';

  Future<void> requestCode() async {
    final text = AppLanguageScope.textOf(context);
    if (_mobileDigits.length != 9) {
      setState(() => error = text.isKy ? '996 кодунан кийин 9 цифра жазыңыз' : 'Введите 9 цифр после 996');
      return;
    }
    setState(() {
      loading = true;
      error = null;
      devCode = null;
      accountExists = false;
    });
    try {
      final result = await widget.api.requestPhoneCode(_fullMobileNumber);
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
    final code = codeController.text.trim();
    if (code.isEmpty) {
      setState(() => error = text.codeRequired);
      return;
    }
    if (code.length != 6) {
      setState(() => error =
          text.isKy ? 'Код 6 цифрадан турушу керек' : 'Введите 6 цифр кода');
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
        mobile: _fullMobileNumber,
        code: code,
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
    final colors = context.appColors;
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
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                        color: colors.shadow,
                        blurRadius: 28,
                        offset: const Offset(0, 16))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [ThemeModeButton(), LanguageMenuButton()]),
                    ),
                    const SizedBox(height: 10),
                    const CircleAvatar(
                      radius: 42,
                      backgroundColor: MobileChatTheme.primary,
                      child: Icon(Icons.sms_rounded,
                          color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      text.appTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _phoneNumberIntro(text),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textMuted),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const ValueKey('auth_mobile_field'),
                      controller: mobileController,
                      enabled: !loading && !codeWasSent,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      onChanged: (_) {
                        if (mounted && error != null) setState(() => error = null);
                      },
                      decoration: InputDecoration(
                        labelText: text.mobileNumber,
                        hintText: '700123456',
                        prefixIcon: const Icon(Icons.phone_iphone_rounded),
                        prefixText: '$_kgPhonePrefix ',
                      ),
                    ),
                    if (codeWasSent) ...[
                      const SizedBox(height: 12),
                      InfoBanner(
                          message: accountExists
                              ? text.existingAccountHint
                              : text.newAccountHint),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('auth_code_field'),
                        controller: codeController,
                        enabled: !loading,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onChanged: (_) {
                          if (mounted) setState(() => error = null);
                        },
                        decoration: InputDecoration(
                          labelText: text.code,
                          hintText: devCode,
                          prefixIcon: const Icon(Icons.password_rounded),
                        ),
                      ),
                      if (!accountExists) ...[
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey('auth_display_name_field'),
                          controller: displayNameController,
                          enabled: !loading,
                          decoration: InputDecoration(
                            labelText: text.displayNameNewOnly,
                            prefixIcon:
                                const Icon(Icons.person_outline_rounded),
                          ),
                        ),
                      ],
                    ],
                    if (devCode != null) ...[
                      const SizedBox(height: 12),
                      InfoBanner(
                          message: devCode == 'any_non_empty_code'
                              ? text.devSmsAnyCode
                              : text.devSmsCode(devCode!)),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      ErrorBanner(message: error!),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      key: const ValueKey('auth_submit_button'),
                      onPressed: loading ||
                              (codeWasSent &&
                                  codeController.text.trim().length != 6)
                          ? null
                          : (codeWasSent ? verifyCode : requestCode),
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(codeWasSent
                              ? Icons.verified_rounded
                              : Icons.sms_rounded),
                      label: Text(loading
                          ? text.pleaseWait
                          : (codeWasSent
                              ? text.verifyAndContinue
                              : text.continueText)),
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


String _phoneLengthError(AppText text) {
  if (text.isKy) {
    return String.fromCharCodes([57, 57, 54, 32, 1082, 1086, 1076, 1091, 1085, 1072, 1085, 32, 1082, 1080, 1081, 1080, 1085, 32, 57, 32, 1094, 1080, 1092, 1088, 1072, 32, 1078, 1072, 1079, 1099, 1187, 1099, 1079]);
  }
  return String.fromCharCodes([1042, 1074, 1077, 1076, 1080, 1090, 1077, 32, 57, 32, 1094, 1080, 1092, 1088, 32, 1087, 1086, 1089, 1083, 1077, 32, 57, 57, 54]);
}

String _phoneNumberIntro(AppText text) {
  if (text.isKy) {
    return String.fromCharCodes([
      1058,
      1077,
      1083,
      1077,
      1092,
      1086,
      1085,
      32,
      1085,
      1086,
      1084,
      1077,
      1088,
      1080,
      1187,
      1080,
      1079,
      1076,
      1080,
      32,
      1078,
      1072,
      1079,
      1099,
      1187,
      1099,
      1079,
      46,
    ]);
  }
  return String.fromCharCodes([
    1042,
    1074,
    1077,
    1076,
    1080,
    1090,
    1077,
    32,
    1085,
    1086,
    1084,
    1077,
    1088,
    32,
    1090,
    1077,
    1083,
    1077,
    1092,
    1086,
    1085,
    1072,
    46,
  ]);
}
