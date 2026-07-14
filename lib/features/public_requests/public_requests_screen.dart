import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

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
import '../groups/group_sheets.dart';
import '../statistics/group_statistics_screen.dart';
import 'moderation_screen.dart';
import 'public_request_media_screens.dart';
import 'public_request_media_widgets.dart';
import 'public_requests_widgets.dart';

class PublicRequestsScreen extends StatefulWidget {
  const PublicRequestsScreen({
    super.key,
    required this.api,
    required this.user,
    required this.group,
  });

  final ApiClient api;
  final UserProfile user;
  final ChatGroup group;

  @override
  State<PublicRequestsScreen> createState() => _PublicRequestsScreenState();
}

class _PublicRequestsScreenState extends State<PublicRequestsScreen> {
  static const int maxGroupAvatarBytes = 512 * 1024;

  late final PublicRequestsApi requestsApi;
  late final GroupRealtimeService realtime;
  late ChatGroup currentGroup;
  final ImagePicker imagePicker = ImagePicker();
  bool updatingGroupPhoto = false;
  late Future<List<PublicRequest>> requestsFuture;
  late Future<int> moderationCountFuture;
  List<PublicRequest> cachedRequests = const <PublicRequest>[];
  bool _requestsLoaded = false;
  String _requestFilter = 'all';
  Timer? _refreshDebounce;
  Timer? _markReadDebounce;
  String? ensuredInviteCode;
  String? ensuredQrPass;
  final Set<String> _votesInFlight = <String>{};

  bool get canModerate =>
      currentGroup.myRole == 'owner' || currentGroup.myRole == 'admin';
  bool get canInvite => currentGroup.canInvite;
  bool get canChangeRoles => currentGroup.ownerId == widget.user.id;
  bool get canMuteComments => canModerate;

  @override
  void initState() {
    super.initState();
    currentGroup = widget.group;
    requestsApi = PublicRequestsApi(
      baseUrl: widget.api.baseUrl,
      sessionStore: widget.api.sessionStore,
    );
    realtime = GroupRealtimeService(api: widget.api, groupId: currentGroup.id);
    requestsFuture = loadRequests();
    moderationCountFuture = loadModerationCount();
    realtime.connect(onEvent: _handleRealtimeEvent);
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _markReadDebounce?.cancel();
    realtime.close();
    super.dispose();
  }

  void _handleRealtimeEvent(GroupRealtimeEvent event) {
    if (!mounted || event.groupId != currentGroup.id) return;
    switch (event.type) {
      case 'connection.ready':
        _scheduleRealtimeRefresh();
        break;
      case 'public_request.created':
        upsertRequestFromPayload(event.payload);
        _scheduleMarkRequestsRead();
        break;
      case 'public_request.comment_created':
        updateRequestCommentCount(event.requestId, 1);
        break;
      case 'public_request.comment_deleted':
        updateRequestCommentCount(event.requestId, -1);
        break;
      case 'public_request.status_updated':
        updateRequestStatus(event.requestId, event.payload);
        break;
      case 'public_request.voted':
      case 'public_request.vote_cleared':
        applyVoteUpdatePayload(event.payload);
        break;
      case 'content_moderation.reviewed':
      case 'content_moderation.pending_review':
        _scheduleRealtimeRefresh();
        break;
    }
  }

