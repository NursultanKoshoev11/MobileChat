import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/api_config.dart';
import '../app/localization.dart';
import '../app/theme.dart';
import 'ui_helpers.dart';

/// Opens a public legal page (Terms / Privacy) in the external browser.
Future<void> openLegalPage(BuildContext context, Uri uri) async {
  final text = AppLanguageScope.textOf(context);
  final failure = text.isKy
      ? 'Баракчаны ачуу мүмкүн болгон жок: $uri'
      : 'Не удалось открыть страницу: $uri';
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) showAppSnack(context, failure);
  } catch (_) {
    if (context.mounted) showAppSnack(context, failure);
  }
}

String termsOfUseLabel(AppText text) =>
    text.isKy ? 'Колдонуу шарттары' : 'Условия использования';

String privacyPolicyLabel(AppText text) =>
    text.isKy ? 'Купуялык саясаты' : 'Политика конфиденциальности';

/// Checkbox "I accept the Terms of Use and Privacy Policy" with both
/// documents linked. Sign-in is blocked until it is checked.
class TermsAcceptanceCheckbox extends StatefulWidget {
  const TermsAcceptanceCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.onOpenLink,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  /// Overrides link handling (used in tests).
  final void Function(Uri uri)? onOpenLink;

  @override
  State<TermsAcceptanceCheckbox> createState() =>
      _TermsAcceptanceCheckboxState();
}

class _TermsAcceptanceCheckboxState extends State<TermsAcceptanceCheckbox> {
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => _open(termsOfUseUri());
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => _open(privacyPolicyUri());

  void _open(Uri uri) {
    final handler = widget.onOpenLink;
    if (handler != null) {
      handler(uri);
    } else {
      openLegalPage(context, uri);
    }
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final linkStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
    );
    final spans = text.isKy
        ? <InlineSpan>[
            const TextSpan(text: 'Мен '),
            TextSpan(
              text: termsOfUseLabel(text),
              style: linkStyle,
              recognizer: _termsTap,
            ),
            const TextSpan(text: ' жана '),
            TextSpan(
              text: privacyPolicyLabel(text),
              style: linkStyle,
              recognizer: _privacyTap,
            ),
            const TextSpan(text: ' менен макулмун'),
          ]
        : <InlineSpan>[
            const TextSpan(text: 'Я принимаю '),
            TextSpan(
              text: termsOfUseLabel(text),
              style: linkStyle,
              recognizer: _termsTap,
            ),
            const TextSpan(text: ' и '),
            TextSpan(
              text: privacyPolicyLabel(text),
              style: linkStyle,
              recognizer: _privacyTap,
            ),
          ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          identifier: 'terms_accept_checkbox',
          container: true,
          child: Checkbox(
            key: const ValueKey('terms_accept_checkbox'),
            value: widget.value,
            onChanged: widget.enabled
                ? (value) => widget.onChanged(value ?? false)
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                color: colors.textMuted,
                height: 1.35,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              children: spans,
            ),
          ),
        ),
      ],
    );
  }
}
