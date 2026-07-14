import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
  });

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

  String get _mobileDigits =>
      mobileController.text.replaceAll(RegExp(r'[^0-9]'), '');
  String get _fullMobileNumber => '$_kgPhonePrefix$_mobileDigits';

  Future<void> requestCode() async {
    final text = AppLanguageScope.textOf(context);
    if (_mobileDigits.length != 9) {
      setState(() {
        error = text.isKy
            ? '996 кодунан кийин 9 цифра жазыңыз'
            : 'Введите 9 цифр после 996';
      });
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
        if (result.accountExists) displayNameController.clear();
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
      setState(() {
        error =
            text.isKy ? 'Код 6 цифрадан турушу керек' : 'Введите 6 цифр кода';
      });
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

  void changePhone() {
    setState(() {
      codeWasSent = false;
      accountExists = false;
      codeController.clear();
      devCode = null;
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 390;
    final veryCompact = screenWidth < 350;

    return Scaffold(
      body: KoomPageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(compact ? 10 : 18, 8,
                    compact ? 10 : 18, 0),
                child: Row(
                  children: [
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: veryCompact
                            ? const KoomLogoMark(size: 36, showShadow: false)
                            : const KoomBrandTitle(compact: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const ThemeModeButton(),
                    const SizedBox(width: 4),
                    LanguageMenuButton(compact: compact),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : 22,
                      22,
                      compact ? 16 : 22,
                      30,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: KoomLogoMark(size: 86)),
                          const SizedBox(height: 22),
                          Text(
                            'Koom',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(fontSize: compact ? 34 : 39),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            text.isKy
                                ? 'Коомчулуктар үчүн байланыш'
                                : 'Общение для сообществ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            text.isKy
                                ? 'Биригиңиз, баарлашыңыз жана чечимдерди чогуу кабыл алыңыз'
                                : 'Объединяйтесь, общайтесь и принимайте решения вместе',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textMuted,
                              height: 1.42,
                            ),
                          ),
                          const SizedBox(height: 26),
                          KoomCard(
                            padding: EdgeInsets.all(compact ? 18 : 23),
                            radius: 28,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  codeWasSent
                                      ? (text.isKy
                                          ? 'Кодду киргизиңиз'
                                          : 'Введите код')
                                      : (text.isKy
                                          ? 'Koomго кирүү'
                                          : 'Вход в Koom'),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontSize: 22),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  codeWasSent
                                      ? (text.isKy
                                          ? 'SMS менен келген алты орундуу кодду жазыңыз'
                                          : 'Введите шестизначный код из SMS')
                                      : _phoneNumberIntro(text),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 240),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: codeWasSent
                                      ? _CodeFields(
                                          key: const ValueKey('code_fields'),
                                          codeController: codeController,
                                          displayNameController:
                                              displayNameController,
                                          accountExists: accountExists,
                                          loading: loading,
                                          devCode: devCode,
                                          onChanged: () {
                                            if (mounted) {
                                              setState(() => error = null);
                                            }
                                          },
                                        )
                                      : TextField(
                                          key: const ValueKey(
                                              'auth_mobile_field'),
                                          controller: mobileController,
                                          enabled: !loading,
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(9),
                                          ],
                                          onChanged: (_) {
                                            if (mounted && error != null) {
                                              setState(() => error = null);
                                            }
                                          },
                                          decoration: InputDecoration(
                                            labelText: text.mobileNumber,
                                            hintText: '700 123 456',
                                            prefixIcon: const Icon(
                                              Icons.phone_iphone_rounded,
                                            ),
                                            prefixText: '$_kgPhonePrefix  ',
                                          ),
                                        ),
                                ),
                                if (devCode != null) ...[
                                  const SizedBox(height: 12),
                                  InfoBanner(
                                    message: devCode == 'any_non_empty_code'
                                        ? text.devSmsAnyCode
                                        : text.devSmsCode(devCode!),
                                  ),
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
                                              codeController.text
                                                      .trim()
                                                      .length !=
                                                  6)
                                      ? null
                                      : (codeWasSent
                                          ? verifyCode
                                          : requestCode),
                                  icon: loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          codeWasSent
                                              ? Icons.verified_rounded
                                              : Icons.arrow_forward_rounded,
                                        ),
                                  label: Text(
                                    loading
                                        ? text.pleaseWait
                                        : (codeWasSent
                                            ? text.verifyAndContinue
                                            : text.continueText),
                                  ),
                                ),
                                if (codeWasSent) ...[
                                  const SizedBox(height: 4),
                                  TextButton.icon(
                                    onPressed: loading ? null : changePhone,
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18),
                                    label: Text(text.changeMobileNumber),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 16,
                                color: colors.textMuted,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  text.isKy
                                      ? 'Ырастоо коду көрсөтүлгөн номерге жөнөтүлөт'
                                      : 'Код подтверждения будет отправлен на указанный номер',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeFields extends StatelessWidget {
  const _CodeFields({
    super.key,
    required this.codeController,
    required this.displayNameController,
    required this.accountExists,
    required this.loading,
    required this.devCode,
    required this.onChanged,
  });

  final TextEditingController codeController;
  final TextEditingController displayNameController;
  final bool accountExists;
  final bool loading;
  final String? devCode;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBanner(
          message:
              accountExists ? text.existingAccountHint : text.newAccountHint,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('auth_code_field'),
          controller: codeController,
          enabled: !loading,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 7,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (_) => onChanged(),
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
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: text.displayNameNewOnly,
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
          ),
        ],
      ],
    );
  }
}

String _phoneNumberIntro(AppText text) {
  if (text.isKy) return 'Кирүү же катталуу үчүн телефон номериңизди жазыңыз';
  return 'Введите номер телефона для входа или регистрации';
}
