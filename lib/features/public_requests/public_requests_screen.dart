import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/blocked_users.dart';
import '../../data/models.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../services/group_realtime_service.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';
import '../groups/group_members_screen.dart';
import '../groups/group_sheets.dart';
import '../safety/group_reports_screen.dart';
import '../safety/safety_ui.dart';
import '../statistics/group_statistics_screen.dart';
import 'moderation_screen.dart';
import 'public_request_media_screens.dart';
import 'public_request_media_widgets.dart';
import 'public_requests_widgets.dart';

/// A single group: its feed, its members, its statistics and — for users who
/// may moderate — its moderation queue, as tabs under the app bar. The
/// overflow menu keeps only the rare actions.
class PublicRequestsScreen extends StatefulWidget {
  const PublicRequestsScreen({
    super.key,
    required this.api,
    required this.user,
    required this.group,
    this.initialRequestId,
    @visibleForTesting this.requestsApi,
    @visibleForTesting this.realtime,
  });

  final ApiClient api;
  final UserProfile user;
  final ChatGroup group;
  final String? initialRequestId;

  /// Test seam: replaces the group API client.
  final PublicRequestsApi? requestsApi;

  /// Test seam: replaces the group websocket.
  final GroupRealtimeService? realtime;

  @override
  State<PublicRequestsScreen> createState() => _PublicRequestsScreenState();
}

