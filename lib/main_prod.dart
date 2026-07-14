import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MobileChatProductionApp());
}

class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
  static const Duration networkTimeout = Duration(seconds: 15);
}

class MobileChatProductionApp extends StatefulWidget {
  const MobileChatProductionApp({super.key});

  @override
  State<MobileChatProductionApp> createState() => _MobileChatProductionAppState();
}

class _MobileChatProductionAppState extends State<MobileChatProductionApp> {
  late final SecureSessionStore sessionStore;
  late final ApiClient api;
  late Future<AppSession?> bootFuture;

  @override
  void initState() {
    super.initState();
    sessionStore = const SecureSessionStore();
    api = ApiClient(AppConfig.apiBaseUrl, sessionStore);
    bootFuture = sessionStore.readSession();
  }

  Future<void> _setSession(AppSession session) async {
    await sessionStore.saveSession(session);
    setState(() => bootFuture = Future.value(session));
  }

  Future<void> _logout() async {
    await sessionStore.clear();
    setState(() => bootFuture = Future.value(null));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MobileChat',
      theme: AppTheme.light,
      home: FutureBuilder<AppSession?>(
        future: bootFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          final session = snapshot.data;
          if (session == null) {
            return AuthScreen(api: api, onAuthenticated: _setSession);
          }
          return HomeScreen(api: api, session: session, onLogout: _logout);
        },
      ),
    );
  }
}

