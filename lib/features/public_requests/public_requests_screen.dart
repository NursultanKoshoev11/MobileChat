import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../services/group_realtime_service.dart';
import '../../shared/ui_helpers.dart';
import '../statistics/group_statistics_screen.dart';

class PublicRequestsScreen extends StatefulWidget {
  const PublicRequestsScreen({super.key, required this.api, required this.user, required this.group});
  final ApiClient api;
  final UserProfile user;
  final ChatGroup group;

  @override
  State<PublicRequestsScreen> createState() => _PublicRequestsScreenState();
}

class _PublicRequestsScreenState extends State<PublicRequestsScreen> {
  late final PublicRequestsApi requestsApi;
  late final GroupRealtimeService realtime;
  late Future<List<PublicRequest>> requestsFuture;
  Timer? _refreshDebounce;

  bool get canModerate => widget.group.myRole == 'owner' || widget.group.myRole == 'admin';
  bool get canInvite => widget.group.canInvite;

  @override
  void initState() {
    super.initState();
    requestsApi = PublicRequestsApi(baseUrl: widget.api.baseUrl, sessionStore: widget.api.sessionStore);
    realtime = GroupRealtimeService(baseUrl: widget.api.baseUrl, sessionStore: widget.api.sessionStore, groupId: widget.group.id);
    requestsFuture = loadRequests();
    realtime.connect(onEvent: _handleRealtimeEvent);
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    realtime.close();
    super.dispose();
  }

  void _handleRealtimeEvent(GroupRealtimeEvent event) {
    if (!mounted || event.groupId != widget.group.id) return;
    if (!event.type.startsWith('public_request.')) return;
    _scheduleRealtimeRefresh();
  }

