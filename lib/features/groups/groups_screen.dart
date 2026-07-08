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
import '../../shared/ui_helpers.dart';
import '../group_creation/admin_group_creation_requests_screen.dart';
import '../group_creation/group_creation_requests_screen.dart';
import '../invitations/invitations_screen.dart';
import '../profile/profile_screen.dart';
import '../public_requests/public_requests_screen.dart';
import 'group_qr_scan_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key, required this.api, required this.session, required this.onLogout});
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
    _foregroundPushSubscription = PushNotificationService.foregroundDataStream.listen(_handleForegroundPushData);
    _openedPushSubscription = PushNotificationService.openedDataStream.listen(_handleOpenedPushData);
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
        incrementUnreadPublicRequests(data['group_id'] ?? '', data['request_id'] ?? '');
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
            ? group.copyWith(unreadPublicRequestCount: group.unreadPublicRequestCount + 1)
            : group)
        .toList();
    setGroups(updated);
  }

  void setUnreadPublicRequests(String groupId, int count) {
    if (groupId.isEmpty) return;
    final updated = currentGroups
        .map((group) => group.id == groupId ? group.copyWith(unreadPublicRequestCount: count) : group)
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
    try { return (await widget.api.fetchAdminGroupCreationRequests(status: 'pending')).length; } catch (_) { return 0; }
  }

  Future<int> loadInvitationsCount() async {
    try { return (await widget.api.fetchInvitations()).length; } catch (_) { return 0; }
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
    if (!isAdmin) { await openGroupRequests(); return; }
    final group = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => CreateGroupSheet(api: widget.api),
    );
    if (group != null) { await refresh(); if (mounted) await openGroup(group); }
  }

  Future<void> openGroupRequests() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupCreationRequestsScreen(api: widget.api, user: widget.session.user)));
    await refresh();
  }

  Future<void> openAdminRequests() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminGroupCreationRequestsScreen(api: widget.api)));
    await refresh();
  }

  Future<void> openProfile() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(user: widget.session.user)));
  }

  Future<void> joinByCode() async {
    final group = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => JoinByCodeSheet(api: widget.api),
    );
    if (group != null) { await refresh(); if (mounted) await openGroup(group); }
  }

  Future<void> scanGroupQr() async {
    final inviteCode = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const GroupQrScanScreen()));
    if (inviteCode == null || inviteCode.trim().isEmpty) return;
    try {
      final group = await widget.api.joinByInviteCode(inviteCode.startsWith('I' + 'NV1.') ? inviteCode : formatGroupInviteCode(inviteCode));
      await refresh();
      if (mounted) await openGroup(group);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString());
    }
  }

  Future<void> openInvitations() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvitationsScreen(api: widget.api)));
    await refresh();
  }

  Future<void> openGroup(ChatGroup group) async {
    if (group.unreadPublicRequestCount > 0) {
      try {
        await widget.api.markPublicRequestsRead(group.id);
        setUnreadPublicRequests(group.id, 0);
      } catch (_) {}
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicRequestsScreen(api: widget.api, user: widget.session.user, group: group)));
    if (mounted) await refresh();
  }

  Future<void> leaveGroup(ChatGroup group) async {
    final text = AppLanguageScope.textOf(context);
    if (group.myRole == 'owner') {
      showAppSnack(context, text.isKy ? 'Ээси топтон чыга албайт.' : 'Владелец группы не может выйти из группы.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.isKy ? 'Топтон чыгуу' : 'Выйти из группы'),
        content: Text(text.isKy ? 'Бул топтон чыгууну каалайсызбы?' : 'Вы действительно хотите выйти из этой группы?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(text.isKy ? 'Жок' : 'Отмена')),
          FilledButton.tonal(onPressed: () => Navigator.pop(dialogContext, true), child: Text(text.isKy ? 'Чыгуу' : 'Выйти')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PublicRequestsApi(baseUrl: widget.api.baseUrl, sessionStore: widget.api.sessionStore).leaveGroup(group.id);
      await refresh();
      if (mounted) showAppSnack(context, text.isKy ? 'Сиз топтон чыктыңыз.' : 'Вы вышли из группы.');
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString());
    }
  }

  Future<void> showMainMenu() async {
    final counts = await Future.wait([adminRequestsCountFuture, invitationsCountFuture]);
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
        title: Text(text.groups),
        actions: [
          const AppSettingsButton(),
          IconButton(onPressed: showMainMenu, icon: const Icon(Icons.more_vert_rounded), tooltip: text.isKy ? 'Меню' : 'Меню'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createGroup,
        icon: Icon(isAdmin ? Icons.add_rounded : Icons.verified_user_outlined),
        label: Text(isAdmin ? text.newGroup : text.requestGroup),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<ChatGroup>>(
          future: groupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return ListView(padding: const EdgeInsets.all(24), children: [ErrorBanner(message: snapshot.error.toString())]);
            final groups = snapshot.data ?? const [];
            if (groups.isEmpty) return _EmptyGroups(isAdmin: isAdmin, onCreate: createGroup);
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: groups.length,
              itemBuilder: (_, index) => GroupTile(group: groups[index], onTap: () => openGroup(groups[index]), onLeave: () => leaveGroup(groups[index])),
            );
          },
        ),
      ),
    );
  }
}


