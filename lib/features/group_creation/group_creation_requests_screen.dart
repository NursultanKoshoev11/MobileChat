import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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


Future<void> showGroupCreationRequestDetails(BuildContext context, GroupCreationRequest request, {int? number}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).cardColor,
    builder: (_) => _GroupRequestDetailSheet(request: request, number: number),
  );
}

class _GroupRequestDetailSheet extends StatelessWidget {
  const _GroupRequestDetailSheet({required this.request, this.number});

  final GroupCreationRequest request;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final documents = GroupRequestDocuments.tryParse(request.documents);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              if (number != null) ...[
                CircleAvatar(backgroundColor: MobileChatTheme.primary, child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(text.isKy ? 'Өтүнүчтүн толук маалыматы' : 'Полные данные заявки', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 14),
            _detailRow(context, text.isKy ? 'Статус' : 'Статус', request.status),
            _detailRow(context, text.isKy ? 'Дата' : 'Дата', request.createdAt?.toLocal().toString().split('.').first ?? ''),
            _detailRow(context, text.isKy ? 'Аты-жөнү' : 'ФИО', request.applicantName),
            _detailRow(context, text.isKy ? 'Кызматы' : 'Должность', request.position),
            _detailRow(context, text.isKy ? 'Уюм' : 'Организация', request.organizationName),
            _detailRow(context, text.isKy ? 'Уюмдун түрү' : 'Тип организации', request.organizationType),
            _detailRow(context, text.isKy ? 'Аймак' : 'Регион', request.region),
            _detailRow(context, text.isKy ? 'Расмий телефон' : 'Официальный телефон', request.officialPhone),
            _detailRow(context, text.isKy ? 'Расмий email' : 'Официальный email', request.officialEmail),
            if (request.website.isNotEmpty) _detailRow(context, text.isKy ? 'Сайт' : 'Сайт', request.website),
            _detailRow(context, text.isKy ? 'Топтун аталышы' : 'Название группы', request.groupTitle),
            if (request.groupDescription.isNotEmpty) _detailRow(context, text.description, request.groupDescription),
            _detailRow(context, text.isKy ? 'Себеби' : 'Причина', request.reason),
            if (request.adminComment.isNotEmpty) _detailRow(context, text.isKy ? 'Админ комментарийи' : 'Комментарий администратора', request.adminComment),
            const SizedBox(height: 12),
            if (documents.note.isNotEmpty || documents.files.isNotEmpty || (documents == GroupRequestDocuments.empty && request.documents.isNotEmpty))
              _DocumentsPreview(documents: documents, rawDocuments: request.documents, expanded: true)
            else
              Text(text.isKy ? 'Документтер жок.' : 'Документы не приложены.', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final colors = context.appColors;
    final clean = value.trim();
    if (clean.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.surfaceSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        SelectableText(clean, style: TextStyle(color: colors.textStrong, fontWeight: FontWeight.w700)),
      ]),
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
    final documents = GroupRequestDocuments.tryParse(request.documents);
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
              if (documents.note.isNotEmpty || documents.files.isNotEmpty || (documents == GroupRequestDocuments.empty && request.documents.isNotEmpty)) ...[
                const SizedBox(height: 10),
                _DocumentsPreview(documents: documents, rawDocuments: request.documents),
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

class _DocumentsPreview extends StatelessWidget {
  const _DocumentsPreview({required this.documents, required this.rawDocuments, this.expanded = false});

  final GroupRequestDocuments documents;
  final String rawDocuments;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    if (documents == GroupRequestDocuments.empty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.chipBackground, borderRadius: BorderRadius.circular(14)),
        child: Text('${text.isKy ? 'Документтер' : 'Документы'}: $rawDocuments', style: TextStyle(color: colors.textStrong)),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.chipBackground, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text.isKy ? 'Документтер / файлдар' : 'Документы / файлы', style: TextStyle(color: colors.textStrong, fontWeight: FontWeight.w900)),
        if (documents.note.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(documents.note, style: TextStyle(color: colors.textStrong)),
        ],
        if (documents.files.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...documents.files.map((file) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openGroupRequestAttachment(context, file),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(children: [
                      Icon(file.isImage ? Icons.image_outlined : Icons.attach_file_rounded, size: 18, color: MobileChatTheme.primaryDark),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${file.name} · ${formatBytes(file.sizeBytes)}', maxLines: expanded ? 2 : 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textStrong, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 6),
                      Icon(Icons.open_in_full_rounded, size: 16, color: colors.textMuted),
                    ]),
                  ),
                ),
              )),
        ],
      ]),
    );
  }
}


