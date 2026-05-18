import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/group_statistics.dart';
import '../../data/models.dart';
import '../../data/public_requests_api.dart';
import '../../shared/ui_helpers.dart';

class GroupStatisticsScreen extends StatefulWidget {
  const GroupStatisticsScreen({super.key, required this.api, required this.group});

  final PublicRequestsApi api;
  final ChatGroup group;

  @override
  State<GroupStatisticsScreen> createState() => _GroupStatisticsScreenState();
}

class _GroupStatisticsScreenState extends State<GroupStatisticsScreen> {
  String period = 'month';
  String granularity = 'day';
  late Future<GroupStatistics> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<GroupStatistics> load() => widget.api.fetchStatistics(widget.group.id, period: period, granularity: granularity);

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  void changePeriod(String nextPeriod) {
    setState(() {
      period = nextPeriod;
      granularity = nextPeriod == 'year' ? 'month' : nextPeriod == 'all' ? 'month' : 'day';
      future = load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(text.isKy ? 'Статистика' : 'Статистика'),
        actions: const [AppSettingsButton()],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<GroupStatistics>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return ListView(padding: const EdgeInsets.all(16), children: [ErrorBanner(message: snapshot.error.toString())]);
            final stats = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Text(widget.group.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(text.isKy ? 'Топ боюнча арыздар, сунуштар жана даттануулар.' : 'Заявки, предложения и жалобы по этой группе.', style: TextStyle(color: context.appColors.textMuted)),
                const SizedBox(height: 14),
                _PeriodSelector(period: period, onChanged: changePeriod),
                const SizedBox(height: 16),
                _SummaryGrid(stats: stats),
                const SizedBox(height: 16),
                _RatesCard(stats: stats),
                const SizedBox(height: 16),
                _TimelineCard(stats: stats),
                const SizedBox(height: 16),
                _BreakdownCard(title: text.isKy ? 'Типтер боюнча' : 'По типам', items: stats.byType, labeler: requestTypeLabel),
                const SizedBox(height: 16),
                _BreakdownCard(title: text.isKy ? 'Статус боюнча' : 'По статусам', items: stats.byStatus, labeler: statusLabel),
                const SizedBox(height: 16),
                _BreakdownCard(title: text.isKy ? 'Формат боюнча' : 'По формату', items: stats.byInteractionMode, labeler: interactionLabel),
                const SizedBox(height: 16),
                _OpenRequestsCard(stats: stats),
              ],
            );
          },
        ),
      ),
    );
  }

  String requestTypeLabel(BuildContext context, String key) {
    final text = AppLanguageScope.textOf(context);
    switch (key) {
      case 'announcement': return text.announcement;
      case 'suggestion': return text.suggestion;
      case 'complaint': return text.complaint;
      case 'requirement': return text.requirement;
      case 'problem': return text.problem;
      case 'idea': return text.idea;
      default: return key;
    }
  }

  String statusLabel(BuildContext context, String key) {
    final isKy = AppLanguageScope.textOf(context).isKy;
    switch (key) {
      case 'new': return isKy ? 'Жаңы' : 'Новые';
      case 'under_review': return isKy ? 'Каралууда' : 'На рассмотрении';
      case 'accepted': return isKy ? 'Кабыл алынган' : 'Принятые';
      case 'resolved': return isKy ? 'Чечилген' : 'Решённые';
      case 'rejected': return isKy ? 'Четке кагылган' : 'Отклонённые';
      default: return key;
    }
  }

  String interactionLabel(BuildContext context, String key) {
    final text = AppLanguageScope.textOf(context);
    switch (key) {
      case 'read_only': return text.textOnly;
      case 'vote_only': return text.votingOnly;
      case 'discussion': return text.discussionWithComments;
      default: return key;
    }
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});
  final String period;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isKy = AppLanguageScope.textOf(context).isKy;
    return SegmentedButton<String>(
      selected: {period},
      onSelectionChanged: (value) => onChanged(value.first),
      segments: [
        ButtonSegment(value: 'week', label: Text(isKy ? 'Апта' : 'Неделя')),
        ButtonSegment(value: 'month', label: Text(isKy ? 'Ай' : 'Месяц')),
        ButtonSegment(value: 'year', label: Text(isKy ? 'Жыл' : 'Год')),
        ButtonSegment(value: 'all', label: Text(isKy ? 'Баары' : 'Все')),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats});
  final GroupStatistics stats;

  @override
  Widget build(BuildContext context) {
    final isKy = AppLanguageScope.textOf(context).isKy;
    final items = [
      _Metric(isKy ? 'Бардык заявкалар' : 'Всего заявок', stats.totalRequests.toString(), Icons.assignment_rounded),
      _Metric(isKy ? 'Даттануулар' : 'Жалобы', stats.totalComplaints.toString(), Icons.report_problem_rounded),
      _Metric(isKy ? 'Ачык' : 'Нерешённые', stats.openRequests.toString(), Icons.hourglass_top_rounded),
      _Metric(isKy ? 'Жабылган' : 'Закрытые', stats.closedRequests.toString(), Icons.task_alt_rounded),
      _Metric(isKy ? 'Комментарий' : 'Комментарии', stats.totalComments.toString(), Icons.forum_rounded),
      _Metric(isKy ? 'Добуштар' : 'Голоса', '${stats.supportVotes + stats.opposeVotes}', Icons.how_to_vote_rounded),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.55, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemBuilder: (_, index) => _MetricCard(metric: items[index]),
    );
  }
}