String _groupRoleLabel(String role) {
  switch (role) {
    case 'owner':
      return 'owner';
    case 'admin':
      return 'admin';
    case 'member':
      return 'member';
    default:
      return role;
  }
}

class MainGroupsMenuSheet extends StatelessWidget {
  const MainGroupsMenuSheet({super.key, required this.isAdmin, required this.adminRequestsCount, required this.invitationsCount, required this.onProfile, required this.onJoinByCode, required this.onScanQr, required this.onInvitations, required this.onMyRequests, required this.onAdminRequests, required this.onLogout});
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (isAdmin) _MenuItem(icon: Icons.admin_panel_settings_outlined, title: text.adminRequests, count: adminRequestsCount, onTap: onAdminRequests),
        _MenuItem(icon: Icons.verified_user_outlined, title: text.groupRequests, onTap: onMyRequests),
        _MenuItem(icon: Icons.mark_email_unread_outlined, title: text.invitations, count: invitationsCount, onTap: onInvitations),
        _MenuItem(icon: Icons.qr_code_rounded, title: text.joinByCode, onTap: onJoinByCode),
        _MenuItem(icon: Icons.qr_code_scanner_rounded, title: text.scanQr, onTap: onScanQr),
        const Divider(),
        _MenuItem(icon: Icons.person_outline_rounded, title: text.profile, onTap: onProfile),
        _MenuItem(icon: Icons.logout_rounded, title: text.logout, onTap: onLogout),
      ]),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.title, required this.onTap, this.count});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: count != null && count! > 0 ? Badge(label: Text('$count')) : null,
      onTap: () { Navigator.pop(context); onTap(); },
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
    return ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 48),
      Icon(Icons.groups_2_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 18),
      Text(text.noGroups, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(text.isKy ? 'Топко кошулуңуз же жаңы топ түзүү сурамын жөнөтүңүз.' : 'Присоединитесь к группе или отправьте заявку на создание новой.', textAlign: TextAlign.center),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: onCreate, icon: Icon(isAdmin ? Icons.add_rounded : Icons.verified_user_outlined), label: Text(isAdmin ? text.newGroup : text.requestGroup)),
    ]);
  }
}

class GroupTile extends StatelessWidget {
  const GroupTile({super.key, required this.group, required this.onTap, required this.onLeave});
  final ChatGroup group;
  final VoidCallback onTap;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final inviteCode = group.inviteCode ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 24, backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), child: Icon(group.visibility == 'public' ? Icons.public_rounded : Icons.lock_outline_rounded, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                [
                  group.visibility == 'public' ? text.publicGroup : text.privateGroup,
                  if (group.memberCount > 0) '${group.memberCount}',
                  if (group.myRole != null) _groupRoleLabel(group.myRole!),
                ].join(' · '),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.textMuted, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(group.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (group.description.isNotEmpty) ...[const SizedBox(height: 4), Text(group.description, maxLines: 2, overflow: TextOverflow.ellipsis)],
            ])),
            if (group.unreadPublicRequestCount > 0) ...[
              Badge(
                label: Text('${group.unreadPublicRequestCount}'),
                child: const Icon(Icons.article_outlined),
              ),
              const SizedBox(width: 8),
            ],
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'copy') {
                  await Clipboard.setData(ClipboardData(text: inviteCode));
                  if (context.mounted) showAppSnack(context, text.inviteCodeCopied);
                }
                if (value == 'leave') onLeave();
              },
              itemBuilder: (_) => [
                if (inviteCode.isNotEmpty) PopupMenuItem(value: 'copy', child: Text(text.copyInviteCode)),
                PopupMenuItem(value: 'leave', child: Text(text.isKy ? 'Топтон чыгуу' : 'Выйти из группы')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