  void _scheduleRealtimeRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) refresh(silent: true);
    });
  }

  Future<List<PublicRequest>> loadRequests() async {
    final requests = await requestsApi.listRequests(widget.group.id);
    final sorted = List<PublicRequest>.from(requests)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Future<void> refresh({bool silent = false}) async {
    final next = loadRequests();
    if (mounted) setState(() => requestsFuture = next);
    await next;
  }

  Future<void> openStatistics() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupStatisticsScreen(api: requestsApi, group: widget.group)));
    await refresh();
  }

  Future<void> createRequest() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => CreatePublicRequestSheet(api: requestsApi, group: widget.group),
    );
    if (created == true) {
      await refresh();
      if (mounted) showAppSnack(context, AppLanguageScope.textOf(context).postPublished);
    }
  }

  Future<void> vote(PublicRequest request, String voteType) async {
    if (request.interactionMode == 'read_only') return;
    try {
      if (request.myVote == voteType) {
        await requestsApi.clearVote(request.id);
      } else if (voteType == 'support') {
        await requestsApi.support(request.id);
      } else {
        await requestsApi.oppose(request.id);
      }
      await refresh();
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    }
  }

  Future<void> updateStatus(PublicRequest request, String status) async {
    if (!canModerate) return;
    try {
      await requestsApi.updateStatus(requestId: request.id, status: status);
      await refresh();
      if (mounted) showAppSnack(context, AppLanguageScope.textOf(context).isKy ? 'Статус жаңыртылды.' : 'Статус обновлён.');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    }
  }

  Future<void> openDetails(PublicRequest request) async {
    if (request.interactionMode != 'discussion') return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PublicRequestDetailsScreen(
        api: requestsApi,
        request: request,
        canModerate: canModerate,
        currentUserId: widget.user.id,
        onStatusChanged: canModerate ? (status) => updateStatus(request, status) : null,
      ),
    ));
    await refresh();
  }

  String get groupAccessCode => (widget.group.inviteCode ?? '').trim().toUpperCase();

  Future<void> showGroupAccess() async {
    final code = groupAccessCode;
    if (code.isEmpty) {
      showAppSnack(context, AppLanguageScope.textOf(context).isKy ? 'Топтун коду азырынча түзүлгөн эмес.' : 'Код группы ещё не создан.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => GroupAccessSheet(groupTitle: widget.group.title, code: code),
    );
  }

  Future<void> inviteByPhone() async {
    if (!canInvite) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => InviteByPhoneSheet(api: widget.api, group: widget.group),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.title),
        actions: [
          IconButton(onPressed: openStatistics, tooltip: text.isKy ? 'Статистика' : 'Статистика', icon: const Icon(Icons.analytics_outlined)),
          IconButton(onPressed: showGroupAccess, tooltip: text.isKy ? 'Код жана QR' : 'Код и QR', icon: const Icon(Icons.qr_code_rounded)),
          if (canInvite) IconButton(onPressed: inviteByPhone, tooltip: text.isKy ? 'Телефон менен чакыруу' : 'Пригласить по телефону', icon: const Icon(Icons.person_add_alt_1_rounded)),
          const AppSettingsButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: createRequest, icon: const Icon(Icons.add_rounded), label: Text(text.newPost)),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<PublicRequest>>(
          future: requestsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return ListView(padding: const EdgeInsets.all(16), children: [ErrorBanner(message: snapshot.error.toString())]);
            final requests = snapshot.data ?? const [];
            if (requests.isEmpty) return EmptyPostsView(onCreate: createRequest);
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: requests.length,
              itemBuilder: (_, index) {
                final request = requests[index];
                return PublicRequestCard(
                  request: request,
                  canModerate: canModerate,
                  onStatusChanged: canModerate ? (status) => updateStatus(request, status) : null,
                  onRead: () => openDetails(request),
                  onSupport: request.interactionMode == 'read_only' ? null : () => vote(request, 'support'),
                  onOppose: request.interactionMode == 'read_only' ? null : () => vote(request, 'oppose'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class EmptyPostsView extends StatelessWidget {
  const EmptyPostsView({super.key, required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 120),
      const Icon(Icons.feed_outlined, size: 72, color: MobileChatTheme.primary),
      const SizedBox(height: 16),
      Text(text.noPostsYet, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(text.postsDescription, textAlign: TextAlign.center, style: TextStyle(color: context.appColors.textMuted)),
      const SizedBox(height: 18),
      Center(child: FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add_rounded), label: Text(text.newPost))),
    ]);
  }
}

class GroupAccessSheet extends StatelessWidget {
  const GroupAccessSheet({super.key, required this.groupTitle, required this.code});
  final String groupTitle;
  final String code;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: colors.border), boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 24, offset: const Offset(0, 12))]),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: colors.textMuted.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(text.isKy ? 'Топко кирүү' : 'Вход в группу', style: TextStyle(color: colors.textStrong, fontWeight: FontWeight.w900, fontSize: 22)),
                const SizedBox(height: 2),
                Text(groupTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w700)),
              ])),
              IconButton.filledTonal(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: colors.surfaceSoft, borderRadius: BorderRadius.circular(20), border: Border.all(color: colors.border)),
              child: Column(children: [
                Text(text.isKy ? 'Топтун коду' : 'Код группы', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SelectableText(code, textAlign: TextAlign.center, style: TextStyle(color: colors.textStrong, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ]),
            ),
            const SizedBox(height: 16),
            Center(child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))), child: QrImageView(data: code, version: QrVersions.auto, size: 210, backgroundColor: Colors.white, errorCorrectionLevel: QrErrorCorrectLevel.M))),
            const SizedBox(height: 12),
            Text(text.isKy ? 'Бул кодду же QR кодду башка колдонуучуга бериңиз. Ал код менен топко кире алат.' : 'Передайте этот код или QR другому пользователю. Он сможет войти в группу по коду.', textAlign: TextAlign.center, style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class InviteByPhoneSheet extends StatefulWidget {
  const InviteByPhoneSheet({super.key, required this.api, required this.group});
  final ApiClient api;
  final ChatGroup group;
  @override
  State<InviteByPhoneSheet> createState() => _InviteByPhoneSheetState();
}

class _InviteByPhoneSheetState extends State<InviteByPhoneSheet> {
  final phoneController = TextEditingController(text: '+996');
  bool loading = false;
  String? error;
  @override
  void dispose() { phoneController.dispose(); super.dispose(); }
  Future<void> submit() async {
    setState(() { loading = true; error = null; });
    try {
      await widget.api.inviteUserByPhone(groupId: widget.group.id, mobile: phoneController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, AppLanguageScope.textOf(context).isKy ? 'Чакыруу жөнөтүлдү.' : 'Приглашение отправлено.');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Padding(padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(text.isKy ? 'Телефон менен чакыруу' : 'Пригласить по телефону', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: text.mobileNumber, hintText: '+996700123456', prefixIcon: const Icon(Icons.phone_iphone_rounded))),
      if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
      const SizedBox(height: 16),
      FilledButton(onPressed: loading ? null : submit, child: Text(loading ? text.pleaseWait : (text.isKy ? 'Чакыруу жөнөтүү' : 'Отправить приглашение'))),
    ]));
  }
}

