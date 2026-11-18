import 'package:flutter/material.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/blocked_users.dart';
import '../../data/safety.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';

String reportReasonLabel(AppText text, String reason) {
  switch (reason) {
    case ReportReason.spam:
      return 'Спам';
    case ReportReason.abuse:
      return text.isKy ? 'Кордоо же куугунтуктоо' : 'Оскорбления или травля';
    case ReportReason.illegal:
      return text.isKy ? 'Мыйзамсыз мазмун' : 'Незаконный контент';
    case ReportReason.other:
      return text.isKy ? 'Башка' : 'Другое';
    default:
      return reason;
  }
}

String reportTargetLabel(AppText text, String targetType) {
  switch (targetType) {
    case ReportTargetType.publicRequest:
      return text.isKy ? 'Жарыя' : 'Публикация';
    case ReportTargetType.comment:
      return text.isKy ? 'Комментарий' : 'Комментарий';
    case ReportTargetType.message:
      return text.isKy ? 'Билдирүү' : 'Сообщение';
    case ReportTargetType.user:
      return text.isKy ? 'Колдонуучу' : 'Пользователь';
    default:
      return targetType;
  }
}

String featureUnavailableMessage(AppText text) => text.isKy
    ? 'Бул функция азырынча жеткиликсиз. Кийинчерээк аракет кылыңыз.'
    : 'Эта функция пока недоступна. Попробуйте позже.';

String reportSentMessage(AppText text) => text.isKy
    ? 'Даттануу жөнөтүлдү. Рахмат, модераторлор карап чыгат.'
    : 'Жалоба отправлена. Спасибо, модераторы её рассмотрят.';

String _errorMessage(BuildContext context, Object error) {
  final text = AppLanguageScope.textOf(context);
  if (error is FeatureUnavailableException) {
    return featureUnavailableMessage(text);
  }
  return localizedMessage(context, error.toString());
}

/// Bottom sheet with the report reason picker and optional details.
class ReportSheet extends StatefulWidget {
  const ReportSheet({
    super.key,
    required this.targetType,
    required this.onSubmit,
  });

  final String targetType;

  /// Sends the report. Throwing keeps the sheet open and shows the error,
  /// except [FeatureUnavailableException], which closes the sheet so the
  /// caller can explain that reporting is not available yet.
  final Future<void> Function(String reason, String details) onSubmit;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final detailsController = TextEditingController();
  String? reason;
  bool sending = false;
  String? error;

