import 'package:flutter/material.dart';

import 'app/theme.dart';

const String adminDemoPhone = '+996000000000';
const String adminDemoPhoneDigits = '996000000000';
const String demoOtpCode = '1111';

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

final demo = DemoStore();

enum DemoRole { user, admin }

enum PostMode { readOnly, voteOnly, discussion }

extension PostModeText on PostMode {
  String get label {
    switch (this) {
      case PostMode.readOnly:
        return 'Text only';
      case PostMode.voteOnly:
        return 'Voting only';
      case PostMode.discussion:
        return 'Discussion';
    }
  }
}

class DemoStore extends ChangeNotifier {
  String currentPhone = '+996555000111';
  String currentName = 'Demo User';
  DemoRole role = DemoRole.user;

  final List<DemoGroup> groups = [
    DemoGroup(id: 'g-city', title: 'City Announcements', description: 'Official city updates and public feedback.', visibility: 'public', role: 'owner', members: 1240),
    DemoGroup(id: 'g-road', title: 'Road Problems', description: 'Report road, traffic, and street light problems.', visibility: 'public', role: 'member', members: 842),
    DemoGroup(id: 'g-school', title: 'School Parents', description: 'Invite-only parent community.', visibility: 'private', role: 'admin', members: 96),
  ];

  final List<GroupCreationRequest> groupRequests = [
    GroupCreationRequest(
      id: 'r-demo-1',
      applicantName: 'Bakyt Asanov',
      position: 'Deputy mayor',
      organizationName: 'Tokmok City Hall',
      organizationType: 'City government',
      region: 'Tokmok',
      officialPhone: '+996312000000',
      officialEmail: 'info@tokmok.gov.kg',
      website: 'tokmok.gov.kg',
      groupTitle: 'Tokmok City Announcements',
      groupDescription: 'Official announcements and public feedback for Tokmok residents.',
      reason: 'We need one verified channel for city announcements, citizen proposals, complaints, and voting.',
      documents: 'Official letter, staff ID, city hall seal',
      status: RequestStatus.pending,
      createdByPhone: '+996555000111',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];

  final List<DemoPost> posts = [
    DemoPost(id: 'p-water', groupId: 'g-city', author: 'City Admin', type: 'announcement', mode: PostMode.readOnly, title: 'Water maintenance notice', body: 'Water maintenance is planned tonight from 22:00 to 03:00. Please store enough water in advance.', status: 'new'),
    DemoPost(id: 'p-bins', groupId: 'g-city', author: 'Aibek', type: 'suggestion', mode: PostMode.voteOnly, title: 'Add more trash bins near the park', body: 'The park gets crowded on weekends. More trash bins will keep the area cleaner.', status: 'under_review', support: 18, oppose: 2),
    DemoPost(id: 'p-light', groupId: 'g-road', author: 'Meerim', type: 'complaint', mode: PostMode.discussion, title: 'Broken street light near school', body: 'The street light near the school entrance is broken. It is difficult to walk there in the evening.', status: 'new', support: 23, oppose: 1),
    DemoPost(id: 'p-meeting', groupId: 'g-school', author: 'Admin', type: 'announcement', mode: PostMode.discussion, title: 'Parent meeting on Friday', body: 'Please confirm whether you can attend the parent meeting this Friday at 18:00.', status: 'new', support: 11),
  ];

  final List<DemoComment> comments = [
    DemoComment(postId: 'p-light', author: 'Nursultan', body: 'I also saw this problem yesterday.'),
    DemoComment(postId: 'p-light', author: 'City Admin', body: 'Thank you. We will check this location.'),
    DemoComment(postId: 'p-meeting', author: 'Parent', body: 'I can attend.'),
  ];

  final Map<String, String> votes = {};

  void login({required String phone, required String name, required DemoRole nextRole}) {
    currentPhone = phone.trim().isEmpty ? '+996555000111' : phone.trim();
    currentName = name.trim().isEmpty ? 'Demo User' : name.trim();
    role = nextRole;
    notifyListeners();
  }

  void logout() {
    role = DemoRole.user;
    currentPhone = '+996555000111';
    currentName = 'Demo User';
    notifyListeners();
  }

  void submitGroupRequest(GroupCreationRequest request) {
    groupRequests.insert(0, request);
    notifyListeners();
  }

  void approveRequest(GroupCreationRequest request) {
    if (request.status == RequestStatus.approved) return;
    request.status = RequestStatus.approved;
    request.adminComment = 'Approved in offline demo.';
    request.reviewedAt = DateTime.now();
    groups.insert(
      0,
      DemoGroup(
        id: 'g-${DateTime.now().microsecondsSinceEpoch}',
        title: request.groupTitle,
        description: request.groupDescription,
        visibility: 'public',
        role: 'owner',
        members: 1,
      ),
    );
    notifyListeners();
  }

  void rejectRequest(GroupCreationRequest request, String reason) {
    request.status = RequestStatus.rejected;
    request.adminComment = reason.trim().isEmpty ? 'Rejected in offline demo.' : reason.trim();
    request.reviewedAt = DateTime.now();
    notifyListeners();
  }

  void needMoreInfo(GroupCreationRequest request, String reason) {
    request.status = RequestStatus.needsMoreInfo;
    request.adminComment = reason.trim().isEmpty ? 'Please add more documents.' : reason.trim();
    request.reviewedAt = DateTime.now();
    notifyListeners();
  }

  void createPost({required String groupId, required String type, required PostMode mode, required String title, required String body}) {
    posts.insert(
      0,
      DemoPost(
        id: 'p-${DateTime.now().microsecondsSinceEpoch}',
        groupId: groupId,
        author: currentName,
        type: type,
        mode: mode,
        title: title.trim().isEmpty ? 'New local post' : title.trim(),
        body: body.trim().isEmpty ? 'Local demo description.' : body.trim(),
        status: 'new',
      ),
    );
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
    comments.add(DemoComment(postId: post.id, author: currentName, body: body.trim()));
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
}

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
  final PostMode mode;
  final String title;
  final String body;
  String status;
  int support;
  int oppose;
  bool hidden;
  bool get canVote => mode == PostMode.voteOnly || mode == PostMode.discussion;
  bool get canComment => mode == PostMode.discussion;
}

class DemoComment {
  DemoComment({required this.postId, required this.author, required this.body});
  final String postId;
  final String author;
  final String body;
}

enum RequestStatus { pending, approved, rejected, needsMoreInfo }

extension RequestStatusText on RequestStatus {
  String get label {
    switch (this) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.approved:
        return 'Approved';
      case RequestStatus.rejected:
        return 'Rejected';
      case RequestStatus.needsMoreInfo:
        return 'Need more info';
    }
  }
}