class AppTheme {
  static const Color primary = Color(0xFF2AABEE);
  static const Color primaryDark = Color(0xFF168AC4);
  static const Color page = Color(0xFFF3F7FB);
  static const Color textStrong = Color(0xFF122033);
  static const Color textMuted = Color(0xFF64748B);
  static const Color mineBubble = Color(0xFFDDF3FF);
  static const Color otherBubble = Colors.white;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: primary, primary: primary);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textStrong,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
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
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class AppSession {
  const AppSession({required this.accessToken, required this.user});

  final String accessToken;
  final UserProfile user;

  factory AppSession.fromJson(Map<String, dynamic> json) {
    return AppSession(
      accessToken: json['access_token'] as String,
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {'access_token': accessToken, 'user': user.toJson()};
  }
}

class UserProfile {
  const UserProfile({required this.id, required this.email, required this.displayName, required this.createdAt});

  final String id;
  final String email;
  final String displayName;
  final DateTime? createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'created_at': createdAt?.toIso8601String(),
    };
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
    required this.myRole,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String visibility;
  final String ownerId;
  final int memberCount;
  final String? inviteCode;
  final String? myRole;
  final DateTime? createdAt;

  bool get isPublic => visibility == 'public';
  bool get canInvite => myRole == 'owner' || myRole == 'admin';

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      visibility: json['visibility'] as String,
      ownerId: json['owner_id'] as String? ?? '',
      memberCount: json['member_count'] as int? ?? 0,
      inviteCode: json['invite_code'] as String?,
      myRole: json['my_role'] as String?,
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

class SecureSessionStore {
  const SecureSessionStore();

  static const _storage = FlutterSecureStorage();
  static const _sessionKey = 'mobilechat_session_v1';

  Future<AppSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> saveSession(AppSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
  }
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  const ApiClient(this.baseUrl, this.sessionStore);

  final String baseUrl;
  final SecureSessionStore sessionStore;

  Future<AppSession> register({required String email, required String displayName, required String password}) async {
    final response = await _post('/api/auth/register', {
      'email': email,
      'display_name': displayName,
      'password': password,
    }, auth: false);
    return AppSession.fromJson(response as Map<String, dynamic>);
  }

  Future<AppSession> login({required String email, required String password}) async {
    final response = await _post('/api/auth/login', {'email': email, 'password': password}, auth: false);
    return AppSession.fromJson(response as Map<String, dynamic>);
  }

  Future<UserProfile> me() async {
    final response = await _get('/api/me');
    return UserProfile.fromJson(response as Map<String, dynamic>);
  }

  Future<List<ChatGroup>> fetchGroups() async {
    final response = await _get('/api/groups');
    return (response as List<dynamic>).map((item) => ChatGroup.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<ChatGroup>> searchPublicGroups(String query) async {
    final response = await _get('/api/groups/search', query: {'q': query});
    return (response as List<dynamic>).map((item) => ChatGroup.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatGroup> createGroup({required String title, required String description, required String visibility}) async {
    final response = await _post('/api/groups', {
      'title': title,
      'description': description,
      'visibility': visibility,
    });
    return ChatGroup.fromJson(response as Map<String, dynamic>);
  }

  Future<void> joinPublicGroup({required String groupId}) async {
    await _post('/api/groups/$groupId/join', {});
  }

  Future<ChatGroup> joinByInviteCode({required String inviteCode}) async {
    final response = await _post('/api/groups/join-by-code', {'invite_code': inviteCode});
    return ChatGroup.fromJson(response as Map<String, dynamic>);
  }

  Future<void> inviteUserById({required String groupId, required String targetUserId}) async {
    await _post('/api/groups/$groupId/invite-user', {'target_user_id': targetUserId});
  }

  Future<List<ChatMessage>> fetchMessages(String groupId, {int limit = 50, DateTime? before}) async {
    final query = <String, String>{'limit': '$limit'};
    if (before != null) query['before'] = before.toUtc().toIso8601String();
    final response = await _get('/api/groups/$groupId/messages', query: query);
    return (response as List<dynamic>).map((item) => ChatMessage.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> sendMessage({required String groupId, required String text}) async {
    final response = await _post('/api/groups/$groupId/messages', {'text': text});
    return ChatMessage.fromJson(response as Map<String, dynamic>);
  }

  Future<dynamic> _get(String path, {Map<String, String>? query, bool auth = true}) async {
    return _request('GET', path, query: query, auth: auth);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    return _request('POST', path, body: body, auth: auth);
  }

  Future<dynamic> _request(String method, String path, {Map<String, String>? query, Map<String, dynamic>? body, bool auth = true}) async {
    final uri = _uri(path, query: query);
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final session = await sessionStore.readSession();
      if (session == null) throw const ApiException('Session expired. Please sign in again.');
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    try {
      final response = method == 'GET'
          ? await http.get(uri, headers: headers).timeout(AppConfig.networkTimeout)
          : await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(AppConfig.networkTimeout);
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
    return base.replace(path: path, queryParameters: query);
  }

  dynamic _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes).trim();
    final decoded = body.isEmpty ? null : jsonDecode(body);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    if (decoded is Map<String, dynamic> && decoded['error'] is String) {
      throw ApiException(decoded['error'] as String);
    }
    throw ApiException('Server error ${response.statusCode}');
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.api, required this.onAuthenticated});

  final ApiClient api;
  final Future<void> Function(AppSession session) onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  bool isRegister = false;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final session = isRegister
          ? await widget.api.register(
              email: emailController.text.trim(),
              displayName: nameController.text.trim(),
              password: passwordController.text,
            )
          : await widget.api.login(email: emailController.text.trim(), password: passwordController.text);
      await widget.onAuthenticated(session);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
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
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 16))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CircleAvatar(radius: 42, backgroundColor: AppTheme.primary, child: Icon(Icons.forum_rounded, color: Colors.white, size: 42)),
                    const SizedBox(height: 22),
                    Text('MobileChat', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      isRegister ? 'Create a secure account to start group messaging.' : 'Sign in to your secure group chat account.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 24),
                    TextField(controller: emailController, enabled: !loading, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                    if (isRegister) ...[
                      const SizedBox(height: 12),
                      TextField(controller: nameController, enabled: !loading, decoration: const InputDecoration(labelText: 'Display name', prefixIcon: Icon(Icons.person_outline_rounded))),
                    ],
                    const SizedBox(height: 12),
                    TextField(controller: passwordController, enabled: !loading, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded))),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      ErrorBanner(message: error!),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: loading ? null : submit,
                      icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_forward_rounded),
                      label: Text(loading ? 'Please wait...' : (isRegister ? 'Create account' : 'Sign in')),
                    ),
                    TextButton(
                      onPressed: loading ? null : () => setState(() => isRegister = !isRegister),
                      child: Text(isRegister ? 'Already have an account? Sign in' : 'Need an account? Create one'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.session, required this.onLogout});

  final ApiClient api;
  final AppSession session;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ChatGroup>> groupsFuture;

  @override
  void initState() {
    super.initState();
    groupsFuture = widget.api.fetchGroups();
  }

  Future<void> refresh() async {
    setState(() => groupsFuture = widget.api.fetchGroups());
    await groupsFuture;
  }

  Future<void> openCreateGroup() async {
    final group = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => CreateGroupSheet(api: widget.api),
    );
    if (group != null) {
      await refresh();
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(api: widget.api, user: widget.session.user, group: group)));
    }
  }

  Future<void> openJoinByCode() async {
    final group = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => JoinByCodeSheet(api: widget.api),
    );
    if (group != null) {
      await refresh();
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(api: widget.api, user: widget.session.user, group: group)));
    }
  }

  Future<void> openSearch() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchGroupsScreen(api: widget.api, user: widget.session.user)));
    await refresh();
  }

  void openGroup(ChatGroup group) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(api: widget.api, user: widget.session.user, group: group)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(onPressed: openSearch, icon: const Icon(Icons.search_rounded)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'create') openCreateGroup();
              if (value == 'join') openJoinByCode();
              if (value == 'logout') widget.onLogout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'create', child: Text('Create group')),
              PopupMenuItem(value: 'join', child: Text('Join by code')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
      drawer: ProfileDrawer(user: widget.session.user, apiBaseUrl: widget.api.baseUrl, onLogout: widget.onLogout),
      floatingActionButton: FloatingActionButton.extended(onPressed: openCreateGroup, icon: const Icon(Icons.add_rounded), label: const Text('New group')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<ChatGroup>>(
          future: groupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const LoadingList();
            if (snapshot.hasError) return ErrorState(title: 'Could not load groups', message: snapshot.error.toString(), onAction: refresh);
            final groups = snapshot.data ?? const [];
            if (groups.isEmpty) {
              return EmptyState(
                icon: Icons.groups_2_outlined,
                title: 'No groups yet',
                message: 'Create a group, search public groups, or join an invite-only group by code.',
                primaryLabel: 'Create group',
                onPrimary: openCreateGroup,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GroupTile(group: group, onTap: () => openGroup(group)),
                );
              },
            );
          },
        ),
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
  final queryController = TextEditingController();
  List<ChatGroup> groups = const [];
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    search();
  }

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }

  Future<void> search() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      groups = await widget.api.searchPublicGroups(queryController.text.trim());
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> join(ChatGroup group) async {
    try {
      await widget.api.joinPublicGroup(groupId: group.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(api: widget.api, user: widget.user, group: group)));
    } catch (e) {
      showAppSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover groups')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: queryController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => search(),
              decoration: InputDecoration(hintText: 'Search public groups', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: IconButton(onPressed: search, icon: const Icon(Icons.arrow_forward_rounded))),
            ),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error != null) Padding(padding: const EdgeInsets.all(16), child: ErrorBanner(message: error!)),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: AppTheme.primary, child: Text(avatarText(group.title), style: const TextStyle(color: Colors.white))),
                      title: Text(group.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${group.memberCount} members · ${group.description}'),
                      trailing: FilledButton(onPressed: () => join(group), child: const Text('Join')),
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
  final messageController = TextEditingController();
  late Future<List<ChatMessage>> messagesFuture;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    messagesFuture = widget.api.fetchMessages(widget.group.id);
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => messagesFuture = widget.api.fetchMessages(widget.group.id));
    await messagesFuture;
  }

  Future<void> send() async {
    final text = messageController.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await widget.api.sendMessage(groupId: widget.group.id, text: text);
      messageController.clear();
      await refresh();
    } catch (e) {
      showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> invite() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => InviteByIdSheet(api: widget.api, group: widget.group),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(backgroundColor: widget.group.isPublic ? AppTheme.primary : AppTheme.primaryDark, child: Text(avatarText(widget.group.title), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(widget.group.title, maxLines: 1, overflow: TextOverflow.ellipsis), Text('${widget.group.isPublic ? 'Public' : 'Invite only'} · ${widget.group.memberCount} members', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))])),
          ],
        ),
        actions: [IconButton(onPressed: widget.group.canInvite ? invite : null, icon: const Icon(Icons.person_add_alt_1_rounded))],
      ),
      body: Column(
        children: [
          if (!widget.group.isPublic && widget.group.inviteCode != null && widget.group.inviteCode!.isNotEmpty) InviteCodeBanner(code: widget.group.inviteCode!),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: FutureBuilder<List<ChatMessage>>(
                future: messagesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const LoadingMessages();
                  if (snapshot.hasError) return ErrorState(title: 'Could not load messages', message: snapshot.error.toString(), onAction: refresh);
                  final messages = snapshot.data ?? const [];
                  if (messages.isEmpty) return EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'No messages yet', message: 'Start the group conversation.', primaryLabel: 'Refresh', onPrimary: refresh);
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index];
                      return MessageBubble(message: message, mine: message.senderId == widget.user.id);
                    },
                  );
                },
              ),
            ),
          ),
          MessageComposer(controller: messageController, sending: sending, onSend: send),
        ],
      ),
    );
  }
}

