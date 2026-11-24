import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/public_requests_api.dart';
import '../../services/push_notification_service.dart';
import '../../services/user_realtime_service.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';
import '../group_creation/admin_group_creation_requests_screen.dart';
import '../group_creation/group_creation_requests_screen.dart';
import '../notifications/notifications_controller.dart';
import '../public_requests/public_requests_screen.dart';
import 'group_qr_scan_screen.dart';
import 'public_groups_sheet.dart';

/// Groups destination of the root shell: the user's groups with a local search
/// box and the quick actions for joining one.
///
/// Profile, sign-out and invitations used to live in the overflow sheet here;
/// they are navigation destinations now, so this screen only keeps the actions
/// that belong to groups.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({
    super.key,
    required this.api,
    required this.session,
    required this.notifications,
    this.onShowGroupsTab,
    this.onShowNotificationsTab,
    this.userRealtime,
    this.initialPushData,
  });
  final ApiClient api;
  final AppSession session;

  /// Shared store behind the notifications tab and its badge. This screen owns
  /// the group list, so it pushes every change into it.
  final KoomNotificationsController notifications;

  /// Asks the shell to show this tab, so a tapped notification is not applied
  /// behind another destination.
  final VoidCallback? onShowGroupsTab;

  /// Asks the shell to show the notifications tab (invitation notifications).
  final VoidCallback? onShowNotificationsTab;

  /// Test seam: replaces the user websocket.
  final UserRealtimeService? userRealtime;

  /// Test seam: stands in for the notification the app was opened from.
  final Map<String, String>? initialPushData;

  @override
  State<GroupsScreen> createState() => GroupsScreenState();
}

class GroupsScreenState extends State<GroupsScreen> {
  late Future<List<ChatGroup>> groupsFuture;
  late Future<int> adminRequestsCountFuture;
  late final UserRealtimeService userRealtime =
      widget.userRealtime ?? UserRealtimeService(api: widget.api);
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<ChatGroup> currentGroups = const <ChatGroup>[];
  final Set<String> seenPublicRequestEvents = <String>{};
  StreamSubscription<Map<String, String>>? _foregroundPushSubscription;
  StreamSubscription<Map<String, String>>? _openedPushSubscription;
  Map<String, String>? _pendingOpenedPushData;
  bool _openingNotificationTarget = false;
  Timer? _invitationsCountDebounce;
  Timer? _adminCountDebounce;
  bool get canReviewGroupCreationRequests =>
      widget.session.user.canReviewGroupCreationRequests;
  bool get canManageAllGroups => widget.session.user.canManageAllGroups;

  @override
  void initState() {
    super.initState();
    groupsFuture = loadGroups();
    adminRequestsCountFuture = loadAdminRequestsCount();
    // A pull-to-refresh on the notifications tab also refreshes the group list
    // the "new posts" entries are built from.
    widget.notifications.groupsRefresher = () => refresh(silent: true);
    userRealtime.connect(onEvent: _handleUserRealtimeEvent);
    _foregroundPushSubscription = PushNotificationService.foregroundDataStream
        .listen(_handleForegroundPushData);
    _openedPushSubscription = PushNotificationService.openedDataStream.listen(
      _handleOpenedPushData,
    );
    final pendingOpenedData =
        widget.initialPushData ?? PushNotificationService.takePendingOpenedData();
    if (pendingOpenedData != null) {
      scheduleMicrotask(() => _handleOpenedPushData(pendingOpenedData));
    }
  }

  @override
  void dispose() {
    _foregroundPushSubscription?.cancel();
    _openedPushSubscription?.cancel();
    _invitationsCountDebounce?.cancel();
    _adminCountDebounce?.cancel();
    _searchController.dispose();
    widget.notifications.groupsRefresher = null;
    userRealtime.close();
    super.dispose();
  }

