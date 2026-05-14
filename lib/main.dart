import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MobileChatApp());
}

class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const Duration networkTimeout = Duration(seconds: 15);
}

class MobileChatApp extends StatelessWidget {
  const MobileChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MobileChat',
      theme: AppTheme.light,
      home: LoginScreen(api: ApiClient(AppConfig.apiBaseUrl)),
    );
  }
}

class AppTheme {
  static const Color primary = Color(0xFF2AABEE);
  static const Color primaryDark = Color(0xFF168AC4);
  static const Color page = Color(0xFFF3F7FB);
  static const Color card = Colors.white;
  static const Color textStrong = Color(0xFF122033);
  static const Color textMuted = Color(0xFF64748B);
  static const Color bubbleMine = Color(0xFFDDF3FF);
  static const Color bubbleOther = Colors.white;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      surface: card,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      appBarTheme: const AppBarTheme(
        backgroundColor: card,
        foregroundColor: textStrong,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: const Color(0xFFE2E8F0),
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final DateTime? createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class ChatGroup {
  const ChatGroup({
    required this.id,
    required this.title,
    required this.description,
    required this.visibility,
    required this.ownerId,
    required this.memberCount,
    required this.inviteCode,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String visibility;
  final String ownerId;
  final int memberCount;
  final String? inviteCode;
  final DateTime? createdAt;

  bool get isPublic => visibility == 'public';

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      visibility: json['visibility'] as String,
      ownerId: json['owner_id'] as String? ?? '',
      memberCount: json['member_count'] as int? ?? 0,
      inviteCode: json['invite_code'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  const ApiClient(this.baseUrl);

  final String baseUrl;

  Future<UserProfile> login(String displayName) async {
    final response = await _post('/api/auth/login', {'display_name': displayName});
    return UserProfile.fromJson(response as Map<String, dynamic>);
  }

  Future<List<ChatGroup>> fetchGroups(String userId) async {
    final response = await _get('/api/groups', query: {'user_id': userId});
    return (response as List<dynamic>).map((item) => ChatGroup.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<ChatGroup>> searchPublicGroups(String query) async {
    final response = await _get('/api/groups/search', query: {'q': query});
    return (response as List<dynamic>).map((item) => ChatGroup.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatGroup> createGroup({
    required String ownerId,
    required String title,
    required String description,
    required String visibility,
  }) async {
    final response = await _post('/api/groups', {
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'visibility': visibility,
    });
    return ChatGroup.fromJson(response as Map<String, dynamic>);
  }

  Future<void> joinPublicGroup({required String userId, required String groupId}) async {
    await _post('/api/groups/$groupId/join', {'user_id': userId});
  }

  Future<ChatGroup> joinByInviteCode({required String userId, required String inviteCode}) async {
    final response = await _post('/api/groups/join-by-code', {
      'user_id': userId,
      'invite_code': inviteCode,
    });
    return ChatGroup.fromJson(response as Map<String, dynamic>);
  }

  Future<void> inviteUserById({
    required String adminId,
    required String groupId,
    required String targetUserId,
  }) async {
    await _post('/api/groups/$groupId/invite-user', {
      'admin_id': adminId,
      'target_user_id': targetUserId,
    });
  }

  Future<List<ChatMessage>> fetchMessages(String groupId) async {
    final response = await _get('/api/groups/$groupId/messages');
    return (response as List<dynamic>).map((item) => ChatMessage.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> sendMessage({
    required String groupId,
    required String senderId,
    required String text,
  }) async {
    final response = await _post('/api/groups/$groupId/messages', {
      'sender_id': senderId,
      'text': text,
    });
    return ChatMessage.fromJson(response as Map<String, dynamic>);
  }

  Future<dynamic> _get(String path, {Map<String, String>? query}) async {
    final uri = _uri(path, query: query);
    try {
      final response = await http.get(uri).timeout(AppConfig.networkTimeout);
      return _decode(response);
    } on TimeoutException {
      throw const ApiException('Connection timed out. Please check the server and try again.');
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException('Network error: $error');
    }
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final uri = _uri(path);
    try {
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(AppConfig.networkTimeout);
      return _decode(response);
    } on TimeoutException {
      throw const ApiException('Connection timed out. Please check the server and try again.');
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException('Network error: $error');
    }
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: path,
      queryParameters: query?.map((key, value) => MapEntry(key, value.trim())),
    );
  }

  dynamic _decode(http.Response response) {
    final body = response.body.trim();
    final decoded = body.isEmpty ? null : jsonDecode(body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    if (decoded is Map<String, dynamic> && decoded['error'] is String) {
      throw ApiException(decoded['error'] as String);
    }
    throw ApiException('Server error ${response.statusCode}');
  }
}

String avatarText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.substring(0, 1).toUpperCase();
}

String compactTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Enter at least 2 characters.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await widget.api.login(name);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(api: widget.api, user: user)),
      );
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: const [
                        BoxShadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 16)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const CircleAvatar(
                          radius: 42,
                          backgroundColor: AppTheme.primary,
                          child: Icon(Icons.forum_rounded, size: 42, color: Colors.white),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'MobileChat',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textStrong,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Clean group messaging for public communities and invite-only teams.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 26),
                        TextField(
                          controller: _nameController,
                          enabled: !_loading,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          ErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _loading ? null : _login,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Text(_loading ? 'Connecting...' : 'Continue'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Your visible user ID is created after login. Other users can add you to groups by this ID.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.user});

  final ApiClient api;
  final UserProfile user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ChatGroup>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _reloadGroups();
  }

  void _reloadGroups() {
    _groupsFuture = widget.api.fetchGroups(widget.user.id);
  }

  Future<void> _refresh() async {
    setState(_reloadGroups);
    await _groupsFuture;
  }

  void _openGroup(ChatGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(api: widget.api, user: widget.user, group: group)),
    );
  }

  Future<void> _openCreateGroup() async {
    final created = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => CreateGroupSheet(api: widget.api, user: widget.user),
    );
    if (created != null) {
      await _refresh();
      if (!mounted) return;
      showAppSnack(context, 'Group created.');
      _openGroup(created);
    }
  }

  Future<void> _openJoinByCode() async {
    final joined = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => JoinByCodeSheet(api: widget.api, user: widget.user),
    );
    if (joined != null) {
      await _refresh();
      if (!mounted) return;
      showAppSnack(context, 'Joined group.');
      _openGroup(joined);
    }
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchGroupsScreen(api: widget.api, user: widget.user)),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            tooltip: 'Search public groups',
            onPressed: _openSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Group actions',
            onSelected: (value) {
              if (value == 'create') _openCreateGroup();
              if (value == 'join') _openJoinByCode();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'create', child: Text('Create group')),
              PopupMenuItem(value: 'join', child: Text('Join by code')),
            ],
          ),
        ],
      ),
      drawer: ProfileDrawer(user: widget.user, apiBaseUrl: widget.api.baseUrl),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateGroup,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New group'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ChatGroup>>(
          future: _groupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingList();
            }
            if (snapshot.hasError) {
              return ErrorState(
                title: 'Could not load groups',
                message: snapshot.error.toString(),
                actionLabel: 'Try again',
                onAction: _refresh,
              );
            }
            final groups = snapshot.data ?? const [];
            if (groups.isEmpty) {
              return EmptyState(
                icon: Icons.groups_2_outlined,
                title: 'No groups yet',
                message: 'Create a group, search public groups, or join an invite-only group by code.',
                primaryLabel: 'Create group',
                onPrimary: _openCreateGroup,
                secondaryLabel: 'Search groups',
                onSecondary: _openSearch,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GroupTile(
                    group: group,
                    isOwner: group.ownerId == widget.user.id,
                    onTap: () => _openGroup(group),
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

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key, required this.user, required this.apiBaseUrl});

  final UserProfile user;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppTheme.primary,
                child: Text(
                  avatarText(user.displayName),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(user.displayName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              SelectableText('ID: ${user.id}', style: const TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 20),
              InfoPanel(
                icon: Icons.badge_outlined,
                title: 'Visible user ID',
                message: 'People can invite you to groups using this ID.',
              ),
              const SizedBox(height: 12),
              InfoPanel(
                icon: Icons.cloud_outlined,
                title: 'Server',
                message: apiBaseUrl,
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen(api: ApiClient(apiBaseUrl))),
                  (_) => false,
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupTile extends StatelessWidget {
  const GroupTile({super.key, required this.group, required this.isOwner, required this.onTap});

  final ChatGroup group;
  final bool isOwner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: group.isPublic ? AppTheme.primary : AppTheme.primaryDark,
                child: Text(
                  avatarText(group.title),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (isOwner) const GroupPill(label: 'Owner'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.description.isEmpty ? 'No description yet' : group.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        GroupPill(label: group.isPublic ? 'Public' : 'Invite only'),
                        GroupPill(label: '${group.memberCount} members'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupPill extends StatelessWidget {
  const GroupPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.primaryDark, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class SearchGroupsScreen extends StatefulWidget {
  const SearchGroupsScreen({super.key, required this.api, required this.user});

  final ApiClient api;
  final UserProfile user;

  @override
  State<SearchGroupsScreen> createState() => _SearchGroupsScreenState();
}

class _SearchGroupsScreenState extends State<SearchGroupsScreen> {
  final _queryController = TextEditingController();
  List<ChatGroup> _groups = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await widget.api.searchPublicGroups(_queryController.text.trim());
      setState(() => _groups = groups);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join(ChatGroup group) async {
    try {
      await widget.api.joinPublicGroup(userId: widget.user.id, groupId: group.id);
      if (!mounted) return;
      showAppSnack(context, 'Joined ${group.title}.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(api: widget.api, user: widget.user, group: group)),
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover groups')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search public groups',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorBanner(message: _error!),
            ),
          Expanded(
            child: _groups.isEmpty && !_loading
                ? EmptyState(
                    icon: Icons.travel_explore_rounded,
                    title: 'Nothing found',
                    message: 'Try another name or create a new public group.',
                    primaryLabel: 'Search again',
                    onPrimary: _search,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primary,
                              child: Text(avatarText(group.title), style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(group.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${group.memberCount} members · ${group.description}'),
                            trailing: FilledButton(
                              onPressed: () => _join(group),
                              child: const Text('Join'),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.api, required this.user, required this.group});

  final ApiClient api;
  final UserProfile user;
  final ChatGroup group;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  late Future<List<ChatMessage>> _messagesFuture;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _reloadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _reloadMessages() {
    _messagesFuture = widget.api.fetchMessages(widget.group.id);
  }

  Future<void> _refresh() async {
    setState(_reloadMessages);
    await _messagesFuture;
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.api.sendMessage(groupId: widget.group.id, senderId: widget.user.id, text: text);
      _messageController.clear();
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _inviteById() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => InviteByIdSheet(api: widget.api, user: widget.user, group: widget.group),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.group.ownerId == widget.user.id;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: widget.group.isPublic ? AppTheme.primary : AppTheme.primaryDark,
              child: Text(avatarText(widget.group.title), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.group.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${widget.group.isPublic ? 'Public' : 'Invite only'} · ${widget.group.memberCount} members',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isOwner ? 'Invite by user ID' : 'Only owner can invite',
            onPressed: isOwner ? _inviteById : null,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!widget.group.isPublic && widget.group.inviteCode != null)
            InviteCodeBanner(code: widget.group.inviteCode!),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<ChatMessage>>(
                future: _messagesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingMessages();
                  }
                  if (snapshot.hasError) {
                    return ErrorState(
                      title: 'Could not load messages',
                      message: snapshot.error.toString(),
                      actionLabel: 'Try again',
                      onAction: _refresh,
                    );
                  }
                  final messages = snapshot.data ?? const [];
                  if (messages.isEmpty) {
                    return EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No messages yet',
                      message: 'Start the group conversation.',
                      primaryLabel: 'Refresh',
                      onPrimary: _refresh,
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index];
                      final mine = message.senderId == widget.user.id;
                      return MessageBubble(message: message, mine: mine);
                    },
                  );
                },
              ),
            ),
          ),
          MessageComposer(controller: _messageController, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppTheme.bubbleMine : AppTheme.bubbleOther,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 6),
            bottomRight: Radius.circular(mine ? 6 : 18),
          ),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${message.senderName} · ${message.senderId}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            Text(message.text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textStrong)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                compactTime(message.createdAt.toLocal()),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageComposer extends StatelessWidget {
  const MessageComposer({super.key, required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, -8))],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({super.key, required this.api, required this.user});

  final ApiClient api;
  final UserProfile user;

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _visibility = 'public';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.length < 3) {
      setState(() => _error = 'Group name must contain at least 3 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final group = await widget.api.createGroup(
        ownerId: widget.user.id,
        title: title,
        description: _descriptionController.text.trim(),
        visibility: _visibility,
      );
      if (!mounted) return;
      Navigator.of(context).pop(group);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Create group',
      subtitle: 'Choose whether everyone can discover it or only invited users can join.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            enabled: !_loading,
            decoration: const InputDecoration(labelText: 'Group name', prefixIcon: Icon(Icons.groups_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            enabled: !_loading,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_rounded)),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'public', label: Text('Public'), icon: Icon(Icons.public_rounded)),
              ButtonSegment(value: 'private', label: Text('Invite only'), icon: Icon(Icons.lock_rounded)),
            ],
            selected: {_visibility},
            onSelectionChanged: _loading ? null : (value) => setState(() => _visibility = value.first),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _create,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_rounded),
            label: Text(_loading ? 'Creating...' : 'Create group'),
          ),
        ],
      ),
    );
  }
}

