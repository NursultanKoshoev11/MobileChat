import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../features/groups/groups_screen.dart';
import '../features/notifications/notifications_controller.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/profile_screen.dart';
import '../services/user_realtime_service.dart';
import 'localization.dart';


/// Destinations of the root bottom navigation bar, in display order.
enum KoomHomeTab { groups, notifications, profile }

/// Signed-in home: a Material 3 [NavigationBar] over three destinations that
/// each keep their own state (scroll position and loaded data) while hidden.
///
/// Replaces `GroupsScreen` as the post-login home. Screens that are not
/// destinations are still pushed on the root navigator, so deep links and
/// "sign out everywhere" keep working exactly as before.
class KoomHomeShell extends StatefulWidget {
  const KoomHomeShell({
    super.key,
    required this.api,
    required this.session,
    required this.onSessionChanged,
    required this.onLogout,
    required this.onAccountDeleted,
    this.onLogoutAllDevices,
    this.initialTab = KoomHomeTab.groups,
    @visibleForTesting this.userRealtime,
    @visibleForTesting this.initialPushData,
  });

  final ApiClient api;
  final AppSession session;
  final Future<void> Function(AppSession session) onSessionChanged;
  final Future<void> Function() onLogout;
  final Future<void> Function() onAccountDeleted;
  final Future<void> Function()? onLogoutAllDevices;
  final KoomHomeTab initialTab;

  /// Test seam: replaces the realtime connection of the groups tab.
  final UserRealtimeService? userRealtime;

  /// Test seam: stands in for a notification the app was opened from.
  final Map<String, String>? initialPushData;

  @override
  State<KoomHomeShell> createState() => KoomHomeShellState();
}

class KoomHomeShellState extends State<KoomHomeShell> {
  final GlobalKey<GroupsScreenState> _groupsKey =
      GlobalKey<GroupsScreenState>();
  late final KoomNotificationsController notifications =
      KoomNotificationsController(api: widget.api);
  late KoomHomeTab _tab = widget.initialTab;

  /// Currently visible destination.
  KoomHomeTab get tab => _tab;

  @override
  void initState() {
    super.initState();
    unawaited(notifications.load());
  }

  @override
  void dispose() {
    notifications.dispose();
    super.dispose();
  }

  /// Shows [tab]. The other destinations stay alive, so returning to one
  /// restores its scroll position and its already loaded data.
  void selectTab(KoomHomeTab tab) {
    if (!mounted || _tab == tab) return;
    setState(() => _tab = tab);
  }

  Future<void> _openGroupFromNotification(ChatGroup group) async {
    // Reuses the groups tab, which marks the group read and refreshes on return.
    await _groupsKey.currentState?.openGroup(group);
  }

  /// [IndexedStack] keeps a hidden destination laid out and in the semantics
  /// tree, which would let screen readers and UI test runners reach controls
  /// nobody can see. Hide the semantics and pause the animations of every
  /// destination except the visible one; its state is still kept alive.
  Widget _hiddenTabGuard(KoomHomeTab tab, Widget child) {
    final visible = tab == _tab;
    return ExcludeSemantics(
      excluding: !visible,
      child: TickerMode(enabled: visible, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return PopScope(
      // Back on a secondary destination returns to the groups tab instead of
      // closing the app.
      canPop: _tab == KoomHomeTab.groups,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) selectTab(KoomHomeTab.groups);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab.index,
          children: [
            _hiddenTabGuard(KoomHomeTab.groups, GroupsScreen(
              key: _groupsKey,
              api: widget.api,
              session: widget.session,
              onSessionChanged: widget.onSessionChanged,
              onLogout: widget.onLogout,
              onAccountDeleted: widget.onAccountDeleted,
              onLogoutAllDevices: widget.onLogoutAllDevices,
              notifications: notifications,
              onShowGroupsTab: () => selectTab(KoomHomeTab.groups),
              onShowNotificationsTab: () =>
                  selectTab(KoomHomeTab.notifications),
              userRealtime: widget.userRealtime,
              initialPushData: widget.initialPushData,
            )),
            _hiddenTabGuard(
                KoomHomeTab.notifications,
                NotificationsScreen(
                  api: widget.api,
                  controller: notifications,
                  onOpenGroup: _openGroupFromNotification,
                )),
            _hiddenTabGuard(
                KoomHomeTab.profile,
                ProfileScreen(
              api: widget.api,
              user: widget.session.user,
              onUserChanged: (user) => widget.onSessionChanged(
                widget.session.copyWith(user: user),
              ),
                  onAccountDeleted: widget.onAccountDeleted,
                  onLogout: widget.onLogout,
                  onLogoutAllDevices: widget.onLogoutAllDevices,
                )),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: notifications,
          builder: (context, _) => NavigationBar(
            key: const ValueKey('home_navigation_bar'),
            selectedIndex: _tab.index,
            onDestinationSelected: (index) =>
                selectTab(KoomHomeTab.values[index]),
            destinations: [
              NavigationDestination(
                key: const ValueKey('home_tab_groups'),
                icon: const Icon(Icons.groups_2_outlined),
                selectedIcon: const Icon(Icons.groups_2_rounded),
                label: text.groups,
              ),
              NavigationDestination(
                key: const ValueKey('home_tab_notifications'),
                icon: _NotificationsTabIcon(
                  count: notifications.badgeCount,
                  icon: Icons.notifications_none_rounded,
                ),
                selectedIcon: _NotificationsTabIcon(
                  count: notifications.badgeCount,
                  icon: Icons.notifications_rounded,
                ),
                label: text.notifications,
              ),
              NavigationDestination(
                key: const ValueKey('home_tab_profile'),
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: text.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bell with the unread total (pending invitations plus unread posts).
class _NotificationsTabIcon extends StatelessWidget {
  const _NotificationsTabIcon({required this.count, required this.icon});

  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return Icon(icon);
    return Badge(
      key: const ValueKey('home_tab_notifications_badge'),
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(icon),
    );
  }
}
