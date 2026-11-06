/// Messages pushed by the realtime gateway
/// (`docs/architecture/04-backend-services.md` §12).
sealed class RealtimeEvent {
  const RealtimeEvent();

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    final deviceId = json['device_id'] as String? ?? '';
    return switch (json['type']) {
      'state' => DeviceStateEvent(
          deviceId: deviceId,
          version: (json['version'] as num?)?.toInt() ?? 0,
          changed: (json['changed'] as Map<String, dynamic>?) ?? const {},
        ),
      'presence' => DevicePresenceEvent(
          deviceId: deviceId,
          online: json['online'] as bool? ?? false,
        ),
      'device_added' => DeviceAddedEvent(deviceId: deviceId),
      'device_removed' => DeviceRemovedEvent(deviceId: deviceId),
      final type => UnknownRealtimeEvent(type?.toString() ?? ''),
    };
  }
}

final class DeviceStateEvent extends RealtimeEvent {
  const DeviceStateEvent({
    required this.deviceId,
    required this.version,
    required this.changed,
  });

  final String deviceId;
  final int version;
  final Map<String, Object?> changed;
}

final class DevicePresenceEvent extends RealtimeEvent {
  const DevicePresenceEvent({required this.deviceId, required this.online});

  final String deviceId;
  final bool online;
}

final class DeviceAddedEvent extends RealtimeEvent {
  const DeviceAddedEvent({required this.deviceId});

  final String deviceId;
}

final class DeviceRemovedEvent extends RealtimeEvent {
  const DeviceRemovedEvent({required this.deviceId});

  final String deviceId;
}

final class UnknownRealtimeEvent extends RealtimeEvent {
  const UnknownRealtimeEvent(this.type);

  final String type;
}