class JoinByCodeSheet extends StatefulWidget {
  const JoinByCodeSheet({super.key, required this.api, required this.user});

  final ApiClient api;
  final UserProfile user;

  @override
  State<JoinByCodeSheet> createState() => _JoinByCodeSheetState();
}

class _JoinByCodeSheetState extends State<JoinByCodeSheet> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter invite code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final group = await widget.api.joinByInviteCode(userId: widget.user.id, inviteCode: code);
      if (!mounted) return;
      Navigator.of(context).pop(group);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Join by code',
      subtitle: 'Use an invite code from a group owner or admin.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _codeController,
            enabled: !_loading,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Invite code', prefixIcon: Icon(Icons.key_rounded)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _join,
            icon: const Icon(Icons.login_rounded),
            label: Text(_loading ? 'Joining...' : 'Join group'),
          ),
        ],
      ),
    );
  }
}

class InviteByIdSheet extends StatefulWidget {
  const InviteByIdSheet({super.key, required this.api, required this.user, required this.group});

  final ApiClient api;
  final UserProfile user;
  final ChatGroup group;

  @override
  State<InviteByIdSheet> createState() => _InviteByIdSheetState();
}

class _InviteByIdSheetState extends State<InviteByIdSheet> {
  final _userIdController = TextEditingController();
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final targetUserId = _userIdController.text.trim();
    if (targetUserId.isEmpty) {
      setState(() => _message = 'Enter user ID.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await widget.api.inviteUserById(
        adminId: widget.user.id,
        groupId: widget.group.id,
        targetUserId: targetUserId,
      );
      setState(() => _message = 'User was added to the group.');
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Invite by ID',
      subtitle: 'Add a user directly to this group using their visible user ID.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _userIdController,
            enabled: !_loading,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'User ID', prefixIcon: Icon(Icons.person_add_alt_1_rounded)),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            InfoBanner(message: _message!),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _invite,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(_loading ? 'Inviting...' : 'Invite user'),
          ),
        ],
      ),
    );
  }
}