void _openGroupRequestAttachment(BuildContext context, GroupRequestAttachment file) {
  final text = AppLanguageScope.textOf(context);
  try {
    final bytes = base64Decode(file.base64Data);
    if (file.isImage) {
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(children: [
                  Expanded(child: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(formatBytes(file.sizeBytes), style: TextStyle(color: context.appColors.textMuted, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(file.name),
        content: Text(text.isKy ? 'Бул файл алдын ала көрүү үчүн сүрөт эмес. Өлчөмү: ${formatBytes(file.sizeBytes)}.' : 'Этот файл не является изображением для предпросмотра. Размер: ${formatBytes(file.sizeBytes)}.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(text.isKy ? 'Жабуу' : 'Закрыть'))],
      ),
    );
  } catch (error) {
    showAppSnack(context, text.isKy ? 'Файлды ачуу мүмкүн болгон жок.' : 'Не удалось открыть файл.');
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
  static const int maxFileBytes = 3 * 1024 * 1024;
  static const int maxFiles = 3;

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
  final documentNote = TextEditingController();
  final List<GroupRequestAttachment> attachments = [];
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
    final parsedDocuments = GroupRequestDocuments.tryParse(initial?.documents ?? '');
    if (parsedDocuments != GroupRequestDocuments.empty) {
      documentNote.text = parsedDocuments.note;
      attachments.addAll(parsedDocuments.files);
    } else {
      documentNote.text = initial?.documents ?? '';
    }
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
    documentNote.dispose();
    super.dispose();
  }

  Future<void> pickFiles() async {
    if (attachments.length >= maxFiles) {
      setState(() => error = AppLanguageScope.textOf(context).isKy ? '3 файлдан көп кошууга болбойт.' : 'Можно добавить максимум 3 файла.');
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );
      if (result == null) return;
      final next = <GroupRequestAttachment>[];
      for (final picked in result.files) {
        final bytes = picked.bytes;
        if (bytes == null) continue;
        if (bytes.length > maxFileBytes) {
          setState(() => error = '${picked.name}: ${AppLanguageScope.textOf(context).isKy ? 'файл 3 МБдан чоң.' : 'файл больше 3 МБ.'}');
          continue;
        }
        next.add(GroupRequestAttachment(name: picked.name, sizeBytes: bytes.length, base64Data: base64Encode(bytes)));
      }
      if (next.isEmpty) return;
      setState(() {
        error = null;
        final available = maxFiles - attachments.length;
        attachments.addAll(next.take(available));
      });
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> pickGalleryPhotos() async {
    if (attachments.length >= maxFiles) {
      setState(() => error = AppLanguageScope.textOf(context).isKy ? '3 файлдан көп кошууга болбойт.' : 'Можно добавить максимум 3 файла.');
      return;
    }
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
      if (images.isEmpty) return;
      final next = <GroupRequestAttachment>[];
      for (final image in images) {
        final bytes = await image.readAsBytes();
        if (bytes.length > maxFileBytes) {
          setState(() => error = '${image.name}: ${AppLanguageScope.textOf(context).isKy ? 'сүрөт 3 МБдан чоң.' : 'фото больше 3 МБ.'}');
          continue;
        }
        next.add(GroupRequestAttachment(name: image.name, sizeBytes: bytes.length, base64Data: base64Encode(bytes), kind: 'image'));
      }
      if (next.isEmpty) return;
      setState(() {
        error = null;
        final available = maxFiles - attachments.length;
        attachments.addAll(next.take(available));
      });
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final documentsPayload = GroupRequestDocuments(note: documentNote.text.trim(), files: attachments).toPayload();
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
        documents: documentsPayload,
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
          _field(documentNote, text.isKy ? 'Документтер боюнча комментарий' : 'Комментарий к документам', lines: 3),
          OutlinedButton.icon(onPressed: loading ? null : pickGalleryPhotos, icon: const Icon(Icons.photo_library_outlined), label: Text(text.isKy ? 'Галереядан сүрөт кошуу' : 'Добавить фото из галереи')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: loading ? null : pickFiles, icon: const Icon(Icons.attach_file_rounded), label: Text(text.isKy ? 'Файл / документ кошуу' : 'Добавить файл / документ')),
          const SizedBox(height: 8),
          Text(text.isKy ? 'PDF, DOC, DOCX, JPG, PNG. Максимум 3 файл, ар бири 3 МБга чейин.' : 'PDF, DOC, DOCX, JPG, PNG. Максимум 3 файла, каждый до 3 МБ.', style: TextStyle(color: context.appColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...attachments.map((file) => _AttachmentTile(file: file, onRemove: loading ? null : () => setState(() => attachments.remove(file)))),
          ],
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

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.file, required this.onRemove});

  final GroupRequestAttachment file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: colors.surfaceSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.border)),
      child: Row(children: [
        Icon(file.isImage ? Icons.image_outlined : Icons.description_outlined, color: MobileChatTheme.primaryDark),
        const SizedBox(width: 10),
        Expanded(child: Text('${file.name} · ${formatBytes(file.sizeBytes)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textStrong, fontWeight: FontWeight.w800))),
        IconButton(onPressed: onRemove, icon: const Icon(Icons.close_rounded)),
      ]),
    );
  }
}

class GroupRequestDocuments {
  const GroupRequestDocuments({required this.note, required this.files});

  static const empty = GroupRequestDocuments(note: '', files: []);

  final String note;
  final List<GroupRequestAttachment> files;

  String toPayload() {
    if (note.trim().isEmpty && files.isEmpty) return '';
    return jsonEncode({
      'version': 1,
      'note': note.trim(),
      'files': files.map((file) => file.toJson()).toList(),
    });
  }

  static GroupRequestDocuments tryParse(String value) {
    final raw = value.trim();
    if (raw.isEmpty || !raw.startsWith('{')) return empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return empty;
      final filesRaw = decoded['files'];
      return GroupRequestDocuments(
        note: decoded['note'] as String? ?? '',
        files: filesRaw is List ? filesRaw.whereType<Map<String, dynamic>>().map(GroupRequestAttachment.fromJson).toList() : const [],
      );
    } catch (_) {
      return empty;
    }
  }
}

class GroupRequestAttachment {
  const GroupRequestAttachment({required this.name, required this.sizeBytes, required this.base64Data, this.kind = 'file'});

  final String name;
  final int sizeBytes;
  final String base64Data;
  final String kind;
  bool get isImage => kind == 'image' || name.toLowerCase().endsWith('.jpg') || name.toLowerCase().endsWith('.jpeg') || name.toLowerCase().endsWith('.png');

  Map<String, dynamic> toJson() => {
        'name': name,
        'size_bytes': sizeBytes,
        'base64': base64Data,
        'kind': kind,
      };

  factory GroupRequestAttachment.fromJson(Map<String, dynamic> json) {
    return GroupRequestAttachment(
      name: json['name'] as String? ?? 'document',
      sizeBytes: json['size_bytes'] as int? ?? 0,
      base64Data: json['base64'] as String? ?? '',
      kind: json['kind'] as String? ?? 'file',
    );
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}
