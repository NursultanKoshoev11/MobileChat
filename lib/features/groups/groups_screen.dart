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
import '../invitations/invitations_screen.dart';
import '../profile/profile_screen.dart';
import '../public_requests/public_requests_screen.dart';
import 'group_qr_scan_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen(
      {super.key,
      required this.api,
      required this.session,
      required this.onLogout});
  final ApiClient api;
  final AppSession session;
  final Future<void> Function() onLogout;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late Future<List<ChatGroup>> groupsFuture;
  late Future<int> adminRequestsCountFuture;
  late Future<int> invitationsCountFuture;
  late final UserRealtimeService userRealtime;
  List<ChatGroup> currentGroups = const <ChatGroup>[];
  final Set<String> seenPublicRequestEvents = <String>{};
  StreamSubscription<Map<String, String>>? _foregroundPushSubscription;
  StreamSubscription<Map<String, String>>? _openedPushSubscription;
  Timer? _realtimeRefreshDebounce;
  bool get isAdmin => widget.session.user.isPlatformAdmin;

  @override
  void initState() {
    super.initState();
    groupsFuture = loadGroups();
    adminRequestsCountFuture = loadAdminRequestsCount();
    invitationsCountFuture = loadInvitationsCount();
    userRealtime = UserRealtimeService(api: widget.api);
    userRealtime.connect(onEvent: _handleUserRealtimeEvent);
    _foregroundPushSubscription = PushNotificationService.foregroundDataStream
        .listen(_handleForegroundPushData);
    _openedPushSubscription =
        PushNotificationService.openedDataStream.listen(_handleOpenedPushData);
  }

  @override
  void dispose() {
    _foregroundPushSubscription?.cancel();
    _openedPushSubscription?.cancel();
    _realtimeRefreshDebounce?.cancel();
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
      case 'invite.created':
      case 'invite.reviewed':
      case 'group_creation_request.created':
      case 'group_creation_request.reviewed':
        _scheduleRealtimeRefresh();
        break;
    }
  }

  void _handleForegroundPushData(Map<String, String> data) {
    if (!mounted) return;
    switch (data['type']) {
      case 'public_request.created':
        incrementUnreadPublicRequests(
            data['group_id'] ?? '', data['request_id'] ?? '');
        break;
      case 'invite.created':
      case 'invite.reviewed':
      case 'group_creation_request.created':
      case 'group_creation_request.reviewed':
      case 'content_moderation.pending_review':
        _scheduleRealtimeRefresh();
        break;
    }
  }

  void _handleOpenedPushData(Map<String, String> data) {
    _handleForegroundPushData(data);
    final groupId = data['group_id'] ?? '';
    if (groupId.isEmpty) return;
    ChatGroup? target;
    for (final group in currentGroups) {
      if (group.id == groupId) {
        target = group;
        break;
      }
    }
    if (target == null) {
      _scheduleRealtimeRefresh();
      return;
    }
    unawaited(openGroup(target));
  }

  void incrementUnreadPublicRequests(String groupId, String requestId) {
    if (groupId.isEmpty) return;
    if (requestId.isNotEmpty && !seenPublicRequestEvents.add(requestId)) return;
    final updated = currentGroups
        .map((group) => group.id == groupId
            ? group.copyWith(
                unreadPublicRequestCount: group.unreadPublicRequestCount + 1)
            : group)
        .toList();
    setGroups(updated);
  }

  void setUnreadPublicRequests(String groupId, int count) {
    if (groupId.isEmpty) return;
    final updated = currentGroups
        .map((group) => group.id == groupId
            ? group.copyWith(unreadPublicRequestCount: count)
            : group)
        .toList();
    setGroups(updated);
  }

  void setGroups(List<ChatGroup> groups) {
    if (!mounted) return;
    currentGroups = groups;
    setState(() => groupsFuture = Future.value(groups));
  }

  void _scheduleRealtimeRefresh() {
    _realtimeRefreshDebounce?.cancel();
    _realtimeRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(refresh(silent: true).catchError((_) {}));
    });
  }

  Future<List<ChatGroup>> loadGroups() async {
    final groups = await widget.api.fetchGroups();
    currentGroups = groups;
    return groups;
  }

  Future<int> loadAdminRequestsCount() async {
    if (!isAdmin) return 0;
    try {
      return (await widget.api
              .fetchAdminGroupCreationRequests(status: 'pending'))
          .length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> loadInvitationsCount() async {
    try {
      return (await widget.api.fetchInvitations()).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> refresh({bool silent = false}) async {
    final nextGroups = loadGroups();
    final nextAdminCount = loadAdminRequestsCount();
    final nextInvitationsCount = loadInvitationsCount();
    if (silent) {
      final groups = await nextGroups;
      final adminCount = await nextAdminCount;
      final invitationsCount = await nextInvitationsCount;
      if (mounted) {
        setState(() {
          groupsFuture = Future.value(groups);
          adminRequestsCountFuture = Future.value(adminCount);
          invitationsCountFuture = Future.value(invitationsCount);
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        groupsFuture = nextGroups;
        adminRequestsCountFuture = nextAdminCount;
        invitationsCountFuture = nextInvitationsCount;
      });
    }
    await Future.wait([nextGroups, nextAdminCount, nextInvitationsCount]);
  }

  Future<void> createGroup() async {
    if (!isAdmin) {
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
      await refresh();
      if (mounted) await openGroup(group);
    }
  }

  Future<void> openGroupRequests() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GroupCreationRequestsScreen(
            api: widget.api, user: widget.session.user)));
    await refresh();
  }

  Future<void> openAdminRequests() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AdminGroupCreationRequestsScreen(api: widget.api)));
    await refresh();
  }

  Future<void> openProfile() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProfileScreen(user: widget.session.user)));
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
      await refresh();
      if (mounted) await openGroup(group);
    }
  }

  Future<void> scanGroupQr() async {
    final inviteCode = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const GroupQrScanScreen()));
    if (inviteCode == null || inviteCode.trim().isEmpty) return;
    try {
      final group = await widget.api.joinByInviteCode(
          inviteCode.startsWith('I' + 'NV1.')
              ? inviteCode
              : formatGroupInviteCode(inviteCode));
      await refresh();
      if (mounted) await openGroup(group);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString());
    }
  }

  Future<void> openInvitations() async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InvitationsScreen(api: widget.api)));
    await refresh();
  }

  Future<void> openGroup(ChatGroup group) async {
    if (group.unreadPublicRequestCount > 0) {
      try {
        await widget.api.markPublicRequestsRead(group.id);
        setUnreadPublicRequests(group.id, 0);
      } catch (_) {}
    }
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PublicRequestsScreen(
            api: widget.api, user: widget.session.user, group: group)));
    if (mounted) await refresh();
  }

  Future<void> leaveGroup(ChatGroup group) async {
    final text = AppLanguageScope.textOf(context);
    if (group.myRole == 'owner') {
      showAppSnack(
          context,
          text.isKy
              ? 'Ээси топтон чыга албайт.'
              : 'Владелец группы не может выйти из группы.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.isKy ? 'Топтон чыгуу' : 'Выйти из группы'),
        content: Text(text.isKy
            ? 'Бул топтон чыгууну каалайсызбы?'
            : 'Вы действительно хотите выйти из этой группы?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(text.isKy ? 'Жок' : 'Отмена')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(text.isKy ? 'Чыгуу' : 'Выйти')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PublicRequestsApi(
              baseUrl: widget.api.baseUrl,
              sessionStore: widget.api.sessionStore)
          .leaveGroup(group.id);
      await refresh();
      if (mounted)
        showAppSnack(context,
            text.isKy ? 'Сиз топтон чыктыңыз.' : 'Вы вышли из группы.');
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString());
    }
  }

  Future<void> showMainMenu() async {
    final counts =
        await Future.wait([adminRequestsCountFuture, invitationsCountFuture]);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => MainGroupsMenuSheet(
        isAdmin: isAdmin,
        adminRequestsCount: counts[0],
        invitationsCount: counts[1],
        onProfile: openProfile,
        onJoinByCode: joinByCode,
        onScanQr: scanGroupQr,
        onInvitations: openInvitations,
        onMyRequests: openGroupRequests,
        onAdminRequests: openAdminRequests,
        onLogout: widget.onLogout,
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const KoomBrandTitle(compact: true),
        actions: [
          const AppSettingsButton(),
          const SizedBox(width: 4),
          IconButton(
            onPressed: showMainMenu,
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: text.isKy ? 'Меню' : 'Меню',
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('groups_create_action'),
        onPressed: createGroup,
        icon: Icon(isAdmin ? Icons.add_rounded : Icons.verified_user_outlined),
        label: Text(isAdmin ? text.newGroup : text.requestGroup),
      ),
      body: KoomPageBackground(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: FutureBuilder<List<ChatGroup>>(
            future: groupsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 180),
                    Center(child: CircularProgressIndicator()),
                  ],
                );
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    _GroupsOverview(
                      userName: widget.session.user.displayName,
                      groupCount: currentGroups.length,
                      isAdmin: isAdmin,
                      adminRequestsCountFuture: adminRequestsCountFuture,
                      invitationsCountFuture: invitationsCountFuture,
                      onJoinByCode: joinByCode,
                      onScanQr: scanGroupQr,
                      onInvitations: openInvitations,
                      onRequests:
                          isAdmin ? openAdminRequests : openGroupRequests,
                    ),
                    const SizedBox(height: 16),
                    ErrorBanner(message: snapshot.error.toString()),
                  ],
                );
              }
              final groups = snapshot.data ?? const <ChatGroup>[];
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
                itemCount: groups.length + (groups.isEmpty ? 3 : 2),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _GroupsOverview(
                      userName: widget.session.user.displayName,
                      groupCount: groups.length,
                      isAdmin: isAdmin,
                      adminRequestsCountFuture: adminRequestsCountFuture,
                      invitationsCountFuture: invitationsCountFuture,
                      onJoinByCode: joinByCode,
                      onScanQr: scanGroupQr,
                      onInvitations: openInvitations,
                      onRequests:
                          isAdmin ? openAdminRequests : openGroupRequests,
                    );
                  }
                  if (index == 1) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(2, 22, 2, 12),
                      child: KoomSectionTitle(
                        title: text.groups,
                        subtitle: groups.isEmpty
                            ? (text.isKy
                                ? 'Сиз кошулган коомчулуктар ушул жерде көрүнөт'
                                : 'Ваши сообщества появятся здесь')
                            : (text.isKy
                                ? '${groups.length} коомчулук'
                                : '${groups.length} сообществ'),
                      ),
                    );
                  }
                  if (groups.isEmpty) {
                    return _EmptyGroups(
                        isAdmin: isAdmin, onCreate: createGroup);
                  }
                  final group = groups[index - 2];
                  return GroupTile(
                    group: group,
                    onTap: () => openGroup(group),
                    onLeave: () => leaveGroup(group),
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

class _GroupsOverview extends StatelessWidget {
  const _GroupsOverview({
    required this.userName,
    required this.groupCount,
    required this.isAdmin,
    required this.adminRequestsCountFuture,
    required this.invitationsCountFuture,
    required this.onJoinByCode,
    required this.onScanQr,
    required this.onInvitations,
    required this.onRequests,
  });

  final String userName;
  final int groupCount;
  final bool isAdmin;
  final Future<int> adminRequestsCountFuture;
  final Future<int> invitationsCountFuture;
  final VoidCallback onJoinByCode;
  final VoidCallback onScanQr;
  final VoidCallback onInvitations;
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
          gradient: MobileChatTheme.brandGradient,
          borderColor: Colors.white.withValues(alpha: 0.14),
          padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
          child: Row(
            children: [
              KoomAvatar(
                label: safeName,
                radius: 28,
                background: Colors.white.withValues(alpha: 0.18),
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
          child: Row(
            children: [
              Expanded(
                child: KoomIconTile(
                  compact: true,
                  icon: Icons.key_rounded,
                  label: text.joinByCode,
                  onTap: onJoinByCode,
                ),
              ),
              Expanded(
                child: KoomIconTile(
                  compact: true,
                  icon: Icons.qr_code_scanner_rounded,
                  label: text.scanQr,
                  onTap: onScanQr,
                ),
              ),
              Expanded(
                child: FutureBuilder<int>(
                  future: invitationsCountFuture,
                  builder: (context, snapshot) => KoomIconTile(
                    compact: true,
                    icon: Icons.mark_email_unread_outlined,
                    label: text.invitations,
                    badge: snapshot.data ?? 0,
                    onTap: onInvitations,
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<int>(
                  future: adminRequestsCountFuture,
                  builder: (context, snapshot) => KoomIconTile(
                    compact: true,
                    icon: isAdmin
                        ? Icons.fact_check_outlined
                        : Icons.verified_user_outlined,
                    label: isAdmin ? text.adminRequests : text.myRequests,
                    badge: isAdmin ? snapshot.data ?? 0 : null,
                    onTap: onRequests,
                  ),
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

class MainGroupsMenuSheet extends StatelessWidget {
  const MainGroupsMenuSheet({
    super.key,
    required this.isAdmin,
    required this.adminRequestsCount,
    required this.invitationsCount,
    required this.onProfile,
    required this.onJoinByCode,
    required this.onScanQr,
    required this.onInvitations,
    required this.onMyRequests,
    required this.onAdminRequests,
    required this.onLogout,
  });

  final bool isAdmin;
  final int adminRequestsCount;
  final int invitationsCount;
  final VoidCallback onProfile;
  final VoidCallback onJoinByCode;
  final VoidCallback onScanQr;
  final VoidCallback onInvitations;
  final VoidCallback onMyRequests;
  final VoidCallback onAdminRequests;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return KoomSheetFrame(
      title: text.isKy ? 'Koom менюсу' : 'Меню Koom',
      child: Column(
        children: [
          if (isAdmin)
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
            icon: Icons.mark_email_unread_outlined,
            title: text.invitations,
            count: invitationsCount,
            onTap: onInvitations,
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          _MenuItem(
            icon: Icons.person_outline_rounded,
            title: text.profile,
            onTap: onProfile,
          ),
          _MenuItem(
            icon: Icons.logout_rounded,
            title: text.logout,
            destructive: true,
            onTap: onLogout,
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
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int? count;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground =
        destructive ? Theme.of(context).colorScheme.error : colors.textStrong;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: destructive
            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.07)
            : colors.surfaceSoft,
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

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.isAdmin, required this.onCreate});

  final bool isAdmin;
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
          icon:
              Icon(isAdmin ? Icons.add_rounded : Icons.verified_user_outlined),
          label: Text(isAdmin ? text.newGroup : text.requestGroup),
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
  });

  final ChatGroup group;
  final VoidCallback onTap;
  final VoidCallback onLeave;

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
                      if (group.unreadPublicRequestCount > 0)
                        Badge(
                          label: Text('${group.unreadPublicRequestCount}'),
                        ),
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
                      KoomStatusPill(
                        label: group.visibility == 'public'
                            ? text.publicGroup
                            : text.privateGroup,
                        icon: group.visibility == 'public'
                            ? Icons.public_rounded
                            : Icons.lock_outline_rounded,
                      ),
                      if (group.memberCount > 0)
                        KoomStatusPill(
                          label: '${group.memberCount}',
                          icon: Icons.people_outline_rounded,
                          color: colors.textMuted,
                        ),
                      if (role.isNotEmpty)
                        KoomStatusPill(
                          label: role,
                          icon: Icons.verified_user_outlined,
                          color: colors.textMuted,
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
                      Text(
                        text.isKy ? 'Топтон чыгуу' : 'Выйти из группы',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
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