  void _handleUserRealtimeEvent(UserRealtimeEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case 'public_request.created':
        incrementUnreadPublicRequests(event.groupId, event.requestId);
        break;
      case 'public_request.read':
        setUnreadPublicRequests(event.groupId, 0);
        break;
      case 'group.avatar_updated':
        final payload = event.payload;
        if (payload is Map<String, dynamic>) {
          final avatarData = payload['avatar_data'] as String? ?? '';
          setGroups(
            currentGroups
                .map(
                  (group) => group.id == event.groupId
                      ? group.copyWith(avatarData: avatarData)
                      : group,
                )
                .toList(),
          );
        }
        break;
      case 'invite.created':
      case 'invite.reviewed':
        _scheduleInvitationsCountRefresh();
        break;
      case 'group_creation_request.created':
      case 'group_creation_request.reviewed':
        _scheduleAdminCountRefresh();
        break;
    }
  }

  void _handleForegroundPushData(Map<String, String> data) {
    if (!mounted) return;
    switch (data['type']) {
      case 'public_request.created':
        incrementUnreadPublicRequests(
          data['group_id'] ?? '',
          data['request_id'] ?? '',
        );
        break;
      case 'invite.created':
      case 'invite.reviewed':
        _scheduleInvitationsCountRefresh();
        break;
      case 'group_creation_request.created':
      case 'group_creation_request.reviewed':
        _scheduleAdminCountRefresh();
        break;
      case 'content_moderation.pending_review':
        break;
    }
  }

  void _handleOpenedPushData(Map<String, String> data) {
    if (!mounted) return;
    _handleForegroundPushData(data);
    // The type decides the destination: an invitation envelope also carries
    // the group_id of the group it invites to, and that group is one the user
    // is not a member of yet, so it has no screen to open.
    final type = data['type'] ?? '';
    if (type == 'invite.created' || type == 'invite.reviewed') {
      // An invitation has no screen of its own: it lives on the notifications
      // tab, where it can be accepted or declined.
      widget.onShowNotificationsTab?.call();
      return;
    }
    if ((data['group_id']?.trim() ?? '').isNotEmpty) {
      // Group targets open a group screen from this tab, so show it first.
      widget.onShowGroupsTab?.call();
    }
    _pendingOpenedPushData = Map<String, String>.from(data);
    unawaited(_openPendingNotificationTarget());
  }

  Future<void> _openPendingNotificationTarget() async {
    if (!mounted || _openingNotificationTarget) return;
    final data = _pendingOpenedPushData;
    if (data == null) return;
    final groupId = data['group_id']?.trim() ?? '';
    if (groupId.isEmpty) {
      _clearPendingNotificationIfCurrent(data);
      return;
    }

    _openingNotificationTarget = true;
    try {
      if (currentGroups.isEmpty) {
        try {
          await groupsFuture;
        } catch (_) {}
      }
      if (!mounted) return;

      ChatGroup? target;
      for (final group in currentGroups) {
        if (group.id == groupId) {
          target = group;
          break;
        }
      }
      if (target == null) {
        try {
          await refresh(silent: true);
        } catch (_) {}
        if (!mounted) return;
        for (final group in currentGroups) {
          if (group.id == groupId) {
            target = group;
            break;
          }
        }
      }
      if (target == null) {
        _clearPendingNotificationIfCurrent(data);
        return;
      }

      final requestId = data['type'] == 'public_request.created'
          ? data['request_id']?.trim()
          : null;
      _clearPendingNotificationIfCurrent(data);
      await openGroup(target, initialRequestId: requestId);
    } finally {
      _openingNotificationTarget = false;
      if (mounted && _pendingOpenedPushData != null) {
        unawaited(_openPendingNotificationTarget());
      }
    }
  }

  void _clearPendingNotificationIfCurrent(Map<String, String> data) {
    if (identical(_pendingOpenedPushData, data)) {
      _pendingOpenedPushData = null;
    }
  }

  void incrementUnreadPublicRequests(String groupId, String requestId) {
    if (groupId.isEmpty) return;
    if (requestId.isNotEmpty && !seenPublicRequestEvents.add(requestId)) return;
    final updated = currentGroups
        .map(
          (group) => group.id == groupId
              ? group.copyWith(
                  unreadPublicRequestCount: group.unreadPublicRequestCount + 1,
                )
              : group,
        )
        .toList();
    setGroups(updated);
  }

  void setUnreadPublicRequests(String groupId, int count) {
    if (groupId.isEmpty) return;
    final updated = currentGroups
        .map(
          (group) => group.id == groupId
              ? group.copyWith(unreadPublicRequestCount: count)
              : group,
        )
        .toList();
    setGroups(updated);
  }

  void setGroups(List<ChatGroup> groups) {
    if (!mounted) return;
    currentGroups = groups;
    widget.notifications.setGroups(groups);
    setState(() {
      groupsFuture = Future.value(groups);
    });
  }

  void _scheduleInvitationsCountRefresh() {
    _invitationsCountDebounce?.cancel();
    _invitationsCountDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(widget.notifications.load(silent: true));
    });
  }

  void _scheduleAdminCountRefresh() {
    if (!canReviewGroupCreationRequests) return;
    _adminCountDebounce?.cancel();
    _adminCountDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(_refreshAdminCount());
    });
  }

  Future<void> _refreshAdminCount() async {
    final count = await loadAdminRequestsCount();
    if (!mounted) return;
    setState(() {
      adminRequestsCountFuture = Future.value(count);
    });
  }

  /// Title of an already known group, e.g. to name the group of a scanned
  /// invite when the user is already a member.
  String? knownGroupTitle(String? groupId) {
    if (groupId == null || groupId.isEmpty) return null;
    for (final group in currentGroups) {
      if (group.id == groupId) return group.title;
    }
    return null;
  }

  void upsertGroup(ChatGroup group) {
    final updated = [
      group,
      ...currentGroups.where((item) => item.id != group.id),
    ];
    setGroups(updated);
  }

  void removeGroup(String groupId) {
    setGroups(currentGroups.where((group) => group.id != groupId).toList());
  }

  Future<List<ChatGroup>> loadGroups() async {
    final groups = await widget.api.fetchGroups();
    currentGroups = groups;
    widget.notifications.setGroups(groups);
    return groups;
  }

  /// Groups whose title matches the search box, in the server's order.
  List<ChatGroup> visibleGroups(List<ChatGroup> groups) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return groups;
    return groups
        .where((group) => group.title.toLowerCase().contains(query))
        .toList(growable: false);
  }

  Future<int> loadAdminRequestsCount() async {
    if (!canReviewGroupCreationRequests) return 0;
    try {
      return (await widget.api.fetchAdminGroupCreationRequests(
        status: 'pending',
      )).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> refresh({bool silent = false}) async {
    final nextGroups = loadGroups();
    final nextAdminCount = loadAdminRequestsCount();
    final nextInvitations = widget.notifications.load(silent: true);
    if (silent) {
      final groups = await nextGroups;
      final adminCount = await nextAdminCount;
      await nextInvitations;
      if (mounted) {
        setState(() {
          groupsFuture = Future.value(groups);
          adminRequestsCountFuture = Future.value(adminCount);
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        groupsFuture = nextGroups;
        adminRequestsCountFuture = nextAdminCount;
      });
    }
    await Future.wait([nextGroups, nextAdminCount, nextInvitations]);
  }

  Future<void> createGroup() async {
    if (!canManageAllGroups) {
      await openGroupRequests();
      return;
    }
    final group = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => CreateGroupSheet(api: widget.api),
    );
    if (group != null) {
      upsertGroup(group);
      if (mounted) await openGroup(group);
    }
  }

  Future<void> openGroupRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupCreationRequestsScreen(
          api: widget.api,
          user: widget.session.user,
        ),
      ),
    );
  }

  Future<void> openAdminRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminGroupCreationRequestsScreen(api: widget.api),
      ),
    );
  }

  Future<void> joinByCode() async {
    final group = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => JoinByCodeSheet(api: widget.api),
    );
    if (group != null) {
      upsertGroup(group);
      if (mounted) await openGroup(group);
    }
  }

  Future<void> discoverPublicGroups() async {
    final group = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => PublicGroupsSheet(
        api: widget.api,
        joinedGroups: currentGroups,
      ),
    );
    if (group != null) {
      upsertGroup(group);
      if (mounted) await openGroup(group);
    }
  }

  Future<void> scanGroupQr() async {
    final inviteCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const GroupQrScanScreen()),
    );
    if (inviteCode == null || inviteCode.trim().isEmpty || !mounted) return;
    final isSignedInvite = inviteCode.startsWith('INV1.');
    final code = isSignedInvite ? inviteCode : formatGroupInviteCode(inviteCode);
    final claims = isSignedInvite ? decodeSignedInviteClaims(inviteCode) : null;
    final displayCode = isSignedInvite
        ? (claims?.inviteCode == null
            ? null
            : formatGroupInviteCode(claims!.inviteCode!))
        : code;
    final confirmed = await confirmJoinScannedInvite(
      context,
      displayCode: displayCode,
      groupName: claims?.groupTitle ?? knownGroupTitle(claims?.groupId),
    );
    if (!confirmed || !mounted) return;
    try {
      final group = await widget.api.joinByInviteCode(code);
      upsertGroup(group);
      if (mounted) await openGroup(group);
    } catch (error) {
      if (mounted) {
        showAppSnack(context, localizedMessage(context, error.toString()));
      }
    }
  }

  Future<void> openGroup(ChatGroup group, {String? initialRequestId}) async {
    if (group.unreadPublicRequestCount > 0) {
      try {
        await widget.api.markPublicRequestsRead(group.id);
        setUnreadPublicRequests(group.id, 0);
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicRequestsScreen(
          api: widget.api,
          user: widget.session.user,
          group: group,
          initialRequestId: initialRequestId,
        ),
      ),
    );
    if (mounted) {
      await refresh(silent: true);
    }
  }

  Future<void> leaveGroup(ChatGroup group) async {
    final text = AppLanguageScope.textOf(context);
    if (group.myRole == 'owner') {
      showAppSnack(
        context,
        text.isKy
            ? 'Ээси топтон чыга албайт.'
            : 'Владелец группы не может выйти из группы.',
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.isKy ? 'Топтон чыгуу' : 'Выйти из группы'),
        content: Text(
          text.isKy
              ? 'Бул топтон чыгууну каалайсызбы?'
              : 'Вы действительно хотите выйти из этой группы?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text.isKy ? 'Жок' : 'Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(text.isKy ? 'Чыгуу' : 'Выйти'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PublicRequestsApi(
        baseUrl: widget.api.baseUrl,
        sessionStore: widget.api.sessionStore,
      ).leaveGroup(group.id);
      removeGroup(group.id);
      if (mounted) {
        showAppSnack(
          context,
          text.isKy ? 'Сиз топтон чыктыңыз.' : 'Вы вышли из группы.',
        );
      }
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString());
    }
  }

  Future<void> deleteGroup(ChatGroup group) async {
    final text = AppLanguageScope.textOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.isKy ? 'Топту өчүрүү' : 'Удалить группу'),
        content: Text(
          text.isKy
              ? '«${group.title}» тобун толугу менен өчүрөсүзбү? Бардык билдирүүлөр жана өтүнүчтөр да өчүрүлөт.'
              : 'Удалить группу «${group.title}» полностью? Все сообщения и заявки этой группы также будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text.isKy ? 'Жок' : 'Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(text.isKy ? 'Өчүрүү' : 'Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.deleteGroupAsPlatformAdmin(group.id);
      removeGroup(group.id);
      if (mounted) {
        showAppSnack(context, text.isKy ? 'Топ өчүрүлдү.' : 'Группа удалена.');
      }
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString());
    }
  }

  Future<void> showMainMenu() async {
    final adminRequestsCount = await adminRequestsCountFuture;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => MainGroupsMenuSheet(
        canReviewGroupCreationRequests: canReviewGroupCreationRequests,
        adminRequestsCount: adminRequestsCount,
        onJoinByCode: joinByCode,
        onScanQr: scanGroupQr,
        onMyRequests: openGroupRequests,
        onAdminRequests: openAdminRequests,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const KoomBrandTitle(compact: true),
        actions: [
          const AppSettingsButton(),
          const SizedBox(width: KoomSpacing.xs),
          IconButton(
            onPressed: showMainMenu,
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: 'Меню',
          ),
          const SizedBox(width: KoomSpacing.md),
        ],
      ),
      floatingActionButton: KoomAdaptiveFab(
        key: const ValueKey('groups_create_action'),
        onPressed: createGroup,
        icon: canManageAllGroups
            ? Icons.add_rounded
            : Icons.verified_user_outlined,
        label: canManageAllGroups ? text.newGroup : text.requestGroup,
      ),
      body: KoomPageBackground(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: FutureBuilder<List<ChatGroup>>(
            future: groupsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _GroupsLoadingSkeleton();
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(KoomSpacing.lg),
                  children: [
                    _overview(currentGroups.length),
                    const SizedBox(height: KoomSpacing.lg),
                    ErrorBanner(
                      message: localizedMessage(
                        context,
                        snapshot.error.toString(),
                      ),
                    ),
                  ],
                );
              }
              final groups = snapshot.data ?? const <ChatGroup>[];
              final visible = visibleGroups(groups);
              final searching = _searchQuery.trim().isNotEmpty;
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  KoomSpacing.lg,
                  KoomSpacing.sm,
                  KoomSpacing.lg,
                  108,
                ),
                itemCount: 2 + (visible.isEmpty ? 1 : visible.length),
                itemBuilder: (context, index) {
                  if (index == 0) return _overview(groups.length);
                  if (index == 1) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        KoomSpacing.xs,
                        KoomSpacing.xl,
                        KoomSpacing.xs,
                        KoomSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (groups.isNotEmpty) ...[
                            KoomSearchField(
                              key: const ValueKey('groups_search_field'),
                              controller: _searchController,
                              hintText: text.searchGroupsHint,
                              clearTooltip: text.clearSearch,
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                            ),
                            const SizedBox(height: KoomSpacing.lg),
                          ],
                          KoomSectionTitle(
                            title: text.groups,
                            subtitle: _groupsSubtitle(
                              text,
                              total: groups.length,
                              visible: visible.length,
                              searching: searching,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (visible.isEmpty) {
                    if (searching) {
                      return KoomCard(
                        showShadow: false,
                        child: KoomEmptyState(
                          icon: Icons.search_off_rounded,
                          title: text.groupsSearchEmptyTitle,
                          message: text.groupsSearchEmptyMessage,
                        ),
                      );
                    }
                    return _EmptyGroups(
                      canReviewGroupCreationRequests: canManageAllGroups,
                      onCreate: createGroup,
                    );
                  }
                  final group = visible[index - 2];
                  return GroupTile(
                    group: group,
                    onTap: () => openGroup(group),
                    onLeave: () => leaveGroup(group),
                    canDelete: canManageAllGroups,
                    onDelete: () => deleteGroup(group),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _overview(int groupCount) => _GroupsOverview(
        userName: widget.session.user.displayName,
        userAvatarBytes: widget.session.user.avatarBytes,
        groupCount: groupCount,
        canReviewGroupCreationRequests: canReviewGroupCreationRequests,
        adminRequestsCountFuture: adminRequestsCountFuture,
        onJoinByCode: joinByCode,
        onDiscoverPublicGroups: discoverPublicGroups,
        onScanQr: scanGroupQr,
        onRequests: canReviewGroupCreationRequests
            ? openAdminRequests
            : openGroupRequests,
      );

  String _groupsSubtitle(
    AppText text, {
    required int total,
    required int visible,
    required bool searching,
  }) {
    if (total == 0) {
      return text.isKy ? 'Сиз кошулган коомчулуктар ушул жерде көрүнөт' : 'Ваши сообщества появятся здесь';
    }
    if (searching) {
      return text.isKy ? '$visible / $total коомчулук' : '$visible из $total';
    }
    return text.isKy ? '$total коомчулук' : '$total сообществ';
  }
}

/// Placeholder blocks while the group list loads, instead of a bare spinner.
class _GroupsLoadingSkeleton extends StatelessWidget {
  const _GroupsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        KoomSpacing.lg,
        KoomSpacing.lg,
        KoomSpacing.lg,
        108,
      ),
      children: const [
        KoomSkeleton(height: 108, radius: KoomRadii.lg),
        SizedBox(height: KoomSpacing.md),
        KoomSkeleton(height: 84, radius: KoomRadii.lg),
        SizedBox(height: KoomSpacing.xl),
        KoomSkeleton(height: 48, radius: KoomRadii.pill),
        SizedBox(height: KoomSpacing.lg),
        KoomSkeletonList(itemCount: 4, itemHeight: 112, radius: KoomRadii.lg),
      ],
    );
  }
}

