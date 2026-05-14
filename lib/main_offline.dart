import 'package:flutter/material.dart';

import 'app/theme.dart';

void main() {
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
      home: const OfflineLoginScreen(),
    );
  }
}

class DemoStore extends ChangeNotifier {
  String displayName = 'Demo User';

  final List<DemoGroup> groups = [
    DemoGroup(id: 'g-city', title: 'City Announcements', description: 'Official city updates and public feedback.', visibility: 'public', role: 'owner', members: 1240),
    DemoGroup(id: 'g-road', title: 'Road Problems', description: 'Report road, traffic, and street light problems.', visibility: 'public', role: 'member', members: 842),
    DemoGroup(id: 'g-school', title: 'School Parents', description: 'Invite-only parent community.', visibility: 'private', role: 'admin', members: 96),
  ];

  final List<DemoPost> posts = [
    DemoPost(id: 'p-water', groupId: 'g-city', author: 'City Admin', type: 'announcement', mode: 'read_only', title: 'Water maintenance notice', body: 'Water maintenance is planned tonight from 22:00 to 03:00. Please store enough water in advance.', status: 'new'),
    DemoPost(id: 'p-bins', groupId: 'g-city', author: 'Aibek', type: 'suggestion', mode: 'vote_only', title: 'Add more trash bins near the park', body: 'The park gets crowded on weekends. More trash bins will keep the area cleaner.', status: 'under_review', support: 18, oppose: 2),
    DemoPost(id: 'p-light', groupId: 'g-road', author: 'Meerim', type: 'complaint', mode: 'discussion', title: 'Broken street light near school', body: 'The street light near the school entrance is broken. It is difficult to walk there in the evening.', status: 'new', support: 23, oppose: 1),
    DemoPost(id: 'p-meeting', groupId: 'g-school', author: 'Admin', type: 'announcement', mode: 'discussion', title: 'Parent meeting on Friday', body: 'Please confirm whether you can attend the parent meeting this Friday at 18:00.', status: 'new', support: 11),
  ];

  final List<DemoComment> comments = [
    DemoComment(postId: 'p-light', author: 'Nursultan', body: 'I also saw this problem yesterday.'),
    DemoComment(postId: 'p-light', author: 'City Admin', body: 'Thank you. We will check this location.'),
    DemoComment(postId: 'p-meeting', author: 'Parent', body: 'I can attend.'),
  ];

  final Map<String, String> votes = {};

  void login(String name) {
    displayName = name.trim().isEmpty ? 'Demo User' : name.trim();
    notifyListeners();
  }

  void createGroup(String title, String description, String visibility) {
    groups.insert(0, DemoGroup(id: 'g-${DateTime.now().microsecondsSinceEpoch}', title: title.trim().isEmpty ? 'New local group' : title.trim(), description: description.trim(), visibility: visibility, role: 'owner', members: 1));
    notifyListeners();
  }

  void createPost(String groupId, String type, String mode, String title, String body) {
    posts.insert(0, DemoPost(id: 'p-${DateTime.now().microsecondsSinceEpoch}', groupId: groupId, author: displayName, type: type, mode: mode, title: title.trim().isEmpty ? 'New local post' : title.trim(), body: body.trim().isEmpty ? 'Local demo description.' : body.trim(), status: 'new'));
    notifyListeners();
  }

  void vote(DemoPost post, String value) {
    if (!post.canVote) return;
    final old = votes[post.id];
    if (old == value) {
      votes.remove(post.id);
      if (value == 'support' && post.support > 0) post.support--;
      if (value == 'oppose' && post.oppose > 0) post.oppose--;
    } else {
      if (old == 'support' && post.support > 0) post.support--;
      if (old == 'oppose' && post.oppose > 0) post.oppose--;
      votes[post.id] = value;
      if (value == 'support') post.support++;
      if (value == 'oppose') post.oppose++;
    }
    notifyListeners();
  }

  void addComment(DemoPost post, String body) {
    if (!post.canComment || body.trim().isEmpty) return;
    comments.add(DemoComment(postId: post.id, author: displayName, body: body.trim()));
    notifyListeners();
  }

  void updateStatus(DemoPost post, String status) {
    post.status = status;
    notifyListeners();
  }

  void hidePost(DemoPost post) {
    post.hidden = true;
    notifyListeners();
  }

  void reset() {
    for (final post in posts) {
      post.hidden = false;
    }
    votes.clear();
    notifyListeners();
  }
}

final demo = DemoStore();

class DemoGroup {
  DemoGroup({required this.id, required this.title, required this.description, required this.visibility, required this.role, required this.members});
  final String id;
  final String title;
  final String description;
  final String visibility;
  final String role;
  final int members;
  bool get isPublic => visibility == 'public';
  bool get canModerate => role == 'owner' || role == 'admin';
}

class DemoPost {
  DemoPost({required this.id, required this.groupId, required this.author, required this.type, required this.mode, required this.title, required this.body, required this.status, this.support = 0, this.oppose = 0, this.hidden = false});
  final String id;
  final String groupId;
  final String author;
  final String type;
  final String mode;
  final String title;
  final String body;
  String status;
  int support;
  int oppose;
  bool hidden;
  bool get canVote => mode != 'read_only';
  bool get canComment => mode == 'discussion';
}