  @override
  void dispose() {
    detailsController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final selected = reason;
    if (selected == null || sending) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.onSubmit(selected, detailsController.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on FeatureUnavailableException {
      // The caller explains that the feature is not available yet.
      if (mounted) Navigator.of(context).pop(false);
    } catch (e) {
      if (mounted) setState(() => error = _errorMessage(context, e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return KoomSheetFrame(
      title: text.isKy ? 'Даттануу' : 'Пожаловаться',
      subtitle:
          '${reportTargetLabel(text, widget.targetType)} · ${text.isKy ? 'Себебин тандаңыз. Даттанууну модераторлор көрөт.' : 'Выберите причину. Жалобу увидят модераторы.'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioGroup<String>(
            groupValue: reason,
            onChanged: (value) {
              if (sending) return;
              setState(() {
                reason = value;
                error = null;
              });
            },
            child: Column(
              children: [
                for (final value in ReportReason.values)
                  RadioListTile<String>(
                    key: ValueKey('report_reason_$value'),
                    value: value,
                    enabled: !sending,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      reportReasonLabel(text, value),
                      style: TextStyle(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('report_details_field'),
            controller: detailsController,
            enabled: !sending,
            minLines: 2,
            maxLines: 5,
            maxLength: maxReportDetailsLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: text.isKy
                  ? 'Кошумча маалымат (милдеттүү эмес)'
                  : 'Подробности (необязательно)',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            ErrorBanner(message: error!),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('report_submit_button'),
            onPressed: reason == null || sending ? null : submit,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.flag_outlined),
            label: Text(
              text.isKy ? 'Даттанууну жөнөтүү' : 'Отправить жалобу',
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the report sheet for a piece of content or a user and shows the
/// confirmation snackbar on success.
Future<void> showReportSheet(
  BuildContext context, {
  required SafetyEndpoints api,
  required String targetType,
  required String targetId,
}) async {
  if (targetId.trim().isEmpty) return;
  final text = AppLanguageScope.textOf(context);
  var unavailable = false;
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).cardColor,
    builder: (_) => ReportSheet(
      targetType: targetType,
      onSubmit: (reason, details) async {
        try {
          await api.submitReport(
            targetType: targetType,
            targetId: targetId,
            reason: reason,
            details: details,
          );
        } on FeatureUnavailableException {
          unavailable = true;
          rethrow;
        }
      },
    ),
  );
  if (!context.mounted) return;
  if (unavailable) {
    showAppSnack(context, featureUnavailableMessage(text));
  } else if (sent == true) {
    showAppSnack(context, reportSentMessage(text));
  }
}

/// Asks for confirmation, then blocks [userId] and hides their content.
Future<bool> confirmAndBlockUser(
  BuildContext context, {
  required SafetyEndpoints api,
  required String userId,
  required String displayName,
  BlockedUsersController? controller,
}) async {
  if (userId.trim().isEmpty) return false;
  final text = AppLanguageScope.textOf(context);
  final name = displayName.trim().isEmpty
      ? (text.isKy ? 'колдонуучу' : 'пользователя')
      : displayName.trim();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(text.isKy ? '$name бөгөттөлсүнбү?' : 'Заблокировать $name?'),
      content: Text(
        text.isKy
            ? 'Бул колдонуучунун жарыялары, комментарийлери жана билдирүүлөрү сизге көрсөтүлбөйт. Бөгөттү профилдеги «Бөгөттөлгөн колдонуучулар» бөлүмүнөн алып салсаңыз болот.'
            : 'Публикации, комментарии и сообщения этого пользователя будут скрыты для вас. Разблокировать можно в профиле, в разделе «Заблокированные пользователи».',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(text.isKy ? 'Жокко чыгаруу' : 'Отмена'),
        ),
        FilledButton(
          key: const ValueKey('confirm_block_button'),
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(text.isKy ? 'Бөгөттөө' : 'Заблокировать'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    await (controller ?? BlockedUsersController.instance).block(
      api,
      userId: userId,
      displayName: displayName,
    );
    if (context.mounted) {
      showAppSnack(
        context,
        text.isKy ? 'Колдонуучу бөгөттөлдү.' : 'Пользователь заблокирован.',
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) showAppSnack(context, _errorMessage(context, error));
    return false;
  }
}

/// Values used by safety popup menu entries.
abstract final class SafetyMenuAction {
  static const report = 'safety_report';
  static const reportUser = 'safety_report_user';
  static const block = 'safety_block';

  static bool isSafetyAction(String value) =>
      value == report || value == reportUser || value == block;
}

/// Content (and its author) that can be reported or blocked.
class SafetyTarget {
  const SafetyTarget({
    required this.targetType,
    required this.targetId,
    required this.authorId,
    required this.authorName,
    required this.currentUserId,
  });

  final String targetType;
  final String targetId;
  final String authorId;
  final String authorName;
  final String currentUserId;

  bool get isOwn =>
      authorId.trim().isNotEmpty && authorId.trim() == currentUserId.trim();

  /// Reporting is offered for anyone else's content (including content of
  /// deleted accounts); never for one's own.
  bool get canReport => !isOwn && targetId.trim().isNotEmpty;

  /// Reporting / blocking the author needs a known, different author.
  bool get canActOnAuthor => !isOwn && authorId.trim().isNotEmpty;
}

List<PopupMenuEntry<String>> safetyMenuEntries(
  AppText text,
  SafetyTarget target,
) {
  if (!target.canReport) return const [];
  Widget row(IconData icon, String label, {Color? color}) => Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Flexible(child: Text(label, style: TextStyle(color: color))),
        ],
      );
  return [
    PopupMenuItem<String>(
      key: const ValueKey('safety_report_item'),
      value: SafetyMenuAction.report,
      child: row(Icons.flag_outlined, text.isKy ? 'Даттануу' : 'Пожаловаться'),
    ),
    if (target.canActOnAuthor &&
        target.targetType != ReportTargetType.user) ...[
      PopupMenuItem<String>(
        key: const ValueKey('safety_report_user_item'),
        value: SafetyMenuAction.reportUser,
        child: row(
          Icons.person_off_outlined,
          text.isKy ? 'Колдонуучуга даттануу' : 'Пожаловаться на пользователя',
        ),
      ),
    ],
    if (target.canActOnAuthor)
      PopupMenuItem<String>(
        key: const ValueKey('safety_block_item'),
        value: SafetyMenuAction.block,
        child: row(
          Icons.block_rounded,
          text.isKy ? 'Бөгөттөө' : 'Заблокировать',
          color: Colors.red.shade700,
        ),
      ),
  ];
}

Future<void> handleSafetyMenuAction(
  BuildContext context,
  String action, {
  required SafetyEndpoints api,
  required SafetyTarget target,
}) async {
  if (!target.canReport) return;
  switch (action) {
    case SafetyMenuAction.report:
      await showReportSheet(
        context,
        api: api,
        targetType: target.targetType,
        targetId: target.targetId,
      );
      break;
    case SafetyMenuAction.reportUser:
      if (!target.canActOnAuthor) return;
      await showReportSheet(
        context,
        api: api,
        targetType: ReportTargetType.user,
        targetId: target.authorId,
      );
      break;
    case SafetyMenuAction.block:
      if (!target.canActOnAuthor) return;
      await confirmAndBlockUser(
        context,
        api: api,
        userId: target.authorId,
        displayName: target.authorName,
      );
      break;
  }
}

/// "More" button with report / block actions. Renders nothing for the
/// current user's own content.
class ContentSafetyMenuButton extends StatelessWidget {
  const ContentSafetyMenuButton({
    super.key,
    required this.api,
    required this.target,
    this.iconSize = 22,
  });

  final SafetyEndpoints api;
  final SafetyTarget target;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (!target.canReport) return const SizedBox.shrink();
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return PopupMenuButton<String>(
      key: ValueKey('safety_menu_${target.targetType}_${target.targetId}'),
      tooltip: text.isKy ? 'Дагы' : 'Ещё',
      iconSize: iconSize,
      icon: Icon(Icons.more_vert_rounded, color: colors.textMuted),
      onSelected: (action) => handleSafetyMenuAction(
        context,
        action,
        api: api,
        target: target,
      ),
      itemBuilder: (_) => safetyMenuEntries(text, target),
    );
  }
}

/// Shown instead of a publication whose author the user has blocked.
class BlockedContentNotice extends StatelessWidget {
  const BlockedContentNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return KoomCard(
      key: const ValueKey('blocked_content_notice'),
      showShadow: false,
      child: KoomEmptyState(
        icon: Icons.block_rounded,
        title: text.isKy ? 'Мазмун жашырылды' : 'Контент скрыт',
        message: text.isKy
            ? 'Сиз бул колдонуучуну бөгөттөдүңүз.'
            : 'Вы заблокировали этого пользователя.',
      ),
    );
  }
}
