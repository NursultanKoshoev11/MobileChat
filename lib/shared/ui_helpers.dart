import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/localization.dart';
import '../app/theme.dart';

String avatarText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.substring(0, 1).toUpperCase();
}

String compactTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

int? _cp1251ByteForRune(int codePoint) {
  if (codePoint <= 0xff) return codePoint;
  if (codePoint >= 0x0410 && codePoint <= 0x044f) {
    return 0xc0 + (codePoint - 0x0410);
  }

  switch (codePoint) {
    case 0x0402:
      return 0x80;
    case 0x0403:
      return 0x81;
    case 0x201a:
      return 0x82;
    case 0x0453:
      return 0x83;
    case 0x201e:
      return 0x84;
    case 0x2026:
      return 0x85;
    case 0x2020:
      return 0x86;
    case 0x2021:
      return 0x87;
    case 0x20ac:
      return 0x88;
    case 0x2030:
      return 0x89;
    case 0x0409:
      return 0x8a;
    case 0x2039:
      return 0x8b;
    case 0x040a:
      return 0x8c;
    case 0x040c:
      return 0x8d;
    case 0x040b:
      return 0x8e;
    case 0x040f:
      return 0x8f;
    case 0x0452:
      return 0x90;
    case 0x2018:
      return 0x91;
    case 0x2019:
      return 0x92;
    case 0x201c:
      return 0x93;
    case 0x201d:
      return 0x94;
    case 0x2022:
      return 0x95;
    case 0x2013:
      return 0x96;
    case 0x2014:
      return 0x97;
    case 0x2122:
      return 0x99;
    case 0x0459:
      return 0x9a;
    case 0x203a:
      return 0x9b;
    case 0x045a:
      return 0x9c;
    case 0x045c:
      return 0x9d;
    case 0x045b:
      return 0x9e;
    case 0x045f:
      return 0x9f;
    case 0x00a0:
      return 0xa0;
    case 0x040e:
      return 0xa1;
    case 0x045e:
      return 0xa2;
    case 0x0408:
      return 0xa3;
    case 0x00a4:
      return 0xa4;
    case 0x0490:
      return 0xa5;
    case 0x00a6:
      return 0xa6;
    case 0x00a7:
      return 0xa7;
    case 0x0401:
      return 0xa8;
    case 0x00a9:
      return 0xa9;
    case 0x0404:
      return 0xaa;
    case 0x00ab:
      return 0xab;
    case 0x00ac:
      return 0xac;
    case 0x00ad:
      return 0xad;
    case 0x00ae:
      return 0xae;
    case 0x0407:
      return 0xaf;
    case 0x00b0:
      return 0xb0;
    case 0x00b1:
      return 0xb1;
    case 0x0406:
      return 0xb2;
    case 0x0456:
      return 0xb3;
    case 0x0491:
      return 0xb4;
    case 0x00b5:
      return 0xb5;
    case 0x00b6:
      return 0xb6;
    case 0x00b7:
      return 0xb7;
    case 0x0451:
      return 0xb8;
    case 0x2116:
      return 0xb9;
    case 0x0454:
      return 0xba;
    case 0x00bb:
      return 0xbb;
    case 0x0458:
      return 0xbc;
    case 0x0405:
      return 0xbd;
    case 0x0455:
      return 0xbe;
    case 0x0457:
      return 0xbf;
  }
  return null;
}

int _mojibakeScore(String value) {
  final brokenPairs = RegExp(r'[РСТУ][\u0400-\u04ff\u00a0-\u00bf]');
  return brokenPairs.allMatches(value).length +
      'Ð'.allMatches(value).length +
      'Ñ'.allMatches(value).length +
      '�'.allMatches(value).length;
}

int _cyrillicScore(String value) =>
    RegExp(r'[\u0400-\u04ff]').allMatches(value).length;

