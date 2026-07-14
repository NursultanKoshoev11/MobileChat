import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/group_statistics.dart';
import '../../data/models.dart';
import '../../data/public_requests_api.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';

class GroupStatisticsScreen extends StatefulWidget {
  const GroupStatisticsScreen(
      {super.key, required this.api, required this.group});

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

  Future<GroupStatistics> load() => widget.api.fetchStatistics(widget.group.id,
      period: period, granularity: granularity);

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  void changePeriod(String nextPeriod) {
    setState(() {
      period = nextPeriod;
      granularity = nextPeriod == 'year'
          ? 'month'
          : nextPeriod == 'all'
              ? 'month'
              : 'day';
      future = load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      key: const ValueKey('group_statistics_screen'),
      appBar: AppBar(
        title: Text(text.isKy ? 'Статистика' : 'Статистика'),
        actions: const [AppSettingsButton()],
      ),
      body: KoomPageBackground(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: FutureBuilder<GroupStatistics>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 210),
                    Center(child: CircularProgressIndicator()),
                  ],
                );
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [ErrorBanner(message: snapshot.error.toString())],
                );
              }
              final stats = snapshot.data!;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  KoomCard(
                    gradient: MobileChatTheme.brandGradient,
                    borderColor: Colors.white.withValues(alpha: 0.14),
                    child: Row(
                      children: [
                        KoomAvatar(
                          label: widget.group.title,
                          radius: 27,
                          background: Colors.white.withValues(alpha: 0.16),
                          icon: Icons.analytics_rounded,
                          imageBytes: widget.group.avatarBytes,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.group.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                text.isKy
                                    ? 'Коомчулуктун активдүүлүгү жана жыйынтыктары'
                                    : 'Активность и результаты сообщества',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _PeriodSelector(period: period, onChanged: changePeriod),
                  const SizedBox(height: 16),
                  _SummaryGrid(stats: stats),
                  const SizedBox(height: 16),
                  _RatesCard(stats: stats),
                  const SizedBox(height: 16),
                  _TimelineCard(stats: stats),
                  const SizedBox(height: 16),
                  _BreakdownCard(
                      title: text.isKy ? 'Типтер боюнча' : 'По типам',
                      items: stats.byType,
                      labeler: requestTypeLabel),
                  const SizedBox(height: 16),
                  _BreakdownCard(
                      title: text.isKy ? 'Статус боюнча' : 'По статусам',
                      items: stats.byStatus,
                      labeler: statusLabel),
                  const SizedBox(height: 16),
                  _BreakdownCard(
                      title: text.isKy ? 'Формат боюнча' : 'По формату',
                      items: stats.byInteractionMode,
                      labeler: interactionLabel),
                  const SizedBox(height: 16),
                  _OpenRequestsCard(stats: stats),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String requestTypeLabel(BuildContext context, String key) {
    final text = AppLanguageScope.textOf(context);
    switch (key) {
      case 'announcement':
        return text.announcement;
      case 'suggestion':
        return text.suggestion;
      case 'complaint':
        return text.complaint;
      case 'requirement':
        return text.requirement;
      case 'problem':
        return text.problem;
      case 'idea':
        return text.idea;
      default:
        return key;
    }
  }

  String statusLabel(BuildContext context, String key) {
    final isKy = AppLanguageScope.textOf(context).isKy;
    switch (key) {
      case 'new':
        return isKy ? 'Жаңы' : 'Новые';
      case 'under_review':
        return isKy ? 'Каралууда' : 'На рассмотрении';
      case 'accepted':
        return isKy ? 'Кабыл алынган' : 'Принятые';
      case 'resolved':
        return isKy ? 'Чечилген' : 'Решённые';
      case 'rejected':
        return isKy ? 'Четке кагылган' : 'Отклонённые';
      default:
        return key;
    }
  }

  String interactionLabel(BuildContext context, String key) {
    final text = AppLanguageScope.textOf(context);
    switch (key) {
      case 'read_only':
        return text.textOnly;
      case 'vote_only':
        return text.votingOnly;
      case 'discussion':
        return text.discussionWithComments;
      default:
        return key;
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
    final items = <(String, String)>[
      ('week', isKy ? 'Апта' : 'Неделя'),
      ('month', isKy ? 'Ай' : 'Месяц'),
      ('year', isKy ? 'Жыл' : 'Год'),
      ('all', isKy ? 'Баары' : 'Все'),
    ];
    return KoomCard(
      showShadow: false,
      padding: const EdgeInsets.all(5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 300 ? 2 : 4;
          const spacing = 4.0;
          final itemWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: items.map((item) {
              final selected = item.$1 == period;
              return SizedBox(
                width: itemWidth,
                child: Material(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () => onChanged(item.$1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 11,
                      ),
                      child: Text(
                        item.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : context.appColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
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
      _Metric(isKy ? 'Бардык заявкалар' : 'Всего заявок',
          stats.totalRequests.toString(), Icons.assignment_rounded),
      _Metric(isKy ? 'Даттануулар' : 'Жалобы', stats.totalComplaints.toString(),
          Icons.report_problem_rounded),
      _Metric(isKy ? 'Ачык' : 'Нерешённые', stats.openRequests.toString(),
          Icons.hourglass_top_rounded),
      _Metric(isKy ? 'Жабылган' : 'Закрытые', stats.closedRequests.toString(),
          Icons.task_alt_rounded),
      _Metric(isKy ? 'Комментарий' : 'Комментарии',
          stats.totalComments.toString(), Icons.forum_rounded),
      _Metric(
          isKy ? 'Добуштар' : 'Голоса',
          '${stats.supportVotes + stats.opposeVotes}',
          Icons.how_to_vote_rounded),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 310
            ? 1
            : constraints.maxWidth < 760
                ? 2
                : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 126,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (_, index) => _MetricCard(metric: items[index]),
        );
      },
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
    return KoomCard(
      padding: const EdgeInsets.all(14),
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(metric.icon,
                color: Theme.of(context).colorScheme.primary, size: 19),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              maxLines: 1,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(metric.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _RatesCard extends StatelessWidget {
  const _RatesCard({required this.stats});
  final GroupStatistics stats;

  @override
  Widget build(BuildContext context) {
    final isKy = AppLanguageScope.textOf(context).isKy;
    return _Panel(
        title: isKy ? 'Прогресс' : 'Прогресс',
        child: Column(children: [
          _ProgressLine(
              title: isKy ? 'Закрыто' : 'Закрыто', percent: stats.closeRate),
          const SizedBox(height: 12),
          _ProgressLine(
              title: isKy ? 'Решено' : 'Решено', percent: stats.resolveRate),
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
      Row(children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${percent.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: MobileChatTheme.primaryDark,
          ),
        ),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1), minHeight: 10)),
    ]);
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.stats});
  final GroupStatistics stats;

  @override
  Widget build(BuildContext context) {
    final isKy = AppLanguageScope.textOf(context).isKy;
    final maxValue = stats.timeline
        .fold<int>(1, (max, item) => item.total > max ? item.total : max);
    return _Panel(
      title: isKy ? 'Динамика' : 'Динамика',
      child: stats.timeline.isEmpty
          ? Text(isKy ? 'Маалымат жок' : 'Нет данных',
              style: TextStyle(color: context.appColors.textMuted))
          : Column(
              children: stats.timeline.map((item) {
              final value = item.total / maxValue;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.bucket,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${item.total}'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                              value: value.clamp(0, 1), minHeight: 9)),
                      const SizedBox(height: 3),
                      Text(
                          '${isKy ? 'Ачык' : 'Открыто'}: ${item.open} · ${isKy ? 'Жабык' : 'Закрыто'}: ${item.closed} · ${isKy ? 'Даттануу' : 'Жалобы'}: ${item.complaints}',
                          style: TextStyle(
                              fontSize: 12,
                              color: context.appColors.textMuted)),
                    ]),
              );
            }).toList()),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard(
      {required this.title, required this.items, required this.labeler});
  final String title;
  final List<StatisticsBreakdownItem> items;
  final String Function(BuildContext, String) labeler;

  @override
  Widget build(BuildContext context) {
    final isKy = AppLanguageScope.textOf(context).isKy;
    return _Panel(
      title: title,
      child: items.isEmpty
          ? Text(isKy ? 'Маалымат жок' : 'Нет данных',
              style: TextStyle(color: context.appColors.textMuted))
          : Column(
              children: items
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProgressLine(
                            title:
                                '${labeler(context, item.key)} · ${item.count}',
                            percent: item.percent),
                      ))
                  .toList()),
    );
  }
}

class _OpenRequestsCard extends StatelessWidget {
  const _OpenRequestsCard({required this.stats});
  final GroupStatistics stats;

  @override
  Widget build(BuildContext context) {
    final isKy = AppLanguageScope.textOf(context).isKy;
    return _Panel(
      title: isKy ? 'Акыркы чечилбегендер' : 'Последние нерешённые',
      child: stats.recentOpenRequests.isEmpty
          ? Text(isKy ? 'Чечилбеген заявкалар жок' : 'Нет нерешённых заявок',
              style: TextStyle(color: context.appColors.textMuted))
          : Column(
              children: stats.recentOpenRequests
                  .map((request) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(request.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(request.status),
                        trailing: Text('${request.commentCount} 💬'),
                      ))
                  .toList()),
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
    return KoomCard(
      padding: const EdgeInsets.all(16),
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
