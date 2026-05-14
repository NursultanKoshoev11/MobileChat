import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OfflineDemoApp());
}

class OfflineDemoApp extends StatelessWidget {
  const OfflineDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MobileChat Offline Demo',
      theme: MobileChatTheme.light,
      home: const OfflineRootScreen(),
    );
  }
}

class OfflineStore {
  static const _storage = FlutterSecureStorage();
  static const _sessionKey = 'offline_demo_session';
  static const _stateKey = 'offline_demo_state';

  Future<OfflineSession?> loadSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    return OfflineSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSession(OfflineSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
  }

  Future<OfflineState> loadState() async {
    final raw = await _storage.read(key: _stateKey);
    if (raw == null || raw.isEmpty) {
      final seeded = OfflineState.seed();
      await saveState(seeded);
      return seeded;
    }
    return OfflineState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveState(OfflineState state) async {
    await _storage.write(key: _stateKey, value: jsonEncode(state.toJson()));
  }

  Future<void> resetDemoData() async {
    await saveState(OfflineState.seed());
  }
}

class OfflineSession {
  const OfflineSession({required this.userId, required this.displayName, required this.mobile});

  final String userId;
  final String displayName;
  final String mobile;

  Map<String, dynamic> toJson() => {'user_id': userId, 'display_name': displayName, 'mobile': mobile};

  factory OfflineSession.fromJson(Map<String, dynamic> json) {
    return OfflineSession(
      userId: json['user_id'] as String? ?? 'LOCAL-USER',
      displayName: json['display_name'] as String? ?? 'Demo User',
      mobile: json['mobile'] as String? ?? '+996000000000',
    );
  }
}

class OfflineState {
  const OfflineState({required this.groups, required this.posts, required this.comments, required this.votes});

  final List<OfflineGroup> groups;
  final List<OfflinePost> posts;
  final List<OfflineComment> comments;
  final Map<String, String> votes;

  factory OfflineState.seed() {
    final now = DateTime.now();
    return OfflineState(
      groups: [
        OfflineGroup(id: 'G-GOV', title: 'City Announcements', description: 'Official city updates and public feedback.', visibility: 'public', myRole: 'owner', memberCount: 1240, createdAt: now),
        OfflineGroup(id: 'G-ROADS', title: 'Road Problems', description: 'Report road, traffic, and street light problems.', visibility: 'public', myRole: 'member', memberCount: 842, createdAt: now),
        OfflineGroup(id: 'G-SCHOOL', title: 'School Parents', description: 'Invite-only parent community.', visibility: 'private', myRole: 'admin', memberCount: 96, createdAt: now),
      ],
      posts: [
        OfflinePost(id: 'P-1', groupId: 'G-GOV', authorName: 'City Admin', requestType: 'announcement', interactionMode: 'read_only', title: 'Water maintenance notice', body: 'Water maintenance is planned tonight from 22:00 to 03:00. Please store enough water in advance.', status: 'new', createdAt: now.subtract(const Duration(hours: 2))),
        OfflinePost(id: 'P-2', groupId: 'G-GOV', authorName: 'Aibek', requestType: 'suggestion', interactionMode: 'vote_only', title: 'Add more trash bins near the park', body: 'The park gets crowded on weekends. More trash bins will keep the area cleaner.', status: 'under_review', supportCount: 18, opposeCount: 2, createdAt: now.subtract(const Duration(hours: 5))),
        OfflinePost(id: 'P-3', groupId: 'G-ROADS', authorName: 'Meerim', requestType: 'complaint', interactionMode: 'discussion', title: 'Broken street light near school', body: 'The street light near the school entrance is broken. It is difficult to walk there in the evening.', status: 'new', supportCount: 23, opposeCount: 1, commentCount: 2, createdAt: now.subtract(const Duration(days: 1))),
        OfflinePost(id: 'P-4', groupId: 'G-SCHOOL', authorName: 'Admin', requestType: 'announcement', interactionMode: 'discussion', title: 'Parent meeting on Friday', body: 'Please confirm whether you can attend the parent meeting this Friday at 18:00.', status: 'new', supportCount: 11, opposeCount: 0, commentCount: 1, createdAt: now.subtract(const Duration(days: 2))),
      ],
      comments: [
        OfflineComment(id: 'C-1', postId: 'P-3', authorName: 'Nursultan', body: 'I also saw this problem yesterday.', createdAt: now.subtract(const Duration(hours: 20))),
        OfflineComment(id: 'C-2', postId: 'P-3', authorName: 'City Admin', body: 'Thank you. We will check this location.', createdAt: now.subtract(const Duration(hours: 18))),
        OfflineComment(id: 'C-3', postId: 'P-4', authorName: 'Parent', body: 'I can attend.', createdAt: now.subtract(const Duration(hours: 8))),
      ],
      votes: {},
    );
  }