class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted)),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class InviteCodeBanner extends StatelessWidget {
  const InviteCodeBanner({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_rounded, color: Color(0xFFA16207)),
          const SizedBox(width: 10),
          Expanded(child: SelectableText('Invite code: $code')),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 76, color: AppTheme.primary),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted)),
        const SizedBox(height: 20),
        Center(child: FilledButton(onPressed: onPrimary, child: Text(primaryLabel))),
        if (secondaryLabel != null && onSecondary != null) ...[
          const SizedBox(height: 8),
          Center(child: TextButton(onPressed: onSecondary, child: Text(secondaryLabel!))),
        ],
      ],
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline_rounded, size: 76, color: Colors.redAccent),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted)),
        const SizedBox(height: 20),
        Center(child: FilledButton(onPressed: onAction, child: Text(actionLabel))),
      ],
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.primaryDark, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key, required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                SelectableText(message, style: const TextStyle(color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingList extends StatelessWidget {
  const LoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: 8,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: SkeletonCard(height: 82),
      ),
    );
  }
}

class LoadingMessages extends StatelessWidget {
  const LoadingMessages({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: 8,
      itemBuilder: (context, index) => Align(
        alignment: index.isEven ? Alignment.centerRight : Alignment.centerLeft,
        child: const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: SkeletonCard(width: 240, height: 58),
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.width, required this.height});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}
