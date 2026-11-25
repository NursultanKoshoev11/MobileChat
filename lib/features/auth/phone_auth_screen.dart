import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/preferences_store.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../shared/koom_ui.dart';
import '../../shared/legal_links.dart';
import '../../shared/phone_input.dart';
import '../../shared/ui_helpers.dart';

/// How long the "send the code again" button stays disabled after a code went
/// out. The server allows a new code after 30 s; 60 s is the SMS delivery
/// budget, so the button only appears once waiting has stopped being useful.
const kPhoneCodeResendCountdown = Duration(seconds: 60);

/// Shortest gap the server accepts between two codes for one number.
const _minimumRequestGap = Duration(seconds: 30);

/// `3 per 10 minutes` and `8 per number per 24 hours`, as enforced by the
/// server. Mirrored here so a user does not spend their quota on a request
/// that is already refused.
const _shortWindow = Duration(minutes: 10);
const _shortWindowLimit = 3;
const _dailyWindow = Duration(hours: 24);
const _dailyLimit = 8;

/// The server's own refusal texts. [localizedMessage] (used by [ErrorBanner])
/// already maps both to Russian and Kyrgyz, so the app reuses the wording
/// instead of inventing a second one.
const kCodeRequestTooSoonMessage = 'please wait before requesting another code';
const kCodeRequestQuotaMessage = 'too many code requests; try again later';