class PublicRequestCard extends StatelessWidget {
  const PublicRequestCard({
    super.key,
    required this.request,
    required this.onRead,
    this.onSupport,
    this.onOppose,
    this.showReadAction = true,
    this.canModerate = false,
    this.onStatusChanged,
  });
  final PublicRequest request;
  final VoidCallback onRead;
  final VoidCallback? onSupport;
  final VoidCallback? onOppose;
  final bool showReadAction;
  final bool canModerate;
  final ValueChanged<String>? onStatusChanged;

  bool get canVote => request.interactionMode != 'read_only';
  bool get canOpenDetails => showReadAction && request.interactionMode == 'discussion';

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final content = request.content;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: canOpenDetails ? onRead : null,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [_ChipLabel(text: translatedRequestType(request.requestType, text)), _ChipLabel(text: modeLabel(request.interactionMode, text)), _StatusChip(status: request.status)]),
              const SizedBox(height: 10),
              Text(request.title, style: TextStyle(color: colors.textStrong, fontSize: 17, fontWeight: FontWeight.w800)),
              if (request.displayBody.isNotEmpty) ...[const SizedBox(height: 6), Text(request.displayBody, maxLines: showReadAction ? 3 : null, overflow: showReadAction ? TextOverflow.ellipsis : TextOverflow.visible, style: TextStyle(color: colors.textStrong))],
              if (content.photos.isNotEmpty) ...[const SizedBox(height: 10), _PostPhotosGrid(photos: content.photos)],
              const SizedBox(height: 10),
              Text('${text.isKy ? 'Жазган' : 'Автор'}: ${request.authorName}', style: TextStyle(color: colors.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (canOpenDetails) FilledButton.tonal(onPressed: onRead, child: Text(text.read)),
                if (canModerate && onStatusChanged != null) _StatusActionButton(request: request, onChanged: onStatusChanged!),
                if (canVote) OutlinedButton.icon(onPressed: onSupport, icon: Icon(request.supportedByMe ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined), label: Text('${request.supportCount}')),
                if (canVote) OutlinedButton.icon(onPressed: onOppose, icon: Icon(request.opposedByMe ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined), label: Text('${request.opposeCount}')),
                if (request.interactionMode == 'discussion') Text('${request.commentCount} ${text.comments}', style: TextStyle(color: colors.textMuted)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  String translatedRequestType(String value, AppText text) {
    if (value == 'announcement') return text.announcement;
    if (value == 'suggestion') return text.suggestion;
    if (value == 'complaint') return text.complaint;
    if (value == 'requirement') return text.requirement;
    if (value == 'problem') return text.problem;
    if (value == 'idea') return text.idea;
    return value;
  }

  String modeLabel(String value, AppText text) {
    if (value == 'read_only') return text.textOnly;
    if (value == 'vote_only') return text.votingOnly;
    return text.discussionWithComments;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final label = publicStatusLabel(context, status);
    final color = publicStatusColor(status);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)), child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)));
  }
}

class _StatusActionButton extends StatelessWidget {
  const _StatusActionButton({required this.request, required this.onChanged});
  final PublicRequest request;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final isKy = AppLanguageScope.textOf(context).isKy;
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem(value: 'under_review', child: Text(isKy ? 'Процессте' : 'В процессе')),
        PopupMenuItem(value: 'resolved', child: Text(isKy ? 'Аяктады' : 'Завершено')),
        PopupMenuItem(value: 'new', child: Text(isKy ? 'Жаңы' : 'Новая')),
        PopupMenuItem(value: 'rejected', child: Text(isKy ? 'Четке кагылды' : 'Отклонено')),
      ],
      child: OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.sync_alt_rounded), label: Text(isKy ? 'Статус' : 'Статус')),
    );
  }
}

String publicStatusLabel(BuildContext context, String status) {
  final isKy = AppLanguageScope.textOf(context).isKy;
  switch (status) {
    case 'under_review': return isKy ? 'Процессте' : 'В процессе';
    case 'resolved': return isKy ? 'Аяктады' : 'Завершено';
    case 'accepted': return isKy ? 'Кабыл алынды' : 'Принято';
    case 'rejected': return isKy ? 'Четке кагылды' : 'Отклонено';
    default: return isKy ? 'Жаңы' : 'Новая';
  }
}