class GroupCreationRequest {
  GroupCreationRequest({
    required this.id,
    required this.applicantName,
    required this.position,
    required this.organizationName,
    required this.organizationType,
    required this.region,
    required this.officialPhone,
    required this.officialEmail,
    required this.website,
    required this.groupTitle,
    required this.groupDescription,
    required this.reason,
    required this.documents,
    required this.status,
    required this.createdByPhone,
    required this.createdAt,
    this.adminComment,
    this.reviewedAt,
  });

  final String id;
  final String applicantName;
  final String position;
  final String organizationName;
  final String organizationType;
  final String region;
  final String officialPhone;
  final String officialEmail;
  final String website;
  final String groupTitle;
  final String groupDescription;
  final String reason;
  final String documents;
  final String createdByPhone;
  final DateTime createdAt;
  RequestStatus status;
  String? adminComment;
  DateTime? reviewedAt;
}

class OfflineLoginScreen extends StatefulWidget {
  const OfflineLoginScreen({super.key});

  @override
  State<OfflineLoginScreen> createState() => _OfflineLoginScreenState();
}

class _OfflineLoginScreenState extends State<OfflineLoginScreen> {
  final phone = TextEditingController(text: '+996555000111');
  final name = TextEditingController(text: 'Demo User');
  final code = TextEditingController(text: demoOtpCode);

  @override
  void dispose() {
    phone.dispose();
    name.dispose();
    code.dispose();
    super.dispose();
  }

