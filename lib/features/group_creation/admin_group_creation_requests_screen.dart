import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../shared/ui_helpers.dart';
import 'group_creation_requests_screen.dart';

class AdminGroupCreationRequestsScreen extends StatefulWidget {
  const AdminGroupCreationRequestsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminGroupCreationRequestsScreen> createState() => _AdminGroupCreationRequestsScreenState();
}

class _AdminGroupCreationRequestsScreenState extends State<AdminGroupCreationRequestsScreen> {
  late Future<List<GroupCreationRequest>> future;
  String status = 'pending';

  @override
  void initState() {
    super.initState();
    future = widget.api.fetchAdminGroupCreationRequests(status: status);
  }

  Future<void> refresh() async {
    final nextFuture = widget.api.fetchAdminGroupCreationRequests(status: status);
    setState(() {
      future = nextFuture;
    });
    await nextFuture;
  }

  Future<void> changeStatus(String value) async {
    final nextFuture = widget.api.fetchAdminGroupCreationRequests(status: value);
    setState(() {
      status = value;
      future = nextFuture;
    });
    await nextFuture;
  }

  Future<void> review(GroupCreationRequest request, String action) async {
    final text = AppLanguageScope.textOf(context);
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => _AdminCommentDialog(action: action),
    );
    if (comment == null) return;
    try {
      if (action == 'approve') {
        await widget.api.approveGroupCreationRequest(request.id, adminComment: comment);
      } else if (action == 'reject') {
        await widget.api.rejectGroupCreationRequest(request.id, adminComment: comment);
      } else {
        await widget.api.needMoreInfoForGroupCreationRequest(request.id, adminComment: comment);
      }
      await refresh();
      if (mounted) showAppSnack(context, text.isKy ? 'Өтүнүч жаңыртылды.' : 'Заявка обновлена.');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(text.adminRequests), actions: const [AppSettingsButton()]),
      body: Column(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'pending', label: Text(text.isKy ? 'Күтүүдө' : 'Ожидает')),
              ButtonSegment(value: 'needs_more_info', label: Text(text.isKy ? 'Маалымат керек' : 'Нужна информация')),
              ButtonSegment(value: 'approved', label: Text(text.isKy ? 'Бекитилген' : 'Одобрено')),
              ButtonSegment(value: 'rejected', label: Text(text.isKy ? 'Четке кагылган' : 'Отклонено')),
              ButtonSegment(value: '', label: Text(text.isKy ? 'Баары' : 'Все')),
            ],
            selected: {status},
            onSelectionChanged: (value) {
              changeStatus(value.first);
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: FutureBuilder<List<GroupCreationRequest>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return ListView(padding: const EdgeInsets.all(24), children: [ErrorBanner(message: snapshot.error.toString())]);
                final requests = snapshot.data ?? const [];
                if (requests.isEmpty) {
                  return ListView(padding: const EdgeInsets.all(24), children: [
                    const SizedBox(height: 120),
                    const Icon(Icons.admin_panel_settings_outlined, size: 72, color: MobileChatTheme.primary),
                    const SizedBox(height: 16),
                    Text(text.isKy ? 'Өтүнүч табылган жок' : 'Заявки не найдены', textAlign: TextAlign.center, style: TextStyle(color: context.appColors.textStrong)),
                  ]);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final canReview = request.status == 'pending' || request.status == 'needs_more_info';
                    return GroupCreationRequestCard(
                      request: request,
                      number: index + 1,
                      actions: canReview
                          ? Wrap(spacing: 8, runSpacing: 8, children: [
                              FilledButton.icon(onPressed: () => review(request, 'approve'), icon: const Icon(Icons.check_rounded), label: Text(text.isKy ? 'Бекитүү' : 'Одобрить')),
                              OutlinedButton.icon(onPressed: () => review(request, 'need_info'), icon: const Icon(Icons.info_outline_rounded), label: Text(text.isKy ? 'Маалымат керек' : 'Нужна информация')),
                              OutlinedButton.icon(onPressed: () => review(request, 'reject'), icon: const Icon(Icons.close_rounded), label: Text(text.isKy ? 'Четке кагуу' : 'Отклонить')),
                            ])
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _AdminCommentDialog extends StatefulWidget {
  const _AdminCommentDialog({required this.action});

  final String action;

  @override
  State<_AdminCommentDialog> createState() => _AdminCommentDialogState();
}

class _AdminCommentDialogState extends State<_AdminCommentDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String title(AppText text) {
    switch (widget.action) {
      case 'approve':
        return text.isKy ? 'Өтүнүчтү бекитүү' : 'Одобрить заявку';
      case 'reject':
        return text.isKy ? 'Өтүнүчтү четке кагуу' : 'Отклонить заявку';
      default:
        return text.isKy ? 'Кошумча маалымат суроо' : 'Запросить информацию';
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return AlertDialog(
      title: Text(title(text)),
      content: TextField(controller: controller, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: text.isKy ? 'Админ комментарийи' : 'Комментарий администратора')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(text.isKy ? 'Жокко чыгаруу' : 'Отмена')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(text.isKy ? 'Сактоо' : 'Сохранить')),
      ],
    );
  }
}