Color publicStatusColor(String status) {
  switch (status) {
    case 'under_review': return Colors.orange;
    case 'resolved': return Colors.green;
    case 'accepted': return MobileChatTheme.primaryDark;
    case 'rejected': return Colors.redAccent;
    default: return Colors.blueGrey;
  }
}

class _PostPhotosGrid extends StatelessWidget {
  const _PostPhotosGrid({required this.photos});
  final List<PublicRequestPhoto> photos;
  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: photos.take(4).map((photo) {
      try {
        final bytes = base64Decode(photo.base64Data);
        return ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(bytes, width: 120, height: 120, fit: BoxFit.cover, gaplessPlayback: true));
      } catch (_) {
        return Container(width: 120, height: 120, alignment: Alignment.center, decoration: BoxDecoration(color: context.appColors.surfaceSoft, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.broken_image_outlined));
      }
    }).toList());
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: context.appColors.chipBackground, borderRadius: BorderRadius.circular(999)), child: Text(text, style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800, fontSize: 12)));
  }
}

class CreatePublicRequestSheet extends StatefulWidget {
  const CreatePublicRequestSheet({super.key, required this.api, required this.group});
  final PublicRequestsApi api;
  final ChatGroup group;
  @override
  State<CreatePublicRequestSheet> createState() => _CreatePublicRequestSheetState();
}

class _CreatePublicRequestSheetState extends State<CreatePublicRequestSheet> {
  static const int maxPhotoBytes = 3 * 1024 * 1024;
  static const int maxPhotos = 4;
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  final List<PublicRequestPhoto> photos = [];
  String type = 'announcement';
  String interactionMode = 'read_only';
  bool loading = false;
  String? error;
  @override
  void dispose() { titleController.dispose(); bodyController.dispose(); super.dispose(); }
  Future<void> pickGalleryPhotos() async {
    if (photos.length >= maxPhotos) { setState(() => error = AppLanguageScope.textOf(context).isKy ? '4 сүрөттөн көп кошууга болбойт.' : 'Можно добавить максимум 4 фото.'); return; }
    try {
      final images = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1600);
      if (images.isEmpty) return;
      final next = <PublicRequestPhoto>[];
      for (final image in images) {
        final bytes = await image.readAsBytes();
        if (bytes.length > maxPhotoBytes) { setState(() => error = '${image.name}: ${AppLanguageScope.textOf(context).isKy ? 'сүрөт 3 МБдан чоң.' : 'фото больше 3 МБ.'}'); continue; }
        next.add(PublicRequestPhoto(name: image.name, sizeBytes: bytes.length, base64Data: base64Encode(bytes)));
      }
      if (next.isEmpty) return;
      setState(() { error = null; photos.addAll(next.take(maxPhotos - photos.length)); });
    } catch (e) { setState(() => error = e.toString()); }
  }
  Future<void> submit() async {
    setState(() { loading = true; error = null; });
    try {
      final content = PublicRequestContent(text: bodyController.text.trim(), photos: photos);
      await widget.api.createRequest(groupId: widget.group.id, type: type, interactionMode: interactionMode, title: titleController.text.trim(), body: content.toPayload());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) { if (mounted) setState(() => error = e.toString()); } finally { if (mounted) setState(() => loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Padding(padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(text.newPost, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(value: type, decoration: InputDecoration(labelText: text.postType), items: [DropdownMenuItem(value: 'announcement', child: Text(text.announcement)), DropdownMenuItem(value: 'suggestion', child: Text(text.suggestion)), DropdownMenuItem(value: 'complaint', child: Text(text.complaint)), DropdownMenuItem(value: 'requirement', child: Text(text.requirement)), DropdownMenuItem(value: 'problem', child: Text(text.problem)), DropdownMenuItem(value: 'idea', child: Text(text.idea))], onChanged: loading ? null : (value) => setState(() => type = value ?? 'announcement')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: interactionMode, decoration: InputDecoration(labelText: text.interactionMode), items: [DropdownMenuItem(value: 'read_only', child: Text(text.textOnly)), DropdownMenuItem(value: 'vote_only', child: Text(text.votingOnly)), DropdownMenuItem(value: 'discussion', child: Text(text.discussionWithComments))], onChanged: loading ? null : (value) => setState(() => interactionMode = value ?? 'read_only')),
      const SizedBox(height: 12),
      TextField(controller: titleController, decoration: InputDecoration(labelText: text.title)),
      const SizedBox(height: 12),
      TextField(controller: bodyController, minLines: 4, maxLines: 8, decoration: InputDecoration(labelText: text.description)),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: loading ? null : pickGalleryPhotos, icon: const Icon(Icons.photo_library_outlined), label: Text(text.isKy ? 'Галереядан сүрөт кошуу' : 'Добавить фото из галереи')),
      if (photos.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: photos.map((photo) { final bytes = base64Decode(photo.base64Data); return Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(bytes, width: 92, height: 92, fit: BoxFit.cover)), Positioned(right: 2, top: 2, child: IconButton.filledTonal(onPressed: loading ? null : () => setState(() => photos.remove(photo)), icon: const Icon(Icons.close_rounded, size: 18))) ]); }).toList())],
      if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
      const SizedBox(height: 16),
      FilledButton(onPressed: loading ? null : submit, child: Text(loading ? text.publishing : text.publish)),
    ])));
  }
}

