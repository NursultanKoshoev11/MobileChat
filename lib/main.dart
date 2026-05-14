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
}

class MobileChatApp extends StatelessWidget {
  const MobileChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MobileChat',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2AABEE),
        scaffoldBackgroundColor: const Color(0xFFF4F7FA),
      ),
      home: const LoginScreen(),
    );
  }
}

class UserProfile {
  const UserProfile({required this.id, required this.displayName});

  final String id;
  final String displayName;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
    );
  }
}

class ChatGroup {
  const ChatGroup({
    required this.id,
    required this.title,
    required this.description,
    required this.visibility,
    required this.memberCount,
    required this.inviteCode,
  });

  final String id;
  final String title;
  final String description;
  final String visibility;
  final int memberCount;
  final String? inviteCode;

  bool get isPublic => visibility == 'public';

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      visibility: json['visibility'] as String,
      memberCount: json['member_count'] as int? ?? 0,
      inviteCode: json['invite_code'] as String?,
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

class ApiClient {
  const ApiClient(this.baseUrl);

  final String baseUrl;

  Future<UserProfile> login(String displayName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'display_name': displayName}),
    );
    _throwIfFailed(response);
    return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<ChatGroup>> fetchGroups(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/groups?user_id=$userId'),
    );
    _throwIfFailed(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => ChatGroup.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<ChatGroup>> searchPublicGroups(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/groups/search?q=${Uri.encodeQueryComponent(query)}'),
    );
    _throwIfFailed(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => ChatGroup.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatGroup> createGroup({
    required String ownerId,
    required String title,
    required String description,
    required String visibility,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/groups'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'owner_id': ownerId,
        'title': title,
        'description': description,
        'visibility': visibility,
      }),
    );
    _throwIfFailed(response);
    return ChatGroup.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> joinPublicGroup({required String userId, required String groupId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/groups/$groupId/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    _throwIfFailed(response);
  }

  Future<ChatGroup> joinByInviteCode({required String userId, required String inviteCode}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/groups/join-by-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'invite_code': inviteCode}),
    );
    _throwIfFailed(response);
    return ChatGroup.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> inviteUserById({
    required String adminId,
    required String groupId,
    required String targetUserId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/groups/$groupId/invite-user'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'admin_id': adminId, 'target_user_id': targetUserId}),
    );
    _throwIfFailed(response);
  }

  Future<List<ChatMessage>> fetchMessages(String groupId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/groups/$groupId/messages'));
    _throwIfFailed(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => ChatMessage.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> sendMessage({
    required String groupId,
    required String senderId,
    required String text,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/groups/$groupId/messages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sender_id': senderId, 'text': text}),
    );
    _throwIfFailed(response);
    return ChatMessage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw Exception('API error ${response.statusCode}: ${response.body}');
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _api = const ApiClient(AppConfig.apiBaseUrl);
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your display name');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _api.login(name);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(api: _api, user: user)),
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
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CircleAvatar(
                        radius: 38,
                        child: Icon(Icons.forum_rounded, size: 42),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'MobileChat',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Group chats only. Public groups, private groups, invite codes and visible user IDs.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _nameController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Continue'),
                      ),
                    ],
                  ),
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
      MaterialPageRoute(
        builder: (_) => ChatScreen(api: widget.api, user: widget.user, group: group),
      ),
    );
  }

  Future<void> _openCreateGroup() async {
    final created = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreateGroupSheet(api: widget.api, user: widget.user),
    );
    if (created != null) {
      await _refresh();
      _openGroup(created);
    }
  }

  Future<void> _openJoinByCode() async {
    final joined = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      builder: (_) => JoinByCodeSheet(api: widget.api, user: widget.user),
    );
    if (joined != null) {
      await _refresh();
      _openGroup(joined);
    }
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchGroupsScreen(api: widget.api, user: widget.user),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(onPressed: _openSearch, icon: const Icon(Icons.search_rounded)),
          PopupMenuButton<String>(
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
      drawer: Drawer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(radius: 32, child: Icon(Icons.person_rounded, size: 34)),
                const SizedBox(height: 16),
                Text(widget.user.displayName, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                SelectableText('ID: ${widget.user.id}'),
                const Divider(height: 32),
                const Text('Your ID is visible. Other users can invite you to groups by this ID.'),
              ],
            ),
          ),
        ),
      ),
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
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load groups: ${snapshot.error}'),
                  ),
                ],
              );
            }
            final groups = snapshot.data ?? const [];
            if (groups.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.groups_rounded, size: 72),
                  SizedBox(height: 16),
                  Text('No groups yet', textAlign: TextAlign.center),
                  SizedBox(height: 8),
                  Text('Create a group, search public groups, or join a private group by invite code.', textAlign: TextAlign.center),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final group = groups[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(group.title.characters.first.toUpperCase())),
                  title: Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${group.isPublic ? 'Public' : 'Private'} · ${group.memberCount} members'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openGroup(group),
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
    await widget.api.joinPublicGroup(userId: widget.user.id, groupId: group.id);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ChatScreen(api: widget.api, user: widget.user, group: group)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search public groups')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search groups',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward_rounded)),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          Expanded(
            child: ListView.separated(
              itemCount: _groups.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final group = _groups[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(group.title.characters.first.toUpperCase())),
                  title: Text(group.title),
                  subtitle: Text('${group.memberCount} members · ${group.description}'),
                  trailing: FilledButton(onPressed: () => _join(group), child: const Text('Join')),
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

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await widget.api.sendMessage(groupId: widget.group.id, senderId: widget.user.id, text: text);
    setState(_reloadMessages);
  }

  Future<void> _inviteById() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => InviteByIdSheet(api: widget.api, user: widget.user, group: widget.group),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(child: Text(widget.group.title.characters.first.toUpperCase())),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.group.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${widget.group.isPublic ? 'Public' : 'Private'} · ${widget.group.memberCount} members',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: _inviteById, icon: const Icon(Icons.person_add_alt_1_rounded)),
        ],
      ),
      body: Column(
        children: [
          if (!widget.group.isPublic && widget.group.inviteCode != null)
            MaterialBanner(
              content: SelectableText('Invite code: ${widget.group.inviteCode}'),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            child: FutureBuilder<List<ChatMessage>>(
              future: _messagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? const [];
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final mine = message.senderId == widget.user.id;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Card(
                          elevation: 0,
                          color: mine ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!mine)
                                  Text(
                                    '${message.senderName} · ${message.senderId}',
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                Text(message.text),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ),
        ],
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _loading = true);
    try {
      final group = await widget.api.createGroup(
        ownerId: widget.user.id,
        title: title,
        description: _descriptionController.text.trim(),
        visibility: _visibility,
      );
      if (!mounted) return;
      Navigator.of(context).pop(group);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Create group', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Group name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'public', label: Text('Public'), icon: Icon(Icons.public_rounded)),
              ButtonSegment(value: 'private', label: Text('Private'), icon: Icon(Icons.lock_rounded)),
            ],
            selected: {_visibility},
            onSelectionChanged: (value) => setState(() => _visibility = value.first),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _loading ? null : _create, child: const Text('Create')),
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final group = await widget.api.joinByInviteCode(userId: widget.user.id, inviteCode: _codeController.text.trim());
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
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Join private group', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _codeController, decoration: const InputDecoration(labelText: 'Invite code', border: OutlineInputBorder())),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _loading ? null : _join, child: const Text('Join')),
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
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await widget.api.inviteUserById(
        adminId: widget.user.id,
        groupId: widget.group.id,
        targetUserId: _userIdController.text.trim(),
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
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Invite by user ID', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _userIdController, decoration: const InputDecoration(labelText: 'User ID', border: OutlineInputBorder())),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _loading ? null : _invite, child: const Text('Invite')),
        ],
      ),
    );
  }
}
