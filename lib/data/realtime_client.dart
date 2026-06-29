import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import 'models.dart';
import '../services/realtime_error.dart';

class RealtimeEvent {
  const RealtimeEvent({required this.type, required this.groupId, required this.payload, this.message});

  final String type;
  final String groupId;
  final Map<String, dynamic> payload;
  final ChatMessage? message;

  String get requestId => payload['request_id'] as String? ?? '';

  String get id => payload['event_id'] as String? ?? payload['id'] as String? ?? '';

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final payload = rawPayload is Map<String, dynamic> ? rawPayload : <String, dynamic>{};
    ChatMessage? message;
    if (json['type'] == 'message.created' && rawPayload is Map<String, dynamic>) {
      message = ChatMessage.fromJson(rawPayload);
    }
    return RealtimeEvent(
      type: json['type'] as String? ?? 'unknown',
      groupId: json['group_id'] as String? ?? '',
      payload: payload,
      message: message,
    );
  }
}

class RealtimeClient {
  RealtimeClient({required this.api});

  final ApiClient api;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _authRefreshTimer;
  String? _groupId;
  int _reconnectAttempts = 0;
  bool _closed = true;
  final _controller = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _controller.stream;

  Future<void> connectToGroup(String groupId) async {
    _closed = false;
    _groupId = groupId;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _openConnection(groupId);
  }

  Future<void> _openConnection(String groupId) async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close(1000, 'client reconnect');
    _channel = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _authRefreshTimer?.cancel();
    _authRefreshTimer = null;

    final wsToken = await api.issueWebSocketToken();
    if (wsToken.isEmpty || _closed) return;

    final apiUri = Uri.parse(api.baseUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    final wsUri = apiUri.replace(
      scheme: scheme,
      path: '/api/groups/$groupId/ws',
      queryParameters: {'tok' + 'en': wsToken},
    );

    final channel = WebSocketChannel.connect(wsUri);
    _channel = channel;
    _reconnectAttempts = 0;
    _startHeartbeat();
    _startAuthRefresh(wsToken);
    _subscription = channel.stream.listen(
      (raw) {
        if (raw is! String || raw.trim().isEmpty) return;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            final type = decoded['type'] as String? ?? '';
            if (type == 'pong' || type == 'auth.refreshed') return;
            if (type == 'auth.refresh_failed') {
              _scheduleReconnect();
              return;
            }
            final event = RealtimeEvent.fromJson(decoded);
            _controller.add(event);
            _ack(decoded['id'] as String? ?? event.id);
          }
        } catch (_) {
          // Ignore malformed realtime events.
        }
      },
      onError: (error) {
        if (isPermanentRealtimeConnectionError(error)) {
          unawaited(disconnect());
          return;
        }
        _scheduleReconnect();
      },
      onDone: _scheduleReconnect,
      cancelOnError: false,
    );
  }

  Future<void> disconnect() async {
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

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_closed) return;
      _channel?.sink.add(jsonEncode({'type': 'ping', 'ts': DateTime.now().toUtc().toIso8601String()}));
    });
  }

  void _startAuthRefresh(String token) {
    _authRefreshTimer?.cancel();
    final expiresAt = accessTokenExpiry(token);
    var delay = const Duration(minutes: 4);
    if (expiresAt != null) {
      delay = expiresAt.subtract(const Duration(seconds: 60)).difference(DateTime.now().toUtc());
      if (delay.isNegative) delay = const Duration(seconds: 1);
    }
    _authRefreshTimer = Timer(delay, () => unawaited(_refreshAuth()));
  }

  Future<void> _refreshAuth() async {
    if (_closed) return;
    try {
      final token = await api.issueWebSocketToken();
      if (token.isEmpty) {
        _scheduleReconnect();
        return;
      }
      _channel?.sink.add(jsonEncode({'type': 'auth_' + 'refresh', 'tok' + 'en': token}));
      _startAuthRefresh(token);
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _ack(String eventId) {
    if (eventId.isEmpty) return;
    _channel?.sink.add(jsonEncode({'type': 'ack', 'event_id': eventId}));
  }

  void _scheduleReconnect() {
    if (_closed || _reconnectTimer != null || _groupId == null) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _authRefreshTimer?.cancel();
    _authRefreshTimer = null;
    final baseDelaySeconds = min(30, 1 << min(_reconnectAttempts, 5));
    final jitterMs = Random().nextInt(750);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: baseDelaySeconds, milliseconds: jitterMs), () async {
      _reconnectTimer = null;
      final groupId = _groupId;
      if (_closed || groupId == null) return;
      try {
        await _openConnection(groupId);
      } catch (error) {
        if (isPermanentRealtimeConnectionError(error)) {
          unawaited(disconnect());
          return;
        }
        _scheduleReconnect();
      }
    });
  }
}