class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({super.key, required this.api});
  final ApiClient api;
  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String visibility = 'public';
  bool loading = false;
  String? error;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> create() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final group = await widget.api.createGroup(title: titleController.text.trim(), description: descriptionController.text.trim(), visibility: visibility);
      if (!mounted) return;
      Navigator.of(context).pop(group);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(title: 'Create group', subtitle: 'Public groups are searchable. Invite-only groups require code or admin invite.', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Group name', prefixIcon: Icon(Icons.groups_rounded))),
      const SizedBox(height: 12),
      TextField(controller: descriptionController, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_rounded))),
      const SizedBox(height: 14),
      SegmentedButton<String>(showSelectedIcon: false, segments: const [ButtonSegment(value: 'public', label: Text('Public'), icon: Icon(Icons.public_rounded)), ButtonSegment(value: 'private', label: Text('Invite only'), icon: Icon(Icons.lock_rounded))], selected: {visibility}, onSelectionChanged: (value) => setState(() => visibility = value.first)),
      if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: loading ? null : create, icon: const Icon(Icons.add_rounded), label: Text(loading ? 'Creating...' : 'Create group')),
    ]));
  }
}

class JoinByCodeSheet extends StatefulWidget {
  const JoinByCodeSheet({super.key, required this.api});
  final ApiClient api;
  @override
  State<JoinByCodeSheet> createState() => _JoinByCodeSheetState();
}