class PublicRequestDetailsScreen extends StatefulWidget {
  const PublicRequestDetailsScreen({super.key, required this.api, required this.request, required this.canModerate, required this.currentUserId, this.onStatusChanged});
  final PublicRequestsApi api;
  final PublicRequest request;
  final bool canModerate;
  final String currentUserId;
  final ValueChanged<String>? onStatusChanged;
  @override
  State<PublicRequestDetailsScreen> createState() => _PublicRequestDetailsScreenState();
}

class _PublicRequestDetailsScreenState extends State<PublicRequestDetailsScreen> {
  final commentController = TextEditingController();
  late final GroupRealtimeService realtime;
  late Future<List<PublicRequestComment>> commentsFuture;
  late int supportCount;
  late int opposeCount;
  late String status;
  late int commentCount;
  String? myVote;
  bool sending = false;
  Timer? _refreshDebounce;
  bool get canComment => widget.request.interactionMode == 'discussion';
  bool get canVote => widget.request.interactionMode != 'read_only';

  @override
  void initState() {
    super.initState();
    supportCount = widget.request.supportCount;
    opposeCount = widget.request.opposeCount;
    commentCount = widget.request.commentCount;
    status = widget.request.status;
    myVote = widget.request.myVote;
    commentsFuture = canComment ? widget.api.listComments(widget.request.id) : Future.value(const []);
    realtime = GroupRealtimeService(baseUrl: widget.api.baseUrl, sessionStore: widget.api.sessionStore, groupId: widget.request.groupId);
    realtime.connect(onEvent: _handleRealtimeEvent);
  }

  @override
  void dispose() { _refreshDebounce?.cancel(); realtime.close(); commentController.dispose(); super.dispose(); }

