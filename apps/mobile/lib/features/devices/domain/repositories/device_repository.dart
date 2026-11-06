import '../entities/device.dart';

abstract interface class DeviceRepository {
  /// All devices in a home, with current state and online status.
  Future<List<Device>> getHomeDevices(String homeId);

  /// Sets DPs by code, e.g. `{'switch_1': true}`. Completes when the cloud
  /// accepted the command; the new state arrives over realtime.
  Future<void> sendCommand(String deviceId, Map<String, Object?> dps);

  Future<void> rename(String deviceId, String name);

  /// [roomId] null means "no room".
  Future<void> moveToRoom(String deviceId, String? roomId);

  /// Unbinds the device; it returns to pairing mode.
  Future<void> remove(String deviceId);
}
