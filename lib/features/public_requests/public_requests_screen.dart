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
  bool get canChangeRoles => widget.group.myRole == 'owner';

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
              ? 'Р РЋРЎвЂљР В°РЎвЂљРЎС“РЎРѓ Р В¶Р В°РўР€РЎвЂ№РЎР‚РЎвЂљРЎвЂ№Р В»Р Т‘РЎвЂ№.'
              : 'Р РЋРЎвЂљР В°РЎвЂљРЎС“РЎРѓ Р С•Р В±Р Р…Р С•Р Р†Р В»РЎвЂР Р….',
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
          onStatusChanged:
              canModerate ? (status) => updateStatus(request, status) : null,
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
            ? 'Р СћР С•Р С—РЎвЂљРЎС“Р Р… Р С”Р С•Р Т‘РЎС“ Р В°Р В·РЎвЂ№РЎР‚РЎвЂ№Р Р…РЎвЂЎР В° РЎвЂљРўР‡Р В·РўР‡Р В»Р С–РЈВ©Р Р… РЎРЊР СР ВµРЎРѓ.'
            : 'Р С™Р С•Р Т‘ Р С–РЎР‚РЎС“Р С—Р С—РЎвЂ№ Р ВµРЎвЂ°РЎвЂ Р Р…Р Вµ РЎРѓР С•Р В·Р Т‘Р В°Р Р….',
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

  Future<void> changeRoleByPhone() async {
    if (!canChangeRoles) return;
    final text = AppLanguageScope.textOf(context);
    final phoneController = TextEditingController(text: '+996');
    var loading = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> changeRole(String role) async {
            final phone = phoneController.text.trim();
            if (phone.isEmpty || loading) return;
            setSheetState(() => loading = true);
            try {
              await requestsApi.updateGroupMemberRoleByPhone(
                  groupId: widget.group.id, phone: phone, role: role);
              if (!context.mounted) return;
              Navigator.pop(sheetContext);
              showAppSnack(context,
                  role == 'admin' ? text.adminAssigned : text.adminRemoved);
            } catch (error) {
              if (context.mounted) showAppSnack(context, error.toString());
            } finally {
              if (context.mounted) setSheetState(() => loading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 22),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(text.manageAdmins,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(text.manageAdminsDescription),
                  const SizedBox(height: 14),
                  TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                          labelText: text.mobileNumber,
                          hintText: '+996700123456',
                          prefixIcon: const Icon(Icons.phone_iphone_rounded))),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: loading ? null : () => changeRole('admin'),
                      icon: const Icon(Icons.admin_panel_settings_rounded),
                      label: Text(loading ? text.pleaseWait : text.makeAdmin)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                      onPressed: loading ? null : () => changeRole('member'),
                      icon: const Icon(Icons.person_outline_rounded),
                      label: Text(text.removeAdmin)),
                ]),
          );
        },
      ),
    );
    phoneController.dispose();
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
            tooltip: text.statistics,
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            onPressed: showGroupAccess,
            tooltip: text.codeAndQr,
            icon: const Icon(Icons.qr_code_rounded),
          ),
          if (canChangeRoles)
            IconButton(
              onPressed: changeRoleByPhone,
              tooltip: text.manageAdmins,
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          if (canInvite)
            IconButton(
              onPressed: inviteByPhone,
              tooltip: text.inviteByPhone,
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
