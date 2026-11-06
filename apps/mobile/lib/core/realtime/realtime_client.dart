import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../storage/token_store.dart';
import 'realtime_event.dart';

/// Live updates for the homes the user is looking at.
abstract interface class RealtimeClient {
  Stream<RealtimeEvent> get events;

  void subscribeHome(String homeId);

  void unsubscribeHome(String homeId);

  Future<void> dispose();
}

/// WebSocket client for `wss://rt.{region}.nestap.io/v1/stream`.
///
/// Connects on the first subscription, authenticates with the first message
/// (never a token in the URL), re-subscribes after reconnecting, and backs off
/// 1 s → 2 s → … → 30 s while the network is down.
class WebSocketRealtimeClient implements RealtimeClient {
  WebSocketRealtimeClient({required Uri url, required TokenStore tokenStore})
      : _url = url,
        _tokenStore = tokenStore;

  final Uri _url;
  final TokenStore _tokenStore;
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _homes = <String>{};

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _disposed = false;

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  void subscribeHome(String homeId) {
    if (!_homes.add(homeId)) return;
    if (_channel == null) {
      unawaited(_connect());
    } else {
      _send({'op': 'subscribe', 'home_id': homeId});
    }
  }

  @override
  void unsubscribeHome(String homeId) {
    if (_homes.remove(homeId)) _send({'op': 'unsubscribe', 'home_id': homeId});
  }

  Future<void> _connect() async {
    if (_disposed || _channel != null || _homes.isEmpty) return;
    final tokens = await _tokenStore.read();
    if (tokens == null) return;

    try {
      final channel = WebSocketChannel.connect(_url);
      _channel = channel;
      await channel.ready;
      _attempt = 0;
      _send({'op': 'auth', 'token': tokens.accessToken});
      for (final homeId in _homes) {
        _send({'op': 'subscribe', 'home_id': homeId});
      }
      _subscription = channel.stream.listen(
        _onMessage,
        onDone: _scheduleReconnect,
        onError: (Object _) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } on Object {
      _scheduleReconnect();
    }
  }

  void _onMessage(Object? raw) {
    if (raw is! String) return;
    final json = jsonDecode(raw);
    if (json is Map<String, dynamic>) _events.add(RealtimeEvent.fromJson(json));
  }

  void _scheduleReconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (_disposed || _homes.isEmpty) return;
    final delay = Duration(seconds: min(30, 1 << _attempt));
    _attempt = min(_attempt + 1, 5);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(_connect()));
  }

  void _send(Map<String, Object?> message) =>
      _channel?.sink.add(jsonEncode(message));

  @override
  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _events.close();
  }
}