/// Decides whether another code may be requested for a number.
///
/// [sentAt] are the moments codes went out for that number in this session,
/// oldest first. Returns the server's refusal text when the request would be
/// rejected, or `null` when it may go out.
String? phoneCodeRequestRefusal(List<DateTime> sentAt, DateTime now) {
  if (sentAt.isEmpty) return null;
  if (now.difference(sentAt.last) < _minimumRequestGap) {
    return kCodeRequestTooSoonMessage;
  }
  final recent = sentAt.where((at) => now.difference(at) < _shortWindow).length;
  if (recent >= _shortWindowLimit) return kCodeRequestQuotaMessage;
  final today = sentAt.where((at) => now.difference(at) < _dailyWindow).length;
  if (today >= _dailyLimit) return kCodeRequestQuotaMessage;
  return null;
}

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
    this.preferencesStore = const AppPreferencesStore(),
    this.clock = DateTime.now,
  });

  final ApiClient api;
  final AppPreferencesStore preferencesStore;
  final Future<void> Function(AppSession session) onAuthenticated;

  /// Wall clock behind the request-code rate-limit mirror. Widget tests run
  /// the countdown on fake time, so they pass a clock they control.
  final DateTime Function() clock;

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
  bool termsAccepted = false;
  String? error;

  /// Seconds left before "send the code again" becomes tappable. Lives in the
  /// state, so a rebuild (typing, a theme or language switch) keeps counting.
  int resendSecondsLeft = 0;
  Timer? _resendTicker;

  /// When codes went out, per number: the daily cap is per number too.
  final Map<String, List<DateTime>> _codeRequests = <String, List<DateTime>>{};

  @override
  void initState() {
    super.initState();
    _restoreTermsAcceptance();
  }

  Future<void> _restoreTermsAcceptance() async {
    try {
      final acceptedAt = await widget.preferencesStore.readTermsAcceptedAt();
      if (!mounted || acceptedAt == null || acceptedAt.isEmpty) return;
      setState(() => termsAccepted = true);
    } catch (_) {}
  }

  Future<void> _rememberTermsAcceptance() async {
    try {
      await widget.preferencesStore.writeTermsAcceptedAt(
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {}
  }

  String _termsRequiredMessage(AppText text) => text.isKy
      ? 'Улантуу үчүн Колдонуу шарттарын жана Купуялык саясатын кабыл алыңыз'
      : 'Чтобы продолжить, примите Условия использования и Политику конфиденциальности';

  @override
  void dispose() {
    _resendTicker?.cancel();
    _resendTicker = null;
    mobileController.dispose();
    codeController.dispose();
    displayNameController.dispose();
    super.dispose();
  }

  String get _mobileDigits => normalizeKgMobileInput(mobileController.text);
  String get _fullMobileNumber => '$_kgPhonePrefix$_mobileDigits';

  void _stopResendCountdown() {
    _resendTicker?.cancel();
    _resendTicker = null;
    resendSecondsLeft = 0;
  }

  void _startResendCountdown() {
    _resendTicker?.cancel();
    setState(() => resendSecondsLeft = kPhoneCodeResendCountdown.inSeconds);
    _resendTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      // The screen can go away mid-countdown (sign-in succeeds, the user
      // leaves): never touch state after that.
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = resendSecondsLeft - 1;
      if (next > 0) {
        setState(() => resendSecondsLeft = next);
        return;
      }
      timer.cancel();
      _resendTicker = null;
      setState(() => resendSecondsLeft = 0);
      // One announcement when waiting is over, instead of a screen reader
      // reading out every second of the countdown.
      SemanticsService.announce(
        AppLanguageScope.textOf(context).resendCode,
        Directionality.of(context),
      );
    });
  }

  Future<void> requestCode() => _sendCode(resend: false);

  Future<void> _sendCode({required bool resend}) async {
    final text = AppLanguageScope.textOf(context);
    if (!termsAccepted) {
      setState(() => error = _termsRequiredMessage(text));
      return;
    }
    if (_mobileDigits.length != 9) {
      setState(() {
        error = text.isKy
            ? '996 кодунан кийин 9 цифра жазыңыз'
            : 'Введите 9 цифр после 996';
      });
      return;
    }
    final number = _fullMobileNumber;
    final refusal = phoneCodeRequestRefusal(
      _codeRequests[number] ?? const <DateTime>[],
      widget.clock(),
    );
    if (refusal != null) {
      setState(() => error = refusal);
      return;
    }
    setState(() {
      loading = true;
      error = null;
      if (!resend) accountExists = false;
    });
    await _rememberTermsAcceptance();
    try {
      final result = await widget.api.requestPhoneCode(number);
      if (!mounted) return;
      (_codeRequests[number] ??= <DateTime>[]).add(widget.clock());
      setState(() {
        codeWasSent = true;
        accountExists = result.accountExists;
        if (result.accountExists) displayNameController.clear();
        // The previous code stops working once a new one is out.
        if (resend) codeController.clear();
      });
      _startResendCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyCode() async {
    final text = AppLanguageScope.textOf(context);
    if (!termsAccepted) {
      setState(() => error = _termsRequiredMessage(text));
      return;
    }
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
    // The server no longer reports whether the number already has an account
    // (that would let anyone enumerate registered numbers), so accountExists
    // stays false for returning users too. Only reject a name that is present
    // but too short; an empty name is fine for returning users, and the
    // server answers "display_name is required for new account" otherwise.
    final displayName = displayNameController.text.trim();
    if (!accountExists && displayName.isNotEmpty && displayName.length < 2) {
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
      if (mounted) setState(_stopResendCountdown);
      await widget.onAuthenticated(session);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      setState(() {
        error = message.contains('display_name is required')
            ? text.displayNameRequiredForNewAccount
            : message;
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void changePhone() {
    setState(() {
      _stopResendCountdown();
      codeWasSent = false;
      accountExists = false;
      codeController.clear();
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final compact = MediaQuery.sizeOf(context).width < 390;
    final gutter = compact ? KoomSpacing.lg : KoomSpacing.xl;

    return Scaffold(
      body: KoomPageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KoomSpacing.md,
                  KoomSpacing.sm,
                  KoomSpacing.md,
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const ThemeModeButton(),
                    const SizedBox(width: KoomSpacing.xs),
                    LanguageMenuButton(compact: compact),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      KoomSpacing.lg,
                      gutter,
                      KoomSpacing.xxl,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: KoomLogoMark(size: 80)),
                          const SizedBox(height: KoomSpacing.lg),
                          Text(
                            text.appTitle,
                            textAlign: TextAlign.center,
                            style: compact
                                ? theme.textTheme.headlineMedium
                                : theme.textTheme.headlineLarge,
                          ),
                          const SizedBox(height: KoomSpacing.sm),
                          Text(
                            text.isKy
                                ? 'Коомчулуктар үчүн байланыш'
                                : 'Общение для сообществ',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: colors.textMuted),
                          ),
                          const SizedBox(height: KoomSpacing.xl),
                          KoomCard(
                            padding: EdgeInsets.all(gutter),
                            child: AutofillGroup(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
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
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: KoomSpacing.sm),
                                  Text(
                                    codeWasSent
                                        ? (text.isKy
                                            ? 'SMS менен келген алты орундуу кодду жазыңыз'
                                            : 'Введите шестизначный код из SMS')
                                        : text.enterMobileNumber,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: colors.textMuted),
                                  ),
                                  const SizedBox(height: KoomSpacing.lg),
                                  AnimatedSwitcher(
                                    duration:
                                        const Duration(milliseconds: 240),
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
                                            resendSecondsLeft:
                                                resendSecondsLeft,
                                            onResend: _resendCode,
                                            onChanged: () {
                                              if (mounted) {
                                                setState(() => error = null);
                                              }
                                            },
                                          )
                                        : _MobileField(
                                            key: const ValueKey(
                                              'mobile_field',
                                            ),
                                            controller: mobileController,
                                            prefix: _kgPhonePrefix,
                                            loading: loading,
                                            onChanged: () {
                                              if (mounted) {
                                                setState(() => error = null);
                                              }
                                            },
                                          ),
                                  ),
                                  const SizedBox(height: KoomSpacing.md),
                                  TermsAcceptanceCheckbox(
                                    value: termsAccepted,
                                    enabled: !loading,
                                    onChanged: (value) => setState(() {
                                      termsAccepted = value;
                                      error = null;
                                    }),
                                  ),
                                  if (error != null) ...[
                                    const SizedBox(height: KoomSpacing.md),
                                    ErrorBanner(message: error!),
                                  ],
                                  const SizedBox(height: KoomSpacing.lg),
                                  Semantics(
                                    identifier: 'auth_submit_button',
                                    container: true,
                                    child: FilledButton.icon(
                                      key: const ValueKey(
                                        'auth_submit_button',
                                      ),
                                      onPressed: loading ||
                                              !termsAccepted ||
                                              (codeWasSent
                                                  ? codeController.text
                                                          .trim()
                                                          .length !=
                                                      6
                                                  : _mobileDigits.length != 9)
                                          ? null
                                          : (codeWasSent
                                              ? verifyCode
                                              : requestCode),
                                      icon: loading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Icon(
                                              codeWasSent
                                                  ? Icons.verified_rounded
                                                  : Icons
                                                      .arrow_forward_rounded,
                                            ),
                                      label: Text(
                                        loading
                                            ? text.pleaseWait
                                            : (codeWasSent
                                                ? text.verifyAndContinue
                                                : text.continueText),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  if (codeWasSent) ...[
                                    const SizedBox(height: KoomSpacing.xs),
                                    TextButton.icon(
                                      key: const ValueKey(
                                        'auth_change_number_button',
                                      ),
                                      style: _tapTargetStyle,
                                      onPressed: loading ? null : changePhone,
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        text.changeMobileNumber,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
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

  Future<void> _resendCode() async {
    if (loading || resendSecondsLeft > 0) return;
    await _sendCode(resend: true);
  }
}

/// Material's minimum touch target, for the two text buttons on this screen:
/// [TextButton]'s own default is 36dp high.
final ButtonStyle _tapTargetStyle = TextButton.styleFrom(
  minimumSize: const Size(48, 48),
);

class _MobileField extends StatelessWidget {
  const _MobileField({
    super.key,
    required this.controller,
    required this.prefix,
    required this.loading,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String prefix;
  final bool loading;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Semantics(
      identifier: 'auth_mobile_field',
      container: true,
      child: TextField(
        key: const ValueKey('auth_mobile_field'),
        controller: controller,
        enabled: !loading,
        keyboardType: TextInputType.phone,
        // Lets the keyboard offer the phone's own number; the formatter
        // still strips the country code the OS fills in.
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: const [KgMobileInputFormatter()],
        maxLength: kgMobileDigits,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          labelText: text.mobileNumber,
          hintText: '700 123 456',
          prefixIcon: const Icon(Icons.phone_iphone_rounded),
          prefixText: '$prefix  ',
          counterText: '',
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
    required this.resendSecondsLeft,
    required this.onResend,
    required this.onChanged,
  });

  final TextEditingController codeController;
  final TextEditingController displayNameController;
  final bool accountExists;
  final bool loading;
  final int resendSecondsLeft;
  final VoidCallback onResend;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBanner(
          message:
              accountExists ? text.existingAccountHint : text.newAccountHint,
        ),
        const SizedBox(height: KoomSpacing.md),
        Semantics(
          identifier: 'auth_code_field',
          container: true,
          child: TextField(
            key: const ValueKey('auth_code_field'),
            controller: codeController,
            enabled: !loading,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            // The one hint that makes iOS and Android offer the code from the
            // incoming SMS instead of making people retype six digits.
            autofillHints: const [AutofillHints.oneTimeCode],
            style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 4),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: text.code,
              prefixIcon: const Icon(Icons.password_rounded),
            ),
          ),
        ),
        const SizedBox(height: KoomSpacing.sm),
        _ResendCode(
          secondsLeft: resendSecondsLeft,
          enabled: !loading,
          onResend: onResend,
        ),
        if (!accountExists) ...[
          const SizedBox(height: KoomSpacing.md),
          Semantics(
            identifier: 'auth_display_name_field',
            container: true,
            child: TextField(
              key: const ValueKey('auth_display_name_field'),
              controller: displayNameController,
              enabled: !loading,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(
                labelText: text.displayNameNewOnly,
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The countdown under the code field, which becomes the "send the code
/// again" button once waiting is over.
class _ResendCode extends StatelessWidget {
  const _ResendCode({
    required this.secondsLeft,
    required this.enabled,
    required this.onResend,
  });

  final int secondsLeft;
  final bool enabled;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final theme = Theme.of(context);
    if (secondsLeft <= 0) {
      return TextButton.icon(
        key: const ValueKey('auth_resend_button'),
        style: _tapTargetStyle,
        onPressed: enabled ? onResend : null,
        icon: const Icon(Icons.sms_outlined, size: 18),
        label: Text(text.resendCode, textAlign: TextAlign.center),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KoomSpacing.sm),
      child: Text(
        key: const ValueKey('auth_resend_countdown'),
        text.resendCodeIn(secondsLeft),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