  void enterDemo() {
    if (code.text.trim() != demoOtpCode) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo code is 1111')));
      return;
    }
    final digits = phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    final role = digits == adminDemoPhoneDigits ? DemoRole.admin : DemoRole.user;
    demo.login(phone: phone.text, name: name.text, nextRole: role);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => role == DemoRole.admin ? const AdminPanelScreen() : const GroupsScreen()));
  }

  void fillAdmin() {
    setState(() {
      phone.text = adminDemoPhone;
      name.text = 'Platform Admin';
      code.text = demoOtpCode;
    });
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
                  const Text('No internet. No server. Test admin number opens Admin Panel.', textAlign: TextAlign.center, style: TextStyle(color: MobileChatTheme.textMuted)),
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(16)), child: Text('Admin test number: $adminDemoPhone\nDemo SMS code: $demoOtpCode', textAlign: TextAlign.center, style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800))),
                  const SizedBox(height: 20),
                  TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_iphone_rounded))),
                  const SizedBox(height: 12),
                  TextField(controller: code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'SMS code', prefixIcon: Icon(Icons.sms_outlined))),
                  const SizedBox(height: 12),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Display name', prefixIcon: Icon(Icons.person_outline_rounded))),
                  const SizedBox(height: 18),
                  FilledButton.icon(onPressed: enterDemo, icon: const Icon(Icons.login_rounded), label: const Text('Enter offline demo')),
                  const SizedBox(height: 8),
                  TextButton(onPressed: fillAdmin, child: const Text('Fill admin test number')),
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
      appBar: AppBar(title: const Text('Groups'), actions: [IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyRequestsScreen())), icon: const Icon(Icons.assignment_outlined), tooltip: 'My requests'), IconButton(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OfflineLoginScreen())), icon: const Icon(Icons.logout_rounded), tooltip: 'Log out')]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: TextField(onChanged: (value) => setState(() => query = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search groups'))),
        Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), itemCount: groups.length, itemBuilder: (_, index) => GroupTile(group: groups[index]))),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RequestGroupScreen())), icon: const Icon(Icons.verified_user_outlined), label: const Text('Request group')),
    );
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

class RequestGroupScreen extends StatefulWidget {
  const RequestGroupScreen({super.key});

  @override
  State<RequestGroupScreen> createState() => _RequestGroupScreenState();
}

class _RequestGroupScreenState extends State<RequestGroupScreen> {
  final fullName = TextEditingController();
  final position = TextEditingController();
  final organization = TextEditingController();
  final organizationType = TextEditingController(text: 'City government');
  final region = TextEditingController();
  final officialPhone = TextEditingController();
  final officialEmail = TextEditingController();
  final website = TextEditingController();
  final groupTitle = TextEditingController();
  final groupDescription = TextEditingController();
  final reason = TextEditingController();
  final documents = TextEditingController(text: 'Official letter, staff ID, organization seal');

  @override
  void dispose() {
    fullName.dispose();
    position.dispose();
    organization.dispose();
    organizationType.dispose();
    region.dispose();
    officialPhone.dispose();
    officialEmail.dispose();
    website.dispose();
    groupTitle.dispose();
    groupDescription.dispose();
    reason.dispose();
    documents.dispose();
    super.dispose();
  }

  void submit() {
    final request = GroupCreationRequest(
      id: 'r-${DateTime.now().microsecondsSinceEpoch}',
      applicantName: fullName.text.trim().isEmpty ? demo.currentName : fullName.text.trim(),
      position: position.text.trim().isEmpty ? 'Representative' : position.text.trim(),
      organizationName: organization.text.trim().isEmpty ? 'Demo Organization' : organization.text.trim(),
      organizationType: organizationType.text.trim().isEmpty ? 'Government organization' : organizationType.text.trim(),
      region: region.text.trim().isEmpty ? 'Demo region' : region.text.trim(),
      officialPhone: officialPhone.text.trim().isEmpty ? demo.currentPhone : officialPhone.text.trim(),
      officialEmail: officialEmail.text.trim().isEmpty ? 'official@example.gov' : officialEmail.text.trim(),
      website: website.text.trim(),
      groupTitle: groupTitle.text.trim().isEmpty ? 'Official demo group' : groupTitle.text.trim(),
      groupDescription: groupDescription.text.trim().isEmpty ? 'Official local group requested in offline demo.' : groupDescription.text.trim(),
      reason: reason.text.trim().isEmpty ? 'Need official communication with residents.' : reason.text.trim(),
      documents: documents.text.trim().isEmpty ? 'Not provided in demo.' : documents.text.trim(),
      status: RequestStatus.pending,
      createdByPhone: demo.currentPhone,
      createdAt: DateTime.now(),
    );
    demo.submitGroupRequest(request);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to admin panel.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request official group')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Fill information so platform admins can verify the organization before creating an official group.', style: TextStyle(color: MobileChatTheme.textMuted)),
        const SizedBox(height: 16),
        _field(fullName, 'Full name'),
        _field(position, 'Position'),
        _field(organization, 'Organization name'),
        _field(organizationType, 'Organization type'),
        _field(region, 'City / region'),
        _field(officialPhone, 'Official phone'),
        _field(officialEmail, 'Official email'),
        _field(website, 'Official website'),
        _field(groupTitle, 'Requested group title'),
        _field(groupDescription, 'Group description', lines: 3),
        _field(reason, 'Reason for creating group', lines: 4),
        _field(documents, 'Documents / proof', lines: 3),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: submit, icon: const Icon(Icons.send_rounded), label: const Text('Send request')),
      ]),
    );
  }

  Widget _field(TextEditingController controller, String label, {int lines = 1}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: controller, minLines: lines, maxLines: lines, decoration: InputDecoration(labelText: label)));
  }
}

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
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
    final requests = demo.groupRequests.where((r) => r.createdByPhone == demo.currentPhone).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('My requests')),
      body: requests.isEmpty ? const Center(child: Text('No requests yet.')) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: requests.length, itemBuilder: (_, index) => RequestCard(request: requests[index], adminView: false)),
    );
  }
}

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
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
    final pendingCount = demo.groupRequests.where((r) => r.status == RequestStatus.pending).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel'), actions: [IconButton(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OfflineLoginScreen())), icon: const Icon(Icons.logout_rounded))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Signed in as admin', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Phone: ${demo.currentPhone}', style: const TextStyle(color: MobileChatTheme.textMuted)),
          const SizedBox(height: 10),
          Text('$pendingCount pending group request(s)', style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800)),
        ])),
        const SizedBox(height: 16),
        Text('Group creation requests', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (demo.groupRequests.isEmpty) const Text('No requests yet.', style: TextStyle(color: MobileChatTheme.textMuted)),
        ...demo.groupRequests.map((request) => RequestCard(request: request, adminView: true)),
        const SizedBox(height: 16),
        Text('Existing groups', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...demo.groups.map((group) => GroupTile(group: group)),
      ]),
    );
  }
}

