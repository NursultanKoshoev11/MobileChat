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
  bool get canChangeRoles => widget.group.ownerId == widget.user.id;
  bool get canMuteComments => canModerate;

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
              ? 'Р В Р Р‹Р РЋРІР‚С™Р В Р’В°Р РЋРІР‚С™Р РЋРЎвЂњР РЋР С“ Р В Р’В¶Р В Р’В°Р СћР в‚¬Р РЋРІР‚в„–Р РЋР вЂљР РЋРІР‚С™Р РЋРІР‚в„–Р В Р’В»Р В РўвЂР РЋРІР‚в„–.'
              : 'Р В Р Р‹Р РЋРІР‚С™Р В Р’В°Р РЋРІР‚С™Р РЋРЎвЂњР РЋР С“ Р В РЎвЂўР В Р’В±Р В Р вЂ¦Р В РЎвЂўР В Р вЂ Р В Р’В»Р РЋРІР‚ВР В Р вЂ¦.',
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
            ? 'Р В РЎС›Р В РЎвЂўР В РЎвЂ”Р РЋРІР‚С™Р РЋРЎвЂњР В Р вЂ¦ Р В РЎвЂќР В РЎвЂўР В РўвЂР РЋРЎвЂњ Р В Р’В°Р В Р’В·Р РЋРІР‚в„–Р РЋР вЂљР РЋРІР‚в„–Р В Р вЂ¦Р РЋРІР‚РЋР В Р’В° Р РЋРІР‚С™Р СћР вЂЎР В Р’В·Р СћР вЂЎР В Р’В»Р В РЎвЂ“Р Р€Р’В©Р В Р вЂ¦ Р РЋР РЉР В РЎВР В Р’ВµР РЋР С“.'
            : 'Р В РЎв„ўР В РЎвЂўР В РўвЂ Р В РЎвЂ“Р РЋР вЂљР РЋРЎвЂњР В РЎвЂ”Р В РЎвЂ”Р РЋРІР‚в„– Р В Р’ВµР РЋРІР‚В°Р РЋРІР‚В Р В Р вЂ¦Р В Р’Вµ Р РЋР С“Р В РЎвЂўР В Р’В·Р В РўвЂР В Р’В°Р В Р вЂ¦.',
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

  Future<void> muteCommentsByPhone() async {
    if (!canMuteComments) return;
    final rootContext = context;
    final text = AppLanguageScope.textOf(context);
    final phoneController = TextEditingController(text: '+996');
    final reasonController = TextEditingController();
    final membersFuture = requestsApi.listGroupMembers(widget.group.id);
    var durationMinutes = 60;
    var loading = false;
    String? errorText;
    String? successText;

    String durationLabel(int minutes) {
      switch (minutes) {
        case 60:
          return text.oneHour;
        case 180:
          return text.threeHours;
        case 360:
          return text.sixHours;
        case 720:
          return text.twelveHours;
        case 1440:
          return text.oneDay;
        case 10080:
          return text.sevenDays;
        case 43200:
          return text.thirtyDays;
        case 0:
          return text.forever;
        default:
          return '$minutes min';
      }
    }

    await showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(rootContext).cardColor,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void showResult({String? error, String? success}) {
            setSheetState(() {
              errorText = error;
              successText = success;
            });
            if (rootContext.mounted) {
              showAppSnack(rootContext, error ?? success ?? '');
            }
          }

          Future<void> mute() async {
            final phone = phoneController.text.trim();
            if (phone.isEmpty || loading) return;
            setSheetState(() {
              loading = true;
              errorText = null;
              successText = null;
            });
            try {
              await requestsApi.setCommentMuteByPhone(
                groupId: widget.group.id,
                phone: phone,
                durationMinutes: durationMinutes,
                reason: reasonController.text.trim(),
              );
              showResult(success: text.mutedDone);
            } catch (error) {
              showResult(
                  error: localizedMessage(rootContext, error.toString()));
            } finally {
              if (context.mounted) setSheetState(() => loading = false);
            }
          }

          Future<void> unmute() async {
            final phone = phoneController.text.trim();
            if (phone.isEmpty || loading) return;
            setSheetState(() {
              loading = true;
              errorText = null;
              successText = null;
            });
            try {
              await requestsApi.clearCommentMuteByPhone(
                  groupId: widget.group.id, phone: phone);
              showResult(success: text.unmutedDone);
            } catch (error) {
              showResult(
                  error: localizedMessage(rootContext, error.toString()));
            } finally {
              if (context.mounted) setSheetState(() => loading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 22),
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(text.blockComments,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(text.blockCommentsDescription),
                    const SizedBox(height: 14),
                    FutureBuilder<List<GroupMember>>(
                      future: membersFuture,
                      builder: (context, snapshot) {
                        final members = (snapshot.data ?? const <GroupMember>[])
                            .where((member) =>
                                member.phone != null &&
                                member.phone!.trim().isNotEmpty)
                            .toList();
                        if (members.isEmpty) return const SizedBox.shrink();
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                    labelText: text.mobileNumber,
                                    prefixIcon: const Icon(
                                        Icons.people_outline_rounded)),
                                items: members
                                    .map((member) => DropdownMenuItem<String>(
                                          value: member.phone,
                                          child: Text(
                                              '${member.displayName} · ${member.phone} · ${member.role}'),
                                        ))
                                    .toList(),
                                onChanged: loading
                                    ? null
                                    : (value) => setSheetState(() =>
                                        phoneController.text =
                                            value ?? phoneController.text),
                              ),
                              const SizedBox(height: 12),
                            ]);
                      },
                    ),
                    TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                            labelText: text.mobileNumber,
                            hintText: '+996700123456',
                            prefixIcon:
                                const Icon(Icons.phone_iphone_rounded))),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: durationMinutes,
                      decoration: InputDecoration(
                          labelText: text.blockDuration,
                          prefixIcon: const Icon(Icons.timer_outlined)),
                      items: const [60, 180, 360, 720, 1440, 10080, 43200, 0]
                          .map((minutes) => DropdownMenuItem<int>(
                              value: minutes,
                              child: Text(durationLabel(minutes))))
                          .toList(),
                      onChanged: loading
                          ? null
                          : (value) => setSheetState(
                              () => durationMinutes = value ?? 60),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: reasonController,
                        minLines: 1,
                        maxLines: 2,
                        decoration: InputDecoration(
                            labelText: text.blockReason,
                            prefixIcon: const Icon(Icons.note_alt_outlined))),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(errorText!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w700)),
                    ],
                    if (successText != null) ...[
                      const SizedBox(height: 12),
                      Text(successText!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        onPressed: loading ? null : mute,
                        icon: const Icon(Icons.block_rounded),
                        label: Text(loading
                            ? text.pleaseWait
                            : text.blockCommentsButton)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                        onPressed: loading ? null : unmute,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: Text(text.unblockCommentsButton)),
                  ]),
            ),
          );
        },
      ),
    );
    phoneController.dispose();
    reasonController.dispose();
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
          if (canMuteComments)
            IconButton(
              onPressed: muteCommentsByPhone,
              tooltip: text.blockComments,
              icon: const Icon(Icons.block_rounded),
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
