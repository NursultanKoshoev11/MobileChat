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

String localizedMessage(BuildContext context, String message) {
  final text = AppLanguageScope.textOf(context);
  final lower = message.toLowerCase();

  if (lower.contains('status updated')) return text.isKy ? 'Статус жаңыртылды.' : 'Статус обновлён.';
  if (lower.contains('comment deleted')) return text.isKy ? 'Комментарий өчүрүлдү.' : 'Комментарий удалён.';
  if (lower.contains('comment added')) return text.isKy ? 'Комментарий кошулду.' : 'Комментарий добавлен.';
  if (lower.contains('request updated')) return text.isKy ? 'Өтүнүч жаңыртылды.' : 'Заявка обновлена.';
  if (lower.contains('request sent')) return text.isKy ? 'Өтүнүч жөнөтүлдү.' : 'Заявка отправлена.';
  if (lower.contains('post published')) return text.postPublished;
  if (lower.contains('invitation sent')) return text.isKy ? 'Чакыруу жөнөтүлдү.' : 'Приглашение отправлено.';
  if (lower.contains('invitation accepted')) return text.isKy ? 'Чакыруу кабыл алынды.' : 'Приглашение принято.';
  if (lower.contains('invitation declined')) return text.isKy ? 'Чакыруу четке кагылды.' : 'Приглашение отклонено.';
  if (lower.contains('session expired')) return text.isKy ? 'Сессия бүттү. Кайра кириңиз.' : 'Сессия истекла. Войдите снова.';
  if (lower.contains('connection timed out')) return text.isKy ? 'Сервер жооп берген жок. Кайра аракет кылыңыз.' : 'Сервер не ответил вовремя. Попробуйте ещё раз.';
  if (lower.contains('network error')) return text.isKy ? 'Тармак катасы. Интернетти же серверди текшериңиз.' : 'Ошибка сети. Проверьте интернет или сервер.';
  if (lower.contains('server error')) return text.isKy ? 'Сервер катасы.' : 'Ошибка сервера.';
  if (lower.contains('mobile must be in international format')) return text.isKy ? 'Номерди эл аралык форматта жазыңыз: +996700123456' : 'Введите номер в международном формате: +996700123456';
  if (lower.contains('code is required')) return text.codeRequired;
  if (lower.contains('display_name is required')) return text.displayNameRequiredForNewAccount;
  if (lower.contains('display_name must be between')) return text.isKy ? 'Аты-жөнү 2ден 40 белгиге чейин болушу керек.' : 'Имя должно быть от 2 до 40 символов.';
  if (lower.contains('invalid email or password') || lower.contains('invalid credentials')) return text.isKy ? 'Маалымат туура эмес.' : 'Неверные данные.';
  if (lower.contains('unauthorized')) return text.isKy ? 'Кирүү укугу жок. Кайра кириңиз.' : 'Нет доступа. Войдите снова.';
  if (lower.contains('forbidden')) return text.isKy ? 'Бул аракетке уруксат жок.' : 'Нет разрешения на это действие.';
  if (lower.contains('title must be between')) return text.isKy ? 'Аталыш 3төн 80 белгиге чейин болушу керек.' : 'Название должно быть от 3 до 80 символов.';
  if (lower.contains('description must be at most')) return text.isKy ? 'Сүрөттөмө өтө узун.' : 'Описание слишком длинное.';
  if (lower.contains('text is required')) return text.isKy ? 'Текст жазыңыз.' : 'Введите текст.';
  if (lower.contains('body is required')) return text.isKy ? 'Текст жазыңыз.' : 'Введите текст.';
  if (lower.contains('not found')) return text.isKy ? 'Табылган жок.' : 'Не найдено.';
  if (lower.contains('already')) return text.isKy ? 'Бул аракет мурун эле жасалган.' : 'Это уже выполнено.';

  return message;
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
        border: Border.all(color: dark ? const Color(0xFF7F2D3A) : const Color(0xFFFFCDD2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(localizedMessage(context, message), style: TextStyle(color: colors.textStrong))),
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
        border: Border.all(color: dark ? const Color(0xFF2A5F82) : const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: MobileChatTheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: colors.textStrong))),
        ],
      ),
    );
  }
}