class DemoComment {
  DemoComment({required this.postId, required this.author, required this.body});
  final String postId;
  final String author;
  final String body;
}

class OfflineLoginScreen extends StatefulWidget {
  const OfflineLoginScreen({super.key});

  @override
  State<OfflineLoginScreen> createState() => _OfflineLoginScreenState();
}

class _OfflineLoginScreenState extends State<OfflineLoginScreen> {
  final phone = TextEditingController(text: '+996');
  final name = TextEditingController(text: 'Demo User');

  @override
  void dispose() {
    phone.dispose();
    name.dispose();
    super.dispose();
  }

  void enterDemo() {
    demo.login(name.text);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GroupsScreen()));
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
                  TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_iphone_rounded))),
                  const SizedBox(height: 12),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Display name', prefixIcon: Icon(Icons.person_outline_rounded))),
                  const SizedBox(height: 18),
                  FilledButton.icon(onPressed: enterDemo, icon: const Icon(Icons.login_rounded), label: const Text('Enter offline demo')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  String query = '';

  @override
  void initState() {
    super.initState();
    demo.addListener(refresh);
  }

  @override
  void dispose() {
    demo.removeListener(refresh);
    super.dispose();
  }

  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final groups = demo.groups.where((g) => query.isEmpty || g.title.toLowerCase().contains(query.toLowerCase()) || g.description.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Groups'), actions: [IconButton(onPressed: demo.reset, icon: const Icon(Icons.restart_alt_rounded)), IconButton(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OfflineLoginScreen())), icon: const Icon(Icons.logout_rounded))]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: TextField(onChanged: (value) => setState(() => query = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search groups'))),
        Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), itemCount: groups.length, itemBuilder: (_, index) => GroupTile(group: groups[index]))),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: createGroup, icon: const Icon(Icons.add_rounded), label: const Text('New group')),
    );
  }

  Future<void> createGroup() async {
    final title = TextEditingController();
    final description = TextEditingController();
    String visibility = 'public';
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (context) => StatefulBuilder(builder: (context, setSheetState) {
      return Padding(
        padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Create local group', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Group name')),
          const SizedBox(height: 12),
          TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 12),
          SegmentedButton<String>(segments: const [ButtonSegment(value: 'public', label: Text('Public')), ButtonSegment(value: 'private', label: Text('Invite only'))], selected: {visibility}, onSelectionChanged: (value) => setSheetState(() => visibility = value.first)),
          const SizedBox(height: 16),
          FilledButton(onPressed: () { demo.createGroup(title.text, description.text, visibility); Navigator.pop(context); }, child: const Text('Create')),
        ]),
      );
    }));
    title.dispose();
    description.dispose();
  }
}