class _JoinByCodeSheetState extends State<JoinByCodeSheet> {
  final codeController = TextEditingController();
  bool loading = false;
  String? error;
  @override
  void dispose() { codeController.dispose(); super.dispose(); }
  Future<void> join() async {
    setState(() { loading = true; error = null; });
    try {
      final group = await widget.api.joinByInviteCode(inviteCode: codeController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(group);
    } catch (e) { setState(() => error = e.toString()); } finally { if (mounted) setState(() => loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    return SheetFrame(title: 'Join by code', subtitle: 'Use an invite code from a private group admin.', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: codeController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Invite code', prefixIcon: Icon(Icons.key_rounded))),
      if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: loading ? null : join, icon: const Icon(Icons.login_rounded), label: Text(loading ? 'Joining...' : 'Join group')),
    ]));
  }
}

class InviteByIdSheet extends StatefulWidget {
  const InviteByIdSheet({super.key, required this.api, required this.group});
  final ApiClient api;
  final ChatGroup group;
  @override
  State<InviteByIdSheet> createState() => _InviteByIdSheetState();
}

class _InviteByIdSheetState extends State<InviteByIdSheet> {
  final userIdController = TextEditingController();
  bool loading = false;
  String? message;
  @override
  void dispose() { userIdController.dispose(); super.dispose(); }
  Future<void> invite() async {
    setState(() { loading = true; message = null; });
    try {
      await widget.api.inviteUserById(groupId: widget.group.id, targetUserId: userIdController.text.trim());
      setState(() => message = 'User was added to the group.');
    } catch (e) { setState(() => message = e.toString()); } finally { if (mounted) setState(() => loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    return SheetFrame(title: 'Invite by ID', subtitle: 'Add a user using their visible user ID.', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: userIdController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'User ID', prefixIcon: Icon(Icons.person_add_alt_1_rounded))),
      if (message != null) ...[const SizedBox(height: 12), InfoBanner(message: message!)],
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: loading ? null : invite, icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(loading ? 'Inviting...' : 'Invite user')),
    ]));
  }
}

