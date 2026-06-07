import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../data/api_client.dart';

class UserRealtimeEvent {
  const UserRealtimeEvent({required this.type, required this.payload});

  final String type;
  final dynamic payload;

  factory UserRealtimeEvent.fromJson(Map<String, dynamic> json) {
    return UserRealtimeEvent(type: json['type'] as String? ?? '', payload: json['payload']);
  }
}

class UserRealtimeService {
  UserRealtimeService({required this.api});

  final ApiClient api;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _closed = false;

  Future<void> connect({required void Function(UserRealtimeEvent event) onEvent, void Function(Object error)? onError}) async {
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
        if (decoded is Map<String, dynamic>) onEvent(UserRealtimeEvent.fromJson(decoded));
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
    return base.replace(scheme: scheme, path: '/api/ws', queryParameters: {'token': token});
  }

  void _scheduleReconnect({required void Function(UserRealtimeEvent event) onEvent, void Function(Object error)? onError}) {
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