  Map<String, dynamic> toJson() => {
        'groups': groups.map((item) => item.toJson()).toList(),
        'posts': posts.map((item) => item.toJson()).toList(),
        'comments': comments.map((item) => item.toJson()).toList(),
        'votes': votes,
      };

  factory OfflineState.fromJson(Map<String, dynamic> json) {
    return OfflineState(
      groups: ((json['groups'] as List<dynamic>?) ?? []).map((item) => OfflineGroup.fromJson(item as Map<String, dynamic>)).toList(),
      posts: ((json['posts'] as List<dynamic>?) ?? []).map((item) => OfflinePost.fromJson(item as Map<String, dynamic>)).toList(),
      comments: ((json['comments'] as List<dynamic>?) ?? []).map((item) => OfflineComment.fromJson(item as Map<String, dynamic>)).toList(),
      votes: Map<String, String>.from(json['votes'] as Map? ?? {}),
    );
  }

  OfflineState copyWith({List<OfflineGroup>? groups, List<OfflinePost>? posts, List<OfflineComment>? comments, Map<String, String>? votes}) {
    return OfflineState(groups: groups ?? this.groups, posts: posts ?? this.posts, comments: comments ?? this.comments, votes: votes ?? this.votes);
  }
}

class OfflineGroup {
  const OfflineGroup({required this.id, required this.title, required this.description, required this.visibility, required this.myRole, required this.memberCount, required this.createdAt});
  final String id;
  final String title;
  final String description;
  final String visibility;
  final String myRole;
  final int memberCount;
  final DateTime createdAt;
  bool get isPublic => visibility == 'public';
  bool get canModerate => myRole == 'owner' || myRole == 'admin';
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'description': description, 'visibility': visibility, 'my_role': myRole, 'member_count': memberCount, 'created_at': createdAt.toIso8601String()};
  factory OfflineGroup.fromJson(Map<String, dynamic> json) => OfflineGroup(id: json['id'] as String, title: json['title'] as String, description: json['description'] as String? ?? '', visibility: json['visibility'] as String? ?? 'public', myRole: json['my_role'] as String? ?? 'member', memberCount: json['member_count'] as int? ?? 1, createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now());
}

