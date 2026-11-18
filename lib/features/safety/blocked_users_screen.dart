import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/blocked_users.dart';
import '../../data/safety.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';
import 'safety_ui.dart';

/// Profile -> "Blocked users": lists blocked users with an unblock action.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({
    super.key,
    required this.api,
    this.controller,
  });

  final SafetyEndpoints api;
  final BlockedUsersController? controller;

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late final BlockedUsersController controller =
      widget.controller ?? BlockedUsersController.instance;
  final Set<String> busyIds = <String>{};
  bool loading = true;
  bool unavailable = false;
  String? error;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChanged);
    refresh();
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final users = await widget.api.fetchBlockedUsers();
      controller.replaceAll(users);
      unavailable = false;
    } on FeatureUnavailableException {
      unavailable = true;
    } catch (e) {
      if (mounted) error = localizedMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> unblock(BlockedUser user) async {
    if (busyIds.contains(user.userId)) return;
    final text = AppLanguageScope.textOf(context);
    setState(() => busyIds.add(user.userId));
    try {
      await controller.unblock(widget.api, user.userId);
      if (mounted) {
        showAppSnack(
          context,
          text.isKy
              ? 'Колдонуучу бөгөттөн чыгарылды.'
              : 'Пользователь разблокирован.',
        );
      }
    } on FeatureUnavailableException {
      if (mounted) showAppSnack(context, featureUnavailableMessage(text));
    } catch (e) {
      if (mounted) showAppSnack(context, localizedMessage(context, e.toString()));
    } finally {
      if (mounted) setState(() => busyIds.remove(user.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final users = controller.users;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          text.isKy ? 'Бөгөттөлгөн колдонуучулар' : 'Заблокированные пользователи',
        ),
        actions: const [AppSettingsButton()],
      ),
      body: KoomPageBackground(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (loading && users.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (unavailable)
                InfoBanner(message: featureUnavailableMessage(text))
              else if (error != null)
                ErrorBanner(message: error!)
              else if (users.isEmpty)
                KoomCard(
                  showShadow: false,
                  child: KoomEmptyState(
                    icon: Icons.block_rounded,
                    title: text.isKy
                        ? 'Бөгөттөлгөн колдонуучулар жок'
                        : 'Нет заблокированных пользователей',
                    message: text.isKy
                        ? 'Бөгөттөлгөн колдонуучулардын мазмуну сизге көрсөтүлбөйт.'
                        : 'Контент заблокированных пользователей скрыт от вас.',
                  ),
                )
              else
                KoomCard(
                  showShadow: false,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < users.length; i++) ...[
                        if (i > 0) Divider(color: colors.border, indent: 62),
                        ListTile(
                          key: ValueKey('blocked_user_${users[i].userId}'),
                          leading: KoomAvatar(
                            label: users[i].displayName,
                            radius: 19,
                          ),
                          title: Text(
                            users[i].displayName.trim().isEmpty
                                ? (text.isKy ? 'Колдонуучу' : 'Пользователь')
                                : users[i].displayName,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          trailing: TextButton(
                            key: ValueKey('unblock_${users[i].userId}'),
                            onPressed: busyIds.contains(users[i].userId)
                                ? null
                                : () => unblock(users[i]),
                            child: Text(
                              text.isKy ? 'Бөгөттөн чыгаруу' : 'Разблокировать',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
