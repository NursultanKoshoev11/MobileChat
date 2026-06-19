import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../shared/ui_helpers.dart';
import 'moderation_screen.dart';
import 'public_request_media_screens.dart';
import 'public_request_media_widgets.dart';
import 'public_requests_widgets.dart';

class PublicRequestsScreen extends StatefulWidget {
  const PublicRequestsScreen({
    super.key,
    required this.api,
    required this.user,
    required this.group,
  });

  final ApiClient api;
  final UserProfile user;
  final ChatGroup group;

  @override
  State<PublicRequestsScreen> createState() => _PublicRequestsScreenState();
}

class _PublicRequestsScreenState extends State<PublicRequestsScreen> {
  late final PublicRequestsApi requestsApi;
  late Future<List<PublicRequest>> requestsFuture;

  bool get canModerate =>
      widget.group.myRole == 'owner' || widget.group.myRole == 'admin';

  @override
  void initState() {
    super.initState();
    requestsApi = PublicRequestsApi(
      baseUrl: widget.api.baseUrl,
      sessionStore: widget.api.sessionStore,
    );
    requestsFuture = loadRequests();
  }

  Future<List<PublicRequest>> loadRequests() async {
    final requests = await requestsApi.listRequests(widget.group.id);
    return List<PublicRequest>.from(requests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> refresh() async {
    final next = loadRequests();
    if (mounted) setState(() => requestsFuture = next);
    await next;
  }

  Future<void> createRequest() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => CreatePublicRequestMediaSheet(
        api: requestsApi,
        groupId: widget.group.id,
      ),
    );
    if (created == true) {
      await refresh();
      if (mounted) {
        showAppSnack(context, AppLanguageScope.textOf(context).postPublished);
      }
    }
  }

  Future<void> vote(PublicRequest request, String voteType) async {
    if (request.interactionMode == 'read_only') return;
    try {
      if (request.myVote == voteType) {
        await requestsApi.clearVote(request.id);
      } else if (voteType == 'support') {
        await requestsApi.support(request.id);
      } else {
        await requestsApi.oppose(request.id);
      }
      await refresh();
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString());
    }
  }

  Future<void> updateStatus(PublicRequest request, String status) async {
    if (!canModerate) return;
    try {
      await requestsApi.updateStatus(requestId: request.id, status: status);
      await refresh();
      if (mounted) showAppSnack(context, 'Status updated.');
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString());
    }
  }

  Future<void> openDetails(PublicRequest request) async {
    if (request.interactionMode != 'discussion') return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaPublicRequestDetailsScreen(
          api: requestsApi,
          request: request,
          canModerate: canModerate,
          currentUserId: widget.user.id,
          onStatusChanged:
              canModerate ? (status) => updateStatus(request, status) : null,
        ),
      ),
    );
    await refresh();
  }

  Future<void> openModerationQueue() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupModerationScreen(
          api: requestsApi,
          group: widget.group,
        ),
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.title),
        actions: [
          if (canModerate)
            IconButton(
              onPressed: openModerationQueue,
              tooltip: 'On review',
              icon: const Icon(Icons.fact_check_outlined),
            ),
          const AppSettingsButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createRequest,
        icon: const Icon(Icons.add_rounded),
        label: Text(text.newPost),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<PublicRequest>>(
          future: requestsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [ErrorBanner(message: snapshot.error.toString())],
              );
            }
            final requests = snapshot.data ?? const <PublicRequest>[];
            if (requests.isEmpty) return EmptyPostsView(onCreate: createRequest);
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: requests.length,
              itemBuilder: (_, index) {
                final request = requests[index];
                return MediaPublicRequestCard(
                  request: request,
                  canModerate: canModerate,
                  onVote: (voteType) => vote(request, voteType),
                  onTap: () => openDetails(request),
                  onStatus: (status) => updateStatus(request, status),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