class _PublicRequestsScreenState extends State<PublicRequestsScreen>
    with TickerProviderStateMixin {
  static const int maxGroupAvatarBytes = 512 * 1024;
  static const int requestsPageSize = 50;

  late final PublicRequestsApi requestsApi;
  late final GroupRealtimeService realtime;
  late final TabController _tabs;
  late ChatGroup currentGroup;
  final ImagePicker imagePicker = ImagePicker();
  final ScrollController _requestsScrollController = ScrollController();
  bool updatingGroupPhoto = false;
  late Future<List<PublicRequest>> requestsFuture;
  late Future<int> moderationCountFuture;
  List<PublicRequest> cachedRequests = const <PublicRequest>[];
  bool _requestsLoaded = false;
  bool _loadingMoreRequests = false;
  bool _hasMoreRequests = true;
  String _requestFilter = 'all';
  Timer? _refreshDebounce;
  Timer? _markReadDebounce;
  String? ensuredInviteCode;
  String? ensuredQrPass;
  final Set<String> _votesInFlight = <String>{};
  bool _realtimeWasReady = false;
  bool _initialRequestOpened = false;

  bool get canModerate =>
      currentGroup.myRole == 'owner' || currentGroup.myRole == 'admin';
  bool get canInvite => currentGroup.canInvite;
  bool get canChangeRoles => currentGroup.ownerId == widget.user.id;
  bool get canMuteComments => canModerate;

  @override
  void initState() {
    super.initState();
    currentGroup = widget.group;
    _tabs = TabController(length: canModerate ? 4 : 3, vsync: this);
    // The "new post" button belongs to the feed tab only.
    _tabs.addListener(_handleTabChanged);
    _requestsScrollController.addListener(_handleRequestsScroll);
    requestsApi = widget.requestsApi ??
        PublicRequestsApi(
          baseUrl: widget.api.baseUrl,
          sessionStore: widget.api.sessionStore,
        );
    realtime = widget.realtime ??
        GroupRealtimeService(api: widget.api, groupId: currentGroup.id);
    final initialRequestsFuture = loadRequests();
    requestsFuture = initialRequestsFuture;
    moderationCountFuture = loadModerationCount();
    realtime.connect(onEvent: _handleRealtimeEvent);
    BlockedUsersController.instance.addListener(_handleBlockedUsersChanged);
    unawaited(_openInitialRequest(initialRequestsFuture));
  }

  void _handleBlockedUsersChanged() {
    if (mounted) setState(() {});
  }

  /// Realtime events are not filtered by the server, so drop anything authored
  /// by a blocked user before it reaches the list.
  bool _isFromBlockedUser(GroupRealtimeEvent event) {
    final payload = event.payload;
    if (payload is! Map<String, dynamic>) return false;
    final blocked = BlockedUsersController.instance;
    final authorId = payload['author_id']?.toString();
    if (blocked.isBlocked(authorId)) return true;
    final comment = payload['comment'];
    if (comment is Map<String, dynamic> &&
        blocked.isBlocked(comment['author_id']?.toString())) {
      return true;
    }
    return false;
  }

  void _handleTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _markReadDebounce?.cancel();
    _tabs.removeListener(_handleTabChanged);
    _tabs.dispose();
    _requestsScrollController.removeListener(_handleRequestsScroll);
    _requestsScrollController.dispose();
    realtime.close();
    BlockedUsersController.instance.removeListener(_handleBlockedUsersChanged);
    super.dispose();
  }

  void _handleRealtimeEvent(GroupRealtimeEvent event) {
    if (!mounted || event.groupId != currentGroup.id) return;
    if (_isFromBlockedUser(event)) return;
    switch (event.type) {
      case 'connection.ready':
        if (_realtimeWasReady) {
          _scheduleRealtimeRefresh();
        } else {
          _realtimeWasReady = true;
        }
        break;
      case 'group.avatar_updated':
        final payload = event.payload;
        if (payload is Map<String, dynamic>) {
          final avatarData = payload['avatar_data'] as String? ?? '';
          setState(() {
            currentGroup = currentGroup.copyWith(avatarData: avatarData);
          });
        }
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
        unawaited(_refreshModerationCount());
        break;
    }
  }

  void upsertRequestFromPayload(dynamic payload) {
    if (payload is! Map<String, dynamic>) return;
    final request = requestsApi.resolveMediaLinks(PublicRequest.fromJson(payload));
    final updated = [
      request,
      ...cachedRequests.where((item) => item.id != request.id),
    ]..sort(_compareRequestsNewestFirst);
    setRequests(updated);
  }

  int _compareRequestsNewestFirst(PublicRequest a, PublicRequest b) {
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }

  void _handleRequestsScroll() {
    if (!_requestsScrollController.hasClients) return;
    final position = _requestsScrollController.position;
    if (position.maxScrollExtent - position.pixels < 420) {
      unawaited(_loadMoreRequests());
    }
  }

  Future<void> _loadMoreRequests() async {
    if (!_requestsLoaded || _loadingMoreRequests || !_hasMoreRequests || cachedRequests.isEmpty) return;
    setState(() => _loadingMoreRequests = true);
    final oldest = cachedRequests.last;
    try {
      final page = await requestsApi.listRequests(currentGroup.id, before: oldest.createdAt, beforeId: oldest.id);
      if (!mounted) return;
      final knownIds = cachedRequests.map((request) => request.id).toSet();
      final merged = [
        ...cachedRequests,
        ...page.where((request) => !knownIds.contains(request.id)),
      ]..sort(_compareRequestsNewestFirst);
      cachedRequests = merged;
      _hasMoreRequests = page.length == requestsPageSize;
      _requestsLoaded = true;
    } catch (error) {
      if (mounted) showAppSnack(context, localizedMessage(context, error.toString()));
    } finally {
      if (mounted) setState(() => _loadingMoreRequests = false);
    }
  }

  void updateRequestCommentCount(String requestId, int delta) {
    if (requestId.isEmpty) return;
    final updated = cachedRequests
        .map(
          (request) => request.id == requestId
              ? request.copyWith(
                  commentCount: request.commentCount + delta < 0
                      ? 0
                      : request.commentCount + delta,
                )
              : request,
        )
        .toList();
    setRequests(updated);
  }

  void updateRequestStatus(String requestId, dynamic payload) {
    if (requestId.isEmpty || payload is! Map<String, dynamic>) return;
    final status = payload['status'] as String?;
    if (status == null || status.isEmpty) return;
    final updated = cachedRequests
        .map(
          (request) => request.id == requestId
              ? request.copyWith(status: status)
              : request,
        )
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
    setRequests(
      cachedRequests
          .map((request) => request.id == next.id ? next : request)
          .toList(),
    );
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
      await requestsApi.listRequests(currentGroup.id),
    )..sort(_compareRequestsNewestFirst);
    cachedRequests = requests;
    _requestsLoaded = true;
    _hasMoreRequests = requests.length == requestsPageSize;
    unawaited(_markRequestsRead());
    return requests;
  }

  Future<void> _openInitialRequest(
    Future<List<PublicRequest>> initialRequestsFuture,
  ) async {
    final requestId = widget.initialRequestId?.trim() ?? '';
    if (requestId.isEmpty || _initialRequestOpened) return;
    try {
      final requests = await initialRequestsFuture;
      if (!mounted || _initialRequestOpened) return;
      PublicRequest? target;
      for (final request in requests) {
        if (request.id == requestId) {
          target = request;
          break;
        }
      }
      if (target == null) return;
      _initialRequestOpened = true;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await openDetails(target);
    } catch (_) {
      // The normal requests screen remains available if the target was deleted
      // or could not be loaded.
    }
  }

  Future<int> loadModerationCount() async {
    if (!canModerate) return 0;
    try {
      return await requestsApi.countModerationItems(currentGroup.id);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _refreshModerationCount() async {
    final count = await loadModerationCount();
    if (!mounted) return;
    setState(() {
      moderationCountFuture = Future.value(count);
    });
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

  Future<void> openReports() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupReportsScreen(api: requestsApi, group: currentGroup),
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
      final visibleCreated = created.authorAvatarData.trim().isEmpty
          ? created.copyWith(authorAvatarData: widget.user.avatarData)
          : created;
      final updated = [
        visibleCreated,
        ...cachedRequests.where((request) => request.id != visibleCreated.id),
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
        _votesInFlight.contains(current.id)) {
      return;
    }
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
      if (mounted) {
        showAppSnack(context, localizedMessage(context, error.toString()));
      }
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
          context,
          text.isKy ? 'Статус жаңыртылды.' : 'Статус обновлён.',
        );
      }
    } catch (error) {
      setRequests(previous);
      if (mounted) {
        showAppSnack(context, localizedMessage(context, error.toString()));
      }
    }
  }

  Future<void> openDetails(PublicRequest request) async {
    final current = currentRequest(request);
    if (current.interactionMode != 'discussion') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MediaPublicRequestDetailsScreen(
            api: requestsApi,
            request: current,
            canModerate: canModerate,
            currentUserId: widget.user.id,
            onStatusChanged: canModerate
                ? (status) => updateStatus(current, status)
                : null,
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicRequestDetailsScreen(
          api: requestsApi,
          request: current,
          canModerate: canModerate,
          currentUserId: widget.user.id,
          onStatusChanged: canModerate
              ? (status) => updateStatus(current, status)
              : null,
          onRequestChanged: replaceRequest,
        ),
      ),
    );
  }

  String get groupAccessCode =>
      formatGroupInviteCode(ensuredInviteCode ?? currentGroup.inviteCode ?? '');

  String get groupAccessQrValue =>
      ensuredQrPass ?? currentGroup.qrPass ?? groupAccessCode;

  /// Members without owner/admin rights only see the code when the server
  /// still includes it in their group payload (older servers).
  bool get canShowGroupAccess => canInvite || groupAccessCode.isNotEmpty;

  Future<void> showGroupAccess() async {
    final text = AppLanguageScope.textOf(context);
    var code = groupAccessCode;
    if (code.isEmpty) {
      if (!canInvite) {
        showAppSnack(context, text.inviteCodeAdminsOnly);
        return;
      }
      try {
        final group = await requestsApi.ensureGroupInviteCode(currentGroup.id);
        if (!mounted) return;
        setState(() {
          ensuredInviteCode = group.inviteCode;
          ensuredQrPass = group.qrPass;
        });
        code = formatGroupInviteCode(group.inviteCode ?? '');
      } catch (error) {
        if (mounted) {
          showAppSnack(
            context,
            error is ApiException && error.statusCode == 403
                ? text.inviteCodeAdminsOnly
                : localizedMessage(context, error.toString()),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    if (code.isEmpty) {
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
        qrValue: groupAccessQrValue,
        onRotate: canInvite ? rotateInviteCode : null,
      ),
    );
  }

  /// Issues a new invite code and returns the new (code, QR value).
  Future<(String, String)> rotateInviteCode() async {
    final group = await requestsApi.rotateGroupInviteCode(currentGroup.id);
    final code = formatGroupInviteCode(group.inviteCode ?? '');
    if (mounted) {
      setState(() {
        ensuredInviteCode = group.inviteCode;
        ensuredQrPass = group.qrPass;
      });
    }
    return (code, group.qrPass ?? code);
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
              showAppSnack(
                context,
                role == 'admin' ? text.adminAssigned : text.adminRemoved,
              );
            } catch (error) {
              if (context.mounted) {
                showAppSnack(
                  context,
                  localizedMessage(context, error.toString()),
                );
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
              if (!rootContext.mounted) return;
              showResult(
                error: localizedMessage(rootContext, error.toString()),
              );
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
                groupId: currentGroup.id,
                userId: userId,
              );
              showResult(success: text.unmutedDone);
            } catch (error) {
              if (!rootContext.mounted) return;
              showResult(
                error: localizedMessage(rootContext, error.toString()),
              );
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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
                          labelText: text.groupMember,
                          prefixIcon: const Icon(Icons.people_outline_rounded),
                        ),
                        items: members
                            .map(
                              (member) => DropdownMenuItem<String>(
                                value: member.userId,
                                child: Text(
                                  '${member.displayName} · ${member.role}',
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
                        : (value) => setSheetState(
                            () => durationMinutes = value ?? 60,
                          ),
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
                      loading ? text.pleaseWait : text.blockCommentsButton,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: loading || selectedUserId == null
                        ? null
                        : unmute,
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
      height: 56,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> withGroupMenuSeparators(
    List<PopupMenuItem<String>> items,
  ) {
    final entries = <PopupMenuEntry<String>>[];
    for (var index = 0; index < items.length; index++) {
      entries.add(items[index]);
      if (index < items.length - 1) {
        entries.add(const PopupMenuDivider(height: 1));
      }
    }
    return entries;
  }

  Future<void> handleGroupMenuAction(String value) async {
    switch (value) {
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
      case 'reports':
        await openReports();
        break;
      case 'group_photo':
        await changeGroupPhoto();
        break;
      case 'settings':
        if (mounted) await showAppSettingsSheet(context);
        break;
    }
  }

  void openGroupPhoto() {
    final imageBytes = currentGroup.avatarBytes;
    if (imageBytes == null || imageBytes.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _GroupPhotoScreen(
          title: currentGroup.title,
          imageBytes: imageBytes,
        ),
      ),
    );
  }

  /// Rare group actions. The feed, members, statistics and moderation queue
  /// are tabs now, so they are no longer buried in here.
  Widget groupMenuButton(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return PopupMenuButton<String>(
      tooltip: 'Меню',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        handleGroupMenuAction(value);
      },
      itemBuilder: (_) => withGroupMenuSeparators([
        if (canShowGroupAccess)
          groupMenuItem(
            value: 'access',
            icon: Icons.qr_code_rounded,
            label: text.codeAndQr,
          ),
        if (canModerate)
          groupMenuItem(
            value: 'group_photo',
            icon: Icons.add_a_photo_outlined,
            label: updatingGroupPhoto ? text.uploading : text.changeGroupPhoto,
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
            value: 'reports',
            icon: Icons.flag_outlined,
            label: text.reports,
          ),
        groupMenuItem(
          value: 'settings',
          icon: Icons.settings_rounded,
          label: text.settings,
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return Scaffold(
      key: const ValueKey('public_requests_screen'),
      appBar: AppBar(
        titleSpacing: KoomSpacing.md,
        title: Row(
          children: [
            Tooltip(
              message: currentGroup.avatarBytes == null
                  ? currentGroup.title
                  : (text.isKy
                      ? 'Сүрөттү ачуу'
                      : 'Открыть фото'),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: currentGroup.avatarBytes == null ? null : openGroupPhoto,
                child: KoomAvatar(
                  label: currentGroup.title,
                  radius: 20,
                  icon: currentGroup.visibility == 'public'
                      ? Icons.groups_2_rounded
                      : Icons.lock_rounded,
                  imageBytes: currentGroup.avatarBytes,
                ),
              ),
            ),
            const SizedBox(width: KoomSpacing.md),
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
                  if (currentGroup.memberCount > 0)
                    Text(
                      _memberCountLabel(text, currentGroup.memberCount),
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
        actions: [groupMenuButton(context), const SizedBox(width: KoomSpacing.md)],
        bottom: TabBar(
          key: const ValueKey('group_tab_bar'),
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(key: const ValueKey('group_tab_feed'), text: text.groupFeed),
            Tab(
              key: const ValueKey('group_tab_members'),
              text: text.groupMembers,
            ),
            Tab(
              key: const ValueKey('group_tab_statistics'),
              text: text.statistics,
            ),
            if (canModerate)
              Tab(
                key: const ValueKey('group_tab_moderation'),
                child: _ModerationTabLabel(
                  label: text.groupModeration,
                  countFuture: moderationCountFuture,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 0
          ? KoomAdaptiveFab(
              key: const ValueKey('public_request_create_action'),
              onPressed: createRequest,
              icon: Icons.add_rounded,
              label: text.newPost,
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildFeed(context, text),
          GroupMembersView(
            api: requestsApi,
            group: currentGroup,
            currentUserId: widget.user.id,
          ),
          GroupStatisticsView(api: requestsApi, group: currentGroup),
          if (canModerate)
            GroupModerationView(
              api: requestsApi,
              group: currentGroup,
              onPendingCountChanged: (count) {
                if (!mounted) return;
                setState(() {
                  moderationCountFuture = Future.value(count);
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFeed(BuildContext context, AppText text) {
    return KoomPageBackground(
      child: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<PublicRequest>>(
          future: requestsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !_requestsLoaded) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  KoomSpacing.lg,
                  KoomSpacing.lg,
                  KoomSpacing.lg,
                  108,
                ),
                children: const [
                  KoomSkeletonList(
                    itemCount: 4,
                    itemHeight: 172,
                    radius: KoomRadii.lg,
                  ),
                ],
              );
            }
            if (snapshot.hasError && !_requestsLoaded) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  KoomSpacing.lg,
                  KoomSpacing.sm,
                  KoomSpacing.lg,
                  KoomSpacing.xxl,
                ),
                children: [
                  ErrorBanner(
                    message: localizedMessage(
                      context,
                      snapshot.error.toString(),
                    ),
                  ),
                ],
              );
            }
            final allRequests = BlockedUsersController.instance.visible(
              _requestsLoaded
                  ? cachedRequests
                  : snapshot.data ?? const <PublicRequest>[],
              (request) => request.authorId,
            );
            final requests = switch (_requestFilter) {
              'resolved' =>
                allRequests
                    .where(
                      (request) =>
                          request.status == 'resolved' ||
                          request.status == 'accepted',
                    )
                    .toList(),
              'unresolved' =>
                allRequests
                    .where(
                      (request) =>
                          request.status != 'resolved' &&
                          request.status != 'accepted',
                    )
                    .toList(),
              _ => allRequests,
            };
            return ListView.builder(
              controller: _requestsScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                KoomSpacing.lg,
                KoomSpacing.sm,
                KoomSpacing.lg,
                108,
              ),
              itemCount: requests.length +
                  1 +
                  (requests.isEmpty ? 1 : 0) +
                  ((_hasMoreRequests || _loadingMoreRequests) ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: KoomSpacing.md),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _RequestFilterChip(
                              label: text.allFilter,
                              selected: _requestFilter == 'all',
                              onTap: () =>
                                  setState(() => _requestFilter = 'all'),
                            ),
                            const SizedBox(width: KoomSpacing.sm),
                            _RequestFilterChip(
                              label: text.resolved,
                              selected: _requestFilter == 'resolved',
                              onTap: () =>
                                  setState(() => _requestFilter = 'resolved'),
                            ),
                            const SizedBox(width: KoomSpacing.sm),
                            _RequestFilterChip(
                              label: text.isKy
                                  ? 'Чечилбеген'
                                  : 'Нерешённые',
                              selected: _requestFilter == 'unresolved',
                              onTap: () => setState(
                                () => _requestFilter = 'unresolved',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          KoomSpacing.xs,
                          KoomSpacing.xl,
                          KoomSpacing.xs,
                          KoomSpacing.md,
                        ),
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
                if (requests.isEmpty && index == 1) {
                  return EmptyPostsView(onCreate: createRequest);
                }
                final requestIndex = index - 1;
                if (requestIndex >= requests.length) {
                  if (_loadingMoreRequests) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: KoomSpacing.lg,
                      ),
                      child: KoomSkeleton(
                        height: 172,
                        radius: KoomRadii.lg,
                      ),
                    );
                  }
                  if (_hasMoreRequests) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) unawaited(_loadMoreRequests());
                    });
                  }
                  return const SizedBox(height: KoomSpacing.md);
                }
                final request = requests[requestIndex];
                return MediaPublicRequestCard(
                  request: request,
                  canModerate: canModerate,
                  onVote: (voteType) => vote(request, voteType),
                  onTap: () => openDetails(request),
                  onStatus: (status) => updateStatus(request, status),
                  safetyMenu: ContentSafetyMenuButton(
                    api: requestsApi,
                    target: SafetyTarget(
                      targetType: ReportTargetType.publicRequest,
                      targetId: request.id,
                      authorId: request.authorId,
                      authorName: request.authorName,
                      currentUserId: widget.user.id,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Moderation tab label with the pending-review count as a badge.
class _ModerationTabLabel extends StatelessWidget {
  const _ModerationTabLabel({required this.label, required this.countFuture});

  final String label;
  final Future<int> countFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: countFuture,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: KoomSpacing.sm),
              Badge(label: Text(count > 99 ? '99+' : '$count')),
            ],
          ],
        );
      },
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

String _memberCountLabel(AppText text, int count) {
  if (text.isKy) return '$count катышуучу';
  final mod10 = count % 10;
  final mod100 = count % 100;
  final suffix = mod10 == 1 && mod100 != 11
      ? 'участник'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 'участника'
      : 'участников';
  return '$count $suffix';
}

class _GroupPhotoScreen extends StatelessWidget {
  const _GroupPhotoScreen({required this.title, required this.imageBytes});

  final String title;
  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Image.memory(
              imageBytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 72,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
