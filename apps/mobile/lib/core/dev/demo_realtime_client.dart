import 'dart:async';

import '../realtime/realtime_client.dart';
import '../realtime/realtime_event.dart';
import 'demo_backend.dart';

class DemoRealtimeClient implements RealtimeClient {
  DemoRealtimeClient(DemoBackend backend)
      : events = backend.events
            .map((json) => RealtimeEvent.fromJson(Map<String, dynamic>.of(json)))
            .asBroadcastStream();

  @override
  final Stream<RealtimeEvent> events;

  @override
  void subscribeHome(String homeId) {}

  @override
  void unsubscribeHome(String homeId) {}

  @override
  Future<void> dispose() async {}
}