class _GroupsOverview extends StatelessWidget {
  const _GroupsOverview({
    required this.userName,
    required this.userAvatarBytes,
    required this.groupCount,
    required this.canReviewGroupCreationRequests,
    required this.adminRequestsCountFuture,
    required this.onJoinByCode,
    required this.onDiscoverPublicGroups,
    required this.onScanQr,
    required this.onRequests,
  });

  final String userName;
  final Uint8List? userAvatarBytes;
  final int groupCount;
  final bool canReviewGroupCreationRequests;
  final Future<int> adminRequestsCountFuture;
  final VoidCallback onJoinByCode;
  final VoidCallback onDiscoverPublicGroups;
  final VoidCallback onScanQr;
  final VoidCallback onRequests;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final safeName = userName.trim().isEmpty
        ? (text.isKy ? 'Колдонуучу' : 'Пользователь')
        : userName.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KoomCard(
          gradient: KoomTheme.brandGradient,
          borderColor: Colors.white.withValues(alpha: 0.14),
          padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
          child: Row(
            children: [
              KoomAvatar(
                label: safeName,
                radius: 28,
                background: Colors.white.withValues(alpha: 0.18),
                imageBytes: userAvatarBytes,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.isKy ? 'Кош келиңиз' : 'Добро пожаловать',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      safeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      text.isKy
                          ? '$groupCount коомчулукка кошулдуңуз'
                          : 'Вы состоите в $groupCount сообществах',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.groups_2_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        KoomCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          showShadow: false,
          child: KoomAdaptiveTileGrid(
            minItemWidth: 112,
            maxColumns: 4,
            spacing: 6,
            runSpacing: 6,
            children: [
              KoomIconTile(
                compact: true,
                icon: Icons.public_rounded,
                label: text.isKy ? 'Ачык топтор' : 'Открытые группы',
                onTap: onDiscoverPublicGroups,
              ),
              KoomIconTile(
                compact: true,
                icon: Icons.key_rounded,
                label: text.joinByCode,
                onTap: onJoinByCode,
              ),
              KoomIconTile(
                compact: true,
                icon: Icons.qr_code_scanner_rounded,
                label: text.scanQr,
                onTap: onScanQr,
              ),
              FutureBuilder<int>(
                future: adminRequestsCountFuture,
                builder: (context, snapshot) => KoomIconTile(
                  compact: true,
                  icon: canReviewGroupCreationRequests
                      ? Icons.fact_check_outlined
                      : Icons.verified_user_outlined,
                  label: canReviewGroupCreationRequests
                      ? text.adminRequests
                      : text.myRequests,
                  badge: canReviewGroupCreationRequests
                      ? snapshot.data ?? 0
                      : null,
                  onTap: onRequests,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Divider(color: colors.border.withValues(alpha: 0)),
      ],
    );
  }
}

/// Overflow sheet of the groups tab. Profile, sign-out and invitations moved
/// to the bottom navigation, so only the rarely used group actions are left.
class MainGroupsMenuSheet extends StatelessWidget {
  const MainGroupsMenuSheet({
    super.key,
    required this.canReviewGroupCreationRequests,
    required this.adminRequestsCount,
    required this.onJoinByCode,
    required this.onScanQr,
    required this.onMyRequests,
    required this.onAdminRequests,
  });

  final bool canReviewGroupCreationRequests;
  final int adminRequestsCount;
  final VoidCallback onJoinByCode;
  final VoidCallback onScanQr;
  final VoidCallback onMyRequests;
  final VoidCallback onAdminRequests;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return KoomSheetFrame(
      title: text.isKy ? 'Koom менюсу' : 'Меню Koom',
      child: Column(
        children: [
          if (canReviewGroupCreationRequests)
            _MenuItem(
              icon: Icons.admin_panel_settings_outlined,
              title: text.adminRequests,
              count: adminRequestsCount,
              onTap: onAdminRequests,
            ),
          _MenuItem(
            icon: Icons.verified_user_outlined,
            title: text.groupRequests,
            onTap: onMyRequests,
          ),
          _MenuItem(
            icon: Icons.qr_code_rounded,
            title: text.joinByCode,
            onTap: onJoinByCode,
          ),
          _MenuItem(
            icon: Icons.qr_code_scanner_rounded,
            title: text.scanQr,
            onTap: onScanQr,
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = colors.textStrong;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: foreground, size: 21),
          ),
          title: Text(title, style: TextStyle(color: foreground)),
          trailing: count != null && count! > 0
              ? Badge(label: Text('$count'))
              : Icon(Icons.chevron_right_rounded, color: colors.textMuted),
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
        ),
      ),
    );
  }
}

class _GroupVisibilityBadge extends StatelessWidget {
  const _GroupVisibilityBadge({required this.isPublic});

  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final color = context.appColors.textMuted;
    final shortLabel = isPublic
        ? (text.isKy ? 'Ачык' : 'Открытая')
        : (text.isKy ? 'Жабык' : 'Закрытая');
    return Tooltip(
      message: isPublic
          ? (text.isKy ? 'Ачык топ' : 'Открытая группа')
          : (text.isKy ? 'Жабык топ' : 'Закрытая группа'),
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
              size: 11,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              shortLabel,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupMetaPill extends StatelessWidget {
  const _GroupMetaPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({
    required this.canReviewGroupCreationRequests,
    required this.onCreate,
  });

  final bool canReviewGroupCreationRequests;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return KoomCard(
      showShadow: false,
      child: KoomEmptyState(
        icon: Icons.groups_2_outlined,
        title: text.noGroups,
        message: text.isKy
            ? 'Топко кошулуңуз же жаңы топ түзүү сурамын жөнөтүңүз.'
            : 'Присоединитесь к группе или отправьте заявку на создание новой.',
        action: FilledButton.icon(
          key: const ValueKey('groups_empty_create_action'),
          onPressed: onCreate,
          icon: Icon(
            canReviewGroupCreationRequests
                ? Icons.add_rounded
                : Icons.verified_user_outlined,
          ),
          label: Text(
            canReviewGroupCreationRequests ? text.newGroup : text.requestGroup,
          ),
        ),
      ),
    );
  }
}

class GroupTile extends StatelessWidget {
  const GroupTile({
    super.key,
    required this.group,
    required this.onTap,
    required this.onLeave,
    required this.canDelete,
    required this.onDelete,
  });

  final ChatGroup group;
  final VoidCallback onTap;
  final VoidCallback onLeave;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final inviteCode = group.inviteCode ?? '';
    final role = switch (group.myRole) {
      'owner' => text.isKy ? 'Ээси' : 'Владелец',
      'admin' => text.isKy ? 'Админ' : 'Администратор',
      'member' => text.isKy ? 'Катышуучу' : 'Участник',
      final String value => value,
      _ => '',
    };

    return KoomCard(
      key: ValueKey('group_tile_${group.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 15, 8, 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            KoomAvatar(
              label: group.title,
              radius: 25,
              icon: group.visibility == 'public'
                  ? Icons.groups_2_rounded
                  : Icons.lock_rounded,
              imageBytes: group.avatarBytes,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _GroupVisibilityBadge(isPublic: group.isPublic),
                      if (group.unreadPublicRequestCount > 0) ...[
                        const SizedBox(width: 6),
                        Badge(label: Text('${group.unreadPublicRequestCount}')),
                      ],
                    ],
                  ),
                  if (group.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      group.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (group.memberCount > 0)
                        _GroupMetaPill(
                          label: '${group.memberCount}',
                          icon: Icons.people_outline_rounded,
                        ),
                      if (role.isNotEmpty)
                        _GroupMetaPill(
                          label: role,
                          icon: Icons.verified_user_outlined,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: text.isKy ? 'Аракеттер' : 'Действия',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) async {
                if (value == 'copy') {
                  await Clipboard.setData(ClipboardData(text: inviteCode));
                  if (context.mounted) {
                    showAppSnack(context, text.inviteCodeCopied);
                  }
                }
                if (value == 'leave') onLeave();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                if (inviteCode.isNotEmpty)
                  PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        const Icon(Icons.copy_rounded, size: 19),
                        const SizedBox(width: 10),
                        Expanded(child: Text(text.copyInviteCode)),
                      ],
                    ),
                  ),
                if (canDelete)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_forever_outlined,
                          size: 19,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            text.isKy ? 'Топту өчүрүү' : 'Удалить группу',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 19,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text.isKy ? 'Топтон чыгуу' : 'Выйти из группы',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks the user to confirm joining a group from a scanned QR code.
/// [displayCode] is shown when the QR carried a plain invite code.
Future<bool> confirmJoinScannedInvite(
  BuildContext context, {
  String? displayCode,
  String? groupName,
}) async {
  final text = AppLanguageScope.textOf(context);
  final name = groupName?.trim() ?? '';
  final String body;
  if (name.isNotEmpty) {
    body = text.isKy
        ? '«$name» тобуна кошулууну ырастаңыз.${displayCode == null ? '' : ' Код: $displayCode.'}'
        : 'Подтвердите вступление в группу «$name».${displayCode == null ? '' : ' Код: $displayCode.'}';
  } else if (displayCode == null) {
    body = text.isKy
        ? 'QR код аркылуу топко кошулууну ырастаңыз. Кодду ишенимдүү булактан гана сканерлеңиз.'
        : 'Подтвердите вступление в группу по QR-коду. Сканируйте коды только из надёжных источников.';
  } else {
    body = text.isKy
        ? '$displayCode коду менен топко кошулууну ырастаңыз.'
        : 'Подтвердите вступление в группу по коду $displayCode.';
  }
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(text.isKy ? 'Топко кошуласызбы?' : 'Вступить в группу?'),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(text.isKy ? 'Жокко чыгаруу' : 'Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(text.isKy ? 'Кошулуу' : 'Вступить'),
        ),
      ],
    ),
  );
  return result ?? false;
}