class OfflinePost {
  const OfflinePost({required this.id, required this.groupId, required this.authorName, required this.requestType, required this.interactionMode, required this.title, required this.body, required this.status, required this.createdAt, this.supportCount = 0, this.opposeCount = 0, this.commentCount = 0, this.hidden = false});
  final String id;
  final String groupId;
  final String authorName;
  final String requestType;
  final String interactionMode;
  final String title;
  final String body;
  final String status;
  final int supportCount;
  final int opposeCount;
  final int commentCount;
  final bool hidden;
  final DateTime createdAt;
  bool get canVote => interactionMode != 'read_only';
  bool get canComment => interactionMode == 'discussion';
  Map<String, dynamic> toJson() => {'id': id, 'group_id': groupId, 'author_name': authorName, 'request_type': requestType, 'interaction_mode': interactionMode, 'title': title, 'body': body, 'status': status, 'support_count': supportCount, 'oppose_count': opposeCount, 'comment_count': commentCount, 'hidden': hidden, 'created_at': createdAt.toIso8601String()};
  factory OfflinePost.fromJson(Map<String, dynamic> json) => OfflinePost(id: json['id'] as String, groupId: json['group_id'] as String, authorName: json['author_name'] as String? ?? 'User', requestType: json['request_type'] as String? ?? 'idea', interactionMode: json['interaction_mode'] as String? ?? 'discussion', title: json['title'] as String? ?? '', body: json['body'] as String? ?? '', status: json['status'] as String? ?? 'new', supportCount: json['support_count'] as int? ?? 0, opposeCount: json['oppose_count'] as int? ?? 0, commentCount: json['comment_count'] as int? ?? 0, hidden: json['hidden'] as bool? ?? false, createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now());
  OfflinePost copyWith({String? status, int? supportCount, int? opposeCount, int? commentCount, bool? hidden}) => OfflinePost(id: id, groupId: groupId, authorName: authorName, requestType: requestType, interactionMode: interactionMode, title: title, body: body, status: status ?? this.status, supportCount: supportCount ?? this.supportCount, opposeCount: opposeCount ?? this.opposeCount, commentCount: commentCount ?? this.commentCount, hidden: hidden ?? this.hidden, createdAt: createdAt);
}

class OfflineComment {
  const OfflineComment({required this.id, required this.postId, required this.authorName, required this.body, required this.createdAt});
  final String id;
  final String postId;
  final String authorName;
  final String body;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => {'id': id, 'post_id': postId, 'author_name': authorName, 'body': body, 'created_at': createdAt.toIso8601String()};
  factory OfflineComment.fromJson(Map<String, dynamic> json) => OfflineComment(id: json['id'] as String, postId: json['post_id'] as String, authorName: json['author_name'] as String? ?? 'User', body: json['body'] as String? ?? '', createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now());
}

class OfflineRootScreen extends StatefulWidget {
  const OfflineRootScreen({super.key});
  @override
  State<OfflineRootScreen> createState() => _OfflineRootScreenState();
}

class _OfflineRootScreenState extends State<OfflineRootScreen> {
  final store = OfflineStore();
  late Future<OfflineSession?> sessionFuture;

  @override
  void initState() {
    super.initState();
    sessionFuture = store.loadSession();
  }

  Future<void> login(OfflineSession session) async {
    await store.saveSession(session);
    setState(() => sessionFuture = Future.value(session));
  }

  Future<void> logout() async {
    await store.clearSession();
    setState(() => sessionFuture = Future.value(null));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OfflineSession?>(
      future: sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final session = snapshot.data;
        if (session == null) return OfflineLoginScreen(onLogin: login);
        return OfflineGroupsScreen(store: store, session: session, onLogout: logout);
      },
    );
  }
}

class OfflineLoginScreen extends StatefulWidget {
  const OfflineLoginScreen({super.key, required this.onLogin});
  final Future<void> Function(OfflineSession session) onLogin;
  @override
  State<OfflineLoginScreen> createState() => _OfflineLoginScreenState();
}

class _OfflineLoginScreenState extends State<OfflineLoginScreen> {
  final mobileController = TextEditingController(text: '+996');
  final nameController = TextEditingController(text: 'Demo User');