class GroupTile extends StatelessWidget {
  const GroupTile({super.key, required this.group, required this.onTap});
  final ChatGroup group;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(22), child: InkWell(borderRadius: BorderRadius.circular(22), onTap: onTap, child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      CircleAvatar(radius: 26, backgroundColor: group.isPublic ? AppTheme.primary : AppTheme.primaryDark, child: Text(avatarText(group.title), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))), if (group.myRole != null) GroupPill(label: group.myRole!)]),
        const SizedBox(height: 4),
        Text(group.description.isEmpty ? 'No description yet' : group.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [GroupPill(label: group.isPublic ? 'Public' : 'Invite only'), GroupPill(label: '${group.memberCount} members')]),
      ])),
      const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
    ]))));
  }
}

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key, required this.user, required this.apiBaseUrl, required this.onLogout});
  final UserProfile user;
  final String apiBaseUrl;
  final Future<void> Function() onLogout;
  @override
  Widget build(BuildContext context) {
    return Drawer(child: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 34, backgroundColor: AppTheme.primary, child: Text(avatarText(user.displayName), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white))),
      const SizedBox(height: 16),
      Text(user.displayName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      SelectableText('ID: ${user.id}', style: const TextStyle(color: AppTheme.textMuted)),
      const SizedBox(height: 6),
      SelectableText(user.email, style: const TextStyle(color: AppTheme.textMuted)),
      const SizedBox(height: 20),
      InfoPanel(icon: Icons.badge_outlined, title: 'Visible user ID', message: 'People can invite you to groups using this ID.'),
      const SizedBox(height: 12),
      InfoPanel(icon: Icons.cloud_outlined, title: 'Server', message: apiBaseUrl),
      const Spacer(),
      OutlinedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout_rounded), label: const Text('Log out')),
    ]))));
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;
  @override
  Widget build(BuildContext context) {
    return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78), margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: mine ? AppTheme.mineBubble : AppTheme.otherBubble, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 6))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!mine) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('${message.senderName} · ${message.senderId}', style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w800, fontSize: 12))),
      Text(message.text, style: const TextStyle(color: AppTheme.textStrong)),
      const SizedBox(height: 4),
      Align(alignment: Alignment.centerRight, child: Text(compactTime(message.createdAt.toLocal()), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
    ])));
  }
}

class MessageComposer extends StatelessWidget {
  const MessageComposer({super.key, required this.controller, required this.sending, required this.onSend});
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) {
    return SafeArea(top: false, child: Container(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, -8))]), child: Row(children: [
      Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 5, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Message', prefixIcon: Icon(Icons.chat_bubble_outline_rounded)))),
      const SizedBox(width: 8),
      IconButton.filled(onPressed: sending ? null : onSend, icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded)),
    ])));
  }
}

