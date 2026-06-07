import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../data/api_client.dart';

class GroupRealtimeEvent {
  const GroupRealtimeEvent({required this.type, required this.groupId, required this.payload});

  final String type;
  final String groupId;
  final dynamic payload;

  String get requestId {
    final value = payload;
    if (value is Map<String, dynamic>) return value['request_id'] as String? ?? value['id'] as String? ?? '';
    return '';
  }

  factory GroupRealtimeEvent.fromJson(Map<String, dynamic> json) {
    return GroupRealtimeEvent(
      type: json['type'] as String? ?? '',
      groupId: json['group_id'] as String? ?? '',
      payload: json['payload'],
    );
  }
}

class GroupRealtimeService {
  GroupRealtimeService({required this.api, required this.groupId});

  final ApiClient api;
  final String groupId;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _closed = false;

  Future<void> connect({required void Function(GroupRealtimeEvent event) onEvent, void Function(Object error)? onError}) async {
    _closed = false;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;

    final token = await api.issueWebSocketToken();
    if (token.isEmpty) return;

    final uri = _webSocketUri(token);
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _subscription = channel.stream.listen(
      (raw) {
        if (raw is! String || raw.trim().isEmpty) return;
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) onEvent(GroupRealtimeEvent.fromJson(decoded));
      },
      onError: (error) {
        onError?.call(error);
        _scheduleReconnect(onEvent: onEvent, onError: onError);
      },
      onDone: () {
        _scheduleReconnect(onEvent: onEvent, onError: onError);
      },
      cancelOnError: false,
    );
  }

  Future<void> close() async {
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Uri _webSocketUri(String token) {
    final base = Uri.parse(api.baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '/api/groups/$groupId/ws',
      queryParameters: {'token': token},
    );
  }

  void _scheduleReconnect({required void Function(GroupRealtimeEvent event) onEvent, void Function(Object error)? onError}) {
    if (_closed || _reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      _reconnectTimer = null;
      if (_closed) return;
      try {
        await connect(onEvent: onEvent, onError: onError);
      } catch (error) {
        onError?.call(error);
        _scheduleReconnect(onEvent: onEvent, onError: onError);
      }
    });
  }
}