  @override
  void dispose() {
    mobileController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> enter() async {
    final mobile = mobileController.text.trim().isEmpty ? '+996000000000' : mobileController.text.trim();
    final name = nameController.text.trim().isEmpty ? 'Demo User' : nameController.text.trim();
    await widget.onLogin(OfflineSession(userId: 'LOCAL-${mobile.hashCode.abs()}', displayName: name, mobile: mobile));
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 16))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const CircleAvatar(radius: 42, backgroundColor: MobileChatTheme.primary, child: Icon(Icons.wifi_off_rounded, color: Colors.white, size: 40)),
                  const SizedBox(height: 22),
                  Text('Offline Demo', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('No internet. No server. Enter a phone number and open the local demo immediately.', textAlign: TextAlign.center, style: TextStyle(color: MobileChatTheme.textMuted)),
                  const SizedBox(height: 24),
                  TextField(controller: mobileController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_iphone_rounded))),
                  const SizedBox(height: 12),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Display name', prefixIcon: Icon(Icons.person_outline_rounded))),
                  const SizedBox(height: 18),
                  FilledButton.icon(onPressed: enter, icon: const Icon(Icons.login_rounded), label: const Text('Enter offline demo')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OfflineGroupsScreen extends StatefulWidget {
  const OfflineGroupsScreen({super.key, required this.store, required this.session, required this.onLogout});
  final OfflineStore store;
  final OfflineSession session;
  final Future<void> Function() onLogout;
  @override
  State<OfflineGroupsScreen> createState() => _OfflineGroupsScreenState();
}

class _OfflineGroupsScreenState extends State<OfflineGroupsScreen> {
  late Future<OfflineState> stateFuture;
  String query = '';

  @override
  void initState() {
    super.initState();
    stateFuture = widget.store.loadState();
  }

  Future<void> refresh() async => setState(() => stateFuture = widget.store.loadState());

  Future<void> reset() async {
    await widget.store.resetDemoData();
    await refresh();
  }

  Future<void> createGroup(OfflineState state) async {
    final created = await showModalBottomSheet<OfflineGroup>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => const CreateGroupSheet());
    if (created == null) return;
    await widget.store.saveState(state.copyWith(groups: [created, ...state.groups]));
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groups'), actions: [IconButton(onPressed: reset, icon: const Icon(Icons.restart_alt_rounded), tooltip: 'Reset demo data'), IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout_rounded), tooltip: 'Log out')]),
      body: FutureBuilder<OfflineState>(
        future: stateFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final state = snapshot.data!;
          final groups = state.groups.where((g) => query.isEmpty || g.title.toLowerCase().contains(query.toLowerCase()) || g.description.toLowerCase().contains(query.toLowerCase())).toList();
          return Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search public and private groups'))),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: groups.length,
                  itemBuilder: (context, index) => OfflineGroupTile(
                    group: groups[index],
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OfflinePostsScreen(store: widget.store, session: widget.session, group: groups[index])));
                      await refresh();
                    },
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
      floatingActionButton: FutureBuilder<OfflineState>(future: stateFuture, builder: (context, snapshot) => FloatingActionButton.extended(onPressed: snapshot.hasData ? () => createGroup(snapshot.data!) : null, icon: const Icon(Icons.add_rounded), label: const Text('New group'))),
    );
  }
}

class OfflineGroupTile extends StatelessWidget {
  const OfflineGroupTile({super.key, required this.group, required this.onTap});
  final OfflineGroup group;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                CircleAvatar(radius: 26, backgroundColor: group.isPublic ? MobileChatTheme.primary : MobileChatTheme.primaryDark, child: Text(group.title.substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 4), Text(group.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: MobileChatTheme.textMuted)), const SizedBox(height: 8), Text('${group.isPublic ? 'Public' : 'Invite only'} · ${group.memberCount} members · ${group.myRole}', style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w700, fontSize: 12))])),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
        ),
      );
}

class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({super.key});
  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  final title = TextEditingController();
  final desc = TextEditingController();
  String visibility = 'public';
  @override
  void dispose() { title.dispose(); desc.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Create local group', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 16),
      TextField(controller: title, decoration: const InputDecoration(labelText: 'Group name')), const SizedBox(height: 12),
      TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')), const SizedBox(height: 12),
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'public', label: Text('Public')), ButtonSegment(value: 'private', label: Text('Invite only'))], selected: {visibility}, onSelectionChanged: (v) => setState(() => visibility = v.first)),
      const SizedBox(height: 16), FilledButton(onPressed: () => Navigator.of(context).pop(OfflineGroup(id: 'G-${DateTime.now().microsecondsSinceEpoch}', title: title.text.trim().isEmpty ? 'New local group' : title.text.trim(), description: desc.text.trim(), visibility: visibility, myRole: 'owner', memberCount: 1, createdAt: DateTime.now())), child: const Text('Create')),
    ]),
  );
}

