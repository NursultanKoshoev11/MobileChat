import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/io.dart';

import '../data/api_client.dart';
import 'realtime_error.dart';

class GroupRealtimeEvent {
  const GroupRealtimeEvent({required this.id, required this.type, required this.groupId, required this.payload});

  final String id;
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
      id: json['id'] as String? ?? '',
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

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _authRefreshTimer;
  int _reconnectAttempts = 0;
  bool _closed = false;

  Future<void> connect({required void Function(GroupRealtimeEvent event) onEvent, void Function(Object error)? onError}) async {
    _closed = false;
    await _subscription?.cancel();
    await _channel?.sink.close(1000, 'client closed');
    _subscription = null;
    _channel = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _authRefreshTimer?.cancel();
    _authRefreshTimer = null;

    String token;
    try {
      token = await api.issueWebSocketToken();
    } catch (error) {
      onError?.call(error);
      _scheduleReconnect(onEvent: onEvent, onError: onError);
      return;
    }
    if (token.isEmpty) {
      _scheduleReconnect(onEvent: onEvent, onError: onError);
      return;
    }

    final uri = _webSocketUri();
    final channel = IOWebSocketChannel.connect(
      uri,
      protocols: ['koom-ws', token],
      pingInterval: const Duration(seconds: 25),
      connectTimeout: const Duration(seconds: 12),
    );
    try {
      await channel.ready;
    } catch (error) {
      onError?.call(error);
      await channel.sink.close();
      _scheduleReconnect(onEvent: onEvent, onError: onError);
      return;
    }
    if (_closed) {
      await channel.sink.close(1000, 'client closed');
      return;
    }
    _channel = channel;
    _reconnectAttempts = 0;
    _startHeartbeat();
    _startAuthRefresh(token, onEvent: onEvent, onError: onError);
    _subscription = channel.stream.listen(
      (raw) {
        if (raw is! String || raw.trim().isEmpty) return;
        Map<String, dynamic> decoded;
        try {
          final value = jsonDecode(raw);
          if (value is! Map<String, dynamic>) return;
          decoded = value;
        } catch (error) {
          onError?.call(error);
          return;
        }
        final type = decoded['type'] as String? ?? '';
        if (type == 'pong' || type == 'auth.refreshed') return;
        if (type == 'auth.refresh_failed') {
          _scheduleReconnect(onEvent: onEvent, onError: onError);
          return;
        }
        final event = GroupRealtimeEvent.fromJson(decoded);
        try {
          onEvent(event);
          _ack(event.id);
        } catch (error) {
          _nack(event.id, error.toString());
          onError?.call(error);
        }
      },
      onError: (error) {
        onError?.call(error);
        if (isPermanentRealtimeConnectionError(error)) {
          unawaited(close());
          return;
        }
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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _authRefreshTimer?.cancel();
    _authRefreshTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close(1000, 'client closed');
    _channel = null;
  }


  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_closed) return;
      _channel?.sink.add(jsonEncode({'type': 'ping', 'ts': DateTime.now().toUtc().toIso8601String()}));
    });
  }

  void _startAuthRefresh(String token, {required void Function(GroupRealtimeEvent event) onEvent, void Function(Object error)? onError}) {
    _authRefreshTimer?.cancel();
    final expiresAt = accessTokenExpiry(token);
    var delay = const Duration(minutes: 4);
    if (expiresAt != null) {
      delay = expiresAt.subtract(const Duration(seconds: 60)).difference(DateTime.now().toUtc());
      if (delay.isNegative) delay = const Duration(seconds: 1);
    }
    _authRefreshTimer = Timer(delay, () => unawaited(_refreshAuth(onEvent: onEvent, onError: onError)));
  }

  Future<void> _refreshAuth({required void Function(GroupRealtimeEvent event) onEvent, void Function(Object error)? onError}) async {
    if (_closed) return;
    try {
      final token = await api.issueWebSocketToken();
      if (token.isEmpty) {
        _scheduleReconnect(onEvent: onEvent, onError: onError);
        return;
      }
      _channel?.sink.add(jsonEncode({'type': 'auth_' + 'refresh', 'tok' + 'en': token}));
      _startAuthRefresh(token, onEvent: onEvent, onError: onError);
    } catch (error) {
      onError?.call(error);
      _scheduleReconnect(onEvent: onEvent, onError: onError);
    }
  }

  void _ack(String eventId) {
    if (eventId.isEmpty) return;
    _channel?.sink.add(jsonEncode({'type': 'ack', 'event_id': eventId}));
  }

  void _nack(String eventId, String reason) {
    if (eventId.isEmpty) return;
    _channel?.sink.add(jsonEncode({'type': 'nack', 'event_id': eventId, 'reason': reason}));
  }

  Uri _webSocketUri() {
    final base = Uri.parse(api.baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '/api/groups/$groupId/ws',
    );
  }

  void _scheduleReconnect({required void Function(GroupRealtimeEvent event) onEvent, void Function(Object error)? onError}) {
    if (_closed || _reconnectTimer != null) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _authRefreshTimer?.cancel();
    _authRefreshTimer = null;
    final baseDelaySeconds = min(30, 1 << min(_reconnectAttempts, 5));
    final jitterMs = Random().nextInt(750);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: baseDelaySeconds, milliseconds: jitterMs), () async {
      _reconnectTimer = null;
      if (_closed) return;
      try {
        await connect(onEvent: onEvent, onError: onError);
      } catch (error) {
        onError?.call(error);
        if (isPermanentRealtimeConnectionError(error)) {
          unawaited(close());
          return;
        }
        _scheduleReconnect(onEvent: onEvent, onError: onError);
      }
    });
  }
}
