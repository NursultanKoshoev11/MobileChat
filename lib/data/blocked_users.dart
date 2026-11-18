import 'package:flutter/foundation.dart';

import 'safety.dart';

/// Client-side source of truth for the users the signed-in user blocked.
///
/// Loaded from `GET /api/me/blocks` after sign-in and updated on
/// block/unblock. The server hides blocked users' content in list endpoints,
/// but realtime events are not filtered server-side, so screens use
/// [isBlocked] to drop incoming events and listen to this controller to hide
/// already-rendered content immediately after a block.
class BlockedUsersController extends ChangeNotifier {
  BlockedUsersController();

  static final BlockedUsersController instance = BlockedUsersController();

  final Map<String, BlockedUser> _users = <String, BlockedUser>{};
  bool _loaded = false;

  bool get loaded => _loaded;
  Set<String> get blockedIds => Set.unmodifiable(_users.keys);
  List<BlockedUser> get users {
    final list = _users.values.toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ));
    return List.unmodifiable(list);
  }

  bool isBlocked(String? userId) {
    final id = userId?.trim() ?? '';
    return id.isNotEmpty && _users.containsKey(id);
  }

  /// Returns [items] without those authored by blocked users.
  List<T> visible<T>(Iterable<T> items, String Function(T item) authorOf) {
    if (_users.isEmpty) return items.toList();
    return items.where((item) => !isBlocked(authorOf(item))).toList();
  }

  /// Replaces the local set with the server list. Failures (including an
  /// endpoint that is not deployed yet) keep the current state.
  Future<void> load(SafetyEndpoints api) async {
    try {
      final users = await api.fetchBlockedUsers();
      replaceAll(users);
    } catch (error) {
      if (kDebugMode) debugPrint('Blocked users not loaded: $error');
    }
  }

  void replaceAll(Iterable<BlockedUser> users) {
    _users
      ..clear()
      ..addEntries(users.map((user) => MapEntry(user.userId, user)));
    _loaded = true;
    notifyListeners();
  }

  /// Blocks [userId] on the server, then hides their content locally.
  Future<void> block(
    SafetyEndpoints api, {
    required String userId,
    required String displayName,
  }) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    await api.blockUser(id);
    _users[id] = BlockedUser(
      userId: id,
      displayName: displayName,
      blockedAt: DateTime.now().toUtc(),
    );
    notifyListeners();
  }

  Future<void> unblock(SafetyEndpoints api, String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    await api.unblockUser(id);
    if (_users.remove(id) != null) notifyListeners();
  }

  /// Forgets all state (sign-out / account deletion).
  void clear() {
    final hadUsers = _users.isNotEmpty || _loaded;
    _users.clear();
    _loaded = false;
    if (hadUsers) notifyListeners();
  }
}