class OfflinePostsScreen extends StatefulWidget {
  const OfflinePostsScreen({super.key, required this.store, required this.session, required this.group});
  final OfflineStore store;
  final OfflineSession session;
  final OfflineGroup group;
  @override
  State<OfflinePostsScreen> createState() => _OfflinePostsScreenState();
}

class _OfflinePostsScreenState extends State<OfflinePostsScreen> {
  late Future<OfflineState> stateFuture;
  String filter = 'newest';
  @override
  void initState() { super.initState(); stateFuture = widget.store.loadState(); }
  Future<void> refresh() async => setState(() => stateFuture = widget.store.loadState());
  Future<void> save(OfflineState state) async { await widget.store.saveState(state); await refresh(); }

  List<OfflinePost> filtered(OfflineState state) {
    final posts = state.posts.where((p) => p.groupId == widget.group.id && !p.hidden).toList();
    if (filter == 'popular') posts.sort((a, b) => (b.supportCount - b.opposeCount).compareTo(a.supportCount - a.opposeCount));
    else if (filter == 'resolved') posts.retainWhere((p) => p.status == 'resolved' || p.status == 'accepted');
    else posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  Future<void> createPost(OfflineState state) async {
    final post = await showModalBottomSheet<OfflinePost>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => CreatePostSheet(groupId: widget.group.id, authorName: widget.session.displayName, canAnnouncement: widget.group.canModerate));
    if (post == null) return;
    await save(state.copyWith(posts: [post, ...state.posts]));
  }

  Future<void> vote(OfflineState state, OfflinePost post, String voteType) async {
    if (!post.canVote) return;
    final votes = Map<String, String>.from(state.votes);
    final previous = votes[post.id];
    var support = post.supportCount;
    var oppose = post.opposeCount;
    if (previous == voteType) { votes.remove(post.id); if (voteType == 'support') support--; else oppose--; }
    else { if (previous == 'support') support--; if (previous == 'oppose') oppose--; votes[post.id] = voteType; if (voteType == 'support') support++; else oppose++; }
    final posts = state.posts.map((p) => p.id == post.id ? p.copyWith(supportCount: support < 0 ? 0 : support, opposeCount: oppose < 0 ? 0 : oppose) : p).toList();
    await save(state.copyWith(posts: posts, votes: votes));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.group.title)),
    body: FutureBuilder<OfflineState>(future: stateFuture, builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final state = snapshot.data!;
      final posts = filtered(state);
      return Column(children: [
        SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), scrollDirection: Axis.horizontal, child: SegmentedButton<String>(segments: const [ButtonSegment(value: 'newest', label: Text('Newest')), ButtonSegment(value: 'popular', label: Text('Popular')), ButtonSegment(value: 'resolved', label: Text('Resolved'))], selected: {filter}, onSelectionChanged: (v) => setState(() => filter = v.first))),
        Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), itemCount: posts.length, itemBuilder: (context, index) {
          final post = posts[index];
          return OfflinePostCard(post: post, myVote: state.votes[post.id], onRead: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OfflinePostDetailsScreen(store: widget.store, session: widget.session, group: widget.group, postId: post.id))); await refresh(); }, onSupport: post.canVote ? () => vote(state, post, 'support') : null, onOppose: post.canVote ? () => vote(state, post, 'oppose') : null);
        })),
      ]);
    }),
    floatingActionButton: FutureBuilder<OfflineState>(future: stateFuture, builder: (context, snapshot) => FloatingActionButton.extended(onPressed: snapshot.hasData ? () => createPost(snapshot.data!) : null, icon: const Icon(Icons.add_rounded), label: const Text('New post'))),
  );
}

