import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../data/models.dart';
import '../../data/safety.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';
import 'safety_ui.dart';

/// Open user reports for a group (owners/admins) with dismiss / remove actions.
class GroupReportsScreen extends StatefulWidget {
  const GroupReportsScreen({
    super.key,
    required this.api,
    required this.group,
  });

  final SafetyEndpoints api;
  final ChatGroup group;

  @override
  State<GroupReportsScreen> createState() => _GroupReportsScreenState();
}

class _GroupReportsScreenState extends State<GroupReportsScreen> {
  final Set<String> busyIds = <String>{};
  List<ContentReport> reports = const <ContentReport>[];
  bool loading = true;
  bool unavailable = false;
  String? error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.api.fetchGroupReports(widget.group.id);
      loaded.sort((a, b) {
        final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
      reports = loaded;
      unavailable = false;
    } on FeatureUnavailableException {
      unavailable = true;
    } catch (e) {
      if (mounted) error = localizedMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resolve(ContentReport report, String action) async {
    if (busyIds.contains(report.id)) return;
    final text = AppLanguageScope.textOf(context);
    if (action == 'content_removed') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(text.isKy ? 'Мазмунду өчүрөсүзбү?' : 'Удалить контент?'),
          content: Text(
            text.isKy
                ? 'Даттанууга дуушар болгон мазмун топтон өчүрүлөт.'
                : 'Контент, на который пожаловались, будет удалён из группы.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(text.isKy ? 'Жокко чыгаруу' : 'Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(text.isKy ? 'Өчүрүү' : 'Удалить'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => busyIds.add(report.id));
    try {
      await widget.api.resolveReport(report.id, action: action);
      if (!mounted) return;
      setState(() {
        reports = reports.where((item) => item.id != report.id).toList();
      });
      showAppSnack(
        context,
        action == 'dismissed'
            ? (text.isKy ? 'Даттануу четке кагылды.' : 'Жалоба отклонена.')
            : (text.isKy ? 'Мазмун өчүрүлдү.' : 'Контент удалён.'),
      );
    } on FeatureUnavailableException {
      if (mounted) showAppSnack(context, featureUnavailableMessage(text));
    } catch (e) {
      if (mounted) showAppSnack(context, localizedMessage(context, e.toString()));
    } finally {
      if (mounted) setState(() => busyIds.remove(report.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(text.isKy ? 'Даттануулар' : 'Жалобы'),
        actions: [
          IconButton(
            onPressed: loading ? null : refresh,
            tooltip: text.isKy ? 'Жаңылоо' : 'Обновить',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const AppSettingsButton(),
        ],
      ),
      body: KoomPageBackground(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (loading && reports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (unavailable)
                InfoBanner(message: featureUnavailableMessage(text))
              else if (error != null)
                ErrorBanner(message: error!)
              else if (reports.isEmpty)
                KoomCard(
                  showShadow: false,
                  child: KoomEmptyState(
                    icon: Icons.verified_user_outlined,
                    title: text.isKy ? 'Даттануулар жок' : 'Жалоб нет',
                    message: text.isKy
                        ? 'Каралбаган даттануулар азырынча жок.'
                        : 'Нерассмотренных жалоб пока нет.',
                  ),
                )
              else
                for (final report in reports)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReportCard(
                      report: report,
                      loading: busyIds.contains(report.id),
                      onDismiss: () => resolve(report, 'dismissed'),
                      onRemove: () => resolve(report, 'content_removed'),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.loading,
    required this.onDismiss,
    required this.onRemove,
  });

  final ContentReport report;
  final bool loading;
  final VoidCallback onDismiss;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    final created = report.createdAt?.toLocal();
    final createdLabel = created == null
        ? ''
        : '${created.day.toString().padLeft(2, '0')}.${created.month.toString().padLeft(2, '0')}.${created.year} ${compactTime(created)}';
    final reporter = report.reporterDisplayName.trim().isEmpty
        ? (text.isKy ? 'Колдонуучу' : 'Пользователь')
        : report.reporterDisplayName.trim();
    final isUserReport = report.targetType == ReportTargetType.user;

    return KoomCard(
      showShadow: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KoomAvatar(
                label: reportTargetLabel(text, report.targetType),
                radius: 21,
                icon: _iconForTarget(report.targetType),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reportTargetLabel(text, report.targetType),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${text.isKy ? 'Даттанган' : 'Пожаловался'}: $reporter',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (createdLabel.isNotEmpty)
                Text(
                  createdLabel,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              KoomStatusPill(
                label:
                    '${text.isKy ? 'Себеби' : 'Причина'}: ${reportReasonLabel(text, report.reason)}',
                icon: Icons.flag_outlined,
              ),
            ],
          ),
          if (report.details.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(report.details.trim(), style: const TextStyle(height: 1.35)),
          ],
          const SizedBox(height: 14),
          KoomResponsiveActions(
            children: [
              OutlinedButton.icon(
                onPressed: loading ? null : onDismiss,
                icon: const Icon(Icons.close_rounded),
                label: Text(
                  text.isKy ? 'Четке кагуу' : 'Отклонить',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton.icon(
                onPressed: loading ? null : onRemove,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.delete_outline_rounded),
                label: Text(
                  isUserReport
                      ? (text.isKy ? 'Чара көрүү' : 'Принять меры')
                      : (text.isKy ? 'Мазмунду өчүрүү' : 'Удалить контент'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForTarget(String type) {
    switch (type) {
      case ReportTargetType.comment:
        return Icons.mode_comment_outlined;
      case ReportTargetType.publicRequest:
        return Icons.feed_outlined;
      case ReportTargetType.message:
        return Icons.campaign_outlined;
      case ReportTargetType.user:
        return Icons.person_outline_rounded;
      default:
        return Icons.shield_outlined;
    }
  }
}
