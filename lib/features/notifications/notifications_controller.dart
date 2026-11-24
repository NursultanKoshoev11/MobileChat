import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../data/api_client.dart';
import '../../data/group_invitation.dart';
import '../../data/models.dart';

/// Backs the notifications tab and the badge on its navigation destination.
///
/// The server has no notification feed, so everything here is derived from
/// endpoints that already exist:
///
/// * pending invitations come from `GET /api/invites` ([ApiClient.fetchInvitations]),
/// * `new posts in <group>` entries come from the per-group unread counter the
///   group list already carries ([ChatGroup.unreadPublicRequestCount]).
///
/// The groups tab owns loading and realtime updates of the group list and
/// pushes it here through [setGroups], so both tabs always show the same
/// counts without fetching twice.
class KoomNotificationsController extends ChangeNotifier {
  KoomNotificationsController({required this.api});

  final ApiClient api;

  List<GroupInvitation> _invitations = const <GroupInvitation>[];
  List<ChatGroup> _groups = const <ChatGroup>[];
  bool _loading = true;
  Object? _error;
  bool _disposed = false;

  /// Set by the groups tab so a pull-to-refresh here also refreshes the group
  /// list the unread entries are built from.
  Future<void> Function()? groupsRefresher;

  List<GroupInvitation> get invitations => _invitations;

  /// Groups with at least one unread post, newest counts first.
  List<ChatGroup> get unreadGroups => _groups
      .where((group) => group.unreadPublicRequestCount > 0)
      .toList(growable: false);

  bool get loading => _loading;
  Object? get error => _error;

  int get invitationCount => _invitations.length;

  int get unreadPostCount => _groups.fold<int>(
        0,
        (total, group) => total + group.unreadPublicRequestCount,
      );

  /// Number shown as a badge on the notifications destination.
  int get badgeCount => invitationCount + unreadPostCount;

  bool get isEmpty => _invitations.isEmpty && unreadPostCount == 0;

  /// Receives the group list owned by the groups tab.
  void setGroups(List<ChatGroup> groups) {
    _groups = List<ChatGroup>.unmodifiable(groups);
    _notify();
  }

  /// Loads pending invitations. [silent] keeps the current list visible and
  /// swallows the error, which is what realtime-triggered refreshes want.
  Future<void> load({bool silent = false}) async {
    if (_disposed) return;
    if (!silent) {
      _loading = true;
      _error = null;
      _notify();
    }
    try {
      final invitations = await api.fetchInvitations();
      if (_disposed) return;
      _invitations = List<GroupInvitation>.unmodifiable(invitations);
      _error = null;
    } catch (error) {
      if (_disposed) return;
      if (!silent) _error = error;
    } finally {
      if (!_disposed) {
        _loading = false;
        _notify();
      }
    }
  }

  /// Pull-to-refresh: invitations and the group list behind the unread
  /// entries. [groupsRefresher] reloads invitations as part of refreshing the
  /// groups tab, so going through it keeps this to one request per endpoint.
  Future<void> refresh() async {
    final refreshGroups = groupsRefresher;
    if (refreshGroups == null) {
      await load(silent: true);
      return;
    }
    try {
      await refreshGroups();
    } catch (_) {
      // Fall back to the invitations this tab can refresh on its own.
      await load(silent: true);
    }
  }

  /// Drops an invitation that was just accepted or declined.
  void removeInvitation(String invitationId) {
    if (invitationId.isEmpty) return;
    final next = _invitations
        .where((invitation) => invitation.id != invitationId)
        .toList(growable: false);
    if (next.length == _invitations.length) return;
    _invitations = List<GroupInvitation>.unmodifiable(next);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    groupsRefresher = null;
    super.dispose();
  }

  /// Notifies listeners, deferring to the next microtask when a frame is
  /// already building (realtime events can arrive mid-build).
  void _notify() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      scheduleMicrotask(() {
        if (!_disposed) notifyListeners();
      });
      return;
    }
    notifyListeners();
  }
}