class CreatePostSheet extends StatefulWidget {
  const CreatePostSheet({super.key, required this.groupId, required this.authorName, required this.canAnnouncement});
  final String groupId; final String authorName; final bool canAnnouncement;
  @override State<CreatePostSheet> createState() => _CreatePostSheetState();
}
class _CreatePostSheetState extends State<CreatePostSheet> {
  final title = TextEditingController(); final body = TextEditingController(); String type = 'suggestion'; String mode = 'discussion';
  @override void initState() { super.initState(); if (widget.canAnnouncement) type = 'announcement'; }
  @override void dispose() { title.dispose(); body.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('New local post', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 16),
    DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Post type'), items: [if (widget.canAnnouncement) const DropdownMenuItem(value: 'announcement', child: Text('Announcement')), const DropdownMenuItem(value: 'suggestion', child: Text('Suggestion')), const DropdownMenuItem(value: 'complaint', child: Text('Complaint')), const DropdownMenuItem(value: 'requirement', child: Text('Requirement')), const DropdownMenuItem(value: 'problem', child: Text('Problem')), const DropdownMenuItem(value: 'idea', child: Text('Idea'))], onChanged: (v) => setState(() => type = v ?? 'suggestion')), const SizedBox(height: 12),
    DropdownButtonFormField<String>(value: mode, decoration: const InputDecoration(labelText: 'Interaction mode'), items: const [DropdownMenuItem(value: 'read_only', child: Text('Text only')), DropdownMenuItem(value: 'vote_only', child: Text('Voting only')), DropdownMenuItem(value: 'discussion', child: Text('Discussion with comments'))], onChanged: (v) => setState(() => mode = v ?? 'discussion')), const SizedBox(height: 12),
    TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')), const SizedBox(height: 12),
    TextField(controller: body, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Description')), const SizedBox(height: 16),
    FilledButton(onPressed: () => Navigator.of(context).pop(OfflinePost(id: 'P-${DateTime.now().microsecondsSinceEpoch}', groupId: widget.groupId, authorName: widget.authorName, requestType: type, interactionMode: mode, title: title.text.trim().isEmpty ? 'New local post' : title.text.trim(), body: body.text.trim().isEmpty ? 'Local demo description.' : body.text.trim(), status: 'new', createdAt: DateTime.now())), child: const Text('Publish locally')),
  ])));
}

class OfflinePostCard extends StatelessWidget {
  const OfflinePostCard({super.key, required this.post, required this.myVote, required this.onRead, this.onSupport, this.onOppose});
  final OfflinePost post; final String? myVote; final VoidCallback onRead; final VoidCallback? onSupport; final VoidCallback? onOppose;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Material(color: Colors.white, borderRadius: BorderRadius.circular(22), child: InkWell(onTap: onRead, borderRadius: BorderRadius.circular(22), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [ChipLabel(text: post.requestType), const SizedBox(width: 8), ChipLabel(text: modeLabel(post.interactionMode)), const Spacer(), Text(post.status, style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700))]),
    const SizedBox(height: 10), Text(post.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(post.body, maxLines: 3, overflow: TextOverflow.ellipsis), const SizedBox(height: 10), Text('By ${post.authorName}', style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12)), const SizedBox(height: 12),
    Row(children: [FilledButton.tonal(onPressed: onRead, child: const Text('Read')), const SizedBox(width: 8), if (post.canVote) ...[OutlinedButton.icon(onPressed: onSupport, icon: Icon(myVote == 'support' ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined), label: Text('${post.supportCount}')), const SizedBox(width: 8), OutlinedButton.icon(onPressed: onOppose, icon: Icon(myVote == 'oppose' ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined), label: Text('${post.opposeCount}'))], const Spacer(), if (post.canComment) Text('${post.commentCount} comments', style: const TextStyle(color: MobileChatTheme.textMuted))]),
  ])))));
  String modeLabel(String value) => value == 'read_only' ? 'Read only' : value == 'vote_only' ? 'Vote only' : 'Discussion';
}

