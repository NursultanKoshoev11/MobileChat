import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';

class EmptyPostsView extends StatelessWidget {
  const EmptyPostsView({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return KoomCard(
      showShadow: false,
      child: KoomEmptyState(
        icon: Icons.feed_outlined,
        title: text.noPostsYet,
        message: text.postsDescription,
        action: FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: Text(text.newPost),
        ),
      ),
    );
  }
}

class GroupAccessSheet extends StatelessWidget {
  const GroupAccessSheet(
      {super.key,
      required this.groupTitle,
      required this.code,
      String? qrValue})
      : qrValue = qrValue ?? code;
  final String groupTitle;
  final String code;
  final String qrValue;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.border)),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: Text(groupTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 20))),
                IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 12),
              SelectableText(code,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
              const SizedBox(height: 16),
              Center(
                  child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: QrImageView(
                          data: qrValue,
                          version: QrVersions.auto,
                          size: 210,
                          backgroundColor: Colors.white))),
              const SizedBox(height: 12),
              Text(
                  text.isKy
                      ? 'Бул кодду же QR кодду башка колдонуучуга бериңиз.'
                      : 'Передайте этот код или QR другому пользователю.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: colors.textMuted, fontWeight: FontWeight.w600)),
            ]),
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
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.api.inviteUserByPhone(
          groupId: widget.group.id, mobile: phoneController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(
          context,
          AppLanguageScope.textOf(context).isKy
              ? 'Чакыруу жөнөтүлдү.'
              : 'Приглашение отправлено.');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text.isKy ? 'Телефон менен чакыруу' : 'Пригласить по телефону',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                    labelText: text.mobileNumber,
                    hintText: '+996700123456',
                    prefixIcon: const Icon(Icons.phone_iphone_rounded))),
            if (error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: error!)
            ],
            const SizedBox(height: 16),
            FilledButton(
                onPressed: loading ? null : submit,
                child: Text(loading
                    ? text.pleaseWait
                    : (text.isKy
                        ? 'Чакыруу жөнөтүү'
                        : 'Отправить приглашение'))),
          ]),
    );
  }
}

Uint8List? _decodePostPhoto(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  final data = raw.contains(',') ? raw.split(',').last : raw;
  try {
    return base64Decode(data);
  } catch (_) {
    return null;
  }
}

String _photoLabel(BuildContext context) {
  final text = AppLanguageScope.textOf(context);
  return text.isKy ? 'Фото' : 'Фото';
}

class _PostPhotoPreview extends StatelessWidget {
  const _PostPhotoPreview({required this.photos, this.compact = true});

  final List<PublicRequestPhoto> photos;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visiblePhotos = photos
        .where((photo) => photo.base64Data.trim().isNotEmpty)
        .take(3)
        .toList(growable: false);
    if (visiblePhotos.isEmpty) return const SizedBox.shrink();
    final decoded = _decodePostPhoto(visiblePhotos.first.base64Data);
    if (decoded == null) return const SizedBox.shrink();
    final radius = BorderRadius.circular(18);
    final image = Image.memory(
      decoded,
      width: double.infinity,
      height: compact ? 170 : null,
      fit: compact ? BoxFit.cover : BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.photo_outlined, size: 16),
          const SizedBox(width: 6),
          Text(
            '${_photoLabel(context)}${visiblePhotos.length > 1 ? ' (${visiblePhotos.length})' : ''}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.appColors.textMuted,
                ),
          ),
        ]),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _openPhotoViewer(context, decoded),
          child: ClipRRect(borderRadius: radius, child: image),
        ),
      ],
    );
  }
}

void _openPhotoViewer(BuildContext context, Uint8List bytes) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          InteractiveViewer(
            minScale: 0.7,
            maxScale: 4,
            child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    ),
  );
}

class PublicRequestCard extends StatelessWidget {
  const PublicRequestCard(
      {super.key,
      required this.request,
      required this.onTap,
      required this.onVote,
      this.canModerate = false,
      this.onStatus});
  final PublicRequest request;
  final VoidCallback onTap;
  final ValueChanged<String> onVote;
  final bool canModerate;
  final ValueChanged<String>? onStatus;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final requestPhotos = request.content.photos;
    String typeLabel(String value) {
      switch (value) {
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
          return value;
      }
    }