String _repairMojibake(String value) {
  if (value.isEmpty ||
      !(value.contains('Р') ||
          value.contains('С') ||
          value.contains('Т') ||
          value.contains('У') ||
          value.contains('Ð') ||
          value.contains('Ñ'))) {
    return value;
  }

  final bytes = <int>[];
  for (final rune in value.runes) {
    final b = _cp1251ByteForRune(rune);
    if (b == null) return value;
    bytes.add(b);
  }

  try {
    final decoded = utf8.decode(bytes, allowMalformed: false);
    if (_mojibakeScore(decoded) < _mojibakeScore(value) &&
        _cyrillicScore(decoded) >= _cyrillicScore(value) ~/ 2) {
      return decoded;
    }
  } on FormatException {
    return value;
  }

  return value;
}

String _formatMuteUntil(String value) {
  try {
    final dt = DateTime.parse(value.trim()).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  } catch (_) {
    final v = value.trim();
    if (v.length >= 16 && v.contains('T')) {
      return '${v.substring(8, 10)}.${v.substring(5, 7)}.${v.substring(0, 4)} ${v.substring(11, 16)}';
    }
    return v;
  }
}

String localizedMessage(BuildContext context, String message) {
  final repairedMessage = _repairMojibake(message);
  final text = AppLanguageScope.textOf(context);
  final lower = repairedMessage.toLowerCase();

  if (lower.contains('comments are blocked until')) {
    final raw = repairedMessage
        .replaceFirst(
            RegExp(r'comments are blocked until\s*', caseSensitive: false), '')
        .trim();
    final value = _formatMuteUntil(raw);
    return text.isKy
        ? '\u041a\u043e\u043c\u043c\u0435\u043d\u0442\u0430\u0440\u0438\u0439 \u0436\u0430\u0437\u0443\u0443 $value \u0447\u0435\u0439\u0438\u043d \u0431\u04e9\u0433\u04e9\u0442\u0442\u04e9\u043b\u0433\u04e9\u043d.'
        : '\u041a\u043e\u043c\u043c\u0435\u043d\u0442\u0430\u0440\u0438\u0438 \u0437\u0430\u0431\u043b\u043e\u043a\u0438\u0440\u043e\u0432\u0430\u043d\u044b \u0434\u043e $value.';
  }
  if (lower.contains('comments are blocked')) {
    return text.isKy
        ? '\u041a\u043e\u043c\u043c\u0435\u043d\u0442\u0430\u0440\u0438\u0439 \u0436\u0430\u0437\u0443\u0443 \u0431\u04e9\u0433\u04e9\u0442\u0442\u04e9\u043b\u0433\u04e9\u043d.'
        : '\u041a\u043e\u043c\u043c\u0435\u043d\u0442\u0430\u0440\u0438\u0438 \u0437\u0430\u0431\u043b\u043e\u043a\u0438\u0440\u043e\u0432\u0430\u043d\u044b.';
  }

  if (lower.contains(String.fromCharCodes([99,111,110,116,101,110,116,32,105,115,32,116,101,109,112,111,114,97,114,105,108,121,32,108,105,109,105,116,101,100]))) {
    return text.isKy
        ? 'Модерация көп жолу четке каккандыктан, билдирүү убактылуу чектелди. Бир аздан кийин аракет кылыңыз.'
        : 'Сообщения временно ограничены после частых отклонений модерацией. Попробуйте позже.';
  }
  if (lower.contains(String.fromCharCodes([99,111,110,116,101,110,116,32,105,115,32,110,111,116,32,97,108,108,111,119,101,100]))) {
    return text.isKy
        ? 'Материал модерациядан өткөн жок. Текстти өзгөртүп кайра жөнөтүңүз.'
        : 'Материал не прошёл модерацию. Измените текст и отправьте заново.';
  }

  if (lower.contains('status updated'))
    return text.isKy ? 'Статус жаңыртылды.' : 'Статус обновлён.';
  if (lower.contains('comment deleted'))
    return text.isKy ? 'Комментарий өчүрүлдү.' : 'Комментарий удалён.';
  if (lower.contains('comment added'))
    return text.isKy ? 'Комментарий кошулду.' : 'Комментарий добавлен.';
  if (lower.contains('request updated'))
    return text.isKy ? 'Өтүнүч жаңыртылды.' : 'Заявка обновлена.';
  if (lower.contains('request sent'))
    return text.isKy ? 'Өтүнүч жөнөтүлдү.' : 'Заявка отправлена.';
  if (lower.contains('post published')) return text.postPublished;
  if (lower.contains('invitation sent'))
    return text.isKy ? 'Чакыруу жөнөтүлдү.' : 'Приглашение отправлено.';
  if (lower.contains('invitation accepted'))
    return text.isKy ? 'Чакыруу кабыл алынды.' : 'Приглашение принято.';
  if (lower.contains('invitation declined'))
    return text.isKy ? 'Чакыруу четке кагылды.' : 'Приглашение отклонено.';
  if (lower.contains('session expired'))
    return text.isKy
        ? 'Сессия бүттү. Кайра кириңиз.'
        : 'Сессия истекла. Войдите снова.';
  if (lower.contains('connection timed out'))
    return text.isKy
        ? 'Сервер жооп берген жок. Кайра аракет кылыңыз.'
        : 'Сервер не ответил вовремя. Попробуйте ещё раз.';
  if (lower.contains('network error'))
    return text.isKy
        ? 'Тармак катасы. Интернетти же серверди текшериңиз.'
        : 'Ошибка сети. Проверьте интернет или сервер.';
  if (lower.contains('server error'))
    return text.isKy ? 'Сервер катасы.' : 'Ошибка сервера.';
  if (lower.contains('mobile must be in international format'))
    return text.isKy
        ? 'Номерди эл аралык форматта жазыңыз: +996700123456'
        : 'Введите номер в международном формате: +996700123456';
  if (lower.contains('code is required')) return text.codeRequired;
  if (lower.contains('display_name is required'))
    return text.displayNameRequiredForNewAccount;
  if (lower.contains('display_name must be between'))
    return text.isKy
        ? 'Аты-жөнү 2ден 40 белгиге чейин болушу керек.'
        : 'Имя должно быть от 2 до 40 символов.';
  if (lower.contains('invalid email or password') ||
      lower.contains('invalid credentials'))
    return text.isKy ? 'Маалымат туура эмес.' : 'Неверные данные.';
  if (lower.contains('unauthorized'))
    return text.isKy
        ? 'Кирүү укугу жок. Кайра кириңиз.'
        : 'Нет доступа. Войдите снова.';
  if (lower.contains('forbidden'))
    return text.isKy
        ? 'Бул аракетке уруксат жок.'
        : 'Нет разрешения на это действие.';
  if (lower.contains('title must be between'))
    return text.isKy
        ? 'Аталыш 3төн 80 белгиге чейин болушу керек.'
        : 'Название должно быть от 3 до 80 символов.';
  if (lower.contains('description must be at most'))
    return text.isKy ? 'Сүрөттөмө өтө узун.' : 'Описание слишком длинное.';
  if (lower.contains('text is required'))
    return text.isKy ? 'Текст жазыңыз.' : 'Введите текст.';
  if (lower.contains('body is required'))
    return text.isKy ? 'Текст жазыңыз.' : 'Введите текст.';
  if (lower.contains('not found'))
    return text.isKy ? 'Табылган жок.' : 'Не найдено.';
  if (lower.contains('already'))
    return text.isKy ? 'Бул аракет мурун эле жасалган.' : 'Это уже выполнено.';

  return repairedMessage;
}

void showAppSnack(BuildContext context, String message) {
  final bottomInset = MediaQuery.of(context).viewInsets.bottom;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(localizedMessage(context, message)),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 96),
        duration: const Duration(seconds: 2),
      ),
    );
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A2026) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: dark ? const Color(0xFF7F2D3A) : const Color(0xFFFFCDD2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(localizedMessage(context, message),
                  style: TextStyle(color: colors.textStrong))),
        ],
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF19364A) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: dark ? const Color(0xFF2A5F82) : const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: MobileChatTheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message, style: TextStyle(color: colors.textStrong))),
        ],
      ),
    );
  }
}
