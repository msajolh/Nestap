import '../entities/device_timer.dart';

abstract interface class TimerRepository {
  Future<List<DeviceTimer>> getTimers(String deviceId);

  Future<DeviceTimer> create(String deviceId, TimerDraft draft);

  Future<void> setEnabled(String timerId, {required bool enabled});

  Future<void> delete(String timerId);
}
