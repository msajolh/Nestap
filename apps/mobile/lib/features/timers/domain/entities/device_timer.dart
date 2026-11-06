import 'package:equatable/equatable.dart';

/// A repeating (or one-off) schedule that sets DPs on one device.
class DeviceTimer extends Equatable {
  const DeviceTimer({
    required this.id,
    required this.deviceId,
    required this.hour,
    required this.minute,
    required this.days,
    required this.dps,
    required this.enabled,
  });

  final String id;
  final String deviceId;
  final int hour;
  final int minute;

  /// 1 = Monday … 7 = Sunday. Empty = runs once.
  final List<int> days;
  final Map<String, Object?> dps;
  final bool enabled;

  /// True when every value in [dps] is `true` (a "Turn on" timer).
  bool? get turnsOn {
    final values = dps.values.toSet();
    if (values.length != 1) return null;
    final only = values.single;
    return only is bool ? only : null;
  }

  @override
  List<Object?> get props => [id, deviceId, hour, minute, days, dps, enabled];
}

/// What the user fills in on the "New schedule" sheet.
class TimerDraft {
  const TimerDraft({
    required this.hour,
    required this.minute,
    required this.days,
    required this.dps,
  });

  final int hour;
  final int minute;
  final List<int> days;
  final Map<String, Object?> dps;
}