class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, required this.adminView});
  final GroupCreationRequest request;
  final bool adminView;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestDetailsScreen(request: request, adminView: adminView))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [ChipLabel(text: request.status.label), const Spacer(), const Icon(Icons.chevron_right_rounded)]),
              const SizedBox(height: 10),
              Text(request.groupTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 4),
              Text(request.organizationName, style: const TextStyle(color: MobileChatTheme.textMuted)),
              const SizedBox(height: 8),
              Text('${request.applicantName} · ${request.position}', style: const TextStyle(fontWeight: FontWeight.w700)),
              if (request.adminComment != null) ...[
                const SizedBox(height: 8),
                Text('Admin comment: ${request.adminComment}', style: const TextStyle(color: MobileChatTheme.textMuted)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class RequestDetailsScreen extends StatefulWidget {
  const RequestDetailsScreen({super.key, required this.request, required this.adminView});
  final GroupCreationRequest request;
  final bool adminView;

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  final comment = TextEditingController();

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  void reject() {
    demo.rejectRequest(widget.request, comment.text);
    Navigator.pop(context);
  }

  void needMoreInfo() {
    demo.needMoreInfo(widget.request, comment.text);
    Navigator.pop(context);
  }

  void approve() {
    demo.approveRequest(widget.request);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Scaffold(
      appBar: AppBar(title: const Text('Request details')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [ChipLabel(text: r.status.label), const Spacer(), Text(r.createdAt.toLocal().toString().split('.').first, style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12))]),
          const SizedBox(height: 12),
          _line('Requested group', r.groupTitle),
          _line('Description', r.groupDescription),
          _line('Applicant', r.applicantName),
          _line('Position', r.position),
          _line('Organization', r.organizationName),
          _line('Organization type', r.organizationType),
          _line('Region', r.region),
          _line('Official phone', r.officialPhone),
          _line('Official email', r.officialEmail),
          _line('Website', r.website.isEmpty ? 'Not provided' : r.website),
          _line('Reason', r.reason),
          _line('Documents / proof', r.documents),
          if (r.adminComment != null) _line('Admin comment', r.adminComment!),
        ])),
        if (widget.adminView && r.status == RequestStatus.pending) ...[
          const SizedBox(height: 16),
          TextField(controller: comment, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Admin comment / reason')),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: approve, icon: const Icon(Icons.check_rounded), label: const Text('Approve and create group')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: needMoreInfo, icon: const Icon(Icons.info_outline_rounded), label: const Text('Need more info')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: reject, icon: const Icon(Icons.close_rounded), label: const Text('Reject')),
        ],
      ]),
    );
  }

  Widget _line(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]));
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
        Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), itemCount: posts.length, itemBuilder: (_, index) => FeedPostCard(post: posts[index], group: widget.group))),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: createPost, icon: const Icon(Icons.add_rounded), label: const Text('New post')),
    );
  }

  Future<void> createPost() async {
    final title = TextEditingController();
    final body = TextEditingController();
    String type = widget.group.canModerate ? 'announcement' : 'suggestion';
    PostMode mode = PostMode.discussion;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (context) => StatefulBuilder(builder: (context, setSheetState) {
      return Padding(
        padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('New local post', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Post type'), items: [if (widget.group.canModerate) const DropdownMenuItem(value: 'announcement', child: Text('Announcement')), const DropdownMenuItem(value: 'suggestion', child: Text('Suggestion')), const DropdownMenuItem(value: 'complaint', child: Text('Complaint')), const DropdownMenuItem(value: 'requirement', child: Text('Requirement')), const DropdownMenuItem(value: 'problem', child: Text('Problem')), const DropdownMenuItem(value: 'idea', child: Text('Idea'))], onChanged: (value) => setSheetState(() => type = value ?? 'suggestion')),
          const SizedBox(height: 12),
          DropdownButtonFormField<PostMode>(value: mode, decoration: const InputDecoration(labelText: 'Interaction mode'), items: const [DropdownMenuItem(value: PostMode.readOnly, child: Text('Text only')), DropdownMenuItem(value: PostMode.voteOnly, child: Text('Voting only')), DropdownMenuItem(value: PostMode.discussion, child: Text('Discussion with comments'))], onChanged: (value) => setSheetState(() => mode = value ?? PostMode.discussion)),
          const SizedBox(height: 12),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: body, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 16),
          FilledButton(onPressed: () { demo.createPost(groupId: widget.group.id, type: type, mode: mode, title: title.text, body: body.text); Navigator.pop(context); }, child: const Text('Publish locally')),
        ])),
      );
    }));
    title.dispose();
    body.dispose();
  }
}