class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: MediaQuery.of(context).viewInsets.bottom + 22), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: AppTheme.textMuted)),
      const SizedBox(height: 18),
      child,
    ])));
  }
}

class GroupPill extends StatelessWidget { const GroupPill({super.key, required this.label}); final String label; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)), child: Text(label, style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w700, fontSize: 11))); }
class ErrorBanner extends StatelessWidget { const ErrorBanner({super.key, required this.message}); final String message; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFCDD2))), child: Row(children: [const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20), const SizedBox(width: 8), Expanded(child: Text(message))])); }
class InfoBanner extends StatelessWidget { const InfoBanner({super.key, required this.message}); final String message; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFBFDBFE))), child: Row(children: [const Icon(Icons.info_outline_rounded, color: AppTheme.primaryDark, size: 20), const SizedBox(width: 8), Expanded(child: Text(message))])); }
class InfoPanel extends StatelessWidget { const InfoPanel({super.key, required this.icon, required this.title, required this.message}); final IconData icon; final String title; final String message; @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: AppTheme.primaryDark), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), SelectableText(message, style: const TextStyle(color: AppTheme.textMuted))]))])); }
class InviteCodeBanner extends StatelessWidget { const InviteCodeBanner({super.key, required this.code}); final String code; @override Widget build(BuildContext context) => Container(width: double.infinity, margin: const EdgeInsets.fromLTRB(12, 8, 12, 0), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFFDE68A))), child: Row(children: [const Icon(Icons.key_rounded, color: Color(0xFFA16207)), const SizedBox(width: 10), Expanded(child: SelectableText('Invite code: $code'))])); }
class LoadingList extends StatelessWidget { const LoadingList({super.key}); @override Widget build(BuildContext context) => ListView.builder(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), itemCount: 8, itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(bottom: 10), child: SkeletonCard(height: 82))); }
class LoadingMessages extends StatelessWidget { const LoadingMessages({super.key}); @override Widget build(BuildContext context) => ListView.builder(reverse: true, padding: const EdgeInsets.all(12), itemCount: 8, itemBuilder: (_, index) => Align(alignment: index.isEven ? Alignment.centerRight : Alignment.centerLeft, child: const Padding(padding: EdgeInsets.only(bottom: 8), child: SkeletonCard(width: 240, height: 58)))); }
class SkeletonCard extends StatelessWidget { const SkeletonCard({super.key, this.width, required this.height}); final double? width; final double height; @override Widget build(BuildContext context) => Container(width: width, height: height, decoration: BoxDecoration(color: Colors.white.withOpacity(0.82), borderRadius: BorderRadius.circular(22))); }
class EmptyState extends StatelessWidget { const EmptyState({super.key, required this.icon, required this.title, required this.message, required this.primaryLabel, required this.onPrimary}); final IconData icon; final String title; final String message; final String primaryLabel; final VoidCallback onPrimary; @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [const SizedBox(height: 80), Icon(icon, size: 76, color: AppTheme.primary), const SizedBox(height: 16), Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted)), const SizedBox(height: 20), Center(child: FilledButton(onPressed: onPrimary, child: Text(primaryLabel)))]); }
class ErrorState extends StatelessWidget { const ErrorState({super.key, required this.title, required this.message, required this.onAction}); final String title; final String message; final Future<void> Function() onAction; @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [const SizedBox(height: 80), const Icon(Icons.error_outline_rounded, size: 76, color: Colors.redAccent), const SizedBox(height: 16), Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted)), const SizedBox(height: 20), Center(child: FilledButton(onPressed: onAction, child: const Text('Try again')))]); }

String avatarText(String value) { final trimmed = value.trim(); if (trimmed.isEmpty) return '?'; return trimmed.substring(0, 1).toUpperCase(); }
String compactTime(DateTime time) { final h = time.hour.toString().padLeft(2, '0'); final m = time.minute.toString().padLeft(2, '0'); return '$h:$m'; }
void showAppSnack(BuildContext context, String message) { ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message))); }
