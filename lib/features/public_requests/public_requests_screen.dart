import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../services/group_realtime_service.dart';
import '../../shared/ui_helpers.dart';
import '../statistics/group_statistics_screen.dart';
import '../groups/group_sheets.dart';
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
  String? ensuredInviteCode;
  late final GroupRealtimeService realtime;
  late Future<List<PublicRequest>> requestsFuture;
  Timer? _refreshDebounce;

  bool get canModerate =>
      widget.group.myRole == 'owner' || widget.group.myRole == 'admin';
  bool get canInvite => widget.group.canInvite;

  @override
  void initState() {
    super.initState();
    requestsApi = PublicRequestsApi(
      baseUrl: widget.api.baseUrl,
      sessionStore: widget.api.sessionStore,
    );
    realtime = GroupRealtimeService(api: widget.api, groupId: widget.group.id);
    requestsFuture = loadRequests();
    realtime.connect(onEvent: _handleRealtimeEvent);
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    realtime.close();
    super.dispose();
  }

  void _handleRealtimeEvent(GroupRealtimeEvent event) {
    if (!mounted || event.groupId != widget.group.id) return;
    if (!event.type.startsWith('public_request.')) return;
    _scheduleRealtimeRefresh();
  }

  void _scheduleRealtimeRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) refresh(silent: true);
    });
  }

  Future<List<PublicRequest>> loadRequests() async {
    final requests = await requestsApi.listRequests(widget.group.id);
    final sorted = List<PublicRequest>.from(requests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Future<void> refresh({bool silent = false}) async {
    final next = loadRequests();
    if (mounted) setState(() => requestsFuture = next);
    await next;
  }

  Future<void> openStatistics() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GroupStatisticsScreen(api: requestsApi, group: widget.group),
      ),
    );
    await refresh();
  }

  Future<void> createRequest() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) =>
          CreatePublicRequestSheet(api: requestsApi, group: widget.group),
    );
    if (created == true) {
      await refresh();
      if (mounted)
        showAppSnack(context, AppLanguageScope.textOf(context).postPublished);
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
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    }
  }

  Future<void> updateStatus(PublicRequest request, String status) async {
    if (!canModerate) return;
    try {
      await requestsApi.updateStatus(requestId: request.id, status: status);
      await refresh();
      if (mounted)
        showAppSnack(
          context,
          AppLanguageScope.textOf(context).isKy
              ? 'Статус жаңыртылды.'
              : 'Статус обновлён.',
        );
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    }
  }

  Future<void> openDetails(PublicRequest request) async {
    if (request.interactionMode != 'discussion') return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicRequestDetailsScreen(
          api: requestsApi,
          request: request,
          canModerate: canModerate,
          currentUserId: widget.user.id,
          onStatusChanged: canModerate
              ? (status) => updateStatus(request, status)
              : null,
        ),
      ),
    );
    await refresh();
  }

  String get groupAccessCode =>
      formatGroupInviteCode(ensuredInviteCode ?? widget.group.inviteCode ?? '');

  Future<void> showGroupAccess() async {
    var code = groupAccessCode;
    if (code.isEmpty) {
      try {
        final group = await requestsApi.ensureGroupInviteCode(widget.group.id);
        if (!mounted) return;
        setState(() => ensuredInviteCode = group.inviteCode);
        code = formatGroupInviteCode(group.inviteCode ?? '');
      } catch (error) {
        if (mounted) showAppSnack(context, error.toString());
        return;
      }
    }
    if (code.isEmpty) {
      showAppSnack(
        context,
        AppLanguageScope.textOf(context).isKy
            ? 'Топтун коду азырынча түзүлгөн эмес.'
            : 'Код группы ещё не создан.',
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) =>
          GroupAccessSheet(groupTitle: widget.group.title, code: code),
    );
  }

  Future<void> inviteByPhone() async {
    if (!canInvite) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => InviteByPhoneSheet(api: widget.api, group: widget.group),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.title),
        actions: [
          IconButton(
            onPressed: openStatistics,
            tooltip: text.isKy ? 'Статистика' : 'Статистика',
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            onPressed: showGroupAccess,
            tooltip: text.isKy ? 'Код жана QR' : 'Код и QR',
            icon: const Icon(Icons.qr_code_rounded),
          ),
          if (canInvite)
            IconButton(
              onPressed: inviteByPhone,
              tooltip: text.isKy
                  ? 'Телефон менен чакыруу'
                  : 'Пригласить по телефону',
              icon: const Icon(Icons.person_add_alt_1_rounded),
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
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [ErrorBanner(message: snapshot.error.toString())],
              );
            final requests = snapshot.data ?? const <PublicRequest>[];
            if (requests.isEmpty) {
              return EmptyPostsView(onCreate: createRequest);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: requests.length,
              itemBuilder: (_, index) => PublicRequestCard(
                request: requests[index],
                canModerate: canModerate,
                onVote: (voteType) => vote(requests[index], voteType),
                onTap: () => openDetails(requests[index]),
                onStatus: (status) => updateStatus(requests[index], status),
              ),
            );
          },
        ),
      ),
    );
  }
}