class FeedPostCard extends StatelessWidget {
  const FeedPostCard({super.key, required this.post, required this.group});
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [ChipLabel(text: post.type), const SizedBox(width: 8), ChipLabel(text: post.mode.label), const Spacer(), Text(post.status, style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700))]),
            const SizedBox(height: 10),
            Text(post.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(post.body, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Text('By ${post.author}', style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            Row(children: [
              if (post.canComment) FilledButton.tonal(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsScreen(post: post, group: group))), child: const Text('Read')),
              if (post.canComment) const SizedBox(width: 8),
              if (post.canVote) ...[
                OutlinedButton.icon(onPressed: () => demo.vote(post, 'support'), icon: Icon(myVote == 'support' ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined), label: Text('${post.support}')),
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: () => demo.vote(post, 'oppose'), icon: Icon(myVote == 'oppose' ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined), label: Text('${post.oppose}')),
              ],
              const Spacer(),
              if (post.canComment) Text('$commentCount comments', style: const TextStyle(color: MobileChatTheme.textMuted)),
            ]),
          ]),
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
          FeedPostCard(post: widget.post, group: widget.group),
          if (widget.group.canModerate) DropdownButtonFormField<String>(value: widget.post.status, decoration: const InputDecoration(labelText: 'Admin status'), items: const [DropdownMenuItem(value: 'new', child: Text('New')), DropdownMenuItem(value: 'under_review', child: Text('Under review')), DropdownMenuItem(value: 'accepted', child: Text('Accepted')), DropdownMenuItem(value: 'rejected', child: Text('Rejected')), DropdownMenuItem(value: 'resolved', child: Text('Resolved'))], onChanged: (value) { if (value != null) demo.updateStatus(widget.post, value); }),
          const SizedBox(height: 12),
          Text('Comments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (comments.isEmpty) const Text('No comments yet.', style: TextStyle(color: MobileChatTheme.textMuted)),
          ...comments.map((c) => ListTile(contentPadding: EdgeInsets.zero, title: Text(c.author, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(c.body))),
        ])),
        SafeArea(top: false, child: Container(padding: const EdgeInsets.all(10), color: Colors.white, child: Row(children: [Expanded(child: TextField(controller: comment, decoration: const InputDecoration(hintText: 'Add local comment'))), const SizedBox(width: 8), IconButton.filled(onPressed: () { demo.addComment(widget.post, comment.text); comment.clear(); }, icon: const Icon(Icons.send_rounded))]))),
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