class _Metric {
  const _Metric(this.title, this.value, this.icon);
  final String title;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: colors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(metric.icon, color: MobileChatTheme.primary),
        Text(metric.value, style: TextStyle(color: colors.textStrong, fontSize: 24, fontWeight: FontWeight.w900)),
        Text(metric.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _RatesCard extends StatelessWidget {
  const _RatesCard({required this.stats});
  final GroupStatistics stats;

  @override
  Widget build(BuildContext context) {
    final isKy = AppLanguageScope.textOf(context).isKy;
    return _Panel(title: isKy ? 'Прогресс' : 'Прогресс', child: Column(children: [
      _ProgressLine(title: isKy ? 'Закрыто' : 'Закрыто', percent: stats.closeRate),
      const SizedBox(height: 12),
      _ProgressLine(title: isKy ? 'Решено' : 'Решено', percent: stats.resolveRate),
    ]));
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.title, required this.percent});
  final String title;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text('${percent.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w900, color: MobileChatTheme.primaryDark)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: (percent / 100).clamp(0, 1), minHeight: 10)),
    ]);
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.stats});
  final GroupStatistics stats;

  @override
  Widget build(BuildContext context) {
    final isKy = AppLanguageScope.textOf(context).isKy;
    final maxValue = stats.timeline.fold<int>(1, (max, item) => item.total > max ? item.total : max);
    return _Panel(title: isKy ? 'Динамика' : 'Динамика', child: stats.timeline.isEmpty
        ? Text(isKy ? 'Маалымат жок' : 'Нет данных', style: TextStyle(color: context.appColors.textMuted))
        : Column(children: stats.timeline.map((item) {
            final value = item.total / maxValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(item.bucket, style: const TextStyle(fontWeight: FontWeight.w800)), Text('${item.total}')]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 9)),
                const SizedBox(height: 3),
                Text('${isKy ? 'Ачык' : 'Открыто'}: ${item.open} · ${isKy ? 'Жабык' : 'Закрыто'}: ${item.closed} · ${isKy ? 'Даттануу' : 'Жалобы'}: ${item.complaints}', style: TextStyle(fontSize: 12, color: context.appColors.textMuted)),
              ]),
            );
          }).toList()),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.items, required this.labeler});
  final String title;
  final List<StatisticsBreakdownItem> items;
  final String Function(BuildContext, String) labeler;

  @override
  Widget build(BuildContext context) {
    final isKy = AppLanguageScope.textOf(context).isKy;
    return _Panel(title: title, child: items.isEmpty
        ? Text(isKy ? 'Маалымат жок' : 'Нет данных', style: TextStyle(color: context.appColors.textMuted))
        : Column(children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProgressLine(title: '${labeler(context, item.key)} · ${item.count}', percent: item.percent),
            )).toList()),
    );
  }
}

class _OpenRequestsCard extends StatelessWidget {
  const _OpenRequestsCard({required this.stats});
  final GroupStatistics stats;

  @override
  Widget build(BuildContext context) {
    final isKy = AppLanguageScope.textOf(context).isKy;
    return _Panel(title: isKy ? 'Акыркы чечилбегендер' : 'Последние нерешённые', child: stats.recentOpenRequests.isEmpty
        ? Text(isKy ? 'Чечилбеген заявкалар жок' : 'Нет нерешённых заявок', style: TextStyle(color: context.appColors.textMuted))
        : Column(children: stats.recentOpenRequests.map((request) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(request.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(request.status),
              trailing: Text('${request.commentCount} 💬'),
            )).toList()),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: colors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: colors.textStrong, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}