class GroupTile extends StatelessWidget {
  const GroupTile({super.key, required this.group});
  final DemoGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostsScreen(group: group))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(radius: 26, backgroundColor: group.isPublic ? MobileChatTheme.primary : MobileChatTheme.primaryDark, child: Text(group.title.substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(group.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: MobileChatTheme.textMuted)),
                const SizedBox(height: 8),
                Text('${group.isPublic ? 'Public' : 'Invite only'} · ${group.members} members · ${group.role}', style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w700, fontSize: 12)),
              ])),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        ),
      ),
    );
  }
}

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key, required this.group});
  final DemoGroup group;

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  String filter = 'newest';

  @override
  void initState() {
    super.initState();
    demo.addListener(refresh);
  }

  @override
  void dispose() {
    demo.removeListener(refresh);
    super.dispose();
  }

  void refresh() => setState(() {});

  List<DemoPost> get posts {
    final list = demo.posts.where((p) => p.groupId == widget.group.id && !p.hidden).toList();
    if (filter == 'popular') list.sort((a, b) => (b.support - b.oppose).compareTo(a.support - a.oppose));
    if (filter == 'resolved') list.retainWhere((p) => p.status == 'resolved' || p.status == 'accepted');
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.title)),
      body: Column(children: [
        SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), scrollDirection: Axis.horizontal, child: SegmentedButton<String>(segments: const [ButtonSegment(value: 'newest', label: Text('Newest')), ButtonSegment(value: 'popular', label: Text('Popular')), ButtonSegment(value: 'resolved', label: Text('Resolved'))], selected: {filter}, onSelectionChanged: (value) => setState(() => filter = value.first))),
        Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), itemCount: posts.length, itemBuilder: (_, index) => PostCard(post: posts[index], group: widget.group))),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: createPost, icon: const Icon(Icons.add_rounded), label: const Text('New post')),
    );
  }

  Future<void> createPost() async {
    final title = TextEditingController();
    final body = TextEditingController();
    String type = widget.group.canModerate ? 'announcement' : 'suggestion';
    String mode = 'discussion';
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (context) => StatefulBuilder(builder: (context, setSheetState) {
      return Padding(
        padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('New local post', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Post type'), items: [if (widget.group.canModerate) const DropdownMenuItem(value: 'announcement', child: Text('Announcement')), const DropdownMenuItem(value: 'suggestion', child: Text('Suggestion')), const DropdownMenuItem(value: 'complaint', child: Text('Complaint')), const DropdownMenuItem(value: 'requirement', child: Text('Requirement')), const DropdownMenuItem(value: 'problem', child: Text('Problem')), const DropdownMenuItem(value: 'idea', child: Text('Idea'))], onChanged: (value) => setSheetState(() => type = value ?? 'suggestion')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: mode, decoration: const InputDecoration(labelText: 'Interaction mode'), items: const [DropdownMenuItem(value: 'read_only', child: Text('Text only')), DropdownMenuItem(value: 'vote_only', child: Text('Voting only')), DropdownMenuItem(value: 'discussion', child: Text('Discussion with comments'))], onChanged: (value) => setSheetState(() => mode = value ?? 'discussion')),
          const SizedBox(height: 12),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: body, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 16),
          FilledButton(onPressed: () { demo.createPost(widget.group.id, type, mode, title.text, body.text); Navigator.pop(context); }, child: const Text('Publish locally')),
        ])),
      );
    }));
    title.dispose();
    body.dispose();
  }
}

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, required this.group});
  final DemoPost post;
  final DemoGroup group;

  @override
  Widget build(BuildContext context) {
    final myVote = demo.votes[post.id];
    final commentCount = demo.comments.where((c) => c.postId == post.id).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsScreen(post: post, group: group))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [ChipLabel(text: post.type), const SizedBox(width: 8), ChipLabel(text: post.mode == 'read_only' ? 'Read only' : post.mode == 'vote_only' ? 'Vote only' : 'Discussion'), const Spacer(), Text(post.status, style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700))]),
              const SizedBox(height: 10),
              Text(post.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(post.body, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Text('By ${post.author}', style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              Row(children: [FilledButton.tonal(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsScreen(post: post, group: group))), child: const Text('Read')), const SizedBox(width: 8), if (post.canVote) ...[OutlinedButton.icon(onPressed: () => demo.vote(post, 'support'), icon: Icon(myVote == 'support' ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined), label: Text('${post.support}')), const SizedBox(width: 8), OutlinedButton.icon(onPressed: () => demo.vote(post, 'oppose'), icon: Icon(myVote == 'oppose' ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined), label: Text('${post.oppose}'))], const Spacer(), if (post.canComment) Text('$commentCount comments', style: const TextStyle(color: MobileChatTheme.textMuted))]),
            ]),
          ),
        ),
      ),
    );
  }
}

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key, required this.post, required this.group});
  final DemoPost post;
  final DemoGroup group;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    demo.addListener(refresh);
  }

  @override
  void dispose() {
    demo.removeListener(refresh);
    comment.dispose();
    super.dispose();
  }

  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final comments = demo.comments.where((c) => c.postId == widget.post.id).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Read post'), actions: [if (widget.group.canModerate) IconButton(onPressed: () { demo.hidePost(widget.post); Navigator.pop(context); }, icon: const Icon(Icons.visibility_off_outlined))]),
      body: Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          PostCard(post: widget.post, group: widget.group),
          if (widget.group.canModerate) DropdownButtonFormField<String>(value: widget.post.status, decoration: const InputDecoration(labelText: 'Admin status'), items: const [DropdownMenuItem(value: 'new', child: Text('New')), DropdownMenuItem(value: 'under_review', child: Text('Under review')), DropdownMenuItem(value: 'accepted', child: Text('Accepted')), DropdownMenuItem(value: 'rejected', child: Text('Rejected')), DropdownMenuItem(value: 'resolved', child: Text('Resolved'))], onChanged: (value) { if (value != null) demo.updateStatus(widget.post, value); }),
          const SizedBox(height: 12),
          if (widget.post.mode == 'read_only') const Text('This post is read-only.', style: TextStyle(color: MobileChatTheme.textMuted)) else if (widget.post.mode == 'vote_only') const Text('This post accepts votes only. Comments are disabled.', style: TextStyle(color: MobileChatTheme.textMuted)) else ...[Text('Comments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8), if (comments.isEmpty) const Text('No comments yet.', style: TextStyle(color: MobileChatTheme.textMuted)), ...comments.map((c) => ListTile(contentPadding: EdgeInsets.zero, title: Text(c.author, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(c.body)))],
        ])),
        if (widget.post.canComment) SafeArea(top: false, child: Container(padding: const EdgeInsets.all(10), color: Colors.white, child: Row(children: [Expanded(child: TextField(controller: comment, decoration: const InputDecoration(hintText: 'Add local comment'))), const SizedBox(width: 8), IconButton.filled(onPressed: () { demo.addComment(widget.post, comment.text); comment.clear(); }, icon: const Icon(Icons.send_rounded))]))),
      ]),
    );
  }
}

class ChipLabel extends StatelessWidget {
  const ChipLabel({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)), child: Text(text, style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800, fontSize: 12)));
  }
}
