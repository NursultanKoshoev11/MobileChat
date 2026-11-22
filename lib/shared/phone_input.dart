import 'package:flutter/services.dart';

/// Number of digits in a Kyrgyz mobile number after the `+996` country code.
const kgMobileDigits = 9;

/// Normalizes whatever the user typed or pasted into the national part of a
/// Kyrgyz mobile number (the 9 digits after `+996`).
///
/// The phone field shows `+996` as a fixed prefix, so users frequently paste
/// or type the full number. Handled forms:
/// * `+996 700 123 456`, `+996700123456` -> `700123456`
/// * `00996700123456` -> `700123456`
/// * `996700123456` (more than 9 digits) -> `700123456`
/// * `0700123456` (local trunk prefix) -> `700123456`
///
/// The result contains digits only and is limited to [kgMobileDigits].
String normalizeKgMobileInput(String input) {
  final trimmed = input.trimLeft();
  var digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (trimmed.startsWith('+')) {
    if (digits.startsWith('996')) digits = digits.substring(3);
  } else if (digits.startsWith('00996')) {
    digits = digits.substring(5);
  } else if (digits.startsWith('996') && digits.length > kgMobileDigits) {
    digits = digits.substring(3);
  }
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length > kgMobileDigits) {
    digits = digits.substring(0, kgMobileDigits);
  }
  return digits;
}

/// Input formatter for the national part of a Kyrgyz mobile number.
///
/// Unlike `digitsOnly` + a length limit it understands a pasted or typed
/// country code / trunk prefix, so `+996 700 123 456` becomes `700123456`
/// instead of `996700123`.
class KgMobileInputFormatter extends TextInputFormatter {
  const KgMobileInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalizeKgMobileInput(newValue.text);
    if (normalized == newValue.text) return newValue;
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}