  void _handleRealtimeEvent(GroupRealtimeEvent event) {
    if (!mounted || event.groupId != widget.request.groupId || !event.type.startsWith('public_request.')) return;
    final eventRequestId = event.requestId;
    if (eventRequestId.isNotEmpty && eventRequestId != widget.request.id) return;
    if (event.type == 'public_request.comment_created') commentCount++;
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      await refreshComments();
      await refreshRequestState();
    });
  }

  Future<void> refreshComments() async {
    if (!canComment) return;
    final next = widget.api.listComments(widget.request.id);
    if (mounted) setState(() => commentsFuture = next);
    await next;
  }

  Future<void> refreshRequestState() async {
    try {
      final requests = await widget.api.listRequests(widget.request.groupId);
      final updated = requests.where((item) => item.id == widget.request.id).firstOrNull;
      if (updated == null || !mounted) return;
      setState(() { supportCount = updated.supportCount; opposeCount = updated.opposeCount; commentCount = updated.commentCount; status = updated.status; myVote = updated.myVote; });
    } catch (_) {}
  }

  Future<void> refresh() async { await refreshComments(); await refreshRequestState(); }

  Future<void> vote(String value) async {
    if (!canVote) return;
    try { if (myVote == value) await widget.api.clearVote(widget.request.id); else if (value == 'support') await widget.api.support(widget.request.id); else await widget.api.oppose(widget.request.id); await refreshRequestState(); } catch (e) { if (mounted) showAppSnack(context, e.toString()); }
  }
  Future<void> changeStatus(String nextStatus) async { final callback = widget.onStatusChanged; if (callback == null) return; setState(() => status = nextStatus); callback(nextStatus); }
  Future<void> deleteComment(PublicRequestComment comment) async { try { await widget.api.deleteComment(comment.id); await refresh(); if (mounted) showAppSnack(context, AppLanguageScope.textOf(context).isKy ? 'Комментарий өчүрүлдү.' : 'Комментарий удалён.'); } catch (e) { if (mounted) showAppSnack(context, e.toString()); } }
  Future<void> sendComment() async { final body = commentController.text.trim(); if (body.isEmpty || sending || !canComment) return; setState(() => sending = true); try { await widget.api.addComment(requestId: widget.request.id, body: body); commentController.clear(); await refresh(); } catch (e) { if (mounted) showAppSnack(context, e.toString()); } finally { if (mounted) setState(() => sending = false); } }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final localRequest = PublicRequest(id: widget.request.id, groupId: widget.request.groupId, authorId: widget.request.authorId, authorName: widget.request.authorName, requestType: widget.request.requestType, interactionMode: widget.request.interactionMode, title: widget.request.title, body: widget.request.body, status: status, supportCount: supportCount < 0 ? 0 : supportCount, opposeCount: opposeCount < 0 ? 0 : opposeCount, commentCount: commentCount < 0 ? 0 : commentCount, myVote: myVote, createdAt: widget.request.createdAt, updatedAt: widget.request.updatedAt);
    return Scaffold(
      appBar: AppBar(title: Text(text.readPost), actions: const [AppSettingsButton()]),
      body: Column(children: [
        Expanded(child: RefreshIndicator(onRefresh: refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
          PublicRequestCard(request: localRequest, onRead: () {}, onSupport: canVote ? () => vote('support') : null, onOppose: canVote ? () => vote('oppose') : null, showReadAction: false, canModerate: widget.canModerate, onStatusChanged: widget.canModerate ? changeStatus : null),
          const SizedBox(height: 12),
          if (widget.request.interactionMode == 'read_only') Text(text.readOnlyPost, style: TextStyle(color: context.appColors.textMuted))
          else if (widget.request.interactionMode == 'vote_only') Text(text.voteOnlyPost, style: TextStyle(color: context.appColors.textMuted))
          else ...[Text(text.comments, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8), FutureBuilder<List<PublicRequestComment>>(future: commentsFuture, builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator()); if (snapshot.hasError) return ErrorBanner(message: snapshot.error.toString()); final comments = snapshot.data ?? const []; if (comments.isEmpty) return Text(text.noCommentsYet, style: TextStyle(color: context.appColors.textMuted)); return Column(children: comments.map((comment) => CommentBubble(comment: comment, mine: comment.authorId == widget.currentUserId, canDelete: widget.canModerate, onDelete: () => deleteComment(comment))).toList()); })],
        ]))),
        if (canComment) SafeArea(top: false, child: Container(padding: const EdgeInsets.all(10), color: context.appColors.surface, child: Row(children: [Expanded(child: TextField(controller: commentController, decoration: InputDecoration(hintText: text.addComment))), const SizedBox(width: 8), IconButton.filled(onPressed: sending ? null : sendComment, icon: const Icon(Icons.send_rounded))]))),
      ]),
    );
  }
}

class CommentBubble extends StatelessWidget {
  const CommentBubble({super.key, required this.comment, required this.mine, required this.canDelete, required this.onDelete});
  final PublicRequestComment comment;
  final bool mine;
  final bool canDelete;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final maxWidth = MediaQuery.of(context).size.width * 0.78;
    return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(
      constraints: BoxConstraints(maxWidth: maxWidth), margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: mine ? MobileChatTheme.mineBubble : colors.surface, borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 6), bottomRight: Radius.circular(mine ? 6 : 18)), boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 12, offset: const Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (!mine) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(comment.authorName, style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800, fontSize: 12))), Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Flexible(child: Text(comment.body, style: TextStyle(color: mine ? MobileChatTheme.lightTextStrong : colors.textStrong))), if (canDelete) ...[const SizedBox(width: 4), InkWell(onTap: onDelete, child: Icon(Icons.delete_outline_rounded, size: 18, color: colors.textMuted))]]), const SizedBox(height: 4), Align(alignment: Alignment.centerRight, child: Text(compactCommentTime(comment.createdAt.toLocal()), style: TextStyle(color: mine ? MobileChatTheme.lightTextMuted : colors.textMuted, fontSize: 11))) ]),
    ));
  }
  String compactCommentTime(DateTime time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