  void upsertRequestFromPayload(dynamic payload) {
    if (payload is! Map<String, dynamic>) return;
    final request = PublicRequest.fromJson(payload);
    final updated = [
      request,
      ...cachedRequests.where((item) => item.id != request.id),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setRequests(updated);
  }

  void updateRequestCommentCount(String requestId, int delta) {
    if (requestId.isEmpty) return;
    final updated = cachedRequests
        .map((request) => request.id == requestId
            ? request.copyWith(
                commentCount: request.commentCount + delta < 0
                    ? 0
                    : request.commentCount + delta)
            : request)
        .toList();
    setRequests(updated);
  }

  void updateRequestStatus(String requestId, dynamic payload) {
    if (requestId.isEmpty || payload is! Map<String, dynamic>) return;
    final status = payload['status'] as String?;
    if (status == null || status.isEmpty) return;
    final updated = cachedRequests
        .map((request) => request.id == requestId
            ? request.copyWith(status: status)
            : request)
        .toList();
    setRequests(updated);
  }

  void applyVoteUpdatePayload(dynamic payload) {
    if (payload is! Map<String, dynamic>) return;
    applyVoteUpdate(PublicRequestVoteUpdate.fromJson(payload));
  }

  void applyVoteUpdate(PublicRequestVoteUpdate update) {
    if (update.requestId.isEmpty || !update.hasCounts) return;
    final updated = cachedRequests.map((request) {
      if (request.id != update.requestId) return request;
      var next = request.copyWith(
        supportCount: update.supportCount!,
        opposeCount: update.opposeCount!,
        updatedAt: DateTime.now(),
      );
      if (update.voterId == widget.user.id) {
        next = next.copyWith(myVote: update.voteType);
      }
      return next;
    }).toList();
    setRequests(updated);
  }

  void setRequests(List<PublicRequest> requests) {
    if (!mounted) return;
    cachedRequests = requests;
    _requestsLoaded = true;
    setState(() {});
  }

  PublicRequest currentRequest(PublicRequest fallback) {
    for (final request in cachedRequests) {
      if (request.id == fallback.id) return request;
    }
    return fallback;
  }

  void replaceRequest(PublicRequest next) {
    setRequests(cachedRequests
        .map((request) => request.id == next.id ? next : request)
        .toList());
  }

  void _scheduleRealtimeRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(refresh(silent: true).catchError((_) {}));
    });
  }

  void _scheduleMarkRequestsRead() {
    _markReadDebounce?.cancel();
    _markReadDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(_markRequestsRead());
    });
  }

  Future<void> _markRequestsRead() async {
    try {
      await widget.api.markPublicRequestsRead(currentGroup.id);
    } catch (_) {}
  }

  Future<List<PublicRequest>> loadRequests() async {
    final requests = List<PublicRequest>.from(
        await requestsApi.listRequests(currentGroup.id))
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    cachedRequests = requests;
    _requestsLoaded = true;
    unawaited(_markRequestsRead());
    return requests;
  }

  Future<int> loadModerationCount() async {
    if (!canModerate) return 0;
    try {
      return await requestsApi.countModerationItems(currentGroup.id);
    } catch (_) {
      return 0;
    }
  }

  Future<void> refresh({bool silent = false}) async {
    final next = loadRequests();
    final nextModerationCount = loadModerationCount();
    if (silent) {
      await next;
      final moderationCount = await nextModerationCount;
      if (mounted) {
        setState(() {
          moderationCountFuture = Future.value(moderationCount);
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        requestsFuture = next;
        moderationCountFuture = nextModerationCount;
      });
    }
    await Future.wait([next, nextModerationCount]);
  }

  Future<void> openStatistics() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GroupStatisticsScreen(api: requestsApi, group: currentGroup),
      ),
    );
  }

  Future<void> createRequest() async {
    final created = await showModalBottomSheet<PublicRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => CreatePublicRequestMediaSheet(
        api: requestsApi,
        groupId: currentGroup.id,
      ),
    );
    if (created != null) {
      final updated = [
        created,
        ...cachedRequests.where((request) => request.id != created.id),
      ];
      cachedRequests = updated;
      if (mounted) {
        setState(() {
          cachedRequests = updated;
          _requestsLoaded = true;
        });
        showAppSnack(context, AppLanguageScope.textOf(context).postPublished);
      }
    }
  }

  Future<void> vote(PublicRequest request, String voteType) async {
    final current = currentRequest(request);
    if (current.interactionMode == 'read_only' ||
        _votesInFlight.contains(current.id)) return;
    _votesInFlight.add(current.id);
    final previous = cachedRequests;
    replaceRequest(optimisticPublicRequestVote(current, voteType));
    try {
      final PublicRequestVoteUpdate update;
      if (current.myVote == voteType) {
        update = await requestsApi.clearVote(current.id);
      } else if (voteType == 'support') {
        update = await requestsApi.support(current.id);
      } else {
        update = await requestsApi.oppose(current.id);
      }
      if (mounted) applyVoteUpdate(update);
    } catch (error) {
      setRequests(previous);
      if (mounted)
        showAppSnack(context, localizedMessage(context, error.toString()));
    } finally {
      _votesInFlight.remove(current.id);
    }
  }

  Future<void> updateStatus(PublicRequest request, String status) async {
    if (!canModerate) return;
    final current = currentRequest(request);
    if (current.status == status) return;
    final previous = cachedRequests;
    final next = current.copyWith(status: status, updatedAt: DateTime.now());
    replaceRequest(next);
    try {
      await requestsApi.updateStatus(requestId: current.id, status: status);
      if (mounted) {
        final text = AppLanguageScope.textOf(context);
        showAppSnack(
            context, text.isKy ? 'Статус жаңыртылды.' : 'Статус обновлён.');
      }
    } catch (error) {
      setRequests(previous);
      if (mounted)
        showAppSnack(context, localizedMessage(context, error.toString()));
    }
  }

  Future<void> openDetails(PublicRequest request) async {
    if (request.interactionMode != 'discussion') return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicRequestDetailsScreen(
          api: requestsApi,
          request: currentRequest(request),
          canModerate: canModerate,
          currentUserId: widget.user.id,
          onStatusChanged:
              canModerate ? (status) => updateStatus(request, status) : null,
          onRequestChanged: replaceRequest,
        ),
      ),
    );
  }

  Future<void> openModerationQueue() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupModerationScreen(
          api: requestsApi,
          group: currentGroup,
        ),
      ),
    );
  }

  String get groupAccessCode =>
      formatGroupInviteCode(ensuredInviteCode ?? currentGroup.inviteCode ?? '');

  String get groupAccessQrValue =>
      ensuredQrPass ?? currentGroup.qrPass ?? groupAccessCode;

  Future<void> showGroupAccess() async {
    var code = groupAccessCode;
    if (code.isEmpty) {
      try {
        final group = await requestsApi.ensureGroupInviteCode(currentGroup.id);
        if (!mounted) return;
        setState(() {
          ensuredInviteCode = group.inviteCode;
          ensuredQrPass = group.qrPass;
        });
        code = formatGroupInviteCode(group.inviteCode ?? '');
      } catch (error) {
        if (mounted)
          showAppSnack(context, localizedMessage(context, error.toString()));
        return;
      }
    }
    if (code.isEmpty) {
      final text = AppLanguageScope.textOf(context);
      showAppSnack(
        context,
        text.isKy
            ? 'Топтун чакыруу коду азырынча түзүлгөн эмес.'
            : 'Код приглашения группы пока не создан.',
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => GroupAccessSheet(
          groupTitle: currentGroup.title,
          code: code,
          qrValue: groupAccessQrValue),
    );
  }

  Future<void> inviteByPhone() async {
    if (!canInvite) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => InviteByPhoneSheet(api: widget.api, group: currentGroup),
    );
  }

  Future<void> changeRoleByPhone() async {
    if (!canChangeRoles) return;
    final text = AppLanguageScope.textOf(context);
    final phoneController = TextEditingController(text: '+996');
    var loading = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> changeRole(String role) async {
            final phone = phoneController.text.trim();
            if (phone.isEmpty || loading) return;
            setSheetState(() => loading = true);
            try {
              await requestsApi.updateGroupMemberRoleByPhone(
                groupId: currentGroup.id,
                phone: phone,
                role: role,
              );
              if (!context.mounted) return;
              Navigator.pop(sheetContext);
              showAppSnack(context,
                  role == 'admin' ? text.adminAssigned : text.adminRemoved);
            } catch (error) {
              if (context.mounted) {
                showAppSnack(
                    context, localizedMessage(context, error.toString()));
              }
            } finally {
              if (context.mounted) setSheetState(() => loading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 22,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text.manageAdmins,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(text.manageAdminsDescription),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: text.mobileNumber,
                    hintText: '+996700123456',
                    prefixIcon: const Icon(Icons.phone_iphone_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: loading ? null : () => changeRole('admin'),
                  icon: const Icon(Icons.admin_panel_settings_rounded),
                  label: Text(loading ? text.pleaseWait : text.makeAdmin),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: loading ? null : () => changeRole('member'),
                  icon: const Icon(Icons.person_outline_rounded),
                  label: Text(text.removeAdmin),
                ),
              ],
            ),
          );
        },
      ),
    );
    phoneController.dispose();
  }

  Future<void> muteCommentsByPhone() async {
    if (!canMuteComments) return;
    final rootContext = context;
    final text = AppLanguageScope.textOf(context);
    final reasonController = TextEditingController();
    final membersFuture = requestsApi.listGroupMembers(currentGroup.id);
    var durationMinutes = 60;
    var loading = false;
    String? selectedUserId;
    String? errorText;
    String? successText;

    String durationLabel(int minutes) {
      switch (minutes) {
        case 60:
          return text.oneHour;
        case 180:
          return text.threeHours;
        case 360:
          return text.sixHours;
        case 720:
          return text.twelveHours;
        case 1440:
          return text.oneDay;
        case 10080:
          return text.sevenDays;
        case 43200:
          return text.thirtyDays;
        case 0:
          return text.forever;
        default:
          return '$minutes min';
      }
    }

    bool canSelectMember(GroupMember member) {
      if (member.userId == widget.user.id) return false;
      if (member.role == 'owner') return false;
      if (currentGroup.ownerId == widget.user.id) return true;
      return member.role == 'member';
    }

    await showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(rootContext).cardColor,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void showResult({String? error, String? success}) {
            setSheetState(() {
              errorText = error;
              successText = success;
            });
            if (rootContext.mounted) {
              showAppSnack(rootContext, error ?? success ?? '');
            }
          }

          Future<void> mute() async {
            final userId = selectedUserId;
            if (userId == null || userId.isEmpty || loading) return;
            setSheetState(() {
              loading = true;
              errorText = null;
              successText = null;
            });
            try {
              await requestsApi.setCommentMute(
                groupId: currentGroup.id,
                userId: userId,
                durationMinutes: durationMinutes,
                reason: reasonController.text.trim(),
              );
              showResult(success: text.mutedDone);
            } catch (error) {
              showResult(
                  error: localizedMessage(rootContext, error.toString()));
            } finally {
              if (context.mounted) setSheetState(() => loading = false);
            }
          }

          Future<void> unmute() async {
            final userId = selectedUserId;
            if (userId == null || userId.isEmpty || loading) return;
            setSheetState(() {
              loading = true;
              errorText = null;
              successText = null;
            });
            try {
              await requestsApi.clearCommentMute(
                  groupId: currentGroup.id, userId: userId);
              showResult(success: text.unmutedDone);
            } catch (error) {
              showResult(
                  error: localizedMessage(rootContext, error.toString()));
            } finally {
              if (context.mounted) setSheetState(() => loading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 22,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    text.blockComments,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(text.blockCommentsDescription),
                  const SizedBox(height: 14),
                  FutureBuilder<List<GroupMember>>(
                    future: membersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final members = (snapshot.data ?? const <GroupMember>[])
                          .where(canSelectMember)
                          .toList();
                      if (members.isEmpty) {
                        return Text(
                          text.isKy
                              ? 'Бөгөттөй турган катышуучу жок.'
                              : 'Нет участников, которых можно заблокировать.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }
                      selectedUserId ??= members.first.userId;
                      return DropdownButtonFormField<String>(
                        value: selectedUserId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: text.mobileNumber,
                          prefixIcon: const Icon(Icons.people_outline_rounded),
                        ),
                        items: members
                            .map(
                              (member) => DropdownMenuItem<String>(
                                value: member.userId,
                                child: Text(
                                  '${member.displayName} · ${member.phone ?? ''} · ${member.role}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: loading
                            ? null
                            : (value) =>
                                setSheetState(() => selectedUserId = value),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: durationMinutes,
                    decoration: InputDecoration(
                      labelText: text.blockDuration,
                      prefixIcon: const Icon(Icons.timer_outlined),
                    ),
                    items: const [60, 180, 360, 720, 1440, 10080, 43200, 0]
                        .map(
                          (minutes) => DropdownMenuItem<int>(
                            value: minutes,
                            child: Text(durationLabel(minutes)),
                          ),
                        )
                        .toList(),
                    onChanged: loading
                        ? null
                        : (value) =>
                            setSheetState(() => durationMinutes = value ?? 60),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    minLines: 1,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: text.blockReason,
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (successText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      successText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: loading || selectedUserId == null ? null : mute,
                    icon: const Icon(Icons.block_rounded),
                    label: Text(
                        loading ? text.pleaseWait : text.blockCommentsButton),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed:
                        loading || selectedUserId == null ? null : unmute,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: Text(text.unblockCommentsButton),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    reasonController.dispose();
  }

  Future<void> changeGroupPhoto() async {
    if (!canModerate || updatingGroupPhoto) return;
    final text = AppLanguageScope.textOf(context);
    try {
      final picked = await imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 82,
      );
      if (picked == null || !mounted) return;

      setState(() => updatingGroupPhoto = true);
      final original = await picked.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        original,
        minWidth: 512,
        minHeight: 512,
        quality: 72,
        format: CompressFormat.jpeg,
      );
      if (compressed.isEmpty || compressed.length > maxGroupAvatarBytes) {
        throw ApiException(
          text.isKy
              ? 'Сүрөт өтө чоң. Башка сүрөт тандаңыз.'
              : 'Фото слишком большое. Выберите другое изображение.',
        );
      }

      final updated = await widget.api.updateGroupAvatar(
        groupId: currentGroup.id,
        avatarData: 'data:image/jpeg;base64,${base64Encode(compressed)}',
      );
      if (!mounted) return;
      setState(() {
        currentGroup = updated.copyWith(
          unreadPublicRequestCount: currentGroup.unreadPublicRequestCount,
          qrPass: currentGroup.qrPass,
        );
        updatingGroupPhoto = false;
      });
      showAppSnack(
        context,
        text.isKy ? 'Топтун сүрөтү жаңыртылды.' : 'Фото группы обновлено.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => updatingGroupPhoto = false);
      showAppSnack(context, localizedMessage(context, error.toString()));
    }
  }

  PopupMenuItem<String> groupMenuItem({
    required String value,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ]),
    );
  }

  Future<void> handleGroupMenuAction(String value) async {
    switch (value) {
      case 'statistics':
        await openStatistics();
        break;
      case 'access':
        await showGroupAccess();
        break;
      case 'admins':
        await changeRoleByPhone();
        break;
      case 'mute':
        await muteCommentsByPhone();
        break;
      case 'invite':
        await inviteByPhone();
        break;
      case 'moderation':
        await openModerationQueue();
        break;
      case 'group_photo':
        await changeGroupPhoto();
        break;
      case 'settings':
        if (mounted) await showAppSettingsSheet(context);
        break;
    }
  }

  Widget groupMenuButton(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return FutureBuilder<int>(
      future: moderationCountFuture,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final reviewLabel = count > 0
            ? (text.isKy
                ? 'Текшерүүдөгү материалдар ($count)'
                : 'Материалы на проверке ($count)')
            : (text.isKy
                ? 'Текшерүүдөгү материалдар'
                : 'Материалы на проверке');
        return PopupMenuButton<String>(
          tooltip: text.isKy ? 'Меню' : 'Меню',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            handleGroupMenuAction(value);
          },
          itemBuilder: (_) => [
            groupMenuItem(
              value: 'statistics',
              icon: Icons.analytics_outlined,
              label: text.statistics,
            ),
            groupMenuItem(
              value: 'access',
              icon: Icons.qr_code_rounded,
              label: text.codeAndQr,
            ),
            if (canChangeRoles)
              groupMenuItem(
                value: 'admins',
                icon: Icons.admin_panel_settings_outlined,
                label: text.manageAdmins,
              ),
            if (canMuteComments)
              groupMenuItem(
                value: 'mute',
                icon: Icons.block_rounded,
                label: text.blockComments,
              ),
            if (canInvite)
              groupMenuItem(
                value: 'invite',
                icon: Icons.person_add_alt_1_rounded,
                label: text.inviteByPhone,
              ),
            if (canModerate)
              groupMenuItem(
                value: 'moderation',
                icon: Icons.fact_check_outlined,
                label: reviewLabel,
              ),
            if (canModerate)
              groupMenuItem(
                value: 'group_photo',
                icon: Icons.add_a_photo_outlined,
                label: updatingGroupPhoto
                    ? (text.isKy ? 'Жүктөлүүдө...' : 'Загрузка...')
                    : (text.isKy
                        ? 'Топтун сүрөтүн өзгөртүү'
                        : 'Изменить фото группы'),
              ),
            groupMenuItem(
              value: 'settings',
              icon: Icons.settings_rounded,
              label: text.settings,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return Scaffold(
      key: const ValueKey('public_requests_screen'),
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            KoomAvatar(
              label: currentGroup.title,
              radius: 20,
              icon: currentGroup.visibility == 'public'
                  ? Icons.groups_2_rounded
                  : Icons.lock_rounded,
              imageBytes: currentGroup.avatarBytes,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentGroup.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentGroup.memberCount > 0
                        ? (text.isKy
                            ? '${currentGroup.memberCount} катышуучу'
                            : '${currentGroup.memberCount} участников')
                        : (currentGroup.visibility == 'public'
                            ? text.publicGroup
                            : text.privateGroup),
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          groupMenuButton(context),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: KoomAdaptiveFab(
        key: const ValueKey('public_request_create_action'),
        onPressed: createRequest,
        icon: Icons.add_rounded,
        label: text.newPost,
      ),
      body: KoomPageBackground(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: FutureBuilder<List<PublicRequest>>(
            future: requestsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !_requestsLoaded) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 180),
                    Center(child: CircularProgressIndicator()),
                  ],
                );
              }
              if (snapshot.hasError && !_requestsLoaded) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    _CommunityOverview(group: currentGroup),
                    const SizedBox(height: 16),
                    ErrorBanner(message: snapshot.error.toString()),
                  ],
                );
              }
              final allRequests = _requestsLoaded
                  ? cachedRequests
                  : snapshot.data ?? const <PublicRequest>[];
              final requests = switch (_requestFilter) {
                'resolved' => allRequests
                    .where((request) =>
                        request.status == 'resolved' ||
                        request.status == 'accepted')
                    .toList(),
                'unresolved' => allRequests
                    .where((request) =>
                        request.status != 'resolved' &&
                        request.status != 'accepted')
                    .toList(),
                _ => allRequests,
              };
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
                itemCount: requests.length + (requests.isEmpty ? 3 : 2),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _CommunityOverview(group: currentGroup);
                  }
                  if (index == 1) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _RequestFilterChip(
                                label: text.isKy ? 'Баары' : 'Все',
                                selected: _requestFilter == 'all',
                                onTap: () =>
                                    setState(() => _requestFilter = 'all'),
                              ),
                              const SizedBox(width: 8),
                              _RequestFilterChip(
                                label: text.isKy ? 'Чечилген' : 'Решённые',
                                selected: _requestFilter == 'resolved',
                                onTap: () =>
                                    setState(() => _requestFilter = 'resolved'),
                              ),
                              const SizedBox(width: 8),
                              _RequestFilterChip(
                                label: text.isKy ? 'Чечилбеген' : 'Нерешённые',
                                selected: _requestFilter == 'unresolved',
                                onTap: () => setState(
                                    () => _requestFilter = 'unresolved'),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 22, 2, 12),
                          child: KoomSectionTitle(
                            title: text.isKy ? 'Жарыялар' : 'Публикации',
                            subtitle: requests.isEmpty
                                ? text.postsDescription
                                : (text.isKy
                                    ? '${requests.length} жарыя'
                                    : '${requests.length} публикаций'),
                          ),
                        ),
                      ],
                    );
                  }
                  if (requests.isEmpty) {
                    return EmptyPostsView(onCreate: createRequest);
                  }
                  final request = requests[index - 2];
                  return MediaPublicRequestCard(
                    request: request,
                    canModerate: canModerate,
                    onVote: (voteType) => vote(request, voteType),
                    onTap: () => openDetails(request),
                    onStatus: (status) => updateStatus(request, status),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CommunityOverview extends StatelessWidget {
  const _CommunityOverview({required this.group});

  final ChatGroup group;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final description = group.description.trim().isEmpty
        ? (text.isKy
            ? 'Коомчулуктун жаңылыктары, сунуштары жана талкуулары'
            : 'Новости, предложения и обсуждения сообщества')
        : group.description.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KoomCard(
          gradient: MobileChatTheme.brandGradient,
          borderColor: Colors.white.withValues(alpha: 0.14),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  KoomAvatar(
                    label: group.title,
                    radius: 29,
                    background: Colors.white.withValues(alpha: 0.17),
                    icon: group.visibility == 'public'
                        ? Icons.groups_2_rounded
                        : Icons.lock_rounded,
                    imageBytes: group.avatarBytes,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _WhitePill(
                              icon: group.visibility == 'public'
                                  ? Icons.public_rounded
                                  : Icons.lock_outline_rounded,
                              label: group.visibility == 'public'
                                  ? text.publicGroup
                                  : text.privateGroup,
                            ),
                            if (group.memberCount > 0)
                              _WhitePill(
                                icon: Icons.people_outline_rounded,
                                label: '${group.memberCount}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestFilterChip extends StatelessWidget {
  const _RequestFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}

class _WhitePill extends StatelessWidget {
  const _WhitePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth =
        (MediaQuery.sizeOf(context).width - 56).clamp(100.0, 320.0).toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
