import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../shared/ui_helpers.dart';

class GroupCreationRequestsScreen extends StatefulWidget {
  const GroupCreationRequestsScreen({super.key, required this.api, required this.user});

  final ApiClient api;
  final UserProfile user;

  @override
  State<GroupCreationRequestsScreen> createState() => _GroupCreationRequestsScreenState();
}

class _GroupCreationRequestsScreenState extends State<GroupCreationRequestsScreen> {
  late Future<List<GroupCreationRequest>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.fetchMyGroupCreationRequests();
  }

  Future<void> refresh() async {
    final nextFuture = widget.api.fetchMyGroupCreationRequests();
    setState(() {
      future = nextFuture;
    });
    await nextFuture;
  }

  Future<void> createRequest({GroupCreationRequest? initialRequest}) async {
    final created = await showModalBottomSheet<GroupCreationRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => CreateGroupRequestSheet(api: widget.api, user: widget.user, initialRequest: initialRequest),
    );
    if (created != null) {
      await refresh();
      if (mounted) showAppSnack(context, AppLanguageScope.textOf(context).isKy ? 'Өтүнүч админдерге жөнөтүлдү.' : 'Заявка отправлена администраторам.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(text.myRequests), actions: const [AppSettingsButton()]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => createRequest(), icon: const Icon(Icons.verified_user_outlined), label: Text(text.requestGroup)),
      body: RefreshIndicator(
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
                const Icon(Icons.assignment_outlined, size: 72, color: MobileChatTheme.primary),
                const SizedBox(height: 16),
                Text(text.isKy ? 'Азырынча өтүнүч жок' : 'Пока нет заявок', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(text.isKy ? 'Расмий топ керек болсо, өтүнүч жөнөтүңүз.' : 'Отправьте заявку, если вам нужна официальная группа.', textAlign: TextAlign.center, style: TextStyle(color: context.appColors.textMuted)),
                const SizedBox(height: 20),
                Center(child: FilledButton(onPressed: () => createRequest(), child: Text(text.requestGroup))),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return GroupCreationRequestCard(
                  request: request,
                  number: index + 1,
                  onTap: request.status == 'needs_more_info' ? () => createRequest(initialRequest: request) : null,
                  actions: request.status == 'needs_more_info'
                      ? FilledButton.icon(
                          onPressed: () => createRequest(initialRequest: request),
                          icon: const Icon(Icons.edit_rounded),
                          label: Text(text.isKy ? 'Оңдоп кайра жөнөтүү' : 'Изменить и отправить заново'),
                        )
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class GroupCreationRequestCard extends StatelessWidget {
  const GroupCreationRequestCard({super.key, required this.request, this.actions, this.number, this.onTap});

  final GroupCreationRequest request;
  final Widget? actions;
  final int? number;
  final VoidCallback? onTap;

  Color get statusColor {
    switch (request.status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      case 'needs_more_info':
        return Colors.orange;
      default:
        return MobileChatTheme.primary;
    }
  }

  String statusText(AppText text) {
    switch (request.status) {
      case 'approved':
        return text.isKy ? 'Бекитилди' : 'Одобрено';
      case 'rejected':
        return text.isKy ? 'Четке кагылды' : 'Отклонено';
      case 'needs_more_info':
        return text.isKy ? 'Маалымат керек' : 'Нужна информация';
      default:
        return text.isKy ? 'Күтүүдө' : 'Ожидает';
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (number != null) ...[
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: MobileChatTheme.primary, borderRadius: BorderRadius.circular(999)),
                    child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
                  child: Text(statusText(text), style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
                const Spacer(),
                Text(request.createdAt?.toLocal().toString().split('.').first ?? '', style: TextStyle(color: colors.textMuted, fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              Text(request.groupTitle, style: TextStyle(color: colors.textStrong, fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 4),
              Text(request.organizationName, style: TextStyle(color: colors.textMuted)),
              const SizedBox(height: 8),
              Text('${request.applicantName} · ${request.position}', style: TextStyle(color: colors.textStrong, fontWeight: FontWeight.w700)),
              if (request.groupDescription.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('${text.description}: ${request.groupDescription}', style: TextStyle(color: colors.textStrong)),
              ],
              if (request.reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('${text.isKy ? 'Себеби' : 'Причина'}: ${request.reason}', style: TextStyle(color: colors.textStrong)),
              ],
              if (request.adminComment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: context.appColors.chipBackground, borderRadius: BorderRadius.circular(14)),
                  child: Text('${text.isKy ? 'Админ комментарийи' : 'Комментарий администратора'}: ${request.adminComment}', style: TextStyle(color: colors.textStrong)),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(height: 8),
                Text(text.isKy ? 'Оңдоо үчүн басыңыз.' : 'Нажмите, чтобы изменить данные.', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w700)),
              ],
              if (actions != null) ...[const SizedBox(height: 12), actions!],
            ]),
          ),
        ),
      ),
    );
  }
}

class CreateGroupRequestSheet extends StatefulWidget {
  const CreateGroupRequestSheet({super.key, required this.api, required this.user, this.initialRequest});

  final ApiClient api;
  final UserProfile user;
  final GroupCreationRequest? initialRequest;

  @override
  State<CreateGroupRequestSheet> createState() => _CreateGroupRequestSheetState();
}

class _CreateGroupRequestSheetState extends State<CreateGroupRequestSheet> {
  final applicant = TextEditingController();
  final position = TextEditingController();
  final organization = TextEditingController();
  final organizationType = TextEditingController();
  final region = TextEditingController();
  final officialPhone = TextEditingController();
  final officialEmail = TextEditingController();
  final website = TextEditingController();
  final title = TextEditingController();
  final description = TextEditingController();
  final reason = TextEditingController();
  final documents = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRequest;
    applicant.text = initial?.applicantName.isNotEmpty == true ? initial!.applicantName : widget.user.displayName;
    position.text = initial?.position ?? '';
    organization.text = initial?.organizationName ?? '';
    organizationType.text = initial?.organizationType ?? '';
    region.text = initial?.region ?? '';
    officialPhone.text = initial?.officialPhone.isNotEmpty == true ? initial!.officialPhone : (widget.user.mobile ?? '');
    officialEmail.text = initial?.officialEmail ?? '';
    website.text = initial?.website ?? '';
    title.text = initial?.groupTitle ?? '';
    description.text = initial?.groupDescription ?? '';
    reason.text = initial?.reason ?? '';
    documents.text = initial?.documents ?? '';
  }

  @override
  void dispose() {
    applicant.dispose();
    position.dispose();
    organization.dispose();
    organizationType.dispose();
    region.dispose();
    officialPhone.dispose();
    officialEmail.dispose();
    website.dispose();
    title.dispose();
    description.dispose();
    reason.dispose();
    documents.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final created = await widget.api.createGroupCreationRequest(
        applicantName: applicant.text.trim(),
        position: position.text.trim(),
        organizationName: organization.text.trim(),
        organizationType: organizationType.text.trim(),
        region: region.text.trim(),
        officialPhone: officialPhone.text.trim(),
        officialEmail: officialEmail.text.trim(),
        website: website.text.trim(),
        groupTitle: title.text.trim(),
        groupDescription: description.text.trim(),
        reason: reason.text.trim(),
        documents: documents.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    if (organizationType.text.isEmpty) organizationType.text = text.isKy ? 'Мамлекеттик уюм' : 'Государственная организация';
    final isResubmit = widget.initialRequest != null;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(isResubmit ? (text.isKy ? 'Өтүнүчтү оңдоо' : 'Изменить заявку') : (text.isKy ? 'Расмий топко өтүнүч' : 'Заявка на официальную группу'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (widget.initialRequest?.adminComment.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            InfoBanner(message: '${text.isKy ? 'Админ комментарийи' : 'Комментарий администратора'}: ${widget.initialRequest!.adminComment}'),
          ],
          const SizedBox(height: 16),
          _field(applicant, text.isKy ? 'Аты-жөнү' : 'ФИО'),
          _field(position, text.isKy ? 'Кызматы' : 'Должность'),
          _field(organization, text.isKy ? 'Уюмдун аталышы' : 'Название организации'),
          _field(organizationType, text.isKy ? 'Уюмдун түрү' : 'Тип организации'),
          _field(region, text.isKy ? 'Шаар / аймак' : 'Город / регион'),
          _field(officialPhone, text.isKy ? 'Расмий телефон' : 'Официальный телефон'),
          _field(officialEmail, text.isKy ? 'Расмий email' : 'Официальный email'),
          _field(website, text.isKy ? 'Веб-сайт' : 'Сайт'),
          _field(title, text.isKy ? 'Топтун аталышы' : 'Название группы'),
          _field(description, text.description, lines: 2),
          _field(reason, text.isKy ? 'Себеби' : 'Причина', lines: 3),
          _field(documents, text.isKy ? 'Документтер / далил' : 'Документы / подтверждение', lines: 3),
          if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
          const SizedBox(height: 16),
          FilledButton(onPressed: loading ? null : submit, child: Text(loading ? (text.isKy ? 'Жөнөтүлүп жатат...' : 'Отправляется...') : (isResubmit ? (text.isKy ? 'Кайра жөнөтүү' : 'Отправить заново') : (text.isKy ? 'Өтүнүч жөнөтүү' : 'Отправить заявку')))),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: controller, minLines: lines, maxLines: lines, decoration: InputDecoration(labelText: label)),
    );
  }
}