class OfflinePostDetailsScreen extends StatefulWidget {
  const OfflinePostDetailsScreen({super.key, required this.store, required this.session, required this.group, required this.postId});
  final OfflineStore store; final OfflineSession session; final OfflineGroup group; final String postId;
  @override State<OfflinePostDetailsScreen> createState() => _OfflinePostDetailsScreenState();
}
class _OfflinePostDetailsScreenState extends State<OfflinePostDetailsScreen> {
  final comment = TextEditingController(); late Future<OfflineState> stateFuture;
  @override void initState() { super.initState(); stateFuture = widget.store.loadState(); }
  @override void dispose() { comment.dispose(); super.dispose(); }
  Future<void> save(OfflineState state) async { await widget.store.saveState(state); setState(() => stateFuture = widget.store.loadState()); }
  Future<void> addComment(OfflineState state, OfflinePost post) async { final text = comment.text.trim(); if (text.isEmpty || !post.canComment) return; comment.clear(); final comments = [...state.comments, OfflineComment(id: 'C-${DateTime.now().microsecondsSinceEpoch}', postId: post.id, authorName: widget.session.displayName, body: text, createdAt: DateTime.now())]; final posts = state.posts.map((p) => p.id == post.id ? p.copyWith(commentCount: p.commentCount + 1) : p).toList(); await save(state.copyWith(posts: posts, comments: comments)); }
  Future<void> hide(OfflineState state, OfflinePost post) async { final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Hide post?'), content: const Text('This local post will disappear from the feed.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hide'))])); if (ok != true) return; await widget.store.saveState(state.copyWith(posts: state.posts.map((p) => p.id == post.id ? p.copyWith(hidden: true) : p).toList())); if (mounted) Navigator.of(context).pop(); }
  Future<void> status(OfflineState state, OfflinePost post, String value) async => save(state.copyWith(posts: state.posts.map((p) => p.id == post.id ? p.copyWith(status: value) : p).toList()));
  @override Widget build(BuildContext context) => FutureBuilder<OfflineState>(future: stateFuture, builder: (context, snapshot) {
    if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final state = snapshot.data!; final post = state.posts.firstWhere((p) => p.id == widget.postId); final comments = state.comments.where((c) => c.postId == post.id).toList();
    return Scaffold(appBar: AppBar(title: const Text('Read post'), actions: [if (widget.group.canModerate) IconButton(onPressed: () => hide(state, post), icon: const Icon(Icons.visibility_off_outlined))]), body: Column(children: [Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [OfflinePostCard(post: post, myVote: state.votes[post.id], onRead: () {}, onSupport: null, onOppose: null), if (widget.group.canModerate) ...[DropdownButtonFormField<String>(value: post.status, decoration: const InputDecoration(labelText: 'Admin status'), items: const [DropdownMenuItem(value: 'new', child: Text('New')), DropdownMenuItem(value: 'under_review', child: Text('Under review')), DropdownMenuItem(value: 'accepted', child: Text('Accepted')), DropdownMenuItem(value: 'rejected', child: Text('Rejected')), DropdownMenuItem(value: 'resolved', child: Text('Resolved'))], onChanged: (v) { if (v != null) status(state, post, v); })], const SizedBox(height: 12), if (post.interactionMode == 'read_only') const Text('This post is read-only.', style: TextStyle(color: MobileChatTheme.textMuted)) else if (post.interactionMode == 'vote_only') const Text('This post accepts votes only. Comments are disabled.', style: TextStyle(color: MobileChatTheme.textMuted)) else ...[Text('Comments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8), if (comments.isEmpty) const Text('No comments yet.', style: TextStyle(color: MobileChatTheme.textMuted)), ...comments.map((c) => ListTile(contentPadding: EdgeInsets.zero, title: Text(c.authorName, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(c.body)))]])), if (post.canComment) SafeArea(top: false, child: Container(padding: const EdgeInsets.all(10), color: Colors.white, child: Row(children: [Expanded(child: TextField(controller: comment, decoration: const InputDecoration(hintText: 'Add local comment'))), const SizedBox(width: 8), IconButton.filled(onPressed: () => addComment(state, post), icon: const Icon(Icons.send_rounded))])))]));
  });
}

class ChipLabel extends StatelessWidget {
  const ChipLabel({super.key, required this.text});
  final String text;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)), child: Text(text, style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800, fontSize: 12)));
}