    String modeLabel(String value) {
      switch (value) {
        case 'read_only':
          return text.textOnly;
        case 'vote_only':
          return text.votingOnly;
        case 'discussion':
          return text.discussionWithComments;
        default:
          return value;
      }
    }

    String statusLabel(String value) {
      switch (value) {
        case 'new':
          return text.statusNew;
        case 'under_review':
          return text.statusUnderReview;
        case 'resolved':
          return text.statusResolved;
        case 'rejected':
          return text.statusRejected;
        default:
          return value;
      }
    }

    final statusText = [
      typeLabel(request.requestType),
      modeLabel(request.interactionMode),
      statusLabel(request.status),
      if (canModerate && onStatus != null) text.adminStatus,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shadowColor: colors.shadow,
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: request.interactionMode == 'discussion' ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(
                    statusText,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textMuted, fontWeight: FontWeight.w800),
                  ),
                ),
                if (canModerate && onStatus != null)
                  _StatusButton(onChanged: onStatus!),
              ]),
              const SizedBox(height: 6),
              Text(request.title,
                  style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              if (request.displayBody.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(request.displayBody,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              if (requestPhotos.isNotEmpty) ...[
                const SizedBox(height: 10),
                _PostPhotoPreview(photos: requestPhotos),
              ],
              const SizedBox(height: 10),
              Text('${text.isKy ? 'Автор' : 'Автор'}: ${request.authorName}',
                  style: TextStyle(color: colors.textMuted, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (request.interactionMode == 'discussion')
                      FilledButton.tonal(
                          onPressed: onTap, child: Text(text.read)),
                    if (request.interactionMode != 'read_only')
                      OutlinedButton.icon(
                          onPressed: () => onVote('support'),
                          icon: Icon(request.supportedByMe
                              ? Icons.thumb_up_alt_rounded
                              : Icons.thumb_up_alt_outlined),
                          label: Text('${request.supportCount}')),
                    if (request.interactionMode != 'read_only')
                      OutlinedButton.icon(
                          onPressed: () => onVote('oppose'),
                          icon: Icon(request.opposedByMe
                              ? Icons.thumb_down_alt_rounded
                              : Icons.thumb_down_alt_outlined),
                          label: Text('${request.opposeCount}')),
                    if (request.interactionMode == 'discussion')
                      Text('${request.commentCount} ${text.comments}',
                          style: TextStyle(color: colors.textMuted)),
                  ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem(
            value: 'under_review', child: Text(text.statusUnderReview)),
        PopupMenuItem(value: 'resolved', child: Text(text.statusResolved)),
        PopupMenuItem(value: 'new', child: Text(text.statusNew)),
        PopupMenuItem(value: 'rejected', child: Text(text.statusRejected)),
      ],
      tooltip: text.adminStatus,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(Icons.sync_alt_rounded,
            size: 18, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class CreatePublicRequestSheet extends StatefulWidget {
  const CreatePublicRequestSheet(
      {super.key, required this.api, required this.group});
  final PublicRequestsApi api;
  final ChatGroup group;

  @override
  State<CreatePublicRequestSheet> createState() =>
      _CreatePublicRequestSheetState();
}

class _CreatePublicRequestSheetState extends State<CreatePublicRequestSheet> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  String type = 'announcement';
  String interactionMode = 'read_only';
  final ImagePicker imagePicker = ImagePicker();
  final List<PublicRequestPhoto> photos = [];
  bool loading = false;
  String? error;

  static const int maxPhotoBytes = 900 * 1024;

  Future<void> pickPhoto() async {
    if (loading) return;
    try {
      final image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 72,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.length > maxPhotoBytes) {
        setState(() => error = AppLanguageScope.textOf(context).isKy
            ? 'Фото өтө чоң. Башка сүрөт тандаңыз.'
            : 'Фото слишком большое. Выберите другое фото.');
        return;
      }
      setState(() {
        photos
          ..clear()
          ..add(PublicRequestPhoto(
            name: image.name.isNotEmpty ? image.name : 'photo.jpg',
            sizeBytes: bytes.length,
            base64Data: base64Encode(bytes),
          ));
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = AppLanguageScope.textOf(context).isKy
            ? 'Фото тандалган жок: $e'
            : 'Не удалось выбрать фото: $e');
      }
    }
  }

  void removePhoto() {
    if (loading) return;
    setState(() => photos.clear());
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final bodyText = bodyController.text.trim();
    if (bodyText.isEmpty && photos.isEmpty) {
      setState(() => error = AppLanguageScope.textOf(context).isKy
          ? 'Текст же фото кошуңуз.'
          : 'Добавьте текст или фото.');
      return;
    }
    final payload = PublicRequestContent(
      text: bodyText,
      photos: List.of(photos),
    ).toPayload();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.api.createRequest(
          groupId: widget.group.id,
          type: type,
          interactionMode: interactionMode,
          title: titleController.text.trim(),
          body: payload);
      if (mounted) Navigator.of(context).pop(true);
    } on ModerationPendingException catch (e) {
      titleController.clear();
      bodyController.clear();
      photos.clear();
      if (mounted) {
        setState(() => error = null);
        showAppSnack(context, e.message);
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(text.newPost,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                  value: type,
                  decoration: InputDecoration(labelText: text.postType),
                  items: [
                    DropdownMenuItem(
                        value: 'announcement', child: Text(text.announcement)),
                    DropdownMenuItem(
                        value: 'suggestion', child: Text(text.suggestion)),
                    DropdownMenuItem(
                        value: 'complaint', child: Text(text.complaint)),
                    DropdownMenuItem(
                        value: 'requirement', child: Text(text.requirement)),
                    DropdownMenuItem(
                        value: 'problem', child: Text(text.problem)),
                    DropdownMenuItem(value: 'idea', child: Text(text.idea))
                  ],
                  onChanged: loading
                      ? null
                      : (value) =>
                          setState(() => type = value ?? 'announcement')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  key: const ValueKey('post_mode_dropdown'),
                  value: interactionMode,
                  decoration: InputDecoration(labelText: text.interactionMode),
                  items: [
                    DropdownMenuItem(
                        value: 'read_only', child: Text(text.textOnly)),
                    DropdownMenuItem(
                        value: 'vote_only', child: Text(text.votingOnly)),
                    DropdownMenuItem(
                        value: 'discussion',
                        child: Text(
                          text.discussionWithComments,
                          key: const ValueKey('post_mode_discussion'),
                        ))
                  ],
                  onChanged: loading
                      ? null
                      : (value) => setState(
                          () => interactionMode = value ?? 'read_only')),
              const SizedBox(height: 12),
              TextField(
                  key: const ValueKey('post_title_field'),
                  controller: titleController,
                  decoration: InputDecoration(labelText: text.title)),
              const SizedBox(height: 12),
              TextField(
                  key: const ValueKey('post_body_field'),
                  controller: bodyController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(labelText: text.description)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: loading ? null : pickPhoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(photos.isEmpty
                    ? (text.isKy ? 'Фото кошуу' : 'Добавить фото')
                    : (text.isKy ? 'Фото алмаштыруу' : 'Заменить фото')),
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Stack(
                  children: [
                    _PostPhotoPreview(photos: photos, compact: false),
                    Positioned(
                      top: 32,
                      right: 8,
                      child: IconButton.filledTonal(
                        onPressed: removePhoto,
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: text.isKy ? 'Фото өчүрүү' : 'Удалить фото',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${(photos.first.sizeBytes / 1024).round()} KB',
                  style: TextStyle(
                    color: context.appColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(message: error!)
              ],
              const SizedBox(height: 16),
              FilledButton(
                  key: const ValueKey('post_submit_button'),
                  onPressed: loading ? null : submit,
                  child: Text(loading ? text.publishing : text.publish)),
            ]),
      ),
    );
  }
}

class PublicRequestDetailsScreen extends StatefulWidget {
  const PublicRequestDetailsScreen(
      {super.key,
      required this.api,
      required this.request,
      required this.canModerate,
      required this.currentUserId,
      this.onStatusChanged,
      this.onRequestChanged});
  final PublicRequestsApi api;
  final PublicRequest request;
  final bool canModerate;
  final String currentUserId;
  final ValueChanged<String>? onStatusChanged;
  final ValueChanged<PublicRequest>? onRequestChanged;

  @override
  State<PublicRequestDetailsScreen> createState() =>
      _PublicRequestDetailsScreenState();
}

class _PublicRequestDetailsScreenState
    extends State<PublicRequestDetailsScreen> {
  final commentController = TextEditingController();
  late PublicRequest request;
  late Future<List<PublicRequestComment>> commentsFuture;
  late final GroupRealtimeService realtime;
  List<PublicRequestComment> cachedComments = const <PublicRequestComment>[];
  Timer? realtimeRefreshDebounce;
  bool sending = false;
  bool voteInFlight = false;
  String? error;

  @override
  void initState() {
    super.initState();
    request = widget.request;
    commentsFuture = loadComments();
    realtime = GroupRealtimeService(
      api: ApiClient(
          baseUrl: widget.api.baseUrl, sessionStore: widget.api.sessionStore),
      groupId: request.groupId,
    );
    unawaited(realtime.connect(onEvent: handleRealtimeEvent));
  }

  @override
  void dispose() {
    realtimeRefreshDebounce?.cancel();
    realtime.close();
    commentController.dispose();
    super.dispose();
  }

  Future<List<PublicRequestComment>> loadComments() async {
    final comments = await widget.api.listComments(request.id);
    cachedComments = comments;
    return comments;
  }

  Future<void> refreshComments({bool silent = false}) async {
    final next = loadComments();
    if (silent) {
      final comments = await next;
      if (mounted) setState(() => commentsFuture = Future.value(comments));
      return;
    }
    setState(() => commentsFuture = next);
    await next;
  }

  void handleRealtimeEvent(GroupRealtimeEvent event) {
    if (!mounted || event.groupId != request.groupId) return;
    if (event.type == 'connection.ready') {
      realtimeRefreshDebounce?.cancel();
      realtimeRefreshDebounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted)
          unawaited(refreshComments(silent: true).catchError((_) {}));
      });
      return;
    }
    if (event.requestId != request.id) return;
    switch (event.type) {
      case 'public_request.comment_created':
        final payload = event.payload;
        if (payload is Map<String, dynamic>) {
          final commentPayload = payload['comment'];
          if (commentPayload is Map<String, dynamic>)
            addRealtimeComment(PublicRequestComment.fromJson(commentPayload));
        }
        break;
      case 'public_request.comment_deleted':
        final payload = event.payload;
        if (payload is Map<String, dynamic>)
          removeRealtimeComment(payload['comment_id'] as String? ?? '');
        break;
      case 'public_request.voted':
      case 'public_request.vote_cleared':
        final payload = event.payload;
        if (payload is Map<String, dynamic>)
          applyVoteUpdate(PublicRequestVoteUpdate.fromJson(payload));
        break;
    }
  }

  void addRealtimeComment(PublicRequestComment comment) {
    if (cachedComments.any((item) => item.id == comment.id)) return;
    final updated = [...cachedComments, comment]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    setComments(updated);
  }

  void removeRealtimeComment(String commentId) {
    if (commentId.isEmpty) return;
    final updated =
        cachedComments.where((comment) => comment.id != commentId).toList();
    setComments(updated);
  }

  void setComments(List<PublicRequestComment> comments) {
    if (!mounted) return;
    cachedComments = comments;
    setState(() => commentsFuture = Future.value(comments));
  }

  void setRequest(PublicRequest next) {
    if (!mounted) return;
    setState(() => request = next);
    widget.onRequestChanged?.call(next);
  }

  void applyVoteUpdate(PublicRequestVoteUpdate update) {
    if (update.requestId != request.id || !update.hasCounts) return;
    var next = request.copyWith(
      supportCount: update.supportCount!,
      opposeCount: update.opposeCount!,
      updatedAt: DateTime.now(),
    );
    if (update.voterId == widget.currentUserId) {
      next = next.copyWith(myVote: update.voteType);
    }
    setRequest(next);
  }

  Future<void> vote(String voteType) async {
    if (request.interactionMode == 'read_only' || voteInFlight) return;
    voteInFlight = true;
    final previous = request;
    setRequest(optimisticPublicRequestVote(request, voteType));
    try {
      final PublicRequestVoteUpdate update;
      if (previous.myVote == voteType) {
        update = await widget.api.clearVote(previous.id);
      } else if (voteType == 'support') {
        update = await widget.api.support(previous.id);
      } else {
        update = await widget.api.oppose(previous.id);
      }
      if (mounted) applyVoteUpdate(update);
    } catch (e) {
      setRequest(previous);
      if (mounted)
        showAppSnack(context, localizedMessage(context, e.toString()));
    } finally {
      voteInFlight = false;
    }
  }

  Future<void> submitComment() async {
    final body = commentController.text.trim();
    if (body.isEmpty || sending || request.interactionMode != 'discussion')
      return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final comment =
          await widget.api.addComment(requestId: request.id, body: body);
      commentController.clear();
      addRealtimeComment(comment);
      setRequest(request.copyWith(
          commentCount: request.commentCount + 1, updatedAt: DateTime.now()));
    } on ModerationPendingException catch (e) {
      commentController.clear();
      if (mounted) {
        setState(() => error = null);
        showAppSnack(context, e.message);
      }
      unawaited(refreshComments(silent: true).catchError((_) {}));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> deleteComment(PublicRequestComment comment) async {
    if (!widget.canModerate && comment.authorId != widget.currentUserId) return;
    final previousComments = cachedComments;
    final previousRequest = request;
    removeRealtimeComment(comment.id);
    setRequest(request.copyWith(
      commentCount: request.commentCount - 1 < 0 ? 0 : request.commentCount - 1,
      updatedAt: DateTime.now(),
    ));
    try {
      await widget.api.deleteComment(comment.id);
    } catch (e) {
      setComments(previousComments);
      setRequest(previousRequest);
      if (mounted)
        showAppSnack(context, localizedMessage(context, e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
          title: Text(text.readPost), actions: const [AppSettingsButton()]),
      body: KoomPageBackground(
        child: RefreshIndicator(
          onRefresh: refreshComments,
          child: FutureBuilder<List<PublicRequestComment>>(
            future: commentsFuture,
            builder: (context, snapshot) {
              final comments = cachedComments.isNotEmpty
                  ? cachedComments
                  : snapshot.data ?? const <PublicRequestComment>[];
              return ListView(
                key: const ValueKey('request_details_comments_list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  PublicRequestCard(
                    request: request,
                    onTap: () {},
                    onVote: vote,
                    canModerate: widget.canModerate,
                    onStatus: widget.onStatusChanged == null
                        ? null
                        : (status) {
                            setRequest(request.copyWith(
                                status: status, updatedAt: DateTime.now()));
                            widget.onStatusChanged!(status);
                          },
                  ),
                  const SizedBox(height: 12),
                  if (request.displayBody.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(request.displayBody,
                          style: TextStyle(
                              color: colors.textStrong, height: 1.35)),
                    ),
                  if (request.content.photos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _PostPhotoPreview(
                      photos: request.content.photos,
                      compact: false,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(text.comments,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (error != null) ...[
                    ErrorBanner(message: error!),
                    const SizedBox(height: 10),
                  ],
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      cachedComments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    ErrorBanner(message: snapshot.error.toString())
                  else if (comments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                          text.isKy
                              ? 'Комментарий азырынча жок.'
                              : 'Комментариев пока нет.',
                          style: TextStyle(color: colors.textMuted)),
                    )
                  else
                    ...comments.map((comment) => _CommentTile(
                          comment: comment,
                          canDelete: widget.canModerate ||
                              comment.authorId == widget.currentUserId,
                          onDelete: () => deleteComment(comment),
                        )),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: request.interactionMode == 'discussion'
          ? SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 10,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('comment_field'),
                      controller: commentController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => submitComment(),
                      decoration: InputDecoration(
                          hintText: text.isKy
                              ? 'Комментарий кошуу'
                              : 'Добавить комментарий'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : submitComment,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile(
      {required this.comment, required this.canDelete, required this.onDelete});
  final PublicRequestComment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 18,
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          child: Text(
              comment.authorName.isEmpty
                  ? '?'
                  : comment.authorName.substring(0, 1).toUpperCase(),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(comment.authorName,
              style: TextStyle(
                  color: colors.textStrong, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(comment.body,
              style: TextStyle(color: colors.textStrong, height: 1.3)),
        ])),
        if (canDelete)
          IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded)),
      ]),
    );
  }
}
